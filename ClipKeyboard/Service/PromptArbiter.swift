//
//  PromptArbiter.swift
//  ClipKeyboard
//
//  **누가 말할지는 여기서만 고른다.** 띠·카드·팁·시트가 저마다 "지금 말해도 되나" 를
//  판단하던 것을 한 곳으로 모은다.
//
//  왜 필요한가: 말하는 쪽마다 따로 판단하니 하나하나는 옳은데 합치면 시끄러웠다.
//  목록 위 띠 13개가 서로를 몰라 한꺼번에 설 수 있었고, 휴면을 지키는 말은 넷뿐이었다.
//  자세한 설계: docs/design/PROGRESSIVE_DISCLOSURE.md
//
//  나눈 일
//
//  | 누가 | 무엇을 답하나 |
//  | --- | --- |
//  | 말하는 쪽 | 말할 거리가 있는가. 그것만 (`PromptCandidate` 를 내민다) |
//  | 고르는 쪽 (여기) | 활동 · 층 · 예산 · 우선순위로 자리마다 하나 |
//  | 원장 (`PromptLedger`) | 종류마다 언제 마지막으로 말했나 |
//
//  ⚠️ **순수하다.** 기기도 화면도 모른다. 값을 받아 값을 돌려준다.
//     그래야 단계 흉내 10단계 x 판 5개를 시험에서 다 돌려 볼 수 있다.
//
//  ⚠️ **페르소나는 여기 들어오지 않는다.** 같은 종류 안의 차례는 부르는 쪽이 후보를
//     내미는 순서로 정한다(`FeatureFit.purchaseMomentOrder` 처럼). 페르소나가 말할지 말지를
//     정하기 시작하면 확신이 없는 첫 주 사람이 어느 판에도 속하지 않게 된다.
//

import Foundation

// MARK: - 자리

/// 말이 서는 자리. 자리마다 한 번에 하나만 선다.
enum PromptSlot: String, CaseIterable {
    /// 고장 난 것을 알리는 띠. 키보드가 꺼져 있다 · 이용 기간이 끝난다.
    case statusBand
    /// 방금 한 일에 대한 답. 방금 복사함 · 빠른 메모 보관함.
    case momentCard
    /// 고른 제안 하나. 팁(TipKit)도 이 자리의 예산을 쓴다.
    case suggestionCard
    /// 앱을 열 때 뜨는 시트·알림. 실행당 하나.
    case launchSheet
}

// MARK: - 종류

/// 말의 종류. **선언 순서가 곧 우선순위다.** 위가 먼저다.
enum PromptKind: Int, CaseIterable, Comparable {
    /// 고장 난 것. 휴면이어도 말한다.
    case status
    /// 사용자가 방금 한 일에 대한 답. 휴면이어도 말한다.
    case moment
    /// 막힌 사람을 푸는 것. 예시에서 골라 담기 · 필수 세 칸.
    case unblock
    /// 필요해진 다음 층 기능 하나를 소개.
    case nextFloor
    /// 결제 이야기. 앱과 키보드가 예산 하나를 나눠 쓴다.
    case money
    /// 부탁. 리뷰 · 피드백 · 친구에게 알리기 · 팁.
    case ask
    /// 소식. 새 소식 · 그거 아세요.
    case news

    static func < (lhs: PromptKind, rhs: PromptKind) -> Bool { lhs.rawValue < rhs.rawValue }
}

// MARK: - 후보

/// 말하는 쪽이 내미는 것. "말할 거리가 있다" 는 뜻이다.
struct PromptCandidate: Equatable {
    /// 저장·로그에 쓰는 이름. 한 번 정하면 바꾸지 않는다.
    let id: String
    let slot: PromptSlot
    let kind: PromptKind
    /// 층에 걸린 말이면 그 자리. 그 자리가 지금 감춰져 있으면 말하지 않는다.
    var surface: UserSurface? = nil
    /// 예산을 쓰지 않는 말. 새 버전 첫 실행의 새 소식처럼 평생 한 번뿐인 것만.
    var bypassesBudget: Bool = false
    /// 돌아온 사람에게도 해도 되는 말. 새 소식처럼 "그동안 바뀐 것" 이 그 사람에게 필요한 것.
    var allowedWhenReturning: Bool = false
}

