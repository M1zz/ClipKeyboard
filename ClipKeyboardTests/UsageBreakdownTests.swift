//
//  UsageBreakdownTests.swift
//  ClipKeyboardTests
//
//  분포·종류·키보드·마케팅 집계를 고정한다.
//
//  이 숫자들은 제품 판단(가격·온보딩·마케팅)의 근거가 되므로, 틀리면 **틀린 결정을 부른다**.
//  특히 도넛은 "전체의 몫"을 그리므로 합이 전체를 넘지 않아야 한다.
//

import XCTest
@testable import ClipKeyboard

final class UsageBreakdownTests: XCTestCase {

    // MARK: - 단축어 개수 분포

    /// 구간 경계가 정확해야 한다 - 7·10 은 사용자가 직접 물어본 지점이다.
    func testDistributionBucketBoundaries() {
        let metrics: [[String: Double]] = [
            ["shortcuts": 0],   // 0개
            ["shortcuts": 3],   // 1–3
            ["shortcuts": 6],   // 4–6
            ["shortcuts": 7],   // 7–9  ← 경계
            ["shortcuts": 9],   // 7–9
            ["shortcuts": 10],  // 10–19 ← 경계
            ["shortcuts": 19],  // 10–19
            ["shortcuts": 20],  // 20+  ← 경계
            ["shortcuts": 500]  // 20+
        ]

        let buckets = UsageInsights.shortcutDistribution(metrics: metrics)

        XCTAssertEqual(buckets.count, 6)
        XCTAssertEqual(buckets[0].installs, 1, "0개")
        XCTAssertEqual(buckets[1].installs, 1, "1–3")
        XCTAssertEqual(buckets[2].installs, 1, "4–6")
        XCTAssertEqual(buckets[3].installs, 2, "7–9")
        XCTAssertEqual(buckets[4].installs, 2, "10–19")
        XCTAssertEqual(buckets[5].installs, 2, "20개 이상")
    }

    /// 모든 설치가 정확히 한 구간에만 속해야 한다(중복/누락 없음).
    func testDistributionCoversEveryInstallExactlyOnce() {
        let metrics = (0...50).map { ["shortcuts": Double($0)] }

        let total = UsageInsights.shortcutDistribution(metrics: metrics).reduce(0) { $0 + $1.installs }

        XCTAssertEqual(total, metrics.count)
    }

    /// 지표가 없는 옛 스냅샷은 0개로 잡힌다(크래시하지 않는다).
    func testDistributionHandlesMissingMetric() {
        let buckets = UsageInsights.shortcutDistribution(metrics: [[:]])

        XCTAssertEqual(buckets[0].installs, 1)
    }

    // MARK: - 종류 (도넛)

    /// ⚠️ 도넛은 "전체의 몫"이라 **합이 100%** 여야 한다.
    /// 수집 쪽에서 한 메모를 한 종류로만 세기 때문에 성립한다.
    func testTypeBreakdownRatiosSumToOne() {
        let metrics: [[String: Double]] = [
            ["texts": 10, "templates": 5, "combos": 3, "images": 2]
        ]

        let shares = UsageInsights.typeBreakdown(metrics: metrics)

        XCTAssertEqual(shares.reduce(0) { $0 + $1.ratio }, 1.0, accuracy: 0.0001)
        XCTAssertEqual(shares.reduce(0) { $0 + $1.count }, 20)
    }

    func testTypeBreakdownSumsAcrossInstalls() {
        let metrics: [[String: Double]] = [
            ["texts": 3, "templates": 1, "combos": 0, "images": 0],
            ["texts": 2, "templates": 0, "combos": 4, "images": 0]
        ]

        let shares = UsageInsights.typeBreakdown(metrics: metrics)

        XCTAssertEqual(shares.first(where: { $0.name == "텍스트" })?.count, 5)
        XCTAssertEqual(shares.first(where: { $0.name == "콤보" })?.count, 4)
    }

