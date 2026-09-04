# 5.0.6 키보드: 시스템이 우리 뷰 밖에 그리는 줄을 몰랐다

iOS 26 · iPhone 17 Pro. 두 가지가 한꺼번에 눈에 걸렸다.

- 우리 키보드가 시스템 키보드보다 **89pt 높게** 섰다
- 키보드 판과 그 아래 지구본 줄의 **배경색이 갈려** 이음매가 한 줄 그어진 것처럼 보였다

뿌리는 하나다. **iOS 26 은 지구본·받아쓰기 줄을 우리 뷰 바깥에 직접 그린다.**

## 무엇이 달라졌나

예전에는 서드파티 키보드가 지구본을 스스로 그렸다. iOS 26 은 시스템이 그린다.
그 증거가 코드에 그대로 있다.

```
needsInputModeSwitchKey = false      ← 우리가 지구본을 그릴 필요가 없다는 뜻
view.safeAreaInsets     = (0,0,0,0)  ← 그런데 그 줄의 자리는 알려 주지 않는다
```

그래서 이런 모양이 된다.

```
┌──────────────────────────┐  ← 키보드 영역 시작
│  시스템이 그리는 위 여백      │  13pt
├──────────────────────────┤
│                          │
│   우리 입력 뷰 (view)      │  우리가 높이를 정하는 유일한 부분
│                          │
├──────────────────────────┤
│  🌐  시스템이 그리는 줄  🎤  │  40pt
│  홈 인디케이터 자리          │  34pt
└──────────────────────────┘  ← 화면 바닥
```

`KeyboardHeightBook` 은 **키보드 전체 높이**를 적어 두는 장부인데, 익스텐션이 그 값을
그대로 `view.heightAnchor` 에 걸고 있었다. 시스템 몫 87pt 가 그 위에 얹히니 전체가
그만큼 높아진다. 5.0.5 에서 고정값 254 를 장부값으로 바꾼 것 자체는 옳았고,
**그래서 오히려 더 높아졌다**(254 시절엔 28pt 초과, 장부 시절엔 89pt 초과).

## 실측

시뮬레이터(iPhone 17 Pro · iOS 26.0.1)에서 사파리 주소창의 y 좌표로 잤다.
주소창은 키보드 바로 위에 붙는 입력 보조 뷰라, 그 위치가 곧 키보드 높이다.

| 우리 뷰에 건 높이 | 키보드 전체 | 차이 |
| --- | --- | --- |
| 314.6 (5.0.5 코드) | 399.7 | **85.1** |
| 268 (제약을 아예 안 걸었을 때 iOS 기본) | 353.0 | **85.0** |
| 시스템 키보드 | 311.0 | - |

우리가 무엇을 걸든 차이가 85pt 로 같다. **우리 뷰 밖의 상수**라는 뜻이다.

색은 픽셀로 확인했다.

| 자리 | 고치기 전 | 시스템 키보드 |
| --- | --- | --- |
| 우리 판 | `#F2F2F3` (테마 `bg`, 불투명) | - |
| 시스템이 그리는 줄 | `#DEDFE5` (반투명 재질) | `#DEDFE5` |

카톡처럼 배경이 푸른 앱에서는 그 줄이 뒤 앱 색(`#BFCEDA`)을 그대로 받아 가서,
회백색 판과의 대비가 더 커졌다. 사용자가 "부자연스럽다"고 한 것이 이것이다.

## 고친 것

### ① 높이 - 시스템 몫을 빼고 요구한다

`ClipKeyboard/Service/KeyboardHeightBook.swift`

```swift
static func totalHeight(for size: CGSize) -> CGFloat   // 키보드 전체 (예전 height)
static func height(for size: CGSize) -> CGFloat        // 우리 판만 = 전체 - systemChrome
static func systemChrome(for size: CGSize) -> CGFloat  // iOS 26+ 에서 85 (세로)
```

울타리로 `minimumContentHeight`(150pt)를 둔다. 상수가 빗나가도 **쓸 수 없는 키보드**가
되지는 않게 한다.

