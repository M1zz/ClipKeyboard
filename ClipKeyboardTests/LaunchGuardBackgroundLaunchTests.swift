//
//  LaunchGuardBackgroundLaunchTests.swift
//  ClipKeyboardTests
//
//  보는 사람 없이 깨어난 런치를 닫는 길(`LaunchGuard.closeIfBackgroundLaunch`)이
//  **앞에 있는 앱의 표식은 지우지 않는다**는 약속.
//
//   ① 앱이 앞에 있으면 표식을 그대로 둔다(첫 화면에서 멈춘 런치는 다음 런치가 알아봐야 한다)
//   ② 표식이 없으면 아무것도 쓰지 않는다
//   ③ 창을 기다리던 표식(`awaiting-scene`)은 멈춘 런치로 읽지 않는다. 나머지는 전부 멈춘 런치다
//   ④ 뒤로 가서 닫힌 런치에는 뒤에서 도는 런치 작업이 표식을 다시 남기지 않는다(5.1.13 prompts)
//   ⑤ 앱이 뒤에 있으면 **창이 붙어 있어도** 닫는다. iOS 는 뒤에서 깨울 때도 창을 붙이고, 그러면
//      런치 작업이 `prompts` 까지 돌다 멈춰진다(5.1.24 까지 불안정 설치의 절반이 이것이었다)
//
//  시험 호스트는 빈 화면 하나(씬 하나)를 띄운다. 앞 · 뒤는 `LaunchGuard.isInBackground` 를 갈아 끼워 정한다.
//

import XCTest
import UIKit
@testable import ClipKeyboard

@MainActor
final class LaunchGuardBackgroundLaunchTests: XCTestCase {

    private var defaults: UserDefaults { AppGroup.defaults ?? .standard }
    private var savedMarker: String?
    private var savedStreak: Any?
    private var savedIsInBackground: (() -> Bool)?

    override func setUp() async throws {
        savedMarker = defaults.string(forKey: DefaultsKey.launchStageInFlight)
        savedStreak = defaults.object(forKey: DefaultsKey.launchFailStreak)
        savedIsInBackground = LaunchGuard.isInBackground
    }

    override func tearDown() async throws {
        LaunchGuard.isClosed = false
        if let savedIsInBackground { LaunchGuard.isInBackground = savedIsInBackground }
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

    func testKeepsFirstFrameMarkerWhenAppIsInForeground() {
        LaunchGuard.isInBackground = { false }
        defaults.set("essential:first-frame", forKey: DefaultsKey.launchStageInFlight)

        LaunchGuard.closeIfBackgroundLaunch("test")

        XCTAssertEqual(defaults.string(forKey: DefaultsKey.launchStageInFlight), "essential:first-frame",
                       "앞에 있는 런치의 표식을 지우면 첫 화면에서 멈춘 사고를 다음 런치가 못 알아본다")
    }

    func testClosesBackgroundLaunchEvenWithSceneConnected() throws {
        try XCTSkipIf(UIApplication.shared.connectedScenes.isEmpty, "시험 호스트에 씬이 없다")
        LaunchGuard.isInBackground = { true }
        defaults.set("optional:prompts", forKey: DefaultsKey.launchStageInFlight)

        LaunchGuard.closeIfBackgroundLaunch("test")

        XCTAssertNil(defaults.string(forKey: DefaultsKey.launchStageInFlight),
                     "뒤에서 깨어난 실행의 표식이 남으면 다음 실행이 세이프 모드로 열린다")
    }

    func testBackgroundLaunchLeavesNoMarkerFromLaterStages() {
        LaunchGuard.isInBackground = { true }
        defaults.removeObject(forKey: DefaultsKey.launchStageInFlight)
        LaunchGuard.markSceneStarted()

        LaunchGuard.closeIfBackgroundLaunch("test")
        LaunchGuard.essential(.prompts) {}

        XCTAssertNil(defaults.string(forKey: DefaultsKey.launchStageInFlight),
                     "닫을 표식이 없던 뒤쪽 실행도, 뒤이어 도는 런치 작업이 표식을 남기면 안 된다")
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
        LaunchGuard.isInBackground = { true }

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
