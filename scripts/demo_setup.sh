#!/bin/sh
# 언어를 바꾸고 데이터를 심은 뒤 목록 화면까지 띄운다.
#
# ⚠️ 앱 그룹의 UserDefaults(빈칸에 저장해 둔 값)는 **기기를 끈 상태에서** 써야 한다.
#    켜져 있으면 cfprefsd 가 메모리에 든 옛 값을 도로 덮어쓴다.
#    `simctl spawn defaults write group.…` 도 소용없다. 그 쪽은 그룹 컨테이너가 아니라
#    시뮬레이터 홈의 Preferences 에 쓴다.
D=27D95C0F-7136-4813-B4A8-71B22249B3BA
G=/Users/hyunholee/Library/Developer/CoreSimulator/Devices/$D/data/Containers/Shared/AppGroup/474EA4A3-A1D6-4279-A489-03AC33B0AF1F
L="$1"
APP=$(xcrun simctl get_app_container $D com.Ysoup.TokenMemo data 2>/dev/null)
xcrun simctl shutdown $D 2>/dev/null
until ! xcrun simctl list devices | grep -q "$D) (Booted)"; do sleep 1; done
python3 scripts/demo_seed.py "$G" "$L" "$APP" || exit 1
xcrun simctl boot $D 2>/dev/null
until xcrun simctl list devices | grep -q "$D) (Booted)"; do sleep 2; done
sleep 6
xcrun simctl spawn $D defaults write .GlobalPreferences AppleLanguages -array "$L" 2>/dev/null
xcrun simctl spawn $D defaults write com.Ysoup.TokenMemo snippetsTabStyle.v1 -string list 2>/dev/null
xcrun simctl launch $D com.Ysoup.TokenMemo -AppleLanguages "($L)" >/dev/null 2>&1
sleep 4
xcrun simctl status_bar $D override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 >/dev/null 2>&1
mkdir -p "/Users/hyunholee/Documents/workspace/Auto/클립키보드/docs/marketing/screenshots/$L"
echo "준비됨 $L"
