//
//  TemplateEditSheet.swift
//  ClipKeyboard
//
//  Created by Leeo on 12/11/25.
//

import SwiftUI
import TipKit

// MARK: - Template Edit Sheet

struct TemplateEditSheet: View {
    let memo: Memo
    let onCopy: (String) -> Void
    let onCancel: () -> Void

    @Environment(\.appTheme) private var theme

    private let templateInfoTip = TemplateInfoTip()

    @State private var customPlaceholders: [String] = []
    @State private var placeholderInputs: [String: String] = [:]
    @State private var editedText: String = ""
    @State private var isEditingText: Bool = false
    /// 미리보기 칩을 탭해 포커스가 옮겨진 placeholder (강조 테두리)
    @State private var highlightedPlaceholder: String? = nil
    /// 자동 변수 칩을 탭했을 때 안내할 토큰 (예: {날짜})
    @State private var autoVarTipToken: String? = nil

    /// 날짜 토큰 — 자동(오늘) 대신 사용자가 오늘/내일/다음 주/2주 뒤/직접 선택할 수 있다.
    private static let dateTokens: Set<String> = ["{날짜}", "{date}"]
    private var dateTokensInTemplate: [String] {
        Self.dateTokens.filter { memo.value.contains($0) }
    }
    /// 날짜를 제외한 자동 변수(시간·타임존 등) — 그대로 자동 입력되며 탭 시 안내만 표시.
    private var autoVarsInTemplate: [String] {
        TemplateVariableProcessor.autoVariableTokens
            .subtracting(Self.dateTokens)
            .filter { memo.value.contains($0) }
    }

