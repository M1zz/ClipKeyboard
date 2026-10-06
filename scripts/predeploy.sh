#!/bin/sh
# 배포 전 게이트 - 다국어 검사 + 전체 테스트가 통과해야 아카이브를 만든다.
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
# ⚠️ 저장소 루트에는 Xcode Cloud 호환용 심볼릭 링크("Token memo.xcodeproj")가 하나 더 있다.
# -project 를 안 주면 xcodebuild 가 "프로젝트가 둘"이라며 멈춘다.
PROJECT="ClipKeyboard.xcodeproj"

echo "🌐 [1/4] 다국어 검사 (check_localization.py)"
python3 scripts/check_localization.py

echo "🌐 켜 놓은 언어가 다 채워졌는지 검사 (scripts/i18n.py check)"
python3 scripts/i18n.py check

echo "☁️  [2/4] CloudKit 컨테이너 생성 위치 검사 (런치 워치독 재발 방지)"
sh scripts/check_main_thread_cloudkit.sh

echo "📋 [3/4] 클립보드 읽는 위치 검사 (멈춤 재발 방지)"
sh scripts/check_main_thread_pasteboard.sh

echo "🔔 알림 쏘는 위치 검사 (배경 발행 재발 방지)"
sh scripts/check_notification_main.sh

echo "🌐 지구본 검사 (check_globe.sh)"
sh scripts/check_globe.sh

echo "🧭 사용자 여정 표 검사 (check_journeys.sh)"
sh scripts/check_journeys.sh

echo "✒️  긴 줄표 검사 (check_dashes.sh)"
sh scripts/check_dashes.sh

# 사용 가능한 첫 iPhone 시뮬레이터를 자동 선택
DEST_ID="$(xcrun simctl list devices available | grep "iPhone" | head -1 | grep -oE '[0-9A-F-]{36}')"
if [ -z "$DEST_ID" ]; then
  echo "❌ 사용 가능한 iPhone 시뮬레이터가 없습니다 (xcrun simctl list devices)"
  exit 1
fi

echo "🧪 [4/4] 전체 테스트 실행 (ClipKeyboardTests, 시뮬레이터 $DEST_ID)"
# ⚠️ 병렬로 돌리지 않고, 떨어진 시험은 한 번만 다시 돌린다.
#    맥이 바쁠 때(다른 작업의 시뮬레이터 · 색인) 병렬 복제 시뮬레이터가 앱을 못 띄우거나
#    시간을 재는 시험이 흔들려, 2026-10-07 배포가 네 번 연달아 매번 다른 시험 하나로 멈췄다.
#    넷 다 혼자 돌리면 통과했다. 다시 돌려도 떨어지는 시험은 그대로 배포를 막는다.
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$DEST_ID" \
  -parallel-testing-enabled NO \
  -retry-tests-on-failure -test-iterations 2 \
  -quiet

echo ""
echo "✅ 모든 검사·테스트 통과 - 배포 가능"

if [ "$1" = "--archive" ]; then
  STAMP="$(date +%Y%m%d-%H%M)"
  ARCHIVE="build/ClipKeyboard-$STAMP.xcarchive"
  echo "📦 아카이브 생성 중: $ARCHIVE"
  xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    -quiet
  echo "✅ 아카이브 완료 - Organizer에서 Distribute App으로 업로드하세요"
  open "$ARCHIVE"
fi
