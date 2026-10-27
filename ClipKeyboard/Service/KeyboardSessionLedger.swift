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
#if canImport(UIKit)
import UIKit
#endif

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
/// | 0 | 이 칸에 맞는 것 (`FieldFit`) | 칸이 카드번호를 받는다고 말했으면 그게 지금 필요한 것이다 |
/// | 1 | 지금 쓸 차례 (`UsageRhythm`) | 달력이 정한 순간은 미리 알 수 있다 |
/// | 2 | 붙박이 (`PersonaEdition.anchors`, 5.1.5) | 요청이 와야 생기는 순간은 언제 올지 몰라, 늘 같은 자리에 둔다 |
/// | 3 | 많이 쓴 것 (찾다 포기하는 사람에게만) | 못 찾는 사람에게 필요한 건 최근이 아니라 늘 쓰던 것이다 |
/// | 4 | 최근 1주 | 예전 그대로 |
///
/// ⚠️ 정렬 규칙은 여기 한 곳에만 둔다(`KeyboardMemoFeed` 와 같은 이유).
enum QuickRowPlanner {

    enum Reason: Equatable {
        /// 입력칸이 받는 것과 종류가 맞는 단축어(`FieldFit`)
        case fits
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
    ///   - fitIDs: 지금 입력칸에 맞는 단축어(`FieldFit.matchingIDs`). 맨 앞에 선다.
    static func plan(memos: [Memo], dueIDs: [UUID], anchorIDs: [UUID] = [], fitIDs: [UUID] = [],
                     struggling: Bool, now: Date) -> [Item] {
        let ids: Set<UUID> = Set(memos.map(\.id))
        var seen = Set<UUID>()
        var items: [Item] = []

        func push(_ id: UUID, _ reason: Reason) {
            guard items.count < limit, ids.contains(id), seen.insert(id).inserted else { return }
            items.append(Item(memoID: id, reason: reason))
        }

        fitIDs.forEach { push($0, .fits) }
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

// MARK: - 이 칸에 맞는 단축어

/// 입력칸이 **무엇을 받는 칸인지** 알려 줄 때, 그 종류의 단축어를 고른다.
///
/// 키보드는 화면도, 상대가 보낸 글도 못 본다. 대신 iOS 가 입력칸의 꼬리표(`textContentType`,
/// 웹 폼의 `autocomplete` 도 여기로 온다)와 자판 종류(`keyboardType`)를 건넨다.
/// 그 둘이 말해 주는 칸에서만 움직인다. 말해 주지 않는 칸에서는 아무것도 하지 않는다.
///
/// ⚠️ 칸에 쓴 글은 보지 않는다. 판정은 꼬리표와 단축어 쪽 종류(`Memo.autoDetectedType`)만 쓴다.
/// ⚠️ 종류가 비어 있는 옛 단축어만 그 자리에서 분류한다. 결과는 키보드가 들고 있다가 다시 쓴다.
enum FieldFit {

    enum Kind: String, Equatable {
        case creditCard, email, phone, address, postalCode, url, name

        /// 이 칸에 넣을 만한 단축어 종류.
        var itemTypes: Set<ClipboardItemType> {
            switch self {
            case .creditCard: return [.creditCard]
            case .email: return [.email]
            case .phone: return [.phone]
            case .address: return [.address]
            case .postalCode: return [.postalCode]
            case .url: return [.url]
            case .name: return [.name]
            }
        }
    }

    #if canImport(UIKit)
    /// 꼬리표가 먼저, 없으면 자판 종류. 둘 다 말이 없으면 nil - **모르는 칸에서는 짐작하지 않는다.**
    ///
    /// ⚠️ 숫자 자판(`numberPad`)은 보지 않는다. 카드번호 · 인증번호 · 금액이 다 그 자판이라
    ///    카드를 띄우면 셋 중 둘은 틀린다. 전화 자판은 iOS 가 다른 키보드를 쓰게 하지 않아 올 일이 없다.
    static func kind(contentType: UITextContentType?, keyboardType: UIKeyboardType?) -> Kind? {
        if let contentType {
            switch contentType {
            case .creditCardNumber: return .creditCard
            case .emailAddress: return .email
            case .telephoneNumber: return .phone
            case .fullStreetAddress, .streetAddressLine1: return .address
            case .postalCode: return .postalCode
            case .URL: return .url
            case .name: return .name
            default: break
            }
        }
        switch keyboardType {
        case .emailAddress?: return .email
        case .URL?: return .url
        default: return nil
        }
    }
    #endif

    /// 이 칸에 맞는 단축어의 id. 많이 쓴 것이 앞이다.
    ///
    /// 템플릿 · 스택 · 그림 단축어는 뺀다(칸 하나에 값 하나를 넣는 자리다).
    /// - Parameter typeOf: 종류가 비어 있는 단축어를 분류하는 길. 키보드가 결과를 들고 있게 밖에서 준다.
    static func matchingIDs(memos: [Memo], kind: Kind,
                            typeOf: (Memo) -> ClipboardItemType? = { $0.autoDetectedType }) -> [UUID] {
        memos
            .filter { !$0.isTemplate && !$0.isStack && $0.contentType == .text }
            .filter { memo in typeOf(memo).map(kind.itemTypes.contains) ?? false }
            .sorted { $0.clipCount != $1.clipCount ? $0.clipCount > $1.clipCount : $0.title < $1.title }
            .map(\.id)
    }
}

// MARK: - 치면 떠오르는 단축어

/// 자판으로 친 마지막 낱말이 단축어 이름이나 아이폰 텍스트 대치와 맞으면 맨 위 띠에 칩으로 세운다.
///
/// ⚠️ **바꿔 넣지 않고 제안만 한다.** 단축어 이름은 "주소" 같은 평범한 낱말이 많아서,
///    스페이스에 저절로 바꾸면 그냥 그 낱말을 쓰려던 사람이 놀란다. 칩은 무시하면 그만이다.
/// ⚠️ 잠근 · 템플릿 · 스택 · 그림 단축어는 세우지 않는다. 그 단축어는 PIN · 빈칸 창을 거치는데,
///    친 낱말을 먼저 지운 뒤 창을 닫으면 낱말만 사라진다.
enum TypedShortcut {

    /// 아이폰 설정 ▸ 키보드 ▸ 텍스트 대치의 한 줄(`UILexicon`).
    struct Replacement: Equatable {
        let shortcut: String
        let phrase: String
    }

    struct Pick: Equatable {
        /// 지울 낱말(친 그대로).
        let typed: String
        /// 칩에 보일 이름.
        let title: String
        /// 넣을 글.
        let text: String
        /// 단축어면 그 id(사용 횟수를 센다), 텍스트 대치면 nil.
        let memoID: UUID?
    }

    /// 커서 바로 앞의 낱말. 띄어쓰기 · 줄바꿈 뒤면 빈 문자열이다.
    static func lastWord(in context: String?) -> String {
        guard let context else { return "" }
        let word = context.reversed().prefix { !$0.isWhitespace && !$0.isNewline }
        return word.count > 24 ? "" : String(word.reversed())
    }

    /// 낱말에 맞는 칩들. 이름과 똑같은 것이 먼저, 이름이 그 낱말로 시작하는 것(두 글자부터)이 다음이다.
    static func picks(for word: String, memos: [Memo], replacements: [Replacement], limit: Int = 3) -> [Pick] {
        guard !word.isEmpty else { return [] }
        let options: String.CompareOptions = [.caseInsensitive, .widthInsensitive]
        func same(_ a: String) -> Bool { a.compare(word, options: options) == .orderedSame }
        func starts(_ a: String) -> Bool { word.count >= 2 && a.range(of: word, options: options.union(.anchored)) != nil }

        let usable = memos
            .filter { !$0.isSecure && !$0.isTemplate && !$0.isStack && $0.contentType == .text && !$0.title.isEmpty }
            .sorted { $0.clipCount > $1.clipCount }
        let exact = replacements.filter { same($0.shortcut) }.map { Pick(typed: word, title: $0.phrase, text: $0.phrase, memoID: nil) }
            + usable.filter { same($0.title) }.map { Pick(typed: word, title: $0.title, text: $0.value, memoID: $0.id) }
        let prefixed = usable.filter { !same($0.title) && starts($0.title) }
            .map { Pick(typed: word, title: $0.title, text: $0.value, memoID: $0.id) }

        var seen = Set<String>()
        return (exact + prefixed)
            .filter { $0.text != word && seen.insert($0.text).inserted }
            .prefix(limit)
            .map { $0 }
    }
}
