//
//  PromptArbiterTests.swift
//  ClipKeyboardTests
//
//  말 거는 자리를 고르는 판정. 자리마다 하나 · 우선순위 · 활동 · 층 · 예산.
//  설계: docs/design/PROGRESSIVE_DISCLOSURE.md 4절
//

import XCTest
@testable import ClipKeyboard

final class PromptArbiterTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 86_400

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func context(activity: UserActivity = .active,
                         hidden: Set<UserSurface> = [],
                         ledger: PromptLedger.Snapshot = .empty,
                         activeDays: Int = 10,
                         now: Date? = nil) -> PromptArbiter.Context {
        PromptArbiter.Context(activity: activity,
                              visibility: { hidden.contains($0) ? .hidden : .lead },
                              ledger: ledger,
                              activeDays: activeDays,
                              now: now ?? self.now,
                              calendar: calendar)
    }

    private func candidate(_ id: String,
                           _ slot: PromptSlot = .suggestionCard,
                           _ kind: PromptKind,
                           surface: UserSurface? = nil,
                           bypassesBudget: Bool = false,
                           allowedWhenReturning: Bool = false) -> PromptCandidate {
        PromptCandidate(id: id, slot: slot, kind: kind, surface: surface,
                        bypassesBudget: bypassesBudget, allowedWhenReturning: allowedWhenReturning)
    }

    // MARK: - 자리마다 하나

    func testEachSlotGetsAtMostOne() {
        let picked = PromptArbiter.pick([
            candidate("keyboardSetup", .statusBand, .status),
            candidate("accessEnding", .statusBand, .status),
            candidate("freshClipboard", .momentCard, .moment),
            candidate("inbox", .momentCard, .moment),
            candidate("bulkImport", .suggestionCard, .nextFloor),
            candidate("proValue", .suggestionCard, .money),
        ], in: context())

        XCTAssertEqual(picked.count, 3, "목록 위에는 많아야 세 줄이다")
        XCTAssertEqual(picked[.statusBand]?.id, "keyboardSetup", "같은 종류면 먼저 낸 것이 먼저다")
        XCTAssertEqual(picked[.momentCard]?.id, "freshClipboard")
        XCTAssertEqual(picked[.suggestionCard]?.id, "bulkImport")
        XCTAssertNil(picked[.launchSheet])
    }

    func testKindOrderBeatsSubmissionOrder() {
        let picked = PromptArbiter.pick([
            candidate("didYouKnow", .launchSheet, .news),
            candidate("review", .launchSheet, .ask),
            candidate("discount", .launchSheet, .money),
            candidate("essentials", .launchSheet, .unblock),
        ], in: context())

        XCTAssertEqual(picked[.launchSheet]?.id, "essentials", "막힘 풀기가 돈·부탁·소식보다 먼저다")
    }

    // MARK: - 활동

    func testDormantKeepsOnlyStatusAndMoment() {
        let candidates = [
            candidate("keyboardSetup", .statusBand, .status),
            candidate("freshClipboard", .momentCard, .moment),
            candidate("essentials", .suggestionCard, .unblock),
            candidate("whatsNew", .launchSheet, .news, bypassesBudget: true, allowedWhenReturning: true),
        ]
        let picked = PromptArbiter.pick(candidates, in: context(activity: .dormant))

        XCTAssertEqual(picked[.statusBand]?.id, "keyboardSetup")
        XCTAssertEqual(picked[.momentCard]?.id, "freshClipboard")
        XCTAssertNil(picked[.suggestionCard], "휴면이면 먼저 말을 걸지 않는다")
        XCTAssertNil(picked[.launchSheet])
    }

    func testReturningDropsMoneyAskNewsButKeepsWhatsNew() {
        let candidates = [
            candidate("proValue", .suggestionCard, .money),
            candidate("review", .launchSheet, .ask),
            candidate("didYouKnow", .launchSheet, .news),
            candidate("whatsNew", .launchSheet, .news, bypassesBudget: true, allowedWhenReturning: true),
        ]
        let picked = PromptArbiter.pick(candidates, in: context(activity: .returning))

        XCTAssertNil(picked[.suggestionCard], "돌아온 첫 화면에 결제 이야기를 꺼내지 않는다")
        XCTAssertEqual(picked[.launchSheet]?.id, "whatsNew", "그동안 바뀐 것은 돌아온 사람에게 필요하다")
    }

    // MARK: - 층

    func testHiddenSurfaceIsSilent() {
        let picked = PromptArbiter.pick([
            candidate("keyboardSetup", .statusBand, .status, surface: .keyboardSetupBanner),
        ], in: context(hidden: [.keyboardSetupBanner]))

        XCTAssertNil(picked[.statusBand], "구경 단계에서는 키보드를 켜라고 하지 않는다")
    }

    func testQuietSurfaceMaySpeak() {
        let ctx = PromptArbiter.Context(activity: .active,
                                        visibility: { _ in .quiet },
                                        ledger: .empty,
                                        activeDays: 0,
                                        now: now)
        let picked = PromptArbiter.pick([candidate("bulkImport", .suggestionCard, .nextFloor, surface: .bulkImport)],
                                        in: ctx)
        XCTAssertEqual(picked[.suggestionCard]?.id, "bulkImport")
    }

    // MARK: - 예산: 돈

    func testMoneyOncePerDay() {
        var ledger = PromptLedger.Snapshot.empty
        ledger.noteSpoke(.money, at: now.addingTimeInterval(-3600), activeDays: 10)

        let sameDay = PromptArbiter.pick([candidate("proValue", .suggestionCard, .money)],
                                         in: context(ledger: ledger))
        XCTAssertNil(sameDay[.suggestionCard], "키보드가 오늘 말했으면 앱은 말하지 않는다")

        let nextDay = PromptArbiter.pick([candidate("proValue", .suggestionCard, .money)],
                                         in: context(ledger: ledger, now: now.addingTimeInterval(day)))
        XCTAssertEqual(nextDay[.suggestionCard]?.id, "proValue")
    }

    func testMoneyRestsThreeDaysAfterDecline() {
        var ledger = PromptLedger.Snapshot.empty
        ledger.noteSpoke(.money, at: now, activeDays: 10)
        ledger.noteDeclined(.money, at: now)

        let twoDays = PromptArbiter.hasBudget(.money, in: context(ledger: ledger, now: now.addingTimeInterval(2 * day)))
        let threeDays = PromptArbiter.hasBudget(.money, in: context(ledger: ledger, now: now.addingTimeInterval(3 * day)))
        XCTAssertFalse(twoDays)
        XCTAssertTrue(threeDays)
    }

    // MARK: - 예산: 부탁

    func testAskOncePerWeek() {
        var ledger = PromptLedger.Snapshot.empty
        ledger.noteSpoke(.ask, at: now, activeDays: 10)

        XCTAssertFalse(PromptArbiter.hasBudget(.ask, in: context(ledger: ledger, now: now.addingTimeInterval(6 * day))))
        XCTAssertTrue(PromptArbiter.hasBudget(.ask, in: context(ledger: ledger, now: now.addingTimeInterval(7 * day))))
    }

    // MARK: - 예산: 소식

    func testNewsCountsActiveDaysNotCalendarDays() {
        var ledger = PromptLedger.Snapshot.empty
        ledger.noteSpoke(.news, at: now, activeDays: 10)

        // 한 달이 지나도 그동안 안 썼으면 소식을 다시 꺼내지 않는다.
        XCTAssertFalse(PromptArbiter.hasBudget(.news, in: context(ledger: ledger, activeDays: 12,
                                                                    now: now.addingTimeInterval(30 * day))))
        XCTAssertTrue(PromptArbiter.hasBudget(.news, in: context(ledger: ledger, activeDays: 13)))
    }

    func testBypassIgnoresBudgetOnly() {
        var ledger = PromptLedger.Snapshot.empty
        ledger.noteSpoke(.news, at: now, activeDays: 10)
        let whatsNew = candidate("whatsNew", .launchSheet, .news, bypassesBudget: true)

        XCTAssertTrue(PromptArbiter.isAllowed(whatsNew, in: context(ledger: ledger)))
        XCTAssertFalse(PromptArbiter.isAllowed(whatsNew, in: context(activity: .dormant, ledger: ledger)),
                       "예산을 건너뛰어도 휴면은 건너뛰지 못한다")
    }

    // MARK: - 원장

    func testLedgerRoundTripsByName() throws {
        var ledger = PromptLedger.Snapshot.empty
        ledger.noteSpoke(.money, at: now, activeDays: 4)
        ledger.noteDeclined(.ask, at: now)

        let data = try JSONEncoder().encode(ledger)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\"money\""), "차례 숫자가 아니라 이름으로 적는다")
        XCTAssertEqual(try JSONDecoder().decode(PromptLedger.Snapshot.self, from: data), ledger)
    }
}
