//
//  ComboItemPickerView.swift
//  Token memo
//
//  Created by Claude on 2026/01/16.
//

import SwiftUI

struct ComboItemPickerView: View {
    @Binding var selectedItems: [ComboItem]
    @Environment(\.dismiss) var dismiss

    @State private var selectedTab: ComboItemType = .memo
    @State private var memos: [Memo] = []
    @State private var clipboardHistory: [SmartClipboardHistory] = []
    @State private var templates: [Memo] = []
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 탭 선택 (메모/클립보드/템플릿)
                Picker("Type", selection: $selectedTab) {
                    Text(NSLocalizedString("메모", comment: "Memo")).tag(ComboItemType.memo)
                    Text(NSLocalizedString("클립보드", comment: "Clipboard")).tag(ComboItemType.clipboardHistory)
                    Text(NSLocalizedString("템플릿", comment: "Template")).tag(ComboItemType.template)
                }
                .pickerStyle(.segmented)
                .padding()

                // 검색 바
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField(NSLocalizedString("검색", comment: "Search"), text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 8)

                Divider()

                // 항목 리스트
                List {
                    switch selectedTab {
                    case .memo:
                        if filteredMemos.isEmpty {
                            Text(NSLocalizedString("메모가 없습니다", comment: "No memos"))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(filteredMemos) { memo in
                                MemoPickerRow(memo: memo) {
                                    addItem(memo)
                                }
                            }
                        }
                    case .clipboardHistory:
                        if filteredClipboard.isEmpty {
                            Text(NSLocalizedString("클립보드 히스토리가 없습니다", comment: "No clipboard history"))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(filteredClipboard) { item in
                                ClipboardPickerRow(item: item) {
                                    addItem(item)
                                }
                            }
                        }
                    case .template:
                        if filteredTemplates.isEmpty {
                            Text(NSLocalizedString("템플릿이 없습니다", comment: "No templates"))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(filteredTemplates) { template in
                                TemplatePickerRow(template: template) {
                                    addItem(template)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle(NSLocalizedString("항목 추가", comment: "Add Item"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("취소", comment: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("완료", comment: "Done")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadData()
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredMemos: [Memo] {
        if searchText.isEmpty {
            return memos
        }
        return memos.filter { memo in
            memo.title.localizedStandardContains(searchText) ||
            memo.value.localizedStandardContains(searchText)
        }
    }

    private var filteredClipboard: [SmartClipboardHistory] {
        if searchText.isEmpty {
            return clipboardHistory
        }
        return clipboardHistory.filter { item in
            item.content.localizedStandardContains(searchText)
        }
    }

    private var filteredTemplates: [Memo] {
        if searchText.isEmpty {
            return templates
        }
        return templates.filter { template in
            template.title.localizedStandardContains(searchText) ||
            template.value.localizedStandardContains(searchText)
        }
    }

    // MARK: - Methods

    private func loadData() {
        print("📥 [ComboItemPickerView] 데이터 로드 시작")

        do {
            let allMemos = try MemoStore.shared.load(type: .tokenMemo)

            // 템플릿과 일반 메모 분리
            templates = allMemos.filter { $0.isTemplate }
            memos = allMemos.filter { !$0.isTemplate }

            print("✅ [ComboItemPickerView] 메모 \(memos.count)개, 템플릿 \(templates.count)개 로드")

            // 클립보드 히스토리 로드
            clipboardHistory = try MemoStore.shared.loadSmartClipboardHistory()
            print("✅ [ComboItemPickerView] 클립보드 히스토리 \(clipboardHistory.count)개 로드")
        } catch {
            print("❌ [ComboItemPickerView] 데이터 로드 실패: \(error)")
        }
    }

    private func addItem(_ source: Any) {
        var newItem: ComboItem?

        if let memo = source as? Memo {
            print("📝 [ComboItemPickerView] 메모 추가: \(memo.title)")
            newItem = ComboItem(
                type: .memo,
                referenceId: memo.id,
                order: selectedItems.count,
                displayTitle: memo.title,
                displayValue: memo.value
            )
        } else if let clipboardItem = source as? SmartClipboardHistory {
            print("📋 [ComboItemPickerView] 클립보드 추가: \(clipboardItem.content.prefix(30))...")
            newItem = ComboItem(
                type: .clipboardHistory,
                referenceId: clipboardItem.id,
                order: selectedItems.count,
                displayTitle: String(clipboardItem.content.prefix(30)),
                displayValue: clipboardItem.content
            )
        }

        if let newItem = newItem {
            selectedItems.append(newItem)
            print("✅ [ComboItemPickerView] 항목 추가됨. 총 \(selectedItems.count)개")
        }
    }
}

// MARK: - Picker Rows

struct MemoPickerRow: View {
    let memo: Memo
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(memo.title)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(memo.value)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 8) {
                    if memo.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                    if memo.isSecure {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }

                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct ClipboardPickerRow: View {
    let item: SmartClipboardHistory
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: item.detectedType.icon)
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(item.detectedType.localizedName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(item.content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(item.copiedAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
            }
        }
    }
}

struct TemplatePickerRow: View {
    let template: Memo
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.purple)
                            .font(.caption)
                        Text(template.title)
                            .font(.body)
                            .foregroundColor(.primary)
                    }

                    Text(template.value)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    // 플레이스홀더 개수 표시
                    if !template.templateVariables.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "curlybraces")
                                .font(.caption2)
                            Text("\(template.templateVariables.count)개 변수")
                                .font(.caption2)
                        }
                        .foregroundColor(.orange)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if template.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }

                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedItems: [ComboItem] = []

        var body: some View {
            ComboItemPickerView(selectedItems: $selectedItems)
        }
    }

    return PreviewWrapper()
}
