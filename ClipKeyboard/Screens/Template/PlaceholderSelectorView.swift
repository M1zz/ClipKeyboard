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
                Text(placeholder.strippingTemplateBraces)
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
                // 키컬러가 녹색이 되면서 "선택지"의 시스템 녹색과 붙어 버렸다.
                // 두 뱃지는 한눈에 갈려야 하므로 선택지 쪽을 인디고로 뗀다.
                .foregroundColor(isNumericToken ? .accentColor : .indigo)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((isNumericToken ? Color.accentColor : Color.indigo).opacity(0.12))
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
                                            .background(isSelected ? Color.accentColor : theme.surfaceAlt)
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
                            .background(newValue.isEmpty ? Color.gray : Color.accentColor)
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
/// **빈칸 관리** - 빈칸을 이름 기준으로 늘어놓는다.
///
/// ⚠️ 예전에는 **템플릿을 먼저 고르게** 했다. 그 순서가 거짓말을 했다.
///    값은 `placeholder_values_{이름}` 에 저장되므로 처음부터 이름 기준이고, 새해인사의
///    `{이름}` 과 안부의 `{이름}` 은 같은 빈칸이다. 그런데 화면이 템플릿부터 물으니
///    사용자는 템플릿마다 빈칸을 새로 만드는 줄 알고 이름을 조금씩 다르게 적었다.
///    이름이 갈라지면 값도 갈라진다. 그래서 화면을 뒤집었다.
///
/// ⚠️ 쓰는 곳이 없어진 빈칸도 값이 남아 있으면 보여 준다. 안 보이면 지울 수도 없다.
struct PlaceholderManagementSheet: View {
    let allMemos: [Memo]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @State private var summaries: [PlaceholderSummary] = []

