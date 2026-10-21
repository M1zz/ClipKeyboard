#!/bin/sh
# Product Hunt 갤러리 원본을 찍는다. scripts/take_screenshots.sh 와 같은 길에 자판 설정만 더했다.
#
#   sh marketing/global/producthunt/capture.sh <UDID> <앱 언어> <판 typing|snippets> <자판 언어> <켜 둘 자판 언어들> <첫 탭 keyboard|list> <장면> <파일>
#   예) sh marketing/global/producthunt/capture.sh <UDID> en typing de "en,de" keyboard none typing-de.png
#       sh marketing/global/producthunt/capture.sh <UDID> en snippets en en keyboard reply snippets-reply.png
#
# 앞서 디버그 빌드를 깔아 둔다(docs/screenshots/README.md ▸ 다시 만들기). 찍은 뒤 sips 로 폭 990 으로 줄여 raw/ 에 둔다.
# 지금 raw/ 는 iPhone 17 Pro Max · iOS 27.0 시뮬레이터, 5.1.13 디버그 빌드로 2026-10-21 에 찍었다.
set -e
D=$1; shift
L=$1; MODE=$2; CUR=$3; LANGS=$4; STYLE=$5; SCENE=$6; OUT=$7
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
RAWDIR="$(cd "$(dirname "$0")" && pwd)/raw"
BID=com.Ysoup.TokenMemo
boot() { xcrun simctl boot "$D" 2>/dev/null || true; xcrun simctl bootstatus "$D" -b >/dev/null 2>&1 || true; }
boot
APP=$(xcrun simctl get_app_container "$D" $BID data)
G=$(xcrun simctl get_app_container "$D" $BID groups | awk -F'\t' '$1=="group.com.Ysoup.TokenMemo"{print $2}')
xcrun simctl terminate "$D" $BID 2>/dev/null || true
xcrun simctl spawn "$D" defaults write .GlobalPreferences AppleLanguages -array "$L"
xcrun simctl spawn "$D" defaults write .GlobalPreferences AppleLocale "$(echo "$L" | tr '-' '_')"
xcrun simctl shutdown "$D"
until xcrun simctl list devices | grep -q "$D) (Shutdown)"; do sleep 1; done
python3 "$ROOT/scripts/demo_seed.py" "$G" "$L" "$APP" >/dev/null
P="$G/Library/Preferences/group.com.Ysoup.TokenMemo.plist"
python3 -c "
import plistlib,sys
p,m,c,l=sys.argv[1:]
d=plistlib.load(open(p,'rb'))
d['keyboardInputMode.v1']=m; d['keyboardTypingCurrent.v1']=c; d['keyboardTypingLanguages.v1']=l
plistlib.dump(d,open(p,'wb'))" "$P" "$MODE" "$CUR" "$LANGS"
boot
sleep 6
xcrun simctl ui "$D" appearance light
xcrun simctl status_bar "$D" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true
xcrun simctl launch "$D" $BID -AppleLanguages "($L)" -AppleLocale "$L" \
  -snippetsTabStyle.v1 "$STYLE" -ScreenshotScene "$SCENE" \
  -startedFresh.v444 NO -firstShortcut.done.v1 YES -tutorialChaptersDone.v1 YES \
  -keyboardStageOffered.v1 YES -didYouKnow.optOut.v1 YES -ghostSuggestionsOff_v1 YES \
  -defaultSamplesInserted_v1 YES -demoSampleOfferResolved_v1 YES \
  -AppleKeyboards '("com.Ysoup.TokenMemo.ClipKeyboardExtension")' >/dev/null
sleep 10
xcrun simctl io "$D" screenshot --type=png "$RAWDIR/$OUT" >/dev/null 2>&1
echo "shot $OUT"