    /// 데이터가 없으면 빈 배열 - 0으로 나누지 않는다.
    func testTypeBreakdownEmptyWhenNoData() {
        XCTAssertTrue(UsageInsights.typeBreakdown(metrics: [["texts": 0]]).isEmpty)
        XCTAssertTrue(UsageInsights.typeBreakdown(metrics: []).isEmpty)
    }

    // MARK: - 키보드 사용량

    func testKeyboardAdoptionRate() {
        let metrics: [[String: Double]] = [
            ["flag.keyboardActive": 1, "keyboardUses": 100, "timeSavedMin": 30],
            ["flag.keyboardActive": 1, "keyboardUses": 50, "timeSavedMin": 10],
            ["flag.keyboardActive": 0, "keyboardUses": 0, "timeSavedMin": 0],
            ["flag.keyboardActive": 0]
        ]

        let usage = UsageInsights.keyboardUsage(metrics: metrics)

        XCTAssertEqual(usage.activeInstalls, 2)
        XCTAssertEqual(usage.totalInstalls, 4)
        XCTAssertEqual(usage.adoptionRate, 0.5, accuracy: 0.0001)
        XCTAssertEqual(usage.totalUses, 150)
        XCTAssertEqual(usage.totalTimeSavedMin, 40)
        XCTAssertEqual(usage.usesPerActiveInstall, 75, accuracy: 0.0001)
    }

    /// 아무도 안 켰으면 0으로 나누지 않는다.
    func testKeyboardUsageHandlesNoActiveInstalls() {
        let usage = UsageInsights.keyboardUsage(metrics: [["flag.keyboardActive": 0]])

        XCTAssertEqual(usage.adoptionRate, 0)
        XCTAssertEqual(usage.usesPerActiveInstall, 0)
    }

    func testKeyboardUsageHandlesEmptyInput() {
        let usage = UsageInsights.keyboardUsage(metrics: [])

        XCTAssertEqual(usage.totalInstalls, 0)
        XCTAssertEqual(usage.adoptionRate, 0)
    }

    // MARK: - 마케팅 지표

    func testMarketingSignalsComputeRates() {
        let metrics: [[String: Double]] = [
            ["flag.isPro": 1, "categories": 3, "clips": 5, "flag.syncOn": 1, "shortcuts": 10, "unusedShortcuts": 2],
            ["flag.isPro": 0, "categories": 0, "clips": 0, "flag.syncOn": 0, "shortcuts": 10, "unusedShortcuts": 8]
        ]

        let signals = UsageInsights.marketingSignals(metrics: metrics)
        func value(_ name: String) -> String? { signals.first(where: { $0.name == name })?.value }

        XCTAssertEqual(value("Pro 전환율"), "50%")
        XCTAssertEqual(value("카테고리 사용"), "50%")
        XCTAssertEqual(value("클립보드 사용"), "50%")
        XCTAssertEqual(value("동기화 사용"), "50%")
        // 안 쓰는 단축어는 **설치 평균이 아니라 전체 단축어 대비** 비율이다 - (2+8)/20
        XCTAssertEqual(value("안 쓰는 단축어"), "50%")
        XCTAssertEqual(value("설치당 단축어"), "10.0")
    }

    /// 표본이 없으면 빈 배열 - 0으로 나누지 않는다.
    func testMarketingSignalsEmptyWithoutSnapshots() {
        XCTAssertTrue(UsageInsights.marketingSignals(metrics: []).isEmpty)
    }

    /// 단축어가 0개면 "안 쓰는 비율"도 0% (0으로 나누지 않는다).
    func testUnusedRateHandlesZeroShortcuts() {
        let signals = UsageInsights.marketingSignals(metrics: [["shortcuts": 0, "unusedShortcuts": 0]])

        XCTAssertEqual(signals.first(where: { $0.name == "안 쓰는 단축어" })?.value, "0%")
    }
}
