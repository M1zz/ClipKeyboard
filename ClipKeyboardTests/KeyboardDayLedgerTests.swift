//
//  KeyboardDayLedgerTests.swift
//  ClipKeyboardTests
//
//  키보드 활동일 원장 테스트 - 앱을 안 여는 사람의 활동을 소급 복원하는 경로다.
//   · 같은 날은 한 칸에 모이고, 날이 바뀌면 칸이 갈린다 (활동일이 뭉치지 않는지)
//   · 보관 한도를 넘으면 **오래된 날부터** 버린다
//   · 전송이 확정된 날만 지워진다 (실패한 날이 유실되지 않는지)
//   · 날짜 키 ↔ 시각 왕복이 시간대가 달라져도 하루씩 밀리지 않는지
//
//  ⚠️ 실제 CloudKit 전송은 여기서 검증하지 않는다 - 네트워크 없이 확인 가능한 정책만.
//

import XCTest
@testable import ClipKeyboard

final class KeyboardDayLedgerTests: XCTestCase {

    private var defaults: UserDefaults! { UserDefaults(suiteName: AppGroup.identifier) }

    override func setUp() {
        super.setUp()
        defaults.removeObject(forKey: DefaultsKey.kbBeaconDayCounts)
    }

    override func tearDown() {
        defaults.removeObject(forKey: DefaultsKey.kbBeaconDayCounts)
        super.tearDown()
    }

    private func counts() -> [String: Int] {
        (defaults.dictionary(forKey: DefaultsKey.kbBeaconDayCounts) as? [String: Int]) ?? [:]
    }

    // MARK: - 날짜별로 갈리는가

    func testUsesOnSameDayCollapseIntoOneEntry() {
        // ⚠️ `Date()` 를 기준으로 시간을 더하면 **자정 근처에서 날이 바뀌어** 테스트가
        //    가끔 깨진다(실제로 23시에 한 번 깨졌다). 하루 안쪽을 확실히 지키도록 정오에 맞춘다.
        let day = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        KeyboardDayLedger.recordUse(at: day)
        KeyboardDayLedger.recordUse(at: day.addingTimeInterval(60))
        KeyboardDayLedger.recordUse(at: day.addingTimeInterval(3600))

        XCTAssertEqual(counts().count, 1, "같은 날은 한 칸이어야 한다")
        XCTAssertEqual(counts()[KeyboardDayLedger.dayKey(for: day)], 3)
    }

    /// 이 테스트가 이 기능의 존재 이유다 - 예전 카운터 하나로는 아래 3일이 구분되지 않았다.
    func testUsesOnDifferentDaysStaySeparate() {
        let now = Date()
        let days = [now, now.addingTimeInterval(-86_400), now.addingTimeInterval(-2 * 86_400)]
        for day in days { KeyboardDayLedger.recordUse(at: day) }

        XCTAssertEqual(counts().count, 3)
        XCTAssertEqual(KeyboardDayLedger.pendingDays(), days.map { KeyboardDayLedger.dayKey(for: $0) }.sorted(),
                       "pendingDays는 오래된 순으로 나와야 소급 전송이 시간 순서대로 나간다")
    }

    // MARK: - 보관 한도

    func testLedgerPrunesOldestDaysBeyondLimit() {
        let now = Date()
        // 한도보다 5일 많게 쌓는다 (오늘부터 과거로)
        for offset in 0..<(KeyboardDayLedger.maxDays + 5) {
            KeyboardDayLedger.recordUse(at: now.addingTimeInterval(-Double(offset) * 86_400))
        }

        let remaining = KeyboardDayLedger.pendingDays()
        XCTAssertEqual(remaining.count, KeyboardDayLedger.maxDays)
        XCTAssertEqual(remaining.last, KeyboardDayLedger.dayKey(for: now),
                       "가장 최근 날은 남아야 한다")
        XCTAssertFalse(remaining.contains(KeyboardDayLedger.dayKey(for: now.addingTimeInterval(-Double(KeyboardDayLedger.maxDays + 4) * 86_400))),
                       "한도를 넘으면 가장 오래된 날부터 버린다")
    }

