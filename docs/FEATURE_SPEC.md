# ClipKeyboard 기능 명세 (Feature Specification)

> 대상 버전: 4.3.x (dev) — 데이터 모델 통합 리팩터 이후 기준
> 이 문서는 **현재 코드에 실제로 존재하는 동작**을 명세하며, `ClipKeyboardTests`의
> Swift Testing 스위트(`*SwiftTests.swift`)가 이 명세를 검증한다.

---

## 1. 데이터 모델 (`Memo`)

`Memo`는 앱의 단일 핵심 모델이다. "메모 / 템플릿 / 콤보"는 별도 타입이 아니라
**같은 `Memo`의 성질**이며, 다음과 같이 **계산형**으로 판정된다.

| 성질 | 판정 | 비고 |
|------|------|------|
| 일반 메모 | `templateVariables.isEmpty && comboValues.isEmpty` | 변수도 단계도 없음 |
| 템플릿 | `isTemplate == !templateVariables.isEmpty` | `{변수}`가 하나라도 있으면 템플릿 |
| 콤보 | `isCombo == !comboValues.isEmpty` | 이어지는 단계가 있으면 콤보 |

### 1.1 주요 필드
- `id: UUID`, `title: String`, `value: String`
- `category: String = "기본"`, `isFavorite`, `isSecure`
- `templateVariables: [String]` — 템플릿 변수 토큰(중괄호 포함, 예 `{이름}`)
- `placeholderValues: [String: [String]]` — 변수별 입력값 히스토리
- `comboValues: [String]` — 콤보 단계(본문=1단계, 이후 단계가 배열에 누적)
- `comboInterval: TimeInterval = 2.0` — 콤보 단계 간 지연
- `contentType: ClipboardContentType` (.text/.image/.emoji/.mixed)
- `imageFileNames: [String]` — 다중 이미지
- `autoDetectedType: ClipboardItemType?` — 자동 분류 캐시
- `childMemoIds: [UUID]` — **레거시(디코드 전용)**, 신규 로직 미사용

### 1.2 하위 호환 (마이그레이션)
- 구버전 JSON의 제거된 키(`attachedTemplateId`, `currentComboIndex`, 저장형 `isTemplate`)는
  **디코드 시 무시**되며, 계산형 `isTemplate`/`isCombo`가 우선한다.
- `OldMemo`(title/value/isChecked만 보유) → `Memo(from:)`로 변환.
- 출시본 4.3.x의 인라인 콤보(`comboValues`)는 변환 없이 그대로 디코드된다.

**검증:** `MemoModelSwiftTests.swift`

---

## 2. 클립보드 자동 분류 (`ClipboardClassificationService`)

`classify(content:) -> (type: ClipboardItemType, confidence: Double)`
정규식 + 체크섬 기반으로 복사된 텍스트의 종류를 추정한다.

- 지원 타입: 이메일, 전화번호, 주소, URL, 카드번호(Luhn), 계좌번호, 여권번호,
  통관번호, 우편번호, 생년월일, IBAN(mod-97), SWIFT/BIC, VAT, 암호화폐 지갑,
  PayPal 링크, IP주소 등 (`ClipboardItemType` 전체).
- **우선순위**: 구체적 패턴 우선. 예) 8자리 숫자 `20240101`은 계좌번호가 아니라
  생년월일로 분류, 통관번호 `P12345...`는 계좌번호로 오인하지 않음.
- 체크섬: 카드번호는 Luhn, IBAN은 mod-97 통과 시에만 해당 타입.
- 빈/공백 문자열 → `.text`, confidence `0.0`.

**검증:** `ClipboardClassificationSwiftTests.swift` (+ 기존 `ClipboardClassificationServiceTests.swift`)

---

## 3. 템플릿 변수 처리 (`TemplateVariableProcessor`)

- `process(_:at:)` — 자동 변수 치환. `{날짜}`/`{date}`→`yyyy-MM-dd`,
  `{시간}`/`{time}`→`HH:mm:ss`, `{연도}`/`{월}`/`{일}`, 그리고 `{timezone}`,
  `{currency}`, `{greeting_time}`, `{city}` 등 글로벌 토큰.
- `extractCustomTokens(in:)` — 사용자 정의 토큰만 추출(자동 변수 제외, 중복 제거,
  등장 순서 보존, 중괄호 포함).
- `substitute(_:with:)` — 사용자 입력값으로 토큰 치환 후 자동 변수까지 처리.
- `compose(memoValue:templateBody:templateInputs:)` — 메모 본문 + 줄바꿈 + 치환된 템플릿.
- `tokenKind(_:)` / `isNumericToken(_:)` — 토큰이 숫자 입력 의도인지 판정
  (`금액/수량/가격/번호/amount/price...` 키워드 부분 매칭).

