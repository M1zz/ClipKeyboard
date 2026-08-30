#!/bin/sh
# 알림을 메인 밖에서 쏠 수 있는 코드가 다시 생겼는지 본다.
#
# 왜 이 검사가 있나:
# `NotificationCenter` 는 **쏜 스레드에서 그대로** 받는 쪽을 부른다. 그런데 이 앱에서
# 알림을 받는 쪽은 거의 전부 화면이고, SwiftUI 의 `onReceive` 는 안에 `receive(on:)` 이
# 없다. 그래서 배경에서 쏜 알림은 **배경 스레드에서** 클로저를 돌리고, 그 클로저가
# `@State` 를 고치거나 뷰모델을 다시 읽게 하면 이 경고가 뜬다.
#
#     Publishing changes from background threads is not allowed
#
# 이 경고가 붙여 주는 파일·행은 **발행한 자리가 아니라 발행을 촉발한 자리**다.
# 그래서 알림을 쏘는 줄이 범인으로 지목되고, 그 줄만 고쳐서는 안 사라진다.
# 실제로 5.0.6 에서 두 번 헛짚었다. 기록: docs/postmortem/OFF_MAIN_PUBLISH_5_0_6.md
#
# 규칙: 알림은 `NotificationCenter.postOnMain(name:object:userInfo:)` 로만 쏜다.
#       (ClipKeyboard/AppNotification.swift. 이미 메인이면 그 자리에서 쏘므로
#        눌러서 시트가 뜨는 흐름의 순서는 그대로다)
#
# 예외: 시험 코드(ClipKeyboardTests)는 일부러 그 자리에서 쏘고 곧바로 확인한다.
#       그 밖에 꼭 직접 쏴야 하면 그 줄(또는 바로 윗줄)에 이유를 붙인다:
#
#           // notify-ok: 메인이어도 한 박자 미뤄야 하는 재진입 때문
#           NotificationCenter.default.post(name: .memoDataChanged, object: nil)
#
# 사용법: sh scripts/check_notification_main.sh
set -e
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

GATE="ClipKeyboard/AppNotification.swift"

RAW="$(grep -rn --include='*.swift' 'NotificationCenter\.default\.post(' \
         ClipKeyboard ClipKeyboardExtension ClipKeyboardActionExtension \
         ClipKeyboardShareExtension Shared widget 2>/dev/null \
       | grep -v "^$GATE:" \
       | grep -vE '^[^:]+:[0-9]+: *(//|///|\*)' || true)"

HITS=""
OLDIFS="$IFS"
IFS='
'
for line in $RAW; do
  [ -n "$line" ] || continue
  file="$(echo "$line" | cut -d: -f1)"
  num="$(echo "$line" | cut -d: -f2)"
  prev=$((num - 1))
  [ "$prev" -lt 1 ] && prev=1
  if sed -n "${prev},${num}p" "$file" 2>/dev/null | grep -q 'notify-ok'; then
    continue
  fi
  HITS="$HITS
$line"
done
IFS="$OLDIFS"

HITS="$(echo "$HITS" | sed '/^$/d')"

if [ -n "$HITS" ]; then
  echo "❌ 알림을 메인 밖에서 쏠 수 있습니다:"
  echo "$HITS" | sed 's/^/   /'
  echo ""
  echo "   대신 이 문을 지나세요 (이미 메인이면 그 자리에서, 아니면 메인으로 넘겨 쏩니다):"
  echo "     NotificationCenter.postOnMain(name: .someName)"
  echo "   꼭 직접 쏴야 하면 그 줄 위에 이유를 적으세요:"
  echo "     // notify-ok: <이유>"
  echo "   이유: $GATE 아래쪽 주석 · docs/postmortem/OFF_MAIN_PUBLISH_5_0_6.md"
  exit 1
fi

echo "✅ 알림을 쏘는 문은 한 곳($GATE)뿐"
