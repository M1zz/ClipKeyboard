//
//  LaunchGuardBackgroundLaunchTests.swift
//  ClipKeyboardTests
//
//  화면 없이 깨어난 런치를 닫는 길(`LaunchGuard.closeIfBackgroundLaunch`)이
//  **첫 화면을 그리던 진짜 사고의 표식은 지우지 않는다**는 약속.
//
//   ① 씬이 붙어 있으면 표식을 그대로 둔다(첫 화면에서 멈춘 런치는 다음 런치가 알아봐야 한다)
//   ② 표식이 없으면 아무것도 쓰지 않는다
//   ③ 창을 기다리던 표식(`awaiting-scene`)은 멈춘 런치로 읽지 않는다. 나머지는 전부 멈춘 런치다
//   ④ 뒤로 가서 닫힌 런치에는 뒤에서 도는 런치 작업이 표식을 다시 남기지 않는다(5.1.13 prompts)
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
        LaunchGuard.isClosed = false
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

    func testClosedLaunchLeavesNoMarkerFromLaterStages() {
        LaunchGuard.finish()

        LaunchGuard.essential(.prompts) {}

        XCTAssertNil(defaults.string(forKey: DefaultsKey.launchStageInFlight),
                     "뒤로 가서 닫힌 런치의 표식이 다시 남으면, 메모리 정리로 사라진 프로세스가 멈춘 런치로 세인다")
    }

    func testDoesNothingWithoutMarker() {
        defaults.removeObject(forKey: DefaultsKey.launchStageInFlight)
        defaults.set(5, forKey: DefaultsKey.launchFailStreak)

        LaunchGuard.closeIfBackgroundLaunch("test")

        XCTAssertNil(defaults.string(forKey: DefaultsKey.launchStageInFlight))
        XCTAssertEqual(defaults.integer(forKey: DefaultsKey.launchFailStreak), 5,
                       "닫을 런치가 없으면 연속 실패 기록도 건드리지 않는다")
    }

    func testAwaitingSceneMarkerIsNotAStall() {
        XCTAssertFalse(LaunchGuard.readsAsStall("essential:awaiting-scene"),
                       "화면 없이 깨어났다 정리된 프로세스를 멈춘 런치로 읽으면 다음 런치가 세이프 모드로 열린다")
        XCTAssertTrue(LaunchGuard.readsAsStall("essential:first-frame"),
                      "창을 만들다 멈춘 것은 scene-create 워치독이다. 다음 런치가 알아봐야 한다")
        XCTAssertTrue(LaunchGuard.readsAsStall("optional:sync"))
        XCTAssertTrue(LaunchGuard.readsAsStall("tips"), "옛 형식 표식도 멈춘 런치로 읽는다")
    }
}
