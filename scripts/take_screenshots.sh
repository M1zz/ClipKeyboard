#!/bin/sh
# 스토어 스크린샷 원본을 찍는다. 손으로 몰지 않는다.
#
#   sh scripts/take_screenshots.sh <기기 UDID> <iphone|ipad|duo|duo-inner> <언어...>
#   duo: 아이폰 듀오 시뮬레이터(접힌 채, 바깥 화면). Xcode 27.1 로 빌드해 깔아야 호환 틀 없이 뜬다
#   duo-inner: 펼친 듀오의 안쪽 화면. 펴는 것은 Xcode 창에서 손으로 한다(명령줄로는 못 편다).
#              껐다 켜면 다시 접힐 수 있어서 **끄지 않고** 데이터를 심는다(아래 seed_live)
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
  # 'Booted' 는 부팅이 끝났다는 뜻이 아니다. 아이패드는 이 틈에 launch 를 받으면 그대로 굳는다
  # bootstatus 도 가끔 끝나지 않으므로 90초까지만 기다린다
  xcrun simctl bootstatus "$D" -b >/dev/null 2>&1 &
  W=$!; N=0
  while kill -0 $W 2>/dev/null && [ $N -lt 90 ]; do sleep 1; N=$((N+1)); done
  kill $W 2>/dev/null || true
}

# 켠 채로 심는다. 앱 그룹 UserDefaults 를 켠 채 파일로 쓰면 cfprefsd 가 들고 있던 옛 값으로
# 덮어쓰므로, 심기 앞뒤로 cfprefsd 를 SIGKILL 로 내린다(저장 없이 죽고, 다음 요청에 디스크를 다시 읽는다).
# 앱은 언어를 실행 인자로 받으니 기기 언어는 건드리지 않는다. 상태 막대에 날짜가 없는 아이폰 계열만 쓴다
seed_live() {
  APP=$(xcrun simctl get_app_container "$D" $BID data)
  G=$(xcrun simctl get_app_container "$D" $BID groups | awk -F'\t' '$1=="group.com.Ysoup.TokenMemo"{print $2}')
  xcrun simctl terminate "$D" $BID 2>/dev/null || true
  sleep 1
  xcrun simctl spawn "$D" launchctl kill 9 system/com.apple.cfprefsd.xpc.daemon >/dev/null 2>&1 || true
  sleep 1
  python3 "$ROOT/scripts/demo_seed.py" "$G" "$L" "$APP"
  xcrun simctl spawn "$D" launchctl kill 9 system/com.apple.cfprefsd.xpc.daemon >/dev/null 2>&1 || true
  sleep 2
}

for L in "$@"; do
 if [ "$DEVICE" = duo-inner ]; then
  seed_live
 else
  boot
  APP=$(xcrun simctl get_app_container "$D" $BID data)
  G=$(xcrun simctl get_app_container "$D" $BID groups | awk -F'\t' '$1=="group.com.Ysoup.TokenMemo"{print $2}')
  xcrun simctl terminate "$D" $BID 2>/dev/null || true
  # 기기 언어 · 지역은 **끄기 전에** 적는다. cfprefsd 가 끌 때 디스크에 쓰고, 다음 부팅에 SpringBoard 가 읽는다.
  # 켠 뒤에 적으면 다음 부팅에야 먹어서 상태 막대 날짜가 앞 언어로 찍혔고(예전 pt-BR 그림의 이탈리아어 날짜),
  # 꺼진 동안 파일에 적으면 끌 때 cfprefsd 가 옛 값으로 덮어쓴다.
  # 아이패드 상태 막대의 날짜는 지역을 따른다. 언어만 바꾸면 앞 언어의 날짜가 남는다
  xcrun simctl spawn "$D" defaults write .GlobalPreferences AppleLanguages -array "$L"
  xcrun simctl spawn "$D" defaults write .GlobalPreferences AppleLocale "$(echo "$L" | tr '-' '_')"
  # ⚠️ 앱 그룹 UserDefaults 는 **기기를 끈 상태에서** 써야 한다(scripts/demo_setup.sh 머리말).
  xcrun simctl shutdown "$D"
  # 'Booted' 가 아니라고 다 꺼진 것이 아니다. 'Shutting Down' 중에 boot 하면 거절된다
  until xcrun simctl list devices | grep -q "$D) (Shutdown)"; do sleep 1; done
  python3 "$ROOT/scripts/demo_seed.py" "$G" "$L" "$APP"
  boot
  sleep 6
 fi
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
      -defaultSamplesInserted_v1 YES -demoSampleOfferResolved_v1 YES \
      -tutorialFirstUseMemoId.v1 "" -tutorial.combo.step.v1 "" -pasteTipDismissed YES \
      -AppleKeyboards '("com.Ysoup.TokenMemo.ClipKeyboardExtension")' >/dev/null
    # 펼친 화면은 장면 연출이 늦게 끝난다. 9초면 1장(답장)이 템플릿을 고르는 중에 찍혔다
    if [ "$DEVICE" = duo-inner ]; then sleep 15; else sleep 9; fi
    # 듀오는 화면이 둘이다. 1번이 바깥 화면(1398x2034), 3번이 안쪽(접혀 있으면 검다)
    # 손으로 튜토리얼을 하다 만 기기는 가리키던 단축어가 남아 파란 안내 띠가 찍힌다. 위 두 인자가 비운다
    DISPLAY_ARG=""
    [ "$DEVICE" = duo ] && DISPLAY_ARG="--display=1"
    [ "$DEVICE" = duo-inner ] && DISPLAY_ARG="--display=3"
    xcrun simctl io "$D" screenshot --type=png $DISPLAY_ARG "$OUT/tmp.png" >/dev/null 2>&1
    if [ "$DEVICE" = iphone ]; then
      ffmpeg -loglevel error -y -i "$OUT/tmp.png" -vf "scale=1242:2699,crop=1242:2688" "$OUT/$1"
    elif [ "$DEVICE" = duo ] || [ "$DEVICE" = duo-inner ]; then
      # 아이폰 듀오는 시뮬레이터 그대로가 제출 규격이다(바깥 1398x2034, 안쪽 2007x2853 · 가로 2853x2007).
      mv "$OUT/tmp.png" "$OUT/$1"
    else
      ffmpeg -loglevel error -y -i "$OUT/tmp.png" -vf "scale=2064:2752" "$OUT/$1"
    fi
    rm -f "$OUT/tmp.png"
    echo "  $L $1"
  }
  # 1 · 2장은 미리보기 영상과 같은 이야기다: 부탁받고 템플릿으로 답하기, 복사해 둔 것 꺼내기
  shot 01-reply.png                keyboard reply
  shot 02-recent-clips.png         keyboard recent
  shot 03-template-fill.png        keyboard template
  shot 04-snippet-stack.png        list     stack
  shot 05-all-snippets.png         list     none
done
