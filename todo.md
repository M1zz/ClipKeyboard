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

---

# 검색 후 키보드 안 올라옴 + "전체" 탭 → "기본" 탭 교체 (2026-06-08)

## 요청 1: 메인 페이지에서 검색 시 키보드가 안 올라옴
- 원인: 검색바(searchBarInlineSection)가 나타날 때 TextField에 포커스를 주는
  코드(@FocusState)가 없어 키보드가 자동으로 뜨지 않음.
- [x] `@FocusState private var isSearchFieldFocused` 추가
- [x] TextField에 `.focused($isSearchFieldFocused)` + `.submitLabel(.search)`
- [x] 검색 토글 버튼: 열릴 때 0.35s 뒤(스프링 애니메이션 후 마운트) 포커스, 닫을 때 해제

## 요청 2: "전체" 탭 제거 + 카테고리 없는 메모를 "기본"으로
- 결정(사용자 확인): "전체" 탭만 제거 / 비어있는 category만 "기본"으로.
- 설계: `.all`은 카테고리 기능 OFF용 단일 페이지로 유지하고, 탭 목록에서만 제거.
  새 `.basic`("기본") 탭이 첫 탭 — **커스텀 카테고리에 속하지 않은 모든 메모 catch-all**
  (기본/빈값/삭제된 카테고리 고아 포함) → "전체"가 사라져도 메모 누락 없음.
- [x] `CategoryTab`에 `.basic` 추가 (displayName "기본", storageKey "__basic__", icon tray.full.fill)
- [x] ViewModel: 기본 선택 탭 `.basic`, allCategoryTabs 선두 `.basic`, `basicBucketMemos` 추가,
      memos(for:)·restore·delete/hide/load 리셋 지점 모두 `.all`→`.basic`
- [x] loadMemos: `normalizeEmptyCategories` — 빈 category를 "기본"으로 정규화(멱등, 변경 시만 저장)
- [x] ClipKeyboardList: allTabScrollView를 `func(memos:)`로 전환(전체/기본 데이터 소스 분리),
      tabIndicatorColor·tabBackgroundColor·tabPageView·addCard 스위치에 `.basic` 처리
- [x] "기본" 문자열은 String Catalog에 기존재(en "General", id 포함) — 추가 작업 불필요
- [x] ClipKeyboard 스킴 빌드 성공

## 검증 필요 (실기기/시뮬레이터)
- [ ] 메인에서 돋보기 → 검색바와 함께 키보드 자동 노출
- [ ] 탭 바에 "전체" 없이 "기본"이 첫 탭으로 표시
- [ ] 빈 카테고리 메모가 "기본" 탭에 모이는지 / 커스텀 카테고리 메모는 해당 탭에만
- [ ] 카테고리 기능 OFF 시 단일 페이지에 모든 메모 정상 노출

---

# 색맹용 메모 타입 테두리를 접근성 설정으로 제어 (2026-06-08)

## 요청
- 색맹용 메모 테두리(템플릿/콤보/보안 타입 구분)를 항상 표시하지 말고 접근성 설정으로 제어.

## 결정 (사용자 확인)
- iOS 시스템 "색상 없이 구별"(Differentiate Without Color) 연동 — 별도 인앱 토글 없이
  `@Environment(\.accessibilityDifferentiateWithoutColor)`로 제어. 켜면 테두리 표시, 끄면 숨김(기본).

## 구현 ✅
- [x] ClipKeyboardList: `@Environment(\.accessibilityDifferentiateWithoutColor)` 추가,
      `memoTypeBorder`가 꺼져 있으면 `.clear` 반환 (메인 메모 그리드 카드)
- [x] KeyboardView(익스텐션): 동일 환경값 추가, `typeStyle`이 꺼져 있으면 clear 반환
- [x] KeyboardLayoutSettings의 KeyboardPreviewView: `typeBorder`도 게이팅(실제 키보드와 일치)
- [x] AccessibilityGuideView "색상 없이 구별" 항목: 설명을 메모/키보드 테두리 제어로 갱신,
      경로를 "색상 필터" → "색상 없이 구별"로 정정
- [x] Localizable.xcstrings: 신규 키 2개(ko 소스 + en) 추가, JSON 유효성 확인
      (구 키 2개는 미사용 → Xcode가 stale 표시)
- [x] ClipKeyboard 스킴 빌드 성공(익스텐션 포함)

## 비고
- 기본값(설정 OFF): 메모 카드/키보드 칸에 타입 테두리 없음 → 더 깔끔.
  타입 구분이 필요한 색맹 사용자는 iOS "색상 없이 구별"을 켜면 색+패턴 테두리 노출.
- 키보드 익스텐션도 SwiftUI 트레잇으로 동일 접근성값을 받으므로 메인 앱과 일관 동작.

## 검증 필요 (실기기)
- [ ] iOS 설정 → 손쉬운 사용 → 디스플레이 및 텍스트 크기 → "색상 없이 구별" OFF: 테두리 없음
- [ ] ON으로 전환: 메인 메모 그리드 + 키보드에 타입 테두리(보라 실선/주황 dash/회색 dot) 표시
- [ ] 키보드 레이아웃 설정 미리보기가 실제 키보드와 동일하게 반영

---

# 우상단 심볼(즐겨찾기 하트 + 카테고리 심볼)을 접근성/토글로 제어 (2026-06-08)

## 요청
- 즐겨찾기 하트 심볼도 항상 보여주지 말 것. 접근성과 연동해 보여주고,
  설정에서 카테고리 심볼 표시 여부를 토글로 제공.

## 결정 (사용자 확인)
- 표시 조건: **접근성 OR 토글** — iOS "색상 없이 구별" ON 또는 설정 "카테고리 심볼" 토글 ON.
- 설정 토글 기본값: **OFF**(기본은 깔끔). 하트·카테고리 심볼 모두 동일 적용.

## 구현 ✅
- [x] ClipKeyboardList: `cornerSymbolVisible = differentiateWithoutColor || categoryBadgeVisible`
      computed 추가. 우상단 심볼 블록(즐겨찾기 하트 + 카테고리 심볼)을 이 게이트로 감쌈.
