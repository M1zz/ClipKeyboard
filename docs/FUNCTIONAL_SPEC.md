# ClipKeyboard 기능명세서

> 버전: v4.0.6 기준
> 작성일: 2026-05-04
> 대상: iOS 17+ / Mac Catalyst (macOS)
> Bundle ID: `com.Ysoup.TokenMemo` · App Group: `group.com.Ysoup.TokenMemo`

---

## 1. 제품 개요

ClipKeyboard는 **메모 + 스마트 클립보드 + 커스텀 키보드 + 자동 입력(Combo)** 을 결합한 입력 보조 앱이다. 자주 쓰는 텍스트(이메일, 주소, 카드번호 등)를 한 번 저장해두고 시스템 키보드에서 즉시 꺼내 쓰는 것을 핵심 가치로 한다. 글로벌 디지털 노마드/프리랜서가 1차 타깃이며, 가격 정책은 무료 + 7일 체험 + Pro 일시불($9.99)이다.

### 주요 타깃 시나리오
- 폼 입력에서 이메일·전화·주소를 반복 입력해야 하는 경우
- 비밀번호/계좌번호 같은 민감 정보를 안전하게 저장해 키보드에서 즉시 꺼내쓰는 경우
- 회원가입처럼 여러 필드를 순차적으로 채워야 하는 경우 → Combo로 자동 입력

---

## 2. 기능 분류

| ID | 기능군 | 핵심 책임 |
|----|--------|-----------|
| F1 | 메모 관리 | 텍스트/이미지/템플릿 메모 CRUD |
| F2 | 스마트 클립보드 | 정규식 기반 자동 분류, 25종 타입 감지 |
| F3 | 커스텀 키보드 | iOS 키보드 익스텐션을 통한 빠른 입력 |
| F4 | macOS 메뉴바 앱 | Mac Catalyst 기반 메뉴바 + 전역 단축키 |
| F5 | Combo 시스템 | 다단계 자동 입력 (메모/클립/템플릿) |
| F6 | CloudKit 백업 | iCloud를 통한 동기화/백업/복구 |
| F7 | OCR 인식 | Vision 기반 한국어/영어 텍스트 추출 |
| F8 | 카테고리 관리 | 사용자 정의 카테고리 + Locale 시드 |
| F9 | 보안 메모 | 생체인증 게이팅 |
| F10 | Pro/체험 | 무료 한도, 7일 체험, 그랜드파더 |
| F11 | 리뷰 요청 | StoreKit 리뷰 시점 룰 |

---

## 3. 데이터 모델

### 3.1 Memo
저장 위치: App Group 컨테이너의 `memos.data` (JSON 인코딩 배열).

| 필드 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `id` | UUID | 자동 생성 | 식별자 |
| `title` | String | — | 메모 제목 |
| `value` | String | — | 본문 (또는 템플릿 본문) |
| `isChecked` | Bool | false | 체크 상태 |
| `lastEdited` | Date | now | 마지막 수정 시각 |
| `isFavorite` | Bool | false | 즐겨찾기 |
| `clipCount` | Int | 0 | 사용 횟수 |
| `lastUsedAt` | Date? | nil | 마지막 사용 시각 |
| `category` | String | "기본" | 사용자 정의 카테고리 |
| `isSecure` | Bool | false | 보안 메모 (생체인증 필요) |
| `isTemplate` | Bool | false | 템플릿 여부 |
| `templateVariables` | [String] | [] | `{이름}` 같은 토큰 목록 |
| `placeholderValues` | [String:[String]] | [:] | 토큰별 후보 값 |
| `isCombo` | Bool | false | 레거시 Combo 플래그 |
| `comboValues` | [String] | [] | 레거시 Combo 값 |
| `currentComboIndex` | Int | 0 | 레거시 진행 인덱스 |
| `autoDetectedType` | ClipboardItemType? | nil | 분류 캐시 |
| `imageFileName` | String? | nil | 단일 이미지 파일명 |
| `imageFileNames` | [String] | [] | 다중 이미지 파일명 |
| `contentType` | ClipboardContentType | .text | text/image/emoji/mixed |

