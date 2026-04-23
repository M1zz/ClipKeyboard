//
//  TemplateEditSheet.swift
//  Token memo
//
//  Created by Leeo on 12/11/25.
//

import SwiftUI

// MARK: - Template Edit Sheet

struct TemplateEditSheet: View {
    let memo: Memo
    let onCopy: (String) -> Void
    let onCancel: () -> Void

    @Environment(\.appTheme) private var theme

    @State private var customPlaceholders: [String] = []
    @State private var placeholderInputs: [String: String] = [:]
    @State private var editedText: String = ""
    @State private var isEditingText: Bool = false

    var previewText: String {
        var result = isEditingText ? editedText : memo.value
        for (placeholder, value) in placeholderInputs where !value.isEmpty {
            result = result.replacingOccurrences(of: placeholder, with: value)
        }
        return TemplateVariableProcessor.process(result)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    templateOriginalSection
                    placeholderSection
                    previewSection
                }
                .padding()
            }
            .navigationTitle(memo.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("취소", comment: "Cancel")) { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("복사", comment: "Copy")) {
                        savePlaceholderInputsToMemo()
                        onCopy(previewText)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            customPlaceholders = memo.value.extractTemplatePlaceholders()
            loadPlaceholderDefaults()
        }
    }

    // MARK: - Subviews

    private var templateOriginalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("템플릿", comment: "Template label"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textMuted)
                Spacer()
                Button {
                    isEditingText.toggle()
                    if isEditingText { editedText = memo.value }
                } label: {
                    Text(isEditingText ? NSLocalizedString("완료", comment: "Done") : NSLocalizedString("수정", comment: "Edit"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }

            if isEditingText {
                TextEditor(text: $editedText)
                    .font(.body)
                    .frame(minHeight: 100)
                    .padding(12)
                    .background(theme.surfaceAlt)
                    .cornerRadius(12)
            } else {
                Text(memo.value)
                    .font(.body)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surfaceAlt)
                    .cornerRadius(12)
            }
        }
    }

    @ViewBuilder
    private var placeholderSection: some View {
        if customPlaceholders.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.green)
                Text(NSLocalizedString("설정할 값이 없습니다", comment: "No values to set"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(NSLocalizedString("이 템플릿은 바로 사용 가능합니다", comment: "Template ready to use"))
                    .font(.caption)
                    .foregroundColor(theme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(NSLocalizedString("값 선택", comment: "Select value"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textMuted)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(NSLocalizedString("값을 선택하세요", comment: "Select a value hint"))
                            .font(.caption)
                            .foregroundColor(theme.textMuted)
                    }
                }

                ForEach(customPlaceholders, id: \.self) { placeholder in
                    PlaceholderSelectorView(
                        placeholder: placeholder,
                        sourceMemoId: memo.id,
                        sourceMemoTitle: memo.title,
                        selectedValue: Binding(
                            get: { placeholderInputs[placeholder] ?? "" },
                            set: { placeholderInputs[placeholder] = $0 }
                        )
                    )
                }
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("미리보기", comment: "Preview"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(theme.textMuted)
            Text(previewText)
                .font(.body)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
        }
    }

    // MARK: - Logic

    private func loadPlaceholderDefaults() {
        for placeholder in customPlaceholders {
            if let savedValues = memo.placeholderValues[placeholder], let first = savedValues.first {
                placeholderInputs[placeholder] = first
            } else if let first = MemoStore.shared.loadPlaceholderValues(for: placeholder).first {
                placeholderInputs[placeholder] = first.value
            } else {
                placeholderInputs[placeholder] = ""
            }
        }
    }

    private func savePlaceholderInputsToMemo() {
        do {
            var memos = try MemoStore.shared.load(type: .tokenMemo)
            guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }
            memos[index].placeholderValues = placeholderInputs
                .filter { !$0.value.isEmpty }
                .mapValues { [$0] }
            try MemoStore.shared.save(memos: memos, type: .tokenMemo)
        } catch {
            // 저장 실패는 조용히 무시 — 복사 기능 자체는 계속 동작
        }
    }
}

