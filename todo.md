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
