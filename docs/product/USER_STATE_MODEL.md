# 사용자 상태 모델 (UserState)

같은 화면을 모두에게 보여 주지 않기 위한 판정.
사람을 **얼마나 오래 머물렀나**(기간)와 **얼마나 손에 익었나**(숙련도) 두 축으로 나누고,
그 칸에 따라 무엇을 앞에 낼지 정한다.

기간은 시간이 알아서 흐르고 숙련도는 사람이 걸어 올라간다.
둘이 어긋나는 칸이 곧 이 앱이 사람을 놓친 자리다.

- 지도(시각화): https://claude.ai/artifact/UEuRs3FxuMcJK9Y3p864AC
- 코드: `ClipKeyboard/Service/UserState.swift` (판정, 순수) · `ClipKeyboard/Service/UserStateStore.swift` (값 긁기·바닥)
- 시험: `ClipKeyboardTests/UserStateTests.swift`

---

## 1. 두 축

### 기간 `UserTenure`

설치일(`DefaultsKey.appInstallDate`)에서 흐른 날수. 저절로 오르고 내려가지 않는다.

| 칸 | 날수 | 무엇 |
| --- | --- | --- |
| `.day0` | 0 ~ 1일 | 아직 이 앱이 무엇인지 모른다 |
| `.week1` | 2 ~ 7일 | 쓸지 말지 정하는 기간 |
| `.month1` | 8 ~ 30일 | 습관이 붙거나 잊히거나 |
| `.settled` | 31 ~ 90일 | 남아 있다면 이미 쓸모를 봤다 |
| `.long` | 91일 이상 | 업데이트가 이 사람의 하루를 건드린다 |

설치일을 모르면(예전 버전에서 올라온 기기) `.long` 이다.
`.day0` 으로 떨어뜨리면 몇 년 쓴 사람이 업데이트 한 번에 첫날 안내를 본다.

### 숙련도 `UserLevel`

**위에서부터 걸리는 첫 칸** 하나다. 그래야 한 사람이 정확히 한 칸에 속한다.

| 칸 | 조건 | 무엇 |
| --- | --- | --- |
| `.browsing` | `ownShortcuts < 1` | 자기 단축어가 아직 없다 |
| `.made` | `uses < 1` | 만들었는데 한 번도 안 썼다 |
| `.expert` | `uses >= 50 && templates + combos >= 1` | 두 번째 도구까지 쓴다 |
| `.fluent` | `uses >= 10 && keyboardPastes >= 1 && activeDays >= 3` | 손에 붙었다 |
| `.used` | 그 밖에 | 처음으로 꺼내 썼다 |

`.expert` 를 `.fluent` 보다 먼저 보는 것은 실수가 아니다.
쓴 날이 하루뿐이어도 200번 쓰고 콤보까지 만든 사람은 이미 능숙한 사람이다.

**문턱의 근거**: 무료 한도가 10개라(`ProFeatureManager.freeMemoLimit`) 8개 이상이면 많이 만든 쪽이다.
50회는 하루 두 번씩 한 달쯤 쓴 양이다. 한도를 바꾸면 `Threshold.hoarderShortcuts` 도 같이 움직여야 한다.

---

## 2. 결 `UserGrain`

레벨로는 안 갈리는 두 모습. 레벨을 올리거나 내리지 않고 화면을 어느 쪽으로 기울일지만 정한다.

| 결 | 조건 | 무엇을 바꾸나 |
| --- | --- | --- |
| `.oneTrick` | `ownShortcuts <= 3 && uses >= 10` | 검색·카테고리·정리를 뺀다. 셋 가지고는 정리할 것이 없다. 빈칸을 앞으로 낸다 |
| `.hoarder` | `ownShortcuts >= 8 && 안 쓴 것 / 전체 >= 0.7` | 한도 안내를 뺀다. 칸이 모자란 게 아니라 못 찾는 것이다. 즐겨찾기·검색을 앞으로 낸다 |
| `.even` | 그 밖에 | 바꾸지 않는다 |

