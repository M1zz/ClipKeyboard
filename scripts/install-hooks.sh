#!/bin/sh
# git 훅 설치 - 새 머신/클론에서 1회 실행: sh scripts/install-hooks.sh
# (.git/hooks 는 버전관리가 안 되므로 이 스크립트로 재설치한다)
set -e
ROOT="$(git rev-parse --show-toplevel)"
HOOK="$ROOT/.git/hooks/pre-commit"

cat > "$HOOK" <<'SH'
#!/bin/sh
# 영어 슬롯에 한국어가 들어가면 커밋 차단 (scripts/check_localization.py)
# 우회가 필요하면: git commit --no-verify
ROOT="$(git rev-parse --show-toplevel)"
python3 "$ROOT/scripts/check_localization.py" || {
  echo ""
  echo "❌ 커밋 차단: 영어 사용자에게 한국어가 노출되는 항목이 있습니다."
  echo "   (긴급 우회: git commit --no-verify)"
  exit 1
}

# CloudKit 컨테이너를 메인 스레드에서 만들 수 있는 코드가 들어오면 커밋 차단.
# 그 한 줄이 런치를 붙잡으면 앱은 워치독에 죽는다 (4.4.6 사고).
sh "$ROOT/scripts/check_main_thread_cloudkit.sh" || {
  echo ""
  echo "❌ 커밋 차단: CloudKit 컨테이너를 관문 밖에서 만들고 있습니다."
  echo "   (긴급 우회: git commit --no-verify)"
  exit 1
}

# 클립보드를 메인 스레드에서 읽는 코드가 들어오면 커밋 차단.
# 유니버설 클립보드가 켜져 있으면 그 한 줄이 초 단위로 기다린다 (5.0.1 멈춤).
sh "$ROOT/scripts/check_main_thread_pasteboard.sh" || {
  echo ""
  echo "❌ 커밋 차단: 클립보드를 메인에서 읽고 있습니다."
  echo "   (긴급 우회: git commit --no-verify)"
  exit 1
}
# 긴 줄표(U+2014 / U+2013)가 들어오면 커밋 차단 - 저장소 전 범위 규칙(CLAUDE.md).
sh "$ROOT/scripts/check_dashes.sh" --staged || {
  echo ""
  echo "❌ 커밋 차단: 긴 줄표가 들어 있습니다."
  echo "   (긴급 우회: git commit --no-verify)"
  exit 1
}

SH

chmod +x "$HOOK"
echo "✅ pre-commit 훅 설치 완료: $HOOK"

# ── commit-msg: 커밋 메시지에도 같은 규칙 ──
# CLAUDE.md 의 금지 범위에 커밋 메시지가 포함돼 있는데, 예전에는 검사가 없었다.
MSGHOOK="$ROOT/.git/hooks/commit-msg"
cat > "$MSGHOOK" <<'SH2'
#!/bin/sh
# 커밋 메시지에 긴 줄표(U+2014 / U+2013)가 있으면 차단.
EM="$(printf '\342\200\224')"
EN="$(printf '\342\200\223')"
if grep -q "[$EM$EN]" "$1"; then
  echo "❌ 커밋 차단: 커밋 메시지에 긴 줄표가 있습니다."
  grep -n "[$EM$EN]" "$1"
  echo "   쉼표(,) 마침표(.) 가운뎃점(·) 콜론(:) 또는 괄호로 바꿉니다."
  echo "   (긴급 우회: git commit --no-verify)"
  exit 1
fi
SH2
chmod +x "$MSGHOOK"
echo "✅ commit-msg 훅 설치: $MSGHOOK"
