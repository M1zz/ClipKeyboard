//
//  ShortcutMartView.swift
//  ClipKeyboard
//
//  **단축어 마트** — 남이 차려 둔 단축어를 둘러보고, 빈칸만 내 것으로 채워 가져간다.
//
//  왜 필요한가: 빈 화면 앞에서 "뭘 만들지"부터 떠올려야 하는 것이 이 앱의 가장 큰 문턱이다.
//  쓸 만한 문장은 이미 52개나 갖고 있으면서(활용 사례), 그건 **읽는 자료**로만 있었다.
//  읽고 나서 직접 옮겨 적어야 했으니 결국 처음부터 만드는 것과 다르지 않았다.
//
//  ⚠️ `StarterPackView`와 겹치지 않는다. 저쪽은 **처음 한 번** 여러 개를 통째로 담는 곳이고
//     (빈칸은 채우지 않은 채 들어간다), 여기는 **언제든 들어와 하나를 골라 채워 가는** 곳이다.
//     같은 시나리오 데이터를 보지만 하는 일이 다르다.
//
//  ⚠️ 시나리오 데이터(`usageCategories`)를 여기서 복제하지 않는다. 문구가 두 벌이 되면
//     한쪽만 고쳐지는 날이 반드시 온다.
//

import SwiftUI
import LeeoKit

/// 마트 진열대에 놓인 것 하나.
struct ShortcutMartItem: Identifiable {
    let id = UUID()
    let emoji: String
    let categoryTitle: String
    let title: String
    /// 저장될 본문 — `{변수}`가 그대로 들어 있다.
    let example: String
    let feature: ScenarioFeature

    /// 채울 빈칸들 (`{이름}`처럼 중괄호를 포함한 토큰).
    /// 날짜·시간 같은 자동 변수는 채울 것이 없으니 빠진다.
    var blanks: [String] { TemplateVariableProcessor.extractCustomTokens(in: example) }
}

