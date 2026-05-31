#!/usr/bin/env python3
"""
영어 사용자에게 한국어가 노출되는 것을 빌드/커밋 단계에서 자동 차단한다.

검사 항목 (ClipKeyboard/Localizable.xcstrings):
  1) 영어(en) 번역 슬롯에 한글이 들어간 항목  → 영어 유저가 한국어를 봄
  2) 한글이 포함된 키인데 en 로컬라이제이션이 아예 없는 항목 → 한글 키로 폴백

위반이 하나라도 있으면 비0으로 종료(빌드/커밋 실패)하고 목록을 출력한다.

사용:
  python3 scripts/check_localization.py            # 일반 실행 (실패 시 exit 1)
  python3 scripts/check_localization.py --xcode    # Xcode Run Script 용 (error: 접두사 출력)

의도적으로 영어 문구에 한글 토큰이 필요한 경우(키보드 한/EN 토글, 두벌식/천지인
레이아웃 이름 등)는 ALLOW_SUBSTRINGS 에 추가한다.
"""
import json
import re
import sys
import os

HANGUL = re.compile(r"[가-힣]")

# en 값에 한글이 있어도 허용되는 정당한 케이스(부분 문자열 매칭).
# 한국어 입력 토글/레이아웃 고유명사 등 — 추가 시 사유를 주석으로 남길 것.
ALLOW_SUBSTRINGS = [
    "한/EN",        # 키보드 언어 전환 버튼 라벨(양언어 공통)
    "(한 toggle)",  # 위 토글을 설명하는 영어 코멘트성 문구
    "두벌식",        # 한국어 자판 고유명사 (영어 설명 안에서 사용)
    "천지인",        # 한국어 자판 고유명사
]

def main() -> int:
    xcode = "--xcode" in sys.argv
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    path = os.path.join(root, "ClipKeyboard", "Localizable.xcstrings")
    if not os.path.exists(path):
        print(f"check_localization: catalog not found at {path}", file=sys.stderr)
        return 0  # 카탈로그 없으면 통과(다른 컨텍스트에서 실행된 경우)

    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    strings = data.get("strings", {})

    en_has_korean = []   # (key, en_value)
    missing_en = []      # key

    for key, entry in strings.items():
        if not key.strip():
            continue
        locs = entry.get("localizations", {})
        en = locs.get("en", {}).get("stringUnit", {})
        val = en.get("value")
        key_has_korean = bool(HANGUL.search(key))

        if "en" not in locs:
            if key_has_korean:
                missing_en.append(key)
            continue
        if val and HANGUL.search(val):
            if any(s in val for s in ALLOW_SUBSTRINGS):
                continue
            en_has_korean.append((key, val))

    total = len(en_has_korean) + len(missing_en)
    if total == 0:
        print("✅ check_localization: 영어 슬롯에 한국어 노출 없음")
        return 0

    prefix = "error: " if xcode else ""
    out = sys.stderr
    print(f"{prefix}로컬라이제이션 검사 실패 — 영어 사용자에게 한국어가 노출됩니다 ({total}건)", file=out)
    if en_has_korean:
        print(f"\n[영어(en) 번역에 한글이 들어 있음 — 실제 영어로 번역 필요] {len(en_has_korean)}건", file=out)
        for k, v in en_has_korean:
            print(f"  • key={k[:50]!r}\n      en={v[:70]!r}", file=out)
    if missing_en:
        print(f"\n[영어 번역 누락(한글 키가 그대로 노출됨)] {len(missing_en)}건", file=out)
        for k in missing_en:
            print(f"  • {k[:70]!r}", file=out)
    print("\n→ ClipKeyboard/Localizable.xcstrings 에서 위 항목의 en 값을 영어로 채우세요.", file=out)
    return 1

if __name__ == "__main__":
    sys.exit(main())