---

## 3. 활동 `UserActivity`

레벨을 덮어쓰지 않고 **위에 얹는** 층. 말을 걸지 말지를 정한다.

| 상태 | 조건 | 화면 |
| --- | --- | --- |
| `.dormant` | 마지막 사용 14일 이상 전 | 말을 거는 자리를 **전부** 끈다 |
| `.returning` | 휴면에서 깬 뒤 7일 | 튜토리얼·리뷰·한도를 끈다. 끊긴 자리를 이어 준다 |
| `.active` | 그 밖에 | 그대로 |

한 번도 안 쓴 사람은 휴면이 아니다. 아직 시작을 안 한 것뿐이고,
휴면으로 보면 첫 단축어 안내까지 같이 꺼진다.

---

## 4. 지도 (기간 x 숙련도)

`UserState.Cell` 이 칸마다 하나씩 나온다.

| | 첫날 | 첫 주 | 첫 달 | 정착 | 오랜 |
| --- | --- | --- | --- | --- | --- |
| **능숙** | 질주 | 질주 | 주력 | 주력 | 기둥 |
| **익음** | 안착 | 안착 | 안착 | 단골 | 단골 |
| **꺼냄** | 탐색 | 탐색 | 탐색 | 정체 | 정체 |
| **만듦** | 만듦 | 머뭇 | 막힘 | 막힘 | 유령 |
| **구경** | 시작 전 | 구경 | 이탈 직전 | 유령 | 유령 |

- `.onTrack` 정상 궤도: 능숙·익음 전부, 꺼냄의 첫 달까지, 만듦·구경의 첫날
- `.watch` 지켜볼 것: 꺼냄의 정착·오랜, 만듦·구경의 첫 주
- `.stuck` 막힘: 만듦의 첫 달·정착, 구경의 첫 달
- `.ghost` 유령: 만듦의 오랜, 구경의 정착·오랜

**손봐야 하는 칸은 `.stuck` 뿐이다.** 만들어 놓고 한 달이 지나도록 한 번도 안 쓴 사람,
한 달이 지나도록 하나도 안 만든 사람. `.ghost` 는 이미 떠난 사람이라 조용히 둔다.

---

## 5. 기능 노출

`UserSurface` 18개 자리 x `UserLevel` 5칸이 바탕이고, 결이 기울이고, 활동이 마지막으로 덮는다.

```
바탕(레벨) → 결(oneTrick · hoarder) → 활동(dormant · returning)
```

| 자리 | 구경 | 만듦 | 꺼냄 | 익음 | 능숙 |
| --- | :-: | :-: | :-: | :-: | :-: |
| 무대 튜토리얼 | 내놓음 | 조용히 | 없음 | 없음 | 없음 |
| 단축어 만들기 | 내놓음 | 조용히 | 내놓음 | 내놓음 | 내놓음 |
| 키보드 켜기 띠 | 없음 | 내놓음 | 조용히 | 없음 | 조용히 |
| 클립보드에서 바로 만들기 | 없음 | 조용히 | 내놓음 | 내놓음 | 내놓음 |
| 즐겨찾기 | 없음 | 없음 | 내놓음 | 내놓음 | 내놓음 |
| 빈칸(템플릿) | 없음 | 없음 | 조용히 | 내놓음 | 내놓음 |
| 검색·순서 바꾸기 | 없음 | 없음 | 조용히 | 내놓음 | 내놓음 |
| 카테고리 | 없음 | 없음 | 없음 | 내놓음 | 내놓음 |
| 콤보 | 없음 | 없음 | 없음 | 조용히 | 내놓음 |
| 백업·동기화 | 없음 | 없음 | 조용히 | 내놓음 | 내놓음 |
| 통계·여권 | 없음 | 없음 | 없음 | 조용히 | 내놓음 |
| 꾸미기 | 없음 | 없음 | 조용히 | 내놓음 | 내놓음 |
| 키보드 판 높이·레이아웃 | 없음 | 없음 | 조용히 | 내놓음 | 내놓음 |
| 위젯·제어센터 | 없음 | 없음 | 없음 | 조용히 | 내놓음 |
| 맥 앱 안내 | 없음 | 없음 | 없음 | 조용히 | 내놓음 |
| 한도 안내·칸 추가 | 없음 | 없음 | 없음 | 조용히 | 내놓음 |
| 리뷰 요청 | 없음 | 없음 | 없음 | 조용히 | 조용히 |
| 한 번에 정리하기 | 조용히 | 없음 | 조용히 | 내놓음 | 내놓음 |
| 예시에서 골라 담기 | 내놓음 | 조용히 | 없음 | 없음 | 없음 |

