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

    var body: some View {
        NavigationStack {
            ZStack {
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

                        // 리뷰 배너 섹션
                        if ReviewManager.shared.shouldShowBanner {
                            Section {
                                ReviewBannerView()
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        // 메모 리스트 섹션
                        Section {
                            ForEach(viewModel.tokenMemos) { memo in
                                memoRow(memo: memo)
                            }
                            .onDelete(perform: viewModel.deleteMemo)
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
        }
    }

    // MARK: - View Sections

    /// 검색 바 섹션 (인라인)
    private var searchBarInlineSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
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
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
        .transition(.scale)
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

        NavigationLink {
            ClipboardList()
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.secondary)
        }

        Button {
            HapticManager.shared.light()
            viewModel.showPlaceholderManagementSheet = true
        } label: {
            Image(systemName: "list.bullet")
                .foregroundColor(.secondary)
        }

        NavigationLink {
            SettingView()
        } label: {
            Image(systemName: "gearshape")
                .foregroundColor(.secondary)
        }

        Spacer()

        NavigationLink {
            MemoAdd()
        } label: {
            Image(systemName: "plus")
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
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
                        .foregroundColor(.secondary)
                    Text("\"\(NSLocalizedString("확인했습니다. 검토 후 답변드리겠습니다", comment: "Empty state example 2"))\"")
                        .font(.body)
                        .foregroundColor(.secondary)
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
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(20)
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
                    .fill(isSelected ? Color.fromName(color) : Color(.systemGray4))
                    .shadow(
                        color: isSelected ? Color.fromName(color).opacity(0.3) : Color.clear,
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            )
            .foregroundColor(isSelected ? .white : Color(.systemGray))
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
