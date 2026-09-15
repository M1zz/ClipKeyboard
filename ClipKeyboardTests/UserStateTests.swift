//
//  UserStateTests.swift
//  ClipKeyboardTests
//
//  사용자 상태 판정을 못 박는다. 전부 순수 함수라 기기 값 없이 검증된다.
//
//  특히 틀리기 쉬운 자리를 고정한다:
//   ① 샘플을 뺀 개수로 판정할 것 - 앱이 심어 준 것으로 사람을 올리면 안 된다
//   ② 레벨은 **내려가지 않을 것** - 쉰 사람이 초심자 안내를 다시 보면 안 된다
//   ③ 휴면인 사람에게는 먼저 말을 걸지 말 것
//   ④ 설치일을 모르면 첫날이 아니라 오랜 사람으로 볼 것
//

import XCTest
@testable import ClipKeyboard

final class UserStateTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func daysAgo(_ days: Double) -> Date {
        now.addingTimeInterval(-days * 86_400)
    }

    // MARK: - 기간

    func testTenureBoundaries() {
        XCTAssertEqual(UserTenure.at(installedAt: daysAgo(0), now: now), .day0)
        XCTAssertEqual(UserTenure.at(installedAt: daysAgo(1.5), now: now), .day0)
        XCTAssertEqual(UserTenure.at(installedAt: daysAgo(2), now: now), .week1)
        XCTAssertEqual(UserTenure.at(installedAt: daysAgo(7.5), now: now), .week1)
        XCTAssertEqual(UserTenure.at(installedAt: daysAgo(8), now: now), .month1)
        XCTAssertEqual(UserTenure.at(installedAt: daysAgo(30.5), now: now), .month1)
        XCTAssertEqual(UserTenure.at(installedAt: daysAgo(31), now: now), .settled)
        XCTAssertEqual(UserTenure.at(installedAt: daysAgo(91), now: now), .long)
    }

    /// 설치일을 모르는 기기(예전 버전에서 올라온 것)를 첫날로 보면,
    /// 몇 년 쓴 사람이 업데이트 한 번에 튜토리얼을 다시 본다.
    func testUnknownInstallDateCountsAsLongTimeUser() {
        XCTAssertEqual(UserTenure.at(installedAt: nil, now: now), .long)
        XCTAssertEqual(UserTenure.at(installedAt: now.addingTimeInterval(86_400), now: now), .long,
                       "시계가 앞선 기기도 첫날로 떨어지면 안 된다")
    }

    // MARK: - 숙련도

    func testLevelLadder() {
        XCTAssertEqual(UserState.rawLevel(UserStateFacts()), .browsing)

        XCTAssertEqual(UserState.rawLevel(UserStateFacts(ownShortcuts: 3, uses: 0)), .made)

        XCTAssertEqual(UserState.rawLevel(UserStateFacts(ownShortcuts: 3, uses: 1)), .used)

        XCTAssertEqual(UserState.rawLevel(
            UserStateFacts(ownShortcuts: 5, uses: 12, keyboardPastes: 4, activeDays: 3)), .fluent)

        XCTAssertEqual(UserState.rawLevel(
            UserStateFacts(ownShortcuts: 9, uses: 60, keyboardPastes: 30, activeDays: 12, templates: 2)), .expert)
    }

    /// 키보드에서 한 번도 안 넣었거나 하루에만 몰아 쓴 사람은 아직 익은 것이 아니다.
    func testFluentNeedsKeyboardAndSeveralDays() {
        let onlyInApp = UserStateFacts(ownShortcuts: 5, uses: 30, keyboardPastes: 0, activeDays: 9)
        XCTAssertEqual(UserState.rawLevel(onlyInApp), .used)

        let oneBigDay = UserStateFacts(ownShortcuts: 5, uses: 30, keyboardPastes: 20, activeDays: 1)
        XCTAssertEqual(UserState.rawLevel(oneBigDay), .used)
    }

    /// 많이 쓰기만 하고 두 번째 도구를 안 쓴 사람은 능숙이 아니다.
    func testExpertNeedsSecondTool() {
        let heavyButPlain = UserStateFacts(ownShortcuts: 6, uses: 200, keyboardPastes: 150,
                                           activeDays: 30, templates: 0, combos: 0)
        XCTAssertEqual(UserState.rawLevel(heavyButPlain), .fluent)
    }

    /// 바닥이 있으면 값이 줄어도 레벨은 그대로다.
    func testLevelNeverFalls() {
        let quietNow = UserStateFacts(ownShortcuts: 1, uses: 1)
        let state = UserState.resolve(facts: quietNow, floor: .expert, now: now)
        XCTAssertEqual(state.level, .expert)
    }

    // MARK: - 결

    func testGrain() {
        XCTAssertEqual(UserState.grain(UserStateFacts(ownShortcuts: 2, uses: 40)), .oneTrick)

        XCTAssertEqual(UserState.grain(
            UserStateFacts(ownShortcuts: 10, uses: 5, unusedShortcuts: 8)), .hoarder)

        XCTAssertEqual(UserState.grain(
            UserStateFacts(ownShortcuts: 10, uses: 40, unusedShortcuts: 2)), .even)
    }

    // MARK: - 활동

    func testActivity() {
        XCTAssertEqual(UserState.activity(UserStateFacts(lastUsedAt: daysAgo(1)), now: now), .active)
        XCTAssertEqual(UserState.activity(UserStateFacts(lastUsedAt: daysAgo(20)), now: now), .dormant)

        let justBack = UserStateFacts(lastUsedAt: daysAgo(0.1), returnedAt: daysAgo(2))
        XCTAssertEqual(UserState.activity(justBack, now: now), .returning)

        let backLongAgo = UserStateFacts(lastUsedAt: daysAgo(0.1), returnedAt: daysAgo(9))
        XCTAssertEqual(UserState.activity(backLongAgo, now: now), .active)
    }

    /// 한 번도 안 쓴 사람은 휴면이 아니다. 아직 시작을 안 한 것뿐이라,
    /// 휴면으로 보면 첫 단축어 안내까지 같이 꺼진다.
    func testNeverUsedIsNotDormant() {
        XCTAssertEqual(UserState.activity(UserStateFacts(lastUsedAt: nil), now: now), .active)
    }

    // MARK: - 지도 25칸

    func testCellDiagnosis() {
        XCTAssertEqual(UserState.cell(tenure: .day0, level: .browsing), .onTrack)
        XCTAssertEqual(UserState.cell(tenure: .week1, level: .browsing), .watch)
        XCTAssertEqual(UserState.cell(tenure: .month1, level: .browsing), .stuck)
        XCTAssertEqual(UserState.cell(tenure: .long, level: .browsing), .ghost)

        XCTAssertEqual(UserState.cell(tenure: .day0, level: .made), .onTrack)
        XCTAssertEqual(UserState.cell(tenure: .month1, level: .made), .stuck)
        XCTAssertEqual(UserState.cell(tenure: .long, level: .made), .ghost)

        XCTAssertEqual(UserState.cell(tenure: .month1, level: .used), .onTrack)
        XCTAssertEqual(UserState.cell(tenure: .settled, level: .used), .watch)

        for tenure in UserTenure.allCases {
            XCTAssertEqual(UserState.cell(tenure: tenure, level: .fluent), .onTrack)
            XCTAssertEqual(UserState.cell(tenure: tenure, level: .expert), .onTrack)
        }
    }

    /// 25칸이 빠짐없이 값을 낸다.
    func testEveryCellResolves() {
        for tenure in UserTenure.allCases {
            for level in UserLevel.allCases {
                _ = UserState.cell(tenure: tenure, level: level)
            }
        }
    }

    // MARK: - 기능 노출

    private func state(_ level: UserLevel,
                       tenure: UserTenure = .month1,
                       grain: UserGrain = .even,
                       activity: UserActivity = .active) -> UserState {
        UserState(tenure: tenure, level: level, grain: grain, activity: activity,
                  cell: UserState.cell(tenure: tenure, level: level))
    }

    func testBeginnerSeesOnlyTheFirstStep() {
        let beginner = state(.browsing, tenure: .day0)
        XCTAssertEqual(beginner.visibility(of: .tutorialStage), .lead)
        XCTAssertEqual(beginner.visibility(of: .createShortcut), .lead)
        XCTAssertEqual(beginner.visibility(of: .statsPassport), .hidden)
        XCTAssertEqual(beginner.visibility(of: .slotLimit), .hidden)
        XCTAssertEqual(beginner.visibility(of: .combo), .hidden)
    }

    /// 만들고 멈춘 사람의 화면 주인공은 키보드 켜기 하나다.
    func testStuckUserLeadsWithKeyboardSetup() {
        let stuck = state(.made)
        XCTAssertEqual(stuck.visibility(of: .keyboardSetupBanner), .lead)
        XCTAssertEqual(stuck.leadingSurface, .keyboardSetupBanner)
        XCTAssertEqual(stuck.visibility(of: .slotLimit), .hidden,
                       "아직 한 번도 안 써 본 사람에게 한도를 들이밀지 않는다")
    }

    func testExpertKeepsBeginnerGuidanceOff() {
        let expert = state(.expert)
        XCTAssertEqual(expert.visibility(of: .tutorialStage), .hidden)
        XCTAssertEqual(expert.visibility(of: .keyboardSetupBanner), .hidden)
        XCTAssertEqual(expert.visibility(of: .statsPassport), .lead)
        XCTAssertEqual(expert.visibility(of: .combo), .lead)
    }

    /// 칸이 모자란 게 아니라 못 찾는 것이다.
    func testHoarderNeverSeesSlotLimit() {
        let hoarder = state(.fluent, grain: .hoarder)
        XCTAssertEqual(hoarder.visibility(of: .slotLimit), .hidden)
        XCTAssertEqual(hoarder.visibility(of: .favorites), .lead)
        XCTAssertEqual(hoarder.visibility(of: .searchAndReorder), .lead)
    }

    /// 셋 가지고는 정리할 것이 없다.
    func testOneTrickHidesOrganizing() {
        let oneTrick = state(.fluent, grain: .oneTrick)
        XCTAssertEqual(oneTrick.visibility(of: .categories), .hidden)
        XCTAssertEqual(oneTrick.visibility(of: .bulkImport), .hidden)
        XCTAssertEqual(oneTrick.visibility(of: .template), .lead,
                       "두 번째 쓸모는 빈칸 쪽에서 나온다")
    }

    /// 휴면인 사람에게는 먼저 말을 걸지 않는다.
    func testDormantSilencesEveryPrompt() {
        let dormant = state(.expert, activity: .dormant)
        for surface in UserSurface.allCases where surface.isPrompt {
            XCTAssertEqual(dormant.visibility(of: surface), .hidden, "\(surface) 가 휴면인 사람에게 떴다")
        }
        XCTAssertNil(dormant.leadingSurface)
        XCTAssertNotEqual(dormant.visibility(of: .backupSync), .hidden,
                          "사람이 찾아가는 자리는 휴면이어도 그대로 둔다")
    }

    /// 돌아온 사람에게 튜토리얼을 다시 틀거나 리뷰를 묻지 않는다.
    func testReturningUserIsNotRestarted() {
        let returning = state(.fluent, activity: .returning)
        XCTAssertEqual(returning.visibility(of: .tutorialStage), .hidden)
        XCTAssertEqual(returning.visibility(of: .reviewRequest), .hidden)
        XCTAssertEqual(returning.visibility(of: .slotLimit), .hidden)
        XCTAssertNotEqual(returning.visibility(of: .searchAndReorder), .hidden)
    }

    /// 화면에 세우는 안내는 **언제나 하나**다.
    ///
    /// 표에서는 여러 자리가 동시에 `.lead` 가 될 수 있다(능숙한 사람에게는 한도·맥 앱·정리가
    /// 다 내놓을 만한 것이다). 그것들이 각자 옳다고 한꺼번에 뜨면 하루에 다섯 번 걸리적거린다.
    /// 그래서 주인공을 고르는 일은 `leadingSurface` 한 곳이 맡는다.
    func testLeadingSurfaceIsAlwaysASingleEligiblePrompt() {
        for level in UserLevel.allCases {
            for grain in [UserGrain.even, .oneTrick, .hoarder] {
                for activity in [UserActivity.active, .dormant, .returning] {
                    let s = state(level, grain: grain, activity: activity)
                    guard let lead = s.leadingSurface else { continue }
                    XCTAssertTrue(lead.isPrompt, "\(lead) 는 말을 거는 자리가 아니다")
                    XCTAssertEqual(s.visibility(of: lead), .lead)
                }
            }
        }
    }

    /// 초심자에게는 주인공이 **반드시** 있어야 한다. 아무것도 안 뜨면 빈 목록 앞에 혼자 남는다.
    func testBeginnersAlwaysHaveSomethingLeading() {
        XCTAssertEqual(state(.browsing, tenure: .day0).leadingSurface, .tutorialStage)
        XCTAssertEqual(state(.made).leadingSurface, .keyboardSetupBanner)
    }
}
