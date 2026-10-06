#!/bin/sh
# 앱 미리보기 영상의 원본을 녹화한다. 손으로 몰지 않는다.
#
#   sh scripts/take_demo_video.sh <아이폰 UDID> <언어...>
#   예) sh scripts/take_demo_video.sh 27D95C0F-7136-4813-B4A8-71B22249B3BA ko en
#
# 앞서 디버그 빌드를 깔아 둔다(docs/screenshots/README.md). 앱은 `-ScreenshotScene demo` 로 켜지면
# 스스로 한 바퀴 돈다(InAppKeyboardStage.runScreenshotScene): 넣고 보내기, 빈칸 채워 보내기,
# '최근' 탭에서 꺼내 보내기. 원본은 docs/screenshots/raw/video/<언어>.mov 에 둔다.
# 그다음 `python3 scripts/make_preview_video.py <언어>` 가 자막을 입혀 제출본을 만든다.
set -e
D="$1"; shift
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BID=com.Ysoup.TokenMemo
OUT="$ROOT/docs/screenshots/raw/video"
mkdir -p "$OUT"

boot() {
  xcrun simctl boot "$D" 2>/dev/null || true
  until xcrun simctl list devices | grep -q "$D) (Booted)"; do sleep 1; done
  xcrun simctl bootstatus "$D" -b >/dev/null 2>&1 &
  W=$!; N=0
  while kill -0 $W 2>/dev/null && [ $N -lt 90 ]; do sleep 1; N=$((N+1)); done
  kill $W 2>/dev/null || true
}

for L in "$@"; do
  boot
  APP=$(xcrun simctl get_app_container "$D" $BID data)
  G=$(xcrun simctl get_app_container "$D" $BID groups | awk -F'\t' '$1=="group.com.Ysoup.TokenMemo"{print $2}')
  xcrun simctl terminate "$D" $BID 2>/dev/null || true
  # 앱 그룹 UserDefaults 는 기기를 끈 상태에서 써야 한다(scripts/demo_setup.sh 머리말).
  xcrun simctl shutdown "$D"
  # 'Booted' 가 아니라고 다 꺼진 것이 아니다. 'Shutting Down' 중에 boot 하면 거절된다
  until xcrun simctl list devices | grep -q "$D) (Shutdown)"; do sleep 1; done
  python3 "$ROOT/scripts/demo_seed.py" "$G" "$L" "$APP"
  boot
  sleep 6
  xcrun simctl spawn "$D" defaults write .GlobalPreferences AppleLanguages -array "$L"
  # 아이패드 상태 막대의 날짜는 지역을 따른다. 언어만 바꾸면 앞 언어의 날짜가 남는다
  xcrun simctl spawn "$D" defaults write .GlobalPreferences AppleLocale "$(echo "$L" | tr '-' '_')"
  xcrun simctl ui "$D" appearance light
  xcrun simctl status_bar "$D" override --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true

  # 한 번 켰다 끈다. 첫 실행의 준비 동작이 녹화에 섞이지 않게 한다.
  xcrun simctl launch "$D" $BID -AppleLanguages "($L)" -AppleLocale "$L" \
    -snippetsTabStyle.v1 keyboard -ScreenshotScene warmup \
    -startedFresh.v444 NO -firstShortcut.done.v1 YES -tutorialChaptersDone.v1 YES \
    -keyboardStageOffered.v1 YES -didYouKnow.optOut.v1 YES -ghostSuggestionsOff_v1 YES \
    -AppleKeyboards '("com.Ysoup.TokenMemo.ClipKeyboardExtension")' >/dev/null
  sleep 6
  xcrun simctl terminate "$D" $BID 2>/dev/null || true
  sleep 1

  rm -f "$OUT/$L.mov"
  xcrun simctl io "$D" recordVideo --codec h264 --force "$OUT/$L.mov" > "$OUT/$L.log" 2>&1 &
  R=$!
  # 녹화가 실제로 시작되기 전에 켜면 앞이 잘린다
  until grep -q "Recording started" "$OUT/$L.log" 2>/dev/null; do sleep 0.5; done
  sleep 1.5
  xcrun simctl launch "$D" $BID -AppleLanguages "($L)" -AppleLocale "$L" \
    -snippetsTabStyle.v1 keyboard -ScreenshotScene demo \
    -startedFresh.v444 NO -firstShortcut.done.v1 YES -tutorialChaptersDone.v1 YES \
    -keyboardStageOffered.v1 YES -didYouKnow.optOut.v1 YES -ghostSuggestionsOff_v1 YES \
    -AppleKeyboards '("com.Ysoup.TokenMemo.ClipKeyboardExtension")' >/dev/null
  # 앱이 뜨는 데 3~5초, 한 바퀴가 18초쯤이다. 마지막 장면을 조금 더 담는다
  sleep 27
  kill -INT $R
  wait $R 2>/dev/null || true
  rm -f "$OUT/$L.log"
  echo "  $L 녹화 $OUT/$L.mov"
done
