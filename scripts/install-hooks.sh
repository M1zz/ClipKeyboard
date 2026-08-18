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
SH

chmod +x "$HOOK"
echo "✅ pre-commit 훅 설치 완료: $HOOK"