### 3.2 SmartClipboardHistory
저장 위치: `smart.clipboard.history.data`. 임시 항목은 7일 후 자동 삭제, 최대 100개 유지(Pro)/50개(무료).

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | UUID | 식별자 |
| `content` | String | 클립보드 텍스트 |
| `copiedAt` | Date | 복사 시각 |
| `isTemporary` | Bool | 7일 후 자동 삭제 여부 |
| `contentType` | ClipboardContentType | text/image/mixed |
| `imageData` | String? | Base64 인코딩 이미지 |
| `detectedType` | ClipboardItemType | 자동 분류 결과 |
| `confidence` | Double | 0.0 ~ 1.0 |
| `userCorrectedType` | ClipboardItemType? | 사용자 수동 수정 |
| `sourceApp` | String? | 출처 앱 (감지 가능 시) |
| `tags` | [String] | 사용자 태그 |

### 3.3 Combo / ComboItem
저장 위치: `combos.data`. 다단계 자동 입력 정의.

```
Combo {
  id: UUID
  title: String
  items: [ComboItem]            // order 기준 자동 정렬
  interval: TimeInterval = 2.0  // 단계 간격(초)
  createdAt, lastUsed
  category: String
  useCount: Int
  isFavorite: Bool
}

ComboItem {
  id: UUID
  type: .memo | .clipboardHistory | .template
  referenceId: UUID             // 참조 대상 ID
  order: Int                    // 실행 순서
  displayTitle: String?
  displayValue: String?         // 템플릿 치환 결과 미리 저장
}
```

### 3.4 ClipboardItemType (25종)
이메일, 전화, 주소, URL, 카드번호, 계좌번호, 여권번호, 통관번호, 우편번호, 이름, 생년월일, 세금번호, 보험번호, 차량번호, IP주소, 회원번호, 송장번호, 예약번호, 진료기록번호, 사번/학번, 이미지, 텍스트, IBAN, SWIFT/BIC, VAT, Crypto Wallet, PayPal Link.
각 케이스는 `icon`(SF Symbol) + `color`(문자열 색상키)를 가진다.

### 3.5 PlaceholderValue
템플릿 토큰의 과거 입력값을 보관. App Group `UserDefaults`에 `placeholder_values_{토큰}` 키로 저장.

```
PlaceholderValue {
  id: UUID
  value: String
  sourceMemoId: UUID
  sourceMemoTitle: String
  addedAt: Date
}
```

---

## 4. 핵심 기능 명세

### F1. 메모 관리

**목표**: 사용자가 자주 쓰는 텍스트/이미지를 빠르게 저장·검색·재사용.

| 기능 | 동작 |
|------|------|
| 추가 | `MemoStore.save(memos:type:.memo)` 로 영속화. 무료 사용자는 `freeMemoLimit=10` 초과 시 차단 (`ProFeatureManager.canAddMemo`). |
| 수정 | 동일 ID 메모 갱신, `lastEdited` 자동 갱신. |
| 삭제 | 배열에서 제거 후 저장. 첨부 이미지가 있으면 `deleteImage(fileName:)` 로 함께 정리. 템플릿이면 `deletePlaceholderValues(fromMemoId:)`. |
| 즐겨찾기 | `isFavorite` 토글, 배지 표시. |
| 사용 카운트 | 키보드/Combo에서 사용 시 `incrementClipCount(for:)` 호출. `clipCount += 1`, `lastUsedAt = Date()`, 키보드 절약 시간 트래킹 갱신. |
| 보안 메모 | `isSecure = true`면 본문 표시 전 `BiometricAuthManager.authenticateUser` 게이팅. |
| 카테고리 | 사용자 정의 + Locale 시드 (Section 8). |
| 이미지 메모 | App Group `Images/` 폴더에 PNG로 저장. 무료 사용자는 `freeImageMemoLimit=5` 까지. |

**마이그레이션**: 신규 형식 디코딩 실패 시 `OldMemo` → `Memo` 폴백. 카테고리 → 테마 마이그레이션 자동 수행.

---

### F2. 스마트 클립보드

**서비스**: `ClipboardClassificationService.shared`

#### 2.1 자동 분류 우선순위
글로벌 타깃 v4.0 기준 우선순위:
1. IBAN (mod-97 검증)
2. SWIFT/BIC
3. VAT
4. Crypto Wallet (BTC/ETH 등 형식)
5. PayPal Link (`paypal.me/...`)
6. 신용카드 (Luhn 체크)
7. 이메일
8. URL
9. 여권번호 (M/S + 8자리)
10. 통관번호 (P + 12자리)
11. IP 주소 (IPv4/IPv6)
12. 생년월일
13. 우편번호 (KR 5자리, 그 외 형식)
14. 전화 (E.164 + KR 010)
15. 계좌번호
16. 이름
17. (그 외) → `.text`, confidence 0.5