struct ShortcutMartView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    /// 담은 뒤 알린다(개수). 목록이 토스트·갱신에 쓴다.
    var onAdded: (Int) -> Void = { _ in }

    /// 내 페르소나에 맞는 것만 볼지. 기본은 **맞는 것만** —
    /// 52개를 통째로 늘어놓으면 고르는 일이 또 하나의 숙제가 된다.
    @State private var onlyMine = true
    @State private var query = ""
    @State private var picked: ShortcutMartItem?
    @State private var addedCount = 0

    private var persona: Persona? { CategoryStore.shared.selectedPersona }

    var body: some View {
        NavigationStack {
            List {
                if visibleCategories.isEmpty {
                    emptySection
                }
                ForEach(visibleCategories, id: \.title) { group in
                    Section {
                        ForEach(group.items) { item in
                            row(item)
                        }
                    } header: {
                        Text("\(group.emoji) \(group.title)")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query,
                        prompt: NSLocalizedString("어떤 상황인가요?", comment: "Shortcut mart search prompt"))
            .navigationTitle(NSLocalizedString("단축어 마트", comment: "Shortcut mart screen title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .solidNavBar(theme.bg)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("닫기", comment: "Close")) { dismiss() }
                }
                ToolbarItem(placement: .principal) { EmptyView() }
            }
            .safeAreaInset(edge: .top) { personaFilterBar }
            .sheet(item: $picked) { item in
                ShortcutMartFillView(item: item) {
                    addedCount += 1
                    onAdded(addedCount)
                }
            }
        }
    }

    // MARK: - 진열대

    /// 페르소나 띠 — 지금 무엇을 기준으로 걸러 보고 있는지 늘 보이게 한다.
    /// 검색만 있고 이 띠가 없으면 "왜 아까 본 게 안 보이지"가 된다.
    private var personaFilterBar: some View {
        HStack(spacing: 8) {
            if let persona {
                Picker("", selection: $onlyMine) {
                    Text(persona.localizedShortTitle).tag(true)
                    Text(NSLocalizedString("전체", comment: "Shortcut mart: show every scenario")).tag(false)
                }
                .pickerStyle(.segmented)
            } else {
                // 페르소나를 안 고른 사람에겐 거를 기준이 없다 — 띠 대신 안내 한 줄.
                Text(NSLocalizedString("설정에서 나에게 맞는 유형을 고르면 더 잘 맞는 것부터 보여드려요",
                                       comment: "Shortcut mart: no persona hint"))
                    .font(.caption)
                    .foregroundColor(theme.textMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    private func row(_ item: ShortcutMartItem) -> some View {
        Button {
            HapticManager.shared.light()
            picked = item
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.text)
                    featureBadge(item.feature)
                    Spacer(minLength: 0)
                    // 채울 것이 몇 개인지 — 고르기 전에 품이 얼마나 드는지 알려준다.
                    if !item.blanks.isEmpty {
                        Text(String(format: NSLocalizedString("빈칸 %d", comment: "Shortcut mart: blank count"),
                                    item.blanks.count))
                            .font(.caption.weight(.medium))
                            .foregroundColor(theme.textMuted)
                    }
                }
                Text(item.example.templateChipAttributed(theme: theme, font: .callout))
                    .font(.callout)
                    .foregroundColor(theme.textMuted)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.blanks.isEmpty
                            ? item.title
                            : String(format: NSLocalizedString("%@, 채울 빈칸 %d개", comment: "Shortcut mart row a11y"),
                                     item.title, item.blanks.count))
        .accessibilityHint(NSLocalizedString("탭하면 내용을 채워 담습니다", comment: "Shortcut mart row a11y hint"))
    }

    private func featureBadge(_ feature: ScenarioFeature) -> some View {
        Text(feature.label)
            .font(.caption2.weight(.semibold))
            .foregroundColor(feature.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(feature.color.opacity(0.15), in: Capsule())
    }

    private var emptySection: some View {
        Section {
            VStack(spacing: 8) {
                Text(NSLocalizedString("찾는 것이 없어요", comment: "Shortcut mart empty title"))
                    .font(.headline)
                Text(NSLocalizedString("전체로 바꿔서 더 둘러보거나, 직접 하나 만들어도 돼요.",
                                       comment: "Shortcut mart empty message"))
                    .font(.callout)
                    .foregroundColor(theme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    // MARK: - 무엇을 진열할까

    private struct Group {
        let emoji: String
        let title: String
        let items: [ShortcutMartItem]
    }

    /// ⚠️ 안내성 시나리오(`smartClipboard`)는 저장할 본문이 없다 — 진열대에 올리면
    ///    "이거 쓰기"를 눌러도 아무것도 안 생긴다.
    private var visibleCategories: [Group] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return usageCategories.compactMap { category in
            let items = category.scenarios
                .filter { $0.feature != .smartClipboard }
                .filter { scenario in
                    guard onlyMine, let persona else { return true }
                    // personas 가 비어 있으면 누구에게나 맞는 것 — 걸러내지 않는다.
                    return scenario.personas.isEmpty || scenario.personas.contains(persona)
                }
                .filter { scenario in
                    guard !needle.isEmpty else { return true }
                    return scenario.title.lowercased().contains(needle)
                        || scenario.example.lowercased().contains(needle)
                        || (scenario.context?.lowercased().contains(needle) ?? false)
                }
                .map {
                    ShortcutMartItem(emoji: category.emoji,
                                     categoryTitle: category.title,
                                     title: $0.title,
                                     example: $0.example,
                                     feature: $0.feature)
                }
            guard !items.isEmpty else { return nil }
            return Group(emoji: category.emoji, title: category.title, items: items)
        }
    }
}

// MARK: - 페르소나 짧은 이름

extension Persona {
    /// 세그먼트 한 칸에 들어갈 짧은 이름.
    /// ⚠️ `localizedTitle`("디지털 노마드 / 프리랜서")은 고르는 화면에서 설명하려고 긴 것이라
    ///    좁은 칸에 넣으면 말줄임으로 잘려 무엇을 고르는지 알 수 없다.
    var localizedShortTitle: String {
        switch self {
        case .nomad:    return NSLocalizedString("노마드", comment: "Persona short: nomad")
        case .business: return NSLocalizedString("직장인", comment: "Persona short: business")
        case .student:  return NSLocalizedString("학생", comment: "Persona short: student")
        case .general:  return NSLocalizedString("일반", comment: "Persona short: general")
        }
    }
}