- **내놓음** `.lead`: 그 화면의 주인공이 될 수 있다
- **조용히** `.quiet`: 있지만 눈을 먼저 끌지 않는다 (지금은 `opacity 0.72`)
- **없음** `.hidden`: 이 상태에서는 화면에 없다. **설정에는 있다**

### 주인공은 하나

표에서는 여러 자리가 동시에 `.lead` 가 될 수 있다.
그것들이 각자 옳다고 한꺼번에 뜨면 하루에 다섯 번 걸리적거린다.
그래서 말을 거는 자리(`UserSurface.isPrompt`) 가운데 주인공을 고르는 일은
`UserState.leadingSurface` 한 곳이 맡는다. `UserSurface.allCases` 순서가 곧 우선순위다.

---

## 6. 지켜야 할 것

1. **레벨은 내려가지 않는다.** 바닥(`DefaultsKey.userStateLevelFloor`)이 그것을 지킨다.
   한 달 쉬었다고 능숙이 꺼냄으로 떨어지면 돌아온 사람이 자기가 다 아는 안내를 처음부터 다시 본다.
2. **위에서 첫 번째로 걸리는 것 하나.** 한 사람은 정확히 한 칸이다.
3. **샘플은 자기 것이 아니다.** 판정은 `SampleMemoStorage` 를 뺀 개수로 한다.
   앱이 심어 준 것으로 사람을 올리면 첫 단축어에서 막힌 사람이 지도에서 사라진다.
4. **결제는 레벨이 아니다.** 산 사람이 잘 쓰는 사람은 아니다.
   한도 안내만 결제 상태를 보고, 화면 구성은 보지 않는다.
5. **감춘다는 것은 없앤다는 뜻이 아니다.** 설정을 뒤지면 늘 거기 있어야 한다.
   쓰던 기능이 업데이트 뒤 사라져 보이면 그것은 개인화가 아니라 고장이다.
   그래서 `userSurface(_:)` 는 **설정 화면에 쓰지 않는다.**
6. **하루에 한 번만 말을 건다.** 주인공 하나만 뜨고 나머지는 다음 날로 미룬다.
7. **기기 밖으로 나가지 않는다.** 판정에 쓰는 값은 전부 이미 기기에 쌓여 있던 것이다.

---

## 7. 판정에 쓰는 값

`UserStateStore.currentFacts()` 가 모은다.

| 무엇 | 어디서 | 쓰임 |
| --- | --- | --- |
| 설치한 날 | `DefaultsKey.appInstallDate` (표준) | 기간 |
| 내 단축어 수 | `memos.data` 에서 `SampleMemoStorage` 제외 | `.browsing` · `.made` 가르기, 결 |
| 쓴 횟수 `uses` | `Memo.clipCount` 합 | 레벨 문턱 전부 |
| 키보드에서 넣은 횟수 | `DefaultsKey.keyboardPasteCount` (App Group) | `.fluent` 조건 |
| 쓴 날의 수 | `ActiveDayLedger` (App Group) | `.fluent` 조건 |
| 마지막으로 쓴 때 | `Memo.lastUsedAt` 중 가장 최근 | 휴면 판정 |
| 빈칸·콤보 수 | `memos.data` | `.expert` 문턱 |
| 키보드를 켰는가 | `keyboard_extension_did_load` · `kb.beacon.lastUse` | 띠를 띄울지 |