### ② 배경 - 시스템 재질을 우리 판 뒤에 깐다

`UIInputView(inputViewStyle: .keyboard)` 가 그 재질을 그려 주는 유일한 공개 API 다.
그것을 맨 뒤에 깔고(`KeyboardViewController.setupSystemBackdrop`), SwiftUI 루트 배경은
익스텐션에서 투명으로 둔다(`KeyboardView.backgroundColor`).

⚠️ 앱 안의 무대(`hostKind == .inApp`)에는 그 재질이 없으므로 예전대로 테마 색을 칠한다.
⚠️ 키보드 색을 직접 고른 사람은 그 색이 이긴다. 고른 것을 안 보여 주면 그건 고장이다.

## 고친 뒤

같은 방법으로 다시 쟀다.

| | 키보드 전체 | 판 배경 |
| --- | --- | --- |
| 시스템 키보드 | 298pt | `#DEDFE5` |
| 우리 키보드 | 302pt | `#DEDFE5` (판 위아래 한 색, 이음매 없음) |

89pt 차이가 4pt 로 줄었다. 남은 4pt 는 아직 실측값이 없어 어림값(0.36 비율)을 쓰기
때문이고, 앱을 한 번 열어 장부가 채워지면 사라진다.

## 시뮬레이터에서 우리 키보드를 띄우는 법

익스텐션은 호스트 앱이 있어야 뜬다. 그리고 **시뮬레이터에는 서드파티 키보드를 켜는
설정 화면이 없다** - App Group 이 아니라 전역 환경설정을 직접 써야 한다.

```sh
D=<시뮬레이터 UDID>
xcrun simctl install $D <경로>/ClipKeyboard.app

# 우리 키보드만 남기면 지구본을 누를 필요 없이 바로 뜬다
xcrun simctl spawn $D defaults write .GlobalPreferences AppleKeyboards \
  -array "com.Ysoup.TokenMemo.ClipKeyboardExtension"
xcrun simctl spawn $D launchctl stop com.apple.SpringBoard   # 반드시 재시작

# 하드웨어 키보드가 붙어 있으면 소프트웨어 키보드가 안 뜬다
# Simulator 메뉴 I/O > Keyboard > Connect Hardware Keyboard 를 끈다 (⇧⌘K)

xcrun simctl openurl $D "https://example.com"   # 사파리 주소창을 호스트로 쓴다
```

탭은 `cliclick` 으로 넣는다. Simulator 창 위치를 매번 다시 읽어 기기 좌표로 환산할 것
(창은 기기 화면보다 가로 8pt · 세로 6pt 크다).

```sh
POS=$(osascript -e 'tell application "System Events" to tell process "Simulator" \
      to get {position, size} of window 1')
# 원점 = (창x + (창너비-화면너비)/2, 창y + (창높이-화면높이)/2)
cliclick m:$X,$Y w:150 dd:$X,$Y w:80 du:$X,$Y
```

높이를 잴 때는 화면을 찍어 **주소창(흰 캡슐)의 y 좌표**를 비교한다. 색은 같은 그림에서
`x=8` 열을 훑어 띠의 경계를 찾는다. 두 방법 다 `PIL` 몇 줄이면 된다.

## 아직 확인 못 한 것

- **가로와 아이패드의 시스템 몫.** 세로 85pt 만 실측했다. 가로는 홈 인디케이터가
  34 → 21pt 로 줄어드는 만큼을 빼 72pt 로 잡았고, 아이패드는 세로값을 그대로 썼다.
  둘 다 **추정**이다. 위 방법으로 재서 `KeyboardHeightBook` 의 상수를 고치면 된다.
- **실기기.** 시뮬레이터에서만 봤다. 다만 사용자가 보낸 실기기 스크린샷의 픽셀 비율이
  시뮬레이터 측정과 일치했다(우리 판 35.6% · 시스템 몫 11% · 전체 46.6%).
- **iOS 25 이하.** `systemDrawsKeyboardChrome` 이 false 라 예전 그대로 동작하지만,
  구버전 기기로 눈확인은 안 했다.
