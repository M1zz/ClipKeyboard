//
//  RemoteFlagsServiceTests.swift
//  ClipKeyboardTests
//
//  원격 킬스위치의 **안전 기본값**을 고정한다.
//
//  가장 중요한 규칙: 값을 모르면 "켬"이다.
//  이게 뒤집히면 네트워크 장애나 CloudKit 권한 문제만으로 사용자 기능이 꺼져,
//  킬스위치가 장애를 막는 대신 장애를 만든다.
//

import XCTest
@testable import ClipKeyboard

final class RemoteFlagsServiceTests: XCTestCase {

    private var defaults: UserDefaults!
    private let prefix = "remote.flag."

    override func setUp() {
        super.setUp()
        defaults = AppGroup.defaults
        clearFlags()
    }

    override func tearDown() {
        clearFlags()
        super.tearDown()
    }

    private func clearFlags() {
        for flag in RemoteFlagsService.Flag.allCases {
            defaults.removeObject(forKey: prefix + flag.rawValue)
        }
    }

    // MARK: - 안전 기본값

    /// 캐시가 비어 있으면(설치 직후, 한 번도 못 받아본 상태) 전부 켬이어야 한다.
    func testDefaultsToEnabledWhenNoCache() {
        for flag in RemoteFlagsService.Flag.allCases {
            XCTAssertTrue(RemoteFlagsService.cachedValue(flag),
                          "\(flag.rawValue): 캐시가 없으면 켬이어야 한다")
        }
    }

    /// 캐시에 false가 있으면 그 값을 따른다(= 실제로 꺼진다).
    func testRespectsCachedDisabledValue() {
        defaults.set(false, forKey: prefix + RemoteFlagsService.Flag.syncEnabled.rawValue)

        XCTAssertFalse(RemoteFlagsService.cachedValue(.syncEnabled))
        // 다른 플래그는 영향을 받지 않는다.
        XCTAssertTrue(RemoteFlagsService.cachedValue(.paywallEnabled))
    }

    /// 캐시에 true가 있으면 켬.
    func testRespectsCachedEnabledValue() {
        defaults.set(true, forKey: prefix + RemoteFlagsService.Flag.paywallEnabled.rawValue)

        XCTAssertTrue(RemoteFlagsService.cachedValue(.paywallEnabled))
    }

    /// 플래그는 서로 독립이어야 한다 - 하나를 끈다고 다른 게 꺼지면 사고가 커진다.
    func testFlagsAreIndependent() {
        defaults.set(false, forKey: prefix + RemoteFlagsService.Flag.usageReportingEnabled.rawValue)

        XCTAssertFalse(RemoteFlagsService.cachedValue(.usageReportingEnabled))
        XCTAssertTrue(RemoteFlagsService.cachedValue(.syncEnabled))
        XCTAssertTrue(RemoteFlagsService.cachedValue(.paywallEnabled))
    }

    // MARK: - 계약

    /// 원격 필드 이름은 CloudKit Dashboard에 만든 필드명과 **정확히** 같아야 한다.
    /// 이름을 바꾸면 대시보드에서 아무리 꺼도 앱은 켠 채로 동작한다(조용한 실패).
    func testFlagRawValuesMatchDashboardFieldNames() {
        XCTAssertEqual(RemoteFlagsService.Flag.syncEnabled.rawValue, "syncEnabled")
        XCTAssertEqual(RemoteFlagsService.Flag.usageReportingEnabled.rawValue, "usageReportingEnabled")
        XCTAssertEqual(RemoteFlagsService.Flag.paywallEnabled.rawValue, "paywallEnabled")
        XCTAssertEqual(RemoteFlagsService.Flag.allCases.count, 3,
                       "플래그를 추가했다면 docs/product/MATURITY_TODO.md 와 대시보드 필드도 함께 갱신할 것")
    }
}
