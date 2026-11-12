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

    /// '최근' 칸에 보일 복사 기록. 최근은 카테고리가 아니지만(카테고리 관리에는 안 나온다)
    /// 홈에서는 다른 칸과 **같은 모양**으로 선다. 칸이 두 종류면 어느 쪽이 무엇인지부터 읽어야 한다.
    @State private var recentClips: [SmartClipboardHistory] = []

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header()

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(tabs, id: \.self) { folderTile($0) }
                    addTile
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 110)
        }
        .scrollEdgeEffectHidden(true, for: .all)
        .contentMargins(.top, 8, for: .scrollContent)
        .onAppear(perform: loadRecentClips)
        // 키보드에서 담은 것은 다른 프로세스가 같은 파일에 쓴다. 앱으로 돌아올 때 다시 읽는다.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            loadRecentClips()
        }
    }

    private func loadRecentClips() {
        guard tabs.contains(.recent) else { return }
        do {
            recentClips = SmartClipboardHistory.keyboardRecents(try ClipboardHistoryStore.shared.load())
        } catch {
            print("❌ [CategoryHomeView.loadRecentClips] \(error)")
        }
    }

    /// 칸에 적을 개수와 첫 두 줄. 최근은 복사 기록에서, 나머지는 단축어에서 읽는다.
    private func summary(for tab: CategoryTab) -> (count: Int, preview: String) {
        if tab == .recent {
            let lines = recentClips.prefix(2).map { clip -> String in
                let text = clip.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")
                // 카드번호 · 계좌처럼 남이 보면 곤란한 것은 끝 네 자리만 (최근 화면과 같은 규칙).
                guard (clip.userCorrectedType ?? clip.detectedType).isSensitive else { return text }
                return "\u{2022}\u{2022}\u{2022}\u{2022} " + text.filter { !$0.isWhitespace }.suffix(4)
            }
            return (recentClips.count, lines.joined(separator: "\n"))
        }
        let list = memos(tab)
        return (list.count, list.prefix(2).map(\.title).joined(separator: "\n"))
    }

    // MARK: - Tiles

    private func folderTile(_ tab: CategoryTab) -> some View {
        let style = Self.style(for: tab, in: customCategories)
        let (count, preview) = summary(for: tab)
        return Button { open(tab) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    badge(style, size: 34)
                    Spacer(minLength: 4)
                    Text("\(count)")
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
        .accessibilityLabel("\(tab.displayName), \(countText(count))")
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
