//
//  TemplateSheets.swift
//  ClipKeyboard
//
//  TemplateEditSheet에서 분리한 템플릿 입력/상세/행/리졸버/날짜 선택 + String 헬퍼.
//

import SwiftUI
import TipKit
import LeeoKit

// MARK: - Template Input Sheet

struct TemplateInputSheet: View {
    let placeholders: [String]
    @Binding var inputs: [String: String]
    let onComplete: () -> Void
    let onCancel: () -> Void
    /// v4.0.8: 미리보기 계산용. 빈 문자열이면 미리보기 미표시.
    var originalText: String = ""
    /// v4.0.8: attachedTemplate 흐름이면 본 메모 본문 - preview 결합 표시용.
    var baseMemoValue: String = ""
    /// 저장값 귀속용 - PlaceholderSelectorView가 값 저장/로드 시 사용.
    var sourceMemoId: UUID = UUID()
    var sourceMemoTitle: String = ""

    @Environment(\.appTheme) private var theme
    private let attachedTemplateTip = AttachedTemplateTip()
    private let templateInfoTip = TemplateInfoTip()

    /// 템플릿에 든 날짜 토큰 - 자동(오늘) 대신 선택 가능.
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
                // 상단 설명 - 다른 뷰들처럼 TipKit 팁으로(플로팅, 닫기 가능).
                Section {
                    Group {
                        if baseMemoValue.isEmpty {
                            AnimatedTip(tip: templateInfoTip) { TipView(templateInfoTip) }
                        } else {
                            AnimatedTip(tip: attachedTemplateTip) { TipView(attachedTemplateTip) }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } header: { EmptyView() }

                // 실시간 결합 미리보기 - '값 선택'보다 위에 둬서 채우는 동안 결과가 바로 보인다.
                if !previewText.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: AppSymbol.eyeFill)
                                    .font(.body)
                                    .foregroundColor(.green)
                                Text(NSLocalizedString("입력될 결과", comment: "Live preview header"))
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(theme.textMuted)
                            }
                            Text(previewText.templateAwareAttributed(theme: theme))
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color.green.opacity(0.08))
                                .cornerRadius(theme.radiusSm)
                        }
                    } header: {
                        Text(NSLocalizedString("미리보기", comment: "Preview"))
                    }
                }

                Section {
                    // 값 선택 - 다른 섹션과 동일한 흰 카드 스타일(embedded: 자체 회색 카드 제거)
                    ForEach(placeholders, id: \.self) { placeholder in
                        PlaceholderSelectorView(
                            placeholder: placeholder,
                            sourceMemoId: sourceMemoId,
                            sourceMemoTitle: sourceMemoTitle,
                            selectedValue: Binding(
                                get: { inputs[placeholder] ?? "" },
                                set: { inputs[placeholder] = $0 }
                            ),
                            embedded: true
                        )
                    }
                } header: {
                    Text(NSLocalizedString("값 선택", comment: "Select value"))
                }

                // 날짜 토큰 - 오늘/내일/다음 주/2주 뒤/직접 선택 (다른 섹션과 동일한 흰 카드)
                if !dateTokensInInput.isEmpty {
                    Section {
                        ForEach(dateTokensInInput, id: \.self) { token in
                            DatePlaceholderSelector(
                                token: token,
                                value: Binding(
                                    get: { inputs[token] ?? "" },
                                    set: { inputs[token] = $0 }
                                ),
                                embedded: true
                            )
                        }
                    } header: {
                        Text(NSLocalizedString("날짜", comment: "Date section header"))
                    }
                }
            }
            .navigationTitle(NSLocalizedString("템플릿 입력", comment: "Template input title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .solidNavBar(theme.bg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("취소", comment: "Cancel")) { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("복사", comment: "Copy")) { onComplete() }
                        .disabled(inputs.values.contains(where: { $0.isEmpty }))
                }
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

                    Text(template.value.templateAwareAttributed(theme: theme))
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
                        Image(systemName: AppSymbol.checkmarkCircleFill)
                            .font(.system(size: 40))
                            .foregroundColor(Color.checkGreen)
                        Text(NSLocalizedString("이 템플릿에는 빈칸이 없습니다", comment: "No placeholders in template"))
                            .font(.body)
                            .foregroundColor(theme.textMuted)
                    }
                    .padding(.top, 50)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(format: NSLocalizedString("빈칸 %d개", comment: "Blank count"), placeholders.count))
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
        .solidNavBar(theme.bg)
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
    @State private var showDeleteConfirm: PlaceholderValue?
    @State private var showDeleteAlert: Bool = false
    @State private var editingValue: PlaceholderValue?
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
                .foregroundColor(.accentColor)
                .font(.system(.title2))
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
                                Image(systemName: AppSymbol.pencilCircleFill)
                                    .font(.system(.title))
                                    .foregroundColor(.accentColor)
                            }
                            .accessibilityLabel(String(format: NSLocalizedString("%@ 수정", comment: "Edit value button label"), value.value))
                            .accessibilityHint(NSLocalizedString("이 값을 수정합니다", comment: "Edit value button hint"))

                            Button {
                                showDeleteConfirm = value
                                showDeleteAlert = true
                            } label: {
                                Image(systemName: AppSymbol.trashCircleFill)
                                    .font(.system(.title))
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
    @State private var loadedMemo: Memo?
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
    /// Form 섹션에 자연스럽게 녹이기 위해 자체 회색 카드를 끈다.
    var embedded: Bool = false
    @Environment(\.appTheme) private var theme
    @State private var customDate: Date = Date()

    /// ⚠️ 여기서 만든 글자가 그대로 문장에 들어간다. `{날짜}` 를 자동으로 넣을 때와
    ///    **같은 모양이어야 한다** - 고른 날짜만 08/31/2026 이고 오늘 날짜는 2026-08-31 이면
    ///    같은 문서 안에서 날짜 모양이 둘로 갈린다.
    private static func formatted(_ date: Date) -> String {
        DateTokenFormat.selection.string(from: date)
    }

    private struct Opt: Identifiable { let id = UUID(); let label: String; let days: Int }
    private var opts: [Opt] {
        [Opt(label: NSLocalizedString("오늘", comment: "Date option: today"), days: 0),
         Opt(label: NSLocalizedString("내일", comment: "Date option: tomorrow"), days: 1),
         Opt(label: NSLocalizedString("다음 주", comment: "Date option: next week"), days: 7),
         Opt(label: NSLocalizedString("2주 뒤", comment: "Date option: in two weeks"), days: 14)]
    }
    private func str(_ days: Int) -> String {
        Self.formatted(Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date())
    }
    private var effectiveValue: String { value.isEmpty ? str(0) : value }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: AppSymbol.calendar)
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
                .onChange(of: customDate) { _, d in value = Self.formatted(d) }
        }
        .embeddableCard(embedded: embedded, isHighlighted: isHighlighted, theme: theme)
        .animation(.easeInOut(duration: 0.25), value: isHighlighted)
        .onAppear { if !value.isEmpty, let d = DateTokenFormat.date(from: value) { customDate = d } }
    }
}