### `uses` 에 비콘을 더하지 말 것

`kb.beacon.totalCount` 는 **키보드가 뜬 횟수**다(`KeyboardViewController.viewDidAppear`).
단축어를 한 번도 안 넣어도 오른다. 이 값을 사용 횟수에 더하면
만들고 멈춘 사람(`.made`)이 전부 `.used` 로 올라가고, 이 모델이 잡으려던 칸이 통째로 빈다.

키보드에서 쓴 것은 이미 `uses` 에 들어 있다.
키보드도 `MemoStore.incrementClipCount` 를 지나기 때문이다(`trackKeyboardPaste`).

> 참고: `UsageInsights.classify`(개발자 통계 화면)는 지금도 `uses + keyboardUses` 로 센다.
> 그쪽은 허브에 쌓인 과거 스냅샷과 이어 보려고 뜻을 바꾸지 않은 것이고, 이 모델과는 별개다.

### 활동일 원장 `ActiveDayLedger`

`AnalyticsService.swift` 에 있다(앱·키보드 양쪽 타겟에서 컴파일된다).
`MemoStore.incrementClipCount` 한 곳에서만 쓴다. 모든 사용이 그 함수를 지나므로 그걸로 충분하다.

**`KeyboardDayLedger` 와 헷갈리지 말 것.** 저쪽은 허브로 보내고 나면 그 날을 지운다(`removeDays`).
보낸 뒤 비워지는 원장으로 활동일을 재면, 꼬박꼬박 쓰는 사람일수록 활동일이 0에 가까워지는
거꾸로 된 값이 나온다.

### 예전부터 쓰던 사람 (바닥 깔기)

활동일 원장은 이 기능과 함께 생겼다. 업데이트로 올라온 기기는 처음에 늘 0이라,
그대로 믿으면 반년 쓴 사람이 `.used` 로 떨어지고 초심자 안내가 다시 얼굴을 내민다.

그래서 첫 판정 때 **활동일 조건만 빼고** 한 번 계산해 바닥으로 깐다
(`UserStateStore.seedFloorIfNeeded`, `DefaultsKey.userStateFloorSeeded`). 그 뒤로는 원장이 스스로 쌓인다.

---

## 8. 화면에서 쓰기

```swift
@StateObject private var userState = UserStateStore.shared

// ① 자리 하나를 상태에 맡긴다
KeyboardSetupBanner()
    .userSurface(.keyboardSetupBanner)

// ② 직접 묻는다
if userState.isVisible(.combo) {
    ComboSection()
}

// ③ 지금 앞에 세울 안내 하나
switch userState.leadingSurface {
case .keyboardSetupBanner: KeyboardSetupBanner()
case .tutorialStage:       TutorialStage()
default:                   EmptyView()
}
```

`refresh()` 를 부르는 자리는 셋이면 된다.

- 앱이 앞으로 올 때 (`scenePhase == .active`)
- 단축어를 쓴 뒤 (`.memoUsed` 알림)
- 목록이 바뀐 뒤 (만들기·지우기·가져오기)

`memos.data` 를 통째로 읽으므로 매 프레임 부르지 말 것.

---

## 8.5. 단계 흉내 (개발자 전용)

설정 ▸ (마스터 모드) ▸ **사용 단계 흉내**에서 단계 하나를 고르면, 앱이 그 단계 사람의 것처럼 보인다.
`ClipKeyboard/Service/UserStageSimulator.swift` · 화면은 `Screens/UserStageSimulatorView.swift`.

고르면 두 가지가 한꺼번에 일어난다.

1. **서랍이 깔린다.** 그 단계 사람의 단축어·클립보드·카테고리가 들어온다. 목록·빈 화면·개수가 진짜로 그렇게 보인다.
2. **판정이 고정된다.** `UserStateStore.refresh()` 가 기기의 진짜 값 대신 그 단계의 상태를 쓴다.

