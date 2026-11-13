//
//  CategoryHomeView.swift
//  ClipKeyboard
//
//  카테고리 고르기 - 모든 카테고리를 한 화면에 늘어놓고, 누르면 그 카테고리를 보인다.
//  목록 제목 옆 아래 화살표로 여는 시트(`CategoryPickerSheet`) 안에 선다.
//  5.1.21 에서는 목록 위 단계의 홈이었다. 들어갔다 나오는 한 단계가 번거로워 시트로 내렸다.
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
    /// 지금 목록에 보이는 카테고리. 그 칸에 테두리를 둘러 어디서 왔는지 보이게 한다.
    var selected: CategoryTab? = nil
    let onOpen: (CategoryTab) -> Void
    let onAddCategory: () -> Void
    @ViewBuilder let header: () -> Header

    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// 설정 ▸ 손쉬운 사용 ▸ 색상 없이 구별. 켜져 있으면 아이콘을 안 고른 칸에도 기본 심볼을 세운다.
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    // MARK: - Layout

    /// '최근' 칸에 보일 복사 기록. 최근은 카테고리가 아니지만(카테고리 관리에는 안 나온다)
    /// 홈에서는 다른 칸과 **같은 모양**으로 선다. 칸이 두 종류면 어느 쪽이 무엇인지부터 읽어야 한다.
    @State private var recentClips: [SmartClipboardHistory] = []
    /// 칸에 안에 든 것 두 줄을 보일지 (설정 ▸ 단축어 표시).
    @AppStorage(AppPrefs.categoryTilePreview.key) private var showsPreview: Bool = AppPrefs.categoryTilePreview.fallback
    /// 칸의 최소 높이. 새 카테고리 칸도 같은 값을 써서 줄이 맞는다.
    private var tileMinHeight: CGFloat { showsPreview ? 92 : 56 }

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
                HStack(alignment: .center, spacing: 8) {
                    if let icon = tileIcon(for: tab) {
                        SnippetIconView(icon: icon, size: 24, tint: style.tint ?? theme.textMuted)
                    }
                    Text(tab.displayName)
                        .font(.headline)
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(count)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(theme.text)
                }
                if showsPreview {
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(theme.textMuted)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                        .accessibilityHidden(true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: tileMinHeight, alignment: .leading)
            // 칸은 **색으로만** 구별한다. 심볼 배지는 뺐다(사용자: 심볼이 왜 필요한지 모르겠다).
            // 흰 면 위에 카테고리 색을 옅게 얹는다 - 키보드 칸과 같은 농도라 글자가 묻히지 않는다.
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.surface)
                    .overlay {
                        if let tint = style.tint {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(tint.opacity(theme.isDark ? 0.22 : 0.14))
                        }
                    }
            }
            .overlay {
                if tab == selected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(theme.accent, lineWidth: 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(tab == selected ? .isSelected : [])
        .accessibilityLabel("\(tab.displayName), \(countText(count))")
    }

    private var addTile: some View {
        Button {
            HapticManager.shared.light()
            onAddCategory()
        } label: {
            VStack(spacing: showsPreview ? 6 : 2) {
                Image(systemName: AppSymbol.plus)
                    .font(.title3.weight(.semibold))
                Text(NSLocalizedString("새 카테고리", comment: "Category home: add category tile"))
                    .font(.subheadline)
            }
            .foregroundStyle(theme.textMuted)
            .frame(maxWidth: .infinity, minHeight: tileMinHeight)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(theme.textFaint, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    /// 칸에 세울 아이콘. 사용자가 고른 것이 있으면 늘, 없으면 '색상 없이 구별' 이 켜진 사람에게만
    /// 기본 심볼을 세운다. 칸은 색으로 구별하므로(위 주석) 색이 안 통하는 사람에게 모양을 준다.
    private func tileIcon(for tab: CategoryTab) -> SnippetIcon? {
        if case .custom(let name) = tab, let picked = customCategoryIcon(for: name) { return picked }
        guard differentiateWithoutColor else { return nil }
        switch tab {
        case .custom(let name): return .symbol(categorySymbol(for: name, in: customCategories))
        case .builtIn(let b):   return .symbol(b.icon)
        case .favorites:        return .symbol(AppSymbol.heartFill)
        case .recent:           return .symbol("clock")
        case .basic, .all:      return .symbol("tray")
        }
    }

    private func open(_ tab: CategoryTab) {
        HapticManager.shared.selection()
        onOpen(tab)
    }

    private func countText(_ count: Int) -> String {
        String(format: NSLocalizedString("%d개", comment: "Item count"), count)
    }

    struct TileStyle {
        /// nil 이면 색 없는 흰 칸이다(최근 · 기본). 회색을 얹으면 바탕과 섞여 칸이 안 보인다.
        let tint: Color?
    }

    /// 칸의 색. 사용자 카테고리는 카드 · 메뉴 · 키보드와 같은 규칙(`categoryTint`)을 쓴다.
    static func style(for tab: CategoryTab, in customCategories: [String]) -> TileStyle {
        switch tab {
        case .recent:          return TileStyle(tint: nil)
        case .favorites:       return TileStyle(tint: .orange)
        case .basic, .all:     return TileStyle(tint: nil)
        case .builtIn(let b):  return TileStyle(tint: b.tint)
        case .custom(let name):
            return TileStyle(tint: categoryTint(for: name, in: customCategories))
        }
    }
}

// MARK: - Category Picker Sheet

/// 목록 제목 옆 아래 화살표로 여는 카테고리 고르기 시트.
/// 칸을 누르면 `selectCategoryTab` 이 시트를 닫고 그 카테고리를 보인다.
/// 새 카테고리 이름 묻기도 이 시트 안에 둔다. 시트가 떠 있는 동안 목록 쪽 알림은 뜨지 않는다.
struct CategoryPickerSheet: View {
    @ObservedObject var viewModel: ClipKeyboardListViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var showAddCategoryAlert = false
    @State private var newCategoryName = ""

    var body: some View {
        NavigationStack {
            CategoryHomeView(
                tabs: viewModel.allCategoryTabs,
                customCategories: viewModel.customCategories,
                memos: { viewModel.memos(for: $0) },
                selected: viewModel.displayedCategoryTab,
                onOpen: { viewModel.selectCategoryTab($0) },
                onAddCategory: {
                    newCategoryName = ""
                    showAddCategoryAlert = true
                },
                header: { EmptyView() }
            )
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("단축어", comment: "Category home: navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    GlassCircleButton(AppSymbol.xmark, role: .secondary,
                                      label: NSLocalizedString("닫기", comment: "Close")) {
                        dismiss()
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .alert(
                NSLocalizedString("새 카테고리", comment: "Add category alert title"),
                isPresented: $showAddCategoryAlert
            ) {
                TextField(NSLocalizedString("카테고리 이름", comment: "Category name placeholder"), text: $newCategoryName)
                Button(NSLocalizedString("추가", comment: "Add")) {
                    // 만든 카테고리로 옮겨 가면서 시트도 닫힌다(`selectCategoryTab`).
                    viewModel.addCustomCategory(newCategoryName)
                    newCategoryName = ""
                }
                Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {
                    newCategoryName = ""
                }
            } message: {
                Text(NSLocalizedString("단축어를 분류할 카테고리 이름을 입력하세요.", comment: "Add category alert message"))
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