// MARK: - String Helper

extension String {
    // `{변수}` 를 다루는 것은 전부 DesignSystem/TemplatePlaceholder.swift 한 곳에 있다.
    // (`templateAwareAttributed` · `strippingTemplateBraces` · `extractTemplatePlaceholders`)

    /// 형식 문자열을 마커에서 갈라 **가운데 한 조각만** 다른 색으로 칠한다.
    /// "무엇이 고정이고 무엇이 바뀌는지"를 색으로 보여주는 안내 문장이 여러 화면에 흩어져
    /// 있어서, 같은 모양을 네 군데서 각자 만들던 것을 여기로 모았다.
    ///
    /// 번역이 마커를 잃어버렸더라도 문장은 그대로 보이게 한다(색만 안 켜질 뿐).
    /// - Parameter strong: 가운데 조각을 굵게. 폰트를 지정하지 않고 강조 의도만 실어서
    ///   호출한 뷰의 폰트를 덮어쓰지 않는다.
    func attributedHighlighting(_ highlight: String,
                                separatedBy marker: String = "%@",
                                base: Color,
                                accent: Color,
                                strong: Bool = false) -> AttributedString {
        func painted(_ text: String, _ color: Color) -> AttributedString {
            var piece = AttributedString(text)
            piece.foregroundColor = color
            return piece
        }

        let parts = components(separatedBy: marker)
        guard parts.count == 2 else {
            return painted(String(format: self, highlight), base)
        }

        var middle = painted(highlight, accent)
        if strong { middle.inlinePresentationIntent = .stronglyEmphasized }
        return painted(parts[0], base) + middle + painted(parts[1], base)
    }

}

// MARK: - Template Fill Sheet (탭 시 하프모달, 키보드 스타일 값 입력)

struct TemplateFillSheet: View {
    let memo: Memo
    /// 최종 resolved 문자열(자동 변수까지 치환됨)을 전달.
    let onCopy: (String) -> Void
    let onCancel: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var inputs: [String: String] = [:]
    @State private var placeholders: [String] = []

