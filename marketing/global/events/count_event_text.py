#!/usr/bin/env python3
"""인앱 이벤트 문구의 글자 수를 세어 마크다운 표로 낸다. 한도를 넘거나 한글이 섞이면 0 이 아닌 값으로 끝난다.

    python3 marketing/global/events/count_event_text.py            # 표 출력
"""
import json, pathlib, re, sys, unicodedata

LIMITS = (30, 50, 120)  # 이름 · 짧은 설명 · 긴 설명 (developer.apple.com/app-store/in-app-events)
HANGUL = re.compile(r"[ᄀ-ᇿ㄰-㆏가-힯]")
data = json.loads((pathlib.Path(__file__).with_name("event_text.json")).read_text())
bad = 0
for event, rows in data.items():
    if event == "_":
        continue
    print(f"\n#### `{event}`\n")
    print("| 로케일 | 이벤트 이름 | 자 | 짧은 설명 | 자 | 긴 설명 | 자 |")
    print("| --- | --- | ---: | --- | ---: | --- | ---: |")
    for loc, texts in rows.items():
        cells = []
        for text, limit in zip(texts, LIMITS):
            text = unicodedata.normalize("NFC", text)
            n = len(text)
            mark = "" if n <= limit else " ⛔"
            if n > limit or (loc != "ko" and HANGUL.search(text)):
                bad += 1
                print(f"!! {event} {loc}: {n}/{limit} {text}", file=sys.stderr)
            cells += [text, f"{n}{mark}"]
        print(f"| {loc} | " + " | ".join(cells) + " |")
sys.exit(1 if bad else 0)
