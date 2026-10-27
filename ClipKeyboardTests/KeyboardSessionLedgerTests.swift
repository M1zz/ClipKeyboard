//
//  KeyboardSessionLedgerTests.swift
//  ClipKeyboardTests
//
//  "찾다가 포기한 판" 판정과 키보드 빠른 줄의 순서.
//

import Testing
import Foundation
import UIKit
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

// MARK: - 이 칸에 맞는 단축어

struct FieldFitTests {

    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    @Test("꼬리표가 말한 칸만 알아본다. 숫자 자판만으로는 짐작하지 않는다")
    func kindComesFromTheFieldOnly() {
        #expect(FieldFit.kind(contentType: .creditCardNumber, keyboardType: .numberPad) == .creditCard)
        #expect(FieldFit.kind(contentType: .emailAddress, keyboardType: nil) == .email)
        #expect(FieldFit.kind(contentType: .fullStreetAddress, keyboardType: nil) == .address)
        #expect(FieldFit.kind(contentType: nil, keyboardType: .emailAddress) == .email)
        #expect(FieldFit.kind(contentType: nil, keyboardType: .numberPad) == nil)
        #expect(FieldFit.kind(contentType: nil, keyboardType: .default) == nil)
        #expect(FieldFit.kind(contentType: .oneTimeCode, keyboardType: .numberPad) == nil)
    }

    @Test("카드번호 칸에는 카드 단축어만, 많이 쓴 것부터")
    func matchesByKindMostUsedFirst() {
        var card = Memo(title: "신한카드", value: "1234-5678-9012-3456", autoDetectedType: .creditCard)
        card.clipCount = 1
        var card2 = Memo(title: "국민카드", value: "9876-5432-1098-7654", autoDetectedType: .creditCard)
        card2.clipCount = 5
        let mail = Memo(title: "회사 메일", value: "me@example.com", autoDetectedType: .email)
        let template = Memo(title: "카드 안내", value: "{이름}님 카드", templateVariables: ["이름"], autoDetectedType: .creditCard)

        let ids = FieldFit.matchingIDs(memos: [card, mail, template, card2], kind: .creditCard)
        #expect(ids == [card2.id, card.id])
    }

    @Test("종류가 비어 있는 옛 단축어는 주어진 분류로 판정한다")
    func untypedMemosUseTheClassifier() {
        let old = Memo(title: "메일", value: "old@example.com")
        let ids = FieldFit.matchingIDs(memos: [old], kind: .email) { _ in .email }
        #expect(ids == [old.id])
    }

    @Test("칸에 맞는 단축어가 빠른 줄 맨 앞에 선다")
    func fitsComeFirstInQuickRow() {
        let due = Memo(title: "보고", value: "주간 보고")
        let card = Memo(title: "카드", value: "1234-5678-9012-3456", autoDetectedType: .creditCard)
        let plan = QuickRowPlanner.plan(memos: [due, card], dueIDs: [due.id], fitIDs: [card.id],
                                        struggling: false, now: now)
        #expect(plan.first == .init(memoID: card.id, reason: .fits))
        #expect(plan.count == 2)
    }
}

struct TypedShortcutTests {

    @Test("커서 바로 앞의 낱말만 본다. 띄어 쓴 뒤면 없다")
    func lastWordIsRightBeforeCursor() {
        #expect(TypedShortcut.lastWord(in: "안녕하세요 주소") == "주소")
        #expect(TypedShortcut.lastWord(in: "주소 ") == "")
        #expect(TypedShortcut.lastWord(in: "첫 줄\nㅈㅅ") == "ㅈㅅ")
        #expect(TypedShortcut.lastWord(in: nil) == "")
    }

    @Test("단축어 이름이나 텍스트 대치를 치면 칩이 선다. 이름과 같은 것이 먼저")
    func typedNameSuggestsShortcut() {
        var home = Memo(title: "주소지", value: "서울시 중구 세종대로 110")
        home.clipCount = 9
        let office = Memo(title: "주소", value: "서울시 강남구 테헤란로 1")
        let sorry = TypedShortcut.Replacement(shortcut: "ㅈㅅ", phrase: "죄송합니다")

        let picks = TypedShortcut.picks(for: "주소", memos: [home, office], replacements: [sorry])
        #expect(picks.map(\.memoID) == [office.id, home.id])
        #expect(picks.first?.typed == "주소")

        let replaced = TypedShortcut.picks(for: "ㅈㅅ", memos: [], replacements: [sorry])
        #expect(replaced == [.init(typed: "ㅈㅅ", title: "죄송합니다", text: "죄송합니다", memoID: nil)])
    }

    @Test("한 글자로는 앞부분을 맞추지 않고, 잠근 · 템플릿 단축어는 세우지 않는다")
    func quietWhenUnsure() {
        let home = Memo(title: "주소", value: "서울시 중구")
        var locked = Memo(title: "카드", value: "1234")
        locked.isSecure = true
        let template = Memo(title: "카드 안내", value: "{이름}님", templateVariables: ["이름"])

        #expect(TypedShortcut.picks(for: "주", memos: [home], replacements: []).isEmpty)
        #expect(TypedShortcut.picks(for: "카드", memos: [locked, template], replacements: []).isEmpty)
    }
}
