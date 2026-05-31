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
                    placeholderSection
                    previewSection
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
            .toolbarBackground(theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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

// MARK: - Template Input Sheet

struct TemplateInputSheet: View {
    let placeholders: [String]
    @Binding var inputs: [String: String]
    let onComplete: () -> Void
    let onCancel: () -> Void
    /// v4.0.8: 미리보기 계산용. 빈 문자열이면 미리보기 미표시.
    var originalText: String = ""
    /// v4.0.8: attachedTemplate 흐름이면 본 메모 본문 — preview 결합 표시용.
    var baseMemoValue: String = ""

    @Environment(\.appTheme) private var theme
    @FocusState private var focusedField: String?

    /// 템플릿에 든 날짜 토큰 — 자동(오늘) 대신 선택 가능.
    private var dateTokensInInput: [String] {
        ["{날짜}", "{date}"].filter { originalText.contains($0) }
    }

    /// 현재 입력값 기준 결합 미리보기.
    private var previewText: String {
        guard !originalText.isEmpty else { return "" }
        let resolvedTemplate = TemplateVariableProcessor.substitute(originalText, with: inputs)
        if baseMemoValue.isEmpty {
            return resolvedTemplate
        }
        return baseMemoValue + "\n" + resolvedTemplate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if baseMemoValue.isEmpty {
                        Text(NSLocalizedString("템플릿을 완성하세요", comment: "Complete the template"))
                            .font(.headline)
                            .foregroundColor(theme.textMuted)
                    } else {
                        // attachedTemplate 흐름 — 메모 본문 + 연결된 템플릿이 합쳐진다는 걸 설명
                        VStack(alignment: .leading, spacing: 4) {
                            Label(NSLocalizedString("메모 + 템플릿", comment: "Memo plus template header"),
                                  systemImage: "doc.badge.plus")
                                .font(.headline)
                                .foregroundColor(theme.text)
                            Text(NSLocalizedString("이 메모에 템플릿이 연결돼 있어요. 빈칸을 채우면 메모 내용과 합쳐서 복사돼요. 아래 '입력될 결과'에서 미리 볼 수 있어요.", comment: "Attached template explanation"))
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                        }
                    }
                } header: { EmptyView() }

                // v4.0.8: 실시간 결합 미리보기
                if !previewText.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "eye.fill")
                                    .font(.body)
                                    .foregroundColor(.green)
                                Text(NSLocalizedString("입력될 결과", comment: "Live preview header"))
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(theme.textMuted)
                            }
                            Text(previewText.templateChipAttributed(theme: theme))
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color.green.opacity(0.08))
                                .cornerRadius(theme.radiusSm)
                        }
                    }
                }

                Section {
                    ForEach(placeholders, id: \.self) { placeholder in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(placeholder.strippingTemplateBraces)
                                    .font(.body)
                                    .foregroundColor(theme.textMuted)
                                if TemplateVariableProcessor.isNumericToken(placeholder) {
                                    Text(NSLocalizedString("숫자", comment: "Numeric token hint"))
                                        .font(.body.weight(.semibold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundColor(.blue)
                                        .cornerRadius(theme.radiusXs)
                                }
                            }

                            TextField(NSLocalizedString("입력하세요", comment: "Input placeholder"), text: Binding(
                                get: { inputs[placeholder] ?? "" },
                                set: { inputs[placeholder] = $0 }
                            ))
                            .clipRoundedField()
                            #if os(iOS)
                            .keyboardType(TemplateVariableProcessor.isNumericToken(placeholder) ? .numberPad : .default)
                            #endif
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

                // 날짜 토큰 — 오늘/내일/다음 주/2주 뒤/직접 선택
                if !dateTokensInInput.isEmpty {
                    Section {
                        ForEach(dateTokensInInput, id: \.self) { token in
                            DatePlaceholderSelector(
                                token: token,
                                value: Binding(
                                    get: { inputs[token] ?? "" },
                                    set: { inputs[token] = $0 }
                                )
                            )
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("템플릿 입력", comment: "Template input title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbarBackground(theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textMuted)

                    Text(template.value.templateChipAttributed(theme: theme))
                        .font(.body)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.surfaceAlt)
                        .cornerRadius(theme.radiusMd)
                }
                .padding(.horizontal)
                .padding(.top)

                if placeholders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        Text(NSLocalizedString("이 템플릿에는 플레이스홀더가 없습니다", comment: "No placeholders in template"))
                            .font(.body)
                            .foregroundColor(theme.textMuted)
                    }
                    .padding(.top, 50)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(format: NSLocalizedString("플레이스홀더 (%d개)", comment: "Placeholder count"), placeholders.count))
                            .font(.body)
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
        .toolbarBackground(theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var values: [PlaceholderValue] = []
    @State private var showDeleteConfirm: PlaceholderValue? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var editingValue: PlaceholderValue? = nil
    @State private var showEditAlert: Bool = false
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
        .cornerRadius(theme.radiusMd)
        .overlay(RoundedRectangle(cornerRadius: theme.radiusMd).stroke(theme.divider, lineWidth: 1))
        .onAppear { loadValues() }
        .alert(NSLocalizedString("삭제 확인", comment: "Delete confirmation"),
               isPresented: $showDeleteAlert) {
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {
                showDeleteConfirm = nil
            }
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
               isPresented: $showEditAlert) {
            TextField(NSLocalizedString("값", comment: "Value"), text: $editText)
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {
                editingValue = nil
            }
            Button(NSLocalizedString("저장", comment: "Save")) {
                if let v = editingValue, !editText.isEmpty {
                    MemoStore.shared.deletePlaceholderValue(valueId: v.id, for: placeholder)
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
                    .font(.body)
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
            withAnimation(reduceMotion ? nil : .spring(response: 0.3)) { isExpanded.toggle() }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(
            String(format: NSLocalizedString("%@, 값 %d개", comment: "Placeholder row header label"), placeholder.strippingTemplateBraces, values.count)
        )
        .accessibilityHint(isExpanded
            ? NSLocalizedString("탭하면 값 목록을 접습니다", comment: "Collapse placeholder row hint")
            : NSLocalizedString("탭하면 값 목록을 펼칩니다", comment: "Expand placeholder row hint")
        )
    }

    @ViewBuilder
    private var valueList: some View {
        if values.isEmpty {
            Text(NSLocalizedString("값이 없습니다.\n템플릿 사용 시 값을 추가하세요.", comment: "No values hint"))
                .font(.body)
                .foregroundColor(.orange)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(theme.radiusSm)
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
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        HStack(spacing: 16) {
                            Button {
                                editingValue = value
                                editText = value.value
                                showEditAlert = true
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.blue)
                            }
                            .accessibilityLabel(String(format: NSLocalizedString("%@ 수정", comment: "Edit value button label"), value.value))
                            .accessibilityHint(NSLocalizedString("이 값을 수정합니다", comment: "Edit value button hint"))

                            Button {
                                showDeleteConfirm = value
                                showDeleteAlert = true
                            } label: {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.red)
                            }
                            .accessibilityLabel(String(format: NSLocalizedString("%@ 삭제", comment: "Delete value button label"), value.value))
                            .accessibilityHint(NSLocalizedString("이 저장된 값을 삭제합니다", comment: "Delete value button hint"))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(theme.surfaceAlt)
                    .cornerRadius(theme.radiusSm)
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
                        .font(.body)
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
            let memo = (try? MemoStore.shared.load(type: .memo))?.first(where: { $0.id == templateId })
            DispatchQueue.main.async {
                loadedMemo = memo
                isLoading = false
            }
        }
    }
}

// MARK: - Date Placeholder Selector

/// 날짜 토큰({날짜}/{date})용 선택기. 자동(오늘) 고정 대신 오늘·내일·다음 주·2주 뒤·직접 선택을 제공.
/// 선택값을 inputs에 넣으면 substitute가 자동 처리보다 우선 적용한다.
struct DatePlaceholderSelector: View {
    let token: String
    @Binding var value: String
    var isHighlighted: Bool = false
    @Environment(\.appTheme) private var theme
    @State private var customDate: Date = Date()

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private struct Opt: Identifiable { let id = UUID(); let label: String; let days: Int }
    private var opts: [Opt] {
        [Opt(label: NSLocalizedString("오늘", comment: "Date option: today"), days: 0),
         Opt(label: NSLocalizedString("내일", comment: "Date option: tomorrow"), days: 1),
         Opt(label: NSLocalizedString("다음 주", comment: "Date option: next week"), days: 7),
         Opt(label: NSLocalizedString("2주 뒤", comment: "Date option: in two weeks"), days: 14)]
    }
    private func str(_ days: Int) -> String {
        Self.fmt.string(from: Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date())
    }
    private var effectiveValue: String { value.isEmpty ? str(0) : value }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text(token.strippingTemplateBraces).fontWeight(.semibold)
                Spacer()
                Text(effectiveValue).fontWeight(.semibold).foregroundColor(theme.accent)
            }
            .font(.body)
            .foregroundColor(theme.textMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(opts) { opt in
                        let sel = effectiveValue == str(opt.days)
                        Button {
                            HapticManager.shared.selection()
                            customDate = Calendar.current.date(byAdding: .day, value: opt.days, to: Date()) ?? Date()
                            value = str(opt.days)
                        } label: {
                            Text(opt.label)
                                .font(.body.weight(.medium))
                                .foregroundColor(sel ? .white : theme.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(sel ? theme.accent : theme.accent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            DatePicker(NSLocalizedString("직접 선택", comment: "Pick a specific date"),
                       selection: $customDate, displayedComponents: .date)
                .font(.body)
                .onChange(of: customDate) { _, d in value = Self.fmt.string(from: d) }
        }
        .padding()
        .background(theme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                .strokeBorder(isHighlighted ? theme.accent : theme.divider, lineWidth: isHighlighted ? 2 : 1)
        )
        .animation(.easeInOut(duration: 0.25), value: isHighlighted)
        .onAppear { if !value.isEmpty, let d = Self.fmt.date(from: value) { customDate = d } }
    }
}

// MARK: - String Helper

private extension String {
    /// 템플릿 본문의 `{플레이스홀더}`를 중괄호 없는 칩(부드러운 배경 + 강조색)으로 렌더링한 AttributedString.
    /// 아직 채워지지 않은 변수 자리를 코드가 아니라 '채울 칸'처럼 보이게 한다.
    func templateChipAttributed(theme: AppTheme) -> AttributedString {
        guard let regex = try? NSRegularExpression(pattern: "\\{([^}]+)\\}") else {
            return AttributedString(self)
        }
        let ns = self as NSString
        var out = AttributedString()
        var cursor = 0
        for match in regex.matches(in: self, range: NSRange(location: 0, length: ns.length)) {
            let full = match.range
            if full.location > cursor {
                let plain = ns.substring(with: NSRange(location: cursor, length: full.location - cursor))
                out += AttributedString(plain)
            }
            // 중괄호는 숨기고 변수명만, 양옆 얇은 공백(U+2009)으로 칩 패딩을 흉내낸다.
            let name = ns.substring(with: match.range(at: 1))
            var chip = AttributedString("\u{2009}\(name)\u{2009}")
            chip.foregroundColor = theme.accent
            chip.backgroundColor = theme.accentSoft
            chip.font = .body.weight(.semibold)
            out += chip
            cursor = full.location + full.length
        }
        if cursor < ns.length {
            out += AttributedString(ns.substring(from: cursor))
        }
        return out
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
