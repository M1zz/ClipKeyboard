# 스토어 스크린샷

DeployBar 가 배포할 때 이 폴더를 읽어 App Store Connect 에 그대로 올린다. 자리는 취향이 아니라 계약이다.

```
raw/<iphone|ipad>/<언어>/01-....png    원본 캡처. 올라가지 않는다
marketing/<스토어 로케일>/01-....png      아이폰 제출본 1242x2688
marketing/<스토어 로케일>/ipad-01-....png 아이패드 제출본 2064x2752
```

- 아이폰과 아이패드가 한 언어 폴더에 같이 있다. DeployBar 가 픽셀로 기기를 가른다.
- 파일 이름 순서가 스토어 순서다.
- 언어 폴더는 스토어 로케일이다(`en-US` · `es-MX` · `de-DE`). 원본은 앱 언어 코드다(`en` · `es` · `de`).
- 확인: `DeployBar --shotplan 클립키보드` 끝이 `뱃지: ✅ 준비됨`.

## 다시 만들기

손으로 몰지 않는다. 화면은 **DEBUG 빌드 전용** 실행 인자 `-ScreenshotScene` 가 연다
(`InAppKeyboardStage` · `ClipKeyboardList` · `ClipKeyboardApp` 의 `#if DEBUG` 블록). 출시 빌드에는 없다.

```sh
# 1) 디버그 빌드를 두 시뮬레이터에 깐다
xcodebuild -project ClipKeyboard.xcodeproj -scheme ClipKeyboard -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/clipkb-dd build
xcrun simctl install <아이폰 UDID> /tmp/clipkb-dd/Build/Products/Debug-iphonesimulator/ClipKeyboard.app
xcrun simctl install <아이패드 UDID> /tmp/clipkb-dd/Build/Products/Debug-iphonesimulator/ClipKeyboard.app

# 2) 원본 (언어마다 데이터를 심고 다섯 장면을 찍는다)
sh scripts/take_screenshots.sh <아이폰 UDID> iphone ko en zh-Hans zh-Hant ru ja es de th vi
sh scripts/take_screenshots.sh <아이패드 UDID> ipad ko en zh-Hans zh-Hant ru ja es de th vi

# 3) 글과 목업을 입힌 제출본
for L in ko en zh-Hans zh-Hant ru ja es de th vi; do
  python3 scripts/make_marketing_screenshots.py $L iphone
  python3 scripts/make_marketing_screenshots.py $L ipad
done
```

시뮬레이터: iPhone 17 Pro Max(6.9"), iPad Pro 13-inch(M5).
데모 데이터는 `scripts/demo_seed.py`, 헤드라인은 `scripts/make_marketing_screenshots.py` 의 `COPY` 에 언어별로 있다.
헤드라인은 기계번역하지 않는다.

### 장면

| 파일 | 첫 탭 | `-ScreenshotScene` | 무엇 |
| --- | --- | --- | --- |
| 01-keyboard-in-messages | 키보드 | none | 키보드 미리보기 |
| 02-template-fill | 키보드 | template | 템플릿 빈칸 채우기 (저장해 둔 값 3개) |
| 03-snippet-stack | 목록 | stack | 스택 시트 |
| 04-keyboard-size | 목록 | layout | 키보드 레이아웃 설정 |
| 05-all-snippets | 목록 | none | 단축어 목록 |

### 찍히면 안 되는 것과 끄는 법 (`take_screenshots.sh` 가 실행 인자로 넘긴다)

| 무엇 | 인자 |
| --- | --- |
| 첫 실행 안내 · 튜토리얼 | `-startedFresh.v444 NO -firstShortcut.done.v1 YES -tutorialChaptersDone.v1 YES -keyboardStageOffered.v1 YES` |
| "알고 계셨나요" 안내 | `-didYouKnow.optOut.v1 YES` |
| 추천 카드(카드 정보 등) | `-ghostSuggestionsOff_v1 YES` |
| "아직 다른 앱에서는 못 써요" 띠 | `-AppleKeyboards '("com.Ysoup.TokenMemo.ClipKeyboardExtension")'` |
| TipKit 팁 띠 | DEBUG 에서 `-ScreenshotScene` 이 있으면 `Tips.hideAllTipsForTesting()` |
| 런치 안내(의견 요청 · 리뷰 · 새 기능 · 반값 제안 등) | DEBUG 에서 `-ScreenshotScene` 이 있으면 `ClipKeyboardApp` 의 런치 안내 묶음을 건너뛴다. 촬영은 앱을 수십 번 켜서 실행 횟수로 뜨는 안내가 반드시 걸린다 |
| 필수 세 칸 카드("가장 자주 다시 치는 세 가지부터") | DEBUG 에서 `-ScreenshotScene` 이 있으면 `PersonaEssentialsCardContainer` 가 숨는다. 칸 판정 낱말이 ko · en 뿐이라 다른 언어 시연 데이터에서는 덜 찬 것으로 읽힌다 |
| iOS 붙여넣기 허용 창 | DEBUG 에서 `-ScreenshotScene` 이 있으면 목록의 "방금 복사한 것" 읽기와 기록 화면의 자동 읽기를 건너뛴다. 시뮬레이터는 Mac 클립보드를 따라가서 촬영 중 Mac 에서 복사하면 그 순간부터 창이 뜬다 |

⚠️ 아이패드는 'Booted' 로 보여도 한동안 준비가 덜 돼 있어, 그 틈에 `simctl launch` 를 받으면 굳는다. 스크립트가 `simctl bootstatus -b` 로 기다린다.

⚠️ 레이아웃 시트는 가끔 늦게 떠서 목록만 찍힐 때가 있다. 찍은 뒤 언어마다 다섯 장을 눈으로 본다.

예전 자리(`docs/marketing/screenshots/`)는 5.1.2 때 손으로 찍은 다섯 언어 판과 미리보기 영상이다. 지금은 올라가지 않는다.

## 앱 미리보기 영상

검색 결과 첫 칸에 소리 없이 자동 재생된다. 첫 2초에 "누르면 들어간다"가 보여야 하고, 자막만으로 읽혀야 한다.

```
preview/<스토어 로케일>/app-preview.mp4   886x1920 · 16초 남짓 · 무음 AAC · bt709
raw/video/<언어>.mov                      녹화 원본 (커밋하지 않는다)
```

```sh
sh scripts/take_demo_video.sh <아이폰 UDID> ko     # 디버그 빌드가 깔려 있어야 한다
python3 scripts/make_preview_video.py ko
```

앱이 `-ScreenshotScene demo` 로 켜지면 스스로 한 바퀴 돈다(`InAppKeyboardStage.runScreenshotScene`):
계좌번호 넣고 보내기, 빈칸에 두 번째 값을 골라 보내기, '최근' 탭에서 복사한 주소를 꺼내 보내기.
시각이 정해져 있어서 자막을 장면에 맞춰 얹는다. 자막은 `make_preview_video.py` 의 `COPY` 에 언어별로 있다.

⚠️ DeployBar 는 영상을 올리지 않는다. App Store Connect 의 그 언어 페이지에 직접 올리고,
대표 프레임은 템플릿 장면(6초쯤)으로 고른다.
