//
//  ComboList.swift
//  ClipKeyboard
//
//  Created by Claude Code on 2025-12-06.
//  Phase 2: Combo System
//

import SwiftUI

struct ComboList: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var combos: [Combo] = []
    @State private var showAddCombo = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var editingCombo: Combo? = nil
    @State private var showPaywall = false
    // 인지 장애 접근성: VoiceOver/스위치 컨트롤 삭제 액션 전 확인
    @State private var comboToDelete: Combo? = nil
    @State private var showDeleteAlert: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if combos.isEmpty {
                    EmptyComboView()
                } else {
                    List {
                        ForEach(combos) { combo in
                            ComboRowView(
                                combo: combo,
                                onExecute: { executeCombo(combo) },
                                onEdit: { editingCombo = combo },
                                onDelete: {
                                    comboToDelete = combo
                                    showDeleteAlert = true
                                },
                                onFavoriteToggle: { toggleFavorite(combo) }
                            )
                        }
                        .onDelete(perform: deleteCombo)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(theme.bg)
                }
            }
            .navigationTitle("Combo")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            addTestData()
                        } label: {
                            Label(NSLocalizedString("테스트 데이터 추가", comment: "Add test data"), systemImage: "wand.and.stars")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel(NSLocalizedString("더 보기", comment: "More options menu"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if ProFeatureManager.canAddCombo(currentCount: combos.count) {
                            showAddCombo = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel(NSLocalizedString("새 Combo 추가", comment: "Add new combo button"))
                    .accessibilityHint(NSLocalizedString("새로운 Combo를 만듭니다", comment: "Add combo button hint"))
                }
            }
            .sheet(isPresented: $showAddCombo) {
                ComboAddEditView(combo: nil) { newCombo in
                    do {
                        try MemoStore.shared.addCombo(newCombo)
                        loadCombos()
                        showToast(message: String(format: NSLocalizedString("Combo '%@' 생성됨", comment: ""), newCombo.title))
                    } catch {
                        showToast(message: String(format: NSLocalizedString("저장 실패: %@", comment: ""), error.localizedDescription))
                    }
                }
            }
            .sheet(item: $editingCombo) { combo in
                ComboAddEditView(combo: combo) { updatedCombo in
                    do {
                        try MemoStore.shared.updateCombo(updatedCombo)
                        loadCombos()
                        showToast(message: String(format: NSLocalizedString("Combo '%@' 수정됨", comment: ""), updatedCombo.title))
                    } catch {
                        showToast(message: String(format: NSLocalizedString("저장 실패: %@", comment: ""), error.localizedDescription))
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if showToast {
                    ToastView(message: toastMessage)
                        .padding(.bottom, 50)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .onChange(of: showToast) { _, visible in
                if visible {
                    UIAccessibility.post(notification: .announcement, argument: toastMessage)
                }
            }
            .onAppear {
                loadCombos()
            }
            .paywall(isPresented: $showPaywall, triggeredBy: .combo)
            .alert(NSLocalizedString("Combo 삭제", comment: "Delete combo confirm title"),
                   isPresented: $showDeleteAlert) {
                Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {
                    comboToDelete = nil
                }
                Button(NSLocalizedString("삭제", comment: "Delete"), role: .destructive) {
                    if let combo = comboToDelete,
                       let idx = combos.firstIndex(where: { $0.id == combo.id }) {
                        deleteCombo(at: IndexSet([idx]))
                    }
                    comboToDelete = nil
                }
            } message: {
                if let combo = comboToDelete {
                    Text(String(format: NSLocalizedString("'%@'을(를) 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.", comment: "Delete combo confirm message"), combo.title))
                }
            }
            .toolbarBackground(theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func loadCombos() {
        do {
            combos = try MemoStore.shared.loadCombos()
            // 즐겨찾기 > 최근 사용 순으로 정렬
            combos.sort { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite {
                    return lhs.isFavorite
                }
                if let lhsDate = lhs.lastUsed, let rhsDate = rhs.lastUsed {
                    return lhsDate > rhsDate
                }
                return (lhs.lastUsed != nil) && (rhs.lastUsed == nil)
            }
        } catch {
            print("❌ Combo 로드 실패: \(error)")
        }
    }

    private func deleteCombo(at offsets: IndexSet) {
        for index in offsets {
            let combo = combos[index]
            do {
                try MemoStore.shared.deleteCombo(id: combo.id)
                showToast(message: String(format: NSLocalizedString("Combo '%@' 삭제됨", comment: ""), combo.title))
            } catch {
                showToast(message: String(format: NSLocalizedString("삭제 실패: %@", comment: ""), error.localizedDescription))
            }
        }
        combos.remove(atOffsets: offsets)
    }

    private func toggleFavorite(_ combo: Combo) {
        var updated = combo
        updated.isFavorite.toggle()
        do {
            try MemoStore.shared.updateCombo(updated)
            loadCombos()
        } catch {
            print("❌ Combo 즐겨찾기 토글 실패: \(error)")
        }
    }

    private func executeCombo(_ combo: Combo) {
        ComboExecutionService.shared.startCombo(combo)
        showToast(message: String(format: NSLocalizedString("Combo '%@' 실행 중... (%d개 항목, %d초 간격)", comment: ""), combo.title, combo.items.count, Int(combo.interval)))
    }

    private func showToast(message: String) {
        toastMessage = message
        withAnimation(reduceMotion ? nil : .default) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(reduceMotion ? nil : .default) {
                showToast = false
            }
        }
    }

    private func addTestData() {
        do {
            try addTestCombo(title: "회원가입 정보", data: [
                "홍길동", "hong@example.com", "010-1234-5678", "06234", "서울특별시 강남구 테헤란로 123"
            ])
            try addTestCombo(title: "배송 정보", data: [
                "김철수", "010-9876-5432", "13579", "부산광역시 해운대구 해운대로 456", "문 앞에 놓아주세요"
            ])
            loadCombos()
            showToast(message: "✨ 테스트 데이터 추가 완료! (2개 Combo, 10개 항목)")
        } catch {
            showToast(message: "❌ 테스트 데이터 추가 실패: \(error.localizedDescription)")
        }
    }

    /// 데이터 배열로 클립보드 히스토리 항목을 생성하고 Combo로 묶어 저장
    private func addTestCombo(title: String, data: [String]) throws {
        var items: [ComboItem] = []
        for (order, text) in data.enumerated() {
            try MemoStore.shared.addToSmartClipboardHistory(content: text)
            let history = try MemoStore.shared.loadSmartClipboardHistory()
            if let item = history.first(where: { $0.content == text }) {
                items.append(ComboItem(
                    type: .clipboardHistory,
                    referenceId: item.id,
                    order: order,
                    displayTitle: String(text.prefix(20)),
                    displayValue: text
                ))
            }
        }
        try MemoStore.shared.addCombo(Combo(title: title, items: items, interval: 2.0))
    }
}

// MARK: - Empty View

struct EmptyComboView: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.2.circlepath.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
                .accessibilityHidden(true)

            Text(NSLocalizedString("Combo가 없습니다", comment: "Empty combo list title"))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.textMuted)

            Text(NSLocalizedString("여러 메모를 순서대로 자동 입력하는\nCombo를 만들어보세요", comment: "Empty combo list description"))
                .font(.body)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Combo Row

struct ComboRowView: View {
    let combo: Combo
    let onExecute: () -> Void
    let onEdit: () -> Void
    var onDelete: (() -> Void)? = nil
    var onFavoriteToggle: (() -> Void)? = nil
    @Environment(\.appTheme) private var theme

    private var rowAccessibilityLabel: String {
        var parts = [combo.title]
        if combo.isFavorite { parts.append(NSLocalizedString("즐겨찾기", comment: "Favorite")) }
        parts.append(String(format: NSLocalizedString("%d개 항목", comment: ""), combo.items.count))
        parts.append(String(format: NSLocalizedString("%d초 간격", comment: ""), Int(combo.interval)))
        if combo.useCount > 0 {
            parts.append(String(format: NSLocalizedString("%d회 사용", comment: ""), combo.useCount))
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(combo.title)
                        .font(.headline)

                    Spacer()

                    if combo.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.body)
                            .foregroundColor(.yellow)
                            .accessibilityHidden(true)
                    }

                    // 실행 버튼 — 중첩 버튼이므로 VoiceOver 커스텀 액션으로 노출
                    Button(action: onExecute) {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityHidden(true)
                }

                HStack(spacing: 12) {
                    Label(String(format: NSLocalizedString("%d개 항목", comment: ""), combo.items.count), systemImage: "list.bullet")
                        .font(.body)
                        .foregroundColor(theme.textMuted)

                    Label(String(format: NSLocalizedString("%d초 간격", comment: ""), Int(combo.interval)), systemImage: "timer")
                        .font(.body)
                        .foregroundColor(theme.textMuted)

                    if combo.useCount > 0 {
                        Label(String(format: NSLocalizedString("%d회 사용", comment: ""), combo.useCount), systemImage: "chart.bar.fill")
                            .font(.body)
                            .foregroundColor(theme.textMuted)
                    }
                }
                .accessibilityHidden(true)

                if !combo.items.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(combo.items.prefix(3)) { item in
                            ComboItemChip(item: item)
                        }

                        if combo.items.count > 3 {
                            Text("+\(combo.items.count - 3)")
                                .font(.caption2)
                                .foregroundColor(theme.textMuted)
                        }
                    }
                    .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityHint(NSLocalizedString("탭하면 편집 화면을 엽니다", comment: "Combo row edit hint"))
        .accessibilityAction(named: NSLocalizedString("실행", comment: "Execute combo action")) {
            onExecute()
        }
        // 스위치 컨트롤: 스와이프 불가 → 즐겨찾기/삭제를 커스텀 액션으로 제공
        .accessibilityAction(named: combo.isFavorite
            ? NSLocalizedString("즐겨찾기 해제", comment: "Remove favorite")
            : NSLocalizedString("즐겨찾기 추가", comment: "Add favorite")
        ) { onFavoriteToggle?() }
        .accessibilityAction(named: NSLocalizedString("삭제", comment: "Delete combo")) {
            onDelete?()
        }
    }
}

// MARK: - Combo Item Chip

struct ComboItemChip: View {
    let item: ComboItem
    @Environment(\.appTheme) private var theme

    var iconName: String {
        switch item.type {
        case .memo:
            return "doc.text"
        case .clipboardHistory:
            return "doc.on.clipboard"
        case .template:
            return "doc.text.fill"
        }
    }

    var colorName: Color {
        switch item.type {
        case .memo:
            return .blue
        case .clipboardHistory:
            return .green
        case .template:
            return .purple
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: iconName)
                .font(.caption2)
            Text(item.type.localizedName)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(colorName.opacity(0.2))
        .foregroundColor(colorName)
        .cornerRadius(theme.radiusXs)
    }
}

// MARK: - Toast View

struct ToastView: View {
    let message: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        Text(message)
            .font(.body)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.8))
            .cornerRadius(theme.radiusSm)
    }
}

