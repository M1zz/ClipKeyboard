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

# --- 하드코딩 한국어(미감싼 UI 문자열) 검사 -----------------------------------
import glob

# UI에 직접 들어가는 한글 문자열 리터럴(Text/Button/navigationTitle 등) + Screens의 한글 배열.
_UI_CALL = re.compile(
    r'(?:Text|Label|Button|navigationTitle|navigationBarTitle|searchable|tabItem'
    r'|confirmationDialog|Picker|Toggle|Section|TextField|Menu|alert|prompt)'
    r'\s*\(\s*(?:[^,()"]*,\s*)?"(?:[^"\\]|\\.)*[가-힣]'
)
_ARRAY = re.compile(r'\b(?:let|var)\s+\w+(?:\s*:\s*\[String\])?\s*=\s*\[[^\]]*?"[^"]*[가-힣][^"]*"')

def _korean_lits_all_tokens(line: str) -> bool:
    """줄의 한글 리터럴이 모두 `{토큰}` 형태면 True(템플릿 토큰 배열 → 무시)."""
    kor = [l for l in re.findall(r'"([^"]*)"', line) if HANGUL.search(l)]
    return bool(kor) and all(re.search(r'\{[^}]*[가-힣]', l) for l in kor)

def check_hardcoded_korean(root: str):
    """NSLocalizedString으로 감싸지 않은 한국어 UI 문자열을 찾는다. (Screens/익스텐션/디자인시스템)"""
    globs = [
        os.path.join(root, "ClipKeyboard", "Screens", "**", "*.swift"),
        os.path.join(root, "ClipKeyboard", "DesignSystem", "**", "*.swift"),
        os.path.join(root, "ClipKeyboardExtension", "**", "*.swift"),
        # 맥 앱 뷰도 영어 노출 보장. Models.swift는 분류 enum rawValue(저장용
        # 한국어)라 UI가 아니므로 제외.
        os.path.join(root, "ClipKeyboard.tap", "*.swift"),
    ]
    # 데이터 모델/직렬화용 한국어(enum rawValue 등)는 UI가 아니므로 스캔 제외.
    excluded_basenames = {"Models.swift"}
    violations = []
    for pat in globs:
        for f in glob.glob(pat, recursive=True):
            if os.path.basename(f) in excluded_basenames:
                continue
            try:
                lines = open(f, encoding="utf-8").read().splitlines()
            except OSError:
                continue
            for i, line in enumerate(lines, 1):
                if "NSLocalizedString" in line or "isKorean" in line:
                    continue
                s = line.lstrip()
                if s.startswith("//") or s.startswith("*") or s.startswith("/*"):
                    continue
                if _korean_lits_all_tokens(line):
                    continue
                if _UI_CALL.search(line) or _ARRAY.search(line):
                    violations.append((os.path.relpath(f, root), i, line.strip()[:80]))
    return violations


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

    hardcoded = check_hardcoded_korean(root)

    total = len(en_has_korean) + len(missing_en) + len(hardcoded)
    if total == 0:
        print("✅ check_localization: 영어 슬롯/하드코딩 한국어 노출 없음")
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
    if hardcoded:
        print(f"\n[하드코딩 한국어 — NSLocalizedString으로 감싸야 함] {len(hardcoded)}건", file=out)
        for rel, ln, txt in hardcoded:
            print(f"  • {rel}:{ln}\n      {txt}", file=out)
    print("\n→ 카탈로그 en 값을 영어로 채우거나, UI 문자열을 NSLocalizedString으로 감싸세요.", file=out)
    return 1

if __name__ == "__main__":
    sys.exit(main())
