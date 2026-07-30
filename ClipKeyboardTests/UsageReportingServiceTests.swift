//
//  UsageReportingServiceTests.swift
//  ClipKeyboardTests
//
//  익명 사용 통계(FeedbackHub 전송) 정책 테스트 — 네트워크 없이 검증 가능한 부분만.
//   · 같은 이벤트가 6시간 안에 두 번 나가지 않는지 (app_open은 20시간)
//   · 스냅샷 지표에 PII가 아닌 약속된 키만 담기는지
//   · AnalyticsService 훅이 이벤트 이름 + 슬라이스를 규약대로 넘기는지
//

import XCTest
@testable import ClipKeyboard

final class UsageReportingServiceTests: XCTestCase {

    private let eventName = "unit_test_event"
    private var throttleKey: String { DefaultsKey.usageEventLastSentPrefix + eventName }

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: throttleKey)
        AnalyticsService.eventSink = nil
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: throttleKey)
        AnalyticsService.eventSink = nil
        super.tearDown()
    }

    // MARK: - 쓰로틀

    func testEventThrottleRecordsTimestampOnce() {
        UsageReportingService.record(event: eventName)
        guard let first = UserDefaults.standard.object(forKey: throttleKey) as? Date else {
            return XCTFail("첫 전송에서 쓰로틀 시각이 기록돼야 한다")
        }
        // 6시간 창 안의 두 번째 호출은 시각을 갱신하지 않는다 (= 허브로 나가지 않는다)
        UsageReportingService.record(event: eventName)
        let second = UserDefaults.standard.object(forKey: throttleKey) as? Date
        XCTAssertEqual(first, second)
    }

    func testCustomThrottleIntervalIsRespected() {
        let key = DefaultsKey.usageEventLastSentPrefix + UsageReportingService.appOpenEvent
        defer { UserDefaults.standard.removeObject(forKey: key) }

        // 8시간 전 — 기본 6시간 창은 지났지만 app_open 의 20시간 창 안이라 다시 나가면 안 된다.
        let eightHoursAgo = Date(timeIntervalSinceNow: -8 * 3600)
        UserDefaults.standard.set(eightHoursAgo, forKey: key)

        UsageReportingService.record(event: UsageReportingService.appOpenEvent, minInterval: 20 * 3600)
        XCTAssertEqual(UserDefaults.standard.object(forKey: key) as? Date, eightHoursAgo)

        UsageReportingService.record(event: UsageReportingService.appOpenEvent, minInterval: 6 * 3600)
        XCTAssertNotEqual(UserDefaults.standard.object(forKey: key) as? Date, eightHoursAgo,
                          "6시간 창 기준으로는 다시 전송돼야 한다")
    }

    func testEventSentAgainAfterThrottleWindow() {
        let stale = Date(timeIntervalSinceNow: -7 * 3600)   // 6시간 창 밖
        UserDefaults.standard.set(stale, forKey: throttleKey)

        UsageReportingService.record(event: eventName)
        let updated = UserDefaults.standard.object(forKey: throttleKey) as? Date
        XCTAssertNotNil(updated)
        XCTAssertGreaterThan(updated ?? .distantPast, stale)
    }

    // MARK: - 스냅샷 지표

    func testMetricsContainOnlyAggregateKeys() {
        let metrics = UsageReportingService.currentMetrics()

        for key in ["shortcuts", "combos", "templates", "images", "favorites",
                    "uses", "timeSavedMin", "keyboardUses",
                    "flag.isPro", "flag.keyboardActive", "flag.syncOn"] {
            XCTAssertNotNil(metrics[key], "약속된 지표 키 \(key)가 빠졌다")
        }

        // 값은 전부 숫자이고 음수가 아니다 — 내용/식별자가 섞여 들어갈 여지가 없어야 한다.
        for (key, value) in metrics {
            XCTAssertGreaterThanOrEqual(value, 0, "\(key) 지표가 음수")
            XCTAssertTrue(value.isFinite, "\(key) 지표가 유한값이 아님")
        }

        // 0/1 플래그는 정확히 0 또는 1
        for key in ["flag.isPro", "flag.keyboardActive", "flag.syncOn"] {
            let value = metrics[key] ?? -1
            XCTAssertTrue(value == 0 || value == 1, "\(key)는 0/1 플래그여야 한다 (실제 \(value))")
        }

        // 페르소나는 있으면 persona.<rawValue> 형태의 플래그 한 개뿐
        let personaKeys = metrics.keys.filter { $0.hasPrefix("persona.") }
        XCTAssertLessThanOrEqual(personaKeys.count, 1)
        for key in personaKeys {
            XCTAssertNotNil(Persona(rawValue: String(key.dropFirst("persona.".count))),
                            "알 수 없는 페르소나 키: \(key)")
        }
    }

    // MARK: - AnalyticsService 훅

    func testAnalyticsSinkForwardsEventName() {
        var received: [String] = []
        AnalyticsService.eventSink = { received.append($0) }

        AnalyticsService.log(.memoCreated, parameters: [.memoType: "text", .memoCount: 3])
        XCTAssertEqual(received, ["memo_created"], "슬라이스가 없으면 이벤트 이름만 넘긴다")
    }

    func testAnalyticsSinkAppendsSlice() {
        var received: [String] = []
        AnalyticsService.eventSink = { received.append($0) }

        AnalyticsService.logPaywallView(triggeredBy: "memo")
        AnalyticsService.logProNudge(.proNudgeShown, source: "time_saved")

        XCTAssertEqual(received, ["paywall_view:memo", "pro_nudge_shown:time_saved"])
    }

    // MARK: - 이름별 집계

    func testEventStatsGroupsByNameAndCountsDistinctInstalls() {
        let now = Date()
        let samples = [
            UsageReportingService.EventSample(name: "memo_created", installID: "a", date: now),
            UsageReportingService.EventSample(name: "memo_created", installID: "a", date: now.addingTimeInterval(-60)),
            UsageReportingService.EventSample(name: "memo_created", installID: "b", date: now.addingTimeInterval(-120)),
            UsageReportingService.EventSample(name: "paywall_view:memo", installID: "b", date: now.addingTimeInterval(-30))
        ]

        let stats = UsageReportingService.eventStats(from: samples)
        XCTAssertEqual(stats.count, 2)
        XCTAssertEqual(stats.first?.name, "memo_created", "건수 많은 순으로 정렬")
        XCTAssertEqual(stats.first?.count, 3)
        XCTAssertEqual(stats.first?.installs, 2, "같은 설치의 반복은 설치 수로 세지 않는다")
        XCTAssertEqual(stats.first?.lastAt, now)
    }

    // MARK: - 기간별 추이 (차트 데이터)

    /// 테스트 재현성을 위해 그레고리력 + UTC 고정.
    private var fixedCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ iso: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: iso)!
    }

    func testTrendFillsEmptyBucketsBetweenData() {
        let events = [
            UsageReportingService.EventSample(name: "e", installID: "a", date: date("2026-03-01 10:00")),
            UsageReportingService.EventSample(name: "e", installID: "a", date: date("2026-03-04 09:00"))
        ]
        let points = UsageReportingService.trend(unit: .day, events: events, snapshots: [],
                                                 calendar: fixedCalendar, now: date("2026-03-04 23:00"))

        XCTAssertEqual(points.count, 4, "3/1 ~ 3/4 사이 빈 날도 채워야 차트가 끊기지 않는다")
        XCTAssertEqual(points.map(\.events), [1, 0, 0, 1])
    }

    func testTrendCountsDistinctInstallsPerBucket() {
        let events = [
            UsageReportingService.EventSample(name: "e", installID: "a", date: date("2026-03-01 01:00")),
            UsageReportingService.EventSample(name: "e", installID: "a", date: date("2026-03-01 20:00")),
            UsageReportingService.EventSample(name: "e", installID: "b", date: date("2026-03-01 22:00"))
        ]
        let points = UsageReportingService.trend(unit: .day, events: events, snapshots: [],
                                                 calendar: fixedCalendar, now: date("2026-03-01 23:00"))

        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points.first?.events, 3)
        XCTAssertEqual(points.first?.activeInstalls, 2, "하루 안의 같은 설치는 1명으로")
    }

    func testTrendGroupsByWeekMonthAndYear() {
        // 2026-03-02(월) ~ 2026-03-08(일) 이 한 주, 3/09 는 다음 주
        let events = [
            UsageReportingService.EventSample(name: "e", installID: "a", date: date("2026-03-02 10:00")),
            UsageReportingService.EventSample(name: "e", installID: "b", date: date("2026-03-05 10:00")),
            UsageReportingService.EventSample(name: "e", installID: "c", date: date("2026-03-09 10:00"))
        ]
        let now = date("2026-03-09 23:00")

        let weekly = UsageReportingService.trend(unit: .week, events: events, snapshots: [],
                                                 calendar: fixedCalendar, now: now)
        XCTAssertEqual(weekly.count, 2)
        XCTAssertEqual(weekly.map(\.events), [2, 1])

        let monthly = UsageReportingService.trend(unit: .month, events: events, snapshots: [],
                                                  calendar: fixedCalendar, now: now)
        XCTAssertEqual(monthly.count, 1)
        XCTAssertEqual(monthly.first?.events, 3)
        XCTAssertEqual(monthly.first?.activeInstalls, 3)

        let yearly = UsageReportingService.trend(unit: .year, events: events, snapshots: [],
                                                 calendar: fixedCalendar, now: now)
        XCTAssertEqual(yearly.count, 1)
        XCTAssertEqual(yearly.first?.events, 3)
    }

    func testTrendExtendsToTodayEvenWithoutRecentEvents() {
        let events = [UsageReportingService.EventSample(name: "e", installID: "a", date: date("2026-03-01 10:00"))]
        let points = UsageReportingService.trend(unit: .day, events: events, snapshots: [],
                                                 calendar: fixedCalendar, now: date("2026-03-05 08:00"))

        XCTAssertEqual(points.count, 5, "마지막 이벤트 이후 오늘까지도 0으로 이어져야 한다")
        XCTAssertEqual(points.last?.events, 0)
    }

    func testTrendIsEmptyWithoutData() {
        XCTAssertTrue(UsageReportingService.trend(unit: .day, events: [], snapshots: [],
                                                  calendar: fixedCalendar, now: Date()).isEmpty)
    }

    func testBucketUnitVisibleWindowsAreSane() {
        for unit in UsageReportingService.BucketUnit.allCases {
            XCTAssertGreaterThan(unit.visibleBuckets, 1, "\(unit.rawValue) 창이 너무 좁다")
            XCTAssertFalse(unit.localizedName.isEmpty)
        }
    }

    func testAnalyticsSinkNeverCarriesValues() {
        var received: [String] = []
        AnalyticsService.eventSink = { received.append($0) }

        // 실패 사유처럼 자유 문자열이 들어오는 이벤트도 이름/슬라이스만 나가야 한다.
        AnalyticsService.logPurchaseFailed(reason: "network timeout at user@example.com", triggeredBy: nil)
        XCTAssertEqual(received, ["purchase_failed"])
    }
}
