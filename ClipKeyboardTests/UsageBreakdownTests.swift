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
    /// 9는 **혼자 한 구간**이다(한 칸 남은 사람 수. 할인 제안이 겨냥하는 무리).
    func testDistributionBucketBoundaries() {
        let metrics: [[String: Double]] = [
            ["shortcuts": 0],   // 0개
            ["shortcuts": 3],   // 1~3
            ["shortcuts": 6],   // 4~6
            ["shortcuts": 7],   // 7~8  ← 경계
            ["shortcuts": 8],   // 7~8  ← 경계 (9로 새지 않아야 한다)
            ["shortcuts": 9],   // 9개   ← 단독 구간
            ["shortcuts": 10],  // 10~19 ← 경계
            ["shortcuts": 19],  // 10~19
            ["shortcuts": 20],  // 20+  ← 경계
            ["shortcuts": 500]  // 20+
        ]

        let buckets = UsageInsights.shortcutDistribution(metrics: metrics)

        XCTAssertEqual(buckets.count, 7)
        XCTAssertEqual(buckets[0].installs, 1, "0개")
        XCTAssertEqual(buckets[1].installs, 1, "1~3")
        XCTAssertEqual(buckets[2].installs, 1, "4~6")
        XCTAssertEqual(buckets[3].installs, 2, "7~8")
        XCTAssertEqual(buckets[4].installs, 1, "9개 단독")
        XCTAssertEqual(buckets[5].installs, 2, "10~19")
        XCTAssertEqual(buckets[6].installs, 2, "20개 이상")
    }

    /// 9개인 사람은 9 구간에만 잡히고 7~8 로 새지 않아야 한다 - 이 숫자로 제안을 띄울지 정한다.
    func testDistributionCountsExactlyNineOnItsOwn() {
        let metrics: [[String: Double]] = [
            ["shortcuts": 8], ["shortcuts": 9], ["shortcuts": 9], ["shortcuts": 10]
        ]

        let buckets = UsageInsights.shortcutDistribution(metrics: metrics)
        let nine = buckets.first { $0.lowerBound == 9 }

        XCTAssertEqual(nine?.installs, 2)
        XCTAssertEqual(buckets.first { $0.lowerBound == 7 }?.installs, 1)
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

    // MARK: - 사용 유형

    /// 한 사람은 **한 무리에만** 속해야 한다. 이게 깨지면 합이 전체를 넘어 비율이 거짓말이 된다.
    func testSegmentsCoverEveryInstallExactlyOnce() {
        let metrics: [[String: Double]] = [
            [:],                                                        // 아직 안 만듦
            ["shortcuts": 3],                                           // 만들고 안 씀
            ["shortcuts": 12, "uses": 80],                              // 많이 씀
            ["shortcuts": 2, "uses": 20],                               // 하나만 계속
            ["shortcuts": 10, "uses": 6, "unusedShortcuts": 9],         // 쌓아만 둠
            ["shortcuts": 5, "uses": 7],                                // 꾸준히
            ["shortcuts": 4, "uses": 2]                                 // 막 써 보는 중
        ]

        let segments = UsageInsights.userSegments(metrics: metrics)

        XCTAssertEqual(segments.reduce(0) { $0 + $1.installs }, metrics.count)
        XCTAssertEqual(segments.reduce(0.0) { $0 + $1.ratio }, 1.0, accuracy: 0.0001)
    }

    /// 무리를 가르는 기준이 흔들리면 다음 버전의 판단이 통째로 흔들린다.
    func testSegmentBoundaries() {
        func kind(_ m: [String: Double]) -> UsageInsights.SegmentKind { UsageInsights.classify(m) }

        XCTAssertEqual(kind([:]), .notStarted)
        XCTAssertEqual(kind(["shortcuts": 0, "uses": 99]), .notStarted, "만든 게 없으면 쓴 것도 없다")
        XCTAssertEqual(kind(["shortcuts": 5]), .lost, "만들고 한 번도 안 썼다")
        XCTAssertEqual(kind(["shortcuts": 5, "keyboardUses": 1]), .dabbling, "키보드로 쓴 것도 사용이다")
        XCTAssertEqual(kind(["shortcuts": 20, "uses": 50]), .heavy)
        XCTAssertEqual(kind(["shortcuts": 3, "uses": 10]), .oneTrick)
        XCTAssertEqual(kind(["shortcuts": 4, "uses": 10]), .regular, "4개부터는 '하나만'이 아니다")
        XCTAssertEqual(kind(["shortcuts": 10, "uses": 6, "unusedShortcuts": 7]), .hoarder)
        XCTAssertEqual(kind(["shortcuts": 10, "uses": 6, "unusedShortcuts": 6]), .regular,
                       "70% 미만이면 쌓아 둔 게 아니다")
    }

    /// 많이 쓰는 사람은 안 쓴 단축어가 많아도 헤비다. 쓰고 있다는 사실이 먼저다.
    func testHeavyWinsOverHoarder() {
        XCTAssertEqual(UsageInsights.classify(["shortcuts": 30, "uses": 200, "unusedShortcuts": 28]), .heavy)
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
