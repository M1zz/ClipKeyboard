# 제어센터 컨트롤이 앱을 못 여는 문제, 트러블슈팅 기록 (iOS 26)

> 2026-07-07 해결. 제어센터의 커스텀 컨트롤(ControlWidget) 버튼을 탭해도
> 앱이 열리지 않던 문제의 원인 분석과 해결 과정 전체 기록.

## TL;DR, 정답 두 가지

**1. iOS 26 SDK에서 `openAppWhenRun`은 deprecated. `supportedModes`로 대체해야 한다.**

```swift
// ❌ iOS 26 SDK로 빌드하면 무시됨 (구 SDK 빌드에서만 호환 동작)
static var openAppWhenRun: Bool = true

// ✅ iOS 26 방식
static var supportedModes: IntentModes { .foreground }
```

SDK swiftinterface에 명시돼 있다:
```
@available(iOS, deprecated: 26.0, message: "Please provide 'supportedModes' instead")
```

**2. 포그라운드 모드 인텐트는 "메인 앱 프로세스"에서 실행된다. 같은 타입이 앱 타겟에도 있어야 한다.**

컨트롤 인텐트를 위젯 익스텐션 타겟에만 두면, 시스템이 포그라운드 실행 대상을
찾지 못해 **탭이 조용히 무시된다** (에러도, 로그도 없음). 인터랙티브 위젯(iOS 17)
버튼 인텐트를 앱+익스텐션 양쪽 타겟에 포함시키는 관행과 같은 원리다.

- 위젯 측: `widget/QuickNoteControl.swift`, `AddQuickNoteControlIntent` (컨트롤 UI가 참조)
- 앱 측: `ClipKeyboard/QuickNoteControlIntent.swift`: **동일 타입명**, 실제로 실행되는 쪽
- 두 정의의 타입명·supportedModes·동작을 항상 일치시킬 것

화면 라우팅은 인텐트가 App Group 보류 플래그(`pendingQuickNoteAdd`)를 켜고
`.openQuickNoteAdd` 알림을 쏘면, `ClipKeyboardList`가 onAppear/didBecomeActive에서
소비해 빠른 메모 입력 시트를 띄운다 (양쪽 다 도착해도 Bool이라 멱등).

## 증상 매트릭스 (실기기 iPhone 16/16 Plus, iOS 26.5)

| 시도 | 결과 | 사후 해석 |
|---|---|---|
| 토글형(SetValueIntent, 백그라운드) | ✅ 동작 | 익스텐션 인텐트 실행은 정상 |
| `openAppWhenRun`만 | ❌ 무반응 | 포그라운드 실행 대상(앱 타겟 인텐트) 없음 |
| `OpenURLIntent`만 반환 | ⚠️ 앱이 떴다가 즉시 닫힘 | 백그라운드 인텐트가 URL을 열지만 시스템이 포그라운드 전환을 회수 |
| `OpenIntent`(공식 샘플) | ❌ 무반응 | 위와 동일, 앱 타겟에 타입 없음 |
| `supportedModes(.foreground)` (위젯 타겟만) | ❌ 무반응 | 위와 동일 |
| **`supportedModes` + 앱 타겟에 동일 인텐트** | ✅ **동작** | 정답 |
| 홈/잠금화면 위젯 `widgetURL` 탭 | ✅ 동작 | 컨트롤과 다른 경로 (항상 안정적) |
| 타사 앱 컨트롤 | ✅ 동작 | 구 SDK 빌드라 openAppWhenRun 호환 동작 |

핵심 추론 포인트: "**인텐트는 실행되는데(토글 OK) 포그라운드 선언한 것만 전부 무반응**"
→ 포그라운드 인텐트는 실행 주체가 다르다(앱 프로세스) → 앱 타겟에 타입이 없어서 실패.

## 디버깅을 방해했던 함정들

1. **죽은 컨트롤 캐시**: 인텐트 타입명을 바꾸면서 컨트롤 kind를 재사용하면,
   이미 추가된 버튼이 옛 인텐트를 참조한 채 죽는다. 인텐트 시그니처가 바뀌면
   **kind도 새 문자열로** 올리고, 사용자는 컨트롤을 제거 후 재추가해야 한다.
   앱 런치 시 `ControlCenter.shared.reloadAllControls()` 호출로 재등록을 돕는다.
2. **시뮬레이터 제어센터는 신뢰 불가**, 컨트롤 검증은 반드시 실기기에서.
3. **익스텐션의 print는 Console.app에 안 잡힌다**, `os.Logger` +
   subsystem(`com.Ysoup.TokenMemo.widget`) 필터로 확인할 것.
4. Debug/Release, 멀티 씬 설정, URL 스킴 등록 여부는 이 문제와 무관했다
   (모두 검증 후 배제).

## Xcode 없이 쓸 수 있는 진단 도구

```bash
# 실기기 설치·실행 (Xcode 안 띄우고)
xcodebuild -scheme ClipKeyboard -destination 'generic/platform=iOS' -configuration Release build -allowProvisioningUpdates
xcrun devicectl list devices
xcrun devicectl device install app --device <UDID> <path>/ClipKeyboard.app
xcrun devicectl device process launch --terminate-existing --device <UDID> com.Ysoup.TokenMemo

# 인텐트가 번들에 실제로 등록됐는지 검증 (앱/익스텐션 각각)
python3 -c "import json; d=json.load(open('<App>.app/Metadata.appintents/extract.actionsdata')); print(list(d['actions'].keys()))"
# → 앱 타겟 결과에 컨트롤 인텐트가 반드시 포함돼야 한다

# supportedModes/openAppWhenRun 반영 확인
# actions.<IntentName> 에 'supportedModes': 2 (= foreground) 가 있어야 함
```

**인텐트 실행 여부 판정 (로그 없이)**: 컨트롤 탭 → 앱을 손으로 열기 →
빠른 메모 시트가 뜨면 인텐트는 실행된 것(플래그가 쓰임), 안 뜨면 실행 자체가 안 된 것.

**토글 컨트롤 트릭**: `ControlWidgetToggle` + `SetValueIntent` 테스트 컨트롤을 만들면
"인텐트가 실행되는가"를 앱 열기와 무관하게 눈으로 확인할 수 있다
(탭 → 토글 유지 = 실행 OK). 이 트릭으로 문제를 "앱 열기 단계"로 좁혔다.

## 최종 구조

```
widget/QuickNoteControl.swift        # 컨트롤 UI + 인텐트(위젯 측 정의)
ClipKeyboard/QuickNoteControlIntent.swift  # 동일 인텐트(앱 측, 실제 실행됨)
widget/QuickNoteControl.swift 내 QuickNoteLockWidget  # 잠금화면/홈 위젯 (widgetURL 경로)
ClipKeyboardList.consumePendingInboxOpen()  # 플래그 소비 → 시트 표시
ClipKeyboardApp: ControlCenter.shared.reloadAllControls()  # 런치 시 컨트롤 재등록
```

진입점 요약:
- **제어센터 컨트롤 "Quick Note"** (iOS 18+): supportedModes 방식
- **잠금화면/홈 위젯 "빠른 메모"**: widgetURL 방식 (컨트롤 문제와 무관하게 항상 동작)
- **Shortcuts/Siri/액션 버튼**: `QuickNoteAppIntents.swift` (백그라운드 캡처 + 보관함 열기)
