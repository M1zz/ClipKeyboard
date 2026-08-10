//
//  UsageInsightsTests.swift
//  ClipKeyboardTests
//
//  퍼널·리텐션 집계 규칙을 고정한다. 전부 순수 함수라 네트워크 없이 검증된다.
//
//  특히 틀리기 쉬운 두 지점을 못 박는다:
//   ① 이벤트 이름에 붙는 슬라이스(`paywall_view:memo`)를 같은 단계로 셀 것
//   ② 아직 오지 않은 날(D7 전에 조회)은 **이탈로 세지 말 것** - 세면 리텐션이
//      실제보다 낮게 나와 잘못된 결론으로 이어진다
//

import XCTest
@testable import ClipKeyboard

final class UsageInsightsTests: XCTestCase {

    private func sample(_ name: String, _ install: String, _ date: Date = Date())
        -> UsageReportingService.EventSample {
        UsageReportingService.EventSample(name: name, installID: install, date: date)
    }

    // MARK: - 퍼널

    func testFunnelCountsDistinctInstallsPerStage() {
        let samples = [
            sample("paywall_view", "A"), sample("paywall_view", "B"), sample("paywall_view", "C"),
            sample("paywall_cta_tapped", "A"), sample("paywall_cta_tapped", "B"),
            sample("paywall_purchase", "A")
        ]

        let stages = UsageInsights.paywallFunnel(from: samples)

        XCTAssertEqual(stages.count, 3)
        XCTAssertEqual(stages[0].installs, 3)
        XCTAssertEqual(stages[1].installs, 2)
        XCTAssertEqual(stages[2].installs, 1)
    }

    /// 같은 설치가 여러 번 남겨도 1로 센다(설치 수 기준).
    func testFunnelDeduplicatesSameInstall() {
        let samples = [sample("paywall_view", "A"), sample("paywall_view", "A"), sample("paywall_view", "A")]

        XCTAssertEqual(UsageInsights.paywallFunnel(from: samples)[0].installs, 1)
    }

    /// ⚠️ 슬라이스가 붙은 이름(`paywall_view:memo`)도 같은 단계로 센다.
    /// 이걸 놓치면 페이월 노출이 대부분 누락돼 전환율이 비정상적으로 높게 보인다.
    func testFunnelCountsSlicedEventNames() {
        let samples = [
            sample("paywall_view:memo", "A"),
            sample("paywall_view:combo", "B"),
            sample("paywall_view", "C")
        ]

        XCTAssertEqual(UsageInsights.paywallFunnel(from: samples)[0].installs, 3)
    }

    func testFunnelRates() {
        let samples = [
            sample("paywall_view", "A"), sample("paywall_view", "B"),
            sample("paywall_view", "C"), sample("paywall_view", "D"),
            sample("paywall_cta_tapped", "A"), sample("paywall_cta_tapped", "B"),
            sample("paywall_purchase", "A")
        ]

        let stages = UsageInsights.paywallFunnel(from: samples)

        XCTAssertEqual(stages[0].rateFromTop, 1.0, accuracy: 0.001)
        XCTAssertEqual(stages[1].rateFromTop, 0.5, accuracy: 0.001)   // 2/4
        XCTAssertEqual(stages[2].rateFromTop, 0.25, accuracy: 0.001)  // 1/4
        XCTAssertEqual(stages[2].rateFromPrevious, 0.5, accuracy: 0.001) // 1/2
    }

    /// 표본이 없어도 0으로 나눠 크래시하지 않아야 한다.
    func testFunnelHandlesEmptySamples() {
        let stages = UsageInsights.paywallFunnel(from: [])

        XCTAssertEqual(stages.count, 3)
        XCTAssertTrue(stages.allSatisfy { $0.installs == 0 })
        XCTAssertEqual(stages[1].rateFromTop, 0)
    }

    func testDropoffReasonsCounted() {
        let samples = [
            sample("paywall_dismissed", "A"), sample("paywall_dismissed", "B"),
            sample("purchase_cancelled", "C"),
            sample("purchase_failed:network", "D")   // 슬라이스도 포함
        ]

        let reasons = UsageInsights.dropoffReasons(from: samples)

        XCTAssertEqual(reasons[0].count, 2)  // 그냥 닫음
        XCTAssertEqual(reasons[1].count, 1)  // 결제 취소
        XCTAssertEqual(reasons[2].count, 1)  // 결제 실패
    }

    // MARK: - 리텐션

    private func makeCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// D1 잔존: 설치 다음날 app_open 이 있으면 잔존.
    func testDay1Retention() throws {
        let cal = makeCalendar()
        let installedAt = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let nextDay = try XCTUnwrap(cal.date(byAdding: .day, value: 1, to: installedAt))
        let now = try XCTUnwrap(cal.date(byAdding: .day, value: 40, to: installedAt))

        let installs = [UsageInsights.Install(id: "A", installDate: installedAt)]
        let events = [sample(UsageReportingService.appOpenEvent, "A", nextDay)]

        let rows = UsageInsights.weeklyRetention(installs: installs, events: events,
                                                 calendar: cal, now: now)

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].size, 1)
        XCTAssertEqual(rows[0].day1, 1)
        XCTAssertEqual(rows[0].day7, 0)
    }

    /// ⚠️ 아직 D7이 오지 않았으면 이탈이 아니다 - 0으로 세되, 그건 "아직 모름"이다.
    /// (이 테스트는 미래 날짜를 잔존으로 잘못 세지 않는지를 본다.)
    func testFutureDaysAreNotCountedAsRetained() throws {
        let cal = makeCalendar()
        let installedAt = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let now = try XCTUnwrap(cal.date(byAdding: .day, value: 2, to: installedAt))  // D7 이전
        let day7 = try XCTUnwrap(cal.date(byAdding: .day, value: 7, to: installedAt))

        let installs = [UsageInsights.Install(id: "A", installDate: installedAt)]
        // 미래(D7)에 이벤트가 있더라도 now 이후이므로 세지 않는다.
        let events = [sample(UsageReportingService.appOpenEvent, "A", day7)]

        let rows = UsageInsights.weeklyRetention(installs: installs, events: events,
                                                 calendar: cal, now: now)

        XCTAssertEqual(rows[0].day7, 0, "아직 오지 않은 날은 잔존으로 세면 안 된다")
    }

    /// installDate 가 없는 스냅샷은 코호트에서 제외한다(분모를 오염시키지 않게).
    func testSnapshotsWithoutInstallDateAreIgnored() {
        let rows = UsageInsights.weeklyRetention(installs: [UsageInsights.Install(id: "A", installDate: nil)],
                                                 events: [], calendar: makeCalendar(), now: Date())

        XCTAssertTrue(rows.isEmpty)
    }

    func testRateHandlesZeroSize() {
        let row = UsageInsights.RetentionRow(cohortStart: Date(), size: 0, day1: 0, day7: 0, day30: 0)

        XCTAssertEqual(row.rate(row.day1), 0)
    }
}
