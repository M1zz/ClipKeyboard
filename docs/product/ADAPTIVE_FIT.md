# 알아서 맞추기 (5.1.4)

사람에게 "당신은 누구냐" 고 묻지 않는다. 이미 기기에 쌓인 것을 보고 앱이 판단하고,
판단한 만큼만 무엇을 먼저 꺼내 보일지 바꾼다.

- 지도(왜 이 순간들인가): `docs/product/PERSONA_JOURNEY_MAP.html`
- 사용자 상태 모델(얼마나 손에 익었나): `docs/product/USER_STATE_MODEL.md`

---

## 1. 층을 나눈 이유

예전에는 페르소나를 사람이 골랐고(`PersonaSelectionView`, `PersonaPrompt`), 고른 값이
추천·샘플·카테고리 제안에 곧장 쓰였다. 고르는 일도, 그 값으로 무엇을 바꾸는지도 한 줄로 이어져 있었다.

이제 세 층이다. 한 층을 고칠 때 다른 층이 같이 흔들리지 않게 떼어 놓았다.

```
기기의 값 ──▶ 판정(순수) ──▶ 저장된 결과 ──▶ 기능 맞춤(순수) ──▶ 화면
            PersonaInference   PersonaResolver     FeatureFit
            UsageRhythm        UsageRhythmLog      QuickRowPlanner
            KeyboardSessionLedger.isStruggling
            RepeatCopyLedger.noting
            PlaceholderSequence
```

| 층 | 무엇 | 규칙 |
| --- | --- | --- |
| 판정 | 이 사람은 어떤 쓰임새인가, 이 단축어는 언제 쓰나, 요즘 못 찾고 있나 | 순수 함수. 시험은 여기서 한다 |
| 저장 | 판정 결과와 판정에 쓰는 기록 | App Group. 내용은 담지 않는다(id·시각·지문만) |
| 맞춤 | 그래서 무엇을 먼저 보이나 | 순수 함수. **막는 것은 없다** |

⚠️ 맞춤 층은 한도·결제·기능 잠금을 바꾸지 않는다. 학생도 한도에 닿으면 똑같이 막힌다.
바뀌는 것은 "무엇을 먼저 꺼내 보이나" 뿐이다.

---

## 2. 쓰임새 알아보기

`ClipKeyboard/Service/PersonaInference.swift` · `PersonaResolver.swift`

| 보는 것 | 무게 |
| --- | --- |
| 자동 분류 종류 (IBAN·SWIFT → 노마드, 세금번호 → 직장인, 주소·송장 → 일반 …) | 종류마다 0.5 ~ 3 |
| 제목·본문의 낱말 | 단축어 하나에 최대 2 |
| 빈칸 이름 ({학번} {시차} {고객사}) | 1.5 |
| 직접 만든 카테고리 이름 | 1 |
| 5.1.3 까지 직접 고른 페르소나 | 2 (한 표) |

- **4점 이상**이고 둘째보다 **1.5배** 앞서야 확신한다. 아니면 일반 + 확신 없음
- 샘플은 넣지 않는다. 보안 단축어의 본문은 보지 않는다
- 영어 낱말은 낱말 단위로 맞춘다(`otherwise` 의 `wise` 를 잡지 않는다)
- 다시 재는 자리: `UserStateStore.refresh` (목록을 이미 읽은 자리). 목록을 못 읽었으면 재지 않는다

화면이 물을 것은 대개 `PersonaResolver.confident` 다. 확신이 없을 때 좁혀 보이면
저장한 것이 두세 개뿐인 사람에게 엉뚱한 진열대가 선다.

설정 > 단축어 > **나에게 맞추기** (`UsageProfileSettingsView`) 가 판단과 근거를 보여 주고,
틀렸을 때 직접 정하는 문을 연다(`PersonaResolver.override`). 기본은 자동이다.

### 쓰는 곳

| 자리 | 무엇을 읽나 |
| --- | --- |
| 단축어 마트 거르기 | `FeatureFit.martFilterPersona(profile)` |
| 카테고리 제안 팁 | `PersonaResolver.confident` |
| 신규 설치 샘플 | `PersonaResolver.current` (설치 직후는 늘 일반) |
| 분석 속성 `persona` | `PersonaResolver.confident` (모르면 nil) |
| 반값 제안 | `FeatureFit.allowsDiscountOffer` → `DiscountOfferManager.Context.fitsDiscountOffer` |
| 친구에게 알리기 | `FeatureFit.isShareMomentDue` → `SnippetsTab.offerShareIfEarned` |

---

## 3. 같은 때 쓰는 단축어

