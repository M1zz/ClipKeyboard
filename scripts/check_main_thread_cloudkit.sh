#!/bin/sh
# CloudKit 컨테이너를 메인 스레드에서 만들 수 있는 코드가 다시 생겼는지 본다.
#
# 왜 이 검사가 있나:
# `CKContainer(identifier:)` 는 값 하나 만드는 생성자처럼 보이지만 cloudd 와 XPC 를
# 주고받는다. 데몬이 대답하지 않으면 부른 스레드가 그대로 멈추고, 그 스레드가 메인이면
# 앱은 화면 한 장 못 그린 채 워치독에 죽는다. 4.4.6 이 실제로 그렇게 죽었다
# (0x8BADF00D, scene-create, 앱 CPU 0.135초 / 경과 22초).
# 기록: docs/LAUNCH_WATCHDOG_4_4_6.md
#
# 규칙: `CKContainer(identifier:)` 를 부르는 자리는
#       ClipKeyboard/Service/CloudKitContainerGate.swift 하나뿐이다.
#
# 사용법: sh scripts/check_main_thread_cloudkit.sh
set -e
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

GATE="ClipKeyboard/Service/CloudKitContainerGate.swift"

# 주석(// 로 시작하는 줄)은 규칙을 설명하는 문장이라 검사에서 뺀다.
HITS="$(grep -rn --include='*.swift' 'CKContainer(identifier:' \
          ClipKeyboard ClipKeyboardExtension ClipKeyboardShareExtension \
          ClipKeyboardActionExtension widget Shared 2>/dev/null \
        | grep -v "^$GATE:" \
        | grep -vE '^[^:]+:[0-9]+: *(//|///|\*)' || true)"

if [ -n "$HITS" ]; then
  echo "❌ CloudKit 컨테이너를 관문 밖에서 만들고 있습니다:"
  echo "$HITS" | sed 's/^/   /'
  echo ""
  echo "   대신 CloudKitContainer 를 쓰세요 (메인 스레드 밖에서 만들어 줍니다):"
  echo "     let db = await CloudKitContainer.privateDatabase(identifier)"
  echo "     let db = await CloudKitContainer.publicDatabase(identifier)"
  echo "   이유: $GATE 위쪽 주석"
  exit 1
fi

echo "✅ CloudKit 컨테이너 생성은 관문($GATE) 한 곳뿐"
