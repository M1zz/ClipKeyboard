//
//  TemplateSheets.swift
//  ClipKeyboard
//
//  TemplateEditSheet에서 분리한 템플릿 입력/상세/행/리졸버/날짜 선택 + String 헬퍼.
//

import SwiftUI
import TipKit

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
    /// 저장값 귀속용 — PlaceholderSelectorView가 값 저장/로드 시 사용.
    var sourceMemoId: UUID = UUID()
    var sourceMemoTitle: String = ""

    @Environment(\.appTheme) private var theme
    private let attachedTemplateTip = AttachedTemplateTip()
    private let templateInfoTip = TemplateInfoTip()

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
                // 상단 설명 — 다른 뷰들처럼 TipKit 팁으로(플로팅, 닫기 가능).
                Section {
                    Group {
                        if baseMemoValue.isEmpty {
                            TipView(templateInfoTip)
                        } else {
                            TipView(attachedTemplateTip)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } header: { EmptyView() }

                // 실시간 결합 미리보기 — '값 선택'보다 위에 둬서 채우는 동안 결과가 바로 보인다.
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
                    } header: {
                        Text(NSLocalizedString("미리보기", comment: "Preview"))
                    }
                }

                Section {
                    // 값 선택 — 다른 섹션과 동일한 흰 카드 스타일(embedded: 자체 회색 카드 제거)
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

                // 날짜 토큰 — 오늘/내일/다음 주/2주 뒤/직접 선택 (다른 섹션과 동일한 흰 카드)
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
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(.title))
                                    .foregroundColor(.blue)
                            }
                            .accessibilityLabel(String(format: NSLocalizedString("%@ 수정", comment: "Edit value button label"), value.value))
                            .accessibilityHint(NSLocalizedString("이 값을 수정합니다", comment: "Edit value button hint"))

                            Button {
                                showDeleteConfirm = value
                                showDeleteAlert = true
                            } label: {
                                Image(systemName: "trash.circle.fill")
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
    /// Form 섹션에 자연스럽게 녹이기 위해 자체 회색 카드를 끈다.
    var embedded: Bool = false
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
        .embeddableCard(embedded: embedded, isHighlighted: isHighlighted, theme: theme)
        .animation(.easeInOut(duration: 0.25), value: isHighlighted)
        .onAppear { if !value.isEmpty, let d = Self.fmt.date(from: value) { customDate = d } }
    }
}

// MARK: - String Helper

extension String {
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
