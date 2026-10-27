//
//  LaunchPromptTests.swift
//  ClipKeyboardTests
//
//  앱을 열 때 저절로 뜨는 창은 하나. 무엇이 먼저인지와 자리를 나눠 쓰는 문지기.
//  설계: docs/design/PROGRESSIVE_DISCLOSURE.md 4.1절
//

import XCTest
@testable import ClipKeyboard

@MainActor
final class LaunchPromptTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func pick(_ due: [PromptCandidate],
                      activity: UserActivity = .active,
                      hidden: Set<UserSurface> = [],
                      ledger: PromptLedger.Snapshot = .empty) -> PromptCandidate? {
        let ordered = PromptCandidate.launchOrder.filter { due.contains($0) }
        let context = PromptArbiter.Context(activity: activity,
                                            visibility: { hidden.contains($0) ? .hidden : .lead },
                                            ledger: ledger,
                                            activeDays: 10,
                                            now: now)
        return PromptArbiter.pick(ordered, in: context)[.launchSheet]
    }

    override func tearDown() {
        LaunchSheetGate.reset()
        super.tearDown()
    }

    // MARK: - 차례

    func testWhatsNewComesBeforeMoneyAndAsks() {
        XCTAssertEqual(pick([.didYouKnow, .reviewRequest, .graduationOffer, .whatsNew])?.id, "whatsNew",
                       "새 버전 첫 실행에는 졸업 제안·리뷰보다 새 소식이 먼저다")
    }

    func testAccessibilityGuideComesFirst() {
        XCTAssertEqual(pick([.whatsNew, .categoryCleanup, .accessibilityGuide])?.id, "accessibilityGuide")
    }

    func testReturningUserGetsNoMoneyOrAsk() {
        XCTAssertNil(pick([.graduationOffer, .reviewRequest, .feedbackNudge, .didYouKnow], activity: .returning),
                     "돌아온 첫 화면에 결제·부탁·소식을 꺼내지 않는다")
        XCTAssertEqual(pick([.graduationOffer, .whatsNew], activity: .returning)?.id, "whatsNew")
    }

    func testReviewWaitsForItsFloor() {
        XCTAssertEqual(pick([.reviewRequest, .feedbackNudge], hidden: [.reviewRequest])?.id, "feedbackNudge",
                       "리뷰를 물을 단계가 아니면 다음 부탁에게 자리를 준다")
    }

    func testAsksShareOneWeeklyBudget() {
        var ledger = PromptLedger.Snapshot.empty
        ledger.noteSpoke(.ask, id: "shareMoment", at: now.addingTimeInterval(-86_400), activeDays: 9)
        XCTAssertNil(pick([.reviewRequest, .feedbackNudge], ledger: ledger),
                     "어제 친구에게 알리기를 권했으면 이번 주에는 리뷰도 묻지 않는다")
    }

    // MARK: - 문지기

    func testGateLetsOnlyOneClaimPerLaunch() {
        LaunchSheetGate.reset()
        XCTAssertTrue(LaunchSheetGate.claim("freeUseReceipt"))
        XCTAssertFalse(LaunchSheetGate.claim("whatsNew"), "목록이 먼저 띄웠으면 앱은 비킨다")
        XCTAssertTrue(LaunchSheetGate.isTaken)

        LaunchSheetGate.reset()
        XCTAssertTrue(LaunchSheetGate.claim("whatsNew"), "앱이 뒤로 갔다 오면 새 실행이다")
    }
}
