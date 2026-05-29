# ClipKeyboard 리팩토링 진행 상황

## Phase 1: Foundation (Storage + Repository) ✅ 완료

- [x] `Data/Storage/AppGroupStorage.swift` - App Group 스토리지 래퍼
- [x] `Domain/Repository/MemoRepositoryProtocol.swift`
- [x] `Domain/Repository/ClipboardRepositoryProtocol.swift`
- [x] `Domain/Repository/ComboRepositoryProtocol.swift`
- [x] `Data/Repository/MemoRepository.swift` - MemoStore 위임
- [x] `Data/Repository/ClipboardRepository.swift`
- [x] `Data/Repository/ComboRepository.swift`

## Phase 2: Use Cases ✅ 완료

- [x] `Domain/UseCase/ClassifyClipboardUseCase.swift`
- [x] `Domain/UseCase/SaveMemoUseCase.swift`

## Phase 3: ViewModel ✅ 완료

- [x] `Presentation/MemoAdd/MemoAddViewModel.swift`

## Phase 4: DI Container ✅ 완료

- [x] `App/AppDependencies.swift`

## Phase 5: Xcode 프로젝트 파일 등록 ✅ 완료

- [x] PBXFileReference 등록 (11개 파일)
- [x] PBXBuildFile 등록 (11개 파일, ClipKeyboard 타겟만)
- [x] PBXGroup 생성 (Data, Data/Storage, Data/Repository, Domain, Domain/Repository, Domain/UseCase, Presentation, Presentation/MemoAdd, App)
- [x] PBXSourcesBuildPhase 등록

## Phase 6: 구조 개선 ✅ 완료

- [x] ClipKeyboardApp.swift에 AppDependencies 주입 (`.environmentObject(deps)`)
- [x] ProStatusManager 이중 상태 제거 (Combine 구독 제거, StoreManager 직접 호출 방식 유지)
- [x] MemoStore God Object 분해:
  - [x] ClipboardClassificationService → 별도 파일 추출 (678줄 → 540줄 → 삭제)
  - [x] OCRService → 별도 파일 추출
  - [x] MemoStore.swift: 1,220줄 → 678줄 (분류/OCR 서비스 분리)

## Phase 7: 최종 완료 ✅

- [x] MemoAdd.swift의 @State 변수를 MemoAddViewModel로 완전 연결 (recentlyUsedCategories, updateRecentlyUsedCategories View 중복 제거, selectCategory 메서드 추가)
- [x] ClipKeyboardList ViewModel 분리 (ClipKeyboardListViewModel 신규 생성, View는 isSearchBarVisible만 유지)
- [x] 미커밋 파일 전체 커밋 완료

## 전체 완료 🎉

---

# v4.0 이전 유료 구매자 Pro 복구 (2026-05-29)

## 문제
- 앱은 v4.0 출시(2026-02-21 00:14 KST) 전까지 **유료 앱(다운로드 유료)**, 이후 **무료 + Pro IAP**로 전환.
- 2024년 유료 구매자가 v4.0 업데이트 후 Pro 기능이 잠겨 "다시 사야 하냐"는 피드백.
- 원인: 그랜드파더 부여가 (1) 신규 Pro IAP 영수증, (2) 기기 내 메모 개수 휴리스틱에만 의존.
  과거 유료 구매자는 신규 IAP 영수증이 없고, 재설치/기기변경 시 메모도 0개 → 신규 무료 유저로 오인.
  Apple 정식 수단인 `AppTransaction`(최초 구매일)을 전혀 확인하지 않던 것이 핵심 결함.

## 해결
- [x] `ProFeatureManager.grandfatherPaidUserIfNeeded()` 추가
  - `AppTransaction.shared.originalPurchaseDate < freemiumReleaseDate`이면 `grandfatheredPurchaseKey` 영구 부여
  - iOS의 `originalAppVersion`은 빌드번호라 신뢰 불가 → `originalPurchaseDate`로 판별
  - 컷오프: `freemiumReleaseDate = 1_771_686_000` (2026-02-22 00:00 KST, 출시일 +여유)
  - idempotent (이미 그랜드파더면 즉시 return)
- [x] `ClipKeyboardApp.init()`에서 매 실행 검증 Task 추가 (bootstrap_done 1회 가드와 무관 → 이미 막힌 유저 자동 구제)
- [x] `StoreManager.restorePurchases()`에서도 재검증 (이전 구매 복원 버튼으로 즉시 해제)
- [x] 부여 직후 `ProStatusManager.objectWillChange.send()`로 UI 갱신
- [x] ClipKeyboard 스킴 빌드 성공 확인

## 검증 필요 (실기기/Sandbox)
- [ ] Sandbox/TestFlight에서 originalPurchaseDate 동작 확인 (Xcode 환경은 originalPurchaseDate가 컷오프 이전이라 항상 부여됨에 유의)
- [ ] 실제 2024 구매 계정으로 업데이트 후 Pro 자동 복구 확인
