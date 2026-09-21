//
//  KeyboardSessionLedger.swift
//  ClipKeyboard / ClipKeyboardExtension
//
//  **키보드를 열었다가 아무것도 넣지 않고 닫았다면, 찾다가 포기한 것이다.**
//
//  왜 필요한가: 키보드 비콘(`kb.beacon`)은 키보드가 **떴다**는 것만 안다. 뜬 뒤에 무엇을
//  넣었는지는 모른다. 그래서 "열 번 열고 한 번 넣는 사람" 과 "열 번 열고 열 번 넣는 사람" 이
//  같은 숫자로 보였다. 앞사람은 원하는 것을 못 찾고 있다.
//
//  판정: 최근 7일, 닫힌 판이 다섯 이상이고, 그중 셋 이상(40% 이상)이 **3초 넘게 열려 있다가
//  아무것도 안 넣고** 닫혔다.
//
//  ⚠️ 3초 미만은 세지 않는다. 지구본을 눌러 다른 키보드로 **지나가는** 것은 찾다 포기한 게 아니다.
//  ⚠️ 글자를 직접 친 판도 세지 않는다. 단축어를 안 넣었을 뿐 키보드는 제 할 일을 했다.
//
//  하는 일: 키보드 빠른 줄에 **많이 쓴 것**을 얹는다(`QuickRowPlanner`). 말을 걸지는 않는다.
//
//  ⚠️ 남기는 것은 시각과 참·거짓 두 개뿐이다. 무엇을 쳤는지는 남기지 않는다.
//

import Foundation

enum KeyboardSessionLedger {

    /// 키보드가 한 번 뜬 판.
    struct Session: Codable, Equatable {
        var openedAt: Date
        var closedAt: Date?
        /// 단축어를 넣었는가.
        var inserted: Bool = false
        /// 글자를 직접 쳤는가.
        var typed: Bool = false
    }

    /// 남기는 판 수. 판정은 최근 7일만 보니 이 정도면 넉넉하다.
    static let limit = 20

    enum Threshold {
        static let windowDays = 7
        static let sessionsMin = 5
        static let abandonsMin = 3
        static let abandonShare = 0.4
        /// 이보다 짧게 열렸다 닫힌 판은 지나간 것이다.
        static let lingerSeconds: TimeInterval = 3
    }

    private static var defaults: UserDefaults? { AppGroup.defaults }

    // MARK: - 기록 (키보드가 부른다)

    /// 키보드가 떴다.
    static func begin(now: Date = Date()) {
        var sessions = load()
        // 닫힘을 못 받은 판이 남아 있으면(프로세스가 죽었다) 판정에서 빠지게 둔다.
        sessions.append(Session(openedAt: now))
        save(sessions)
    }

    /// 단축어를 넣었다.
    static func noteInserted() { updateOpen { $0.inserted = true } }

    /// 글자를 직접 쳤다. 한 판에 한 번만 부르면 된다(`KeyboardViewController.sessionTypedNoted`).
    static func noteTyped() { updateOpen { $0.typed = true } }

    /// 키보드가 내려갔다.
    static func end(now: Date = Date()) { updateOpen { $0.closedAt = now } }

    static func load() -> [Session] {
        guard let data = defaults?.data(forKey: DefaultsKey.keyboardSessionLedger) else { return [] }
        return (try? JSONDecoder().decode([Session].self, from: data)) ?? []
    }

    private static func updateOpen(_ change: (inout Session) -> Void) {
        var sessions = load()
        guard let index = sessions.indices.last, sessions[index].closedAt == nil else { return }
        change(&sessions[index])
        save(sessions)
    }

    private static func save(_ sessions: [Session]) {
        let trimmed = Array(sessions.suffix(limit))
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        defaults?.set(data, forKey: DefaultsKey.keyboardSessionLedger)
    }

    // MARK: - 판정

    /// 찾다가 포기한 판인가 - **순수 함수.**
    static func isAbandoned(_ session: Session) -> Bool {
        guard let closedAt = session.closedAt else { return false }
        guard !session.inserted, !session.typed else { return false }
        return closedAt.timeIntervalSince(session.openedAt) >= Threshold.lingerSeconds
    }

    /// 요즘 원하는 것을 못 찾고 있는가 - **순수 함수.**
    static func isStruggling(_ sessions: [Session], now: Date) -> Bool {
        let from = now.addingTimeInterval(-TimeInterval(Threshold.windowDays) * 86_400)
        let recent = sessions.filter { $0.closedAt != nil && $0.openedAt >= from && $0.openedAt <= now }
        guard recent.count >= Threshold.sessionsMin else { return false }
        let abandons = recent.filter(isAbandoned).count
        guard abandons >= Threshold.abandonsMin else { return false }
        return Double(abandons) / Double(recent.count) >= Threshold.abandonShare
    }
}

