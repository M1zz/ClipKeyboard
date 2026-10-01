#!/bin/sh
# 스토어 스크린샷 원본을 찍는다. 손으로 몰지 않는다.
#
#   sh scripts/take_screenshots.sh <기기 UDID> <iphone|ipad> <언어...>
#   예) sh scripts/take_screenshots.sh 27D95C0F-7136-4813-B4A8-71B22249B3BA iphone ko en ja
#
# 앞서 디버그 빌드를 깔아 둔다. 화면은 DEBUG 전용 실행 인자 `-ScreenshotScene` 로 연다
# (InAppKeyboardStage · ClipKeyboardList · ClipKeyboardApp 의 `#if DEBUG` 블록).
# 원본은 docs/screenshots/raw/<기기>/<언어>/ 에, 제출 규격으로 줄여 둔다.
# 그다음 `python3 scripts/make_marketing_screenshots.py <언어> <기기>` 가 글과 목업을 입힌다.
set -e
D="$1"; DEVICE="$2"; shift 2
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BID=com.Ysoup.TokenMemo

boot() {
  xcrun simctl boot "$D" 2>/dev/null || true
  until xcrun simctl list devices | grep -q "$D) (Booted)"; do sleep 1; done
}

for L in "$@"; do
  boot
  APP=$(xcrun simctl get_app_container "$D" $BID data)
  G=$(xcrun simctl get_app_container "$D" $BID groups | awk -F'\t' '$1=="group.com.Ysoup.TokenMemo"{print $2}')
  xcrun simctl terminate "$D" $BID 2>/dev/null || true
  # ⚠️ 앱 그룹 UserDefaults 는 **기기를 끈 상태에서** 써야 한다(scripts/demo_setup.sh 머리말).
  xcrun simctl shutdown "$D"
  until ! xcrun simctl list devices | grep -q "$D) (Booted)"; do sleep 1; done
  python3 "$ROOT/scripts/demo_seed.py" "$G" "$L" "$APP"
  boot
  sleep 6
  xcrun simctl spawn "$D" defaults write .GlobalPreferences AppleLanguages -array "$L"
  # 기존 스토어 그림이 밝은 화면이다. 어두운 판 위에 밝은 화면을 얹는다.
  xcrun simctl ui "$D" appearance light
  xcrun simctl status_bar "$D" override --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true
  OUT="$ROOT/docs/screenshots/raw/$DEVICE/$L"
  mkdir -p "$OUT"

  shot() {  # 파일 이름 · 첫 탭 모양 · 장면
    xcrun simctl terminate "$D" $BID 2>/dev/null || true
    sleep 1
    xcrun simctl launch "$D" $BID -AppleLanguages "($L)" -AppleLocale "$L" \
      -snippetsTabStyle.v1 "$2" -ScreenshotScene "$3" \
      -startedFresh.v444 NO -firstShortcut.done.v1 YES -tutorialChaptersDone.v1 YES \
      -keyboardStageOffered.v1 YES -didYouKnow.optOut.v1 YES -ghostSuggestionsOff_v1 YES \
      -AppleKeyboards '("com.Ysoup.TokenMemo.ClipKeyboardExtension")' >/dev/null
    sleep 9
    xcrun simctl io "$D" screenshot --type=png "$OUT/tmp.png" >/dev/null 2>&1
    if [ "$DEVICE" = iphone ]; then
      ffmpeg -loglevel error -y -i "$OUT/tmp.png" -vf "scale=1242:2699,crop=1242:2688" "$OUT/$1"
    else
      ffmpeg -loglevel error -y -i "$OUT/tmp.png" -vf "scale=2064:2752" "$OUT/$1"
    fi
    rm -f "$OUT/tmp.png"
    echo "  $L $1"
  }
  shot 01-keyboard-in-messages.png keyboard none
  shot 02-template-fill.png        keyboard template
  shot 03-snippet-stack.png        list     stack
  shot 04-keyboard-size.png        list     layout
  shot 05-all-snippets.png         list     none
done