// MARK: - Add/Edit View (Placeholder)

struct ComboAddEditView: View {
    let combo: Combo?
    let onSave: (Combo) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.appTheme) private var theme
    @State private var title: String = ""
    @State private var interval: TimeInterval = 2.0
    @State private var selectedItems: [ComboItem] = []
    @State private var isFavorite: Bool = false

    // 항목 추가/편집 관련 상태
    @State private var showItemPicker = false
    @State private var editingTemplateItem: ComboItem? = nil
    @State private var editingTemplateIndex: Int? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("기본 정보", comment: "Basic info section header")) {
                    TextField(NSLocalizedString("Combo 이름", comment: "Combo name placeholder"), text: $title)
                        .accessibilityLabel(NSLocalizedString("Combo 이름", comment: "Combo name field"))
                        .accessibilityHint(NSLocalizedString("Combo의 이름을 입력합니다", comment: "Combo name hint"))

                    HStack {
                        Text(NSLocalizedString("항목 간 간격", comment: "Interval label"))
                        Spacer()
                        Picker(NSLocalizedString("항목 간 간격", comment: "Interval picker label"), selection: $interval) {
                            Text(NSLocalizedString("1초", comment: "1 second")).tag(1.0)
                            Text(NSLocalizedString("2초", comment: "2 seconds")).tag(2.0)
                            Text(NSLocalizedString("3초", comment: "3 seconds")).tag(3.0)
                            Text(NSLocalizedString("5초", comment: "5 seconds")).tag(5.0)
                        }
                        .pickerStyle(.menu)
                        .accessibilityLabel(NSLocalizedString("항목 간 간격", comment: "Interval picker label"))
                        .accessibilityHint(NSLocalizedString("Combo 실행 시 각 항목이 입력되는 사이의 대기 시간", comment: "Interval picker hint"))
                    }

                    Toggle(NSLocalizedString("즐겨찾기", comment: "Favorite toggle"), isOn: $isFavorite)
                }

                Section {
                    if selectedItems.isEmpty {
                        Text(NSLocalizedString("항목을 추가해주세요", comment: "Add items prompt"))
                            .foregroundColor(theme.textMuted)
                    } else {
                        ForEach(selectedItems) { item in
                            HStack {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(theme.textFaint)
                                    .accessibilityHidden(true)
                                ComboItemChip(item: item)
                                Spacer()
                                if let title = item.displayTitle {
                                    Text(title)
                                        .font(.body)
                                        .foregroundColor(theme.textMuted)
                                        .lineLimit(2)
                                }

                                if item.type == .template {
                                    Button {
                                        editTemplateItem(item)
                                    } label: {
                                        Image(systemName: "pencil.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .accessibilityLabel(NSLocalizedString("플레이스홀더 편집", comment: "Edit template placeholders"))
                                }
                            }
                        }
                        .onMove(perform: moveItem)
                        .onDelete(perform: deleteItem)
                    }

                    Button(NSLocalizedString("항목 추가", comment: "Add item button")) {
                        showItemPicker = true
                    }
                    .accessibilityHint(NSLocalizedString("메모, 클립보드 항목, 템플릿을 Combo에 추가합니다", comment: "Add item hint"))
                } header: {
                    Text(String(format: NSLocalizedString("항목 (%d개)", comment: "Items count header"), selectedItems.count))
                } footer: {
                    if !selectedItems.isEmpty {
                        Text(NSLocalizedString("드래그하여 순서를 변경할 수 있습니다. Combo 실행 시 이 순서대로 각 항목이 입력됩니다.", comment: "Drag to reorder instruction with execution order explanation"))
                            .font(.body)
                    }
                }
            }
            .navigationTitle(combo == nil ? NSLocalizedString("Combo 추가", comment: "Add combo title") : NSLocalizedString("Combo 편집", comment: "Edit combo title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("취소", comment: "Cancel button")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("저장", comment: "Save button")) {
                        saveCombo()
                    }
                    .disabled(title.isEmpty || selectedItems.isEmpty)
                }
            }
            .sheet(isPresented: $showItemPicker) {
                ComboItemPickerSheet(selectedItems: $selectedItems)
            }
            .sheet(item: $editingTemplateItem) { item in
                if let index = editingTemplateIndex,
                   let memo = loadTemplateMemo(item.referenceId) {
                    ComboTemplateInputView(
                        template: memo,
                        comboItem: Binding(
                            get: { item },
                            set: { updated in
                                selectedItems[index] = updated
                                editingTemplateItem = nil
                                editingTemplateIndex = nil
                            }
                        )
                    )
                }
            }
            .onAppear {
                if let combo = combo {
                    title = combo.title
                    interval = combo.interval
                    selectedItems = combo.items
                    isFavorite = combo.isFavorite
                }
            }
        }
    }

    private func moveItem(from: IndexSet, to: Int) {
        selectedItems.move(fromOffsets: from, toOffset: to)
        // order 재정렬
        for (index, _) in selectedItems.enumerated() {
            selectedItems[index].order = index
        }
        print("📝 [ComboAddEditView] 항목 재정렬 완료")
    }

    private func deleteItem(at: IndexSet) {
        selectedItems.remove(atOffsets: at)
        // order 재정렬
        for (index, _) in selectedItems.enumerated() {
            selectedItems[index].order = index
        }
        print("🗑️ [ComboAddEditView] 항목 삭제 완료. 남은 항목: \(selectedItems.count)개")
    }

    private func editTemplateItem(_ item: ComboItem) {
        if let index = selectedItems.firstIndex(where: { $0.id == item.id }) {
            editingTemplateIndex = index
            editingTemplateItem = item
        }
    }

    private func loadTemplateMemo(_ templateId: UUID) -> Memo? {
        do {
            let memos = try MemoStore.shared.load(type: .memo)
            return memos.first(where: { $0.id == templateId && $0.isTemplate })
        } catch {
            print("❌ [ComboAddEditView] 템플릿 로드 실패: \(error)")
            return nil
        }
    }

    private func saveCombo() {
        let newCombo = Combo(
            id: combo?.id ?? UUID(),
            title: title,
            items: selectedItems,
            interval: interval,
            isFavorite: isFavorite
        )
        onSave(newCombo)
        dismiss()
    }
}

