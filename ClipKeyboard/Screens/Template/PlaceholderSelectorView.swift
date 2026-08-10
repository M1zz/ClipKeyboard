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
    /// 미리보기 칩을 탭해 이 박스로 포커스가 옮겨졌을 때 강조 테두리 표시
    var isHighlighted: Bool = false
    /// Form 섹션 안에 넣을 때 - 자체 회색 카드/패딩을 끄고 섹션의 흰 카드에 자연스럽게 녹인다.
    var embedded: Bool = false
    @Environment(\.appTheme) private var theme

    @State private var values: [PlaceholderValue] = []
    @State private var newValue: String = ""
    @State private var showDeleteConfirm: PlaceholderValue?
    @State private var showDeleteAlert: Bool = false

    /// v4.0.8: 토큰명에 금액/amount/price 등이 있으면 numberPad
    private var isNumericToken: Bool {
        TemplateVariableProcessor.isNumericToken(placeholder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(placeholder.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textMuted)

                // 타입 뱃지
                HStack(spacing: 4) {
                    Image(systemName: isNumericToken ? "number" : "list.bullet")
                        .font(.body.weight(.semibold))
                    Text(isNumericToken
                         ? NSLocalizedString("숫자 입력", comment: "Numeric placeholder badge")
                         : NSLocalizedString("선택지", comment: "Selection placeholder badge"))
                        .font(.body.weight(.semibold))
                }
                .foregroundColor(isNumericToken ? .blue : .green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((isNumericToken ? Color.blue : Color.green).opacity(0.12))
                .cornerRadius(theme.radiusXs)
            }

            if isNumericToken {
                // 금액 등 숫자 토큰: 저장하지 않고 입력값을 바로 사용한다.
                // (다시 쓸 일 없는 1회성 값이라 저장 목록을 만들지 않음)
                TextField(NSLocalizedString("값을 입력해주세요", comment: "Direct value input placeholder"), text: $selectedValue)
                    .clipRoundedField()
                    .font(.body)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            } else {
                // 값 목록 (저장된 값 칩)
                if values.isEmpty {
                    // ⚠️ 예전에는 주황색 경고문 한 줄만 있었다. 처음 만든 템플릿을 눌러보면
                    //    빈칸에 뭘 넣어야 하는지 알 수 없어서 여기서 멈춘다.
                    //    **어떻게 생긴 값인지 보여 주는 것**이 설명보다 빠르다.
                    let examples = PlaceholderExamples.suggestions(for: placeholder)
                    if examples.isEmpty {
                        // 빈칸 이름을 못 알아본 경우. 엉뚱한 예시를 지어내느니 안내만 한다.
                        Text(NSLocalizedString("아래에서 값을 추가하세요", comment: "Add value hint"))
                            .font(.body)
                            .foregroundColor(theme.textMuted)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.surfaceAlt)
                            .cornerRadius(theme.radiusSm)
                    } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("이런 값을 넣어요", comment: "Placeholder examples header"))
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(theme.textMuted)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(examples, id: \.self) { example in
                                    Button {
                                        // 예시는 **누를 때에만** 내 값이 된다. 미리 넣어 두면
                                        // 쓴 적 없는 값이 목록에 쌓인다.
                                        MemoStore.shared.addPlaceholderValue(
                                            example, for: placeholder,
                                            sourceMemoId: sourceMemoId, sourceMemoTitle: sourceMemoTitle
                                        )
                                        loadValues()
                                        selectedValue = example
                                    } label: {
                                        Text(example)
                                            .font(.body)
                                            .foregroundColor(theme.textMuted)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                                                    .strokeBorder(theme.divider,
                                                                  style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                            )
                                    }
                                    .accessibilityHint(NSLocalizedString("탭하면 이 값으로 저장됩니다",
                                                                        comment: "Placeholder example chip hint"))
                                }
                            }
                        }

                        Text(NSLocalizedString("예시예요. 누르면 내 값으로 저장돼요.", comment: "Placeholder examples footnote"))
                            .font(.caption)
                            .foregroundColor(theme.textFaint)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surfaceAlt)
                    .cornerRadius(theme.radiusSm)
                    }
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
                                            .font(.body.weight(isSelected ? .semibold : .regular))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(isSelected ? Color.blue : theme.surfaceAlt)
                                            .foregroundColor(isSelected ? .white : .primary)
                                            .cornerRadius(theme.radiusLg)
                                    }
                                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                                    .accessibilityHint(isSelected
                                        ? NSLocalizedString("현재 선택됨", comment: "Filter chip: currently selected")
                                        : NSLocalizedString("탭하면 이 값으로 설정됩니다", comment: "Placeholder value chip hint"))

                                    Button {
                                        showDeleteConfirm = placeholderValue
                                        showDeleteAlert = true
                                    } label: {
                                        Image(systemName: AppSymbol.xmarkCircleFill)
                                            .font(.body)
                                            .foregroundColor(.red)
                                    }
                                    .accessibilityLabel(String(format: NSLocalizedString("%@ 삭제", comment: "Delete value label"), placeholderValue.value))
                                    .accessibilityHint(NSLocalizedString("이 저장된 값을 삭제합니다", comment: "Delete placeholder value hint"))
                                }
                            }
                        }
                    }
                }

                // 값 추가 입력 (저장형 토큰만)
                HStack(spacing: 8) {
                    TextField(NSLocalizedString("새로운 값을 추가해주세요", comment: "New value input placeholder"), text: $newValue)
                        .clipRoundedField()
                        .font(.body)

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
                            .font(.body)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(newValue.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(theme.radiusSm)
                    }
                    .disabled(newValue.isEmpty)
                    .accessibilityHint(NSLocalizedString("새 값을 목록에 추가합니다", comment: "Add value button hint"))
                }
            }
        }
        .embeddableCard(embedded: embedded, isHighlighted: isHighlighted, theme: theme)
        .animation(.easeInOut(duration: 0.25), value: isHighlighted)
        .onAppear {
            print("🎬 [PlaceholderSelectorView] onAppear - 플레이스홀더: \(placeholder)")
            loadValues()
            print("✅ [PlaceholderSelectorView] onAppear 완료 - 로드된 값: \(values.count)개, 선택된 값: '\(selectedValue)'")
        }
        .alert(NSLocalizedString("삭제 확인", comment: "Delete confirmation title"),
               isPresented: $showDeleteAlert) {
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {
                showDeleteConfirm = nil
            }
            Button(NSLocalizedString("삭제", comment: "Delete"), role: .destructive) {
                if let v = showDeleteConfirm {
                    MemoStore.shared.deletePlaceholderValue(valueId: v.id, for: placeholder)
                    loadValues()
                    if selectedValue == v.value { selectedValue = "" }
                }
                showDeleteConfirm = nil
            }
        } message: {
            if let v = showDeleteConfirm {
                Text(String(format: NSLocalizedString("'%@'을(를) 삭제하시겠습니까?", comment: "Delete confirmation message"), v.value))
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
                    Image(systemName: AppSymbol.docTextMagnifyingglass)
                        .font(.system(size: 50))
                        .foregroundColor(theme.textFaint)
                    Text(NSLocalizedString("템플릿이 없습니다", comment: "No templates"))
                        .font(.headline)
                        .foregroundColor(theme.textMuted)
                    Text(NSLocalizedString("채울 칸이 있는 템플릿을 만들면\n그 값들을 여기서 관리할 수 있어요", comment: "No templates description"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(NSLocalizedString("플레이스홀더 관리", comment: "Placeholder management title"))
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .solidNavBar(theme.bg)
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
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .navigationTitle(NSLocalizedString("플레이스홀더 관리", comment: "Placeholder management title"))
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .solidNavBar(theme.bg)
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
