//
//  ClipKeyboardList.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/05/14.
//

import SwiftUI
import LocalAuthentication

var fontSize: CGFloat = 20

struct ClipKeyboardList: View {

    @StateObject private var viewModel = ClipKeyboardListViewModel()

    // MARK: - View-only State

    @State private var isSearchBarVisible = false
    @State private var memoToDelete: Memo? = nil
    @State private var graceBannerVisible: Bool = ProFeatureManager.hasGraceMemoQuota && !ProFeatureManager.didDismissGraceBanner
    @State private var showPaywallFromKeyboard: Bool = false

    @Environment(\.appTheme) private var theme

    private var shouldShowGraceBanner: Bool {
        graceBannerVisible && !ProFeatureManager.isPro
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Design handoff: bg 토큰으로 전체 배경 통일.
                theme.bg.ignoresSafeArea()

                // 메모 리스트
                if !viewModel.tokenMemos.isEmpty {
                    List {
                        // 검색 바 섹션 (조건부 표시)
                        if isSearchBarVisible {
                            Section {
                                searchBarInlineSection
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // 타입 필터 바 섹션
                        if !viewModel.loadedData.isEmpty {
                            Section {
                                typeFilterBarInlineSection
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        // v4.0 Grace 배너 (메모가 새 한도 초과한 기존 유저 1회 노출)
                        if shouldShowGraceBanner {
                            Section {
                                GraceQuotaBannerView {
                                    ProFeatureManager.markGraceBannerDismissed()
                                    graceBannerVisible = false
                                }
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        // 리뷰 배너 섹션
                        if ReviewManager.shared.shouldShowBanner {
                            Section {
                                ReviewBannerView()
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        // 맥락 부제 + 히어로 카드 (타입 필터 비활성일 때만)
                        if viewModel.selectedTypeFilter == nil {
                            Section {
                                contextLeadView
                                if let hero = heroMemo {
                                    heroCardView(memo: hero)
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        // 메모 리스트 섹션 (타입 필터 활성 시 그룹핑 비활성)
                        if viewModel.selectedTypeFilter != nil {
                            Section {
                                ForEach(viewModel.tokenMemos) { memo in
                                    memoRow(memo: memo)
                                }
                            }
                        } else {
                            ForEach(groupedSections, id: \.id) { group in
                                Section {
                                    ForEach(group.memos) { memo in
                                        memoRow(memo: memo)
                                    }
                                } header: {
                                    Text(group.localizedTitle)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(theme.textMuted)
                                        .textCase(nil)
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }

                // 빈 화면
                if viewModel.tokenMemos.isEmpty {
                    EmptyListView
                }
            }
            .task {
                print("🔄 [task] 메모 리프레시")
                viewModel.loadMemos()
            }
            .toolbar {
                toolbarContent
            }
            // Toast 메시지 오버레이
            .overlay(alignment: .bottom) {
                toastOverlay
            }
            .animation(.easeInOut(duration: 0.5), value: viewModel.showToast)

            // Navigation 설정
            .navigationTitle(NSLocalizedString("저장된 항목", comment: "Saved items"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            // 검색 및 필터 변경 감지
            .onChange(of: viewModel.searchQueryString, perform: { _ in viewModel.applyFilters() })
            .onChange(of: viewModel.selectedTypeFilter, perform: { _ in
                viewModel.applyFilters()
                viewModel.saveSelectedFilter()
            })
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
                       let idx = viewModel.tokenMemos.firstIndex(where: { $0.id == memo.id }) {
                        viewModel.deleteMemo(at: IndexSet(integer: idx))
                    }
                    memoToDelete = nil
                }
                Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {
                    memoToDelete = nil
                }
            } message: {
                Text(NSLocalizedString("이 작업은 취소할 수 없습니다.", comment: "Delete warning"))
            }
            // 각종 Sheet Modifiers
            .modifier(SheetModifiers(
                showTemplateInputSheet: $viewModel.showTemplateInputSheet,
                showPlaceholderManagementSheet: $viewModel.showPlaceholderManagementSheet,
                selectedTemplateIdForSheet: $viewModel.selectedTemplateIdForSheet,
                selectedComboIdForSheet: $viewModel.selectedComboIdForSheet,
                templatePlaceholders: viewModel.templatePlaceholders,
                templateInputs: $viewModel.templateInputs,
                tokenMemos: viewModel.tokenMemos,
                currentTemplateMemo: viewModel.currentTemplateMemo,
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
            // 단축키 메모 오버레이
            .overlay(content: {
                shortcutMemoOverlay
            })
            .onAppear {
                viewModel.onAppear()
                fontSize = UserDefaults.standard.object(forKey: "fontSize") as? CGFloat ?? 20.0
                print("🔤 [ClipKeyboardList] 폰트 크기: \(fontSize)")
            }
            .paywall(isPresented: $showPaywallFromKeyboard, triggeredBy: nil)
            .onReceive(NotificationCenter.default.publisher(for: .showPaywall)) { _ in
                showPaywallFromKeyboard = true
            }
        }
    }

    // MARK: - View Sections

    /// 검색 바 섹션 (인라인)
    private var searchBarInlineSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme.textFaint)
                .font(.system(size: 16))

            TextField(NSLocalizedString("검색", comment: "Search"), text: $viewModel.searchQueryString)
                .textFieldStyle(PlainTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !viewModel.searchQueryString.isEmpty {
                Button(action: {
                    HapticManager.shared.soft()
                    viewModel.searchQueryString = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.textFaint)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.surfaceAlt)
        .cornerRadius(theme.radiusSm)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Context Lead + Hero Card

    /// 나브 타이틀 아래 인라인 부제.
    /// - 최근 1시간 내 사용한 메모 있으면 "방금 전 %@ 꺼냈어요"
    /// - 오늘 여러 번 쓴 메모 있으면 "오늘 %@ 많이 썼어요"
    /// - 없으면 "저장된 %d개 · 필요한 거 찾아봐요"
    private var contextLeadView: some View {
        Text(contextLeadText)
            .font(.system(size: 14))
            .foregroundColor(theme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }

    private var contextLeadText: String {
        let memos = viewModel.tokenMemos
        let now = Date()
        let hourAgo = now.addingTimeInterval(-60 * 60)

        if let recent = memos.first(where: { ($0.lastUsedAt ?? Date.distantPast) >= hourAgo }) {
            let format = NSLocalizedString("Just used %@", comment: "Context lead: recently used memo")
            return String(format: format, recent.title)
        }

        let topToday = memos
            .filter {
                guard let used = $0.lastUsedAt else { return false }
                return Calendar.current.isDateInToday(used) && $0.clipCount >= 2
            }
            .max(by: { $0.clipCount < $1.clipCount })
        if let topToday {
            let format = NSLocalizedString("Used %@ a lot today", comment: "Context lead: most-used today")
            return String(format: format, topToday.title)
        }

        let format = NSLocalizedString("%d saved · find what you need", comment: "Context lead: default with count")
        return String(format: format, memos.count)
    }

    /// 히어로 카드에 띄울 메모. lastUsedAt이 최근 1시간 이내인 항목만 채택.
    private var heroMemo: Memo? {
        let hourAgo = Date().addingTimeInterval(-60 * 60)
        return viewModel.tokenMemos.first(where: { ($0.lastUsedAt ?? Date.distantPast) >= hourAgo })
    }

    /// "방금 쓴 것" 히어로 카드.
    private func heroCardView(memo: Memo) -> some View {
        Button {
            viewModel.copyMemo(memo: memo)
        } label: {
            MemoRowView(memo: memo, fontSize: fontSize)
                .padding(12)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusMd)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 4)
    }

    /// 타입 필터 바 섹션 (인라인)
    private var typeFilterBarInlineSection: some View {
        MemoTypeFilterBar(selectedFilter: $viewModel.selectedTypeFilter, memos: viewModel.loadedData)
    }

    /// 메모 행
    private func memoRow(memo: Memo) -> some View {
        Button {
            viewModel.copyMemo(memo: memo)
        } label: {
            MemoRowView(
                memo: memo,
                fontSize: fontSize,
                showFavoriteNudge: viewModel.tokenMemos.first?.id == memo.id && viewModel.showFavoriteNudge
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            editButton(memo: memo)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                memoToDelete = memo
            } label: {
                Label(NSLocalizedString("삭제", comment: "Delete memo"), systemImage: "trash")
            }
            Button {
                viewModel.toggleFavorite(memoId: memo.id)
            } label: {
                Label(
                    memo.isFavorite
                        ? NSLocalizedString("즐겨찾기 해제", comment: "Remove favorite")
                        : NSLocalizedString("즐겨찾기", comment: "Add favorite"),
                    systemImage: memo.isFavorite ? "heart.slash" : "heart"
                )
            }
            .tint(.pink)
        }
        .contextMenu {
            memoContextMenu(memo: memo)
        }
        .transition(.scale)
    }

    /// 우클릭(Mac) / 롱프레스(iOS) 컨텍스트 메뉴.
    /// swipe 액션은 iOS trackpad에서만 닿고 Mac에서는 불편하므로 같은 액션을 컨텍스트로도 제공.
    @ViewBuilder
    private func memoContextMenu(memo: Memo) -> some View {
        Button {
            viewModel.copyMemo(memo: memo)
        } label: {
            Label(NSLocalizedString("Copy", comment: "Context: copy"), systemImage: "doc.on.doc")
        }

        Button {
            viewModel.toggleFavorite(memoId: memo.id)
        } label: {
            Label(
                memo.isFavorite
                    ? NSLocalizedString("즐겨찾기 해제", comment: "Remove favorite")
                    : NSLocalizedString("즐겨찾기", comment: "Add favorite"),
                systemImage: memo.isFavorite ? "heart.slash" : "heart"
            )
        }

        Divider()

        NavigationLink {
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
        } label: {
            Label(NSLocalizedString("수정", comment: "Edit"), systemImage: "pencil")
        }

        Divider()

        Button(role: .destructive) {
            memoToDelete = memo
        } label: {
            Label(NSLocalizedString("삭제", comment: "Delete memo"), systemImage: "trash")
        }
    }

    /// 수정 버튼
    private func editButton(memo: Memo) -> some View {
        NavigationLink {
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
        } label: {
            Label(NSLocalizedString("수정", comment: "Edit"), systemImage: "pencil")
        }
        .tint(.green)
    }

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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                viewModel.showPlaceholderManagementSheet = true
            } label: {
                Label(
                    NSLocalizedString("플레이스홀더 관리", comment: "Menu: placeholder management"),
                    systemImage: "list.bullet"
                )
            }

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

        Spacer()

        NavigationLink {
            MemoAdd()
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.blue)
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
        }
    }

    /// 단축키 메모 오버레이
    @ViewBuilder
    private var shortcutMemoOverlay: some View {
        VStack {
            Spacer()
            if !viewModel.value.isEmpty {
                ShortcutMemoView(
                    keyword: $viewModel.keyword,
                    value: $viewModel.value,
                    tokenMemos: $viewModel.tokenMemos,
                    originalData: $viewModel.loadedData,
                    showShortcutSheet: $viewModel.showShortcutSheet,
                    detectedType: viewModel.clipboardDetectedType,
                    confidence: viewModel.clipboardConfidence
                )
                .offset(y: 0)
                .shadow(radius: 15)
                .opacity(viewModel.showShortcutSheet ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).delay(0.3), value: viewModel.showShortcutSheet)
            }
        }
    }

    /// Empty list view
    private var EmptyListView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 24) {
                Text(NSLocalizedString("자주 치는 문장이 뭔가요?", comment: "Empty state question"))
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    Text("\"\(NSLocalizedString("회의가 10분 늦어질 것 같습니다", comment: "Empty state example 1"))\"")
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                    Text("\"\(NSLocalizedString("확인했습니다. 검토 후 답변드리겠습니다", comment: "Empty state example 2"))\"")
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
                .multilineTextAlignment(.center)

                NavigationLink {
                    MemoAdd()
                } label: {
                    Text(NSLocalizedString("첫 클립 추가", comment: "Add first clip button"))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(height: 44)
                        .padding(.horizontal, 24)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 30)
            .background(theme.bg)
            .cornerRadius(theme.radiusLg)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
}

struct ClipKeyboardList_Previews: PreviewProvider {
    static var previews: some View {
        ClipKeyboardList()
    }
}


// MARK: - Section Grouping (recency buckets)

struct MemoSectionGroup: Identifiable {
    let id: String
    let localizedTitle: String
    let memos: [Memo]
}

extension ClipKeyboardList {
    /// 타입 필터가 꺼져 있을 때 사용하는 시간 기반 섹션 그룹.
    /// - 방금(1시간 이내 사용) / 자주 쓰는 것(오늘+clipCount≥3) / 이번 주 / 더 오래
    /// - 즐겨찾기 정렬은 ViewModel.sortMemos에서 이미 처리되어 들어오므로 각 버킷 내 상대순서는 보존된다.
    var groupedSections: [MemoSectionGroup] {
        let memos = viewModel.tokenMemos
        guard !memos.isEmpty else { return [] }

        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-60 * 60)
        let weekAgo = now.addingTimeInterval(-60 * 60 * 24 * 7)

        var justNow: [Memo] = []
        var frequent: [Memo] = []
        var thisWeek: [Memo] = []
        var older: [Memo] = []

        for memo in memos {
            let reference = memo.lastUsedAt ?? memo.lastEdited
            if reference >= oneHourAgo {
                justNow.append(memo)
                continue
            }
            if memo.clipCount >= 3 && reference >= weekAgo {
                frequent.append(memo)
                continue
            }
            if reference >= weekAgo {
                thisWeek.append(memo)
                continue
            }
            older.append(memo)
        }

        var groups: [MemoSectionGroup] = []
        if !justNow.isEmpty {
            groups.append(MemoSectionGroup(
                id: "just-now",
                localizedTitle: NSLocalizedString("Just now", comment: "Section header: memos used in the last hour"),
                memos: justNow
            ))
        }
        if !frequent.isEmpty {
            groups.append(MemoSectionGroup(
                id: "frequent",
                localizedTitle: NSLocalizedString("Frequent", comment: "Section header: frequently used memos"),
                memos: frequent
            ))
        }
        if !thisWeek.isEmpty {
            groups.append(MemoSectionGroup(
                id: "this-week",
                localizedTitle: NSLocalizedString("This week", comment: "Section header: memos used this week"),
                memos: thisWeek
            ))
        }
        if !older.isEmpty {
            groups.append(MemoSectionGroup(
                id: "older",
                localizedTitle: NSLocalizedString("Older", comment: "Section header: older memos"),
                memos: older
            ))
        }
        return groups
    }
}


// MARK: - Memo Type Filter Bar

struct MemoTypeFilterBar: View {
    @Binding var selectedFilter: ClipboardItemType?
    let memos: [Memo]

    // 메모에 설정된 category(테마) 기준으로 개수 계산
    var typeCounts: [ClipboardItemType: Int] {
        var counts: [ClipboardItemType: Int] = [:]
        for type in ClipboardItemType.allCases {
            counts[type] = memos.filter { $0.category == type.rawValue }.count
        }
        return counts
    }

    // 개수가 많은 순서대로 타입 정렬
    var sortedTypes: [ClipboardItemType] {
        ClipboardItemType.allCases.sorted { type1, type2 in
            let count1 = typeCounts[type1, default: 0]
            let count2 = typeCounts[type2, default: 0]
            return count1 > count2
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // 전체 버튼 (항상 첫 번째)
                MemoFilterChip(
                    title: NSLocalizedString("전체", comment: "All"),
                    icon: "list.bullet",
                    count: memos.count,
                    isSelected: selectedFilter == nil
                ) {
                    selectedFilter = nil
                }

                // 타입별 필터 (개수가 많은 순서대로 정렬)
                ForEach(sortedTypes, id: \.self) { type in
                    MemoFilterChip(
                        title: type.localizedName,
                        icon: type.icon,
                        count: typeCounts[type, default: 0],
                        color: type.color,
                        isSelected: selectedFilter == type
                    ) {
                        selectedFilter = type
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
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
                    .font(.system(size: 13))
                    .fontWeight(isSelected ? .semibold : .regular)
                Text(title)
                    .font(.system(size: 13))
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("\(count)")
                    .font(.system(size: 11))
                    .fontWeight(isSelected ? .bold : .medium)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        isSelected
                            ? Color.white.opacity(0.25)
                            : Color.black.opacity(0.1)
                    )
                    .cornerRadius(8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18)
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
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        isSelected ? Color.white.opacity(0.2) : Color.clear,
                        lineWidth: 1
                    )
            )
            .scaleEffect(isSelected ? 1.0 : 0.96)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
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
    let tokenMemos: [Memo]
    let currentTemplateMemo: Memo?

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
                if currentTemplateMemo != nil {
                    TemplateInputSheet(
                        placeholders: templatePlaceholders,
                        inputs: $templateInputs,
                        onComplete: onTemplateComplete,
                        onCancel: onTemplateCancel
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
            // 플레이스홀더 관리 시트
            .sheet(isPresented: $showPlaceholderManagementSheet) {
                PlaceholderManagementSheet(allMemos: tokenMemos)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            // 템플릿 편집 시트
            .sheet(item: $selectedTemplateIdForSheet) { templateId in
                TemplateSheetResolver(
                    templateId: templateId,
                    allMemos: tokenMemos,
                    onCopy: onTemplateCopy,
                    onCancel: onTemplateSheetCancel
                )
            }
            // Combo 편집 시트
            .sheet(item: $selectedComboIdForSheet) { comboId in
                ComboSheetResolver(
                    comboId: comboId,
                    allMemos: tokenMemos,
                    onDismiss: onComboDismiss
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }
}

// UUID를 Identifiable로 만들기 위한 extension
extension UUID: Identifiable {
    public var id: UUID { self }
}
