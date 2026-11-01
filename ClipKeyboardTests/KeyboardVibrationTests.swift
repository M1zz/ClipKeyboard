//
//  KeyboardVibrationTests.swift
//  ClipKeyboardTests
//
//  키보드 진동 끄기. 진동 자체는 시험이 느낄 수 없으니, 모든 진동이 보는 값을 지킨다.
//
//  ⚠️ 여기 시험 이름은 docs/engineering/USER_JOURNEYS.md 의 표에 걸려 있다.
//

import XCTest
@testable import ClipKeyboard

final class KeyboardVibrationTests: XCTestCase {

    /// 만진 적 없으면 지금까지처럼 울리고, 설정에서 끄면 키보드가 같은 값을 본다.
    func test_키보드_진동은_기본이_켬이고_끄면_꺼진다() {
        let key = KeyboardPrefs.vibrates.key
        let saved = AppGroup.defaults?.object(forKey: key)
        defer { AppGroup.defaults?.set(saved, forKey: key) }

        AppGroup.defaults?.removeObject(forKey: key)
        XCTAssertTrue(KeyboardHaptics.vibrates, "만진 적 없는 사람의 키보드는 달라지지 않는다")

        AppGroup.defaults?.set(false, forKey: key)
        XCTAssertFalse(KeyboardHaptics.vibrates, "끈 사람의 키보드는 울리지 않는다")

        AppGroup.defaults?.set(true, forKey: key)
        XCTAssertTrue(KeyboardHaptics.vibrates)
    }
}
