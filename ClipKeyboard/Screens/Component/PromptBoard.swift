//
//  PromptBoard.swift
//  ClipKeyboard
//
//  **띠들이 말할 거리를 올려 두는 게시판.** 고르는 일은 `PromptArbiter` 가 하고,
//  여기는 누가 손을 들었는지 모으고 고른 결과를 띠들에게 돌려준다.
//
//  왜 게시판인가: 띠마다 보일지 말지를 정하는 판단이 컨테이너 안에 있다(비동기로 세는 것,
//  닫은 기록, TipKit 상태). 그걸 목록 화면으로 끌어올려 다시 계산하면 두 곳이 어긋난다.
//  그래서 판단은 그 자리에 두고, **"말할 거리가 있다" 는 사실만** 여기에 올린다.
//
//  ```swift
//  PromptRow(.bulkImport, wants: BulkImportNudge.shouldOfferInList(...)) {
//      BulkImportNudgeBanner(...)
//  }
//  ```
//
//  자세한 설계: docs/design/PROGRESSIVE_DISCLOSURE.md 4절
//

import SwiftUI

// MARK: - 목록 위의 말들

extension PromptCandidate {
    // 상태 띠 - 고장 난 것. 이용 기간이 끝나는 것이 먼저다(곧 사라지는 말이다).
    static let accessEnding = PromptCandidate(id: "accessEnding", slot: .statusBand, kind: .status)
    static let keyboardSetup = PromptCandidate(id: "keyboardSetup", slot: .statusBand, kind: .status,
                                               surface: .keyboardSetupBanner)

    // 지금 카드 - 방금 한 일에 대한 답.
    // ⚠️ 층에 걸지 않는다. 아직 자기 단축어가 없는 사람에게는 이 카드가 첫 단축어를 만드는 길이다.
    static let freshClipboard = PromptCandidate(id: "freshClipboard", slot: .momentCard, kind: .moment)
    static let quickNoteInbox = PromptCandidate(id: "quickNoteInbox", slot: .momentCard, kind: .moment)

    // 제안 카드
    static let personaEssentials = PromptCandidate(id: "personaEssentials", slot: .suggestionCard, kind: .unblock)
    static let pasteTip = PromptCandidate(id: "pasteTip", slot: .suggestionCard, kind: .nextFloor)
    static let bulkImport = PromptCandidate(id: "bulkImport", slot: .suggestionCard, kind: .nextFloor,
                                            surface: .bulkImport)
    static let categoryActivation = PromptCandidate(id: "categoryActivation", slot: .suggestionCard, kind: .nextFloor,
                                                    surface: .categories)
    static let personaCategoryTip = PromptCandidate(id: "personaCategoryTip", slot: .suggestionCard, kind: .nextFloor,
                                                    surface: .categories)
    static let categorySuggestionTip = PromptCandidate(id: "categorySuggestionTip", slot: .suggestionCard, kind: .nextFloor,
                                                       surface: .categories)
    static let freeUseMilestone = PromptCandidate(id: "freeUseMilestone", slot: .suggestionCard, kind: .money)
    static let proValue = PromptCandidate(id: "proValue", slot: .suggestionCard, kind: .money)
    static let tipAsk = PromptCandidate(id: "tipAsk", slot: .suggestionCard, kind: .ask)

    /// 같은 종류 안의 차례. **이 배열 순서가 곧 차례다.**
    static let listOrder: [PromptCandidate] = [
        .accessEnding, .keyboardSetup,
        .freshClipboard, .quickNoteInbox,
        .personaEssentials,
        .pasteTip, .bulkImport, .categoryActivation, .personaCategoryTip, .categorySuggestionTip,
        .freeUseMilestone, .proValue,
        .tipAsk,
    ]
}

// MARK: - 게시판

@MainActor
final class PromptBoard: ObservableObject {
    static let list = PromptBoard(order: PromptCandidate.listOrder)

    /// 자리마다 고른 말.
    @Published private(set) var picked: [PromptSlot: PromptCandidate] = [:]

    private let order: [PromptCandidate]
    /// 말할 거리가 있다고 손을 든 자리들. 같은 말을 여러 페이지가 올리므로 표(token)로 센다.
    private var raised: [String: Set<UUID>] = [:]

    init(order: [PromptCandidate]) {
        self.order = order
    }

    func isPicked(_ candidate: PromptCandidate) -> Bool {
        picked[candidate.slot]?.id == candidate.id
    }

    /// 손을 들거나 내린다.
    func set(_ candidate: PromptCandidate, wants: Bool, token: UUID) {
        var tokens = raised[candidate.id, default: []]
        let changed = wants ? tokens.insert(token).inserted : tokens.remove(token) != nil
        raised[candidate.id] = tokens
        if changed { recompute() }
    }

    /// 사용자 상태나 원장이 바뀌었을 때 다시 고른다.
    func recompute(now: Date = Date()) {
        let store = UserStateStore.shared
        let state = store.state
        let candidates = order.filter { !(raised[$0.id]?.isEmpty ?? true) }
        let context = PromptArbiter.Context(activity: state.activity,
                                            visibility: { state.visibility(of: $0) },
                                            ledger: PromptLedger.current,
                                            activeDays: store.lastFacts.activeDays,
                                            now: now)
        let next = PromptArbiter.pick(candidates, in: context)
        guard next != picked else { return }
        picked = next
        print("🔄 [PromptBoard.recompute] " + PromptSlot.allCases.map { "\($0.rawValue)=\(next[$0]?.id ?? "-")" }.joined(separator: " "))
    }

    /// 고른 말이 실제로 화면에 섰다. 예산을 쓰는 종류면 원장에 적는다.
    func noteShown(_ candidate: PromptCandidate) {
        switch candidate.kind {
        case .money, .ask, .news:
            PromptLedger.noteSpoke(candidate.kind, id: candidate.id,
                                   activeDays: UserStateStore.shared.lastFacts.activeDays)
        case .status, .moment, .unblock, .nextFloor:
            break
        }
    }

    /// 사용자가 닫았다. 돈 이야기면 며칠 쉰다.
    func noteDeclined(_ candidate: PromptCandidate) {
        guard candidate.kind == .money else { return }
        PromptLedger.noteDeclined(.money)
        recompute()
    }
}

// MARK: - 띠

/// 말할 거리가 있으면 손을 들고, 골렸을 때만 그린다.
///
/// ⚠️ 그릇은 `DismissibleRow` 다. 게으른 스택 안에서 전이가 걸리게 하는 이유는 그쪽 주석에 있다.
struct PromptRow<Content: View>: View {
    let candidate: PromptCandidate
    let wants: Bool
    @ViewBuilder let content: () -> Content

    @ObservedObject private var board = PromptBoard.list
    @State private var token = UUID()

    init(_ candidate: PromptCandidate, wants: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.candidate = candidate
        self.wants = wants
        self.content = content
    }

    private var isShowing: Bool { wants && board.isPicked(candidate) }

    var body: some View {
        DismissibleRow(isShowing: isShowing) {
            content()
                .onAppear { board.noteShown(candidate) }
        }
        .onChange(of: wants, initial: true) { _, wants in
            board.set(candidate, wants: wants, token: token)
        }
        .onDisappear { board.set(candidate, wants: false, token: token) }
    }
}
