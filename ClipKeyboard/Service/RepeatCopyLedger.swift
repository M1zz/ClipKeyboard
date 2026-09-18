//
//  RepeatCopyLedger.swift
//  ClipKeyboard
//
//  **같은 글을 일주일 안에 두 번 복사했다면, 그 글은 저장할 글이다.**
//
//  왜 필요한가: 앱을 열면 방금 복사한 것을 저장할지 묻는 카드가 뜬다(`ClipboardCaptureCard`).
//  그런데 그 카드는 복사한 모든 것에 같은 얼굴이었다. 한 번 보고 말 링크와, 이번 주에만 세 번째
//  은행 앱에서 꺼내 온 계좌번호가 똑같이 보였다. 사람은 대개 닫는다.
//  그리고 한 번 닫은 글은 다시는 카드로 뜨지 않았다. 정확히 저장해야 할 글이 가장 먼저 사라졌다.
//
//  이제
//   - 두 번째 복사부터 카드에 "이번 주 n번째 복사" 를 붙인다
//   - 전에 닫았던 글이라도, 다시 복사했으면 **한 번 더** 보여 준다(그다음에는 정말 끝)
//
//  ⚠️ **글 자체는 남기지 않는다.** 남기는 것은 글의 지문(SHA-256 앞 16자리)과 복사 번호뿐이다.
//     복사한 글에는 비밀번호도 섞여 있다. 그걸 판단하겠다고 또 어딘가에 적는 순간 사고다.
//
//  ⚠️ "두 번 복사" 는 앱을 두 번 연 것이 아니다. 복사 한 번은 클립보드 `changeCount` 하나다.
//     같은 복사를 앱에서 열 번 봐도 한 번이다.
//

import Foundation
import CryptoKit

enum RepeatCopyLedger {

    struct Entry: Codable, Equatable {
        var digest: String
        /// 복사 번호(`UIPasteboard.changeCount`)와 처음 본 시각.
        var copies: [Copy]
        /// 닫았던 카드를 다시 꺼내 준 적이 있는가.
        var resurfaced: Bool = false

        struct Copy: Codable, Equatable {
            var changeCount: Int
            var seenAt: Date
        }
    }

    enum Threshold {
        static let windowDays = 7
        /// 이만큼 복사했으면 반복이다.
        static let repeatCopies = 2
        /// 기억하는 글 수.
        static let limit = 40
    }

    // MARK: - 순수 함수

    /// 글의 지문. 앞뒤 공백은 같은 글로 본다.
    static func digest(_ text: String) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hash = SHA256.hash(data: Data(normalized.utf8))
        return hash.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    /// 한 번 봤다고 적은 새 장부와, 최근 7일 안에 몇 번 복사했는지.
    static func noting(_ entries: [Entry],
                       digest: String,
                       changeCount: Int,
                       now: Date) -> (entries: [Entry], copies: Int, entry: Entry) {
        let from = now.addingTimeInterval(-TimeInterval(Threshold.windowDays) * 86_400)
        var next = entries
        var entry = next.first(where: { $0.digest == digest }) ?? Entry(digest: digest, copies: [])
        next.removeAll { $0.digest == digest }

        entry.copies.removeAll { $0.seenAt < from }
        if !entry.copies.contains(where: { $0.changeCount == changeCount }) {
            entry.copies.append(.init(changeCount: changeCount, seenAt: now))
        }

        // 최근에 본 것이 맨 앞. 오래 안 본 글부터 잊는다.
        next.insert(entry, at: 0)
        next.removeAll { $0.copies.allSatisfy { $0.seenAt < from } }
        if next.count > Threshold.limit { next = Array(next.prefix(Threshold.limit)) }
        return (next, entry.copies.count, entry)
    }

    /// 전에 닫았던 글을 한 번 더 꺼내 줄 때인가.
    static func shouldResurface(_ entry: Entry) -> Bool {
        entry.copies.count >= Threshold.repeatCopies && !entry.resurfaced
    }

    // MARK: - 기록

    private static var defaults: UserDefaults { .standard }

    static func load() -> [Entry] {
        guard let data = defaults.data(forKey: DefaultsKey.repeatCopyLedger) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    private static func save(_ entries: [Entry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: DefaultsKey.repeatCopyLedger)
    }

    /// 방금 본 클립보드를 적는다.
    /// - Returns: 최근 7일 복사 횟수와, 닫았던 카드를 다시 꺼내도 되는지.
    @discardableResult
    static func note(text: String, changeCount: Int, now: Date = Date()) -> (copies: Int, mayResurface: Bool) {
        let result = noting(load(), digest: digest(text), changeCount: changeCount, now: now)
        save(result.entries)
        return (result.copies, shouldResurface(result.entry))
    }

    /// 닫았던 카드를 한 번 더 꺼내 줬다고 적는다.
    static func markResurfaced(text: String) {
        let key = digest(text)
        var entries = load()
        guard let index = entries.firstIndex(where: { $0.digest == key }) else { return }
        entries[index].resurfaced = true
        save(entries)
    }
}
