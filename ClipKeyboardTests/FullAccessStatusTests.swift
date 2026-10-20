//
//  FullAccessStatusTests.swift
//  ClipKeyboardTests
//
//  설정에서 전체 접근을 켜고 돌아온 사람에게 "꺼짐" 이라고 말하지 않는다.
//

import XCTest
@testable import ClipKeyboard

final class FullAccessStatusTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_키보드가_켜짐을_적었으면_켜짐() {
        XCTAssertEqual(FullAccessStatus.state(granted: true, openedSettingsAt: nil, now: now), .on)
        XCTAssertEqual(FullAccessStatus.state(granted: true, openedSettingsAt: now, now: now), .on)
    }

    /// 키보드는 뜰 때만 값을 적는다. 설정에서 켜고 막 돌아온 사람은 아직 꺼짐으로 남아 있다.
    func test_설정을_열어_준_뒤에는_꺼졌다고_단정하지_않는다() {
        let opened = now.addingTimeInterval(-30)
        XCTAssertEqual(FullAccessStatus.state(granted: false, openedSettingsAt: opened, now: now), .checking)
    }

    func test_한참_지나도_키보드를_안_띄웠으면_꺼짐으로_돌아간다() {
        let opened = now.addingTimeInterval(-FullAccessStatus.checkingWindow - 1)
        XCTAssertEqual(FullAccessStatus.state(granted: false, openedSettingsAt: opened, now: now), .off)
    }

    func test_설정을_열어_준_적이_없으면_꺼짐() {
        XCTAssertEqual(FullAccessStatus.state(granted: false, openedSettingsAt: nil, now: now), .off)
    }
}