- [x] `categoryBadgeVisible` 기본값 true → **false**로 변경 (View + DisplaySettingsView 양쪽)
- [x] DisplaySettingsView 푸터 텍스트 갱신(하트+카테고리 심볼, 접근성 자동 표시, 기본 OFF 안내)
- [x] Localizable.xcstrings: 신규 푸터 키(ko+en) 추가, 구 키는 미사용(stale). JSON 유효성 확인
- [x] ClipKeyboard 스킴 빌드 성공

## 비고
- 즐겨찾기는 심볼이 꺼져도 카드 **배경색(clipFavorite 분홍)**으로 여전히 식별 가능 → 정보 손실 없음.
- 기존 사용자도 키 미설정 시 기본 false 적용 → 우상단 심볼이 사라짐(의도된 동작).
- "카테고리 배지 끄기" 넛지는 categoryBadgeVisible=true일 때만 떠서, 기본 OFF에선 자연히 비노출.

## 검증 필요 (실기기)
- [ ] 기본 상태: 우상단에 하트/카테고리 심볼 없음(즐겨찾기는 분홍 배경으로 구분)
- [ ] iOS "색상 없이 구별" ON: 하트·카테고리 심볼 자동 표시
- [ ] 설정 → 디스플레이 → 메모 표시 → "카테고리 심볼" ON: 심볼 표시 / OFF: 숨김
- [ ] 설정 미리보기 토글 즉시 반영

---

# 데이터 모델 단순화: 모든 것을 메모/템플릿으로 통합 (2026-06-08)

## 요청
- 모든 데이터는 메모이거나 템플릿. "메모+템플릿"은 그냥 템플릿. 콤보는 "메모 안에 메모들".
  → 메모/템플릿만 남기고 Combo·attachedTemplateId 정리. (계획 승인 후 진행)

## 확정 설계
- 콤보 = **기존 메모 참조** `Memo.childMemoIds: [UUID]` (순서). 비어있지 않으면 콤보.
- attachedTemplateId = **본문 합쳐 일반 메모로** (TemplateVariableProcessor.compose).
- 콤보 입력 = **순차 입력 유지**(interval). 키보드는 정책 A(탭 1회→자식 순차 insert).

## 구현 ✅ (전 타깃 빌드 그린: iOS앱+익스텐션+위젯, macOS tap)
- [x] Memo 모델: childMemoIds/comboInterval 추가, isCombo **계산형**(`!childMemoIds.isEmpty`),
      comboValues/currentComboIndex/attachedTemplateId **제거**. 3개 Memo 정의 동기화.
- [x] MemoStore: childMemos/resolveChildValues/pruneMissingChildren 추가.
- [x] ComboExecutionService: startCombo(Memo) + childMemoIds 기반 순차 클립보드 복사.
- [x] 키보드: handleComboMemoIfNeeded 정책A 재작성, handleAttachedTemplate/Skip 제거, canSplit/bypass 정리.
- [x] UI: ComboList를 콤보-메모 매니저로 전면 재작성(자식 메모 피커), ComboEditSheet→ComboAddEditView redirect,
      MemoAdd에서 콤보/attached 섹션 제거, MemoAddViewModel/SaveMemoUseCase 정리.
- [x] ClipKeyboardList body가 콜드 타입체크 한계 초과 → mainColumn/screenBody/screenL3~L8 computed로 분할.
- [x] 마이그레이션 `migrateComboModelIfNeeded`(플래그 comboModelUnifyMigrated_v1, onAppear 맨앞):
      원본 JSON에서 레거시 필드 선읽기 → 메모내장콤보/attached/combos.data 변환, combos.data 삭제.
- [x] 테스트: ComboExecutionServiceTests 신모델 재작성, AttachedTemplateTests→콤보 모델 테스트.
- [x] Localizable.xcstrings 신규 키 2개(ko+en).

## 비고 / 남은 것
- 레거시 `Combo`/`ComboItem`/`ComboItemType` 타입 + MemoStore combo CRUD + CloudKit combosAsset는
  **마이그레이션 디코드용으로 의도적으로 유지**(죽은 코드). pbxproj 수술 회피.
- ComboItemPickerView/ComboTemplateInputView도 미사용이나 컴파일됨(레거시 타입 참조).
- **기존 실패(무관)**: CategoryStoreTests.swift:127 `CategoryStore.localeDefaults` — 내 변경 아님(git 깨끗).
  테스트 타깃 전체 빌드는 이 한 줄 때문에 실패하나 콤보/attached 테스트 자체는 정상.

## 검증 필요 (실기기/업그레이드)
- [ ] 업그레이드: 메모내장콤보/attached/플랫콤보 각 1개 → 첫 실행 변환·combos.data 삭제·재시작 무중복
- [ ] 콤보 생성/편집(ComboList): 자식 메모 선택·순서·interval, 실행 시 순차 복사 + 완료 clipCount↑
- [ ] 키보드 콤보 탭: 자식 값 interval 순차 입력
- [ ] 메모 리스트/검색/키보드에 콤보 배지·미리보기 정상

## 마이그레이션 하위호환 강화 (2026-06-09)
- [x] **init 맨 앞에서 실행** — bootstrapV4GrandfatherFlags의 load()(구 카테고리 자동 재저장)가
      레거시 키를 지우기 전에 변환. onAppear 호출은 방어용 유지(멱등).
- [x] **레거시 데이터 감지 시 재실행** — `hasLegacyComboData()`(combos.data 존재 OR memos.data 원본에
      `"isCombo":true`/`"attachedTemplateId":"`)가 참이면 플래그 set돼 있어도 재변환 → 옛 CloudKit 백업 복원 대비.
- [x] **CloudKit 복원 시 플래그 리셋** — saveRestoredData에서 comboModelUnifyMigrated_v1=false →
      복원된 레거시 데이터가 다음 실행에 신 모델로 재변환.
