//
//  ClipboardList.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/06/03.
//  Enhanced with Smart Classification by Claude Code
//

import SwiftUI

struct ClipboardList: View {

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var clipboardHistory: [SmartClipboardHistory] = []
    @State private var selectedFilter: ClipboardItemType? = nil

    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var showSaveDialog: Bool = false
    @State private var itemToSave: SmartClipboardHistory?

    // 자동 추가 개선
    @State private var recentlyAddedId: UUID? = nil
    @State private var isCheckingClipboard: Bool = false

    // Combo 생성 (Phase 2)
    @State private var isSelectingForCombo: Bool = false
    @State private var selectedForCombo: Set<UUID> = []
    @State private var showComboCreation: Bool = false

    // 인지 장애 접근성: 파괴적 작업 전 확인 알림
    @State private var showClearAllConfirm: Bool = false

    // 붙여넣기 허용 팁
    @State private var showPasteTip: Bool = !UserDefaults.standard.bool(forKey: "pasteTipDismissed")

    var filteredHistory: [SmartClipboardHistory] {
        if let filter = selectedFilter {
            return clipboardHistory.filter { $0.detectedType == filter }
        }
        return clipboardHistory
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 타입 필터 바
                if !clipboardHistory.isEmpty {
                    TypeFilterBar(selectedFilter: $selectedFilter, history: clipboardHistory)
                }

                // 붙여넣기 허용 팁 배너
                if showPasteTip {
                    PasteTipBanner {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showPasteTip = false
                        }
                        UserDefaults.standard.set(true, forKey: "pasteTipDismissed")
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 히스토리 리스트
                ScrollViewReader { proxy in
                    List {
                        if filteredHistory.isEmpty {
                            EmptyListView
                        } else {
                            ForEach(filteredHistory) { item in
                                HStack(spacing: 12) {
                                    // 선택 모드 체크박스
                                    if isSelectingForCombo {
                                        let isChecked = selectedForCombo.contains(item.id)
                                        Button {
                                            toggleSelection(item.id)
                                        } label: {
                                            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(isChecked ? .blue : .gray)
                                                .font(.title3)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(isChecked
                                            ? NSLocalizedString("선택됨", comment: "Combo checkbox: selected")
                                            : NSLocalizedString("선택 안 됨", comment: "Combo checkbox: not selected")
                                        )
                                        .accessibilityHint(NSLocalizedString("탭하여 Combo에 포함하거나 제외합니다", comment: "Combo checkbox hint"))
                                        .accessibilityAddTraits(isChecked ? [.isButton, .isSelected] : .isButton)
                                    }

                                    ClipboardItemRow(
                                        item: item,
                                        isHighlighted: item.id == recentlyAddedId,
                                        onTap: {
                                            if isSelectingForCombo {
                                                toggleSelection(item.id)
                                            } else {
                                                copyToPasteboard(item)
                                            }
                                        },
                                        onSave: {
                                            if !isSelectingForCombo {
                                                prepareToSave(item)
                                            }
                                        },
                                        onTypeChange: { newType in
                                            if !isSelectingForCombo {
                                                updateItemType(item: item, newType: newType)
                                            }
                                        }
                                    )
                                }
                                .id(item.id)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowSeparator(.hidden)
                            }
                            .onDelete(perform: isSelectingForCombo ? nil : deleteItems)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(theme.bg)
                    .onChange(of: recentlyAddedId) { _, newId in
                        if let id = newId {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) {
                                proxy.scrollTo(id, anchor: .top)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isSelectingForCombo
                ? NSLocalizedString("Combo 생성", comment: "Clipboard list: combo creation mode title")
                : NSLocalizedString("클립보드 히스토리", comment: "Clipboard list navigation title")
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectingForCombo {
                        Button(NSLocalizedString("취소", comment: "Cancel combo selection")) {
                            isSelectingForCombo = false
                            selectedForCombo.removeAll()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelectingForCombo {
                        Button(String(format: NSLocalizedString("생성 (%d)", comment: ""), selectedForCombo.count)) {
                            if !selectedForCombo.isEmpty {
                                showComboCreation = true
                            }
                        }
                        .disabled(selectedForCombo.isEmpty)
                    } else {
                        Menu {
                            Button {
                                isSelectingForCombo = true
                            } label: {
                                Label(NSLocalizedString("Combo 생성", comment: "Create combo from clipboard items"), systemImage: "arrow.triangle.2.circlepath.circle")
                            }

                            Divider()

                            Button(role: .destructive) {
                                showClearAllConfirm = true
                            } label: {
                                Label(NSLocalizedString("전체 삭제", comment: "Clear all clipboard history"), systemImage: "trash")
                            }

                            Button {
                                selectedFilter = nil
                            } label: {
                                Label(NSLocalizedString("필터 초기화", comment: "Reset filter"), systemImage: "line.3.horizontal.decrease.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .onAppear {
                checkAndAddCurrentClipboard()
                loadHistory()
            }

            // Toast 메시지
            VStack {
                Spacer()
                if showToast {
                    HStack(spacing: 12) {
                        Text(toastMessage)
                            .font(.body)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)

                        Button(action: {
                            withAnimation(reduceMotion ? nil : .spring(response: 0.3)) {
                                showToast = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.body)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.8))
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showToast)
        }
        .sheet(isPresented: $showSaveDialog) {
            if let item = itemToSave {
                SaveToMemoSheet(item: item) { savedSuccessfully in
                    if savedSuccessfully {
                        showToast(message: NSLocalizedString("메모로 저장되었습니다", comment: "Clipboard item saved as memo"))
                    }
                    showSaveDialog = false
                }
            }
        }
        .sheet(isPresented: $showComboCreation) {
            CreateComboSheet(itemCount: selectedForCombo.count) { title, interval in
                createComboFromSelection(title: title, interval: interval)
                showComboCreation = false
            } onCancel: {
                showComboCreation = false
            }
        }
        .toolbarBackground(theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert(NSLocalizedString("클립보드 히스토리 전체 삭제", comment: "Clear all confirm title"),
               isPresented: $showClearAllConfirm) {
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("전체 삭제", comment: "Confirm clear all"), role: .destructive) {
                clearAll()
            }
        } message: {
            Text(NSLocalizedString("저장된 클립보드 항목이 모두 삭제됩니다. 이 작업은 되돌릴 수 없습니다.", comment: "Clear all confirm message"))
        }
    }

    /// Empty list view
    private var EmptyListView: some View {
        VStack(spacing: 5) {
            Image(systemName: selectedFilter == nil ? "eyes" : "magnifyingglass")
                .font(.system(size: 45))
                .padding(10)

            if selectedFilter == nil {
                Text(NSLocalizedString("클립보드 히스토리 없음", comment: "No clipboard history"))
                    .font(.system(.title2)).bold()
                Text(NSLocalizedString("복사한 내용이 자동으로 여기에 저장됩니다\n(최대 100개, 7일간 유지)", comment: "Clipboard history empty description"))
                    .opacity(0.7)
            } else {
                Text(String(format: NSLocalizedString("%@ 타입 없음", comment: "No items of type"), selectedFilter!.localizedName))
                    .font(.system(.title2)).bold()
                Text(NSLocalizedString("이 타입으로 분류된 항목이 없습니다", comment: "No items of this type"))
                    .opacity(0.7)
            }
        }
        .multilineTextAlignment(.center)
        .padding(30)
    }

    // MARK: - Actions

    private func checkAndAddCurrentClipboard() {
        guard !isCheckingClipboard else { return }
        isCheckingClipboard = true
        defer { isCheckingClipboard = false }

        guard let currentClipboard = UIPasteboard.general.string,
              !currentClipboard.isEmpty else { return }

        do {
            let history = try MemoStore.shared.loadSmartClipboardHistory()
            guard !isAlreadyLatestItem(currentClipboard, in: history) else { return }

            try MemoStore.shared.addToSmartClipboardHistory(content: currentClipboard)
            print("✅ [ClipboardList] 클립보드 자동 추가: \(currentClipboard.prefix(30))...")
            loadHistory()

            let updatedHistory = try MemoStore.shared.loadSmartClipboardHistory()
            if let newItem = updatedHistory.first {
                highlightNewlyAdded(newItem)
            }
        } catch {
            print("❌ [ClipboardList] 클립보드 체크 실패: \(error)")
        }
    }

    private func isAlreadyLatestItem(_ content: String, in history: [SmartClipboardHistory]) -> Bool {
        guard let latest = history.first, latest.content == content else { return false }
        print("ℹ️ [ClipboardList] 이미 최근 항목에 존재: \(content.prefix(30))...")
        return true
    }

    private func highlightNewlyAdded(_ item: SmartClipboardHistory) {
        recentlyAddedId = item.id
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
            showToast(message: String(format: NSLocalizedString("📋 새로운 %@ 항목이 추가되었습니다", comment: ""), item.detectedType.localizedName))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(reduceMotion ? nil : .default) { recentlyAddedId = nil }
        }
    }

    private func copyToPasteboard(_ item: SmartClipboardHistory) {
        UIPasteboard.general.string = item.content
        showToast(message: String(format: NSLocalizedString("[%@] 복사됨", comment: ""), String(item.content.prefix(30))))
    }

    private func prepareToSave(_ item: SmartClipboardHistory) {
        itemToSave = item
        showSaveDialog = true
    }

    private func updateItemType(item: SmartClipboardHistory, newType: ClipboardItemType) {
        do {
            try MemoStore.shared.updateClipboardItemType(id: item.id, correctedType: newType)
            loadHistory()
            showToast(message: String(format: NSLocalizedString("타입이 %@로 변경되었습니다", comment: ""), newType.localizedName))
        } catch {
            print("❌ [ClipboardList.updateItemType] \(error)")
        }
    }

    private func showToast(message: String) {
        toastMessage = message
        showToast = true
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }

    private func loadHistory() {
        do {
            clipboardHistory = try MemoStore.shared.loadSmartClipboardHistory()
        } catch {
            print("❌ [ClipboardList.loadHistory] \(error)")
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let filtered = filteredHistory
        let idsToDelete = offsets.map { filtered[$0].id }

        clipboardHistory.removeAll { item in idsToDelete.contains(item.id) }

        do {
            try MemoStore.shared.saveSmartClipboardHistory(history: clipboardHistory)
        } catch {
            print("❌ [ClipboardList.deleteItems] \(error)")
        }
    }

    private func clearAll() {
        clipboardHistory.removeAll()
        do {
            try MemoStore.shared.saveSmartClipboardHistory(history: [])
        } catch {
            print("❌ [ClipboardList.clearAll] \(error)")
        }
    }

    // MARK: - Combo 관련 함수

    private func toggleSelection(_ id: UUID) {
        if selectedForCombo.contains(id) {
            selectedForCombo.remove(id)
        } else {
            selectedForCombo.insert(id)
        }
    }

    private func createComboFromSelection(title: String, interval: TimeInterval) {
        let selectedItems = clipboardHistory.filter { selectedForCombo.contains($0.id) }

        // 순서 보장: 리스트 순서대로
        let sortedItems = selectedItems.sorted { first, second in
            guard let firstIndex = clipboardHistory.firstIndex(where: { $0.id == first.id }),
                  let secondIndex = clipboardHistory.firstIndex(where: { $0.id == second.id }) else {
                return false
            }
            return firstIndex < secondIndex
        }

        let comboItems = sortedItems.enumerated().map { index, item in
            ComboItem(
                type: .clipboardHistory,
                referenceId: item.id,
                order: index,
                displayTitle: String(item.content.prefix(30)),
                displayValue: item.content
            )
        }

        let combo = Combo(
            title: title,
            items: comboItems,
            interval: interval
        )

        do {
            try MemoStore.shared.addCombo(combo)
            showToast(message: String(format: NSLocalizedString("Combo '%@' 생성됨", comment: ""), title))

            // 선택 모드 종료
            isSelectingForCombo = false
            selectedForCombo.removeAll()
        } catch {
            showToast(message: String(format: NSLocalizedString("Combo 생성 실패: %@", comment: ""), error.localizedDescription))
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Type Filter Bar

struct TypeFilterBar: View {
    @Binding var selectedFilter: ClipboardItemType?
    let history: [SmartClipboardHistory]
    @Environment(\.appTheme) private var theme

    var typeCounts: [ClipboardItemType: Int] {
        Dictionary(grouping: history, by: { $0.detectedType })
            .mapValues { $0.count }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 전체 버튼
                FilterChip(
                    title: NSLocalizedString("전체", comment: "All"),
                    icon: "list.bullet",
                    count: history.count,
                    isSelected: selectedFilter == nil
                ) {
                    selectedFilter = nil
                }

                // 타입별 필터 (개수가 있는 것만)
                ForEach(ClipboardItemType.allCases.filter { typeCounts[$0, default: 0] > 0 }, id: \.self) { type in
                    FilterChip(
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
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(theme.bg)
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let count: Int
    var color: String = "blue"
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body)
                Text(title)
                    .font(.body)
                    .fontWeight(isSelected ? .bold : .regular)
                Text("\(count)")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                    .cornerRadius(theme.radiusXs)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.fromName(color) : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(theme.radiusLg)
        }
    }
}

// MARK: - Clipboard Item Row

struct ClipboardItemRow: View {
    let item: SmartClipboardHistory
    var isHighlighted: Bool = false
    let onTap: () -> Void
    let onSave: () -> Void
    let onTypeChange: (ClipboardItemType) -> Void
    @Environment(\.appTheme) private var theme

    var displayType: ClipboardItemType {
        item.userCorrectedType ?? item.detectedType
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    // 타입 아이콘 — VoiceOver에서는 합성 레이블이 타입을 포함하므로 숨김
                    Image(systemName: displayType.icon)
                        .font(.title3)
                        .foregroundColor(Color.fromName(displayType.color))
                        .frame(width: 24)
                        .scaleEffect(isHighlighted ? 1.2 : 1.0)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        // 내용
                        Text(item.content)
                            .font(.body)
                            .lineLimit(3)
                            .foregroundColor(.primary)

                        // 메타 정보
                        HStack(spacing: 8) {
                            // 타입 태그
                            HStack(spacing: 4) {
                                Text(displayType.localizedName)
                                    .font(.caption2)

                                if item.userCorrectedType != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .accessibilityHidden(true)
                                } else if item.confidence > 0.8 {
                                    Image(systemName: "sparkles")
                                        .font(.caption2)
                                        .accessibilityHidden(true)
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.fromName(displayType.color).opacity(0.2))
                            .cornerRadius(theme.radiusXs)

                            // 시간
                            Text(formatDate(item.copiedAt))
                                .font(.body)
                                .foregroundColor(theme.textFaint)

                            Spacer()

                            // 임시 태그
                            if item.isTemporary {
                                Text(NSLocalizedString("임시", comment: "Temporary"))
                                    .font(.body)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(theme.radiusXs)
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusMd)
                .fill(theme.surface)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMd)
                .fill(isHighlighted ? Color.fromName(displayType.color).opacity(0.1) : Color.clear)
                .animation(.easeInOut(duration: 0.3), value: isHighlighted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMd)
                .stroke(isHighlighted ? Color.fromName(displayType.color).opacity(0.5) : Color.clear, lineWidth: 2)
                .animation(.easeInOut(duration: 0.3), value: isHighlighted)
        )
        .accessibilityLabel({
            var parts = [displayType.localizedName, item.content, formatDate(item.copiedAt)]
            if item.isTemporary { parts.append(NSLocalizedString("임시 항목", comment: "VoiceOver: temporary item")) }
            return parts.joined(separator: ", ")
        }())
        .accessibilityHint(NSLocalizedString("탭하면 클립보드에 복사됩니다", comment: "Clipboard item copy hint"))
        .swipeActions(edge: .leading) {
            Button {
                onSave()
            } label: {
                Label(NSLocalizedString("저장", comment: "Save clipboard item as memo"), systemImage: "square.and.arrow.down")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing) {
            Menu {
                ForEach(ClipboardItemType.allCases, id: \.self) { type in
                    Button {
                        onTypeChange(type)
                    } label: {
                        Label(type.localizedName, systemImage: type.icon)
                    }
                }
            } label: {
                Label(NSLocalizedString("타입 변경", comment: "Change item type"), systemImage: "tag")
            }
            .tint(.blue)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

}

// MARK: - Save to Memo Sheet

struct SaveToMemoSheet: View {
    let item: SmartClipboardHistory
    let onComplete: (Bool) -> Void

    @Environment(\.appTheme) private var theme
    @State private var title: String
    @State private var category: String = "기본"
    @State private var isSecure: Bool = false

    init(item: SmartClipboardHistory, onComplete: @escaping (Bool) -> Void) {
        self.item = item
        self.onComplete = onComplete

        // 자동으로 제목 생성
        let suggestedTitle = String(item.content.prefix(30))
        _title = State(initialValue: suggestedTitle)

        // 민감한 정보는 자동으로 보안 모드
        let sensitiveTypes: [ClipboardItemType] = [.creditCard, .bankAccount, .passportNumber]
        _isSecure = State(initialValue: sensitiveTypes.contains(item.detectedType))

        // 타입에 따라 테마 자동 설정
        let suggestedCategory = Constants.categoryForClipboardType(item.detectedType)
        _category = State(initialValue: suggestedCategory)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(NSLocalizedString("메모 정보", comment: "Memo info section header")) {
                    TextField(NSLocalizedString("제목", comment: "Title field placeholder"), text: $title)

                    // 카테고리는 아래 "자동 분류 정보"의 감지 타입으로 자동 결정됨 (수동 선택 제거).

                    Toggle(NSLocalizedString("보안 메모", comment: "Secure memo toggle"), isOn: $isSecure)
                }

                Section(NSLocalizedString("내용", comment: "Content section header")) {
                    Text(item.content)
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }

                Section(NSLocalizedString("자동 분류 정보", comment: "Auto classification info section header")) {
                    HStack {
                        Image(systemName: item.detectedType.icon)
                        Text(item.detectedType.localizedName)
                        Spacer()
                        if item.confidence > 0.8 {
                            Text(String(format: NSLocalizedString("%d%% 확신", comment: "Confidence percentage"), Int(item.confidence * 100)))
                                .font(.body)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("메모로 저장", comment: "Save to memo sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("취소", comment: "Cancel button")) {
                        onComplete(false)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("저장", comment: "Save button")) {
                        saveToMemo()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func saveToMemo() {
        do {
            var memos = try MemoStore.shared.load(type: .memo)
            let newMemo = Memo(
                title: title,
                value: item.content,
                lastEdited: Date(),
                category: category,
                isSecure: isSecure,
                autoDetectedType: item.detectedType
            )
            memos.append(newMemo)
            try MemoStore.shared.save(memos: memos, type: .memo)
            onComplete(true)
        } catch {
            print("❌ [ClipboardList.saveAsMemo] \(error)")
            onComplete(false)
        }
    }
}

// MARK: - Create Combo Sheet

struct CreateComboSheet: View {
    let itemCount: Int
    let onCreate: (String, TimeInterval) -> Void
    let onCancel: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var title: String = ""
    @State private var interval: TimeInterval = 2.0

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("Combo 정보", comment: "Combo info section header")) {
                    TextField(NSLocalizedString("Combo 이름", comment: "Combo name field placeholder"), text: $title)

                    Picker(NSLocalizedString("자동 복사 간격", comment: "Auto copy interval picker label"), selection: $interval) {
                        Text(NSLocalizedString("1초", comment: "1 second")).tag(1.0)
                        Text(NSLocalizedString("2초", comment: "2 seconds")).tag(2.0)
                        Text(NSLocalizedString("3초", comment: "3 seconds")).tag(3.0)
                        Text(NSLocalizedString("5초", comment: "5 seconds")).tag(5.0)
                    }
                }

                Section {
                    Label(String(format: NSLocalizedString("%d개 항목이 순서대로 실행됩니다", comment: ""), itemCount), systemImage: "info.circle")
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
            }
            .navigationTitle(NSLocalizedString("Combo 생성", comment: "Create combo sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("취소", comment: "Cancel button")) {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("생성", comment: "Create button")) {
                        onCreate(title, interval)
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Paste Tip Banner

private struct PasteTipBanner: View {
    @Environment(\.appTheme) private var theme
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.body)
                    .foregroundColor(theme.accent)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("붙여넣기 팝업 없애는 방법", comment: "Paste tip banner title"))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.text)

                    Text(NSLocalizedString("설정 → 클립키보드 → 다른 앱에서 붙여넣기 → 허용으로 설정하면 팝업이 더 이상 뜨지 않습니다.", comment: "Paste tip banner body"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundColor(theme.textFaint)
                        .padding(6)
                        .background(theme.divider)
                        .clipShape(Circle())
                }
                .accessibilityLabel(NSLocalizedString("닫기", comment: "Close paste tip"))
            }

            Button(action: onDismiss) {
                Text(NSLocalizedString("더 이상 보지 않기", comment: "Don't show paste tip again"))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(theme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

struct ClipboardList_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ClipboardList()
        }
    }
}
