//
//  UsageScenarioPickerSheet.swift
//  ClipKeyboard
//

import SwiftUI

struct UsageScenarioPickerSheet: View {
    /// 선택된 시나리오 전체를 부모에게 전달. 부모는 example 본문 외에도
    /// scenario.feature를 보고 isTemplate / isCombo 토글을 함께 설정한다.
    let onSelect: (UsageScenario) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @State private var selectedCategoryId: UUID? = nil

    private var filteredCategories: [UsageCategory] {
        guard let id = selectedCategoryId else { return usageCategories }
        return usageCategories.filter { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(
                            label: NSLocalizedString("전체", comment: "All categories filter"),
                            emoji: "🌐",
                            isSelected: selectedCategoryId == nil,
                            action: { selectedCategoryId = nil }
                        )
                        ForEach(usageCategories) { category in
                            filterChip(
                                label: category.title,
                                emoji: category.emoji,
                                isSelected: selectedCategoryId == category.id,
                                action: { selectedCategoryId = category.id }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(theme.surface)

                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(filteredCategories) { category in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Text(category.emoji)
                                    Text(category.title)
                                        .font(.headline)
                                }
                                Text(category.desc)
                                    .font(.body)
                                    .foregroundColor(theme.textMuted)

                                VStack(spacing: 8) {
                                    ForEach(category.scenarios) { scenario in
                                        scenarioCard(scenario)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle(NSLocalizedString("활용사례", comment: "Usage scenarios picker title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("닫기", comment: "Close")) { dismiss() }
                }
            }
        }
    }

    private func filterChip(label: String, emoji: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(emoji)
                Text(label)
                    .font(.body.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : theme.surfaceAlt)
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func scenarioCard(_ scenario: UsageScenario) -> some View {
        Button {
            onSelect(scenario)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scenario.title)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        if let context = scenario.context {
                            Text(context)
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.caption2)
                        Text(NSLocalizedString("입력", comment: "Tap-to-insert hint"))
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                }

                Text(highlightedExample(scenario.example))
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surfaceAlt)
                    .cornerRadius(theme.radiusXs)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 1.2)
            )
            .cornerRadius(theme.radiusMd)
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func highlightedExample(_ raw: String) -> AttributedString {
        var attr = AttributedString(raw)
        attr.foregroundColor = .secondary

        let pattern = "\\[[^\\]]+\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return attr }
        let nsRange = NSRange(raw.startIndex..., in: raw)
        let matches = regex.matches(in: raw, range: nsRange)
        for match in matches.reversed() {
            guard let stringRange = Range(match.range, in: raw),
                  let attrRange = Range(stringRange, in: attr) else { continue }
            attr[attrRange].foregroundColor = .red
            attr[attrRange].font = .system(size: 12, weight: .semibold, design: .monospaced)
        }
        return attr
    }
}
