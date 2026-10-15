//
//  FoldNavigation.swift
//  ClipKeyboard
//
//  펼친 아이폰 듀오의 **목록 | 자세히**. 목록에서 고르면 들어가던 화면이 옆(세로면 위)에 열린다.
//
//  접혀 있으면 지금처럼 `NavigationStack` 하나이고, `FoldLink` 는 `NavigationLink` 와 똑같이 민다.
//  펴면 화면을 쌓은 줄(`FoldColumns`)의 **마지막 두 장**이 두 판에 선다.
//
//    [설정]                 → 고르는 쪽: 설정        결과 쪽: (고르면 여기에 열려요)
//    [설정, 키보드]           → 고르는 쪽: 설정        결과 쪽: 키보드
//    [설정, 키보드, 레이아웃]   → 고르는 쪽: 키보드      결과 쪽: 레이아웃   (한 칸 밀림, 고르는 쪽에 뒤로)
//
//  고르는 쪽에서 다른 줄을 고르면 결과 쪽만 바뀐다. 결과 쪽에서 고르면 한 칸 밀린다.
//  그래서 어느 깊이에서든 "지금 고르는 목록"과 "고른 것"이 접힌 선을 사이에 두고 마주 본다.
//
//  ⚠️ 시스템 `NavigationSplitView` 를 쓰지 않는다. 세로에서는 목록을 결과 위에 덮어 띄우고(실측),
//     가로에서는 두 단의 경계에 구분선을 그어 접힌 선 위에 선이 하나 더 선다.
//  ⚠️ 펴고 접는 순간 들어가 있던 자리는 처음으로 돌아간다(틀이 바뀐다).
//

import SwiftUI

// MARK: - 쌓은 화면

@MainActor
final class FoldColumns: ObservableObject {
    struct Page: Identifiable {
        let id = UUID()
        /// 이 화면을 연 `FoldLink`. 그 줄을 고른 표시로 쓴다.
        let sourceID: UUID
        let view: AnyView
        /// 이 화면이 결과 쪽에 세우고 싶은 짝(미리보기). 있으면 이 화면이 고르는 쪽으로 옮겨 간다.
        var companion: AnyView?
    }

    /// 뿌리 다음부터. 뿌리(목록)는 `FoldNavigation` 이 들고 있다.
    @Published private(set) var pages: [Page] = []

    /// `index` 번째 장(0 = 뿌리)에서 고른 화면을 그 바로 다음 장으로 연다. 더 깊던 장은 버린다.
    func open(_ view: AnyView, companion: AnyView? = nil, from index: Int, sourceID: UUID) {
        let keep = max(0, min(index, pages.count))
        if keep < pages.count, pages[keep].sourceID == sourceID { return }   // 이미 열려 있다
        pages = Array(pages.prefix(keep)) + [Page(sourceID: sourceID, view: view, companion: companion)]
    }

    func goBack() {
        guard !pages.isEmpty else { return }
        pages.removeLast()
    }

    func reset() { pages = [] }

    #if DEBUG
    // MARK: 개발용 - 명령줄 시뮬레이터에서 줄을 고른 상태로 띄운다(`-FoldPreviewPath 3,0`)

    /// 장마다 나타난 줄을 나타난 차례대로.
    private var debugLinks: [Int: [(id: UUID, open: () -> (view: AnyView, companion: AnyView?))]] = [:]

    func debugRegister(index: Int, id: UUID, open: @escaping () -> (view: AnyView, companion: AnyView?)) {
        var list = debugLinks[index, default: []]
        guard !list.contains(where: { $0.id == id }) else { return }
        list.append((id, open))
        debugLinks[index] = list
    }

