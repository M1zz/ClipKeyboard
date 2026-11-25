# `launch_incomplete:keyboard` 102건: 어디서 멈췄는지 모르는 숫자였다

2026-11-25 · 안정화 작업. **허브 원본 리포트는 읽지 못했다**(보호 폴더). 코드 · 기존 문서 · 시험으로 본 것이다.

## 한 줄

키보드의 `launch_incomplete` 는 "viewDidLoad 뒤 3초를 못 버텼다" 하나뿐이라, 뜨다가 죽은 것과
보이지도 않은 채 정리된 것이 한 숫자였다. 진짜 사고인지 셈법인지 **지금 숫자로는 가를 수 없다.**
다음 빌드부터 멈춘 단계를 붙여 보낸다(`launch_incomplete:keyboard-load` · `-appearing` · `-shown`,
그리고 따로 `keyboard_idle_exit`).

## 무엇을 세고 있었나 (확인, 코드)

`LeeoCrashLoopGuard(name: "keyboard")` 는 `viewDidLoad` 에서 표식을 남기고, 다음 셋 중 하나가 오면 지운다.

- `viewDidAppear` 뒤 3초 (`markLaunchSucceededAfterSurvivalDelay`)
- `viewWillDisappear`
- 호스트 앱이 비활성 · 백그라운드로 감 (`hostWillLeave`, 5.1.12 무렵 ee2064c4)

그러니 표식이 남는 실행은 이렇다.

| 멈춘 곳 | 무엇인가 | 사고인가 |
| --- | --- | --- |
| `load` (viewDidLoad 안: 단축어 읽기 · SwiftUI 판) | 읽다가 죽음, 메모리 초과 | 사고 |
| `idle` (viewDidLoad 는 끝났고 보이라는 말이 없음) | iOS 가 만들어 두고 쓰지 않은 키보드를 정리 | 사고 아님(추정) |
| `appearing` (첫 레이아웃 ~ viewDidAppear) | 첫 그림에서 죽음, 메모리 초과 | 사고 |
| `shown` (떴고 3초가 안 지남) | 3초 안에 죽음, 또는 알림 없이 정리됨 | 섞임 |

## 판단

- **진짜 사고인지 셈법인지 가를 근거가 지금은 없다.** 허브에 같은 기간 키보드 CrashReport 가 몇 건인지 보지 못했다.
  `todo.md` 의 "허브에서 `launch_incomplete:keyboard` · 키보드 CrashReport 확인" 도 아직 열려 있다.
- 5.1.24 의 앱 쪽 숫자는 대부분 셈법이었다(`LAUNCH_INCOMPLETE_BACKGROUND_WAKE_5_1_24.md`). 키보드도 `idle` · `shown` 칸에
  같은 성격이 섞여 있을 수 있다(추정). `load` · `appearing` 이 남으면 그것이 진짜다.
- 시뮬레이터에서는 재현하지 못했다. 앱을 켜고 20초 살아 있음, 새 크래시 리포트 없음까지만 봤다.

## 고친 것

- `KeyboardLaunchTrail` (`ClipKeyboardExtension/KeyboardDocumentState.swift`): 단계를 App Group 에 적고
  (적자마자 디스크로 민다), 가드가 직전 실행을 "끝나지 못함" 으로 셀 때 그 단계를 함께 남긴다. 앱이 열릴 때 꺼내 보낸다.
- `idle` 에서 사라진 실행 때문에 세이프 모드로 열지 않는다(`opensSafeMode`). 그 실행은 viewDidLoad 를 무사히 마쳤다.
  ⚠️ 위험: viewDidLoad 뒤 보이기 전에 도는 우리 코드(알림 받기 · 텍스트 대치 사전 받기)에서 죽으면 세이프 모드가 늦게 걸린다.
  연속 횟수는 계속 쌓이므로 다음에 `load` · `appearing` 에서 못 뜨면 바로 세이프 모드가 된다.
- `textDidChange` 와 `viewWillLayoutSubviews` 의 `nextKeyboardButton` 을 옵셔널로 부른다(암시적 언래핑 값을 뷰가 생기기 전에 풀면 죽는다. 그런 순서가 실제로 오는지는 확인 못 함).