    /// 사용자 변수가 모두 채워졌는지.
    private var allFilled: Bool {
        !placeholders.contains { (inputs[$0] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// 현재 입력 기준 최종 결과(자동 변수 포함 치환). 복사 시 사용.
    private var resolvedValue: String {
        TemplateVariableProcessor.substitute(memo.value, with: inputs)
    }

    /// 미리보기용 - 아직 안 채운 변수는 그대로 남겨 칩으로 보이게 한다.
    /// (onAppear가 inputs를 빈 문자열("")로 초기화하므로, 빈 값까지 치환하면
    ///  {금액} 같은 미입력 변수가 빈칸으로 지워져 프리뷰에서 사라진다 → 빈 값은 제외.)
    private var previewValue: String {
        let filled = inputs.filter { !$0.value.isEmpty }
        return TemplateVariableProcessor.substitute(memo.value, with: filled)
    }

    /// 제목 - 채울 변수가 하나뿐이면 변수명 기반("금액 입력")으로 더 구체적으로,
    /// 여러 개면 일반 "템플릿 입력"으로 표시.
    private var fillTitle: String {
        let custom = memo.value.extractTemplatePlaceholders()
        if custom.count == 1 {
            return String(
                format: NSLocalizedString("%@ 입력", comment: "Template fill title for a single placeholder, e.g. 금액 입력"),
                custom[0].strippingTemplateBraces
            )
        }
        return NSLocalizedString("템플릿 입력", comment: "Template input title")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: 미리보기 - 복사될 결과. 입력값은 치환된 평문으로, 아직 안 채운 변수는
                // 다른 화면(TemplateInputSheet/TemplateEditSheet)과 동일하게 중괄호 없는 강조색
                // 칩으로 표시한다(templateAwareAttributed).
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: AppSymbol.eyeFill)
                            .font(.footnote)
                            .foregroundColor(.green)
                        Text(NSLocalizedString("입력될 결과", comment: "Live preview header"))
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(theme.textMuted)
                    }
                    Text(previewValue.templateAwareAttributed(theme: theme))
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(theme.surfaceAlt)
                        .cornerRadius(theme.radiusSm)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // MARK: 플레이스홀더 입력
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(placeholders, id: \.self) { ph in
                            TemplateFillRow(
                                placeholder: ph,
                                templateId: memo.id,
                                templateTitle: memo.title,
                                value: Binding(
                                    get: { inputs[ph] ?? "" },
                                    set: { inputs[ph] = $0 }
                                )
                            )
                        }
                    }
                    .padding(16)
                }
            }
            .background(theme.bg)
            .navigationTitle(fillTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("취소", comment: "Cancel")) { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        // ⚠️ 여기서 값을 저장하지 않는다. 적은 값은 **이번에만** 쓰는 것이고,
                        //    남길지는 각 칸의 별이 정한다(`TemplateFillRow`).
                        HapticManager.shared.success()
                        onCopy(resolvedValue)
                    } label: {
                        Label(NSLocalizedString("복사", comment: "Copy"), systemImage: AppSymbol.docOnDoc)
                            .fontWeight(.semibold)
                    }
                    .disabled(!allFilled)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            // 자동 변수({날짜} 등)는 제외하고 사용자가 채울 커스텀 변수만.
            let custom = memo.value.extractTemplatePlaceholders()
            placeholders = custom
            for ph in custom where inputs[ph] == nil { inputs[ph] = "" }
        }
    }

}

// MARK: - Per-Placeholder Fill Row (키보드 PlaceholderInputView 이식 + 인앱 TextField)

private struct TemplateFillRow: View {
    let placeholder: String
    let templateId: UUID
    let templateTitle: String
    @Binding var value: String

    @Environment(\.appTheme) private var theme
    @State private var savedValues: [String] = []