// MARK: - Combo Item Picker Sheet (템플릿 처리 포함)

struct ComboItemPickerSheet: View {
    @Binding var selectedItems: [ComboItem]
    @Environment(\.dismiss) var dismiss

    @State private var tempSelectedItems: [ComboItem] = []
    @State private var showTemplateInput = false
    @State private var pendingTemplateItem: (memo: Memo, comboItem: ComboItem)? = nil

    var body: some View {
        ComboItemPickerView(selectedItems: $tempSelectedItems)
            .onChange(of: tempSelectedItems) { _, newValue in
                // 새로 추가된 항목 확인
                let added = newValue.filter { newItem in
                    !selectedItems.contains(where: { $0.id == newItem.id })
                }

                for item in added {
                    if item.type == .template {
                        // 템플릿인 경우 플레이스홀더 입력 화면 표시
                        if let memo = loadTemplateMemo(item.referenceId) {
                            pendingTemplateItem = (memo, item)
                            showTemplateInput = true
                        }
                    } else {
                        // 메모/클립보드는 바로 추가
                        selectedItems.append(item)
                    }
                }
            }
            .sheet(isPresented: $showTemplateInput) {
                if let pending = pendingTemplateItem {
                    ComboTemplateInputView(
                        template: pending.memo,
                        comboItem: Binding(
                            get: { pending.comboItem },
                            set: { updated in
                                selectedItems.append(updated)
                                pendingTemplateItem = nil
                            }
                        )
                    )
                }
            }
            .onAppear {
                tempSelectedItems = selectedItems
            }
    }

    private func loadTemplateMemo(_ templateId: UUID) -> Memo? {
        do {
            let memos = try MemoStore.shared.load(type: .memo)
            return memos.first(where: { $0.id == templateId && $0.isTemplate })
        } catch {
            print("❌ [ComboItemPickerSheet] 템플릿 로드 실패: \(error)")
            return nil
        }
    }
}

#Preview {
    ComboList()
}
