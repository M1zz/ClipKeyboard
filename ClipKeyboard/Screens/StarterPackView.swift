//
//  StarterPackView.swift
//  ClipKeyboard
//
//  "내가 이걸로 이런 걸 할 수 있겠다"를 한 번에 체험시키는 스타터팩.
//  선택된 페르소나에 맞는 바로 쓸 수 있는 메모를 체크해서 일괄 추가한다.
//  활용 사례(UsageGuideView)의 시나리오 데이터를 재사용.
//

import SwiftUI

/// 스타터팩에 담길 한 항목 (활용 시나리오 1개).
struct StarterPackItem: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let example: String
    let feature: ScenarioFeature
}

struct StarterPackView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    /// 추가 완료 콜백 (추가된 개수). 표시 측에서 토스트/리프레시에 사용.
    var onComplete: (Int) -> Void

    private let items: [StarterPackItem]
    @State private var selected: Set<UUID>

    init(onComplete: @escaping (Int) -> Void = { _ in }) {
        self.onComplete = onComplete

        // 선택된 페르소나에 맞는 시나리오만 모아 스타터팩 구성.
        // 안내성(smartClipboard) 시나리오는 저장 대상이 아니므로 제외.
        let persona = CategoryStore.shared.selectedPersona
        var built: [StarterPackItem] = []
        for category in usageCategories {
            for sc in category.scenarios where sc.feature != .smartClipboard {
                let matches = persona == nil || sc.personas.isEmpty || sc.personas.contains(persona!)
                if matches {
                    built.append(StarterPackItem(
                        emoji: category.emoji,
                        title: sc.title,
                        example: sc.example,
                        feature: sc.feature
                    ))
                }
            }
        }
        let trimmed = Array(built.prefix(12))
        self.items = trimmed
        // 기본으로 상위 5개를 미리 선택해 둔다 (한 탭으로 바로 추가 가능).
        _selected = State(initialValue: Set(trimmed.prefix(5).map { $0.id }))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    ForEach(items) { item in
                        row(item)
                    }
                    Spacer(minLength: 90)
                }
                .padding(16)
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("스타터팩", comment: "Starter pack screen title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .solidNavBar(theme.bg)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("취소", comment: "Cancel")) { dismiss() }
                }
                #endif
            }
            .safeAreaInset(edge: .bottom) {
                addButton
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("바로 쓸 수 있는 메모", comment: "Starter pack header"))
                .font(.system(.title2, weight: .bold))
                .foregroundColor(theme.text)
            Text(NSLocalizedString("골라서 한 번에 추가하세요. 키보드에서 바로 꺼내 쓸 수 있어요.", comment: "Starter pack subtitle"))
                .font(.body)
                .foregroundColor(theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
    }

    private func row(_ item: StarterPackItem) -> some View {
        let isOn = selected.contains(item.id)
        return Button {
            HapticManager.shared.light()
            if isOn { selected.remove(item.id) } else { selected.insert(item.id) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(item.emoji)
                    .font(.system(.title3))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.body.weight(.semibold))
                            .foregroundColor(theme.text)
                            .lineLimit(1)
                        featureBadge(item.feature)
                        Spacer(minLength: 0)
                    }
                    Text(item.example.templateChipAttributed(theme: theme))
                        .font(.callout)
                        .foregroundColor(theme.textMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(.title3))
                    .foregroundColor(isOn ? .blue : theme.textFaint)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                    .stroke(isOn ? Color.blue.opacity(0.5) : theme.divider, lineWidth: isOn ? 1.5 : 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(item.title)
        .accessibilityHint(NSLocalizedString("탭하면 스타터팩에 추가/제외", comment: "VoiceOver: toggle starter pack item"))
    }

    private func featureBadge(_ feature: ScenarioFeature) -> some View {
        Text(feature.label)
            .font(.system(.caption2, weight: .semibold))
            .foregroundColor(feature.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(feature.color.opacity(0.12))
            .clipShape(Capsule())
            .accessibilityHidden(true)
    }

    private var addButton: some View {
        let count = selected.count
        return Button(action: addSelected) {
            Text(count > 0
                 ? String(format: NSLocalizedString("선택한 %d개 추가하기", comment: "Starter pack add button (count)"), count)
                 : NSLocalizedString("항목을 골라주세요", comment: "Starter pack add button (none selected)"))
                .font(.body.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(count > 0 ? Color.blue : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(count == 0)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .padding(.top, 8)
        .background(.regularMaterial)
    }

    // MARK: - Action

    private func addSelected() {
        let chosen = items.filter { selected.contains($0.id) }
        guard !chosen.isEmpty else { dismiss(); return }

        do {
            var memos = try MemoStore.shared.load(type: .memo)
            for item in chosen {
                // {플레이스홀더}가 있으면 템플릿으로 — 탭하면 값 채우기 UX.
                let isTemplate = item.example.contains("{")
                let vars = isTemplate ? item.example.extractTemplatePlaceholders() : []
                let memo = Memo(
                    title: item.title,
                    value: item.example,
                    isTemplate: isTemplate,
                    templateVariables: vars
                )
                memos.insert(memo, at: 0)
            }
            try MemoStore.shared.save(memos: memos, type: .memo)
            // 리스트가 .demoSamplesInserted를 관찰해 자동 갱신.
            NotificationCenter.default.post(name: .demoSamplesInserted, object: nil)
            #if os(iOS)
            HapticManager.shared.success()
            #endif
            print("✅ [StarterPack] \(chosen.count)개 메모 추가 완료")
            onComplete(chosen.count)
        } catch {
            print("❌ [StarterPack] 저장 실패: \(error)")
        }
        dismiss()
    }
}

#if DEBUG
struct StarterPackView_Previews: PreviewProvider {
    static var previews: some View {
        StarterPackView()
    }
}
#endif