// MARK: - Template Input Sheet

struct TemplateInputSheet: View {
    let placeholders: [String]
    @Binding var inputs: [String: String]
    let onComplete: () -> Void
    let onCancel: () -> Void

    @Environment(\.appTheme) private var theme
    @FocusState private var focusedField: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(NSLocalizedString("템플릿을 완성하세요", comment: "Complete the template"))
                        .font(.headline)
                        .foregroundColor(theme.textMuted)
                } header: { EmptyView() }

                Section {
                    ForEach(placeholders, id: \.self) { placeholder in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(placeholder.strippingTemplateBraces)
                                .font(.caption)
                                .foregroundColor(theme.textMuted)

                            TextField(NSLocalizedString("입력하세요", comment: "Input placeholder"), text: Binding(
                                get: { inputs[placeholder] ?? "" },
                                set: { inputs[placeholder] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: placeholder)
                            .submitLabel(.next)
                            .onSubmit {
                                if let i = placeholders.firstIndex(of: placeholder), i < placeholders.count - 1 {
                                    focusedField = placeholders[i + 1]
                                } else {
                                    focusedField = nil
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("템플릿 입력", comment: "Template input title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("취소", comment: "Cancel")) { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("복사", comment: "Copy")) { onComplete() }
                        .disabled(inputs.values.contains(where: { $0.isEmpty }))
                }
            }
            .onAppear {
                focusedField = placeholders.first
            }
        }
    }
}

// MARK: - Template Detail Placeholder View

struct TemplateDetailPlaceholderView: View {
    let template: Memo
    @Environment(\.appTheme) private var theme
    @State private var placeholders: [String] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("템플릿 내용", comment: "Template content"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textMuted)

                    Text(template.value)
                        .font(.body)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.surfaceAlt)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top)

                if placeholders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        Text(NSLocalizedString("이 템플릿에는 플레이스홀더가 없습니다", comment: "No placeholders in template"))
                            .font(.subheadline)
                            .foregroundColor(theme.textMuted)
                    }
                    .padding(.top, 50)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(format: NSLocalizedString("플레이스홀더 (%d개)", comment: "Placeholder count"), placeholders.count))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textMuted)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            ForEach(placeholders, id: \.self) { placeholder in
                                TemplatePlaceholderRow(
                                    placeholder: placeholder,
                                    templateId: template.id,
                                    templateTitle: template.title
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle(template.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            placeholders = template.value.extractTemplatePlaceholders()
        }
    }
}

// MARK: - Template Placeholder Row

struct TemplatePlaceholderRow: View {
    let placeholder: String
    let templateId: UUID
    let templateTitle: String

