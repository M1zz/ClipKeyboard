//
//  ActivationReportTests.swift
//  ClipKeyboardTests
//
//  키보드에 닿기까지 퍼널(`UsageInsights.activationReport`)의 세는 규칙을 고정한다.
//
//  못 박는 지점:
//   ① 새 지표(`state.level`)를 안 보낸 옛 스냅샷은 분모에서 뺀다 - "안 켰다"와 "안 보냈다"를 섞지 않는다
//   ② 비콘이 없어도 키보드 활동일 이벤트를 보낸 설치는 "떠 봄" 으로 센다
//   ③ 키보드 없이 앱에서만 꺼내 쓴 사람도 "꺼내 쓴 설치" 로 잡힌다
//

import XCTest
import LeeoKit
@testable import ClipKeyboard

final class ActivationReportTests: XCTestCase {

    private func snap(_ id: String,
                      installed: Date? = Date(),
                      _ metrics: [String: Double]) -> UsageReportingService.Snapshot {
        .init(id: id, appId: nil, appVersion: "5.1.6", platform: "iOS", osVersion: "26", locale: "ko",
              launchCount: 1, eventCount: 0, daysSinceInstall: 0,
              installDate: installed, lastActiveAt: nil, metrics: metrics)
    }

    func testLegacySnapshotsAreExcludedFromDenominator() {
        let report = UsageInsights.activationReport(
            snapshots: [
                snap("old", ["flag.keyboardActive": 0]),
                snap("new", ["state.level": 0, "flag.keyboardEnabled": 0])
            ],
            keyboardDayInstalls: [])

        XCTAssertEqual(report.counted, 1)
        XCTAssertEqual(report.legacy, 1)
        XCTAssertEqual(report.stages.first?.installs, 1)
    }

    func testKeyboardDayEventCountsAsAppearedWithoutBeacon() {
        let report = UsageInsights.activationReport(
            snapshots: [
                snap("A", ["state.level": 1, "flag.keyboardEnabled": 1, "flag.keyboardActive": 0]),
                snap("B", ["state.level": 1, "flag.keyboardEnabled": 1, "flag.keyboardActive": 1])
            ],
            keyboardDayInstalls: ["A"])

        XCTAssertEqual(report.stages.map(\.installs), [2, 2, 2, 0])
    }

    func testAppOnlyUsersReachValueWithoutKeyboard() {
        let report = UsageInsights.activationReport(
            snapshots: [
                snap("app", ["state.level": 2, "flag.keyboardEnabled": 0]),
                snap("kb", ["state.level": 3, "flag.keyboardEnabled": 1, "flag.keyboardActive": 1, "keyboardPastes": 5]),
                snap("made", ["state.level": 1])
            ],
            keyboardDayInstalls: [])

        XCTAssertEqual(report.reachedValue, 2)
        XCTAssertEqual(report.reachedValueAppOnly, 1)
    }

    func testWindowKeepsOnlyRecentInstalls() {
        let old = Date(timeIntervalSinceNow: -60 * 86_400)
        let report = UsageInsights.activationReport(
            snapshots: [
                snap("recent", ["state.level": 0]),
                snap("old", installed: old, ["state.level": 0])
            ],
            keyboardDayInstalls: [],
            installedSince: Date(timeIntervalSinceNow: -30 * 86_400))

        XCTAssertEqual(report.counted, 1)
    }
}
