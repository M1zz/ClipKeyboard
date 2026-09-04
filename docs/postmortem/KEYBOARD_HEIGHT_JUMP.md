# 키보드가 뜰 때 높이가 팍 튀던 이야기

두 가지 불평이 있었다. "우리 키보드가 기본 키보드와 높이가 안 맞아 위화감이 든다",
그리고 "뜰 때 높이가 팍 튀어서 버그처럼 보인다". **뿌리가 하나였다.**

## 원인

`ClipKeyboardExtension/KeyboardViewController.swift`

```swift
private func setupHeightConstraint() {
    let keyboardHeight: CGFloat = 254  // SwiftUI 영역(200) + 하단 바(54)
    let heightConstraint = view.heightAnchor.constraint(equalToConstant: keyboardHeight)
    heightConstraint.priority = .defaultHigh   // 750
    heightConstraint.isActive = true
}
```

### ① 254 라는 숫자에 근거가 없었다

주석은 "SwiftUI 영역(200) + 하단 바(54)" 라고 설명한다. 그런데 그 **하단 UIKit 바는 이미
없어졌다.** 바로 아래 `setupHostingController` 에 "하단 UIKit 바 제거됨" 이라고 적혀 있고,
SwiftUI 뷰를 상하좌우에 붙인다. 사라진 바의 54pt 가 상수 안에 그대로 남아 있었다.

기기마다 다른 진짜 키보드 높이와 어긋난 만큼이 위화감이었다.

### ② 회전을 보지 않았다

`viewWillTransition` 도 `traitCollectionDidChange` 도 없어서 가로에서도 254 를 썼다.
가로 시스템 키보드는 200pt 언저리다. 가로에서의 위화감이 세로보다 컸던 이유다.

### ③ 우선순위가 750 이라 iOS 가 두 번 세웠다

이것이 "팍 튀는" 순간의 정체다.

1. iOS 가 입력 뷰를 **자기 기본 높이로** 한 번 세운다.
2. 다음 레이아웃 패스에서 우리 254 제약이 적용된다.
3. 그 높이 변화를 iOS 가 **애니메이션한다.**

즉 키보드가 뜰 때 **잠깐 올바른 높이를 보여줬다가 우리 숫자로 끌려 내려오고 있었다.**
두 불평이 같은 원인인 이유가 이것이다.

반창고는 이미 붙어 있었다. `viewWillAppear` 의 `view.layoutIfNeeded()` 에
"레이아웃을 미리 계산하여 튀는 현상 방지" 라고 적혀 있었다. 증상은 알고 있었지만
원인이 우선순위라는 것은 못 짚은 상태였다. `viewDidAppear` 에도 같은 호출이 있었는데,
그쪽은 등장 애니메이션이 **끝난 뒤**라 오히려 한 번 더 움찔할 자리였다.

## 고친 것

### 우선순위 999

```swift
constraint.priority = UILayoutPriority(999)
```

첫 레이아웃부터 우리 값으로 선다. 1000(`.required`)이 아닌 이유는 시스템이 입력 뷰에
거는 제약과 충돌해 로그를 더럽히기 때문이다.

그리고 **높이가 실제 시스템 키보드와 같아지면 애니메이션할 차이 자체가 사라진다.**
아래 ②가 ③을 마저 없앤다.

### 시스템 키보드 높이를 앱이 재서 알려준다

익스텐션에는 시스템 키보드 높이를 물어볼 API 가 **없다.** 그래서 길은 하나뿐이다.

메인 앱은 시스템 키보드를 띄울 수 있다. 앱에서 `keyboardWillShowNotification` 이 올 때
높이를 재서 App Group 에 적어 두면, 익스텐션이 그대로 읽는다. 예측 입력 줄을 켰는지
같은 그 사람의 설정까지 저절로 반영된다.

`ClipKeyboard/Service/KeyboardHeightBook.swift` (앱·익스텐션 양쪽 타겟)