#### 2.2 공개 API
```swift
class ClipboardClassificationService {
    static let shared: ClipboardClassificationService

    func classify(content: String) -> (type: ClipboardItemType, confidence: Double)
    func resolvedType(for memo: Memo) -> ClipboardItemType?
    func invalidateResolvedType(for memoId: UUID)
    func updateClassificationModel(content: String, correctedType: ClipboardItemType)
    func checkClipboard() -> SmartClipboardHistory?   // iOS only
    func hasImage() -> Bool
    func hasText() -> Bool
}
```

#### 2.3 신뢰도 (confidence) 정책
- 형식 검증 통과 + 정규식 일치 → ≥ 0.9
- 형식 일치하지만 모호 → 0.7 ~ 0.85
- 미분류 텍스트 → 0.5

#### 2.4 자동 정리
- 임시 항목(`isTemporary=true`)은 7일 후 자동 삭제
- 최대 항목 수: 무료 50개, Pro 100개 (`ProFeatureManager.clipboardHistoryLimit()`)

---

### F3. 커스텀 키보드 (ClipKeyboardExtension)

| 항목 | 동작 |
|------|------|
| 메모 표시 | App Group을 통해 `memos.data` 읽기. 무료는 `keyboardMemoDisplayLimit=10` 까지만 노출. |
| 클립 사용 | 탭 시 메인 앱 → `incrementClipCount` 트리거 (App Group UserDefaults flag). |
| 클립보드 인식 | `ClipboardClassificationService.checkClipboard()` 로 현재 클립 분류 표시. |
| 카테고리 필터 | `CategoryStore.shared.allCategories` 동일 순서로 노출. |
| 템플릿 입력 | 토큰 입력 UI에서 `PlaceholderValue` 히스토리 자동 추천. |
| Full Access 권한 | RequestsOpenAccess = NO (기본). 클립보드 접근 불요 시 권한 없이 동작. |

---

### F4. macOS 앱 (ClipKeyboard.tap)

Mac Catalyst 기반. iOS 코드를 공유하되 다음만 macOS 전용:
- `MenuBarManager`: 메뉴바 아이콘 + 메뉴 (메모 빠른 접근, 환경설정 열기)
- `GlobalHotkeyManager`: 시스템 전역 단축키 (사용자 정의 키 조합으로 메모 즉시 입력)
- Command Menu (메뉴바의 앱 메뉴 항목)
- 조건부 컴파일: `#if targetEnvironment(macCatalyst)`

---

### F5. Combo 시스템

**서비스**: `ComboExecutionService.shared`

#### 5.1 상태 머신
```
.idle → .running(currentIndex, totalCount)
       ↔ .paused(currentIndex)
.running → .completed
.running → .error(message)
```

#### 5.2 공개 API
```swift
class ComboExecutionService: ObservableObject {
    @Published var state: ComboExecutionState = .idle
    @Published var currentItemIndex: Int = 0
    var progress: Double { get }            // 0.0 ~ 1.0
    var currentItem: ComboItem? { get }

    func startCombo(_ combo: Combo)
    func pauseCombo()
    func resumeCombo()
    func stopCombo()
}
```

#### 5.3 동작 규칙
- 실행 중에 다른 Combo `start` 호출은 무시 (idempotent)
- 각 단계는 `combo.interval` 초 간격으로 클립보드에 복사
- 템플릿 항목은 `TemplateVariableProcessor.process(_:)` 로 `{날짜}`, `{시간}` 등 자동 변수 치환
- 잘못된 `referenceId` 항목은 스킵 (실행 중단 X)
- 완료 시 `useCount += 1`, `.reviewTriggerComboCompleted` 노티 발송 → ReviewManager 트리거

#### 5.4 Combo 항목 검증
- `MemoStore.validateComboItem(_:) -> Bool` : 참조 대상 존재 확인
- `MemoStore.cleanupCombo(_:) -> Combo` : 무효 항목 제거
- `MemoStore.getComboItemValue(_:) -> String` : 실제 입력 값 해석 (memo / template displayValue / clipboardHistory)

