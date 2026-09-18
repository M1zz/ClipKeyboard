//
//  KeyboardSessionLedgerTests.swift
//  ClipKeyboardTests
//
//  "찾다가 포기한 판" 판정과 키보드 빠른 줄의 순서.
//

import Testing
import Foundation
@testable import ClipKeyboard

struct KeyboardSessionLedgerTests {

    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func session(_ minutesAgo: Double, open seconds: TimeInterval,
                         inserted: Bool = false, typed: Bool = false) -> KeyboardSessionLedger.Session {
        let opened = now.addingTimeInterval(-minutesAgo * 60)
        return .init(openedAt: opened, closedAt: opened.addingTimeInterval(seconds), inserted: inserted, typed: typed)
    }

    // MARK: - 포기한 판

    @Test("열어 두었다가 아무것도 안 넣고 닫으면 포기한 판이다")
    func lingeringWithoutInsertIsAbandoned() {
        #expect(KeyboardSessionLedger.isAbandoned(session(1, open: 8)))
    }

    @Test("지구본으로 지나간 판은 포기가 아니다")
    func passingThroughIsNotAbandoned() {
        #expect(!KeyboardSessionLedger.isAbandoned(session(1, open: 1)))
    }

    @Test("넣었거나 직접 쳤으면 포기가 아니다")
    func insertedOrTypedIsNotAbandoned() {
        #expect(!KeyboardSessionLedger.isAbandoned(session(1, open: 20, inserted: true)))
        #expect(!KeyboardSessionLedger.isAbandoned(session(1, open: 20, typed: true)))
    }

    @Test("아직 안 닫힌 판은 판정하지 않는다")
    func openSessionIsNotAbandoned() {
        #expect(!KeyboardSessionLedger.isAbandoned(.init(openedAt: now)))
    }

    // MARK: - 요즘 못 찾는가

    @Test("일주일에 다섯 판 중 셋을 포기하면 못 찾고 있는 것이다")
    func strugglingThreshold() {
        let sessions = [session(10, open: 9), session(20, open: 9), session(30, open: 9),
                        session(40, open: 5, inserted: true), session(50, open: 5, inserted: true)]
        #expect(KeyboardSessionLedger.isStruggling(sessions, now: now))
    }

    @Test("판이 적으면 판단하지 않는다")
    func tooFewSessions() {
        let sessions = [session(10, open: 9), session(20, open: 9), session(30, open: 9)]
        #expect(!KeyboardSessionLedger.isStruggling(sessions, now: now))
    }

    @Test("대부분 넣었으면 가끔 닫은 것은 괜찮다")
    func mostlySuccessful() {
        var sessions = (0..<10).map { session(Double($0) * 10, open: 5, inserted: true) }
        sessions += [session(200, open: 9), session(210, open: 9), session(220, open: 9)]
        #expect(!KeyboardSessionLedger.isStruggling(sessions, now: now))
    }

    @Test("일주일보다 오래된 판은 보지 않는다")
    func oldSessionsIgnored() {
        let eightDays = 8.0 * 24 * 60
        let sessions = (0..<6).map { session(eightDays + Double($0), open: 9) }
        #expect(!KeyboardSessionLedger.isStruggling(sessions, now: now))
    }

    // MARK: - 빠른 줄

    private func memo(_ title: String, uses: Int = 0, lastUsedDaysAgo: Double? = nil) -> Memo {
        var m = Memo(title: title, value: title,
                     lastUsedAt: lastUsedDaysAgo.map { now.addingTimeInterval(-$0 * 86_400) })
        m.clipCount = uses
        return m
    }

    @Test("지금 쓸 차례가 최근보다 앞에 선다")
    func dueFirst() {
        let recent = memo("recent", uses: 1, lastUsedDaysAgo: 1)
        let invoice = memo("invoice", uses: 3, lastUsedDaysAgo: 30)
        let plan = QuickRowPlanner.plan(memos: [recent, invoice], dueIDs: [invoice.id], struggling: false, now: now)
        #expect(plan.map(\.memoID) == [invoice.id, recent.id])
        #expect(plan.first?.reason == .due)
    }

    @Test("많이 쓴 것은 찾다 포기하는 사람에게만 얹는다")
    func frequentOnlyWhenStruggling() {
        let heavy = memo("heavy", uses: 40, lastUsedDaysAgo: 20)
        let recent = memo("recent", uses: 1, lastUsedDaysAgo: 1)
        let calm = QuickRowPlanner.plan(memos: [heavy, recent], dueIDs: [], struggling: false, now: now)
        #expect(calm.map(\.memoID) == [recent.id])

        let struggling = QuickRowPlanner.plan(memos: [heavy, recent], dueIDs: [], struggling: true, now: now)
        #expect(struggling.map(\.memoID) == [heavy.id, recent.id])
        #expect(struggling.first?.reason == .frequent)
    }

    @Test("같은 단축어는 한 번만, 다섯 개까지, 키보드에 없는 것은 빼고")
    func dedupeLimitAndVisibility() {
        let memos = (0..<8).map { memo("m\($0)", uses: 5, lastUsedDaysAgo: Double($0) * 0.1) }
        let hidden = UUID()
        let plan = QuickRowPlanner.plan(memos: memos, dueIDs: [hidden, memos[3].id], struggling: true, now: now)
        #expect(plan.count == QuickRowPlanner.limit)
        #expect(Set(plan.map(\.memoID)).count == plan.count)
        #expect(!plan.map(\.memoID).contains(hidden))
        #expect(plan.first?.memoID == memos[3].id)
    }
}
