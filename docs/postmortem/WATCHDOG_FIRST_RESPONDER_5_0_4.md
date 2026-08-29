# 5.0.4 워치독 종료: 포커스가 뷰 그래프를 다시 부르고, 그 갱신이 다시 포커스를 바꿨다

2026-08-28 ~ 08-29 · 이틀에 15건 · 5.0.4 · **0x8BADF00D**

`docs/postmortem/WATCHDOG_SHARE_VIDEO_5_0_4.md` 를 먼저 썼는데, **그 진단은 빗나갔다.**
이 문서가 그걸 바로잡는다.

## 심볼이 붙은 한 건

리포트 15건 중 딱 하나가 iPhone16,2 · **26.5.2(23F84)** 였고, 그 심볼이 로컬에 있었다.
근사치가 아니다. 리포트의 `0AB507CF` 가 캐시의 `libobjc.A.dylib` 와 **UUID 가 정확히
일치**했으므로 나머지 셋도 같은 심볼셋으로 확정할 수 있었다.

| 바이너리 | 정체 |
| --- | --- |
| `0AB507CF` | libobjc.A.dylib |
| `A5CD9C54` | SwiftUI |
| `B688BC17` | SwiftUICore |
| `9EE8C19A` | UIKitCore |

```
-[UIResponder _setFirstResponder:]  ↔  -[UIView _setFirstResponder:]   (반복)
  → @objc _UIHostingView._didChange(toFirstResponder:)
  → _UIHostingView._didChange(toFirstResponder:)
  → ViewGraphRootValueUpdater.responderNode.getter
  → ViewGraphRootValueUpdater._updateViewGraph<A>(body:)
  → ViewGraphRootValueUpdater.updateGraph()
  → closure #1 in ViewGraphRootValueUpdater.updateGraph()
  → _UIHostingView.updateTransform()
  → objc_retain
```

⚠️ **크래시 리포트의 프레임은 잎부터 나열된다.** hang 리포트는 뿌리(`dyld start`)부터인데
크래시는 반대다. `objc_retain` 이 첫 줄에 있는 것이 그 증거다. 뿌리일 수 없는 함수다.

읽으면 이렇다. **입력 포커스가 바뀌자 SwiftUI 가 뷰 그래프를 통째로 다시 계산했다.**

## 우리 코드의 고리

`ClipKeyboard/Screens/Memo/HighlightedTextEditor.swift`

```swift
func updateUIView(_ uiView: UITextView, context: Context) {
    ...
    if isFocused && !uiView.isFirstResponder {
        uiView.becomeFirstResponder()          // ← 갱신 도중에, 그 자리에서
    } else if !isFocused && uiView.isFirstResponder {
        uiView.resignFirstResponder()
    }
}

func textViewDidBeginEditing(_ textView: UITextView) {
    parent.isFocused = true                     // ← @Binding 쓰기 = 상태 변경
}
```

닫히는 고리는 이렇다.

```
updateUIView
  → becomeFirstResponder()          동기 호출
    → textViewDidBeginEditing       그 자리에서 불린다
      → parent.isFocused = true     뷰를 그리는 도중에 상태를 바꾼다
        → _UIHostingView._didChange(toFirstResponder:)
          → ViewGraphRootValueUpdater.updateGraph()      ← 확정된 프레임
            → updateUIView          다시 여기로
```

`becomeFirstResponder()` 는 값을 대입하는 것처럼 생겼지만 **응답자 사슬을 타고 올라가며
호스팅 뷰에 알림을 뿌리는 일**이고, SwiftUI 는 그 알림을 뷰 그래프 갱신으로 받는다.
갱신 도중에 그걸 부르면 갱신이 갱신을 부른다.

## 고친 것

### 1. 갱신 밖으로 내보냈다

`Coordinator.syncFocus(_:desired:)` 를 두고 한 박자 미뤄서 바꾼다. 그러면
`textViewDidBeginEditing` 이 `updateUIView` 바깥에서 불리므로 "그리는 도중의 상태 변경"
이 아니게 된다.

### 2. 되쓰지 않는다

우리가 스스로 옮기는 중이면(`isSyncingFocus`) 델리게이트가 바인딩에 되쓰지 않는다.
같은 값이면 아예 쓰지 않는다. 같은 값을 다시 쓰는 것만으로도 갱신이 한 바퀴 더 돈다.