    @Environment(\.appTheme) private var theme
    @State private var values: [PlaceholderValue] = []
    @State private var showDeleteConfirm: PlaceholderValue? = nil
    @State private var editingValue: PlaceholderValue? = nil
    @State private var editText: String = ""
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            if isExpanded {
                Divider().padding(.horizontal, 16)
                valueList.padding(.horizontal, 16).padding(.bottom, 12)
            }
        }
        .background(theme.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.divider, lineWidth: 1))
        .onAppear { loadValues() }
        .alert(NSLocalizedString("삭제 확인", comment: "Delete confirmation"),
               isPresented: .constant(showDeleteConfirm != nil)) {
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { showDeleteConfirm = nil }
            Button(NSLocalizedString("삭제", comment: "Delete"), role: .destructive) {
                if let v = showDeleteConfirm {
                    MemoStore.shared.deletePlaceholderValue(valueId: v.id, for: placeholder)
                    loadValues()
                }
                showDeleteConfirm = nil
            }
        } message: {
            if let v = showDeleteConfirm {
                Text(String(format: NSLocalizedString("'%@'을(를) 삭제하시겠습니까?", comment: "Delete value confirmation"), v.value))
            }
        }
        .alert(NSLocalizedString("값 수정", comment: "Edit value"),
               isPresented: .constant(editingValue != nil)) {
            TextField(NSLocalizedString("값", comment: "Value"), text: $editText)
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { editingValue = nil }
            Button(NSLocalizedString("저장", comment: "Save")) {
                if let old = editingValue, !editText.isEmpty {
                    MemoStore.shared.deletePlaceholderValue(valueId: old.id, for: placeholder)
                    MemoStore.shared.addPlaceholderValue(editText, for: placeholder, sourceMemoId: templateId, sourceMemoTitle: templateTitle)
                    loadValues()
                }
                editingValue = nil
            }
        } message: {
            if let v = editingValue {
                Text(String(format: NSLocalizedString("'%@' 값을 수정하세요.", comment: "Edit value prompt"), v.value))
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(placeholder.strippingTemplateBraces)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(String(format: NSLocalizedString("값 %d개", comment: "Value count"), values.count))
                    .font(.subheadline)
                    .foregroundColor(theme.textMuted)
            }
            Spacer(minLength: 20)
            Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 24))
        }
        .padding(16)
        .background(theme.surface)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
        }
    }

    @ViewBuilder
    private var valueList: some View {
        if values.isEmpty {
            Text(NSLocalizedString("값이 없습니다.\n템플릿 사용 시 값을 추가하세요.", comment: "No values hint"))
                .font(.callout)
                .foregroundColor(.orange)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .multilineTextAlignment(.center)
        } else {
            VStack(spacing: 10) {
                ForEach(values) { value in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(value.value)
                                .font(.body)
                                .fontWeight(.semibold)
                            Text(value.addedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        HStack(spacing: 16) {
                            Button {
                                editingValue = value
                                editText = value.value
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.blue)
                            }
                            Button {
                                showDeleteConfirm = value
                            } label: {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(theme.surfaceAlt)
                    .cornerRadius(10)
                }
            }
        }
    }

    private func loadValues() {
        values = MemoStore.shared.loadPlaceholderValues(for: placeholder)
    }
}

// MARK: - Template Sheet Resolver

struct TemplateSheetResolver: View {
    let templateId: UUID
    let allMemos: [Memo]
    let onCopy: (Memo, String) -> Void
    let onCancel: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var loadedMemo: Memo? = nil
    @State private var isLoading: Bool = false

    var body: some View {
        Group {
            if let memo = loadedMemo {
                TemplateEditSheet(
                    memo: memo,
                    onCopy: { processedValue in onCopy(memo, processedValue) },
                    onCancel: onCancel
                )
            } else {
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.5)
                    Text(NSLocalizedString("템플릿 불러오는 중...", comment: "Loading template"))
                        .font(.callout)
                        .foregroundColor(theme.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.surface)
            }
        }
        .onAppear { loadMemo() }
    }

    private func loadMemo() {
        guard !isLoading else { return }
        isLoading = true

        if let memo = allMemos.first(where: { $0.id == templateId }) {
            loadedMemo = memo
            isLoading = false
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let memo = (try? MemoStore.shared.load(type: .tokenMemo))?.first(where: { $0.id == templateId })
            DispatchQueue.main.async {
                loadedMemo = memo
                isLoading = false
            }
        }
    }
}

// MARK: - String Helper

private extension String {
    var strippingTemplateBraces: String {
        replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
    }

    func extractTemplatePlaceholders() -> [String] {
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: self, range: NSRange(startIndex..., in: self))
        var result: [String] = []
        for match in matches {
            if let range = Range(match.range, in: self) {
                let token = String(self[range])
                if !TemplateVariableProcessor.autoVariableTokens.contains(token), !result.contains(token) {
                    result.append(token)
                }
            }
        }
        return result
    }
}