- 화면키는 `"393x852-P"` 처럼 **크기와 방향**을 함께 담는다. 한 칸을 나눠 쓰면
  회전할 때마다 서로의 값을 덮어쓴다.
- 적는 쪽은 **앱뿐이다.** 익스텐션이 적으면 자기 높이를 정답으로 삼는 고리가 생긴다.
- 믿을 수 없는 측정은 **안 적는다.** 틀린 값이 장부에 굳으면 어림값으로도 못 돌아간다.
  - 하드웨어 키보드가 붙었을 때의 단축 바(55pt 안팎)
  - 아이패드의 떠 있는 키보드(화면 너비를 다 안 씀)
  - 화면의 20% 미만 / 60% 초과

### 잰 적 없을 때의 어림값

앱을 한 번도 안 연 사람에게는 잰 값이 없다. 화면 높이 비율로 어림한다
(세로 0.36, 가로 0.50, 아이패드 0.30, 위아래 울타리). **정답이 아니라 첫 인상용**이고,
앱을 한 번 쓰면 정확해진다.

| 기기 | 세로 어림 | 254 대비 | 가로 어림 | 254 대비 |
|---|---|---|---|---|
| iPhone SE (2·3세대) | 240pt | -14 | 188pt | -66 |
| iPhone 13 mini | 292pt | +38 | 188pt | -66 |
| iPhone 15 / 16 | 307pt | +53 | 196pt | -58 |
| iPhone 17 Pro | 315pt | +61 | 201pt | -53 |
| iPhone Pro Max | 336pt | +82 | 215pt | -39 |
| iPad 11" | 358pt | +104 | 260pt | +6 |

세로에서는 **넓어지고**, 가로에서는 **크게 줄어든다.**

### 회전

```swift
override func viewWillTransition(to size: CGSize, with coordinator: ...) {
    coordinator.animate(alongsideTransition: { [weak self] _ in self?.applyHeight() })
}
```

⚠️ 회전 **애니메이션 안에서** 바꾼다. 끝난 뒤에 바꾸면 회전이 멎은 다음 한 번 더
움찔하는데, 그게 정확히 없애려던 그 움직임이다.

## 함께 고친 것: 기본값 불일치

`keyboardButtonHeight` 의 기본값이 **앱은 56.0, 익스텐션은 44.0** 이었다. 같은 App Group
키인데 기본값이 달랐다. 설정을 만진 적 없는 사람은 앱 미리보기와 실제 키보드의 키 높이가
달랐다.

44 로 통일했다. `@AppStorage` 는 기본값을 저장하지 않으므로 **실제로 쓰이고 있던 값이
44** 였고, 앱 쪽 미리보기만 거짓말을 하고 있었다. 이 방향이 아무의 키보드도 바꾸지 않는다.

(바로 옆 `contentHintEnabled` 에는 "⚠️ 기본값은 앱과 **같아야** 한다" 고 이미 적혀 있다.
같은 함정을 두 번 밟았다.)

## 시험

`ClipKeyboardTests/KeyboardHeightBookTests.swift` 12건.

이 화면은 눈으로만 확인되는 종류라 시험이 특히 중요하다. 잘못된 높이는 크래시가 아니라
**위화감**으로 나타나서, 빌드가 초록이어도 아무도 모른 채 배포된다. 실제로 254 가
그렇게 오래 남아 있었다.

## 아직 확인 못 한 것

- **실기기 눈확인.** 시뮬레이터에서는 소프트웨어 키보드가 뜨지 않아(텍스트 필드가
  first responder 가 돼도 `keyboardWillShow` 가 오지 않는다) 실제 높이를 못 쟀고,
  튐이 사라졌는지도 눈으로 못 봤다.
- **가로에서 콘텐츠가 들어가는지.** 가로 높이가 254 → 190~215 로 줄어든다.
  카테고리 줄 + 메모 격자 + 하단 키 줄이 그 안에 들어가는지 봐야 한다.
