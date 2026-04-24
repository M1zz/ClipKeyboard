//
//  ComboTemplateInputView.swift
//  Token memo
//
//  Created by Claude on 2026/01/16.
//

import SwiftUI

struct ComboTemplateInputView: View {
    let template: Memo
    @Binding var comboItem: ComboItem
    @Environment(\.dismiss) var dismiss

    @State private var placeholders: [String] = []
    @State private var inputs: [String: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("템플릿 미리보기", comment: "Template Preview"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        Text(template.value)
                            .font(.body)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }

                if placeholders.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)

                            Text(NSLocalizedString("이 템플릿에는 플레이스홀더가 없습니다", comment: "No placeholders"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                } else {
                    Section(header: Text(NSLocalizedString("플레이스홀더 값 설정", comment: "Set Placeholder Values"))) {
                        ForEach(placeholders, id: \.self) { placeholder in
                            PlaceholderSelectorView(
                                placeholder: placeholder,
                                sourceMemoId: template.id,
                                sourceMemoTitle: template.title,
                                selectedValue: Binding(
                                    get: { inputs[placeholder] ?? "" },
                                    set: { inputs[placeholder] = $0 }
                                )
                            )
                            .padding(.vertical, 8)
                        }
                    }

                    Section(header: Text(NSLocalizedString("결과 미리보기", comment: "Preview Result"))) {
                        if allPlaceholdersFilled {
                            Text(previewText)
                                .font(.body)
                                .foregroundColor(.blue)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        } else {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(NSLocalizedString("모든 플레이스홀더 값을 입력해주세요", comment: "Fill all placeholders"))
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("템플릿 값 설정", comment: "Set Template Values"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("취소", comment: "Cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("추가", comment: "Add")) {
                        saveAndDismiss()
                    }
                    .disabled(!allPlaceholdersFilled)
                }
            }
            .onAppear {
                extractPlaceholders()
            }
        }
    }

    // MARK: - Computed Properties

    private var allPlaceholdersFilled: Bool {
        if placeholders.isEmpty {
            return true
        }
        return placeholders.allSatisfy { placeholder in
            let value = inputs[placeholder] ?? ""
            return !value.isEmpty
        }
    }

    private var previewText: String {
        var result = template.value

        // 커스텀 플레이스홀더 치환
        for (placeholder, value) in inputs {
            result = result.replacingOccurrences(of: placeholder, with: value)
        }

        // 자동 변수 치환
        result = processTemplateVariables(in: result)

        return result
    }

    // MARK: - Methods

    private func extractPlaceholders() {
        print("🔍 [ComboTemplateInputView] 플레이스홀더 추출 시작")

        let autoVariables = ["{날짜}", "{시간}", "{연도}", "{월}", "{일}"]
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            print("❌ [ComboTemplateInputView] 정규식 생성 실패")
            return
        }

        let matches = regex.matches(in: template.value, range: NSRange(template.value.startIndex..., in: template.value))
        var extractedPlaceholders: [String] = []

        for match in matches {
            if let range = Range(match.range, in: template.value) {
                let placeholder = String(template.value[range])
                if !autoVariables.contains(placeholder) && !extractedPlaceholders.contains(placeholder) {
                    extractedPlaceholders.append(placeholder)
                }
            }
        }

        placeholders = extractedPlaceholders
        print("✅ [ComboTemplateInputView] \(placeholders.count)개 플레이스홀더 추출: \(placeholders)")

        // 기존 값이 있으면 로드
        if comboItem.displayValue != nil {
            print("📝 [ComboTemplateInputView] 기존 값 존재")
        }
    }

    private func processTemplateVariables(in text: String) -> String {
        TemplateVariableProcessor.process(text)
    }

    private func saveAndDismiss() {
        print("💾 [ComboTemplateInputView] 저장 시작")

        // 최종 값 생성
        let finalValue = previewText

        // ComboItem 업데이트
        var updatedItem = comboItem
        updatedItem.displayValue = finalValue
        updatedItem.displayTitle = template.title

        comboItem = updatedItem

        print("✅ [ComboTemplateInputView] 저장 완료")
        print("   최종 값: \(finalValue.prefix(50))...")

        dismiss()
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var comboItem = ComboItem(
            type: .template,
            referenceId: UUID(),
            order: 0,
            displayTitle: "테스트 템플릿",
            displayValue: nil
        )

        var body: some View {
            ComboTemplateInputView(
                template: Memo(
                    title: "이메일 서명",
                    value: "감사합니다.\n{이름} 드림\n{부서} | {회사명}",
                    isTemplate: true
                ),
                comboItem: $comboItem
            )
        }
    }

    return PreviewWrapper()
}