- [x] **변환 견고화** — 빈/공백 comboValue·빈 콤보·값 없는 항목 스킵(잡 메모 방지), 자식 0개 콤보 미생성,
      변경 있을 때만 원자적 save(실패 시 플래그 미set→재시도), OldMemo 등 과거 포맷도 id로 디코드.
- [x] ClipKeyboard 스킴 빌드 성공

---

# 구분 장치 심플화: 기본 제목만 + 마스터 토글 옵션 (2026-06-09)

## 요청
- 색맹/구분 장치는 좋지만, 기본은 최대한 심플(인지부하↓). 지금까지의 장치들을 옵션으로 제공.

## 결정(사용자)
- 기본 모습 = **제목만** (아이콘/배지/테두리/우상단 심볼/배경색 전부 OFF). 이미지 콘텐츠는 유지.
- 제어 = **단일 마스터 토글** "메모 구분 표시". iOS "색상 없이 구별" 켜면 자동 ON.

## 구현 ✅ (iOS앱+키보드+위젯+macOS 빌드 그린)
- [x] `showVisualCues`(App Group UD, 기본 false) + `visualCuesVisible = differentiateWithoutColor || showVisualCues`.
- [x] ClipKeyboardList 카드: 상단 행(타입 아이콘+우상단 심볼)·타입 테두리·배경색·cardIsColored 전부 게이팅.
      배지 nudge는 "구분 표시 끄기" 제안으로 의미 전환.
- [x] MemoRowView(검색 행): leadingIcon·배지·하트 게이팅.
- [x] KeyboardView: typeStyle(테두리)·메모 버튼 카테고리 틴트 게이팅(App Group 토글 공유).
- [x] SettingView DisplaySettingsView: "카테고리 심볼"→"메모 구분 표시" 마스터 토글(showVisualCues).
- [x] AccessibilityGuide "색상 없이 구별" 카피 갱신(이제 마스터 토글 자동 ON).
- [x] 마이그레이션 `migrateVisualCuesIfNeeded`: 구 categoryBadgeVisible=true → showVisualCues=true 승계.
- [x] Localizable.xcstrings 신규 키 3개(ko+en).

## 비고
- 카테고리 색 코딩/즐겨찾기 분홍/타입 아이콘이 기본 OFF → 카테고리는 상단 탭/스와이프로 구분(여전히 동작).
- 토글 하나로 카드·검색행·키보드의 모든 구분 장치가 한 번에 켜짐(인지부하 최소).
- 검증 권장(실기기): 기본=제목만 / 토글 ON 시 전 장치 표시 / iOS "색상 없이 구별" ON 시 자동 표시 / 구버전 categoryBadgeVisible 사용자 승계.

---

# 제안(고스트) 메모 등장/퇴장 애니메이션 (2026-06-09)
- [x] ghostMemoCell에 `.transition(.scale(0.2)+opacity)` + `.id(pattern.title)`.
- [x] X 버튼: ① `withAnimation(.easeIn 0.22){ ghostSuggestion=nil }`(작아지며 사라짐)
      ② 0.24s 뒤 `withAnimation(.spring){ refreshGhostSuggestion() }`(다음 제안이 작은 네모부터 커지며 등장).
- [x] reduceMotion이면 즉시 전환(애니메이션 없음). 빌드 성공.

---

# 생성 모델 통합: "메모 하나"로 (2026-06-09)
- 사용자 인지 모델: 메모만 만든다. **변수({…}) 넣으면 템플릿**, **이어지는 메모 더하면 콤보**.
- [x] Memo: `comboValues:[String]` 복원(출시본 호환), `isCombo`=`!comboValues.isEmpty`, `isTemplate`=`!templateVariables.isEmpty`(둘 다 계산형). childMemoIds는 디코드/마이그레이션용만.
- [x] 실행: ComboExecutionService/키보드/프리뷰를 comboValues로.
- [x] MemoAdd: 수동 템플릿 토글 제거(변수 자동 감지→템플릿 도우미 자동 노출), 본문 포커스 시 변수삽입 바 상시,
      "이어지는 메모" 섹션(continuations→저장 시 comboValues=[본문]+단계들). 편집 진입 시 분해 로드.