### 3. 시험 (`ClipKeyboardTests/FocusUpdateLoopTests.swift`)

값이 아니라 **시점**을 지킨다. 부른 자리에서 바뀌지 않는가, 한 박자 뒤에는 실제로
바뀌는가(미루기만 하고 안 하면 키보드가 안 올라온다).

옛 코드로 되돌려 놓고 돌려 확인했다. 네 개 중 두 개가 실패한다.

## 확정과 정황의 경계

**확정**: 심볼이 붙은 한 건은 포커스 변경이 뷰 그래프 갱신을 부른 자리에서 죽었다.
`HighlightedTextEditor` 가 그 고리를 닫고 있었다는 것도 코드로 확인된다.

**정황**: 나머지 14건도 같은 것인지. 근거는 세 가지다.
1. 앱 CPU 가 허용 시간과 거의 같다(10초에 9.0~9.7, 5초에 4.7~4.9). 전부 태우고 있었다
2. 여러 건에서 **같은 오프셋 쌍이 번갈아 반복**된다(재귀). 예: 8/29 02:04 은 `5824364`
   하나가 계속 반복된다
3. 서로 다른 리포트가 **같은 오프셋 열**을 공유한다.
   `E47D2D7D 5242832 → FEB88855 51476 → 59212 → E47D2D7D 544832 → 120732` 이 8/28 20:56 ·
   8/28 17:23 · 8/29 09:11 에 똑같이 나온다

**못 본 것**: 앱 프레임. 이유는 아래.

## 왜 앱 프레임을 못 봤나 (우리가 자르고 있었다)

`LeeoKit/Sources/LeeoKit/Diagnostics/LeeoDiagnostics.swift`

```swift
private static let maxStackLength = 4000
return String(text.prefix(maxStackLength))
```

MetricKit 의 `jsonRepresentation()` 은 **들여쓰기가 붙은 pretty-print JSON** 이라 프레임이
깊어질수록 한 프레임이 잡아먹는 글자 수가 늘어난다. 4000자면 **13~16 프레임**에서 끊긴다.
받은 15건이 전부 그 지점에서 잘려 있었다.

크래시 스택은 잎부터 나열되므로, **잘려 나간 뒤쪽이 정확히 앱 코드가 있는 자리**다.
검증도 된다. 15건은 모두 같은 5.0.4 인데 **서로 다른 OS 빌드 사이에 공유되는 바이너리가
하나도 없다.** 앱 바이너리라면 OS 와 무관하게 같은 UUID 로 여러 리포트에 나타나야 한다.

Organizer 에는 아무것도 없다. 그건 정상이다. 이 리포트는 Organizer 것이 아니라 우리가
MetricKit 으로 직접 모아 CloudKit 에 올린 것이고, 원본은 어디에도 남지 않는다.
**받은 시점에 이미 잘린 문자열 하나뿐이다.**

### 아직 안 고침

프레임을 납작하게(`UUID+오프셋` 한 줄씩) 적으면 같은 4000자에 80~100 프레임이 들어간다.
앱 바이너리 UUID 도 함께 저장하면 어느 프레임이 우리 코드인지 즉시 갈린다.
LeeoKit 수정 → 3.3.1 태그 → 의존성 올리기가 따라온다. → `todo.md`

## 다음에 같은 것이 오면

1. `RBSTerminateContext` 를 먼저 읽는다. 앱 CPU 가 허용 시간에 가까우면 **태운 것**,
   0에 가까우면 **기다린 것**이다. 이 15건은 전부 태운 쪽이었다
2. 크래시 스택은 **잎부터** 나열된다. hang 은 뿌리부터다. 헷갈리면 첫 프레임을 본다.
   `objc_retain` 같은 게 첫 줄이면 잎부터인 것이다
3. 리포트에 나온 UUID 를 **OS 빌드별로 묶어 본다.** 여러 OS 에 걸쳐 나타나는 UUID 가
   앱이다. 하나도 없으면 앱 프레임이 안 담긴 것이니 스택을 더 받아야 한다
4. `~/Library/Developer/Xcode/iOS DeviceSupport/<기기> <버전>/Symbols` 에 같은 OS 빌드가
   있으면 `dwarfdump --uuid` 로 전수 매핑해 `atos` 로 붙인다. 정확히 일치하는 UUID 가
   하나라도 있으면 그 심볼셋 전체를 믿어도 된다