---

### F6. CloudKit 백업

**서비스**: `CloudKitBackupService.shared`

| 기능 | 동작 |
|------|------|
| 계정 확인 | `checkAccountStatus()` → `isAuthenticated` 갱신 |
| 백업 | `backupData() async throws` — 메모/스마트클립/Combo를 별도 CKAsset으로 업로드. 이미지 포함. |
| 복구 | `restoreData() async throws` — 다운로드 후 MemoStore에 반영. |
| 자동 백업 | `enableAutoBackup()` / `disableAutoBackup()` |
| 삭제 | `deleteBackup() async throws` |
| 게이팅 | `ProFeatureManager.isCloudBackupAvailable` (`hasFullAccess` 한정) |
| 상태 플래그 | `isBackingUp`, `isRestoring`, `lastBackupDate` |

---

### F7. OCR 지원

**서비스**: `OCRService` (iOS 한정, Vision Framework)
- 한국어 + 영어 인식
- 카드 정보 / 주소 자동 파싱
- 결과는 `ClipboardClassificationService` 로 전달되어 자동 분류됨

---

### F8. 카테고리 관리 (CategoryStore)

저장 위치: App Group UserDefaults (`user.categories.v1`).

| API | 설명 |
|-----|------|
| `add(_ name)` | 중복 제외, 공백 trim. |
| `rename(from:to:)` | 중복/동일 이름 시 false. |
| `remove(_ name)` | `protectedCategories = ["기본","텍스트","이미지"]` 는 삭제 불가. |
| `move(from:to:)` | 사용자 순서 변경. |
| `resetToDefaults()` | Locale 기반 기본값으로 초기화. |
| `localeDefaults()` | 글로벌 공통 + 국가별 특화 항목 결합. |

첫 실행 시 `Locale.current.regionCode` 기준 시드 카테고리 자동 생성.

---

### F9. 보안 메모 (BiometricAuthManager)

```swift
enum BiometricType { case none, touchID, faceID }

class BiometricAuthManager {
    static let shared: BiometricAuthManager
    func biometricType() -> BiometricType
    func authenticateUser(reason:String, completion:(Bool, Error?) -> Void)
}
```

- 기기 지원 여부에 따라 Touch ID / Face ID / 없음 분기
- 보안 메모(`isSecure=true`) 표시 전 호출
- 게이팅: `ProFeatureManager.isBiometricLockAvailable`

---

### F10. Pro / 무료 / 7일 체험 (ProFeatureManager)

| 항목 | 값 |
|------|-----|
| 무료 메모 한도 | 10 |
| 무료 Combo 한도 | 3 |
| 무료 템플릿 한도 | 3 |
| 무료 클립 히스토리 | 50 (Pro 100) |
| 무료 이미지 메모 | 5 |
| 체험 기간 | 7일 (1회 한정) |
| 가격 | $9.99 일시불 |

#### 10.1 핵심 플래그
```
hasFullAccess = isPro || isGrandfathered || isInTrial
isPro          = TestFlight || group UserDefaults["clipkeyboard_is_pro"]
isGrandfathered = hasGrandfatheredPurchase || wasExistingFreeUser
isInTrial      = trialStartedAt != nil && monotonicNow < startedAt + 7d
```

#### 10.2 시계 조작 방어
`monotonicNow` = `max(now, lastSeen)`. 시계를 뒤로 돌려도 체험 잔여 시간이 늘어나지 않는다.

#### 10.3 한도 체크 API
```swift
ProFeatureManager.canAddMemo(currentCount: Int) -> Bool
ProFeatureManager.canAddCombo(currentCount: Int) -> Bool
ProFeatureManager.canAddTemplate(currentCount: Int) -> Bool
ProFeatureManager.canAddImageMemo(currentImageMemoCount: Int) -> Bool
ProFeatureManager.clipboardHistoryLimit() -> Int
ProFeatureManager.startTrial() -> Bool
```

---

### F11. 리뷰 요청 (ReviewManager)

#### 11.1 트리거
| 키 | 조건 | 1회 한정 |
|----|------|---------|
| `firstPaste` | 키보드 첫 붙여넣기 성공 | ✅ |
| `combo` | Combo 완료 | ✅ |
| `powerUser` | 클립 ≥10개 + 설치 후 3일 + 키보드 ≥5회 | ✅ |
| 클래식 | 앱 실행 ≥5회 + 메모 ≥3개 | 90일 쿨다운 |