    // MARK: - 전송 확정분만 지우기

    func testRemoveDaysOnlyDropsListedDays() {
        let now = Date()
        let older = now.addingTimeInterval(-86_400)
        KeyboardDayLedger.recordUse(at: now)
        KeyboardDayLedger.recordUse(at: older)

        // 오래된 하루만 전송에 성공한 상황
        KeyboardDayLedger.removeDays([KeyboardDayLedger.dayKey(for: older)])

        XCTAssertEqual(KeyboardDayLedger.pendingDays(), [KeyboardDayLedger.dayKey(for: now)],
                       "보내지 못한 날은 원장에 남아 다음 기회에 다시 시도돼야 한다")
    }

    func testRemoveDaysWithEmptyListKeepsLedgerIntact() {
        KeyboardDayLedger.recordUse(at: Date())
        KeyboardDayLedger.removeDays([])
        XCTAssertEqual(counts().count, 1, "전송이 한 건도 확정되지 않았으면 아무것도 지우면 안 된다")
    }

    // MARK: - 날짜 키 ↔ 시각

    func testDayKeyIsZeroPaddedAndSortsChronologically() {
        var components = DateComponents()
        components.year = 2026; components.month = 3; components.day = 7
        let march7 = Calendar.current.date(from: components)!
        XCTAssertEqual(KeyboardDayLedger.dayKey(for: march7), "2026-03-07",
                       "사전순 정렬이 시간순 정렬이 되려면 0으로 채워야 한다")

        components.month = 12; components.day = 25
        let december25 = Calendar.current.date(from: components)!
        XCTAssertTrue(KeyboardDayLedger.dayKey(for: march7) < KeyboardDayLedger.dayKey(for: december25))
    }

    func testDateFromDayKeyRoundTripsToSameDay() {
        let now = Date()
        let key = KeyboardDayLedger.dayKey(for: now)
        guard let restored = KeyboardDayLedger.date(fromDayKey: key) else {
            return XCTFail("방금 만든 키는 다시 시각으로 읽혀야 한다")
        }
        XCTAssertEqual(KeyboardDayLedger.dayKey(for: restored), key)
    }

    /// 정오로 환산하는 이유 - 기록한 기기와 집계를 보는 기기의 시간대가 달라도
    /// 앞뒤 날짜로 넘어가면 안 된다. 자정으로 잡으면 조금만 밀려도 전날이 된다.
    ///
    /// 기준을 UTC로 고정해 테스트가 도는 기기의 시간대에 좌우되지 않게 한다.
    /// (±12시간이 정오가 버틸 수 있는 한계라, 현실적인 어긋남 폭인 ±11시간까지 확인한다)
    func testDateFromDayKeyStaysOnSameDayAcrossTimezoneShift() {
        var utc = Calendar.current
        utc.timeZone = TimeZone(identifier: "UTC")!

        let key = "2026-06-15"
        guard let noon = KeyboardDayLedger.date(fromDayKey: key, calendar: utc) else {
            return XCTFail("유효한 키를 읽지 못했다")
        }

        for hoursFromGMT in [-11, -5, 0, 5, 11] {
            var viewer = Calendar.current
            viewer.timeZone = TimeZone(secondsFromGMT: hoursFromGMT * 3600)!
            XCTAssertEqual(KeyboardDayLedger.dayKey(for: noon, calendar: viewer), key,
                           "UTC\(hoursFromGMT >= 0 ? "+" : "")\(hoursFromGMT)에서 봐도 같은 날이어야 한다")
        }
    }

    func testDateFromMalformedDayKeyReturnsNil() {
        XCTAssertNil(KeyboardDayLedger.date(fromDayKey: "not-a-date"))
        XCTAssertNil(KeyboardDayLedger.date(fromDayKey: "2026-06"))
        XCTAssertNil(KeyboardDayLedger.date(fromDayKey: ""))
    }
}
