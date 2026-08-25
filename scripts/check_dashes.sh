#!/bin/sh
# 긴 줄표(em dash U+2014 / en dash U+2013) 금지 - 저장소 전 범위.
#
# 왜 여기서 지키나: 사람이 쓴 글처럼 읽히게 하려고 정한 규칙이다(CLAUDE.md).
# 취향으로 정한 규칙은 사람이 지키면 반드시 새어 나가므로, 사람이 아니라 이 파일이 지킨다.
#
# 범위: 저장소 전체. 앱 문자열·카탈로그·docs·릴리즈 노트·주석·스크립트가 다 포함된다.
#       예전에는 ClipKeyboard/ClipKeyboardExtension/widget 의 .swift/.xcstrings 만 봤고,
#       그 바깥(docs/)에 위반이 살아 있었다.
#
# 쓰는 법:
#   sh scripts/check_dashes.sh            # 저장소 전체
#   sh scripts/check_dashes.sh --staged   # 커밋될 파일만 (pre-commit 훅)
#
# ⚠️ 이 파일 자체에 그 글자를 적지 않는다. printf 로 만들어 쓴다.
#    (적어 두면 가드가 자기 자신을 잡는다.)

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
cd "$ROOT" || exit 1

EM="$(printf '\342\200\224')"   # U+2014
EN="$(printf '\342\200\223')"   # U+2013
PATTERN="$EM$EN"

HITS=""

if [ "$1" = "--staged" ]; then
  FILES="$(git diff --cached --name-only --diff-filter=ACM)"
  [ -z "$FILES" ] && exit 0
  for f in $FILES; do
    [ -f "$f" ] || continue
    case "$f" in
      .git/*|build/*|*/build/*|DerivedData/*|scripts/check_dashes.sh) continue ;;
    esac
    # -I: 바이너리는 건너뛴다
    if grep -Iq "[$PATTERN]" "$f" 2>/dev/null; then
      HITS="$HITS$(grep -In "[$PATTERN]" "$f" | sed "s|^|$f:|")
"
    fi
  done
else
  HITS="$(grep -rIn "[$PATTERN]" . \
    --exclude-dir=.git --exclude-dir=build --exclude-dir=DerivedData \
    --exclude-dir=.build --exclude-dir=Pods \
    --exclude=check_dashes.sh 2>/dev/null)"
fi

if [ -n "$(printf '%s' "$HITS" | tr -d '[:space:]')" ]; then
  echo "❌ 긴 줄표가 남아 있습니다 (U+2014 / U+2013):"
  printf '%s\n' "$HITS"
  echo ""
  echo "   대체: 사용자에게 보이는 글은 쉼표(,) 마침표(.) 가운뎃점(·) 콜론(:)"
  echo "         코드 주석은 하이픈(-), 끼워 넣는 말은 괄호, 두 문장이면 마침표로 끊는다"
  echo "         범위는 ~ 또는 to"
  exit 1
fi

echo "✅ 긴 줄표 없음 (저장소 전 범위)"