둘 다 필요하다. 데이터만 깔면 설치일·활동일을 흉내 낼 수 없어 판정이 어긋나고,
판정만 바꾸면 목록은 여전히 내 것이라 화면이 거짓말을 한다.

| 단계 | 나오는 칸 |
| --- | --- |
| 첫 방문자 | `.browsing` · `.day0` |
| 구경만 하는 사람 | `.browsing` · `.month1` (막힘) |
| 만들고 멈춘 사람 | `.made` · `.month1` (막힘) |
| 처음 써 본 사람 | `.used` · `.week1` |
| 손에 익은 사람 | `.fluent` · `.settled` |
| 능숙한 사람 | `.expert` · `.long` |
| 하나만 쓰는 사람 | `.fluent` · 결 `.oneTrick` |
| 쌓아만 두는 사람 | `.used` · 결 `.hoarder` |
| 휴면 | `.fluent` · `.dormant` |
| 돌아온 사람 | `.fluent` · `.returning` |

**내 데이터는 안전하다.** 데모 데이터와 **같은 백업 한 벌**을 쓴다(`DemoDataService.apply`).
단계를 끄거나 설정의 데모 토글을 끄면 원래 단축어·클립보드·카테고리가 그대로 돌아온다.

**흉내는 진짜 기록을 물들이지 않는다.** 단계를 쓰는 동안 바닥(`userStateLevelFloor`)도
휴면 기록도 건드리지 않는다. 그래서 능숙한 사람의 기기에서도 첫 방문자를 볼 수 있고,
끄면 원래 상태가 그대로 돌아온다.

⚠️ 단계의 서랍은 **실제로 그 판정을 낳아야 한다.** 예를 들어 능숙한 사람의 서랍에 템플릿이
하나도 없으면 판정은 익음에서 멈추는데 화면 제목만 능숙이라고 적힌다. 그 화면을 보고 내린
판단은 통째로 틀린 것이 된다. `UserStageSimulatorTests` 가 단계마다 이것을 검사한다.

## 9. 아직 안 한 것

- **붙여 넣기.** 세 자리를 붙였다.

  | 자리 | 어디서 읽나 | 무엇이 달라졌나 |
  | --- | --- | --- |
  | 예시에서 골라 담기 | `ClipKeyboardList.minimalEmptyState` | 아직 하나도 안 만든 사람에게만 뜬다 |
  | 키보드 켜기 띠 | `KeyboardSetupBannerGate.shows(stateAllows:)` | 첫 단축어 전에는 켜라고 하지 않는다 |
  | 무대 튜토리얼 | `SnippetsOnboardingStep.current(stateAllows:)` | 돌아온 사람에게 다시 틀지 않는다 |

  **판단을 옮기지 않고 얹었다.** 띠와 계단은 저마다 "지금이 말할 때인가" 를 알고 있고,
  그 판단은 오래 벼려진 것이라 그대로 둔다. 상태 모델이 답하는 것은 "이 사람에게 낼
  자리인가" 뿐이다. 한 곳에 섞으면 타이밍을 고치려다 대상이 바뀌고 그 반대도 일어난다.
  시험도 둘로 나눠 둔다 - 때만 맞아도, 자리만 맞아도 열리지 않는다.

  나머지 화면들은 여전히 저마다 조건을 들고 있다
  (`DiscountOfferManager` · `ReviewManager` · `BulkImportNudge` · `FavoriteNudgeManager`).
  옮기는 순서는 막힌 칸부터다. 다음은 한도 안내와 반값 제안.

- **다국어.** `localizedName` 과 단계 시뮬레이터 문구가 아직 카탈로그에 없다.
  릴리즈 전에 `python3 scripts/i18n.py extract` 부터 파이프라인을 한 번 돌려야 한다
  (`docs/engineering/I18N_PIPELINE.md`). 지금은 한국어 원문이 그대로 보인다.
- **`.quiet` 의 생김새.** 지금은 `opacity 0.72` 하나다. 자리마다 다르게 내려야 할 수도 있다
  (목록 아래로 밀기 · 설정 안으로 넣기 · 배지만 떼기).
