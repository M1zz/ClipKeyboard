#!/bin/sh
# 배포 전 게이트 — 다국어 검사 + 전체 테스트가 통과해야 아카이브를 만든다.
#
# 사용법:
#   sh scripts/predeploy.sh            # 검사 + 전체 테스트만 (게이트 확인)
#   sh scripts/predeploy.sh --archive  # 통과 시 App Store용 아카이브 생성 + Organizer 열기
#
# Xcode의 Archive pre-action은 실패해도 아카이브를 막지 못하므로,
# 배포 시에는 Xcode 메뉴 대신 이 스크립트의 --archive를 사용할 것.
set -e
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

SCHEME="ClipKeyboard"

echo "🌐 [1/2] 다국어 검사 (check_localization.py)"
python3 scripts/check_localization.py

# 사용 가능한 첫 iPhone 시뮬레이터를 자동 선택
DEST_ID="$(xcrun simctl list devices available | grep "iPhone" | head -1 | grep -oE '[0-9A-F-]{36}')"
if [ -z "$DEST_ID" ]; then
  echo "❌ 사용 가능한 iPhone 시뮬레이터가 없습니다 (xcrun simctl list devices)"
  exit 1
fi

echo "🧪 [2/2] 전체 테스트 실행 (ClipKeyboardTests, 시뮬레이터 $DEST_ID)"
xcodebuild test \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$DEST_ID" \
  -quiet

echo ""
echo "✅ 모든 검사·테스트 통과 — 배포 가능"

if [ "$1" = "--archive" ]; then
  STAMP="$(date +%Y%m%d-%H%M)"
  ARCHIVE="build/ClipKeyboard-$STAMP.xcarchive"
  echo "📦 아카이브 생성 중: $ARCHIVE"
  xcodebuild archive \
    -scheme "$SCHEME" \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    -quiet
  echo "✅ 아카이브 완료 — Organizer에서 Distribute App으로 업로드하세요"
  open "$ARCHIVE"
fi