    func debugFollowPath() {
        guard let raw = UserDefaults.standard.string(forKey: "FoldPreviewPath") else { return }
        let steps = raw.split(separator: ",").compactMap { Int($0) }
        func step(_ depth: Int) {
            guard depth < steps.count else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let self, let links = self.debugLinks[depth], steps[depth] < links.count else { return }
                let link = links[steps[depth]]
                let opened = link.open()
                self.open(opened.view, companion: opened.companion, from: depth, sourceID: link.id)
                step(depth + 1)
            }
        }
        step(0)
    }
    #endif

    /// `index` 번째 장에서 지금 열린(그 다음 장을 연) 줄.
    func openedSource(after index: Int) -> UUID? {
        index < pages.count ? pages[index].sourceID : nil
    }
}

private struct FoldColumnsKey: EnvironmentKey {
    static let defaultValue: FoldColumns? = nil
}

private struct FoldColumnIndexKey: EnvironmentKey {
    static let defaultValue = 0
}

private struct FoldShowsCompanionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// 펼친 `FoldNavigation` 안이면 쌓은 화면 줄. 접혀 있거나 바깥이면 nil.
    var foldColumns: FoldColumns? {
        get { self[FoldColumnsKey.self] }
        set { self[FoldColumnsKey.self] = newValue }
    }

    /// 이 화면의 짝(미리보기)이 지금 결과 쪽에 서 있는가. 그러면 화면 안의 미리보기는 숨긴다.
    var foldShowsCompanion: Bool {
        get { self[FoldShowsCompanionKey.self] }
        set { self[FoldShowsCompanionKey.self] = newValue }
    }

    /// 이 화면이 줄의 몇 번째 장인가(0 = 뿌리).
    var foldColumnIndex: Int {
        get { self[FoldColumnIndexKey.self] }
        set { self[FoldColumnIndexKey.self] = newValue }
    }
}

// MARK: - 틀

struct FoldNavigation<Root: View, Idle: View>: View {
    @Environment(\.foldLayout) private var fold
    @StateObject private var columns = FoldColumns()
    private let root: Root
    private let idle: Idle

    /// - Parameter idle: 펼쳤는데 아직 아무것도 고르지 않았을 때 결과 쪽에 설 것.
    init(@ViewBuilder root: () -> Root, @ViewBuilder idle: () -> Idle) {
        self.root = root()
        self.idle = idle()
    }

    var body: some View {
        if fold.isUnfolded {
            FoldSplitView {
                column(at: chooseIndex)
            } result: {
                if let companion = columns.pages.last?.companion {
                    companion
                        .id(columns.pages.last?.id)
                } else if columns.pages.isEmpty {
                    idle
                } else {
                    column(at: columns.pages.count)
                }
            }
            .onChange(of: fold.posture) { _, _ in columns.reset() }
            #if DEBUG
            .onAppear { columns.debugFollowPath() }
            #endif
        } else {
            NavigationStack { root }
                .onAppear { columns.reset() }
        }
    }

    /// 고르는 쪽에 설 장. 결과 쪽 바로 앞 장이다.
    /// 마지막 장이 짝(미리보기)을 가졌으면 그 장이 고르는 쪽으로 오고, 짝이 결과 쪽에 선다.
    private var chooseIndex: Int {
        if columns.pages.last?.companion != nil { return columns.pages.count }
        return max(0, columns.pages.count - 1)
    }

    @ViewBuilder
    private func column(at index: Int) -> some View {
        NavigationStack {
            page(at: index)
                .environment(\.foldColumns, columns)
                .environment(\.foldColumnIndex, index)
                .environment(\.foldShowsCompanion,
                             index == columns.pages.count && columns.pages.last?.companion != nil)
                .toolbar {
                    // 고르는 쪽이 뿌리가 아니면 한 칸 되돌아갈 길이 있어야 한다.
                    if index > 0 && index == chooseIndex {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { columns.goBack() }
                            } label: {
                                Image(systemName: AppSymbol.chevronBackward)
                            }
                            .accessibilityLabel(NSLocalizedString("뒤로", comment: "Back button"))
                        }
                    }
                }
        }
        .id(index == 0 ? nil : columns.pages[index - 1].id)
    }

    @ViewBuilder
    private func page(at index: Int) -> some View {
        if index == 0 {
            root
        } else {
            columns.pages[index - 1].view
        }
    }
}

