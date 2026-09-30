# 키보드가 뜰 때 needsInputModeSwitchKey 에서 죽음

2026-09-29. 허브 "신호 ExtensionFoundation" 25건(5.0.7 ~ 5.1.5, iPhone 15 가 절반, iPad 포함).

## 콜스택 (iOS 26.5 심볼로 되돌림, 잎 쪽)

```
-[UIViewController _setViewAppearState:isAnimating:]
  KeyboardViewController.viewWillAppear            (ClipKeyboardExtension +196432 / +196800)
    -[UIInputViewController needsInputModeSwitchKey]
      -[_UITextDocumentInterface needsInputModeSwitchKey]
        -[_UITextDocumentInterface _controllerState]
          ___forwarding___ → doesNotRecognizeSelector → objc_exception_throw → abort
```

## 원인

`viewWillAppear` 에서 `needsInputModeSwitchKey` 를 읽었다. 그 값은 호스트가 보내 주는 문서 상태
(`_controllerState`)에서 나오는데, 뜨기 직전에는 그 상태가 아직 안 와 있을 때가 있다. 그러면
UIKit 안에서 모르는 메시지를 보내 NSException 으로 죽는다. Swift 에서는 잡을 수 없다.

## 고친 것

- `viewWillAppear` 는 전체 접근 여부만 읽는다.
- `needsInputModeSwitchKey` 는 `viewDidAppear` 에서 읽는다. 호스트와 연결이 끝난 뒤다.
- 첫 그림은 지난번에 읽은 값(`DefaultsKey.keyboardNeedsGlobeKey`)으로 그린다. 값이 없으면
  true(전환 수단이 하나 더 보이는 쪽이 없는 쪽보다 낫다). 달라졌을 때만 다시 그린다.
- 앱 안의 키보드(`InAppKeyboardHost`)는 기억에만 두고 적지 않는다. 적으면 진짜 키보드가 그 값을 읽는다.

## 확인할 것

- 다음 버전 이후 이 지문이 다시 올라오는지(허브).
- Face ID 기기에서 새로 설치한 직후 첫 번째로 뜰 때만 지구본이 잠깐 보였다 사라질 수 있다(기본값 true).