시험: `ClipKeyboardTests/StabilityHardeningTests.swift` (단계 셈 · 세이프 모드 판정 · 상한).

## 같은 작업에서 막은 다른 자리 (잠복 · 좁은 조건)

| 자리 | 조건 | 무엇이 | 막은 법 |
| --- | --- | --- | --- |
| `MemoStore.load` | 단축어 한 칸이 못 풀림(종류 이름이 지워진 값 등) | 목록 전체가 옛 형식(제목 · 본문)으로 떨어져 즐겨찾기 · 잠금 · 스택 · 쓴 횟수가 다음 저장에 사라짐 | 칸마다 따로 풀고, 못 푼 칸만 제목 · 본문으로. 원본 사본을 한 벌 남김 |
| `Memo` · `QuickNote` 디코더 | 모르는 enum 값 | 위와 같음 | `try?` 로 읽고 기본값 |
| `MemoSyncEngine.allLocalMemos` | 깨진 파일이 빈 목록으로 읽힘 | 모든 단축어의 삭제가 iCloud 로 올라감 | 파일에 내용이 있는데 비면 그 차례를 건너뜀 |
| `DataWipeService` | 모든 데이터 지우기 | 동기화 섀도가 남아 다른 기기 단축어까지 지움 | 섀도도 지움 |
| 키보드 저장 | 키보드에서 단축어를 씀 | 앱의 낡은 목록이 다음 편집에 키보드의 변경(쓰면 지우기 등)을 덮음 | 익스텐션 저장이 앱에 표식을 세움 |
| `QuickShortcutSave` | 보관함 파일을 못 읽음 | 덮어써서 한 줄만 남음 | 실패로 돌려보냄 |
| `ClipboardHistoryStore.load` | 복사 기록을 못 풂 | 다음 담기가 덮음 | 사본을 남김 |
| `OCRService` | Vision 실패 | completion 두 번 → `DispatchGroup.leave` 초과로 죽음 | 메인에서 한 번만 |
| `uniqueKeysWithValues` (섀도 · 툼스톤) | 대소문자만 다른 UUID 열쇠 | 그 자리에서 죽음 | `uniquingKeysWith` |
| `TypedShortcut.place` | 찾은 자리가 첫 글자 묶음 안쪽 | `index(before:)` 범위 밖 | 글자 경계로 맞춘 뒤 판단(재현 입력은 못 찾음) |
| `FoldPresentationGuard` | 메인 밖에서 표시 | `assumeIsolated` 가 죽임 | 원래 구현으로 |
| `abs(hashValue)` | `Int.min` | 넘침 | `magnitude` |
| `BeaconBackgroundScheduler` | 다른 종류의 작업 | `as!` 로 죽음 | `as?` |

## 쓰는 중 멈춤 후보 (빌드 52 · 53): 고치지 않았다

코드로 따져 본 결과.

- `CoachAnchorKey`: 받은 자리는 덧그림(`floatingLayer`, 손대기 막힘)에만 쓰인다. 카드 배치로 돌아가지 않아 고리가 없다.
- `StaleScrollOffsetReset`: 맨 위로 되돌린 뒤 제목이 펼쳐지면 한 번 더 걸릴 수 있지만 두 번째에 맨 위에서 멈춘다. 수렴한다.
  손이 굴리는 동안(`isPageScrolling`)에는 안 돌고, 제목 접기는 그때만 돌아 둘이 겹치지 않는다.
- `trackPageScroll` 제목 접기: 제목 모드가 바뀌어 위 여백(`contentInsets.top`)이 줄고 오프셋이 그대로면 판정이 뒤집힐 수 있다.
  그러면 손이 굴리는 동안 접기 · 펼치기가 번갈아 돈다. **UIKit 이 여백과 함께 오프셋을 옮기는지에 달렸고 코드만으로는 확정 못 했다.**
  멈춤 시험(`ListHangUITests`, 문턱 근처 천천히 스크롤)에서 2.5초 넘는 멈춤이 없었으므로 고리가 확인될 때까지 두었다.
