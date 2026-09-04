#!/bin/sh
# 클립보드를 메인 스레드에서 읽는 코드가 다시 생겼는지 본다.
#
# 왜 이 검사가 있나:
# `UIPasteboard.general.string` 은 속성 하나 읽는 것처럼 보이지만 pasteboardd 와 주고받는
# 일이고, 유니버설 클립보드가 켜져 있으면 **옆 기기에서 내용을 끌어오기까지 기다린다.**
# 기다리는 동안 부른 스레드는 선다. 그 스레드가 메인이면 화면이 굳는다.
# `.image` 는 거기에 큰 그림을 푸는 일까지 얹힌다.
# 5.0.1 에서 1.28초 멈춤(hang)이 실제로 올라왔다. 기록: docs/postmortem/HANG_PASTEBOARD_5_0_1.md
#
# 규칙: **자동으로** 읽는 자리(화면이 뜰 때·앱이 앞으로 올 때)는 `PasteboardReader` 로만 읽는다.
#
# 예외: 사용자가 붙여넣기를 직접 누른 자리. 거기서는 기다림이 곧 대답이다.
#       그 줄(또는 바로 윗줄)에 이유를 붙여 표시한다:
#
#           // pasteboard-ok: 사용자가 붙여넣기 버튼을 눌렀다
#           clipboard = UIPasteboard.general.string
#
#       ⚠️ 파일 단위로 봐주지 않는 이유: 한 파일 안에 사용자가 시킨 읽기와
#          저절로 도는 읽기가 같이 산다. 봐주려면 **그 줄만** 봐줘야 한다.
#
# 쓰기(`UIPasteboard.general.string = …`)는 검사하지 않는다. 기다리는 일이 아니다.
#
# 사용법: sh scripts/check_main_thread_pasteboard.sh
set -e
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

READER="ClipKeyboard/Service/PasteboardReader.swift"

# 읽기만 고른다: `UIPasteboard.general.<속성>` 뒤에 `=` 가 오면 쓰기다.
RAW="$(grep -rnE --include='*.swift' 'UIPasteboard\.general\.(string|image|items|data)' \
         ClipKeyboard 2>/dev/null \
       | grep -v "^$READER:" \
       | grep -vE '^[^:]+:[0-9]+: *(//|///|\*)' \
       | grep -vE 'UIPasteboard\.general\.(string|image|items|data)[a-zA-Z]* *=[^=]' || true)"

HITS=""
for hit in $(echo "$RAW" | tr ' ' '\001'); do
  line="$(echo "$hit" | tr '\001' ' ')"
  [ -n "$line" ] || continue
  file="$(echo "$line" | cut -d: -f1)"
  num="$(echo "$line" | cut -d: -f2)"
  prev=$((num - 1))
  [ "$prev" -lt 1 ] && prev=1
  if sed -n "${prev},${num}p" "$file" 2>/dev/null | grep -q 'pasteboard-ok'; then
    continue
  fi
  HITS="$HITS
$line"
done

HITS="$(echo "$HITS" | sed '/^$/d')"

if [ -n "$HITS" ]; then
  echo "❌ 클립보드를 메인에서 읽고 있습니다:"
  echo "$HITS" | sed 's/^/   /'
  echo ""
  echo "   대신 PasteboardReader 를 쓰세요 (메인 밖에서 읽고 메인으로 돌려줍니다):"
  echo "     PasteboardReader.string { text in … }"
  echo "     PasteboardReader.content { content in … }"
  echo "   사용자가 직접 누른 자리라면 그 줄 위에 이유를 적으세요:"
  echo "     // pasteboard-ok: 사용자가 붙여넣기 버튼을 눌렀다"
  echo "   이유: $READER 위쪽 주석 · docs/postmortem/HANG_PASTEBOARD_5_0_1.md"
  exit 1
fi

echo "✅ 자동으로 읽는 클립보드는 통로($READER) 한 곳뿐"
