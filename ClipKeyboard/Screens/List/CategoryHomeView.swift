//
//  CategoryHomeView.swift
//  ClipKeyboard
//
//  카테고리 홈 - 모든 카테고리를 한 화면에 늘어놓고, 누르면 그 카테고리로 한 단계 들어간다.
//
//  왜: 사용자 피드백(2026-11, 중국어).
//  > 좌우로 넘기다 보면 원하는 게 어디 있는지 못 찾는다. 개인 · 업무 · 생활 같은 분류를
//  > 목록 화면에 바로 보여 주고, 누르면 그 분류의 문구가 나오게 해 달라.
//  예전 목록은 카테고리마다 한 장씩 옆으로 넘기는 페이저였고, 몇 장이 있는지 · 지금 어디인지
//  알려 주는 것이 제목 한 줄뿐이었다. 이 화면이 그 지도다.
//

import SwiftUI
import LeeoKit

struct CategoryHomeView<Header: View>: View {
    let tabs: [CategoryTab]
    let customCategories: [String]
    let memos: (CategoryTab) -> [Memo]
    let onOpen: (CategoryTab) -> Void
    let onAddCategory: () -> Void
    @ViewBuilder let header: () -> Header

    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Layout

    /// 위의 작은 칸(최근 · 즐겨찾기)과 아래의 큰 칸(나머지)을 가른다.
    private var pinnedTabs: [CategoryTab] { tabs.filter { $0 == .recent || $0 == .favorites } }
    private var folderTabs: [CategoryTab] { tabs.filter { $0 != .recent && $0 != .favorites } }

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header()

                if !pinnedTabs.isEmpty {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(pinnedTabs, id: \.self) { pinnedTile($0) }
                    }
                    .padding(.horizontal, 16)
                }

                Text(NSLocalizedString("카테고리", comment: "Category home: section title"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.text)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .accessibilityAddTraits(.isHeader)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(folderTabs, id: \.self) { folderTile($0) }
                    addTile
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 110)
        }
        .scrollEdgeEffectHidden(true, for: .all)
        .contentMargins(.top, 8, for: .scrollContent)
    }

    // MARK: - Tiles

    private func pinnedTile(_ tab: CategoryTab) -> some View {
        let style = Self.style(for: tab, in: customCategories)
        let count = tab == .recent ? nil : memos(tab).count
        return Button { open(tab) } label: {
            HStack(spacing: 10) {
                badge(style, size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tab.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.text)
                    if let count {
                        Text(countText(count))
                            .font(.footnote)
                            .foregroundStyle(theme.textMuted)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func folderTile(_ tab: CategoryTab) -> some View {
        let style = Self.style(for: tab, in: customCategories)
        let list = memos(tab)
        let preview = list.prefix(2).map(\.title).joined(separator: "\n")
        return Button { open(tab) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    badge(style, size: 34)
                    Spacer(minLength: 4)
                    Text("\(list.count)")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(theme.text)
                }
                Text(tab.displayName)
                    .font(.headline)
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(theme.textMuted)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tab.displayName), \(countText(list.count))")
    }

    private var addTile: some View {
        Button {
            HapticManager.shared.light()
            onAddCategory()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: AppSymbol.plus)
                    .font(.title3.weight(.semibold))
                Text(NSLocalizedString("새 카테고리", comment: "Category home: add category tile"))
                    .font(.subheadline)
            }
            .foregroundStyle(theme.textMuted)
            .frame(maxWidth: .infinity, minHeight: 118)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(theme.textFaint, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func badge(_ style: TileStyle, size: CGFloat) -> some View {
        Image(systemName: style.symbol)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(style.tint, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }

    // MARK: - Helpers

    private func open(_ tab: CategoryTab) {
        HapticManager.shared.selection()
        onOpen(tab)
    }

    private func countText(_ count: Int) -> String {
        String(format: NSLocalizedString("%d개", comment: "Item count"), count)
    }

    struct TileStyle {
        let tint: Color
        let symbol: String
    }

    /// 칸의 색과 그림. 사용자 카테고리는 카드 · 메뉴 · 키보드와 같은 규칙(`categoryTint` · `categorySymbol`)을 쓴다.
    static func style(for tab: CategoryTab, in customCategories: [String]) -> TileStyle {
        switch tab {
        case .recent:          return TileStyle(tint: .gray, symbol: AppSymbol.clock)
        case .favorites:       return TileStyle(tint: .orange, symbol: AppSymbol.starFill)
        case .basic, .all:     return TileStyle(tint: .gray, symbol: AppSymbol.folder)
        case .builtIn(let b):  return TileStyle(tint: b.tint, symbol: b.icon)
        case .custom(let name):
            return TileStyle(tint: categoryTint(for: name, in: customCategories),
                             symbol: categorySymbol(for: name, in: customCategories))
        }
    }
}
