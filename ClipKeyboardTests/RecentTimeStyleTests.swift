//
//  RecentTimeStyleTests.swift
//  ClipKeyboardTests
//
//  '최근' 페이지의 복사한 때 표시. 얼마 전 · 날짜와 시간.
//  사용자 요청(2026-11, 중국어): "며칠 전" 은 별 뜻이 없다, 시간으로 보여 달라.
//

import XCTest
@testable import ClipKeyboard

final class RecentTimeStyleTests: XCTestCase {

    private let locale = Locale(identifier: "ko_KR")
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// 고른 적 없는 사람은 예전 그대로 얼마 전이고, 날짜와 시간을 고르면 정확한 때가 보인다.
    func test_고르기_전에는_얼마_전이고_날짜와_시간을_고르면_정확한_때가_보인다() {
        XCTAssertEqual(AppPrefs.recentTimeStyle.fallback, RecentTimeStyle.relative.rawValue)

        let now = date(2026, 11, 13, 18, 0)
        let threeDaysAgo = date(2026, 11, 10, 15, 42)

        let relative = RecentTimeStyle.relative.text(for: threeDaysAgo, now: now, calendar: calendar, locale: locale)
        XCTAssertTrue(relative.contains("3"), "얼마 전: \(relative)")
        XCTAssertFalse(relative.contains("42"), "얼마 전에는 시각이 없다: \(relative)")

        let exact = RecentTimeStyle.exact.text(for: threeDaysAgo, now: now, calendar: calendar, locale: locale)
        XCTAssertTrue(exact.contains("11월") && exact.contains("10일") && exact.contains("3:42"), "날짜와 시간: \(exact)")
    }

    /// 오늘 것은 시각만, 지난해 것은 연도까지. 같은 날짜가 해마다 겹치지 않게.
    func test_날짜와_시간은_오늘이면_시각만_지난해면_연도까지() {
        let now = date(2026, 11, 13, 18, 0)

        let today = RecentTimeStyle.exact.text(for: date(2026, 11, 13, 9, 5), now: now, calendar: calendar, locale: locale)
        XCTAssertTrue(today.contains("9:05"), today)
        XCTAssertFalse(today.contains("11월"), "오늘은 날짜를 적지 않는다: \(today)")

        let lastYear = RecentTimeStyle.exact.text(for: date(2025, 12, 31, 23, 10), now: now, calendar: calendar, locale: locale)
        XCTAssertTrue(lastYear.contains("2025"), lastYear)
    }
}
