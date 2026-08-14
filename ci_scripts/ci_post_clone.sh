#!/bin/sh
#
# Xcode Cloud - 저장소를 클론한 직후, 빌드가 시작되기 **전에** 도는 스크립트.
#
# 여기서 하는 일은 하나다: **싼 검사를 먼저 돌려 비싼 빌드를 아낀다.**
# 다국어 위반은 컴파일과 무관하게 통과해 버리므로, 빌드를 15분 돌린 뒤 배포하고 나서야
# 영어 사용자가 한국어를 보는 일이 생긴다. 그 검사는 1초면 끝나므로 맨 앞에 둔다.
#
# ⚠️ Xcode Cloud 는 이 파일이 `ci_scripts/` 아래에 이 이름으로 있을 때만 실행한다.
#    이름을 바꾸면 조용히 건너뛴다(빌드 로그에 "Post-Clone script not found" 로 남는다).
# ⚠️ 실행 권한이 있어야 한다. `git update-index --chmod=+x` 로 저장소에 권한째 들어가 있다.
# ⚠️ 실패하면(비0 종료) 빌드가 거기서 멈춘다. 그게 이 파일의 존재 이유다.
#
# 자세한 배경과 워크플로 설정 방법: docs/XCODE_CLOUD.md
#

set -e

echo "▶︎ [ci_post_clone] 저장소 검사 시작"
cd "$CI_PRIMARY_REPOSITORY_PATH" || exit 1

# ── 1. 다국어: 영어 슬롯에 한국어가 들어갔거나, 감싸지 않은 한국어 UI 문자열이 있는가 ──
if command -v python3 >/dev/null 2>&1; then
  echo "▶︎ [ci_post_clone] 다국어 검사"
  python3 scripts/check_localization.py
else
  # 파이썬이 없다고 빌드를 세우지는 않는다 - 검사를 못 한 것과 위반이 있는 것은 다르다.
  echo "⚠️ [ci_post_clone] python3 없음, 다국어 검사를 건너뜁니다"
fi

# ── 2. 긴 줄표(em dash / en dash) 금지 - 저장소 규칙 ──
# 사람이 쓴 글처럼 읽히게 하려고 정한 규칙이라, 사람이 아니라 여기서 지킨다.
echo "▶︎ [ci_post_clone] 긴 줄표 검사"
DASH_HITS=$(grep -rln "$(printf '—')" \
  --include="*.swift" --include="*.xcstrings" \
  ClipKeyboard ClipKeyboardExtension widget 2>/dev/null || true)
if [ -n "$DASH_HITS" ]; then
  echo "❌ [ci_post_clone] 긴 줄표(U+2014)가 남아 있습니다:"
  echo "$DASH_HITS"
  exit 1
fi

echo "✅ [ci_post_clone] 검사 통과"