    private var isNumeric: Bool { TemplateVariableProcessor.isNumericToken(placeholder) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 토큰 이름 헤더 - 여러 변수일 때 어느 칸인지 구분.
            Text(placeholder.strippingTemplateBraces)
                .font(.body.weight(.semibold))
                .foregroundColor(theme.textMuted)

            if isNumeric {
                numericSection
            } else {
                textSection
            }
        }
        .padding(14)
        .background(theme.surface)
        .cornerRadius(theme.radiusMd)
        .overlay(RoundedRectangle(cornerRadius: theme.radiusMd).stroke(theme.divider, lineWidth: 1))
        .onAppear { loadSaved() }
    }

    // MARK: 숫자 입력 - 1-9 키패드 + ⌫ + 00/000/0000 + 저장값 칩

    @ViewBuilder
    private var numericSection: some View {
        VStack(spacing: 8) {
            // 입력값은 상단 "입력될 결과" 프리뷰에 실시간 반영되므로 여기서 다시 표시하지 않는다(중복 제거).
            HStack(spacing: 6) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9"], id: \.self) { d in numericKey(d) }
                Button {
                    if !value.isEmpty { value.removeLast() }
                    HapticManager.shared.selection()
                } label: {
                    Image(systemName: AppSymbol.deleteLeft)
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color(UIColor.systemGray4))
                        .foregroundColor(.primary)
                        .cornerRadius(theme.radiusXs)
                }
                .accessibilityLabel(NSLocalizedString("지우기", comment: "Backspace button"))
            }
            HStack(spacing: 6) {
                numericKey("0")
                ForEach(["00", "000", "0000"], id: \.self) { z in numericKey(z) }
            }
            savedChips
        }
    }

    @ViewBuilder
    private func numericKey(_ digit: String) -> some View {
        Button {
            guard value.count + digit.count <= 13 else { return }
            if value.isEmpty && (digit == "0" || digit.allSatisfy { $0 == "0" }) {
                value = "0"
            } else if value == "0" {
                value = digit.allSatisfy { $0 == "0" } ? "0" : digit
            } else {
                value += digit
            }
            HapticManager.shared.selection()
        } label: {
            Text(digit)
                .font(.system(.headline, design: .monospaced, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(UIColor.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(theme.radiusXs)
        }
    }

    // MARK: 텍스트 입력 - 곧장 채우는 TextField + 저장값 칩

    /// ⚠️ **적은 값은 저장되지 않는다.** 예전에는 "추가"를 눌러 목록에 넣어야만 쓸 수 있었고,
    ///    복사할 때 채운 값이 전부 목록에 쌓였다. 그래서 한 번 쓰고 말 값(오늘 회의 장소,
    ///    이번 주문번호)까지 칩으로 남아 목록이 금세 못 쓰게 됐다.
    ///
    ///    이제 입력칸은 **채울 값에 곧장 이어져** 있다. 치면 그대로 쓰인다.
    ///    남길 값만 별을 눌러 저장한다.
    @ViewBuilder
    private var textSection: some View {
        HStack(spacing: 8) {
            TextField(NSLocalizedString("값 입력", comment: "Template value text field placeholder"), text: $value)
                .textFieldStyle(.roundedBorder)
            keepButton
        }
        Text(NSLocalizedString("적은 값은 이번에만 써요. 별을 누르면 다음에도 쓰게 저장돼요",
                               comment: "Fill sheet: one-off value hint"))
            .font(.caption)
            .foregroundColor(theme.textFaint)
            .fixedSize(horizontal: false, vertical: true)
        savedChips
    }

    private var trimmedValue: String {
        value.trimmingCharacters(in: .whitespaces)
    }

    /// 지금 값이 이미 저장 목록에 있는가.
    private var isKept: Bool {
        !trimmedValue.isEmpty && savedValues.contains(trimmedValue)
    }

    /// 이 값을 남길지 정하는 별. 이미 저장된 값이면 채워진 채로 서 있기만 한다.
    private var keepButton: some View {
        Button {
            keepCurrentValue()
        } label: {
            Image(systemName: isKept ? AppSymbol.starFill : AppSymbol.star)
                .font(.title3)
                .foregroundColor(isKept ? .yellow : theme.textFaint)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(trimmedValue.isEmpty || isKept)
        .accessibilityLabel(isKept
            ? NSLocalizedString("이미 저장해 둔 값이에요", comment: "Fill sheet: value already kept")
            : NSLocalizedString("이 값 저장해 두기", comment: "Fill sheet: keep this value"))
    }

    /// 지금 값을 저장 목록에 남긴다. 누른 그 자리에서 칩으로 나타난다.
    private func keepCurrentValue() {
        let v = trimmedValue
        guard !v.isEmpty, !savedValues.contains(v) else { return }
        MemoStore.shared.addPlaceholderValue(v, for: placeholder,
                                             sourceMemoId: templateId, sourceMemoTitle: templateTitle)
        HapticManager.shared.success()
        loadSaved()
    }

    // MARK: 저장값 칩 (공통)

    @ViewBuilder
    private var savedChips: some View {
        if !savedValues.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(savedValues, id: \.self) { v in
                        Button {
                            value = v
                            HapticManager.shared.selection()
                        } label: {
                            Text(v)
                                .font(.footnote.weight(value == v ? .semibold : .regular))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(value == v ? theme.accent : Color(UIColor.systemGray5))
                                .foregroundColor(value == v ? theme.accentFg : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func loadSaved() {
        // 중복 제거 + 최근 순 유지.
        var seen = Set<String>()
        savedValues = MemoStore.shared.loadPlaceholderValues(for: placeholder)
            .map { $0.value }
            .filter { seen.insert($0).inserted }
    }
}