    var body: some View {
        NavigationStack {
            Group {
                if summaries.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle(NSLocalizedString("빈칸 관리", comment: "Placeholder management title (by name)"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .solidNavBar(theme.bg)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("완료", comment: "Done")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: reload)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: AppSymbol.curlybraces)
                .font(.system(size: 50))
                .foregroundColor(theme.textFaint)
            Text(NSLocalizedString("아직 빈칸이 없어요", comment: "No placeholders yet"))
                .font(.headline)
                .foregroundColor(theme.textMuted)
            Text(NSLocalizedString("내용에 { }로 감싼 자리를 넣으면 여기 모여요. 이름이 같으면 여러 단축어가 값을 함께 씁니다.",
                                   comment: "No placeholders description"))
                .font(.body)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List {
            Section {
                ForEach(summaries) { summary in
                    NavigationLink {
                        PlaceholderDetailView(summary: summary, allMemos: allMemos, onChange: reload)
                    } label: {
                        row(summary)
                    }
                }
            } footer: {
                Text(NSLocalizedString("빈칸은 이름으로 묶여요. 여러 단축어에서 같은 이름을 쓰면 값도 함께 씁니다.",
                                       comment: "Placeholder management footer"))
            }
        }
    }

    private func row(_ summary: PlaceholderSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(summary.displayName)
                    .font(.headline)
                    .foregroundColor(theme.text)

                // ⚠️ 두 갈래를 **색으로** 가른다. 숫자 칸은 값을 저장하지 않아서
                //    아래에 보이는 것이 아예 다르다.
                Text(summary.isNumeric
                     ? NSLocalizedString("숫자 입력", comment: "Numeric placeholder badge")
                     : NSLocalizedString("선택지", comment: "Selection placeholder badge"))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(summary.isNumeric ? .accentColor : .indigo)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((summary.isNumeric ? Color.accentColor : Color.indigo).opacity(0.12))
                    .cornerRadius(theme.radiusXs)
            }

            Text(subtitle(summary))
                .font(.caption)
                .foregroundColor(summary.isOrphan ? .orange : theme.textMuted)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func subtitle(_ summary: PlaceholderSummary) -> String {
        if summary.isOrphan {
            return String(format: NSLocalizedString("쓰는 단축어 없음, 값 %d개",
                                                    comment: "Orphan placeholder subtitle"),
                          summary.valueCount)
        }
        if summary.isNumeric {
            return String(format: NSLocalizedString("단축어 %d곳에서 씀",
                                                    comment: "Placeholder usage subtitle (numeric)"),
                          summary.memos.count)
        }
        return String(format: NSLocalizedString("단축어 %1$d곳에서 씀, 값 %2$d개",
                                                comment: "Placeholder usage subtitle"),
                      summary.memos.count, summary.valueCount)
    }

    private func reload() {
        summaries = PlaceholderCatalog.summaries(from: allMemos)
    }
}

// MARK: - 빈칸 하나

/// 빈칸 하나에 딸린 것 전부 - 저장해 둔 값과, 이 빈칸을 쓰는 단축어들.
struct PlaceholderDetailView: View {
    let summary: PlaceholderSummary
    let allMemos: [Memo]
    /// 값을 고치면 앞 화면의 개수도 다시 세게 한다.
    var onChange: () -> Void = {}

    @Environment(\.appTheme) private var theme
    @State private var values: [PlaceholderValue] = []
    @State private var newValue: String = ""
    @State private var pendingDelete: PlaceholderValue?
    @State private var showDeleteAlert = false

    var body: some View {
        List {
            if summary.isNumeric {
                Section {
                    Text(NSLocalizedString("금액이나 수량처럼 매번 달라지는 값은 저장하지 않아요. 쓸 때 숫자판이 열립니다.",
                                           comment: "Numeric placeholder explanation"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
            } else {
                valuesSection
            }

            usageSection
        }
        .navigationTitle(summary.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .solidNavBar(theme.bg)
        .onAppear { values = MemoStore.shared.loadPlaceholderValues(for: summary.token) }
        .alert(NSLocalizedString("삭제 확인", comment: "Delete confirmation"), isPresented: $showDeleteAlert) {
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { pendingDelete = nil }
            Button(NSLocalizedString("삭제", comment: "Delete"), role: .destructive) {
                if let v = pendingDelete {
                    MemoStore.shared.deletePlaceholderValue(valueId: v.id, for: summary.token)
                    values = MemoStore.shared.loadPlaceholderValues(for: summary.token)
                    onChange()
                }
                pendingDelete = nil
            }
        } message: {
            if let v = pendingDelete {
                Text(String(format: NSLocalizedString("'%@'을(를) 삭제하시겠습니까?", comment: "Delete value confirmation"), v.value))
            }
        }
    }

    private var valuesSection: some View {
        Section {
            ForEach(values) { value in
                VStack(alignment: .leading, spacing: 2) {
                    Text(value.value)
                        .font(.body)
                        .foregroundColor(theme.text)
                    if !value.sourceMemoTitle.isEmpty {
                        Text(String(format: NSLocalizedString("%@에서 넣음", comment: "Value source memo"),
                                    value.sourceMemoTitle))
                            .font(.caption)
                            .foregroundColor(theme.textFaint)
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        pendingDelete = value
                        showDeleteAlert = true
                    } label: {
                        Label(NSLocalizedString("삭제", comment: "Delete"), systemImage: AppSymbol.trash)
                    }
                }
            }

            HStack {
                TextField(NSLocalizedString("값 추가", comment: "Add placeholder value"), text: $newValue)
                    .onSubmit(addValue)
                Button(action: addValue) {
                    Image(systemName: AppSymbol.plusCircleFill)
                        .foregroundColor(newValue.trimmingCharacters(in: .whitespaces).isEmpty
                                         ? theme.textFaint : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(newValue.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel(NSLocalizedString("값 추가", comment: "Add placeholder value"))
            }
        } header: {
            Text(NSLocalizedString("저장해 둔 값", comment: "Saved values section"))
        } footer: {
            Text(NSLocalizedString("이 값들은 이 빈칸을 쓰는 모든 단축어에서 함께 보여요.",
                                   comment: "Saved values footer"))
        }
    }

    private var usageSection: some View {
        Section {
            if summary.memos.isEmpty {
                Text(NSLocalizedString("이 빈칸을 쓰는 단축어가 없어요. 값만 남아 있습니다.",
                                       comment: "Orphan placeholder detail"))
                    .font(.body)
                    .foregroundColor(.orange)
            } else {
                ForEach(summary.memos) { reference in
                    if let memo = allMemos.first(where: { $0.id == reference.id }) {
                        NavigationLink {
                            TemplateDetailPlaceholderView(template: memo)
                        } label: {
                            Text(memo.title.templateAwareAttributed(theme: theme, font: .body))
                        }
                    } else {
                        Text(reference.title)
                    }
                }
            }
        } header: {
            Text(NSLocalizedString("이 빈칸을 쓰는 단축어", comment: "Placeholder usage section"))
        }
    }

    private func addValue() {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // 관리 화면에서 직접 넣은 값이라 출처가 될 단축어가 없다. 쓰는 곳이 있으면 그중 첫째를
        // 출처로 적고, 없으면 이 화면에서 넣었다고 남긴다.
        let source = summary.memos.first
        MemoStore.shared.addPlaceholderValue(
            trimmed,
            for: summary.token,
            sourceMemoId: source?.id ?? UUID(),
            sourceMemoTitle: source?.title ?? NSLocalizedString("빈칸 관리", comment: "Placeholder management title (by name)")
        )
        values = MemoStore.shared.loadPlaceholderValues(for: summary.token)
        newValue = ""
        onChange()
    }
}
