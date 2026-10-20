//
//  LaunchGuardBackgroundLaunchTests.swift
//  ClipKeyboardTests
//
//  화면 없이 깨어난 런치를 닫는 길(`LaunchGuard.closeIfBackgroundLaunch`)이
//  **첫 화면을 그리던 진짜 사고의 표식은 지우지 않는다**는 약속.
//
//   ① 씬이 붙어 있으면 표식을 그대로 둔다(첫 화면에서 멈춘 런치는 다음 런치가 알아봐야 한다)
//   ② 표식이 없으면 아무것도 쓰지 않는다
//
//  시험 호스트는 빈 화면 하나(씬 하나)를 띄우므로 ① 의 조건이 그대로 선다.
//

import XCTest
import UIKit
@testable import ClipKeyboard

@MainActor
final class LaunchGuardBackgroundLaunchTests: XCTestCase {

    private var defaults: UserDefaults { AppGroup.defaults ?? .standard }
    private var savedMarker: String?
    private var savedStreak: Any?

    override func setUp() async throws {
        savedMarker = defaults.string(forKey: DefaultsKey.launchStageInFlight)
        savedStreak = defaults.object(forKey: DefaultsKey.launchFailStreak)
    }

    override func tearDown() async throws {
        if let savedMarker {
            defaults.set(savedMarker, forKey: DefaultsKey.launchStageInFlight)
        } else {
            defaults.removeObject(forKey: DefaultsKey.launchStageInFlight)
        }
        if let savedStreak {
            defaults.set(savedStreak, forKey: DefaultsKey.launchFailStreak)
        } else {
            defaults.removeObject(forKey: DefaultsKey.launchFailStreak)
        }
    }

    func testKeepsFirstFrameMarkerWhenSceneIsConnected() throws {
        try XCTSkipIf(UIApplication.shared.connectedScenes.isEmpty, "시험 호스트에 씬이 없다")
        defaults.set("essential:first-frame", forKey: DefaultsKey.launchStageInFlight)

        LaunchGuard.closeIfBackgroundLaunch("test")

        XCTAssertEqual(defaults.string(forKey: DefaultsKey.launchStageInFlight), "essential:first-frame",
                       "씬이 붙은 런치의 표식을 지우면 첫 화면에서 멈춘 사고를 다음 런치가 못 알아본다")
    }

    func testDoesNothingWithoutMarker() {
        defaults.removeObject(forKey: DefaultsKey.launchStageInFlight)
        defaults.set(5, forKey: DefaultsKey.launchFailStreak)

        LaunchGuard.closeIfBackgroundLaunch("test")

        XCTAssertNil(defaults.string(forKey: DefaultsKey.launchStageInFlight))
        XCTAssertEqual(defaults.integer(forKey: DefaultsKey.launchFailStreak), 5,
                       "닫을 런치가 없으면 연속 실패 기록도 건드리지 않는다")
    }
}