#### 11.2 배너
- 클립 저장 ≥ 5회면 노출 가능
- "나중에" 선택 시 7일 후 재노출
- "리뷰 남기기" 선택 시 영구 닫기

---

## 5. 저장 구조 요약

### 5.1 App Group 컨테이너 파일
| 파일 | 내용 |
|------|------|
| `memos.data` | `[Memo]` JSON |
| `clipboard.history.data` | `[ClipboardHistory]` (레거시) |
| `smart.clipboard.history.data` | `[SmartClipboardHistory]` |
| `combos.data` | `[Combo]` |
| `Images/{fileName}` | PNG 이미지 |

### 5.2 App Group UserDefaults (`group.com.Ysoup.TokenMemo`)
| 키 | 의미 |
|----|------|
| `clipkeyboard_is_pro` | Pro 구매 |
| `clipkeyboard_was_pro_at_v3` | v3.x Pro 그랜드파더 |
| `clipkeyboard_existing_free_user` | v3.x 무료 유저 |
| `clipkeyboard_v4_grace_memos` | v4 grace 상태 |
| `clipkeyboard_v4_grace_banner_dismissed` | 배너 닫음 |
| `clipkeyboard_trial_started_at` | 체험 시작 epoch |
| `clipkeyboard_trial_last_seen` | 단조 시간 갱신용 |
| `user.categories.v1` | 사용자 카테고리 |
| `user.categories.seeded.v1` | 시드 완료 플래그 |
| `placeholder_values_{토큰}` | 템플릿 후보 값 |

### 5.3 표준 UserDefaults
| 키 | 의미 |
|----|------|
| `onboarding` | 온보딩 노출 여부 |
| `useCaseSelection` | 유스케이스 선택 노출 여부 |
| `appLaunchCount` | 앱 실행 횟수 |
| `keyboard_use_count`, `clip_save_count` | 리뷰 트리거 카운트 |
| `app_install_date` | 설치일 |

---

## 6. 다국어 지원

- 모든 사용자 노출 문자열은 `NSLocalizedString` 처리
- 지원 언어: 한국어(ko), 영어(en)
- enum의 `rawValue` 직접 노출 금지 → `localizedName` 계산 프로퍼티 사용
- Xcode String Catalog 사용

---

## 7. 비기능 요구사항

| 항목 | 요구사항 |
|------|----------|
| iOS 최소 | 17.0 |
| 메모리 | 이미지 1024px 제한, JPEG 0.7 압축 |
| 응답성 | UI 렌더 시 분류 결과 캐시 (`resolvedType`) |
| 동시성 | `@Published` 갱신은 메인 스레드, classification cache는 thread-safe |
| 프라이버시 | 클립보드 데이터는 로컬/iCloud 외부로 전송하지 않음 |

---

## 8. 테스트 매트릭스

| 영역 | 테스트 파일 |
|------|-------------|
| 데이터 모델 | `ModelTests.swift` |
| MemoStore CRUD | `MemoStoreTests.swift` |
| 분류 (간단) | `ClipboardDetectionTests.swift` |
| 분류 (전체 25종) | `ClipboardClassificationServiceTests.swift` |
| Combo 실행 | `ComboExecutionServiceTests.swift` |
| CloudKit | `CloudKitBackupServiceTests.swift` |
| Pro/체험/한도 | `ProFeatureManagerTests.swift` |
| 카테고리 | `CategoryStoreTests.swift` |
| 생체인증 | `BiometricAuthManagerTests.swift` |
| 데이터 매니저 | `DataManagerTests.swift` |
| 리뷰 매니저 | `ReviewManagerTests.swift` |
| 플레이스홀더 | `PlaceholderValueTests.swift` |
| 사용 카운트/이미지 | `MemoStoreUsageAndImageTests.swift` |

---

## 9. 미구현 / 향후 작업

- [ ] 사용 카운트 동기화의 키보드 익스텐션 단방향 보강
- [ ] 데이터 마이그레이션 자동화 테스트 강화 (OldMemo → Memo)
- [ ] OCR 서비스 단위 테스트 (실제 이미지 의존성 → 통합 테스트로 분리)
- [ ] CloudKit Asset 인코딩/디코딩 분리 테스트
