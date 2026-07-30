//
//  ExperimentServiceTests.swift
//  ClipKeyboardTests
//
//  A/B 배정이 갖춰야 할 성질을 고정한다.
//
//  실험 데이터를 통째로 무의미하게 만드는 실패는 두 가지다:
//   ① 배정이 실행마다 바뀜 → 같은 사람이 A였다 B였다 하며 두 그룹 모두를 오염시킨다
//   ② 실험끼리 상관이 생김 → 어떤 설치가 모든 실험에서 늘 A에 배정되면
//      "A 그룹 = 특정 사용자 집단"이 되어 비교가 성립하지 않는다
//

import XCTest
@testable import ClipKeyboard

final class ExperimentServiceTests: XCTestCase {

    private let key = ExperimentService.installIDKey
    private var saved: String?

    override func setUp() {
        super.setUp()
        saved = UserDefaults.standard.string(forKey: key)
    }

    override func tearDown() {
        if let saved {
            UserDefaults.standard.set(saved, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
        super.tearDown()
    }

    // MARK: - ① 안정성

    /// 같은 설치 ID면 몇 번을 물어도 같은 그룹이어야 한다.
    func testVariantIsStableForSameInstall() {
        UserDefaults.standard.set("11111111-2222-3333-4444-555555555555", forKey: key)

        let first = ExperimentService.variant(for: .paywallCopy)
        for _ in 0..<20 {
            XCTAssertEqual(ExperimentService.variant(for: .paywallCopy), first,
                           "같은 설치는 항상 같은 그룹이어야 한다")
        }
    }

    /// 설치 ID를 못 읽으면 대조군(a)으로 떨어진다 — 실험 대상에서 조용히 빠지는 게
    /// 잘못된 그룹에 넣는 것보다 안전하다.
    func testFallsBackToControlWithoutInstallID() {
        UserDefaults.standard.removeObject(forKey: key)

        XCTAssertEqual(ExperimentService.variant(for: .paywallCopy), .a)
    }

    // MARK: - ② 분포

    /// 설치가 여러 개면 두 그룹에 나뉘어야 한다. 한쪽으로 다 몰리면 해시가 망가진 것이다.
    /// (완벽한 50:50을 요구하지 않는다 — 표본 200에서 양쪽 모두 20% 이상이면 정상)
    func testVariantsAreDistributed() {
        var counts: [ExperimentService.Variant: Int] = [.a: 0, .b: 0]

        for i in 0..<200 {
            UserDefaults.standard.set("install-\(i)-\(i * 7919)", forKey: key)
            counts[ExperimentService.variant(for: .paywallCopy), default: 0] += 1
        }

        XCTAssertGreaterThan(counts[.a] ?? 0, 40, "A 그룹이 너무 적다 — 해시 편향 의심")
        XCTAssertGreaterThan(counts[.b] ?? 0, 40, "B 그룹이 너무 적다 — 해시 편향 의심")
        XCTAssertEqual((counts[.a] ?? 0) + (counts[.b] ?? 0), 200)
    }

    // MARK: - 슬라이스 계약

    /// 슬라이스 문자열이 바뀌면 이전 실험 데이터와 이어지지 않는다.
    func testSliceFormat() {
        UserDefaults.standard.set("fixed-install-id", forKey: key)

        let slice = ExperimentService.slice(for: .paywallCopy)

        XCTAssertTrue(slice.hasPrefix("exp_paywall_copy_"), "슬라이스 접두가 바뀌면 집계가 끊긴다")
        XCTAssertTrue(slice.hasSuffix("_a") || slice.hasSuffix("_b"))
    }

    /// 이벤트 이름 길이 상한(60자)을 넘지 않아야 한다 —
    /// `UsageReportingService.record` 가 앞 60자로 자르기 때문에 잘리면 그룹이 뭉개진다.
    func testSliceFitsEventNameLimit() {
        UserDefaults.standard.set("fixed-install-id", forKey: key)

        for experiment in ExperimentService.Experiment.allCases {
            let eventName = "paywall_view:\(ExperimentService.slice(for: experiment))"
            XCTAssertLessThanOrEqual(eventName.count, 60,
                                     "\(experiment.rawValue): 이벤트 이름이 잘려 그룹 구분이 사라진다")
        }
    }
}
