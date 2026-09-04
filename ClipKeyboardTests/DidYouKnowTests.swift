//
//  DidYouKnowTests.swift
//  ClipKeyboardTests
//
//  "그거 아세요?" 가 **알림이 아니라 방해가 되는 선**을 넘지 않게 지킨다.
//
//  ⚠️ 이 시험들이 지키는 것은 문구가 아니라 **말 거는 예의**다.
//     첫날엔 조용히 · 며칠에 한 번 · 본 것은 다시 안 · 그만하라면 그만.
//

import XCTest
@testable import ClipKeyboard

final class DidYouKnowTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        DidYouKnowScheduler.resetAll()
    }

    override func tearDown() {
        DidYouKnowScheduler.resetAll()
        super.tearDown()
    }

    private func candidate(onboarded: Bool = true,
                           installedDaysAgo: Double? = 30) -> DidYouKnow? {
        DidYouKnowScheduler.candidate(
            onboardingFinished: onboarded,
            installedAt: installedDaysAgo.map { now.addingTimeInterval(-$0 * 86_400) },
            now: now)
    }

    // MARK: - 말 거는 예의

    func test_처음_오는_길을_지나는_중에는_말하지_않는다() {
        // 온보딩 위에 얹히면 둘 다 안 읽힌다.
        XCTAssertNil(candidate(onboarded: false))
    }

    func test_설치_첫날에는_조용히_있는다() {
        XCTAssertNil(candidate(installedDaysAgo: 0.5))
        XCTAssertNotNil(candidate(installedDaysAgo: 1.5))
    }

    func test_설치일을_모르면_말하지_않는다() {
        // 모르는 채로 첫날에 말을 걸 바에는 아무 말도 안 하는 편이 낫다.
        XCTAssertNil(candidate(installedDaysAgo: nil))
    }

    func test_며칠에_한_번만_말한다() {
        guard let first = candidate() else { return XCTFail("첫 이야기가 있어야 한다") }
        DidYouKnowScheduler.markShown(first, at: now)
        XCTAssertNil(candidate(), "방금 말했으면 오늘은 그만")
        // 사흘이 지나야 다음 이야기.
        let later = DidYouKnowScheduler.candidate(
            onboardingFinished: true,
            installedAt: now.addingTimeInterval(-30 * 86_400),
            now: now.addingTimeInterval(DidYouKnowScheduler.interval + 60))
        XCTAssertNotNil(later)
        XCTAssertNotEqual(later?.id, first.id, "같은 이야기를 또 하면 광고가 된다")
    }

    func test_그만_보겠다고_하면_그만한다() {
        DidYouKnowScheduler.isOptedOut = true
        XCTAssertNil(candidate())
    }

    // MARK: - 다 하면 멈춘다

    func test_다_하고_나면_처음으로_돌아가지_않는다() {
        for item in DidYouKnow.all { DidYouKnowScheduler.markShown(item, at: now) }
        XCTAssertNil(DidYouKnowScheduler.next,
                     "되풀이되는 순간 알림이 아니라 광고가 된다")
    }

    func test_본_것은_다시_나오지_않는다() {
        guard let first = DidYouKnowScheduler.next else { return XCTFail() }
        DidYouKnowScheduler.markShown(first, at: now)
        XCTAssertNotEqual(DidYouKnowScheduler.next?.id, first.id)
    }

    // MARK: - 이야기 자체

    func test_열쇠가_겹치지_않는다() {
        // id 가 겹치면 하나를 보면 다른 하나도 본 것이 되어 조용히 사라진다.
        let ids = DidYouKnow.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func test_빈_이야기가_없다() {
        for item in DidYouKnow.all {
            XCTAssertFalse(item.title.isEmpty, "\(item.id) 제목이 비었다")
            XCTAssertFalse(item.body.isEmpty, "\(item.id) 본문이 비었다")
            XCTAssertFalse(item.symbol.isEmpty, "\(item.id) 기호가 비었다")
        }
    }

    func test_가장_먼저_할_말은_안심시키는_것이다() {
        // 이 앱에 개인정보를 적어도 되는지가 첫 며칠의 가장 큰 물음이다.
        // 그 답을 못 들으면 나머지 기능은 쓸 일이 없다.
        XCTAssertEqual(DidYouKnow.all.first?.id, "no-server")
    }
}