**검증:** `TemplateVariableProcessorSwiftTests.swift`

---

## 4. 콤보 실행 (`ComboExecutionService`)

- `startCombo(_:)` / `pauseCombo()` / `resumeCombo()` / `stopCombo()`로 콤보를
  순차 재생. 단계 소스는 `Memo.comboValues`.
- 상태 머신 `ComboExecutionState`: `.idle` / `.running(currentIndex,totalCount)` /
  `.paused(currentIndex)` / `.completed` / `.error(String)` (Equatable).
- `progress`, `currentValue` 계산형으로 UI 진행률 노출.
- 완료/단계 실행 시 `Notification.Name.comboCompleted` 등 발행.

**검증:** `ComboAndTemplateModelSwiftTests.swift` (상태 머신), 기존 `ComboExecutionServiceTests.swift`

---

## 5. 리스트 미리보기 (`MemoPreviewFormatter`)

`preview(for:resolvedType:)`가 한 줄 미리보기를 생성한다.
- 콤보 → "N items", 템플릿 → "본문 · N variables"(중괄호 제거),
  이미지 → "N image(s)".
- 보안 메모 + 마스킹 가능 타입(카드/계좌/여권 등) → `•••• 1234`(끝자리만 노출).
- URL → 호스트+경로, 그 외 → 40자 truncate + `…`.
- `extractPlaceholders(in:)` — 변수명만(중괄호 제거) 중복 제거 추출.

**검증:** `MemoPreviewFormatterSwiftTests.swift`

---

## 6. 무료/Pro 제한 (`ProFeatureManager`)

- 무료 한도: 메모 10, 콤보 3, 템플릿 3, 이미지 메모 5, 클립보드 히스토리 50.
- `canAddMemo/Combo/Template/ImageMemo(currentCount:)` — 풀 액세스면 무제한,
  아니면 한도 미만일 때만 `true`.
- `hasFullAccess = isPro || isGrandfathered || isInTrial`.
- 7일 무료 체험(`startTrial`/`isInTrial`/`trialDaysRemaining`), v4.0 이전 구매자
  grandfathering.
- `clipboardHistoryLimit()` — 풀 액세스 100, 무료 50.

**검증:** `ProFeatureLimitsSwiftTests.swift` (+ 기존 `ProFeatureManagerTests.swift`)

---

## 7. 카테고리 (`CategoryStore`)

- 사용자 카테고리 CRUD(`add/rename/remove/move`), 보호 카테고리
  `["기본","텍스트","이미지"]`는 삭제/개명 불가.
- 카테고리별 지정색(`colorHex(for:)`/`setColorHex(_:for:)`) — **항상 표시**
  (구분 표시 토글과 무관, 카테고리 정체성).
- 즐겨찾기는 하나의 카테고리로 취급 → 즐겨찾기한 메모는 "기본" 버킷에서 제외.
- 기능 토글(`isFeatureEnabled`/`enableFeature`) 및 활성화 배너.

**검증:** 기존 `CategoryStoreTests.swift`

---

## 8. 저장소 & 타임머신 (`MemoStore`)

- App Group(`group.com.Ysoup.TokenMemo`) 컨테이너에 JSON 파일로 저장
  (`save(memos:type:recordHistory:)` / `load(type:)`).
- **타임머신**: 의미 있는 변경 시 최근 10개 스냅샷(`MemoSnapshot`)을 링버퍼로 보관
  (`loadMemoHistory()` / `restoreMemoSnapshot(_:)`). 서명은 `clipCount`/`lastUsedAt`을
  무시해 사용 카운트 변동만으로는 스냅샷을 남기지 않음.
- 플레이스홀더 값, 클립보드 히스토리, 콤보 CRUD 지원.

**검증:** 기존 `MemoStoreTests.swift`, `MemoStoreUsageAndImageTests.swift`

---

## 부록: 테스트 매핑

| 기능 | Swift Testing 스위트 | 기존 XCTest |
|------|----------------------|-------------|
| Memo 모델/계산형/마이그레이션 | `MemoModelSwiftTests` | `ModelTests` |
| 템플릿 변수 처리 | `TemplateVariableProcessorSwiftTests` | `AttachedTemplateTests` |
| 미리보기 포매터 | `MemoPreviewFormatterSwiftTests` | — |
| 클립보드 분류 | `ClipboardClassificationSwiftTests` | `ClipboardClassificationServiceTests`, `ClipboardDetectionTests` |
| Pro 제한 | `ProFeatureLimitsSwiftTests` | `ProFeatureManagerTests` |
| 콤보 상태 머신 | `ComboAndTemplateModelSwiftTests` | `ComboExecutionServiceTests` |