    var previewText: String {
        var result = isEditingText ? editedText : memo.value
        for (placeholder, value) in placeholderInputs where !value.isEmpty {
            result = result.replacingOccurrences(of: placeholder, with: value)
        }
        return TemplateVariableProcessor.process(result)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    // 템플릿을 탭해 처음 열었을 때 채우는 방법 안내
                    TipView(templateInfoTip)

                    templateOriginalSection
                    if !customPlaceholders.isEmpty || !autoVarsInTemplate.isEmpty {
                        fillChipsRow(proxy)
                    }
                    // 미리보기를 '값 선택'보다 위에 — 채우는 동안 결과가 바로 보이게.
                    previewSection
                    placeholderSection
                }
                .padding()
            }
            }
            .alert(
                String(format: NSLocalizedString("'%@'은 자동으로 채워져요", comment: "Auto variable tip title"),
                       (autoVarTipToken ?? "").strippingTemplateBraces),
                isPresented: Binding(get: { autoVarTipToken != nil }, set: { if !$0 { autoVarTipToken = nil } })
            ) {
                Button(NSLocalizedString("확인", comment: "OK")) { autoVarTipToken = nil }
            } message: {
                Text(NSLocalizedString("이 칸은 따로 입력하지 않아도 돼요. 복사할 때 오늘 날짜·현재 시각 등 현재 값으로 자동 입력됩니다.", comment: "Auto variable tip message"))
            }
            .navigationTitle(memo.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .solidNavBar(theme.bg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("취소", comment: "Cancel")) { onCancel() }
                        .accessibilityHint(NSLocalizedString("변경을 취소하고 닫습니다", comment: "Cancel template edit hint"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("복사", comment: "Copy")) {
                        savePlaceholderInputsToMemo()
                        onCopy(previewText)
                    }
                    .fontWeight(.semibold)
                    .accessibilityHint(NSLocalizedString("미리보기 텍스트를 클립보드에 복사합니다", comment: "Copy template button hint"))
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
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textMuted)
                Spacer()
                Button {
                    isEditingText.toggle()
                    if isEditingText { editedText = memo.value }
                } label: {
                    Text(isEditingText ? NSLocalizedString("완료", comment: "Done") : NSLocalizedString("수정", comment: "Edit"))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                .accessibilityHint(isEditingText
                    ? NSLocalizedString("편집을 완료하고 미리보기에 반영합니다", comment: "Done editing template hint")
                    : NSLocalizedString("템플릿 내용을 직접 수정합니다", comment: "Edit template content hint"))
            }

            if isEditingText {
                TextEditor(text: $editedText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)
                    .padding(12)
                    .background(theme.surfaceAlt)
                    .cornerRadius(theme.radiusMd)
                    .accessibilityLabel(NSLocalizedString("템플릿 내용 편집", comment: "Template content editor label"))
                    .accessibilityHint(NSLocalizedString("내용을 수정 후 완료를 눌러 저장합니다", comment: "Template editor hint"))
            } else {
                Text(memo.value.templateChipAttributed(theme: theme))
                    .font(.body)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surfaceAlt)
                    .cornerRadius(theme.radiusMd)
            }
        }
    }

    @ViewBuilder
    private var placeholderSection: some View {
        if customPlaceholders.isEmpty && dateTokensInTemplate.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.green)
                Text(NSLocalizedString("설정할 값이 없습니다", comment: "No values to set"))
                    .font(.body)
                    .fontWeight(.semibold)
                Text(NSLocalizedString("이 템플릿은 바로 사용 가능합니다", comment: "Template ready to use"))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(theme.radiusMd)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(NSLocalizedString("값 선택", comment: "Select value"))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textMuted)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.body)
                            .foregroundColor(.blue)
                        Text(NSLocalizedString("값을 선택하세요", comment: "Select a value hint"))
                            .font(.body)
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
                        ),
                        isHighlighted: highlightedPlaceholder == placeholder
                    )
                    .id(placeholder)
                }

                // 날짜 토큰 — 오늘/내일/다음 주/2주 뒤/직접 선택
                ForEach(dateTokensInTemplate, id: \.self) { token in
                    DatePlaceholderSelector(
                        token: token,
                        value: Binding(
                            get: { placeholderInputs[token] ?? "" },
                            set: { placeholderInputs[token] = $0 }
                        ),
                        isHighlighted: highlightedPlaceholder == token
                    )
                    .id(token)
                }
            }
        }
    }

    // MARK: - Fill Chips (탭해서 채우기)

    /// 템플릿의 빈칸들을 칩으로 보여주고, 탭하면 해당 값 선택으로 포커스를 옮긴다.
    /// 자동 변수(날짜 등)는 탭 시 "자동으로 채워짐" 안내를 띄운다.
    private func fillChipsRow(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("빈칸을 탭해 채우세요", comment: "Tap a blank to fill it"))
                .font(.body)
                .foregroundColor(theme.textMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(customPlaceholders, id: \.self) { ph in
                        let filled = !(placeholderInputs[ph] ?? "").isEmpty
                        Button { focusPlaceholder(ph, proxy: proxy) } label: {
                            fillChip(text: ph.strippingTemplateBraces,
                                     icon: filled ? "checkmark.circle.fill" : "arrow.down.circle.fill",
                                     tint: filled ? theme.success : theme.accent)
                        }
                        .accessibilityHint(NSLocalizedString("값 선택으로 이동합니다", comment: "Scroll to value selector hint"))
                    }
                    ForEach(dateTokensInTemplate, id: \.self) { token in
                        Button { focusPlaceholder(token, proxy: proxy) } label: {
                            fillChip(text: token.strippingTemplateBraces, icon: "calendar", tint: theme.accent)
                        }
                        .accessibilityHint(NSLocalizedString("날짜를 선택합니다", comment: "Pick a date hint"))
                    }
                    ForEach(autoVarsInTemplate, id: \.self) { tok in
                        Button { autoVarTipToken = tok } label: {
                            fillChip(text: tok.strippingTemplateBraces, icon: "clock.fill", tint: theme.textMuted)
                        }
                        .accessibilityHint(NSLocalizedString("자동으로 채워지는 값입니다", comment: "Auto-filled value hint"))
                    }
                }
            }
        }
    }

    private func fillChip(text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.body.weight(.medium))
        .foregroundColor(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }

    private func focusPlaceholder(_ placeholder: String, proxy: ScrollViewProxy) {
        HapticManager.shared.selection()
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(placeholder, anchor: .center)
            highlightedPlaceholder = placeholder
        }
        // 잠시 강조 후 해제
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if highlightedPlaceholder == placeholder {
                withAnimation { highlightedPlaceholder = nil }
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("미리보기", comment: "Preview"))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(theme.textMuted)
            Text(previewText.templateChipAttributed(theme: theme))
                .font(.body)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(theme.radiusMd)
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
            var memos = try MemoStore.shared.load(type: .memo)
            guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }
            memos[index].placeholderValues = placeholderInputs
                .filter { !$0.value.isEmpty }
                .mapValues { [$0] }
            try MemoStore.shared.save(memos: memos, type: .memo)
        } catch {
            // 저장 실패는 조용히 무시 — 복사 기능 자체는 계속 동작
        }
    }
}
