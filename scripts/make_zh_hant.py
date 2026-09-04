#!/usr/bin/env python3
"""번체(zh-Hant) 를 간체(zh-Hans) 에서 다시 만든다.

왜 자동인가: 같은 글을 두 벌 손으로 관리하면 한쪽만 고쳐진 채로 남는다.
간체만 사람이 쓰고, 번체는 언제든 여기서 다시 뽑는다.

두 단계다.
  1) 글자: macOS 의 ICU 변환(Hans-Hant). `zh_hant_transform.swift` 가 한다.
  2) 말   : 대만에서 쓰는 어휘·인용부호. `zh_hant_vocab.py` 의 표가 한다.
     (剪貼板→剪貼簿, 設置→設定, “”→「」 … 글자만 바꾸면 대륙 말이 그대로 남는다)

쓰는 법:
    python3 scripts/make_zh_hant.py            # 카탈로그의 zh-Hant 를 통째로 다시 만든다
    python3 scripts/make_zh_hant.py --check    # 다시 만든 것과 다른 항목만 세어 본다(고치지 않음)

⚠️ 새 문자열을 더했으면 **간체를 먼저** 채운 뒤 이걸 돌린다. 간체가 없으면 그 줄은 건너뛴다.
"""
import collections
import io
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "ClipKeyboard", "Localizable.xcstrings")
SWIFT = os.path.join(ROOT, "scripts", "zh_hant_transform.swift")

sys.path.insert(0, os.path.join(ROOT, "scripts"))
from zh_hant_vocab import to_taiwan  # noqa: E402

NEWLINE_MARK = "⏎"  # 한 줄에 한 항목으로 넘기려고 줄바꿈을 이 글자로 접어 둔다


def transform(lines):
    """ICU 로 글자만 번체로 바꾼다 (macOS 의 CFStringTransform)."""
    out = subprocess.run(
        ["swift", SWIFT], input="\n".join(lines), capture_output=True, text=True, check=True
    ).stdout.split("\n")
    if out and out[-1] == "":
        out.pop()
    assert len(out) == len(lines), f"줄 수가 어긋남: {len(lines)} → {len(out)}"
    return out


def main():
    check_only = "--check" in sys.argv
    d = json.loads(io.open(CATALOG, encoding="utf-8").read(),
                   object_pairs_hook=collections.OrderedDict)
    strings = d["strings"]

    keys, hans = [], []
    for key, entry in strings.items():
        unit = entry.get("localizations", {}).get("zh-Hans", {}).get("stringUnit")
        if not unit:
            continue
        keys.append(key)
        hans.append(unit["value"].replace("\n", NEWLINE_MARK))

    hant = [to_taiwan(line).replace(NEWLINE_MARK, "\n") for line in transform(hans)]

    changed = 0
    for key, value in zip(keys, hant):
        locs = strings[key].setdefault("localizations", collections.OrderedDict())
        current = locs.get("zh-Hant", {}).get("stringUnit", {}).get("value")
        if current == value:
            continue
        changed += 1
        locs["zh-Hant"] = collections.OrderedDict(
            [("stringUnit", collections.OrderedDict([("state", "translated"), ("value", value)])) ]
        )
        strings[key]["localizations"] = collections.OrderedDict(sorted(locs.items()))

    if check_only:
        print(f"간체 {len(keys)}건 중 번체가 다른 항목 {changed}건")
        return 1 if changed else 0

    # ⚠️ 끝에 줄바꿈을 붙이지 않는다. Xcode 는 안 붙인다 - 붙이면 빌드할 때마다
    #    그 한 글자가 오갔다 하며 diff 가 선다 (scripts/i18n.py 의 `write_catalog` 와 같은 규칙).
    io.open(CATALOG, "w", encoding="utf-8").write(
        json.dumps(d, ensure_ascii=False, indent=2, separators=(",", " : "), sort_keys=False)
    )
    print(f"번체 {len(keys)}건 재생성 (바뀐 항목 {changed}건)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
