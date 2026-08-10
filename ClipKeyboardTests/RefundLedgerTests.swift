//
//  RefundLedgerTests.swift
//  ClipKeyboardTests
//
//  월 원장의 계약을 고정한다.
//
//  가장 중요한 세 지점:
//   ① **초와 횟수를 따로 쌓는다** - 초를 회당 금액으로 나눠 역산하면 문구를 고친 순간부터
//      "×N"이 어긋난다. 실제로 그래서 키를 하나 더 뒀다.
//   ② **기간은 월 단위뿐이다** - 월 원장에서 임의 구간을 뽑으면 그 달 전체가 딸려와
//      틀린 수를 찍는다. 정확하지 않은 기간은 아예 만들지 않았다.
//   ③ **원장 이전은 없다** - 예전부터 쓰던 사람의 지난달을 0원으로 찍으면 거짓말이라,
//      시작일을 남겨 영수증이 "여기서부터 셌다"고 밝힌다.
//

import XCTest
@testable import ClipKeyboard

final class RefundLedgerTests: XCTestCase {

    private var defaults: UserDefaults? { UserDefaults(suiteName: "group.com.Ysoup.TokenMemo") }

    /// 테스트가 쓰는 달들 - 시뮬레이터에 잔존값이 남으면 다음 실행을 깨뜨린다.
    private var touchedMonths: [Date] {
        let now = Date()
        return [now,
                Calendar.current.date(byAdding: .month, value: -1, to: now)!,
                Calendar.current.date(byAdding: .month, value: -40, to: now)!]
    }

    override func setUp() { super.setUp(); clear() }
    override func tearDown() { clear(); super.tearDown() }

    private func clear() {
        guard let defaults else { return }
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("kb.ledger.") || key.hasPrefix("kb.usage.daily.") {
            defaults.removeObject(forKey: key)
        }
    }

    private func stamp(_ date: Date, _ format: String) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = format
        return f.string(from: date)
    }

    // MARK: - 쌓기

    func testRecordAccumulatesSecondsAndUsesSeparately() {
        let id = UUID()
        RefundLedger.record(memoID: id, seconds: 9)
        RefundLedger.record(memoID: id, seconds: 9)
        RefundLedger.record(memoID: id, seconds: 3)

        XCTAssertEqual(RefundLedger.entries(forMonthOf: Date())[id], 21)
        XCTAssertEqual(RefundLedger.uses(forMonthOf: Date())[id], 3, "횟수는 금액과 따로 센다")
    }

    func testDifferentMemosAreKeptApart() {
        let a = UUID(), b = UUID()
        RefundLedger.record(memoID: a, seconds: 10)
        RefundLedger.record(memoID: b, seconds: 40)

        let entries = RefundLedger.entries(forMonthOf: Date())
        XCTAssertEqual(entries[a], 10)
        XCTAssertEqual(entries[b], 40)
        XCTAssertEqual(RefundLedger.total(forMonthOf: Date()), 50)
    }

    func testMonthsAreKeptApart() {
        let id = UUID()
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())!

        RefundLedger.record(memoID: id, seconds: 10, on: Date())
        RefundLedger.record(memoID: id, seconds: 999, on: lastMonth)

        XCTAssertEqual(RefundLedger.total(forMonthOf: Date()), 10)
        XCTAssertEqual(RefundLedger.total(forMonthOf: lastMonth), 999)
    }

    func testZeroEarningStillMarksTheStartButAddsNothing() {
        // 벌이가 0이어도 "언제부터 셌나"는 사실이라 남긴다.
        RefundLedger.record(memoID: UUID(), seconds: 0)

        XCTAssertNotNil(RefundLedger.startedAt, "시작일은 금액과 무관하게 남아야 한다")
        XCTAssertEqual(RefundLedger.total(forMonthOf: Date()), 0)
    }

    func testStartedAtDoesNotMoveOnLaterWrites() {
        let old = Date(timeIntervalSince1970: 1_700_000_000)
        RefundLedger.record(memoID: UUID(), seconds: 5, on: old)
        let first = RefundLedger.startedAt

        RefundLedger.record(memoID: UUID(), seconds: 5, on: Date())

        XCTAssertEqual(RefundLedger.startedAt, first, "시작일은 처음 한 번만 찍힌다")
    }

    // MARK: - 읽기

    func testEmptyMonthReadsAsZeroNotNil() {
        let untouched = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        XCTAssertEqual(RefundLedger.total(forMonthOf: untouched), 0)
        XCTAssertTrue(RefundLedger.entries(forMonthOf: untouched).isEmpty)
    }

    func testUseCountSumsDailyKeysAcrossTheMonth() {
        guard let defaults else { return XCTFail("App Group 없음") }
        let now = Date()
        guard let interval = Calendar.current.dateInterval(of: .month, for: now) else {
            return XCTFail("달 구간 없음")
        }
        // 이 달의 첫날과 오늘에 각각 기록.
        defaults.set(3, forKey: "kb.usage.daily." + stamp(interval.start, "yyyy-MM-dd"))
        defaults.set(4, forKey: "kb.usage.daily." + stamp(now, "yyyy-MM-dd"))

        let expected = stamp(interval.start, "yyyy-MM-dd") == stamp(now, "yyyy-MM-dd") ? 4 : 7
        XCTAssertEqual(RefundLedger.useCount(forMonthOf: now), expected)
    }

    // MARK: - 청소

    func testPruneRemovesOldMonthsAndKeepsRecentOnes() {
        let id = UUID()
        let ancient = Calendar.current.date(byAdding: .month, value: -40, to: Date())!

        RefundLedger.record(memoID: id, seconds: 50, on: ancient)
        RefundLedger.record(memoID: id, seconds: 50, on: Date())
        XCTAssertEqual(RefundLedger.total(forMonthOf: ancient), 50)

        let removed = RefundLedger.pruneIfNeeded()

        XCTAssertGreaterThan(removed, 0)
        XCTAssertEqual(RefundLedger.total(forMonthOf: ancient), 0, "40개월 전은 지워진다")
        XCTAssertEqual(RefundLedger.total(forMonthOf: Date()), 50, "이번 달은 남는다")
    }

    func testPruneRunsOnlyOncePerDay() {
        XCTAssertGreaterThanOrEqual(RefundLedger.pruneIfNeeded(), 0)
        // 두 번째 호출은 곧바로 빠져나온다 - 켤 때마다 전체 사전을 훑으면 안 된다.
        XCTAssertEqual(RefundLedger.pruneIfNeeded(), 0)
    }

    // MARK: - 기간

    func testThisMonthAndLastMonthPointAtDifferentMonths() {
        let now = Date(timeIntervalSince1970: 1_770_000_000)
        let this = RefundPeriod.thisMonth.month(from: now)!
        let last = RefundPeriod.lastMonth.month(from: now)!

        XCTAssertEqual(stamp(this, "yyyy-MM"), stamp(now, "yyyy-MM"))
        XCTAssertNotEqual(stamp(last, "yyyy-MM"), stamp(this, "yyyy-MM"))
    }

    func testAllTimeHasNoMonth() {
        XCTAssertNil(RefundPeriod.allTime.month(from: Date()),
                     "전체는 특정 달이 아니다. 달을 주면 그 달 것만 세게 된다")
    }

    func testEveryPeriodHasAName() {
        for period in RefundPeriod.allCases {
            XCTAssertFalse(period.localizedName.isEmpty)
            XCTAssertFalse(period.label(from: Date()).isEmpty)
        }
    }
}