`ClipKeyboard/Service/UsageRhythm.swift` (앱·키보드)

- 기록: `MemoStore.incrementClipCount` 한 곳에서 `UsageRhythmLog.record`. 단축어마다 최근 24번
- 박자: 매달(같은 날짜 ±2일, 또는 월말 7일) · 매주(같은 요일) · 매일(같은 시각 ±1시간)
- 울타리: 한 기간에 평균 2번보다 많이 쓰면 매달·매주로 보지 않는다(매일 쓰는 것을 월말로 오인하지 않게)
- 이번 몫을 이미 썼으면 세우지 않는다(매달 10일 · 매주 같은 날 · 매일 3시간)

하는 일은 키보드 빠른 줄(`QuickRowPlanner`)의 맨 앞자리뿐이다. 말을 걸지 않는다.
빠른 줄을 꺼 달라고 한 사람에게는 세우지 않고, 아직 안 정한 사람에게는 단축어가 적어도 차례가 있으면 세운다.

## 4. 찾다가 포기하는 판

`ClipKeyboard/Service/KeyboardSessionLedger.swift` (앱·키보드)

- 키보드가 뜨면 `begin`, 내려가면 `end`, 단축어를 넣으면 `noteInserted`, 글자를 치면 `noteTyped` (판마다 한 번)
- 포기한 판: 3초 넘게 열려 있다가 아무것도 안 넣고 닫힘
- 못 찾는 중: 최근 7일 닫힌 판 5개 이상, 포기 3개 이상이고 40% 이상
- 하는 일: 빠른 줄에 **많이 쓴 것** 두 개를 얹는다

## 5. 다음 번호

`ClipKeyboard/Service/PlaceholderSequence.swift` (앱·키보드)

- 빈칸 이름이 차례를 뜻하거나(번호·회차·No …), 최근 두 값이 1 차이면 `INV-1042` → `INV-1043` 칩을 맨 앞에
- 전화·계좌·카드·학번 같은 말이 이름에 있으면 이름으로는 차례로 보지 않는다
- 기본값으로 채우지 않는다. 고르면 넣기를 마칠 때 새 값으로 적는다

⚠️ **고른 값을 앞으로 옮기지 않는다.** 지도에서는 "{도시} 새 값을 기본으로" 를 제안했지만
5.0.7 에서 사용자 요청으로 "쓴다고 자리가 움직이지 않는다" 로 정한 것과 부딪혀 넣지 않았다.

## 6. 같은 글을 두 번 복사

`ClipKeyboard/Service/RepeatCopyLedger.swift` (앱)

- 복사 한 번 = 클립보드 `changeCount` 하나. 같은 복사를 앱에서 여러 번 봐도 한 번
- 글은 담지 않고 SHA-256 앞 16자리만
- 두 번째 복사부터 캡처 카드에 "이번 주에 n번째 복사한 글이에요"
- 전에 닫았던 글이라도 다시 복사했으면 **한 번 더** 보여 준다. 이미 단축어로 저장한 글이면 아무 말도 안 한다

## 7. 사진에서 읽은 민감한 값

`FeatureFit.shouldLockValueFromPhoto` · `MemoAddViewModel.noteValueFromPhoto`

사진(문질러 담기·줄 고르기·OCR 후보)에서 담은 값이 여권·카드·계좌처럼 민감하면(신뢰도 0.7 이상)
보안 단축어로 돌린다. 잠금을 못 쓰는 사람에게는 켜지 않는다. 저장하려다 결제 창이 뜨면
사진에서 값을 담은 것이 곧 결제 요구가 된다. 그 사람에게는 저장 뒤의 순간(`PurchaseMoment.sensitiveSaved`)이 따로 있다.

---

## 8. 지운 것

- `PersonaPrompt` (단축어 두 개를 만들면 "혹시 이런 분이신가요?" 를 묻던 판)
- `PersonaSelectionView` · `PersonaSettingsContainer` (고르는 화면)
- `Persona.localizedDescription` · `exampleTags` (고르는 화면에서만 쓰던 것)

`CategoryStore.selectedPersona` 와 저장 키는 남겼다. 예전에 고른 사람의 선택이 한 표로 들어간다.

## 9. 시험

| 무엇 | 시험 |
| --- | --- |
| 쓰임새 판정 | `PersonaInferenceTests` |
| 기능 맞춤 | `FeatureFitTests` · `DiscountOfferManagerTests` |
| 박자 | `UsageRhythmTests` |
| 포기한 판 · 빠른 줄 | `KeyboardSessionLedgerTests` |
| 다음 번호 | `PlaceholderSequenceTests` |
| 복사 반복 | `RepeatCopyLedgerTests` |
