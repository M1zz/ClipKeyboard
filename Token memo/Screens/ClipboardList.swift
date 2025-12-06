//
//  ClipboardList.swift
//  Token memo
//
//  Created by hyunho lee on 2023/06/03.
//  Enhanced with Smart Classification by Claude Code
//

import SwiftUI

struct ClipboardList: View {

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
                                        Image(systemName: selectedForCombo.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedForCombo.contains(item.id) ? .blue : .gray)
                                            .font(.title3)
                                            .onTapGesture {
                                                toggleSelection(item.id)
                                            }
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
                            }
                            .onDelete(perform: isSelectingForCombo ? nil : deleteItems)
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: recentlyAddedId) { newId in
                        if let id = newId {
                            // 부드럽게 스크롤
                            withAnimation(.easeInOut(duration: 0.5)) {
                                proxy.scrollTo(id, anchor: .top)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isSelectingForCombo ? "Combo 생성" : "클립보드 히스토리")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectingForCombo {
                        Button("취소") {
                            isSelectingForCombo = false
                            selectedForCombo.removeAll()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelectingForCombo {
                        Button("생성 (\(selectedForCombo.count))") {
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
                                Label("Combo 생성", systemImage: "arrow.triangle.2.circlepath.circle")
                            }

                            Divider()

                            Button(role: .destructive) {
                                clearAll()
                            } label: {
                                Label("전체 삭제", systemImage: "trash")
                            }

                            Button {
                                selectedFilter = nil
                            } label: {
                                Label("필터 초기화", systemImage: "line.3.horizontal.decrease.circle")
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
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)

                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                showToast = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption)
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
                        showToast(message: "메모로 저장되었습니다")
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
    }

    /// Empty list view
    private var EmptyListView: some View {
        VStack(spacing: 5) {
            Image(systemName: selectedFilter == nil ? "eyes" : "magnifyingglass")
                .font(.system(size: 45))
                .padding(10)

            if selectedFilter == nil {
                Text("클립보드 히스토리 없음")
                    .font(.system(size: 22)).bold()
                Text("복사한 내용이 자동으로 여기에 저장됩니다\n(최대 100개, 7일간 유지)")
                    .opacity(0.7)
            } else {
                Text("\(selectedFilter!.rawValue) 타입 없음")
                    .font(.system(size: 22)).bold()
                Text("이 타입으로 분류된 항목이 없습니다")
                    .opacity(0.7)
            }
        }
        .multilineTextAlignment(.center)
        .padding(30)
    }

    // MARK: - Actions

    private func checkAndAddCurrentClipboard() {
        // 중복 체크 방지
        guard !isCheckingClipboard else { return }
        isCheckingClipboard = true

        // 현재 클립보드 내용 가져오기
        guard let currentClipboard = UIPasteboard.general.string,
              !currentClipboard.isEmpty else {
            isCheckingClipboard = false
            return
        }

        // 이미 히스토리에 있는지 확인
        do {
            let history = try MemoStore.shared.loadSmartClipboardHistory()

            // 가장 최근 항목과 같으면 무시 (중복 방지)
            if let latestItem = history.first,
               latestItem.content == currentClipboard {
                print("ℹ️ [ClipboardList] 이미 최근 항목에 존재: \(currentClipboard.prefix(30))...")
                isCheckingClipboard = false
                return
            }

            // 히스토리에 없으면 자동으로 추가 (자동 분류 포함!)
            try MemoStore.shared.addToSmartClipboardHistory(content: currentClipboard)
            print("✅ [ClipboardList] 클립보드 자동 추가: \(currentClipboard.prefix(30))...")

            // 즉시 UI에 반영
            loadHistory()

            // 방금 추가된 항목 찾기
            let updatedHistory = try MemoStore.shared.loadSmartClipboardHistory()
            if let newItem = updatedHistory.first {
                recentlyAddedId = newItem.id

                // 피드백 표시
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showToast(message: "📋 새로운 \(newItem.detectedType.rawValue) 항목이 추가되었습니다")
                }

                // 3초 후 하이라이트 해제
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        recentlyAddedId = nil
                    }
                }
            }
        } catch {
            print("❌ [ClipboardList] 클립보드 체크 실패: \(error)")
        }

        isCheckingClipboard = false
    }

    private func copyToPasteboard(_ item: SmartClipboardHistory) {
        UIPasteboard.general.string = item.content
        showToast(message: "[\(item.content.prefix(30))] 복사됨")
    }

    private func prepareToSave(_ item: SmartClipboardHistory) {
        itemToSave = item
        showSaveDialog = true
    }

    private func updateItemType(item: SmartClipboardHistory, newType: ClipboardItemType) {
        do {
            try MemoStore.shared.updateClipboardItemType(id: item.id, correctedType: newType)
            loadHistory()
            showToast(message: "타입이 \(newType.rawValue)로 변경되었습니다")
        } catch {
            print("Error updating type: \(error)")
        }
    }

    private func showToast(message: String) {
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }

    private func loadHistory() {
        do {
            clipboardHistory = try MemoStore.shared.loadSmartClipboardHistory()
        } catch {
            print("Error loading clipboard history: \(error)")
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let filtered = filteredHistory
        let idsToDelete = offsets.map { filtered[$0].id }

        clipboardHistory.removeAll { item in idsToDelete.contains(item.id) }

        do {
            try MemoStore.shared.saveSmartClipboardHistory(history: clipboardHistory)
        } catch {
            print("Error deleting clipboard history: \(error)")
        }
    }

    private func clearAll() {
        clipboardHistory.removeAll()
        do {
            try MemoStore.shared.saveSmartClipboardHistory(history: [])
        } catch {
            print("Error clearing clipboard history: \(error)")
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
            showToast(message: "Combo '\(title)' 생성됨")

            // 선택 모드 종료
            isSelectingForCombo = false
            selectedForCombo.removeAll()
        } catch {
            showToast(message: "Combo 생성 실패: \(error.localizedDescription)")
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

    var typeCounts: [ClipboardItemType: Int] {
        Dictionary(grouping: history, by: { $0.detectedType })
            .mapValues { $0.count }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 전체 버튼
                FilterChip(
                    title: "전체",
                    icon: "list.bullet",
                    count: history.count,
                    isSelected: selectedFilter == nil
                ) {
                    selectedFilter = nil
                }

                // 타입별 필터 (개수가 있는 것만)
                ForEach(ClipboardItemType.allCases.filter { typeCounts[$0, default: 0] > 0 }, id: \.self) { type in
                    FilterChip(
                        title: type.rawValue,
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
        .background(Color(.systemGray6))
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let count: Int
    var color: String = "blue"
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .regular)
                Text("\(count)")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? colorFor(color) : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }

    private func colorFor(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "indigo": return .indigo
        case "brown": return .brown
        case "cyan": return .cyan
        case "teal": return .teal
        case "pink": return .pink
        case "mint": return .mint
        default: return .gray
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

    var displayType: ClipboardItemType {
        item.userCorrectedType ?? item.detectedType
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    // 타입 아이콘
                    Image(systemName: displayType.icon)
                        .font(.title3)
                        .foregroundColor(colorFor(displayType.color))
                        .frame(width: 24)
                        // 하이라이트 시 스케일 애니메이션
                        .scaleEffect(isHighlighted ? 1.2 : 1.0)

                    VStack(alignment: .leading, spacing: 4) {
                        // 내용
                        Text(item.content)
                            .font(.system(size: 14))
                            .lineLimit(2)
                            .foregroundColor(.primary)

                        // 메타 정보
                        HStack(spacing: 8) {
                            // 타입 태그
                            HStack(spacing: 4) {
                                Text(displayType.rawValue)
                                    .font(.caption2)

                                if item.userCorrectedType != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                } else if item.confidence > 0.8 {
                                    Image(systemName: "sparkles")
                                        .font(.caption2)
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(colorFor(displayType.color).opacity(0.2))
                            .cornerRadius(4)

                            // 시간
                            Text(formatDate(item.copiedAt))
                                .font(.caption)
                                .foregroundColor(.gray)

                            Spacer()

                            // 임시 태그
                            if item.isTemporary {
                                Text("임시")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHighlighted ? colorFor(displayType.color).opacity(0.15) : Color.clear)
                .animation(.easeInOut(duration: 0.3), value: isHighlighted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHighlighted ? colorFor(displayType.color).opacity(0.5) : Color.clear, lineWidth: 2)
                .animation(.easeInOut(duration: 0.3), value: isHighlighted)
        )
        .swipeActions(edge: .leading) {
            Button {
                onSave()
            } label: {
                Label("저장", systemImage: "square.and.arrow.down")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing) {
            Menu {
                ForEach(ClipboardItemType.allCases, id: \.self) { type in
                    Button {
                        onTypeChange(type)
                    } label: {
                        Label(type.rawValue, systemImage: type.icon)
                    }
                }
            } label: {
                Label("타입 변경", systemImage: "tag")
            }
            .tint(.blue)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func colorFor(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "indigo": return .indigo
        case "brown": return .brown
        case "cyan": return .cyan
        case "teal": return .teal
        case "pink": return .pink
        case "mint": return .mint
        default: return .gray
        }
    }
}

// MARK: - Save to Memo Sheet

struct SaveToMemoSheet: View {
    let item: SmartClipboardHistory
    let onComplete: (Bool) -> Void

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
                Section("메모 정보") {
                    TextField("제목", text: $title)

                    Picker("테마", selection: $category) {
                        ForEach(Constants.categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }

                    Toggle("보안 메모", isOn: $isSecure)
                }

                Section("내용") {
                    Text(item.content)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Section("자동 분류 정보") {
                    HStack {
                        Image(systemName: item.detectedType.icon)
                        Text(item.detectedType.rawValue)
                        Spacer()
                        if item.confidence > 0.8 {
                            Text("\(Int(item.confidence * 100))% 확신")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("메모로 저장")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        onComplete(false)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveToMemo()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func saveToMemo() {
        do {
            var memos = try MemoStore.shared.load(type: .tokenMemo)
            let newMemo = Memo(
                title: title,
                value: item.content,
                lastEdited: Date(),
                category: category,
                isSecure: isSecure,
                autoDetectedType: item.detectedType
            )
            memos.append(newMemo)
            try MemoStore.shared.save(memos: memos, type: .tokenMemo)
            onComplete(true)
        } catch {
            print("Error saving to memo: \(error)")
            onComplete(false)
        }
    }
}

// MARK: - Create Combo Sheet

struct CreateComboSheet: View {
    let itemCount: Int
    let onCreate: (String, TimeInterval) -> Void
    let onCancel: () -> Void

    @State private var title: String = ""
    @State private var interval: TimeInterval = 2.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Combo 정보") {
                    TextField("Combo 이름", text: $title)

                    Picker("자동 복사 간격", selection: $interval) {
                        Text("1초").tag(1.0)
                        Text("2초").tag(2.0)
                        Text("3초").tag(3.0)
                        Text("5초").tag(5.0)
                    }
                }

                Section {
                    Label("\(itemCount)개 항목이 순서대로 실행됩니다", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Combo 생성")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("생성") {
                        onCreate(title, interval)
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

struct ClipboardList_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ClipboardList()
        }
    }
}