- [x] "+" 메뉴: **새 메모 + 텍스트 가져오기**만(새 템플릿/새 콤보 항목 제거). 콤보 메모 탭→통합 MemoAdd 편집.
- [x] 마이그레이션: 출시본 인라인 comboValues는 그대로 / flat combos.data→comboValues / dev childMemoIds→comboValues.
- [x] 다국어 신규 키(ko+en). 전 타깃 빌드 그린(iOS·키보드·위젯·macOS).
- 비고: ComboList 화면은 미사용(#Preview만)이라 죽은 코드. ComboAddEditView는 ComboList에서만 참조(미도달).
- 검증 권장(실기기): 본문에 {변수}→템플릿 도우미 / 이어지는 메모→콤보·키보드 순차입력 / "+"엔 새 메모만 / 콤보 탭 편집.

## 템플릿 변수 표시: 중괄호 없는 하이라이트(4.3.0 스타일) (2026-06-09)
- [x] HighlightedTextEditor: `{변수}` 토큰의 칩 배경/강조색은 유지하되 `{`·`}` 글자만 투명색 → 화면엔 변수명만 칩으로(텍스트엔 중괄호 남아 파싱 그대로). 편집 중에도 willProcessEditing에서 재적용.
- [x] QuickInsertTokenButton: 칩 라벨을 `token.strippingTemplateBraces`로(중괄호 없이 표시, 삽입은 {…} 그대로).
- 비고: 템플릿 안내 문구("{날짜} 형식…")는 작성법 설명이라 유지. 빌드 그린.

---

# 카테고리 손실 버그 수정 + 메모 타임머신 (2026-06-09)

## 카테고리 자동 손실 차단 (데이터 손실 사고 대응)
- [x] `migrateLegacyCategoriesToThemes` — `개인정보/금융/여행/업무/기본` 카테고리를 자동으로 덮어써 삭제하던
      파괴적 1회 마이그레이션. **무력화(항상 원본 반환)**. (이미 출시본에 있던 버그 → 핫픽스 필요)
- [x] `migrateExistingMemosClassification` — "기본" 메모를 타입으로 자동 이동하던 부분 제거(autoDetectedType만 채움).
- [x] MemoAdd 편집 시 기존 category 미로드로 저장 시 재분류 덮어쓰던 버그 수정(편집은 항상 기존 category 보존).
- 검증: 자동으로 기존 카테고리를 바꾸는 경로 0 (이동/삭제는 사용자 직접 동작만).

## 메모 타임머신 (A안: 전체 스냅샷 링버퍼)
- [x] `MemoStore.save(.memo)` 직전, **의미 있는 변경**(제목/본문/카테고리/자식/이미지/힌트 변화)일 때만
      직전 전체 상태를 `MemoSnapshot`으로 보관. 사용량(clipCount/lastUsedAt)만 변경 시 skip. 최근 10개 유지.
- [x] `memo.history.data`(App Group) 저장. `loadMemoHistory()` / `restoreMemoSnapshot(id)`(되돌리기도 되돌림 가능).
- [x] 설정 → 데이터 & 보안 → "변경 기록 (되돌리기)" 화면(MemoHistoryView): 시점 목록·복원 확인·토스트.
- [x] 마이그레이션 같은 대량 변경도 직전 상태가 스냅샷되어 되돌릴 수 있음(오늘 같은 사고 복구 가능).
- [x] Localizable.xcstrings 신규 키 10개(ko+en), 날짜는 setLocalizedDateFormatFromTemplate로 자동 현지화. 빌드 성공.

---

# 지원 페이지(사용 가이드) 기능 동기화 (2026-06-10)

## 요청
- docs/tutorial.html(지원/사용 가이드)을 현재 기능에 맞게 업데이트.

## 반영 ✅
- [x] 용어 정리: "테마" → "카테고리" (메모 추가 단계)
- [x] 콤보 생성 흐름 수정: 별도 "콤보 탭" 제거 → 메모 본문 + "이어지는 메모"로 콤보 생성, 탭 시 미리보기 하프시트
- [x] 보안 메모 섹션 추가: 길게 눌러 잠금/해제, 기기 암호화, Face ID·Touch ID, 자물쇠 표시 (Pro)
- [x] 템플릿: 탭 시 값 입력 시트, "템플릿으로 만들기"(롱프레스), 날짜 변수 선택지
- [x] 키보드 외형: 즐겨찾기 분홍·보안 자물쇠·현재 카테고리 큰 제목
- [x] 이미지 메모: OCR(문자 인식) 추가
- [x] FAQ: 보안 메모 잠금 항목 추가
- [x] ko/en 양쪽 번역 동기화

---

# 데이터 모델 UML 다이어그램 HTML (2026-06-08)

## 요청
- 앱의 데이터 모델링을 UML 다이어그램으로 시각화한 HTML 문서로 남기기.

## 산출물 ✅
- [x] `docs/data-model-uml.html` 생성 — 완전 자립형(인터넷/CDN 불필요)
  - Mermaid classDiagram을 **다크 테마 SVG로 미리 렌더해 인라인 임베드**(오프라인 OK)
  - 편집용 Mermaid 소스는 `<details>`에 보존
  - 엔티티 상세 카드(속성·타입·프로토콜) + 영속화 테이블 + 마이그레이션 노트
- [x] 포함 모델: Memo, OldMemo(레거시), SmartClipboardHistory, ClipboardHistory(레거시),
      PlaceholderValue, Combo, ComboItem + enum(ClipboardItemType/ContentType/ComboItemType/MemoType)
      + 서비스(MemoStore, CloudKitBackupService)
- [x] 관계 표기: 합성(*--)/집합(o--)/연관(-->)/의존·UUID참조·마이그레이션(..>)
- [x] mermaid-cli로 문법 검증(SVG 생성) + 헤드리스 크롬 스크린샷으로 렌더 확인

## 비고
- 출처: Model/Memo.swift(정본), Service/MemoStore.swift, Service/CloudKitBackupService.swift
- 코드 변경 없음(문서 산출물만). 모델 변경 시 details의 Mermaid 소스를 고쳐 재렌더하면 됨.

---

# 기능 명세 + Swift Testing 테스트 대거 작성 (2026-06-09)

## 요청
- 현재 존재하는 기능을 명세하고, 이를 검증하는 테스트코드(Swift Testing)를 대거 작성.

## 산출물 ✅
- [x] `docs/FEATURE_SPEC.md` — 현재(4.3.x dev) 기능 명세 8개 영역 + 테스트 매핑표.
- [x] Swift Testing 신규 6개 스위트(`ClipKeyboardTests/*SwiftTests.swift`):
  - MemoModelSwiftTests / TemplateVariableProcessorSwiftTests / MemoPreviewFormatterSwiftTests
  - ClipboardClassificationSwiftTests / ProFeatureLimitsSwiftTests / ComboAndTemplateModelSwiftTests
- [x] 전체 ClipKeyboardTests **294 케이스 그린**(시뮬레이터 실행 검증).

## 테스트 인프라 수리 (리팩터 이후 stale 제거)
- [x] 호스트 앱 런치 가드 추가(`ClipKeyboardApp.isRunningUnitTests`) — 테스트 시 Firebase/스케줄러/
      마이그레이션 스킵 → "test runner hung before establishing connection" 해결.
- [x] stale 테스트 수정: ModelTests/MemoStoreTests(`isTemplate:` 인자 제거), CategoryStoreTests
      (`localeDefaults` 제거), ComboExecutionServiceTests(childMemoIds→comboValues),
      PersonaTests(applyPersona는 카테고리 시드 안 함→선택 저장만), AttachedTemplateTests(콤보=comboValues).

## ⚠️ 테스트가 잡아낸 실제 데이터 손실 회귀 (수정 완료)
- [x] Memo가 **합성 Codable**이라, 최근 추가된 비옵셔널 키(childMemoIds/comboInterval/comboValues 등)가
      없는 구버전 memos.data는 `keyNotFound`로 **[Memo] 전체 디코딩 실패** → OldMemo 폴백 → 대량 손실.
- [x] **3개 Memo 복사본 모두** 관용 디코더(`init(from:)` + decodeIfPresent) 추가:
      `ClipKeyboard/Model/Memo.swift`, `Shared/Models/SharedModels.swift`(키보드/위젯),
      `ClipKeyboard.tap/Models.swift`(macOS). 누락 키를 기본값으로 안전 디코딩.
- [x] 회귀 가드 테스트 2건(MemoModelSwiftTests): 신규 키 누락 JSON·배열 안전 디코딩.
- [x] iOS 테스트 타겟 + macOS tap 빌드 그린.

---

# 콤보/리팩터 죽은 코드 정리 (2026-06-09, 테스트 안전망 기반)

## 방법
- 모든 삭제 후보를 grep으로 직접 참조 검증(에이전트 조사 신뢰 안 함 — 실제로 "KEEP" 오판 다수 발견).
- 삭제마다 294개 테스트 그린 유지 확인.

## 삭제 (확정 죽은 코드)
- [x] 파일 5개: `Screens/ComboList.swift`, `Screens/Combo/ComboItemPickerView.swift`,
      `Screens/Combo/ComboTemplateInputView.swift`, `Data/Repository/ComboRepository.swift`,
      `Domain/Repository/ComboRepositoryProtocol.swift` (+ pbxproj 항목 20줄 제거).
- [x] `AppDependencies.comboRepository` 주입 라인(아무 데서도 안 읽힘).
- [x] `MemoStore`: `childMemos`/`resolveChildValues`/`pruneMissingChildren`(참조 0),
      무력화된 `migrateLegacyCategoriesToThemes`(no-op) + 호출부 → `load()` 단순화.

## 유지 (검증으로 확인 — 살아있음)
- `ComboEditSheet.swift`(ComboSheetResolver) ← ClipKeyboardListComponents.swift:889에서 사용.
- 콤보 CRUD(`loadCombos`/`saveCombos` 등) + `Combo`/`ComboItem` 타입 ← CloudKit 백업 + 테스트 커버.
- `Memo.childMemoIds` + `migrateComboModelIfNeeded`/`LegacyMemoFields`/`attachedTemplateId` ← 마이그레이션/디코드 전용.

## 검증
- iOS 테스트 타겟 빌드 + 294 테스트 그린 + 제네릭 iOS 디바이스 빌드 그린.

---

# 템플릿 탭 → 키보드 스타일 값 입력 하프모달 (2026-06-09)

## 요청
- 템플릿 메모를 탭하면 값 입력 하프모달이 올라오고, 우상단 복사 버튼 + 복사될 결과 미리보기.
- 키보드 익스텐션의 TemplateInputOverlay와 동일한 UI 사용.

## 구현 ✅
- [x] `TemplateFillSheet` (Screens/Template/TemplateSheets.swift에 추가 — 메인 타겟이 명시적
      pbxproj 참조라 새 파일 대신 기존 파일에 합침).
  - 컬러 프리뷰(채운 값 초록, 빈 변수 {토큰}) — 키보드 coloredPreviewText 이식.
  - 숫자 토큰: 1-9 키패드 + ⌫ + 00/000/0000 + 저장값 칩 (키보드 PlaceholderInputView 이식).
  - 텍스트 토큰: TextField(직접 입력) + 저장값 빠른 선택 칩.
  - 우상단 "복사" 버튼(모두 채워야 활성) → 입력값 히스토리 저장 후 resolved 문자열 복사.
  - `.presentationDetents([.medium, .large])` 하프모달.
- [x] 탭 라우팅(processMemoAfterAuth): 템플릿 → 하프모달. 단, 자동 변수({날짜})만 있으면 바로 복사.
- [x] SheetModifiers: selectedTemplateIdForSheet → TemplateFillSheet로 교체(기존 편집시트는 폴백).
      편집은 셀 메뉴 onEdit로 계속 접근 가능.

## 검증
- 빌드(테스트 타겟/제네릭 iOS) 그린 + 294 테스트 그린.

---

# iCloud 백업/복원 무결성 테스트 + 메모 타임머신 테스트 (2026-06-11)

## 요청
- 아이클라우드를 포함, 사용자가 쓰는 기능들의 정상 동작 무결성을 테스트 코드로 보장.

## 구현 ✅
- [x] **CloudKitBackupService 테스트 가능 리팩토링** — `CloudKitBackupDatabase` 프로토콜 신설
      (record(for:)/save/deleteRecord), CKDatabase가 그대로 채택. 계정 상태도 클로저 주입.
      테스트 전용 init(database:accountStatus:)는 타이머·리스너·초기백업 부작용 없음.
      shared 동작은 동일(시그니처/경로 변화 없음).
- [x] `CloudKitBackupIntegrityTests` 14건 — 네트워크 없이 mock DB로 출시 코드 경로 전체 검증:
  - 백업 레코드 구성(3 Asset+버전+날짜), 2차 백업은 기존 레코드 갱신(레코드 1개 유지)
  - **백업→로컬 전체 삭제→복원 라운드트립: Memo 전 필드 보존**(보안/즐겨찾기/템플릿 변수/
    placeholderValues/comboValues/이미지 파일명/힌트/날짜/clipCount + 클립보드·콤보)
  - 복원 시 comboModelUnifyMigrated_v1 플래그 리셋(옛 백업 재변환 보장)
  - 로컬 데이터 있으면 forceOverwrite 없이 복원 거부 + 로컬 데이터 무손상
  - 백업 없음→noBackupFound / 깨진 백업 JSON→실패해도 로컬 데이터 무손상
  - 레거시 Data 필드 백업(CKAsset 이전 포맷) 복원 호환
  - 미인증(noAccount/restricted) 시 백업·복원 거부(네트워크 시도 0회)
  - 일시적 네트워크 오류 1회 재시도 후 성공 / 권한 오류는 재시도 없이 즉시 실패
  - hasBackup 정합성, deleteBackup 후 레코드·lastBackupDate 제거
- [x] `MemoTimeMachineTests` 7건 — 변경 기록(스냅샷 링버퍼) 첫 테스트:
  - 의미 있는 변경만 스냅샷(사용량 clipCount 변경은 skip), recordHistory:false는 미기록
  - 최근 10개 링버퍼 유지, 대량 삭제 복원(전 필드), 되돌리기의 되돌리기, 없는 id는 false+무손상

## 검증
- 신규 21건 그린 + **전체 스위트 297건 그린**(기존 테스트 무회귀, 시뮬레이터 iPhone 17 Pro).

## 남은 것 (실기기/실계정에서만 가능)
- [ ] 실제 iCloud 계정으로 기기 A 백업 → 기기 B 복원 E2E (CKContainer 실연결)

---

# 커버리지 갭 검토 + 미커버 기능 테스트 27건 추가 (2026-06-11)

## 요청
- 버그 신고를 받기 전에 보장 안 된 기능이 없는지 검토하고 테스트 보강.

## 갭 분석 결과 → 테스트 추가 ✅
- [x] `CategorySidecarTests` 6건 — **카테고리 다운그레이드 안전장치(완전 미검증이었음)**:
      save 시 비기본만 사이드카 기록 / 유실(기본·빈값)만 복원·사용자 변경은 보존 /
      다운그레이드 재저장→load 치유 왕복 / 의도적 "기본" 이동은 부활 안 함 / 기존 사용자 부트스트랩
- [x] `SmartClipboardLifecycleTests` 6건 — 복사 시 자동 분류, 중복은 맨 앞 이동(무중복),
      요금제별 개수 제한(무료50/Pro100), 7일 지난 임시 항목 정리(보관 항목은 유지),
      사용자 분류 수정 영속, 레거시 clipboard.history.data → 스마트 마이그레이션(id 보존)
- [x] `MemoListSortingTests` 4건 — 즐겨찾기 우선→최근순, 수동 순서 시 즐겨찾기 고정 해제,
      순서 미등록 새 메모 맨 위, commitReorder 영구 저장+새 ViewModel 재현
- [x] `BuiltInCategoryTests` 4건 + `CategoryTabStorageTests` 2건 — 타입별 모아보기 판정
      (템플릿은 메모+템플릿 탭에도 포함, mixed는 이미지 탭), 탭 storageKey 왕복(한글·이모지 포함)
- [x] `KeyboardUsageTrackerTests` 4건 — 일일 카운트, 절약 시간 누적(40자=9초), 음수 clamp, 날짜 스코프
- [x] `TemplateBraceDisplayTests` 1건 — 칩 라벨 중괄호 제거

## 검증
- **전체 스위트 324건 그린**(297 + 신규 27, 시뮬레이터 iPhone 17 Pro).

## 남은 갭 (현 구조로는 단위 테스트 불가 — 인지하고 관리)
- [ ] `migrateComboModelIfNeeded`/`hasLegacyComboData` — ClipKeyboardApp에 private.
      테스트하려면 별도 타입으로 추출 필요(마이그레이션 로직 이동 리스크 있어 보류). 실기기 검증 항목 유지.
- [ ] 키보드 익스텐션/위젯의 Memo 복사본(Shared/Models/SharedModels.swift) — 익스텐션 타겟에
      테스트 타겟이 없음. 메인 Memo와 디코더 동기화는 코드 리뷰로 관리(memo_codable_backcompat 참고).
- [ ] `grandfatherPaidUserIfNeeded` — AppTransaction(StoreKit) 의존, Sandbox/실기기 전용.
- [ ] UI 레이어(시트 라우팅·애니메이션·키보드 익스텐션 UI) — 단위 테스트 범위 밖, 실기기 체크리스트로.

---

# 키보드 익스텐션 타이핑 로직 테스트 33건 추가 (2026-06-11)

## 요청
- 키보드 익스텐션 입력(타이핑) 쪽도 테스트로 커버.

## 방법
- HangulComposer/CheonjiinInput은 익스텐션 타겟 소속이지만 **순수 Foundation 로직 +
  HangulInputProxy 프로토콜 추상화**라, pbxproj에서 두 소스를 ClipKeyboardTests 타겟에도
  컴파일하도록 등록(PBXBuildFile 2건 + 테스트 타겟 Sources phase).
- `FakeHangulProxy`(insertText/deleteBackward를 텍스트 버퍼로 재현) → **fake의 text가
  사용자가 키보드에서 보는 글자** 그대로를 검증.

## 구현 ✅
- [x] `HangulComposerTests` 18건 — 2벌식 조합:
      기본 음절(한/한글/꼬), 받침 이동 도깨비불(안+ㅏ=아나), 겹받침 분해 이동(읽+ㅓ=일거),
      복합 모음(과/희), 겹받침(읽), 종성불가 ㄸ 처리(바따), ㅇ초성 자동(가오),
      백스페이스 단계 되돌리기(한→하→ㅎ→∅, ㄺ→ㄹ, ㅘ→ㅗ), 비한글 commit(가!나), commit 후 글자단위 삭제
- [x] `CheonjiinInputTests` 15건 — 천지인:
      자음 multi-tap 순환(ㄱ→ㅋ→ㄲ→ㄱ), 0.5초 타임아웃 시 새 글자(ㄱㄱ), 다른 키로 사이클 중단,
      모음 획 진화(이→아→야), ㅐ 조합, 단독 ㆍ 임시표시→해석(ㅓ), 음절 완성(한),
      받침 이동(간+ㅏ=가나), 백스페이스(자음 전체 삭제/획 되돌리기 야→아/임시 ㆍ 제거),
      commit(음절 확정/미완성 획 폐기 — 쓰레기 문자 방지)

## 검증
- **전체 스위트 357건 그린**(324 + 신규 33). 익스텐션은 앱 임베드로 함께 빌드 확인.

## 여전히 자동화 불가 (실기기 수동 체크리스트)
- [ ] KeyboardViewController의 입력 핸들링(메모 탭→insertText, 콤보 순차 입력) — UIInputViewController 의존
- [ ] 시스템 레벨 E2E(서드파티 키보드 활성화·전환·실제 앱에서 타이핑) — iOS 제약상 XCUITest 불가

---

# 메인 화면 검색 키보드가 안 내려가는 문제 수정 (2026-06-11)

## 원인
- 검색 포커스(isSearchFieldFocused) 해제 경로가 돋보기 토글 버튼 단 하나뿐.
  iOS는 배경 탭으로 키보드를 자동으로 닫지 않으며(항상 opt-in), 메모 그리드는
  일반 ScrollView라(List/Form과 달리) 스크롤 시 자동 dismiss도 없었음.

## 수정 ✅
- [x] ClipKeyboardList.screenBody의 ZStack(메모 영역)에:
  - `.simultaneousGesture(TapGesture → isSearchFieldFocused = false)` — 빈 곳/카드
    어디를 탭해도 키보드 닫힘. simultaneous라 카드 탭 동작(복사 등)은 그대로 실행.
  - `.scrollDismissesKeyboard(.immediately)` — 그리드 스크롤/탭 페이지 스와이프 시 닫힘.
- 검색바 자신은 safeAreaInset 분리 영역이라 탭해도 포커스 안 풀림(재탭 깜빡임 없음).
- [x] ClipKeyboard 스킴 빌드 그린.

## 검증 필요 (시뮬레이터/실기기)
- [ ] 검색 중 메모 카드 탭 → 키보드 내려가면서 복사 동작 정상
- [ ] 빈 공간 탭/스크롤/페이지 스와이프 → 키보드 내려감
- [ ] 검색 필드 재탭 → 키보드 유지(깜빡임 없음)

---

# 메모 카드 속 "내용 힌트" — 맺혔다 흩어지는 미리보기 (2026-06-11)

## 요청 (3차 확정)
- 1차: 타이틀 아래 통계 띠(반려). 2차: 카드 속 내용이 물고기처럼 좌우 유영(반려 — "좀 별로,
  깔끔하고 우아하게. 힌트는 주고 싶은데 지저분하지 않게").
- 확정: **움직임 없이 제자리에서** 블러가 걷히며 살며시 맺혔다가, 머문 뒤 흩어지듯 사라지는 힌트.

## 구현 ✅
- [x] `ContentHintPreview` (ClipKeyboardListComponents.swift, 구 FishbowlContentPreview 교체):
  - 주기 14~18초(메모 id 시드별) 중 6초만 노출:
    **맺힘 0.9s**(blur 4→0, 3pt 아래서 떠오름, 페이드 인) → **머묾 4.2s**(또렷) →
    **흩어짐 0.9s**(blur 0→4, 살짝 떠오르며 페이드 아웃) → 휴식 8~12s(빈 공간).
  - smoothstep(easeInOut) 곡선, 좌우 이동·기울기·둥실거림 전부 제거 — iOS 알림 텍스트 톤.
  - 시드 기반 위상 분산(카드들이 동시에 깜빡이지 않음), allowsHitTesting(false),
    accessibilityHidden, reduceMotion=페이드만(blur·rise 없음).
- [x] 호출부 이름 교체 외 동일: fishbowlText(보안 메모 nil) + 영역 상시 확보(높이 균일).

## 검증 ✅
- 빌드 그린. 시뮬레이터 프레임: "간단 인사말" 힌트 또렷 + "내 이메일"은 블러에 싸여 맺히는 중
  (위상 분산 확인), 5초 뒤 앞 힌트는 사라지고 "이름 + 연락처"에 "2 items" 등장.
- 검증 권장(실기기): 머묾 4.2s/휴식 길이 취향, 다크모드 가독성, reduceMotion.

## 후속 조정 (2026-06-11, 사용자 피드백 "좋고")
- [x] **더 가끔 등장**: 기본 주기 14~18s → 24~31s(보통). 빈도 3단계 `ContentHintPace`:
      여유롭게(38~48s) / 보통(24~31s, 기본) / 자주(14~19s).
- [x] **설정 추가** (설정 → 메모 표시): "메모 내용 힌트" 토글(기본 ON) + "등장 빈도"
      세그먼트 피커(토글 OFF면 비활성). @AppStorage contentHintEnabled / contentHintPace.
      끄면 힌트 영역 자체가 사라져 완전한 제목-only 카드로(전 카드 동일 → 높이 균일 유지).
- [x] **폰트 .caption2 → .body**, zoneHeight 16 → 22.
- [x] Localizable.xcstrings 신규 키 5개(ko+en/id): 메모 내용 힌트/등장 빈도/여유롭게/자주/푸터 설명.
- [x] 빌드 그린 + 시뮬레이터 확인(.body 크기 힌트 교대 등장).

## 후속 조정 2 — 등장 기준 변경 + 키보드 확장 (2026-06-11)
- 요청: "사용자가 화면을 봤을 때에는 안 나오다가 **2초 머물면** 지금처럼 보이다가 사라지게.
  설정은 유지. 키보드에도 비슷하게 — 공간이 좁으니 **타이틀을 잠시 감추고 내용을 보였다가
  다시 타이틀로**."
- [x] **앱 카드 힌트 — 주기 반복 → 등장 1회**: `ContentHintPreview` 재작성.
      카드가 화면에 나타나 2초 머묾 → 맺힘 0.9s → 머묾 4.2s → 흩어짐 0.9s → 끝.
      `.task` 기반(화면 이탈 시 취소·재등장 시 처음부터). TimelineView 20fps 상시 구동 제거(배터리↓).
      seed·`ContentHintPace`(빈도 3단계) 삭제 — 반복이 없어져 빈도 개념 소멸.
- [x] **설정**: "메모 내용 힌트" 토글 유지, "등장 빈도" 피커 제거, 푸터 설명 갱신(2초 기준 +
      키보드 동작 + 보안 메모 미노출). `contentHintEnabled`를 **App Group**으로 이동
      (키보드 공유). xcstrings: 등장 빈도/여유롭게/자주/구 푸터 키 삭제, 새 푸터 키 추가(ko+en/id).
- [x] **키보드 — 제목 ↔ 내용 스왑** (`MemoTitleHintSwap`, KeyboardView.swift):
      셀 등장 2초 후 제목이 내용으로 크로스페이드(0.4s, 블러 3pt) → 3.2s 읽힘 → 제목 복귀.
      등장당 1회. 보안 메모·이미지·설정 OFF는 nil → 스왑 없음. VoiceOver는 버튼 라벨 그대로.
- [x] MemoPreviewFormatter.swift를 키보드 익스텐션 타겟에 추가(pbxproj),
      `String.strippingTemplateBraces`를 HighlightedTextEditor → MemoPreviewFormatter로 이동
      (키보드 타겟 공유). xcstrings는 키보드 타겟에 이미 포함 → "%d items" 등 번역 그대로 동작.
- [x] 빌드 그린(앱+키보드+위젯) + 전체 테스트 그린.
- [ ] 검증 권장(실기기): 키보드 셀 스왑 가독성(좁은 셀에서 긴 내용 2줄), 머묾 시간 취향,
      스크롤 시 재등장 빈도가 과하지 않은지.

## 후속 조정 3 — 시차 분산 + 콤보 첫 값 (2026-06-11)
- 요청: "한 번에 다 머물다 사라질 필요 없다, 감각적으로 임의의 패턴으로"(앱·키보드 모두) +
  "콤보는 모든 곳에서 첫 번째 값이 표시되도록".
- [x] **앱 카드**: seed(메모 id 해시) 기반 결정적 편차 — 등장 지연 2.0~3.6s,
      머묾 3.6~5.4s. 2초 바닥값은 유지, 카드들이 하나둘 맺혔다 제각각 흩어진다.
      (splitmix64풍 해시 → 0..<1, salt로 지연/머묾 독립)
- [x] **키보드 셀**: 동일 방식 — 스왑 시점 2.0~3.6s, 읽힘 2.8~4.2s.
- [x] **콤보 미리보기**: "%d items" → **"첫 값(≤28자) · %d items"**
      (MemoPreviewFormatter.comboPreview — 앱 카드 힌트·리스트 행·키보드 스왑 모두 공통).
      기존 테스트 comboPreviewShowsCount(숫자 포함 검사)와 호환.
- [x] 빌드 + 전체 테스트 그린.

## 후속 조정 4 — 커스텀 힌트 + 주기 반복 + 키보드 전환 완화 (2026-06-11)
- 요청: ① 보이고 싶은 값을 직접 넣으면 그걸 표시(만들기/수정에서 힌트 입력 +
  "키보드에 표시할 이름과 같이 표시" 동기화 토글), ② 앱 힌트는 켜둔 동안 주기적으로
  반복(휴식 4~10초 괜찮음), ③ 키보드는 너무 확확 바뀜 → 더 천천히.
- [x] **모델**: 기존 `Memo.hint`(컨텍스트 힌트, UI 미연결 상태였음)를 카드/키보드 표시에 연결.
      신규 `hintShownOnKeyboard: Bool = true`(decodeIfPresent ?? true — 하위호환,
      신규 키 추가라 구버전 디코더 안전). 라운드트립+구버전 기본값 테스트 추가.
- [x] **MemoAdd(풀 모드)**: titleInputSection 아래 "내용 힌트 (선택)" 입력 +
      힌트가 있을 때만 나타나는 동기화 토글(기본 ON). ViewModel 로드/저장/리셋 연결.
      xcstrings 신규 키 4개(ko+en/id).
- [x] **표시 우선순위**: 커스텀 힌트 > 자동 요약. 커스텀 힌트는 직접 쓴 한 줄이라
      보안 메모에도 표시(자동 요약은 여전히 보안 메모 미노출). 키보드는 동기화 토글
      OFF면 해당 메모 스왑 없음.
- [x] **앱 카드 주기 반복**: 1회성 → 맺힘·머묾·흩어짐 후 휴식 4~10s(seed별) 쉬고 다시 맺힘.
      앱을 켜둔 동안 반복, 화면 이탈 시 task 취소.
- [x] **키보드 전환 완화**: 크로스페이드 0.4s → 1.0s, 읽힘 3.2~4.6s.
- [x] 빌드 + 전체 테스트 그린(신규 테스트 포함).

---

# iOS ↔ macOS 저장체계 동기화 (2026-06-12)

## 맥앱 업데이트 (Models.swift / CloudKitBackupService.swift)

- [x] `Memo.hint` 필드 추가 — 맥에서 저장 시 iOS 힌트가 영구 손실되던 버그 수정
- [x] `OldMemo` 폴백 디코딩 추가 (1.x 포맷 마이그레이션, iOS와 동일)
- [x] `preloadLocalizedStrings`에 v4.0 항목(IBAN/SWIFT/VAT/Crypto/PayPal) 동기화
- [x] 맥 CloudKitBackupService에 `CloudKitBackupDatabase` 테스트 시임 추가 (iOS와 동일 구조)
- [x] 맥 복원 시 `comboModelUnifyMigrated_v1` 플래그 리셋 (iOS와 동일)

## 백업/복원 무결성 테스트

- [x] `scripts/roundtrip/run_roundtrip_test.sh` — 실제 양쪽 모델 소스로
      iOS 인코딩→맥 디코딩→맥 재인코딩→iOS 디코딩 전 필드 보존 검증
- [x] 수정 전 모델로 돌리면 hint 손실로 실패함을 확인 (테스트 유효성 검증)
- [x] macOS 타겟 빌드 그린
- [x] iOS 전체 테스트 스위트 (CloudKitBackupIntegrityTests 포함) 그린
- [x] (부수 수정) KeyboardUsageTrackerTests 날짜 잔존값 격리 버그 수정
      — 전날 실행이 남긴 어제 키 때문에 다음 날 반드시 깨지던 테스트
