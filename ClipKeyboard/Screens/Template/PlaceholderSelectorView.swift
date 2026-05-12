//
//  PlaceholderSelectorView.swift
//  ClipKeyboard
//
//  Created by Leeo on 12/11/25.
//

import SwiftUI

// 플레이스홀더 선택 뷰 (수정 가능)
struct PlaceholderSelectorView: View {
    let placeholder: String
    let sourceMemoId: UUID
    let sourceMemoTitle: String
    @Binding var selectedValue: String
    @Environment(\.appTheme) private var theme

    @State private var values: [PlaceholderValue] = []
    @State private var newValue: String = ""
    @State private var showDeleteConfirm: PlaceholderValue? = nil

    /// v4.0.8: 토큰명에 금액/amount/price 등이 있으면 numberPad
    private var isNumericToken: Bool {
        TemplateVariableProcessor.isNumericToken(placeholder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(placeholder.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textMuted)

                // 타입 뱃지
                HStack(spacing: 4) {
                    Image(systemName: isNumericToken ? "number" : "list.bullet")
                        .font(.system(size: 9, weight: .semibold))
                    Text(isNumericToken
                         ? NSLocalizedString("숫자 입력", comment: "Numeric placeholder badge")
                         : NSLocalizedString("선택지", comment: "Selection placeholder badge"))
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(isNumericToken ? .blue : .green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((isNumericToken ? Color.blue : Color.green).opacity(0.12))
                .cornerRadius(5)
            }

            // 값 목록
            if values.isEmpty {
                Text(NSLocalizedString("아래에서 값을 추가하세요", comment: "Add value hint"))
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(values) { placeholderValue in
                            HStack(spacing: 6) {
                                let isSelected = selectedValue == placeholderValue.value
                                Button {
                                    selectedValue = placeholderValue.value
                                } label: {
                                    Text(placeholderValue.value)
                                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? Color.blue : theme.surfaceAlt)
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .cornerRadius(16)
                                }
                                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                                .accessibilityHint(isSelected
                                    ? NSLocalizedString("현재 선택됨", comment: "Filter chip: currently selected")
                                    : NSLocalizedString("탭하면 이 값으로 설정됩니다", comment: "Placeholder value chip hint"))

                                Button {
                                    showDeleteConfirm = placeholderValue
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                }
                                .accessibilityLabel(String(format: NSLocalizedString("%@ 삭제", comment: "Delete value label"), placeholderValue.value))
                                .accessibilityHint(NSLocalizedString("이 저장된 값을 삭제합니다", comment: "Delete placeholder value hint"))
                            }
                        }
                    }
                }
            }

            // 값 추가 입력 (항상 표시)
            HStack(spacing: 8) {
                TextField(NSLocalizedString("새 값 입력", comment: "New value input placeholder"), text: $newValue)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    #if os(iOS)
                    .keyboardType(isNumericToken ? .numberPad : .default)
                    #endif

                Button {
                    if !newValue.isEmpty && !values.contains(where: { $0.value == newValue }) {
                        MemoStore.shared.addPlaceholderValue(
                            newValue,
                            for: placeholder,
                            sourceMemoId: sourceMemoId,
                            sourceMemoTitle: sourceMemoTitle
                        )
                        loadValues()
                        selectedValue = newValue
                        newValue = ""
                    }
                } label: {
                    Text(NSLocalizedString("추가", comment: "Add button"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(newValue.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(newValue.isEmpty)
                .accessibilityHint(NSLocalizedString("새 값을 목록에 추가합니다", comment: "Add value button hint"))
            }
        }
        .padding()
        .background(theme.surfaceAlt)
        .cornerRadius(10)
        .onAppear {
            print("🎬 [PlaceholderSelectorView] onAppear - 플레이스홀더: \(placeholder)")
            loadValues()
            print("✅ [PlaceholderSelectorView] onAppear 완료 - 로드된 값: \(values.count)개, 선택된 값: '\(selectedValue)'")
        }
        .alert(NSLocalizedString("삭제 확인", comment: "Delete confirmation title"), isPresented: .constant(showDeleteConfirm != nil)) {
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {
                showDeleteConfirm = nil
            }
            Button(NSLocalizedString("삭제", comment: "Delete"), role: .destructive) {
                if let valueToDelete = showDeleteConfirm {
                    MemoStore.shared.deletePlaceholderValue(valueId: valueToDelete.id, for: placeholder)
                    loadValues()
                    if selectedValue == valueToDelete.value {
                        selectedValue = ""
                    }
                }
                showDeleteConfirm = nil
            }
        } message: {
            if let value = showDeleteConfirm {
                Text(String(format: NSLocalizedString("'%@'을(를) 삭제하시겠습니까?", comment: "Delete confirmation message"), value.value))
            }
        }
    }

    private func loadValues() {
        print("   📥 [PlaceholderSelectorView.loadValues] 값 로드 중...")
        values = MemoStore.shared.loadPlaceholderValues(for: placeholder)
        print("   ✅ [PlaceholderSelectorView.loadValues] 완료 - \(values.count)개")
    }
}

// 플레이스홀더 관리 시트
struct PlaceholderManagementSheet: View {
    let allMemos: [Memo]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var templateMemos: [Memo] {
        allMemos.filter { $0.isTemplate }
    }

    var body: some View {
        NavigationStack {
            if templateMemos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(theme.textFaint)
                    Text(NSLocalizedString("템플릿이 없습니다", comment: "No templates"))
                        .font(.headline)
                        .foregroundColor(theme.textMuted)
                    Text(NSLocalizedString("템플릿 메모를 생성하고 {} 를 사용하면\n여기서 관리할 수 있습니다", comment: "No templates description"))
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(NSLocalizedString("플레이스홀더 관리", comment: "Placeholder management title"))
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(NSLocalizedString("완료", comment: "Done")) {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            } else {
                List {
                    ForEach(templateMemos) { template in
                        NavigationLink {
                            TemplateDetailPlaceholderView(template: template)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.title)
                                    .font(.headline)

                                Text(extractPlaceholderPreview(from: template.value))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .navigationTitle(NSLocalizedString("플레이스홀더 관리", comment: "Placeholder management title"))
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(NSLocalizedString("완료", comment: "Done")) {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func extractPlaceholderPreview(from text: String) -> String {
        let emptyLabel = NSLocalizedString("No placeholders", comment: "Fallback when template has no placeholders")
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return emptyLabel }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var placeholders: [String] = []

        for match in matches {
            if let range = Range(match.range, in: text) {
                let placeholder = String(text[range])
                if !TemplateVariableProcessor.autoVariableTokens.contains(placeholder) && !placeholders.contains(placeholder) {
                    placeholders.append(placeholder)
                }
            }
        }

        if placeholders.isEmpty {
            return emptyLabel
        }

        return placeholders.map { $0.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "") }.joined(separator: ", ")
    }
}