// MARK: - 예산

enum PromptBudget {
    /// 돈 이야기: 하루 한 번(같은 날이면 다시 안 함).
    static let moneyPerDay = 1
    /// 돈 이야기를 거절했으면 쉬는 날.
    static let moneyRestAfterDecline: TimeInterval = 3 * 86_400
    /// 부탁: 7일에 한 번.
    static let askInterval: TimeInterval = 7 * 86_400
    /// 소식: 단축어를 쓴 날 기준 3일에 한 번.
    static let newsActiveDays = 3
}

// MARK: - 고르기

enum PromptArbiter {

    /// 고르는 데 쓰는 값.
    struct Context {
        var activity: UserActivity
        /// 층에 걸린 자리의 노출. 보통 `UserState.visibility(of:)`.
        var visibility: (UserSurface) -> SurfaceVisibility
        var ledger: PromptLedger.Snapshot
        /// 단축어를 쓴 날의 수(`UserStateFacts.activeDays`). 소식 예산을 쓴 날로 센다.
        var activeDays: Int
        var now: Date
        var calendar: Calendar = .current
    }

    /// 자리마다 하나를 고른다. 후보는 **같은 종류 안에서 먼저 낸 것이 먼저다.**
    static func pick(_ candidates: [PromptCandidate], in context: Context) -> [PromptSlot: PromptCandidate] {
        var picked: [PromptSlot: PromptCandidate] = [:]
        for slot in PromptSlot.allCases {
            let best = candidates
                .enumerated()
                .filter { $0.element.slot == slot && isAllowed($0.element, in: context) }
                .min { lhs, rhs in
                    lhs.element.kind != rhs.element.kind
                        ? lhs.element.kind < rhs.element.kind
                        : lhs.offset < rhs.offset
                }
            if let best { picked[slot] = best.element }
        }
        return picked
    }

    /// 이 후보가 지금 말해도 되는가. 자리 다툼과는 따로 본다.
    static func isAllowed(_ candidate: PromptCandidate, in context: Context) -> Bool {
        allowsActivity(candidate, context.activity)
            && allowsSurface(candidate, context.visibility)
            && (candidate.bypassesBudget
                || context.ledger.holdsBudget(candidate.kind, id: candidate.id)
                || hasBudget(candidate.kind, in: context))
    }

    // MARK: 활동

    /// 휴면이면 고장과 방금 한 일에 대한 답만. 돌아온 사람에게는 돈·부탁·소식을 꺼낸다.
    static func allowsActivity(_ candidate: PromptCandidate, _ activity: UserActivity) -> Bool {
        switch activity {
        case .active:
            return true
        case .dormant:
            return candidate.kind <= .moment
        case .returning:
            if candidate.allowedWhenReturning { return true }
            switch candidate.kind {
            case .status, .moment, .unblock, .nextFloor: return true
            case .money, .ask, .news: return false
            }
        }
    }

    // MARK: 층

    static func allowsSurface(_ candidate: PromptCandidate,
                              _ visibility: (UserSurface) -> SurfaceVisibility) -> Bool {
        guard let surface = candidate.surface else { return true }
        return visibility(surface).isVisible
    }

    // MARK: 예산

    static func hasBudget(_ kind: PromptKind, in context: Context) -> Bool {
        let ledger = context.ledger
        switch kind {
        case .status, .moment, .unblock, .nextFloor:
            return true

        case .money:
            if let declined = ledger.lastDeclined[.money],
               context.now.timeIntervalSince(declined) < PromptBudget.moneyRestAfterDecline {
                return false
            }
            guard let last = ledger.lastSpoke[.money] else { return true }
            return !context.calendar.isDate(last, inSameDayAs: context.now)

        case .ask:
            guard let last = ledger.lastSpoke[.ask] else { return true }
            return context.now.timeIntervalSince(last) >= PromptBudget.askInterval

        case .news:
            guard let spokeAt = ledger.activeDaysAtSpeak[.news] else { return true }
            return context.activeDays - spokeAt >= PromptBudget.newsActiveDays
        }
    }
}
