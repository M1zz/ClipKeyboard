//
//  ClipKeyboardList.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/05/14.
//

import SwiftUI
import LocalAuthentication
import TipKit

var fontSize: CGFloat = 20

extension Color {
    /// 즐겨찾기 지정색 — 시스템 핑크보다 더 선명한 분홍(#FF4A9E).
    static let clipFavorite = Color(red: 1.0, green: 0.29, blue: 0.62)
}

// UUID는 이 Swift 버전에서 Identifiable을 자동 제공하지 않으므로 명시적으로 추가
extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

/// List 스크롤 오프셋을 상위 View로 전달하는 PreferenceKey.
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ClipKeyboardList: View {

    @StateObject private var viewModel = ClipKeyboardListViewModel()
    @ObservedObject private var suggestionManager = SuggestionManager.shared

    // MARK: - View-only State

    @State private var isSearchBarVisible = false
    @State private var memoToDelete: Memo? = nil
    @State private var graceBannerVisible: Bool = ProFeatureManager.hasGraceMemoQuota && !ProFeatureManager.didDismissGraceBanner
    @State private var showPaywallFromKeyboard: Bool = false
    @State private var showBulkImport: Bool = false
    @State private var hasAppeared: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var occasionalSuggestion_: SuggestionTemplate? = nil
    @State private var navigateToOccasionalAdd: Bool = false

    // Category badge nudge
    @State private var categoryBadgeVisible: Bool = UserDefaults.standard.object(forKey: "categoryBadgeVisible") as? Bool ?? true
    @State private var showCategoryBadgeNudge: Bool = false

    // Category
    @State private var showCategoryManagement: Bool = false
    @State private var showAddCategoryAlert: Bool = false
    @State private var newCategoryName: String = ""
    @State private var categoryToDelete: String? = nil
    // 롱프레스 컨텍스트에서 즉석 카테고리 생성+배정
    @State private var memoForCategoryAssign: Memo? = nil
    @State private var newCategoryForMemo: String = ""
    @State private var showNewCategoryForMemoAlert: Bool = false

    // 롱프레스 테두리 애니메이션 + 액션 메뉴
    @State private var longPressActiveMemo: Memo? = nil
    @State private var longPressProgress: CGFloat = 0
    @State private var memoForActions: Memo? = nil
    @State private var showMemoActions: Bool = false

    // 즐겨찾기 탭 전용
    @State private var showAddFavoriteMemoSheet: Bool = false
    @State private var showSwipeCategoryDialog: Bool = false

    // Sheet modals for MemoAdd
    @State private var showAddMemoSheet: Bool = false
    @State private var addMemoSheetCategory: String = ""
    @State private var showAddTemplateSheet: Bool = false
    @State private var showAddComboSheet: Bool = false
    @State private var showAddImageMemoSheet: Bool = false
    @State private var memoToEdit: Memo? = nil

    // TipKit
    private let welcomeTip = WelcomeTip()
    private let addMemoTip = AddMemoTip()
    private let cleanUpTip = CleanUpSamplesTip()

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shouldShowGraceBanner: Bool {
        graceBannerVisible && !ProFeatureManager.isPro
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 현재 탭에 따라 배경색이 부드럽게 전환
                tabBackgroundColor
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.38), value: viewModel.selectedCategoryTab)

                // v4.1.0: 활성화 배너를 메모 위에 overlay하지 않고 VStack flow 안에
                // 두어 콘텐츠가 자연스럽게 아래로 밀려남. 다른 배너들(ReviewBanner,
                // GraceQuotaBanner 등)과 통일된 패턴.
                VStack(spacing: 0) {
                    if CategoryStore.shared.shouldShowActivationBanner(currentMemoCount: viewModel.memos.count) {
                        CategoryActivationBanner(
                            onEnable: {
                                withAnimation { CategoryStore.shared.enableFeature() }
                                HapticManager.shared.success()
                            },
                            onDismiss: {
                                withAnimation { CategoryStore.shared.dismissActivationBanner() }
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // 메모를 보고 카테고리 생성을 제안 (TipKit). 자동 분류된 메모가 임계치 이상
                    // 쌓였는데 아직 그 카테고리가 없으면 부드럽게 안내.
                    if CategoryStore.shared.isFeatureEnabled,
                       let suggestion = viewModel.suggestedCategory {
                        categorySuggestionTip(name: suggestion.name, count: suggestion.count)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // 카테고리 기능이 활성일 때만 탭/swipe 뷰. 비활성이면 .all 페이지 하나.
                    if CategoryStore.shared.isFeatureEnabled {
                        categoryTabView
                    } else {
                        tabPageView(for: .all)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isSearchBarVisible {
                    searchBarInlineSection
                        .background(.regularMaterial)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .alert(
                NSLocalizedString("새 카테고리", comment: "Add category alert title"),
                isPresented: $showAddCategoryAlert
            ) {
                TextField(NSLocalizedString("카테고리 이름", comment: "Category name placeholder"), text: $newCategoryName)
                Button(NSLocalizedString("추가", comment: "Add")) {
                    viewModel.addCustomCategory(newCategoryName)
                    newCategoryName = ""
                }
                Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {
                    newCategoryName = ""
                }
            } message: {
                Text(NSLocalizedString("메모를 분류할 카테고리 이름을 입력하세요.", comment: "Add category alert message"))
            }
            .alert(
                NSLocalizedString("카테고리 삭제", comment: "Delete category alert title"),
                isPresented: Binding(get: { categoryToDelete != nil }, set: { if !$0 { categoryToDelete = nil } })
            ) {
                Button(NSLocalizedString("삭제", comment: "Delete"), role: .destructive) {
                    if let name = categoryToDelete { viewModel.deleteCustomCategory(name) }
                    categoryToDelete = nil
                }
                Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { categoryToDelete = nil }
            } message: {
                if let name = categoryToDelete {
                    Text(String(format: NSLocalizedString("'%@' 카테고리를 삭제하시겠습니까? 메모는 유지됩니다.", comment: "Delete category confirm message"), name))
                }
            }
            .alert(
                NSLocalizedString("새 카테고리 만들기", comment: "Create new category and assign alert title"),
                isPresented: $showNewCategoryForMemoAlert
            ) {
                TextField(NSLocalizedString("카테고리 이름", comment: "Category name placeholder"), text: $newCategoryForMemo)
                Button(NSLocalizedString("추가", comment: "Add")) {
                    let trimmed = newCategoryForMemo.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty, let memo = memoForCategoryAssign {
                        viewModel.addCustomCategory(trimmed)
                        viewModel.moveMemo(memo, toCategory: trimmed)
                    }
                    newCategoryForMemo = ""
                    memoForCategoryAssign = nil
                }
                Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {
                    newCategoryForMemo = ""
                    memoForCategoryAssign = nil
                }
            } message: {
                Text(NSLocalizedString("카테고리가 생성되고 이 메모가 바로 이동됩니다.", comment: "Create category and assign message"))
            }
            .sheet(isPresented: $navigateToOccasionalAdd, onDismiss: { viewModel.loadMemos() }) {
                NavigationStack {
                    Group {
                        if let s = occasionalSuggestion_ { memoAdd(for: s) } else { MemoAdd() }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(NSLocalizedString("취소", comment: "Cancel")) { navigateToOccasionalAdd = false }
                        }
                    }
                }
            }
            .task {
                viewModel.loadMemos()
            }
            .toolbar {
                toolbarContent
            }
            // 하단 툴바 — iOS 26: 배경 hidden으로 Liquid Glass pill이 콘텐츠 위에 플로팅
            // iOS 17-25: thin material 유지
            .toolbarBackground(.hidden, for: .bottomBar)
            // Toast 메시지 오버레이
            .overlay(alignment: .bottom) {
                toastOverlay
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: viewModel.showToast)

            // Navigation 설정 — 네비게이션 바 완전히 숨김. 그리팅이 상단 앵커 역할.
            .navigationTitle("")
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .accessibilityLabel(NSLocalizedString("Saved items", comment: "Screen: main memo list"))
            // 검색 및 필터 변경 감지
            .onChange(of: viewModel.searchQueryString) { _, _ in viewModel.applyFilters() }
            .onChange(of: viewModel.selectedTypeFilter) { _, _ in
                viewModel.applyFilters()
                viewModel.saveSelectedFilter()
            }
            .onChange(of: viewModel.showFavoritesFilter) { _, _ in viewModel.applyFilters() }
            // 인증 실패 Alert
            .alert(NSLocalizedString("인증 실패", comment: "Auth failed"), isPresented: $viewModel.showAuthAlert) {
                Button(NSLocalizedString("확인", comment: "Confirm"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("보안 메모에 접근하려면 생체 인증이 필요합니다", comment: "Biometric auth required"))
            }
            // 메모 삭제 확인 Alert
            .alert(
                NSLocalizedString("메모 삭제", comment: "Delete memo alert title"),
                isPresented: Binding(
                    get: { memoToDelete != nil },
                    set: { if !$0 { memoToDelete = nil } }
                )
            ) {
                Button(NSLocalizedString("삭제", comment: "Confirm delete"), role: .destructive) {
                    if let memo = memoToDelete,
                       let idx = viewModel.memos.firstIndex(where: { $0.id == memo.id }) {
                        viewModel.deleteMemo(at: IndexSet(integer: idx))
                    }
                    memoToDelete = nil
                }
                Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {
                    memoToDelete = nil
                }
            } message: {
                if let memo = memoToDelete {
                    Text(String(format: NSLocalizedString("'%@'을(를) 삭제하시겠습니까? 이 작업은 취소할 수 없습니다.", comment: "Delete memo confirm message with title"), memo.title))
                } else {
                    Text(NSLocalizedString("이 작업은 취소할 수 없습니다.", comment: "Delete warning"))
                }
            }
            // 롱프레스 완료 후 액션 시트 (커스텀 bottom sheet)
            // iOS confirmationDialog/actionSheet는 시스템 디자인상 button systemImage를
            // 렌더링 안 함. 아이콘 표시를 위해 .sheet + MemoActionSheet 사용.
            // SwiftUI race 회피: sheet dismiss 후 0.35s 뒤에 memoToEdit/memoToDelete set.
            .sheet(isPresented: $showMemoActions) {
                if let memo = memoForActions {
                    MemoActionSheet(
                        memo: memo,
                        categories: viewModel.customCategories,
                        onCopy: {
                            HapticManager.shared.selection()
                            viewModel.copyMemo(memo: memo)
                        },
                        onToggleFavorite: {
                            HapticManager.shared.selection()
                            viewModel.toggleFavorite(memoId: memo.id)
                        },
                        onEdit: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                memoToEdit = memo
                            }
                        },
                        onDelete: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                memoToDelete = memo
                            }
                        },
                        onMoveToCategory: { category in
                            HapticManager.shared.selection()
                            viewModel.moveMemo(memo, toCategory: category)
                        },
                        onCreateNewCategory: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                memoForCategoryAssign = memo
                                newCategoryForMemo = ""
                                showNewCategoryForMemoAlert = true
                            }
                        }
                    )
                    .presentationDetents([.height(380)])
                    .presentationDragIndicator(.visible)
                }
            }
            // 즐겨찾기 탭 + 버튼 — 즐겨찾기로 바로 저장
            .sheet(isPresented: $showAddFavoriteMemoSheet, onDismiss: { viewModel.loadMemos() }) {
                NavigationStack {
                    MemoAdd(insertedIsFavorite: true)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button(NSLocalizedString("취소", comment: "Cancel")) { showAddFavoriteMemoSheet = false }
                            }
                        }
                }
            }
            // 즐겨찾기 탭 오른쪽 스와이프 → 새 카테고리 생성 제안
            .confirmationDialog(
                NSLocalizedString("새로운 카테고리를 만들까요?", comment: "Swipe right favorites: create category dialog title"),
                isPresented: $showSwipeCategoryDialog,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("새 카테고리 만들기", comment: "Swipe right favorites: confirm create category")) {
                    newCategoryName = ""
                    showAddCategoryAlert = true
                }
                Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("즐겨찾기 메모를 정리할 카테고리를 만들어볼까요?", comment: "Swipe right favorites: create category message"))
            }
            .sheet(item: $memoToEdit, onDismiss: { viewModel.loadMemos() }) { memo in
                NavigationStack {
                    MemoAdd(
                        memoId: memo.id,
                        insertedKeyword: memo.title,
                        insertedValue: memo.value,
                        insertedCategory: memo.category,
                        insertedIsTemplate: memo.isTemplate,
                        insertedIsSecure: memo.isSecure,
                        insertedIsCombo: memo.isCombo,
                        insertedComboValues: memo.comboValues
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(NSLocalizedString("취소", comment: "Cancel")) { memoToEdit = nil }
                        }
                    }
                }
            }
            // 각종 Sheet Modifiers
            .modifier(SheetModifiers(
                showTemplateInputSheet: $viewModel.showTemplateInputSheet,
                showPlaceholderManagementSheet: $viewModel.showPlaceholderManagementSheet,
                selectedTemplateIdForSheet: $viewModel.selectedTemplateIdForSheet,
                selectedComboIdForSheet: $viewModel.selectedComboIdForSheet,
                templatePlaceholders: viewModel.templatePlaceholders,
                templateInputs: $viewModel.templateInputs,
                memos: viewModel.memos,
                currentTemplateMemo: viewModel.currentTemplateMemo,
                attachedTemplateBaseMemo: viewModel.attachedTemplateBaseMemo,
                onTemplateComplete: {
                    viewModel.confirmTemplateInput()
                },
                onTemplateCancel: { viewModel.showTemplateInputSheet = false },
                onTemplateCopy: { memo, processedValue in
                    viewModel.finalizeCopy(memo: memo, processedValue: processedValue)
                    viewModel.selectedTemplateIdForSheet = nil
                },
                onTemplateSheetCancel: { viewModel.selectedTemplateIdForSheet = nil },
                onComboDismiss: {
                    viewModel.selectedComboIdForSheet = nil
                    viewModel.loadMemos()
                }
            ))
            .onAppear {
                viewModel.onAppear()
                fontSize = UserDefaults.standard.object(forKey: "fontSize") as? CGFloat ?? 20.0
                // v4.1.0: 카테고리 기능 마이그레이션 — 기존 사용자 자동 활성
                CategoryStore.shared.migrateFeatureEnabledIfNeeded(
                    existingMemoCategories: viewModel.memos.map { $0.category }
                )
                // 첫 로드 시 stagger enter 트리거 (한 번만)
                if !hasAppeared {
                    SuggestionManager.shared.recordAppOpen()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        hasAppeared = true
                    }
                }
            }
            .paywall(isPresented: $showPaywallFromKeyboard, triggeredBy: nil)
            .onReceive(NotificationCenter.default.publisher(for: .showPaywall)) { _ in
                showPaywallFromKeyboard = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                viewModel.onSceneResume()
            }
            .onReceive(NotificationCenter.default.publisher(for: .demoSamplesInserted)) { _ in
                viewModel.loadCustomCategories()   // 시드된 카테고리 탭 반영
                viewModel.loadMemos()
            }
        }
    }

    // MARK: - View Sections

    /// 검색 바 섹션 (인라인)
    private var searchBarInlineSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme.textFaint)
                .font(.callout)
                .accessibilityHidden(true)

            TextField(NSLocalizedString("검색", comment: "Search"), text: $viewModel.searchQueryString)
                .textFieldStyle(PlainTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .accessibilityLabel(NSLocalizedString("메모 검색", comment: "Search field accessibility label"))
                .accessibilityHint(NSLocalizedString("메모 제목 또는 내용으로 검색합니다", comment: "Search field accessibility hint"))

            if !viewModel.searchQueryString.isEmpty {
                Button(action: {
                    HapticManager.shared.soft()
                    viewModel.searchQueryString = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.textFaint)
                        .font(.callout)
                }
                .accessibilityLabel(NSLocalizedString("검색어 지우기", comment: "Clear search field"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.surfaceAlt)
        .cornerRadius(theme.radiusSm)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Grid

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private func memoGridCell(memo: Memo) -> some View {
        let imageFileName = memo.imageFileNames.first ?? memo.imageFileName ?? ""
        let hasImage = !imageFileName.isEmpty
        let onColor = cardIsColored(memo: memo, hasImage: hasImage)
        let isActive = longPressActiveMemo?.id == memo.id
        let holdDuration: Double = 0.65
        // progress fill을 trigger보다 살짝 짧게 — 시뮬 환경에서 onLongPressGesture가
        // 미세하게 일찍 fire되는 경우가 있어 "원이 아직 안 찼는데 시트 뜸" 현상을
        // 방지하기 위함. 사용자는 0.5s에 원이 가득 차는 걸 보고 0.65s까지 누르면 시트.
        let progressFillDuration: Double = 0.5

        // Button + onLongPressGesture 조합이 iOS 17+에서 long press를 가로채는 경우가 있어
        // 일반 View + onTapGesture + onLongPressGesture 패턴으로 분리. 시각 affordance는
        // 그대로 유지 (button trait 명시 + tap 햅틱).
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                memoTypeIcon(memo: memo, onColor: onColor)
                Spacer()
                // 우상단 = 카테고리 식별 심볼(색맹 대비). 즐겨찾기는 하트, 커스텀 카테고리는 지정 심볼.
                if memo.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundColor(onColor ? .white.opacity(0.9) : .clipFavorite)
                        .accessibilityHidden(true)
                } else if categoryBadgeVisible,
                          CategoryStore.shared.isFeatureEnabled,
                          viewModel.customCategories.contains(memo.category) {
                    Image(systemName: customCategoryIcon(memo.category))
                        .font(.title2)
                        .foregroundColor(onColor
                            ? .white.opacity(0.85)
                            : customCategoryColor(memo.category))
                        .accessibilityHidden(true)
                }
            }
            Spacer(minLength: 16)
            Text(memo.title)
                .font(.title2.weight(.semibold))
                .foregroundColor(onColor ? .white : theme.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        // 모든 메모 셀 동일 높이: 제목 2줄(최대 콘텐츠)보다 큰 값으로 floor를 잡아
        // 1줄·2줄 제목 모두 같은 높이로 정렬되게 한다. (제목은 2줄로 제한)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(memoCardBackground(memo: memo, imageFileName: imageFileName, hasImage: hasImage))
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
        .onTapGesture {
            HapticManager.shared.selection() // 탭: 선택 햅틱
            viewModel.copyMemo(memo: memo)
            checkCategoryBadgeNudge()
            #if os(iOS)
            if UIAccessibility.isVoiceOverRunning {
                let msg = String(format: NSLocalizedString("%@ 복사됨", comment: "VoiceOver: copied announcement"), memo.title)
                UIAccessibility.post(notification: .announcement, argument: msg)
            }
            #endif
        }
        .accessibilityAddTraits(.isButton)
        // 롱프레스 감아지는 테두리 오버레이
        .overlay {
            RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
                .trim(from: 0, to: isActive ? longPressProgress : 0)
                .stroke(theme.accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .animation(
                    isActive
                        ? .linear(duration: progressFillDuration)
                        : .easeOut(duration: 0.18),
                    value: longPressProgress
                )
                .allowsHitTesting(false)
        }
        .onLongPressGesture(minimumDuration: holdDuration, maximumDistance: 20) {
            // 완료 — 진행 완료 햅틱 후 액션 메뉴 표시
            HapticManager.shared.heavy()
            longPressActiveMemo = nil
            longPressProgress = 0
            memoForActions = memo
            showMemoActions = true
        } onPressingChanged: { isPressing in
            if isPressing {
                longPressActiveMemo = memo
                longPressProgress = 0
                // 프로세스 진행 햅틱: 시작(light) → 중간(medium) → 완료 직전(medium)
                HapticManager.shared.light()
                DispatchQueue.main.asyncAfter(deadline: .now() + progressFillDuration * 0.45) {
                    guard self.longPressActiveMemo?.id == memo.id else { return }
                    HapticManager.shared.medium()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + progressFillDuration * 0.85) {
                    guard self.longPressActiveMemo?.id == memo.id else { return }
                    HapticManager.shared.medium()
                }
                withAnimation(.linear(duration: progressFillDuration)) {
                    longPressProgress = 1.0
                }
            } else {
                // 중간에 뗌 — 테두리 되감기
                withAnimation(.easeOut(duration: 0.18)) {
                    longPressProgress = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if self.longPressActiveMemo?.id == memo.id {
                        self.longPressActiveMemo = nil
                    }
                }
            }
        }
        .accessibilityLabel(memo.title)
        .accessibilityHint(NSLocalizedString("탭하면 클립보드에 복사, 꾹 누르면 추가 옵션", comment: "Memo card hint"))
    }


    /// 카드 배경이 짙은 색(컬러드)인지 여부 — 텍스트/아이콘 색상 결정에 사용.
    /// 색은 '카테고리'를 의미한다 — 타입(템플릿/콤보)은 색이 아니라 좌상단 아이콘으로 구분.
    private func cardIsColored(memo: Memo, hasImage: Bool) -> Bool {
        if hasImage { return true }
        if memo.isFavorite || memo.isSecure { return true }
        if CategoryStore.shared.isFeatureEnabled,
           viewModel.customCategories.contains(memo.category) { return true }
        return false
    }

    private func memoTypeIconName(memo: Memo) -> String {
        if memo.isTemplate { return "wand.and.sparkles" }
        if memo.isCombo    { return "square.stack.3d.up.fill" }
        if memo.isSecure   { return "lock.fill" }
        return "doc.fill"
    }

    @ViewBuilder
    private func memoTypeIcon(memo: Memo, onColor: Bool) -> some View {
        Image(systemName: memoTypeIconName(memo: memo))
            .font(.title2)
            .foregroundStyle(onColor ? Color.white.opacity(0.9) : theme.textFaint)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func memoCardBackground(memo: Memo, imageFileName: String, hasImage: Bool) -> some View {
        if hasImage {
            ZStack {
                MemoImageBackground(fileName: imageFileName)
                LinearGradient(
                    colors: [.black.opacity(0.15), .clear, .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        } else if memo.isFavorite {
            // 즐겨찾기 = 분홍 (기본 제공되는 즐겨찾기 카테고리 색)
            Color.clipFavorite
        } else if CategoryStore.shared.isFeatureEnabled,
                  viewModel.customCategories.contains(memo.category) {
            // 색 = 카테고리 (타입은 좌상단 아이콘으로 구분)
            customCategoryColor(memo.category)
        } else if memo.isSecure {
            Color(uiColor: .systemGray3)
        } else {
            theme.surface
        }
    }

    // MARK: - Tab Background Color

    /// 하단 인디케이터 선택 dot 색상 — 탭 배경색과 시각적으로 매칭.
    /// 즐겨찾기는 분홍, 커스텀 카테고리는 그 카테고리 색, 전체는 무채색.
    private var tabIndicatorColor: Color {
        switch viewModel.selectedCategoryTab {
        case .all:       return .gray
        case .favorites: return .clipFavorite
        case .custom(let name): return customCategoryColor(name)
        }
    }

    /// 현재 탭에 맞는 배경색 — all=흰색, favorites=핑크, custom=팔레트색
    private var tabBackgroundColor: Color {
        switch viewModel.selectedCategoryTab {
        case .all:       return theme.bg
        case .favorites: return Color.clipFavorite.opacity(0.10)
        case .custom(let name): return customCategoryColor(name).opacity(0.08)
        }
    }

    /// 커스텀 카테고리 순서에 따라 결정적으로 색상 반환
    private func customCategoryColor(_ name: String) -> Color {
        let palette: [Color] = [.blue, .green, .orange, .purple, .teal, .indigo, .cyan]
        let idx = viewModel.customCategories.firstIndex(of: name) ?? 0
        return palette[idx % palette.count]
    }

    /// 커스텀 카테고리마다 고정 SF Symbol 반환 (색상 팔레트와 1:1 매핑)
    private func customCategoryIcon(_ name: String) -> String {
        // 사용자가 '카테고리 아이콘' 설정(CategoryIconSettings)에서 지정한 커스텀 심볼 우선.
        // 색맹 사용자가 색 대신 심볼로 카테고리를 구분할 수 있게 한다. 미지정 시 기본 팔레트.
        if let custom = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?
            .dictionary(forKey: "userCategoryIcons_v1") as? [String: String],
           let symbol = custom[name] {
            return symbol
        }
        return defaultIcon(for: name, in: viewModel.customCategories)
    }

    // MARK: - Category Tab Bar

    private var categoryTabBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.allCategoryTabs, id: \.self) { tab in
                        categoryTabChip(tab: tab, proxy: proxy)
                    }
                    // "+" 추가 버튼
                    Button {
                        HapticManager.shared.light()
                        showAddCategoryAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.caption.weight(.semibold))
                            Text(NSLocalizedString("추가", comment: "Add category button"))
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(theme.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().strokeBorder(theme.textFaint.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .accessibilityLabel(NSLocalizedString("카테고리 추가", comment: "Add category accessibility label"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background {
                // iOS 26+ : Liquid Glass / 이하 : ultraThinMaterial
                // ignoresSafeArea로 상태바 아래까지 확장해 카드처럼 떠있는 느낌 제거
                if #available(iOS 26, *) {
                    Rectangle()
                        .glassEffect()
                        .ignoresSafeArea(edges: .top)
                } else {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea(edges: .top)
                }
            }
            .onChange(of: viewModel.selectedCategoryTab) { _, newTab in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newTab, anchor: .center)
                }
            }
        }
        // 하단 경계 — 미세한 그림자로 자연스러운 분리
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }

    /// 카테고리 생성 제안 TipKit 카드. 수락 시 카테고리 추가 + 해당 탭으로 이동.
    /// id에 카테고리명을 포함해 카테고리별로 1회만 노출(무효화 추적)된다.
    @ViewBuilder
    private func categorySuggestionTip(name: String, count: Int) -> some View {
        let tip = CategorySuggestionTip(
            categoryRawName: name,
            displayName: Constants.localizedThemeName(name),
            count: count
        )
        TipView(tip) { action in
            if action.id == "create" {
                withAnimation { viewModel.acceptSuggestedCategory(name) }
                HapticManager.shared.success()
                tip.invalidate(reason: .actionPerformed)
            }
        }
    }

    private func categoryTabChip(tab: CategoryTab, proxy: ScrollViewProxy) -> some View {
        let isSelected = viewModel.selectedCategoryTab == tab
        return Button {
            HapticManager.shared.selection()
            viewModel.selectCategoryTab(tab)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.caption2.weight(.semibold))
                Text(tab.displayName)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                if !tab.isBuiltIn {
                    Button {
                        HapticManager.shared.light()
                        categoryToDelete = tab.displayName
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(isSelected ? .white.opacity(0.7) : theme.textFaint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(format: NSLocalizedString("'%@' 카테고리 삭제", comment: "Delete category chip"), tab.displayName))
                }
            }
            .foregroundColor(isSelected ? .white : theme.textMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule().fill(Color.blue)
                } else {
                    // 비선택 칩: glass 환경에서 자연스럽게 녹아드는 반투명
                    if #available(iOS 26, *) {
                        Capsule().fill(.thinMaterial)
                    } else {
                        Capsule().fill(theme.surfaceAlt)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .id(tab)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Category Tab View (Page Swipe)

    /// TabView.page 방식 — ScrollView 내부 제스처 충돌 없이 수평 스와이프 완벽 처리.
    /// 마지막 탭에서 왼쪽으로 더 스와이프(없는 페이지 방향) → 새 카테고리 생성 제안.
    private var categoryTabView: some View {
        let binding = Binding<CategoryTab>(
            get: { viewModel.selectedCategoryTab },
            set: { newTab in
                viewModel.selectCategoryTab(newTab)
            }
        )
        return TabView(selection: binding) {
            ForEach(viewModel.allCategoryTabs, id: \.self) { tab in
                tabPageView(for: tab)
                    .tag(tab)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .id(viewModel.customCategories)
        // 경계 스와이프 감지: 없는 페이지 방향으로 스와이프할 때만 동작.
        // 첫 탭에서 오른쪽 → 마지막 탭으로 순환,
        // 마지막 탭에서 왼쪽(더 이상 없는 방향) → 카테고리 생성 제안.
        .simultaneousGesture(
            DragGesture(minimumDistance: 60)
                .onEnded { value in
                    let h = value.translation.width
                    let v = value.translation.height
                    guard abs(h) > abs(v) * 1.5, abs(h) > 80 else { return }
                    let tabs = viewModel.allCategoryTabs
                    let idx = viewModel.selectedCategoryIndex
                    if h > 0, idx == 0 {
                        // 첫 탭에서 오른쪽 스와이프 → 마지막 탭으로
                        HapticManager.shared.light()
                        viewModel.selectCategoryTab(tabs[tabs.count - 1])
                    } else if h < 0, idx == tabs.count - 1 {
                        // 마지막 탭에서 더 왼쪽(없는 페이지 방향) → 카테고리 생성 제안
                        HapticManager.shared.light()
                        showSwipeCategoryDialog = true
                    }
                }
        )
        .overlay(alignment: .bottom) {
            if viewModel.allCategoryTabs.count > 1 {
                SwipePageIndicator(
                    total: viewModel.allCategoryTabs.count,
                    selectedIndex: viewModel.selectedCategoryIndex,
                    accentColor: tabIndicatorColor
                )
                .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder
    private func tabPageView(for tab: CategoryTab) -> some View {
        let filtered = viewModel.memos(for: tab)
        switch tab {
        case .all:
            if !viewModel.memos.isEmpty {
                allTabScrollView
            } else {
                EmptyListView
            }
        case .favorites:
            if !filtered.isEmpty {
                filteredTabScrollView(memos: filtered, isFavorites: true)
            } else {
                favoritesEmptyStateView
            }
        case .custom(let name):
            if !filtered.isEmpty {
                filteredTabScrollView(memos: filtered)
            } else {
                categoryEmptyStateView(
                    icon: "folder",
                    message: String(format: NSLocalizedString("'%@'에 메모가 없습니다", comment: "Custom category empty state"), name)
                )
            }
        }
    }

    private var allTabScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // 상단 여백 — Dynamic Island 아래 숨 쉬는 공간
                Color.clear.frame(height: 16)

                // TipKit 팁들
                VStack(spacing: 12) {
                    TipView(welcomeTip)
                        .tipBackground(theme.surface)
                        .onDisappear { AddMemoTip.welcomeTipInvalidated = true }
                    TipView(cleanUpTip) { action in
                        if action.id == "delete" {
                            deleteSampleMemos()
                            cleanUpTip.invalidate(reason: .actionPerformed)
                        } else {
                            cleanUpTip.invalidate(reason: .actionPerformed)
                        }
                    }
                    .tipBackground(theme.surface)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // Grace 배너
                if shouldShowGraceBanner {
                    GraceQuotaBannerView {
                        ProFeatureManager.markGraceBannerDismissed()
                        graceBannerVisible = false
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                // 카테고리 배지 끄기 넛지
                if showCategoryBadgeNudge {
                    categoryBadgeNudgeBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 전체 메모를 하나의 그리드로.
                // 정렬: 즐겨찾기 먼저 + lastEdited 내림차순 (viewModel.memos = sortMemos 결과).
                // 사용량(lastUsedAt) 기반 재정렬은 의도적으로 적용하지 않음 — 사용자가 위치를
                // 외워서 찾기 때문에 사용할 때마다 카드가 점프하면 안 됨.
                let allMemos = viewModel.memos
                if !allMemos.isEmpty {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(Array(allMemos.enumerated()), id: \.element.id) { index, memo in
                            memoGridCell(memo: memo)
                                .opacity(hasAppeared ? 1.0 : (reduceMotion ? 1.0 : 0.0))
                                .offset(y: (hasAppeared || reduceMotion) ? 0 : 12)
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(Double(min(index, 12)) * 0.03), value: hasAppeared)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            // 하단 safe area + 툴바 높이 확보: Liquid Glass pill 뒤로 콘텐츠가 흐름
            .padding(.bottom, 120)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: viewModel.selectedTypeFilter)
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func filteredTabScrollView(memos: [Memo], isFavorites: Bool = false) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: 16)
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(Array(memos.enumerated()), id: \.element.id) { index, memo in
                        memoGridCell(memo: memo)
                            .opacity(hasAppeared ? 1.0 : (reduceMotion ? 1.0 : 0.0))
                            .offset(y: (hasAppeared || reduceMotion) ? 0 : 12)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(Double(min(index, 12)) * 0.03), value: hasAppeared)
                    }
                    if isFavorites {
                        addFavoriteMemoCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .padding(.bottom, 120)
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var addFavoriteMemoCard: some View {
        Button {
            HapticManager.shared.light()
            showAddFavoriteMemoSheet = true
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.title2.weight(.medium))
                    .foregroundColor(theme.textFaint)
                Text(NSLocalizedString("즐겨찾기 추가", comment: "Add memo to favorites card"))
                    .font(.caption.weight(.medium))
                    .foregroundColor(theme.textFaint)
            }
            .frame(maxWidth: .infinity, minHeight: 140)  // 메모 셀과 동일 높이
            .background(theme.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
                    .strokeBorder(
                        theme.textFaint.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("즐겨찾기 메모 추가", comment: "Add favorite memo card a11y"))
    }

    private func categoryEmptyStateView(icon: String, message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(theme.textFaint)
            Text(message)
                .font(.subheadline)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var favoritesEmptyStateView: some View {
        ZStack(alignment: .center) {
            // 화면 정 중앙 — 빈 상태 안내
            VStack(spacing: 14) {
                Image(systemName: "heart.slash")
                    .font(.system(size: 44))
                    .foregroundColor(theme.textFaint)
                Text(NSLocalizedString("즐겨찾기한 메모가 없습니다.\n메모를 꾹 눌러 즐겨찾기에 추가해보세요", comment: "Favorites tab empty state with hint"))
                    .font(.subheadline)
                    .foregroundColor(theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // 상단 — 즐겨찾기 메모 추가 카드
            VStack {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    addFavoriteMemoCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Ambient Top Block

    /// 상단 통합 블록: 시간대 인사 + 스마트 컨텍스트 + 액션 카드 하나.
    /// 기존에 분산돼 있던 "방금 복사 캡처 / 컨텍스트 부제 / 히어로 카드"가
    /// 사용자 상태에 따라 자연스럽게 하나로 합쳐져 표시된다.
    private var ambientTopBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            greetingHeader
            contextActionCard
        }
    }

    /// 시간대 인사말 + 상태 한 줄 통계.
    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timeGreeting)
                .font(.system(.title, design: .serif, weight: .black))
                .foregroundColor(theme.text)
            Text(contextLine)
                .font(.footnote)
                .foregroundColor(theme.textMuted)
            if let savedText = timeSavedBadgeText {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                        .accessibilityHidden(true)
                    Text(savedText)
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(.green)
                .padding(.top, 2)
            }
        }
    }

    /// 평생 누적 절약 시간 배지 — 10분 미만이면 숨김.
    private var timeSavedBadgeText: String? {
        let total = KeyboardUsageTracker.totalTimeSavedSeconds()
        guard total >= 600 else { return nil }
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        if hours > 0 {
            return String(format: NSLocalizedString("Saved %dh %dm so far", comment: "Time saved badge h+m"), hours, minutes)
        }
        return String(format: NSLocalizedString("Saved %dm so far", comment: "Time saved badge minutes"), minutes)
    }

    /// 상황에 맞는 단 하나의 액션 카드.
    /// 우선순위: 방금 복사한 클립보드 → 최근 1시간 내 쓴 메모 히어로 → 없음(숨김)
    @ViewBuilder
    private var contextActionCard: some View {
        if viewModel.hasFreshClipboard {
            ClipboardCaptureCard(
                value: viewModel.value,
                detectedType: viewModel.clipboardDetectedType,
                confidence: viewModel.clipboardConfidence,
                onDismiss: {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                        viewModel.dismissClipboardCapture()
                    }
                },
                onSaveTap: {
                    viewModel.markClipboardSaved()
                }
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        } else if let hero = heroMemo {
            heroCardView(memo: hero)
        }
    }

    /// 시간대 기반 인사말 + 이모지 — 아침/낮/저녁/밤.
    /// 이모지는 일출·낮·일몰·밤을 근사 (실제 일출/일몰 시간은 위치 권한 피하려 시간대로 근사).
    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let emoji: String
        let phrase: String
        switch hour {
        case 5..<8:
            emoji = "🌅"
            phrase = NSLocalizedString("Good morning", comment: "Greeting: morning")
        case 8..<12:
            emoji = "☀️"
            phrase = NSLocalizedString("Good morning", comment: "Greeting: morning")
        case 12..<17:
            emoji = "🌤"
            phrase = NSLocalizedString("Good afternoon", comment: "Greeting: afternoon")
        case 17..<20:
            emoji = "🌅"
            phrase = NSLocalizedString("Good evening", comment: "Greeting: evening")
        case 20..<24:
            emoji = "🌙"
            phrase = NSLocalizedString("Good evening", comment: "Greeting: evening")
        default:
            emoji = "🌙"
            phrase = NSLocalizedString("Still up?", comment: "Greeting: late night")
        }
        return "\(emoji)  \(phrase)"
    }

    // MARK: - Scroll Fade (Notes-style)

    /// 상단 그리팅 영역의 스크롤 오프셋을 기록하는 GeometryReader.
    private var scrollOffsetReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: ScrollOffsetPreferenceKey.self,
                value: -proxy.frame(in: .named("listScroll")).minY
            )
        }
    }

    /// 스크롤 오프셋 기반 fade — 80pt 넘게 스크롤하면 완전 투명.
    private var greetingOpacity: Double {
        1 - Double(min(max(scrollOffset / 80, 0), 1))
    }

    /// 그리팅 아래 한 줄 — 상황 기반 스마트 문구.
    /// 우선순위: 오늘 사용 횟수 표시 → 최근 1시간 사용한 메모 → 기본 개수 표시
    /// 일일 카운트는 KeyboardUsageTracker (사용자 로컬 자정 기준 자연 초기화).
    private var contextLine: String {
        let memos = viewModel.memos
        let todayTaps = KeyboardUsageTracker.dailyUsageCount()

        if todayTaps > 0 {
            let format = NSLocalizedString("%d saved · %d taps today", comment: "Stats with today usage")
            return String(format: format, memos.count, todayTaps)
        }

        let hourAgo = Date().addingTimeInterval(-60 * 60)
        if let recent = memos.first(where: { ($0.lastUsedAt ?? .distantPast) >= hourAgo }) {
            let format = NSLocalizedString("Just used %@", comment: "Context: recently used memo")
            return String(format: format, recent.title)
        }

        let format = NSLocalizedString("%d saved · find what you need", comment: "Stats default")
        return String(format: format, memos.count)
    }

    /// 히어로 카드에 띄울 메모. lastUsedAt이 최근 1시간 이내인 항목만 채택.
    private var heroMemo: Memo? {
        let hourAgo = Date().addingTimeInterval(-60 * 60)
        return viewModel.memos.first(where: { ($0.lastUsedAt ?? Date.distantPast) >= hourAgo })
    }

    /// "방금 쓴 것" 히어로 카드.
    private func heroCardView(memo: Memo) -> some View {
        Button {
            HapticManager.shared.soft()
            viewModel.copyMemo(memo: memo)
        } label: {
            MemoRowView(
                memo: memo,
                fontSize: fontSize,
                onFavoriteToggle: { viewModel.toggleFavorite(memoId: memo.id) },
                onDelete: { memoToDelete = memo }
            )
            .padding(14)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                    .stroke(Color.blue.opacity(0.12), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Recency Fade

    /// 메모의 최근 사용 시점에 따라 행 opacity를 부드럽게 감쇠.
    /// 섹션 헤더 없이도 "최근 것은 생생하고 오래된 것은 조용히 뒤로 물러나는" 느낌.
    private func recencyOpacity(for memo: Memo) -> Double {
        let reference = memo.lastUsedAt ?? memo.lastEdited
        let interval = Date().timeIntervalSince(reference)
        if interval < 60 * 60 { return 1.0 }                 // 1시간 이내
        if interval < 60 * 60 * 24 { return 0.95 }           // 오늘
        if interval < 60 * 60 * 24 * 7 { return 0.88 }       // 이번 주
        return 0.78                                           // 그 이상
    }

    // MARK: - Context Menu Preview (Mail-style)

    /// 길게 눌렀을 때 떠오르는 플로팅 미리보기 — 실제 콘텐츠 전체 보기.
    private func memoContextPreview(memo: Memo) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Text(memo.title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(theme.text)
                    if memo.isTemplate {
                        TagBadge(label: NSLocalizedString("Template", comment: "Tag: template"))
                    }
                    // v4.0.8: 옵션 템플릿이 연결된 일반 메모 — Template 배지와 시각 구분
                    if !memo.isTemplate && memo.attachedTemplateId != nil {
                        TagBadge(
                            label: NSLocalizedString("+Template", comment: "Tag: optional attached template"),
                            tint: .purple
                        )
                    }
                    if memo.isCombo {
                        TagBadge(label: NSLocalizedString("Combo", comment: "Tag: combo"))
                    }
                    if memo.isSecure {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(theme.textFaint)
                    }
                    Spacer(minLength: 0)
                }

                #if os(iOS)
                if (memo.contentType == .image || memo.contentType == .mixed),
                   let firstImageFileName = memo.imageFileNames.first,
                   let image = MemoStore.shared.loadImage(fileName: firstImageFileName) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
                }
                #endif

                if !memo.value.isEmpty {
                    Text(memo.value)
                        .font(.subheadline)
                        .foregroundColor(theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                HStack(spacing: 8) {
                    if memo.clipCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.caption2)
                            Text(String(format: NSLocalizedString("Used %d×", comment: "Preview: total use count"), memo.clipCount))
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundColor(theme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.surfaceAlt)
                        .clipShape(Capsule())
                    }
                    if memo.isFavorite {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                            Text(NSLocalizedString("Favorite", comment: "Preview: favorite badge"))
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundColor(.clipFavorite)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.clipFavorite.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 420, minHeight: 120, idealHeight: 260, maxHeight: 520)
        .background(theme.surface)
    }

    // MARK: - Time Divider (day boundary)

    /// 이전 메모와 날짜 버킷(오늘/어제/이번주/이번달…)이 바뀔 때만 divider 라벨 반환.
    private func dayBoundaryLabel(for memo: Memo, previousMemo: Memo?) -> String? {
        let cal = Calendar.current
        let reference = memo.lastUsedAt ?? memo.lastEdited

        guard let prev = previousMemo else {
            return relativeDateLabel(reference)
        }
        let prevRef = prev.lastUsedAt ?? prev.lastEdited

        // 같은 날이거나 같은 버킷(예: 둘 다 "This week")이면 헤더 불필요
        if cal.isDate(reference, inSameDayAs: prevRef) { return nil }
        let currentLabel = relativeDateLabel(reference)
        let prevLabel = relativeDateLabel(prevRef)
        if currentLabel == prevLabel { return nil }
        return currentLabel
    }

    /// 초미니멀 day divider — 얇은 수평선 + 작은 라벨.
    private func timeDivider(label: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(theme.divider)
                .frame(height: 0.5)
                .accessibilityHidden(true)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(theme.textFaint)
                .textCase(.uppercase)
                .tracking(0.5)
            Rectangle()
                .fill(theme.divider)
                .frame(height: 0.5)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isHeader)
    }

    /// 캘린더 기준 상대적 날짜 라벨.
    private func relativeDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return NSLocalizedString("Today", comment: "Divider label: today")
        }
        if cal.isDateInYesterday(date) {
            return NSLocalizedString("Yesterday", comment: "Divider label: yesterday")
        }
        let daysDiff = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
        if daysDiff < 7 {
            return NSLocalizedString("This week", comment: "Divider label: earlier this week")
        }
        if daysDiff < 30 {
            return NSLocalizedString("This month", comment: "Divider label: earlier this month")
        }
        return NSLocalizedString("Earlier", comment: "Divider label: earlier than a month")
    }

    /// 타입 필터 바 섹션 (인라인)
    private var typeFilterBarInlineSection: some View {
        MemoTypeFilterBar(
            selectedFilter: $viewModel.selectedTypeFilter,
            showFavorites: $viewModel.showFavoritesFilter,
            memos: viewModel.loadedData
        )
    }

    /// 우클릭(Mac) / 롱프레스(iOS) 컨텍스트 메뉴.
    /// Toolbar 컨텐츠
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItemGroup(placement: .bottomBar) {
            toolbarButtons
        }
        #else
        ToolbarItemGroup(placement: .automatic) {
            toolbarButtons
        }
        #endif
    }

    /// Toolbar 버튼들 (iOS/macOS 공통)
    /// 구성: [검색 토글] [더보기 메뉴(히스토리·플레이스홀더·설정)]  ···  [+ 추가]
    /// "클립보드 앱의 주어는 '꺼내기'"라는 관점에서 검색/추가를 시각적으로 주연으로.
    @ViewBuilder
    private var toolbarButtons: some View {
        Button {
            HapticManager.shared.light()
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
                isSearchBarVisible.toggle()
                if !isSearchBarVisible {
                    viewModel.searchQueryString = ""
                }
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isSearchBarVisible ? .blue : .secondary)
        }

        Menu {
            NavigationLink {
                ClipboardList()
            } label: {
                Label(
                    NSLocalizedString("클립보드 히스토리", comment: "Menu: clipboard history"),
                    systemImage: "clock.arrow.circlepath"
                )
            }

            Button {
                HapticManager.shared.light()
                showCategoryManagement = true
            } label: {
                Label(
                    NSLocalizedString("카테고리 관리", comment: "Menu: manage categories"),
                    systemImage: "folder.badge.gearshape"
                )
            }

            Button {
                HapticManager.shared.light()
                viewModel.showPlaceholderManagementSheet = true
            } label: {
                Label(
                    NSLocalizedString("플레이스홀더 관리", comment: "Menu: placeholder management"),
                    systemImage: "list.bullet"
                )
            }

            Divider()

            NavigationLink {
                SettingView()
            } label: {
                Label(
                    NSLocalizedString("설정", comment: "Menu: settings"),
                    systemImage: "gearshape"
                )
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(theme.textMuted)
        }
        .accessibilityLabel(NSLocalizedString("더 보기", comment: "More options menu label"))
        .accessibilityHint(NSLocalizedString("클립보드 히스토리, 플레이스홀더 관리, 설정 메뉴를 엽니다", comment: "More options menu hint"))

        Spacer()

        Menu {
            Button {
                HapticManager.shared.light()
                if case .custom(let name) = viewModel.selectedCategoryTab { addMemoSheetCategory = name } else { addMemoSheetCategory = "" }
                showAddMemoSheet = true
            } label: {
                Label(NSLocalizedString("새 메모 만들기", comment: "Menu: new memo"), systemImage: "square.and.pencil")
            }
            Button {
                HapticManager.shared.light()
                showAddTemplateSheet = true
            } label: {
                Label(NSLocalizedString("새 템플릿 만들기", comment: "Menu: new template"), systemImage: "wand.and.sparkles")
            }
            Button {
                HapticManager.shared.light()
                showAddComboSheet = true
            } label: {
                Label(NSLocalizedString("새 콤보 만들기", comment: "Menu: new combo"), systemImage: "square.stack.3d.forward.dottedline.fill")
            }
            Button {
                HapticManager.shared.light()
                showAddImageMemoSheet = true
            } label: {
                Label(NSLocalizedString("이미지 메모 추가", comment: "Menu: new image memo"), systemImage: "photo.badge.plus")
            }
            Divider()
            Button {
                showBulkImport = true
            } label: {
                Label(NSLocalizedString("텍스트 가져오기", comment: "Menu: bulk import"), systemImage: "doc.on.clipboard")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)
        }
        .accessibilityLabel(NSLocalizedString("메모 추가", comment: "Add memo menu label"))
        .accessibilityHint(NSLocalizedString("새 메모를 작성하거나 텍스트를 가져옵니다", comment: "Add memo menu hint"))
        .popoverTip(addMemoTip)
        .sheet(isPresented: $showBulkImport) {
            BulkImportView()
        }
        .sheet(isPresented: $showCategoryManagement) {
            CategoryManagementSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAddMemoSheet, onDismiss: { viewModel.loadMemos() }) {
            NavigationStack {
                MemoAdd(insertedCategory: addMemoSheetCategory.isEmpty ? "텍스트" : addMemoSheetCategory)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(NSLocalizedString("취소", comment: "Cancel")) { showAddMemoSheet = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showAddTemplateSheet, onDismiss: { viewModel.loadMemos() }) {
            NavigationStack {
                MemoAdd(insertedIsTemplate: true)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(NSLocalizedString("취소", comment: "Cancel")) { showAddTemplateSheet = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showAddComboSheet, onDismiss: { viewModel.loadMemos() }) {
            NavigationStack {
                MemoAdd(insertedIsCombo: true)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(NSLocalizedString("취소", comment: "Cancel")) { showAddComboSheet = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showAddImageMemoSheet, onDismiss: { viewModel.loadMemos() }) {
            NavigationStack {
                MemoAdd(openImagePickerOnAppear: true)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(NSLocalizedString("취소", comment: "Cancel")) { showAddImageMemoSheet = false }
                        }
                    }
            }
        }
    }

    /// Toast 오버레이
    @ViewBuilder
    private var toastOverlay: some View {
        if viewModel.showToast {
            Text(viewModel.toastMessage)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.toastBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                .onTapGesture {
                    HapticManager.shared.soft()
                    viewModel.showToast = false
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeOut(duration: 0.2), value: viewModel.showToast)
                .padding(.bottom, 50)
                .accessibilityHidden(true)  // VoiceOver는 아래 onChange announcement로 전달
                .onChange(of: viewModel.showToast) { _, isShowing in
                    #if os(iOS)
                    if isShowing {
                        UIAccessibility.post(notification: .announcement, argument: viewModel.toastMessage)
                    }
                    #endif
                }
        }
    }

    /// Empty list — locale-aware suggestion card grid
    private var EmptyListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("이런 방법으로 쓸 수 있어요", comment: "Empty state suggestion header"))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.text)
                    Text(NSLocalizedString("탭해서 바로 내 메모로 추가할 수 있어요", comment: "Empty state suggestion subhead"))
                        .font(.subheadline)
                        .foregroundColor(theme.textMuted)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(suggestionManager.emptyStateSuggestions) { suggestion in
                        suggestionCard(suggestion)
                    }
                }
                .padding(.horizontal, 16)

                Button {
                    showAddMemoSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text(NSLocalizedString("직접 추가하기", comment: "Add memo manually button"))
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    .foregroundColor(theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.accent.opacity(0.1))
                    .cornerRadius(theme.radiusSm)
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// feature 태그에 맞게 MemoAdd를 구성한다.
    /// .template → 템플릿 토글 ON, .combo → 콤보 토글 ON, 나머지 → 일반 메모.
    private func deleteSampleMemos() {
        let sampleIds = SampleMemoStorage.load()
        guard !sampleIds.isEmpty else { return }
        do {
            let allMemos = try MemoStore.shared.load(type: .memo)
            let remaining = allMemos.filter { !sampleIds.contains($0.id) }
            try MemoStore.shared.save(memos: remaining, type: .memo)
            SampleMemoStorage.clear()
            viewModel.loadMemos()
            print("🗑️ [ClipKeyboardList] 샘플 메모 \(sampleIds.count)개 삭제 완료")
        } catch {
            print("❌ [ClipKeyboardList] 샘플 메모 삭제 실패: \(error)")
        }
    }

    /// 메모 복사 시 호출 — 3회 이상이면 카테고리 배지 끄기 넛지 표시 (1회)
    private func checkCategoryBadgeNudge() {
        guard categoryBadgeVisible else { return }
        guard !UserDefaults.standard.bool(forKey: "categoryBadgeNudgeDismissed") else { return }
        let count = UserDefaults.standard.integer(forKey: "memoCopyCount") + 1
        UserDefaults.standard.set(count, forKey: "memoCopyCount")
        if count >= 3 {
            withAnimation(.easeInOut(duration: 0.3)) { showCategoryBadgeNudge = true }
        }
    }

    /// 카테고리 색상 배지 끄기 넛지 배너
    private var categoryBadgeNudgeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.fill")
                .font(.title3)
                .foregroundColor(.blue)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("카테고리 색상 배지", comment: "Nudge: category badge title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.text)
                Text(NSLocalizedString("카드 오른쪽 점이 카테고리를 표시해요. 끄시겠어요?", comment: "Nudge: category badge message"))
                    .font(.caption)
                    .foregroundColor(theme.textMuted)
            }
            Spacer()
            VStack(spacing: 6) {
                Button {
                    UserDefaults.standard.set(false, forKey: "categoryBadgeVisible")
                    UserDefaults.standard.set(true, forKey: "categoryBadgeNudgeDismissed")
                    withAnimation { categoryBadgeVisible = false; showCategoryBadgeNudge = false }
                } label: {
                    Text(NSLocalizedString("끄기", comment: "Nudge: turn off"))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue, in: Capsule())
                }
                Button {
                    UserDefaults.standard.set(true, forKey: "categoryBadgeNudgeDismissed")
                    withAnimation { showCategoryBadgeNudge = false }
                } label: {
                    Text(NSLocalizedString("유지", comment: "Nudge: keep on"))
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                }
            }
        }
        .padding(12)
        .background(theme.surface)
        .cornerRadius(theme.radiusMd)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private func memoAdd(for suggestion: SuggestionTemplate) -> MemoAdd {
        var add = MemoAdd()
        add.insertedValue = suggestion.content
        switch suggestion.feature {
        case .template:      add.insertedIsTemplate = true
        case .combo:         add.insertedIsCombo    = true
        case .memo, .smartClipboard: break
        }
        return add
    }

    private func suggestionCard(_ suggestion: SuggestionTemplate) -> some View {
        Button {
            occasionalSuggestion_ = suggestion
            navigateToOccasionalAdd = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(suggestion.emoji)
                        .font(.title2)
                    Spacer()
                    Text(suggestion.feature.label)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(suggestion.feature.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(suggestion.feature.color.opacity(0.12))
                        .cornerRadius(theme.radiusXs)
                }

                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.text)

                Text(suggestion.content.components(separatedBy: "\n").first ?? suggestion.content)
                    .font(.caption)
                    .foregroundColor(theme.textMuted)
                    .lineLimit(3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .cornerRadius(theme.radiusMd)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: NSLocalizedString("%@ 예시 메모 추가", comment: "Suggestion card a11y label"), suggestion.title))
        .accessibilityHint(NSLocalizedString("탭하면 이 예시로 메모를 만들 수 있어요", comment: "Suggestion card a11y hint"))
    }
}

struct ClipKeyboardList_Previews: PreviewProvider {
    static var previews: some View {
        ClipKeyboardList()
    }
}

// MARK: - Swipe Page Indicator

// MARK: - Category Activation Banner (v4.1.0)

/// 카테고리 기능이 미활성일 때 메모가 5개 이상이면 상단에 노출.
/// "쓸래요" → enableFeature, "안 쓸래요" → dismissActivationBanner (영구 닫힘).
private struct CategoryActivationBanner: View {
    let onEnable: () -> Void
    let onDismiss: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "folder.badge.plus")
                    .font(.title3)
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("메모가 늘었어요", comment: "Category activation banner title"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.text)
                    Text(NSLocalizedString("카테고리로 분류해서 빠르게 찾아볼까요?", comment: "Category activation banner subtitle"))
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                Button(action: onDismiss) {
                    Text(NSLocalizedString("괜찮아요", comment: "Decline category activation"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.surfaceAlt)
                        .clipShape(Capsule())
                }
                Button(action: onEnable) {
                    Text(NSLocalizedString("써볼게요", comment: "Accept category activation"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}

// MARK: - Memo Action Sheet (long-press menu)

/// 메모 카드를 long-press 했을 때 뜨는 커스텀 bottom sheet.
/// confirmationDialog는 iOS에서 button icon을 렌더링 안 해서 자체 시트로 구현.
/// 각 행에 SF Symbol + 텍스트 표시 (삭제는 빨간색).
private struct MemoActionSheet: View {
    let memo: Memo
    /// 이동 대상 카테고리 목록 (키보드 페이지와 동일한 통일 목록).
    var categories: [String] = []
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    /// 메모를 다른 카테고리로 이동. nil이면 이동 행을 표시하지 않는다.
    var onMoveToCategory: ((String) -> Void)? = nil
    /// "새 카테고리에 추가" — 즉석 생성 후 이 메모 이동 (호스트가 alert 표시).
    var onCreateNewCategory: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // 헤더 — 메모 제목
            HStack {
                Text(memo.title)
                    .font(.headline)
                    .foregroundColor(theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // 액션 그룹
            VStack(spacing: 0) {
                actionRow(
                    label: NSLocalizedString("복사", comment: "Action: copy"),
                    systemImage: "doc.on.doc"
                ) {
                    onCopy()
                    dismiss()
                }
                Divider().padding(.leading, 56)
                actionRow(
                    label: memo.isFavorite
                        ? NSLocalizedString("즐겨찾기 해제", comment: "Action: remove favorite")
                        : NSLocalizedString("즐겨찾기 추가", comment: "Action: add favorite"),
                    systemImage: memo.isFavorite ? "heart.slash" : "heart"
                ) {
                    onToggleFavorite()
                    dismiss()
                }
                // 카테고리 이동 — 통일된 카테고리 목록으로 즉시 이동 (메모 작성 폼엔 선택 UI 없음)
                if let onMoveToCategory {
                    Divider().padding(.leading, 56)
                    Menu {
                        ForEach(categories, id: \.self) { cat in
                            Button {
                                onMoveToCategory(cat)
                                dismiss()
                            } label: {
                                if memo.category == cat {
                                    Label(cat, systemImage: "checkmark")
                                } else {
                                    Text(cat)
                                }
                            }
                        }
                        if let onCreateNewCategory {
                            Divider()
                            Button {
                                dismiss()
                                onCreateNewCategory()
                            } label: {
                                Label(NSLocalizedString("새 카테고리에 추가", comment: "Create new category and assign memo"), systemImage: "folder.badge.plus")
                            }
                        }
                        if memo.category != "기본" {
                            Divider()
                            Button {
                                onMoveToCategory("기본")
                                dismiss()
                            } label: {
                                Label(NSLocalizedString("카테고리 해제", comment: "Action: remove from category"), systemImage: "tray")
                            }
                        }
                    } label: {
                        actionRowLabel(
                            label: NSLocalizedString("카테고리 이동", comment: "Action: move to category"),
                            systemImage: "folder"
                        )
                    }
                }
                Divider().padding(.leading, 56)
                actionRow(
                    label: NSLocalizedString("수정", comment: "Action: edit"),
                    systemImage: "pencil"
                ) {
                    dismiss()
                    onEdit()
                }
                Divider().padding(.leading, 56)
                actionRow(
                    label: NSLocalizedString("삭제", comment: "Action: delete"),
                    systemImage: "trash",
                    isDestructive: true
                ) {
                    dismiss()
                    onDelete()
                }
            }
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
            .padding(.horizontal, 16)

            Spacer(minLength: 12)

            // 취소
            Button {
                dismiss()
            } label: {
                Text(NSLocalizedString("취소", comment: "Cancel"))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(theme.bg)
    }

    private func actionRow(
        label: String,
        systemImage: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            actionRowLabel(label: label, systemImage: systemImage, isDestructive: isDestructive)
        }
        .buttonStyle(.plain)
    }

    /// 행 라벨 비주얼 — Button과 Menu(카테고리 이동)가 공유.
    private func actionRowLabel(
        label: String,
        systemImage: String,
        isDestructive: Bool = false
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 24, alignment: .center)
                .foregroundColor(isDestructive ? .red : theme.text)
            Text(label)
                .font(.body)
                .foregroundColor(isDestructive ? .red : theme.text)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Category Suggestion Tip (TipKit)

/// 메모를 보고 "이 카테고리를 만들어 정리할까요?"를 부드럽게 제안하는 팁.
/// 메모는 자동 분류로 이미 `category` 값을 갖고 있어, 카테고리를 추가하면 곧바로 모인다.
/// id에 카테고리 rawValue를 포함 → 카테고리별로 1회씩 노출/무효화가 추적된다.
struct CategorySuggestionTip: Tip {
    let categoryRawName: String
    let displayName: String
    let count: Int

    var id: String { "category-suggestion-\(categoryRawName)" }

    var title: Text {
        Text(String(format: NSLocalizedString("'%@' 메모가 %d개 있어요", comment: "Category suggestion tip title — category name, memo count"),
                    displayName, count))
    }

    var message: Text? {
        Text(String(format: NSLocalizedString("'%@' 카테고리를 만들어 한 곳에 모아드릴까요?", comment: "Category suggestion tip message — category name"),
                    displayName))
    }

    var image: Image? {
        Image(systemName: "folder.badge.plus")
    }

    var actions: [Tips.Action] {
        [Tips.Action(id: "create") {
            Text(NSLocalizedString("카테고리 만들기", comment: "Category suggestion: create action button"))
        }]
    }
}

private struct SwipePageIndicator: View {
    let total: Int
    let selectedIndex: Int
    var accentColor: Color = .blue

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == selectedIndex ? accentColor : theme.textFaint.opacity(0.35))
                    .frame(width: index == selectedIndex ? 20 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: selectedIndex)
        .animation(.easeInOut(duration: 0.3), value: accentColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Memo Image Background Helper

/// 이미지 메모용 배경 뷰 — 로딩 중엔 회색 플레이스홀더, 완료 후 풀-블리드 표시
private struct MemoImageBackground: View {
    let fileName: String
    @State private var image: UIImage? = nil

    var body: some View {
        ZStack {
            Color(uiColor: .systemGray5)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundColor(Color(uiColor: .systemGray3))
            }
        }
        .clipped()
        .onAppear {
            guard image == nil, !fileName.isEmpty else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                // 파일 경로 확인
                let containerURL = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo"
                )
                let filePath = containerURL?.appendingPathComponent("Images").appendingPathComponent(fileName).path ?? "nil"
                let exists = FileManager.default.fileExists(atPath: filePath)
                print("🖼️ [MemoImageBackground] fileName='\(fileName)' path='\(filePath)' exists=\(exists)")

                let loaded = MemoStore.shared.loadImage(fileName: fileName)
                print("🖼️ [MemoImageBackground] loaded=\(loaded != nil ? "✅ \(Int(loaded!.size.width))x\(Int(loaded!.size.height))" : "❌ nil")")
                DispatchQueue.main.async { image = loaded }
            }
        }
    }
}

// MARK: - Activation Card (첫 붙여넣기 유도)

struct ActivationCard: View {
    let onPractice: () -> Void
    let onSnooze: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("⌨️")
                    .font(.title3)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("이제 다른 앱에서 써보세요", comment: "Activation card title"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.text)
                    Text(NSLocalizedString("아무 텍스트 필드 탭 → 🌐 눌러 전환 → 메모 탭", comment: "Activation card hint"))
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button(action: onPractice) {
                    Text(NSLocalizedString("지금 연습하기", comment: "Activation card: start practice button"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.accentColor)
                        .cornerRadius(theme.radiusSm)
                }

                Button(action: onSnooze) {
                    Text(NSLocalizedString("나중에", comment: "Activation card: snooze button"))
                        .font(.subheadline)
                        .foregroundColor(theme.textMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(theme.surfaceAlt)
                        .cornerRadius(theme.radiusSm)
                }
            }
        }
        .padding(14)
        .background(theme.surface)
        .cornerRadius(theme.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMd)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Template Hint Banner

struct TemplateHintBanner: View {
    let onDismiss: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.purple)
                    .font(.subheadline)
                Text(NSLocalizedString("💡 템플릿으로 반복 입력을 자동화해보세요", comment: "Template hint banner title"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.text)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                        .padding(6)
                        .background(theme.surfaceAlt)
                        .clipShape(Circle())
                }
                .accessibilityLabel(NSLocalizedString("템플릿 힌트 닫기", comment: "Dismiss template hint banner"))
            }

            Text(NSLocalizedString("{이름}님 안녕하세요! 같은 문구를 변수로 바꿔 빠르게 입력해요.", comment: "Template hint description"))
                .font(.caption)
                .foregroundColor(theme.textMuted)

            NavigationLink {
                MemoAdd(insertedIsTemplate: true)
            } label: {
                Text(NSLocalizedString("첫 템플릿 만들기", comment: "Template hint CTA button"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.purple)
                    .cornerRadius(theme.radiusSm)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onDismiss() }
            })
        }
        .padding(14)
        .background(theme.surface)
        .cornerRadius(theme.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMd)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Occasional Suggestion Banner

struct OccasionalSuggestionBanner: View {
    let suggestion: SuggestionTemplate
    let onDismiss: () -> Void
    let onAdd: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.subheadline)
                Text(NSLocalizedString("이런 것도 써보실래요?", comment: "Occasional suggestion banner title"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.text)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                        .padding(6)
                        .background(theme.surfaceAlt)
                        .clipShape(Circle())
                }
                .accessibilityLabel(NSLocalizedString("제안 닫기", comment: "Dismiss suggestion banner"))
            }

            HStack(spacing: 10) {
                Text(suggestion.emoji)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(theme.text)
                    Text(suggestion.content.components(separatedBy: "\n").first ?? suggestion.content)
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                        .lineLimit(3)
                }
                Spacer()
            }

            Button(action: onAdd) {
                Text(NSLocalizedString("지금 추가하기", comment: "Accept suggestion button"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(theme.accent)
                    .cornerRadius(theme.radiusSm)
            }
        }
        .padding(14)
        .background(theme.surface)
        .cornerRadius(theme.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMd)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Memo Type Filter Bar

struct MemoTypeFilterBar: View {
    @Binding var selectedFilter: ClipboardItemType?
    @Binding var showFavorites: Bool
    let memos: [Memo]
    @State private var isExpanded = false

    private let visibleLimit = 2

    var favoritesCount: Int { memos.filter { $0.isFavorite }.count }

    // resolvedType 기준으로 개수 계산 — 이미지/자동분류 타입까지 반영
    var typeCounts: [ClipboardItemType: Int] {
        var counts: [ClipboardItemType: Int] = [:]
        for memo in memos {
            if let type = ClipboardClassificationService.shared.resolvedType(for: memo) {
                counts[type, default: 0] += 1
            }
        }
        return counts
    }

    // 메모가 있는 타입만, 개수 많은 순 정렬
    var sortedTypes: [ClipboardItemType] {
        ClipboardItemType.allCases
            .filter { typeCounts[$0, default: 0] > 0 }
            .sorted { typeCounts[$0, default: 0] > typeCounts[$1, default: 0] }
    }

    var visibleTypes: [ClipboardItemType] {
        isExpanded ? sortedTypes : Array(sortedTypes.prefix(visibleLimit))
    }

    var hiddenCount: Int { max(0, sortedTypes.count - visibleLimit) }

    // 전체/즐겨찾기 선택 시 타입 필터 해제, 타입 선택 시 즐겨찾기 해제
    private func selectAll() {
        selectedFilter = nil
        showFavorites = false
    }
    private func selectFavorites() {
        selectedFilter = nil
        showFavorites = true
    }
    private func selectType(_ type: ClipboardItemType) {
        showFavorites = false
        selectedFilter = type
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // 전체 버튼
                MemoFilterChip(
                    title: NSLocalizedString("전체", comment: "All"),
                    icon: "list.bullet",
                    count: memos.count,
                    isSelected: selectedFilter == nil && !showFavorites
                ) { selectAll() }

                // 즐겨찾기 버튼 (전체 바로 오른쪽)
                if favoritesCount > 0 {
                    MemoFilterChip(
                        title: NSLocalizedString("즐겨찾기", comment: "Favorites filter chip"),
                        icon: "star.fill",
                        count: favoritesCount,
                        color: "orange",
                        isSelected: showFavorites
                    ) { selectFavorites() }
                }

                // 상위 2개 (또는 전체) 타입 필터
                ForEach(visibleTypes, id: \.self) { type in
                    MemoFilterChip(
                        title: type.localizedName,
                        icon: type.icon,
                        count: typeCounts[type, default: 0],
                        color: type.color,
                        isSelected: selectedFilter == type && !showFavorites
                    ) { selectType(type) }
                }

                // 더 보기 / 접기 버튼
                if hiddenCount > 0 {
                    FilterExpandChip(isExpanded: isExpanded, hiddenCount: hiddenCount) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: selectedFilter) { _, newFilter in
            // 선택된 필터가 숨겨진 영역에 있으면 자동 펼침
            guard let f = newFilter, !visibleTypes.contains(f) else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded = true }
        }
    }
}

private struct FilterExpandChip: View {
    let isExpanded: Bool
    let hiddenCount: Int
    let action: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(isExpanded
                     ? NSLocalizedString("접기", comment: "Collapse filter bar")
                     : String(format: NSLocalizedString("+%d개", comment: "More filter count"), hiddenCount))
                    .font(.footnote.weight(.medium))
                Image(systemName: isExpanded ? "chevron.left" : "chevron.right")
                    .font(.caption2.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(theme.surfaceAlt)
            .cornerRadius(theme.radiusLg)
            .foregroundColor(theme.textMuted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded
            ? NSLocalizedString("접기", comment: "Collapse filter bar")
            : String(format: NSLocalizedString("%d개 카테고리 더 보기", comment: "More categories a11y"), hiddenCount))
    }
}

struct MemoFilterChip: View {
    let title: String
    let icon: String
    let count: Int
    var color: String = "blue"
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.footnote)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.footnote)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(isSelected ? .bold : .medium)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        isSelected
                            ? Color.white.opacity(0.25)
                            : Color.black.opacity(0.1)
                    )
                    .cornerRadius(theme.radiusSm)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusLg)
                    .fill(isSelected ? Color.fromName(color) : theme.surfaceAlt)
                    .shadow(
                        color: isSelected ? Color.fromName(color).opacity(0.3) : Color.clear,
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            )
            .foregroundColor(isSelected ? .white : theme.textFaint)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusLg)
                    .strokeBorder(
                        isSelected ? Color.white.opacity(0.2) : Color.clear,
                        lineWidth: 1
                    )
            )
            .scaleEffect(isSelected ? 1.0 : 0.96)
            .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(
            String(format: NSLocalizedString("%@, %d개", comment: "Filter chip: name and count"), title, count)
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(
            isSelected
                ? NSLocalizedString("현재 선택됨", comment: "Filter chip: currently selected")
                : NSLocalizedString("탭하여 이 유형으로 필터링", comment: "Filter chip: tap to filter")
        )
    }
}

// MARK: - Sheet Modifiers
/// 모든 Sheet 프레젠테이션을 관리하는 ViewModifier
struct SheetModifiers: ViewModifier {
    // Sheet 표시 상태
    @Binding var showTemplateInputSheet: Bool
    @Binding var showPlaceholderManagementSheet: Bool
    @Binding var selectedTemplateIdForSheet: UUID?
    @Binding var selectedComboIdForSheet: UUID?

    // 데이터
    let templatePlaceholders: [String]
    @Binding var templateInputs: [String: String]
    let memos: [Memo]
    let currentTemplateMemo: Memo?
    /// v4.0.8: attachedTemplate 흐름이면 본 메모(계좌번호 등). preview 결합용.
    let attachedTemplateBaseMemo: Memo?

    // 콜백
    let onTemplateComplete: () -> Void
    let onTemplateCancel: () -> Void
    let onTemplateCopy: (Memo, String) -> Void
    let onTemplateSheetCancel: () -> Void
    let onComboDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            // 템플릿 입력 시트
            .sheet(isPresented: $showTemplateInputSheet) {
                if let template = currentTemplateMemo {
                    TemplateInputSheet(
                        placeholders: templatePlaceholders,
                        inputs: $templateInputs,
                        onComplete: onTemplateComplete,
                        onCancel: onTemplateCancel,
                        originalText: template.value,
                        baseMemoValue: attachedTemplateBaseMemo?.value ?? ""
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
            // 플레이스홀더 관리 시트
            .sheet(isPresented: $showPlaceholderManagementSheet) {
                PlaceholderManagementSheet(allMemos: memos)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            // 템플릿 편집 시트
            .sheet(item: $selectedTemplateIdForSheet) { templateId in
                TemplateSheetResolver(
                    templateId: templateId,
                    allMemos: memos,
                    onCopy: onTemplateCopy,
                    onCancel: onTemplateSheetCancel
                )
            }
            // Combo 편집 시트
            .sheet(item: $selectedComboIdForSheet) { comboId in
                ComboSheetResolver(
                    comboId: comboId,
                    allMemos: memos,
                    onDismiss: onComboDismiss
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }
}


// MARK: - Category Management Sheet

struct CategoryManagementSheet: View {
    @ObservedObject var viewModel: ClipKeyboardListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showAddAlert = false
    @State private var newName = ""
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            List {
                Section(NSLocalizedString("기본", comment: "Category section: built-in")) {
                    HStack {
                        Label {
                            Text(NSLocalizedString("전체", comment: "Category: all"))
                        } icon: {
                            Image(systemName: "square.grid.2x2.fill")
                                .foregroundColor(.blue)
                        }
                        Spacer()
                        Text(NSLocalizedString("항상 표시", comment: "Category always visible"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Toggle(isOn: Binding(
                        get: { viewModel.isCategoryVisible("__favorites__") },
                        set: { viewModel.setCategoryVisible("__favorites__", visible: $0) }
                    )) {
                        Label {
                            Text(NSLocalizedString("즐겨찾기", comment: "Category: favorites"))
                        } icon: {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.clipFavorite)
                        }
                    }
                }

                Section(NSLocalizedString("커스텀", comment: "Category section: custom")) {
                    ForEach(viewModel.customCategories, id: \.self) { cat in
                        Toggle(isOn: Binding(
                            get: { viewModel.isCategoryVisible(cat) },
                            set: { viewModel.setCategoryVisible(cat, visible: $0) }
                        )) {
                            Label(cat, systemImage: "folder.fill")
                        }
                    }
                    .onDelete { indexSet in
                        for idx in indexSet.sorted(by: >) {
                            viewModel.deleteCustomCategory(viewModel.customCategories[idx])
                        }
                    }
                    .onMove(perform: viewModel.reorderCustomCategories)

                    Button {
                        showAddAlert = true
                    } label: {
                        Label(
                            NSLocalizedString("새 카테고리 추가", comment: "Add new category button"),
                            systemImage: "plus.circle.fill"
                        )
                    }
                }
            }
            .navigationTitle(NSLocalizedString("카테고리 관리", comment: "Category management sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditing
                           ? NSLocalizedString("완료", comment: "Done editing")
                           : NSLocalizedString("편집", comment: "Edit list")) {
                        withAnimation { isEditing.toggle() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("닫기", comment: "Close sheet")) { dismiss() }
                }
            }
        }
        .alert(
            NSLocalizedString("새 카테고리", comment: "Add category alert title"),
            isPresented: $showAddAlert
        ) {
            TextField(NSLocalizedString("카테고리 이름", comment: "Category name placeholder"), text: $newName)
            Button(NSLocalizedString("추가", comment: "Add")) {
                viewModel.addCustomCategory(newName)
                newName = ""
            }
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { newName = "" }
        } message: {
            Text(NSLocalizedString("메모를 분류할 카테고리 이름을 입력하세요.", comment: "Add category alert message"))
        }
    }
}