// MARK: - 빠른 줄

/// 키보드 맨 위 빠른 줄(칩)에 무엇을 어떤 순서로 세울지.
///
/// 예전에는 "최근 1주에 쓴 것" 하나였다. 이제 세 갈래가 자리를 나눈다.
///
/// | 순서 | 갈래 | 왜 |
/// | --- | --- | --- |
/// | 1 | 지금 쓸 차례 (`UsageRhythm`) | 달력이 정한 순간은 미리 알 수 있다 |
/// | 2 | 붙박이 (`PersonaEdition.anchors`, 5.1.5) | 요청이 와야 생기는 순간은 언제 올지 몰라, 늘 같은 자리에 둔다 |
/// | 3 | 많이 쓴 것 (찾다 포기하는 사람에게만) | 못 찾는 사람에게 필요한 건 최근이 아니라 늘 쓰던 것이다 |
/// | 4 | 최근 1주 | 예전 그대로 |
///
/// ⚠️ 정렬 규칙은 여기 한 곳에만 둔다(`KeyboardMemoFeed` 와 같은 이유).
enum QuickRowPlanner {

    enum Reason: Equatable {
        case due
        /// 판이 붙박아 둔 것(계좌·송금 정보·명함·학번). `PersonaEdition.anchors`
        case anchor
        case frequent
        case recent
    }

    struct Item: Equatable {
        let memoID: UUID
        let reason: Reason
    }

    static let limit = 5
    /// 많이 쓴 것으로 치려면 적어도 이만큼은 써야 한다.
    static let frequentMinUses = 2
    /// 많이 쓴 것은 이만큼만 얹는다. 최근 쓴 것까지 밀어내면 예전 줄을 믿던 사람이 헷갈린다.
    static let frequentMax = 2

    /// - Parameters:
    ///   - memos: 키보드에 실제로 보이는 단축어(무료 한도로 자른 뒤).
    ///   - dueIDs: 지금 쓸 차례인 단축어(`UsageRhythm.dueMemoIDs`).
    ///   - anchorIDs: 판이 붙박아 둔 단축어(`QuickRowAnchors.load`).
    ///   - struggling: 요즘 찾다가 포기하는가(`KeyboardSessionLedger.isStruggling`).
    static func plan(memos: [Memo], dueIDs: [UUID], anchorIDs: [UUID] = [],
                     struggling: Bool, now: Date) -> [Item] {
        let ids: Set<UUID> = Set(memos.map(\.id))
        var seen = Set<UUID>()
        var items: [Item] = []

        func push(_ id: UUID, _ reason: Reason) {
            guard items.count < limit, ids.contains(id), seen.insert(id).inserted else { return }
            items.append(Item(memoID: id, reason: reason))
        }

        dueIDs.forEach { push($0, .due) }
        anchorIDs.forEach { push($0, .anchor) }

        if struggling {
            let used = memos.filter { $0.clipCount >= frequentMinUses }
            let frequent = used.sorted(by: byUsesDescending)
            frequent.prefix(frequentMax).forEach { push($0.id, .frequent) }
        }

        let weekAgo = now.addingTimeInterval(-7 * 86_400)
        let recent = memos.filter { ($0.lastUsedAt ?? .distantPast) >= weekAgo }
        recent.sorted(by: byLastUsedDescending).forEach { push($0.id, .recent) }

        return items
    }

    private static func byUsesDescending(_ a: Memo, _ b: Memo) -> Bool {
        if a.clipCount != b.clipCount { return a.clipCount > b.clipCount }
        return a.id.uuidString < b.id.uuidString
    }

    private static func byLastUsedDescending(_ a: Memo, _ b: Memo) -> Bool {
        let left: Date = a.lastUsedAt ?? .distantPast
        let right: Date = b.lastUsedAt ?? .distantPast
        return left > right
    }
}

// MARK: - 붙박이

/// 판이 키보드 빠른 줄에 붙박아 둔 단축어(App Group). **앱이 적고 키보드가 읽는다.**
///
/// 쓰임새 판정(`PersonaResolver`)과 판(`PersonaEdition`)은 앱에만 있다. 키보드까지 끌고 가면
/// 익스텐션이 목록 전체를 분류하느라 뜨는 시간이 늘어난다. 그래서 결과인 id 만 건넨다.
enum QuickRowAnchors {

    private static var defaults: UserDefaults? { AppGroup.defaults }

    static func load() -> [UUID] {
        (defaults?.stringArray(forKey: DefaultsKey.quickRowAnchors) ?? []).compactMap(UUID.init(uuidString:))
    }

    static func save(_ ids: [UUID]) {
        defaults?.set(ids.map(\.uuidString), forKey: DefaultsKey.quickRowAnchors)
    }
}
