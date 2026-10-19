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
        let candidates = order.filter { !(raised[$0.id]?.isEmpty ?? true) }
        let next = Self.pickNow(candidates, now: now)
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

// MARK: - 실행 시트

extension PromptCandidate {
    // 고장 · 막힘
    static let accessibilityGuide = PromptCandidate(id: "accessibilityGuide", slot: .launchSheet, kind: .status)
    static let categoryCleanup = PromptCandidate(id: "categoryCleanup", slot: .launchSheet, kind: .unblock)
    // ⚠️ 새 소식은 **방금 일어난 일(업데이트)에 대한 답**으로 친다. 소식으로 두면 같은 실행의
    //    반값 제안·리뷰에 밀려, 정작 새 버전 첫 실행에 말하지 못한다. 평생 한 번이라 예산도 안 쓴다.
    static let whatsNew = PromptCandidate(id: "whatsNew", slot: .launchSheet, kind: .moment,
                                          bypassesBudget: true, allowedWhenReturning: true)
    static let discountOffer = PromptCandidate(id: "discountOffer", slot: .launchSheet, kind: .money)
    static let reviewRequest = PromptCandidate(id: "reviewRequest", slot: .launchSheet, kind: .ask,
                                               surface: .reviewRequest)
    static let feedbackNudge = PromptCandidate(id: "feedbackNudge", slot: .launchSheet, kind: .ask)
    static let didYouKnow = PromptCandidate(id: "didYouKnow", slot: .launchSheet, kind: .news)

    // 탭이 띄우는 판
    static let shareMoment = PromptCandidate(id: "shareMoment", slot: .launchSheet, kind: .ask)

    /// 앱을 열 때 고르는 차례. 같은 종류 안에서는 이 순서다.
    static let launchOrder: [PromptCandidate] = [
        .accessibilityGuide, .categoryCleanup, .whatsNew, .discountOffer,
        .reviewRequest, .feedbackNudge, .didYouKnow,
    ]
}

extension PromptBoard {
    /// 지금 사용자 상태와 원장으로 고른다. 실행 시트처럼 게시판을 거치지 않는 자리가 쓴다.
    static func pickNow(_ candidates: [PromptCandidate], now: Date = Date()) -> [PromptSlot: PromptCandidate] {
        PromptArbiter.pick(candidates, in: currentContext(now: now))
    }

    /// 이 말 하나가 지금 해도 되는 말인가(활동 · 층 · 예산).
    static func allowsNow(_ candidate: PromptCandidate, now: Date = Date()) -> Bool {
        PromptArbiter.isAllowed(candidate, in: currentContext(now: now))
    }

    private static func currentContext(now: Date) -> PromptArbiter.Context {
        let store = UserStateStore.shared
        let state = store.state
        return PromptArbiter.Context(activity: state.activity,
                                     visibility: { state.visibility(of: $0) },
                                     ledger: PromptLedger.current,
                                     activeDays: store.lastFacts.activeDays,
                                     now: now)
    }
}

/// **앱을 한 번 여는 동안 저절로 뜨는 창은 하나.** 먼저 쥔 쪽이 띄운다.
///
/// 왜 필요한가: 실행 때 뜨는 창은 앱(`ClipKeyboardApp`)도, 목록(무료 사용 영수증 · 배경 제안)도,
/// 첫 탭(연습용 단축어 치우기 · 키보드 무대 권유 · 친구에게 알리기)도 띄운다. 앱은 1.0초에서
/// 4.5초까지 시간차를 두고 서로를 확인했지만 목록과 탭의 창은 몰랐다. 그래서 두 창이 겹쳤다.
///
/// ⚠️ 자리를 못 쥔 쪽은 **본 것으로 적지 않는다.** 다음 실행에 다시 온다.
/// ⚠️ 사람이 직접 연 화면(설정의 "다시 보기", 버튼으로 연 페이월)은 여기를 거치지 않는다.
@MainActor
enum LaunchSheetGate {
    private static var holder: String?

    static var isTaken: Bool { holder != nil }

    /// 이번 실행의 자리를 쥔다. 이미 누가 쥐었으면 false.
    static func claim(_ id: String) -> Bool {
        guard holder == nil else {
            print("⏭️ [LaunchSheetGate.claim] \(id) 비킴 (이미 \(holder ?? "") 이 떠 있음)")
            return false
        }
        holder = id
        print("🪟 [LaunchSheetGate.claim] \(id)")
        return true
    }

    /// 앱이 뒤로 갔다. 다음에 앞으로 오면 새 실행으로 친다.
    static func reset() {
        holder = nil
    }
}
