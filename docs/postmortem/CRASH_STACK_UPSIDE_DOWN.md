# 콜스택을 거꾸로 보내 멈춤 160여 건이 한 이슈로 묶인 이야기

2026-09-29. `CRASH_STACK_TRUNCATION.md` 의 후속이다.

## 증상

허브의 멈춤 이슈 제목이 전부 `ClipKeyboard +991504` 였다.

| 이슈 | 건수 |
| --- | --- |
| 워치독: 종료 지연 | 82 |
| 워치독: 기타 | 78 |
| 워치독: 화면 갱신 지연 | 8 (`+991172`) |

세 이슈 모두 0번이 `dyld +19484`, 1번이 `ClipKeyboard +9915xx` 였다.
키보드의 신호 크래시(25건)도 0번이 dyld, 맨 끝이 `libsystem_kernel` 의 abort 였다.

## 원인

`+991504` 는 앱의 `main` 이다(SwiftUI `App` 진입점). 모든 스택이 **뿌리부터** 적혀 있었다.

`DiagnosticsService.framesByParsing` 은 MetricKit 트리가 "뿌리가 바깥, `subFrames` 가 잎 쪽"
이라고 믿고 편 목록을 뒤집었다. 실제 트리는 반대다. **잎이 바깥**이고 `subFrames` 가 dyld
`start` 쪽으로 들어간다. 옳은 순서를 한 번 더 뒤집은 것이다.

시험도 같은 믿음으로 가짜 페이로드를 만들어서(뿌리를 바깥에 둠) 버그와 함께 통과했다.

허브는 "0번에서 가장 가까운 내 코드 프레임"을 범인으로 잡으니 늘 `main` 이 나왔고,
지문(`앞 6프레임의 바이너리 이름`)도 늘 `dyld>ClipKeyboard>SwiftUI>SwiftUI>SwiftUI>UIKitCore`
로 같았다. 서로 다른 멈춤이 종류별로 한 덩어리가 되어, 무엇이 제일 많이 멈추는지 물을 수 없었다.

## 고친 것

- `DiagnosticsService.leafFirst`: 순서를 **내용으로** 세운다. 뿌리(dyld, libsystem_pthread)가
  앞에만 있으면 뒤집는다. 트리 모양이 iOS 판마다 달라도 0번은 잎이다.
- 시험 페이로드를 실제 모양(잎이 바깥)으로 고치고, 반대 모양도 시험한다.
- FeedbackHubViewer `CrashReport.leafFirst`: 이미 올라온 거꾸로 된 기록을 읽을 때 바로 세운다.
  지문과 범인이 다시 계산되어 옛 기록도 제 이슈로 갈라진다.

## 남은 것

- 옛 기록 중 8000자에서 잘린 것은 **잎 쪽**이 잘렸다. 바로 세워도 죽은 자리는 없다.
- 멈춤 스택의 앱 프레임을 함수 이름으로 되돌리려면 그 빌드의 dSYM 이 있어야 한다.
  Xcode Cloud 빌드라 이 맥에는 없다. App Store Connect(TestFlight 빌드 페이지)에서 받는다.
