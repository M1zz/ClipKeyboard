//
//  UserStageSimulatorTests.swift
//  ClipKeyboardTests
//
//  단계 흉내가 **진짜로 그 단계가 되는지** 못 박는다.
//
//  이 시험이 없으면 시뮬레이터는 거짓말을 한다. 예를 들어 "능숙한 사람" 단계의 서랍에
//  템플릿을 하나도 안 넣어 두면 판정은 익음에서 멈추는데 화면 제목만 능숙이라고 적힌다.
//  그 상태로 화면을 보고 "능숙한 사람에게는 이렇게 보이는구나" 라고 판단하면,
//  그 판단이 통째로 틀린 것이 된다.
//

import XCTest
@testable import ClipKeyboard

final class UserStageSimulatorTests: XCTestCase {

    /// 단계마다 나와야 하는 숙련도.
    private let expectedLevel: [UserStage: UserLevel] = [
        .firstDay: .browsing,
        .browsing: .browsing,
        .madeAndStopped: .made,
        .firstUse: .used,
        .fluent: .fluent,
        .expert: .expert,
        .oneTrick: .fluent,
        .hoarder: .used,
        .dormant: .fluent,
        .returning: .fluent
    ]

    func testEveryStageResolvesToItsOwnLevel() {
        for stage in UserStage.allCases {
            XCTAssertEqual(stage.state().level, expectedLevel[stage],
                           "'\(stage.rawValue)' 단계의 서랍이 그 숙련도를 만들어 내지 못한다")
        }
    }

    func testTenureMatchesEachStage() {
        XCTAssertEqual(UserStage.firstDay.state().tenure, .day0)
        XCTAssertEqual(UserStage.firstUse.state().tenure, .week1)
        XCTAssertEqual(UserStage.browsing.state().tenure, .month1)
        XCTAssertEqual(UserStage.fluent.state().tenure, .settled)
        XCTAssertEqual(UserStage.expert.state().tenure, .long)
    }

    func testGrainStages() {
        XCTAssertEqual(UserStage.oneTrick.state().grain, .oneTrick)
        XCTAssertEqual(UserStage.hoarder.state().grain, .hoarder)
        XCTAssertEqual(UserStage.fluent.state().grain, .even,
                       "고르게 쓰는 단계가 결에 걸리면 화면이 엉뚱하게 기운다")
    }

    func testActivityStages() {
        XCTAssertEqual(UserStage.dormant.state().activity, .dormant)
        XCTAssertEqual(UserStage.returning.state().activity, .returning)
        XCTAssertEqual(UserStage.fluent.state().activity, .active)
    }

    /// 막힌 칸을 눈으로 보려고 만든 단계들이다. 진단까지 맞아야 쓸모가 있다.
    func testStuckStagesAreDiagnosedAsStuck() {
        XCTAssertEqual(UserStage.madeAndStopped.state().cell, .stuck)
        XCTAssertEqual(UserStage.browsing.state().cell, .stuck)
        XCTAssertEqual(UserStage.firstDay.state().cell, .onTrack)
    }

    /// 화면에 보일 목록과 판정이 같은 데이터에서 나와야 한다.
    func testFactsAreCountedFromTheDrawerItself() {
        for stage in UserStage.allCases {
            let facts = stage.facts()
            XCTAssertEqual(facts.ownShortcuts, stage.memos.count)
            XCTAssertEqual(facts.uses, stage.memos.reduce(0) { $0 + $1.clipCount })
            XCTAssertEqual(facts.unusedShortcuts, stage.memos.filter { $0.clipCount == 0 }.count)
        }
    }

    /// 능숙한 사람은 두 번째 도구를 쓰는 사람이다. 서랍에 그것이 실제로 들어 있어야 한다.
    func testExpertDrawerActuallyHasTemplatesAndCombos() {
        let facts = UserStage.expert.facts()
        XCTAssertGreaterThan(facts.templates, 0)
        XCTAssertGreaterThan(facts.combos, 0)
    }

    /// 휴면·복귀는 같은 서랍을 쓰되 **마지막으로 쓴 때**만 다르다.
    func testDormantAndReturningShareTheDrawerButNotTheClock() {
        XCTAssertEqual(UserStage.dormant.memos.count, UserStage.fluent.memos.count)
        XCTAssertEqual(UserStage.returning.memos.count, UserStage.fluent.memos.count)

        let dormantLast = UserStage.dormant.facts().lastUsedAt ?? .distantPast
        let returningLast = UserStage.returning.facts().lastUsedAt ?? .distantPast
        XCTAssertGreaterThan(returningLast, dormantLast)
    }

    /// 단계마다 앞에 세우는 안내가 달라야 한다. 다 같으면 흉내 낼 이유가 없다.
    func testStagesLeadWithDifferentPrompts() {
        XCTAssertEqual(UserStage.firstDay.state().leadingSurface, .tutorialStage)
        XCTAssertEqual(UserStage.madeAndStopped.state().leadingSurface, .keyboardSetupBanner)
        XCTAssertNil(UserStage.dormant.state().leadingSurface)
    }
}
