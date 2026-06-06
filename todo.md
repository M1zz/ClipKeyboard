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

---

# 기본 제공 카테고리 (타입별 모아보기) (2026-06-06)

## 요청
- 템플릿만 / 메모+템플릿 / 이미지 메모만 / 콤보만 처럼 앱이 미리 만들어 두는 카테고리를
  제공하고, 사용자가 켜고 끌 수 있게. (필터가 아니라 "카테고리"로 — 사용자에겐 일반
  카테고리와 동일하게 보이되 멤버십만 타입 기준으로 판정)

## 구현 ✅
- [x] `BuiltInCategory` enum 신설 (templates/textMemos/images/combos)
  - displayName·icon·tint + `matches(Memo)` 타입 판정 (isTemplate / contentType / isCombo)
- [x] `CategoryTab`에 `.builtIn(BuiltInCategory)` 케이스 추가 (isBuiltIn=true → 칩 삭제버튼 없음)
- [x] ViewModel: `enabledBuiltInCategories` @Published, `allCategoryTabs`·`memos(for:)` 확장,
      loadCustomCategories에서 App Group 키 로드 + 끈 탭이 선택중이면 .all로 복귀
- [x] CategoryStore: `enabledBuiltInCategories_v1` 영구 저장 + `isBuiltInEnabled/setBuiltInEnabled`
- [x] CategorySettings: "기본 제공 카테고리" 섹션 + 토글 4개
- [x] ClipKeyboardList: tabIndicatorColor·tabBackgroundColor·tabPageView 스위치에 .builtIn 처리
- [x] Localizable.xcstrings: 신규 키 5개 ko/en/id 추가
- [x] ClipKeyboard 스킴 빌드 성공

## 비고
- 켜면 메모 유무와 무관하게 탭 노출(사용자가 명시적으로 켰으므로) — 빈 경우 empty state 표시
- 키보드 익스텐션도 같은 App Group 키를 읽으면 동일 카테고리 활용 가능(추후)

---

# 메모 순서 바꾸기(흔들기/드래그) + Today 스타일 탭 애니메이션 (2026-06-06)

## 요청
- 메모 길게 누르기 → "수정" 위에 "순서 바꾸기" 버튼 → iOS 홈화면처럼 카드가 오들오들
  떨면서 드래그앤드롭으로 그리드 순서 변경. 순서 영구 저장.
- 메모 탭 시 App Store Today 카드처럼 폭 눌렸다 부드럽게 올라오는 애니메이션.

## 결정 (사용자 확인)
- 순서 범위: **전체 메모 한 벌**(전체 탭 기준). 재정렬 모드는 전체 목록을 보여줌.
- 즐겨찾기 고정: **해제** — 수동 순서를 한 번이라도 쓰면 즐겨찾기 맨위 고정 풀고 내 순서 그대로.

## 구현 ✅
- [x] sortMemos: manualOrderActive면 저장된 id 순서대로 정렬(없는 새 메모는 맨 위). 아니면 기존 즐겨찾기→최근순.
- [x] ViewModel: isReorderMode/reorderList + enterReorderMode/exitReorderMode/commitReorder.
      manualOrder/manualOrderActive는 App Group UserDefaults(memoManualOrder_v1 / memoManualOrderActive_v1)에 저장.
- [x] MemoActionSheet: onReorder 콜백 + "순서 바꾸기" 행(수정 위). 시트 높이 470→530.
- [x] memoCardSurface(memo:) 추출 — 제스처 없는 카드 비주얼을 그리드 셀/재정렬 셀이 공유.
- [x] Today 스타일 press: pressedMemoId + scaleEffect(0.95) + spring(response 0.34, damping 0.62).
      onPressingChanged에서 set/reset, 롱프레스 완료 시 reset. reduceMotion이면 비활성.
- [x] reorderModeView(fullScreenCover): 흔들리는 LazyVGrid + onDrag(명시 preview)/onDrop 라이브 재배치.
      MemoReorderDropDelegate(dropEntered에서 move+haptic), 여백 드롭용 ReorderResetDropDelegate.
      wiggle 회전 ±1.4°, index별 delay로 유기적. reduceMotion/드래그 중엔 정지.
- [x] Localizable.xcstrings: "순서 바꾸기"/"카드를 끌어 순서를 바꾸세요"/"드래그하여 순서를 바꿉니다" ko/en/id.
- [x] ClipKeyboard 스킴 빌드 성공.

## 검증 필요 (실기기/시뮬레이터)
- [ ] 흔들기·드래그 재배치 부드러움, 미리보기 또렷함, 여백 드롭 복구
- [ ] 완료 후 메인 그리드 순서 반영 + 앱 재시작 후 순서 유지
- [ ] Today 탭 press 애니메이션 느낌
- [ ] 새 메모 추가 시 맨 위 노출(순서 미등록) 확인
