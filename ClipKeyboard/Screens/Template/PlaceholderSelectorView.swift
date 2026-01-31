//
//  PlaceholderSelectorView.swift
//  Token memo
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

    @State private var values: [PlaceholderValue] = []
    @State private var isAdding: Bool = false
    @State private var newValue: String = ""
    @State private var showDeleteConfirm: PlaceholderValue? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(placeholder.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    isAdding.toggle()
                } label: {
                    Image(systemName: isAdding ? "xmark.circle.fill" : "plus.circle.fill")
                        .foregroundColor(isAdding ? .red : .blue)
                        .font(.system(size: 18))
                }
            }

            // 값 추가 입력
            if isAdding {
                HStack(spacing: 8) {
                    TextField("새 값 입력", text: $newValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout)

                    Button {
                        if !newValue.isEmpty && !values.contains(where: { $0.value == newValue }) {
                            // 새 값 추가 (출처 정보 포함)
                            MemoStore.shared.addPlaceholderValue(
                                newValue,
                                for: placeholder,
                                sourceMemoId: sourceMemoId,
                                sourceMemoTitle: sourceMemoTitle
                            )
                            loadValues()
                            selectedValue = newValue
                            newValue = ""
                            isAdding = false
                        }
                    } label: {
                        Text("추가")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(newValue.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(newValue.isEmpty)
                }
            }

            // 값 목록
            if values.isEmpty {
                Text("+ 버튼을 눌러 값을 추가하세요")
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
                                Button {
                                    selectedValue = placeholderValue.value
                                } label: {
                                    Text(placeholderValue.value)
                                        .font(.system(size: 14, weight: selectedValue == placeholderValue.value ? .semibold : .regular))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedValue == placeholderValue.value ? Color.blue : Color(.systemGray5))
                                        .foregroundColor(selectedValue == placeholderValue.value ? .white : .primary)
                                        .cornerRadius(16)
                                }

                                Button {
                                    showDeleteConfirm = placeholderValue
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .onAppear {
            print("🎬 [PlaceholderSelectorView] onAppear - 플레이스홀더: \(placeholder)")
            loadValues()
            print("✅ [PlaceholderSelectorView] onAppear 완료 - 로드된 값: \(values.count)개, 선택된 값: '\(selectedValue)'")
        }
        .alert("삭제 확인", isPresented: .constant(showDeleteConfirm != nil)) {
            Button("취소", role: .cancel) {
                showDeleteConfirm = nil
            }
            Button("삭제", role: .destructive) {
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
                Text("'\(value.value)'을(를) 삭제하시겠습니까?")
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

    var templateMemos: [Memo] {
        allMemos.filter { $0.isTemplate }
    }

    var body: some View {
        NavigationStack {
            if templateMemos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("템플릿이 없습니다")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("템플릿 메모를 생성하고 {} 를 사용하면\n여기서 관리할 수 있습니다")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("플레이스홀더 관리")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("완료") {
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
                .navigationTitle("플레이스홀더 관리")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("완료") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func extractPlaceholderPreview(from text: String) -> String {
        let autoVariables = ["{날짜}", "{시간}", "{연도}", "{월}", "{일}"]
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return "플레이스홀더 없음" }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var placeholders: [String] = []

        for match in matches {
            if let range = Range(match.range, in: text) {
                let placeholder = String(text[range])
                if !autoVariables.contains(placeholder) && !placeholders.contains(placeholder) {
                    placeholders.append(placeholder)
                }
            }
        }

        if placeholders.isEmpty {
            return "플레이스홀더 없음"
        }

        return placeholders.map { $0.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "") }.joined(separator: ", ")
    }
}
