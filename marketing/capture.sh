#!/bin/bash
# 부팅된 시뮬레이터의 "현재 화면"을 깔끔한 상태바(9:41, 풀 배터리/신호)로 캡처한다.
# 사용법: ./capture.sh <이름>    예) ./capture.sh screen2
# 결과:  marketing/raw/<이름>.png
#
# 워크플로: 시뮬레이터에서 원하는 화면으로 이동 → 이 스크립트 실행 → shots.json 에 캡션 작성 → make_shot.py
set -e
NAME="${1:-screen1}"
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$DIR/raw"

# 상태바를 App Store 표준(9:41, 풀 배터리/신호)으로 고정
xcrun simctl status_bar booted override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 --dataNetwork wifi 2>/dev/null || true

# "◀ Safari" 같은 '이전 앱으로' 표시 제거 (직전 포그라운드 앱 종료)
xcrun simctl terminate booted com.apple.mobilesafari 2>/dev/null || true

xcrun simctl io booted screenshot "$DIR/raw/$NAME.png"
echo "✅ raw/$NAME.png 캡처 완료"