extension FoldNavigation where Idle == FoldDetailPlaceholder {
    init(@ViewBuilder root: () -> Root) {
        self.init(root: root, idle: { FoldDetailPlaceholder() })
    }
}

/// 아직 아무것도 고르지 않은 결과 쪽. 말수를 아낀다.
struct FoldDetailPlaceholder: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        Text(NSLocalizedString("고르면 여기에 열려요", comment: "Fold detail pane: nothing selected yet"))
            .font(.body)
            .foregroundColor(theme.textMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.bg.ignoresSafeArea())
    }
}

// MARK: - 줄

/// `NavigationLink` 대신 쓴다. 접혀 있으면 똑같이 밀고, 펼친 `FoldNavigation` 안이면 옆 판에 연다.
struct FoldLink<Label: View, Destination: View>: View {
    @Environment(\.foldColumns) private var columns
    @Environment(\.foldColumnIndex) private var index
    @State private var linkID = UUID()

    private let destination: () -> Destination
    private let label: Label

    init(destination: Destination, @ViewBuilder label: () -> Label) {
        self.destination = { destination }
        self.label = label()
    }

    init(@ViewBuilder destination: @escaping () -> Destination, @ViewBuilder label: () -> Label) {
        self.destination = destination
        self.label = label()
    }

    var body: some View {
        if let columns {
            let isOpen = columns.openedSource(after: index) == linkID
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    let opened = Self.make(destination())
                    columns.open(opened.view, companion: opened.companion, from: index, sourceID: linkID)
                }
            } label: {
                HStack {
                    label
                    Spacer(minLength: 8)
                    Image(systemName: AppSymbol.chevronRight)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(isOpen ? Color.accentColor.opacity(0.14) : nil)
            #if DEBUG
            .onAppear { columns.debugRegister(index: index, id: linkID) { Self.make(destination()) } }
            #endif
            .accessibilityAddTraits(isOpen ? .isSelected : [])
        } else {
            NavigationLink(destination: destination, label: { label })
        }
    }

    /// 화면과, 그 화면이 짝을 가졌으면 짝도.
    private static func make(_ page: Destination) -> (view: AnyView, companion: AnyView?) {
        let companion = (page as? any FoldCompanionProviding).map { AnyView($0.foldCompanionView) }
        return (AnyView(page), companion)
    }
}

// MARK: - 짝(미리보기)

/// 펼친 화면에서 **결과 쪽 판 전체**에 미리보기를 세우고 싶은 화면이 따른다(손잡이 | 미리보기).
///
/// 이 화면을 `FoldLink` 로 열면 이 화면이 고르는 쪽에, `foldCompanion` 이 결과 쪽에 선다.
/// 화면 안에 원래 있던 작은 미리보기는 `foldShowsCompanion` 이 true 일 때 숨긴다.
/// ⚠️ 짝은 화면의 `@State` 를 볼 수 없다. 설정 값(`@AppStorage` · 공용 객체)을 스스로 읽어야
///    손잡이를 움직일 때 함께 바뀐다.
@MainActor
protocol FoldCompanionProviding {
    associatedtype Companion: View
    @ViewBuilder var foldCompanion: Companion { get }
}

extension FoldCompanionProviding {
    var foldCompanionView: AnyView { AnyView(foldCompanion) }
}

/// 짝 판의 공용 틀. 머리말 하나와 판을 채우는 내용.
struct FoldCompanionPane<Content: View>: View {
    @Environment(\.appTheme) private var theme
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundColor(theme.textMuted)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.surfaceAlt.opacity(0.45).ignoresSafeArea())
    }
}
