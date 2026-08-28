//
//  UsageStatsCacheTests.swift
//  ClipKeyboardTests
//
//  통계 증분 캐시의 합치기 규칙.
//
//  왜 시험하나: 증분은 "덜 받는" 대신 "합치기를 틀리면 숫자가 조용히 어긋나는" 방식이다.
//  설치를 두 번 세거나(중복), 오래전에 깔고 오늘 온 사람을 빠뜨리거나, 물때가 뒤로
//  물러나 같은 것을 계속 다시 받는 것이 여기서 잡힌다. 네트워크는 건드리지 않는다.
//

import XCTest
@testable import ClipKeyboard

final class UsageStatsCacheTests: XCTestCase {

    private func row(_ id: String, active: Date) -> UsageStatsSnapshotCache.Row {
        .init(id: id, appVersion: "5.0.5", platform: "iOS", osVersion: "26", locale: "ko",
              launchCount: 1, eventCount: 1, daysSinceInstall: 1,
              installDate: nil, lastActiveAt: active, metrics: [:])
    }

    private func event(_ name: String, install: String, at: Date, created: Date? = nil) -> UsageStatsSnapshotCache.Event {
        .init(name: name, installID: install, date: at, createdAt: created ?? at)
    }

    // MARK: - 스냅샷은 설치마다 한 줄

    func testSameInstallIsReplacedNotDuplicated() {
        let old = [row("A", active: Date(timeIntervalSince1970: 100)),
                   row("B", active: Date(timeIntervalSince1970: 200))]
        let fresh = [row("A", active: Date(timeIntervalSince1970: 999))]

        let merged = UsageStatsCache.merged(snapshots: old, with: fresh)

        XCTAssertEqual(merged.count, 2, "같은 설치가 두 번 세어지면 사용자 수가 부풀려진다")
        XCTAssertEqual(merged.first?.id, "A", "새로 활동한 설치가 앞에 온다")
        XCTAssertEqual(merged.first?.lastActiveAt, Date(timeIntervalSince1970: 999), "새것이 이겨야 한다")
    }

    func testNewInstallIsAdded() {
        let merged = UsageStatsCache.merged(snapshots: [row("A", active: Date(timeIntervalSince1970: 100))],
                                            with: [row("C", active: Date(timeIntervalSince1970: 300))])
        XCTAssertEqual(Set(merged.map(\.id)), ["A", "C"])
    }

    // MARK: - 이벤트는 덧붙되 겹치지 않게

    func testDuplicateEventFromWatermarkBoundaryIsDropped() {
        let at = Date(timeIntervalSince1970: 500)
        let old = [event("app_open", install: "i1", at: at)]
        let fresh = [event("app_open", install: "i1", at: at),      // 물때 경계에서 다시 온 것
                     event("memo_created", install: "i1", at: at)]

        let merged = UsageStatsCache.merged(events: old, with: fresh)

        XCTAssertEqual(merged.count, 2, "같은 이벤트가 두 번 들어오면 건수가 부풀려진다")
    }

    func testOldestEventsAreDroppedAtTheLimit() {
        let base = Date(timeIntervalSince1970: 0)
        let old = (0..<5).map { event("e", install: "i", at: base.addingTimeInterval(Double($0))) }
        let fresh = [event("e", install: "i", at: base.addingTimeInterval(100))]

        let merged = UsageStatsCache.merged(events: old, with: fresh, limit: 3)

        XCTAssertEqual(merged.count, 3)
        XCTAssertEqual(merged.first?.date, base.addingTimeInterval(100), "최근 것이 남아야 한다")
        XCTAssertFalse(merged.contains { $0.date == base }, "가장 오래된 것이 먼저 버려진다")
    }

    // MARK: - 물때는 앞으로만 간다

    func testWatermarkMovesForward() {
        let old = Date(timeIntervalSince1970: 100)
        let next = UsageStatsCache.advanced(old, with: [Date(timeIntervalSince1970: 300),
                                                        Date(timeIntervalSince1970: 200)])
        XCTAssertEqual(next, Date(timeIntervalSince1970: 300))
    }

    func testWatermarkNeverGoesBackward() {
        let old = Date(timeIntervalSince1970: 500)
        let next = UsageStatsCache.advanced(old, with: [Date(timeIntervalSince1970: 100)])
        XCTAssertEqual(next, old, "뒤로 물러나면 이미 받은 것을 계속 다시 받는다")
    }

    func testWatermarkStaysWhenNothingArrived() {
        let old = Date(timeIntervalSince1970: 500)
        XCTAssertEqual(UsageStatsCache.advanced(old, with: []), old)
        XCTAssertNil(UsageStatsCache.advanced(nil, with: [nil, nil]))
    }
}
