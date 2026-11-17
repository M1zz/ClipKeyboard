#!/usr/bin/env python3
"""자판의 한자 변환 사전을 만든다 (중국어 간체 병음 · 번체 주음).

    python3 -m venv /tmp/ckdict && /tmp/ckdict/bin/pip install pypinyin opencc-python-reimplemented
    curl -o /tmp/jieba_dict.txt https://raw.githubusercontent.com/fxsjy/jieba/master/jieba/dict.txt
    /tmp/ckdict/bin/python scripts/make_typing_dictionary.py /tmp/jieba_dict.txt

나오는 것: ClipKeyboardExtension/Dictionaries/zh-Hans.ckdict · zh-Hant.ckdict
읽는 곳:   ClipKeyboardExtension/ConversionDictionaryFile.swift (메모리 매핑)

재료와 라이선스 (모두 MIT 또는 Apache-2.0, 설정 > 정보에 적는다):
  - 낱말과 빈도: jieba dict.txt (MIT, Sun Junyi)
  - 읽기: pypinyin 과 그 자료 pinyin-data · phrase-pinyin-data (MIT, mozillazg)
  - 간체 → 번체: OpenCC 변환표 (Apache-2.0), opencc-python-reimplemented 로 읽는다

파일 모양 (리틀 엔디언):
  "CKDICT1\\0"                      8바이트
  keyCount                         u32
  offsets[keyCount]                u32, 파일 처음부터 레코드까지
  레코드: keyLen u8, key(UTF-8), valueBytes u16, 낱말들
  낱말:   weight u8, len u8, 글(UTF-8)        weight 큰 것부터

key 는 바이트 순으로 정렬돼 있다. 읽는 쪽은 이분 탐색으로 정확히 같은 key 와 앞부분이 같은 key 를 찾는다.
"""
import math
import struct
import sys
from collections import defaultdict
from pathlib import Path

from opencc import OpenCC
from pypinyin import Style, lazy_pinyin, pinyin

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "ClipKeyboardExtension" / "Dictionaries"

MIN_WORD_FREQ = 10      # 이보다 드문 낱말은 뺀다 (약 10만 개가 남는다)
MAX_WORD_CHARS = 8
MAX_PER_KEY = 200       # 한 읽기에 낱말이 이보다 많으면 드문 것을 자른다
TONES = "ˊˇˋ˙"


def is_han(text: str) -> bool:
    return bool(text) and all("一" <= ch <= "鿿" for ch in text)


def load_words(path: str) -> dict[str, int]:
    words: dict[str, int] = {}
    with open(path, encoding="utf-8") as source:
        for line in source:
            parts = line.split(" ")
            if len(parts) < 2 or not is_han(parts[0]):
                continue
            word, freq = parts[0], int(parts[1])
            if len(word) == 1 or (freq >= MIN_WORD_FREQ and len(word) <= MAX_WORD_CHARS):
                words[word] = max(words.get(word, 0), freq)
    return words


def syllables(word: str, style) -> list[str]:
    out = lazy_pinyin(word, style=style, v_to_u=False)
    return [s.strip(TONES + "ˉ") for s in out]


def char_readings(ch: str, style) -> list[str]:
    seen: list[str] = []
    for reading in pinyin(ch, style=style, heteronym=True, v_to_u=False)[0]:
        reading = reading.strip(TONES + "ˉ")
        if reading and reading not in seen:
            seen.append(reading)
    return seen


def build(words: dict[str, int], style, convert) -> dict[str, dict[str, int]]:
    """읽기 → {낱말: 빈도}. convert 는 적을 글자를 바꾼다 (번체)."""
    table: dict[str, dict[str, int]] = defaultdict(dict)
    from_words: dict[tuple[str, str], int] = defaultdict(int)

    def put(key: str, text: str, freq: int) -> None:
        if not key or not is_han(text):
            return
        table[key][text] = max(table[key].get(text, 0), freq)

    for word, freq in words.items():
        written = convert(word)
        if len(written) != len(word):
            continue
        if len(word) == 1:
            readings = char_readings(word, style)
            for rank, reading in enumerate(readings):
                # 첫 읽기가 그 글자의 빈도를 갖는다. 나머지 읽기는 낱말에서 본 만큼만 올라간다.
                put(reading, written, freq if rank == 0 else max(1, freq // 50))
            continue
        parts = syllables(word, style)
        if len(parts) != len(word) or not all(parts):
            continue
        put("".join(parts), written, freq)
        for ch, part in zip(written, parts):
            from_words[(ch, part)] += freq

    # 낱말 안에서만 나오는 글자와 읽기 (번체의 髮 · 裡, 银行 의 行 hang 같은 것).
    for (ch, part), total in from_words.items():
        put(part, ch, max(1, total // 4))
    return table


def weight(freq: int) -> int:
    return max(1, min(255, round(math.log2(freq + 1) * 10)))


def write(table: dict[str, dict[str, int]], path: Path) -> None:
    records = []
    for key in sorted(table, key=lambda k: k.encode("utf-8")):
        raw_key = key.encode("utf-8")
        if len(raw_key) > 255:
            continue
        ranked = sorted(table[key].items(), key=lambda item: (-item[1], len(item[0]), item[0]))[:MAX_PER_KEY]
        values = b""
        for text, freq in ranked:
            raw = text.encode("utf-8")
            entry = struct.pack("<BB", weight(freq), len(raw)) + raw
            if len(values) + len(entry) > 0xFFFF:
                break
            values += entry
        records.append(struct.pack("<B", len(raw_key)) + raw_key + struct.pack("<H", len(values)) + values)

    header = b"CKDICT1\0" + struct.pack("<I", len(records))
    offset = len(header) + 4 * len(records)
    offsets = b""
    for record in records:
        offsets += struct.pack("<I", offset)
        offset += len(record)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + offsets + b"".join(records))
    words = sum(len(v) for v in table.values())
    print(f"✅ {path.relative_to(ROOT)}: 읽기 {len(records)}개 · 낱말 {words}개 · {path.stat().st_size / 1_048_576:.2f}MB")


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    words = load_words(sys.argv[1])
    print(f"📁 낱말 {len(words)}개")
    write(build(words, Style.NORMAL, lambda w: w), OUT / "zh-Hans.ckdict")
    taiwan = OpenCC("s2tw")
    write(build(words, Style.BOPOMOFO, taiwan.convert), OUT / "zh-Hant.ckdict")


if __name__ == "__main__":
    main()
