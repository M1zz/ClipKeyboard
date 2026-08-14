//
//  DiscountOfferManagerTests.swift
//  ClipKeyboardTests
//
//  반값 제안이 **언제 뜨는가**를 못박는다.
//
//  왜 테스트로 붙잡는가: 이 판정이 틀리면 두 방향 모두 사고다.
//   · 너무 자주 뜨면  → 결제 창이 되풀이되는 앱이 된다(고친 티도 안 나고 미움만 남는다).
//   · 안 뜨면        → 아무도 모르고 지나간다. 화면은 멀쩡한데 조건 하나가 조용히 막고 있다.
//  판정을 순수 함수로 떼어 둔 이유가 이것이라, 그 계약을 여기서 고정한다.
//

import Testing
import Foundation
@testable import ClipKeyboard

// ⚠️ `.serialized` - 기록을 확인하는 두 테스트가 **같은 App Group UserDefaults** 를 만진다.
//    나란히 돌리면 한쪽의 reset 이 다른 쪽이 방금 쓴 값을 지운다(실제 앱에는 기기가 하나뿐이라
//    생기지 않는 상황이다).
@Suite("DiscountOfferManager, 반값 제안이 뜨는 조건", .serialized)
struct DiscountOfferManagerTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func daysAgo(_ days: Double) -> Date {
        now.addingTimeInterval(-days * 86_400)
    }

    /// 기본은 "다 갖춘 상태" - 각 테스트는 한 조건만 무너뜨려 그 조건의 힘을 본다.
    private func shouldOffer(reachedAt: Date? = nil,
                             daysSinceReach: Double? = 7,
                             alreadyShown: Bool = false,
                             hasPro: Bool = false,
                             discountAvailable: Bool = true) -> Bool {
        let reached = reachedAt ?? daysSinceReach.map { daysAgo($0) }
        return DiscountOfferManager.shouldOffer(now: now,
                                                reachedAt: reached,
                                                alreadyShown: alreadyShown,
                                                hasPro: hasPro,
                                                discountAvailable: discountAvailable)
    }

    @Test("한 칸 앞에 닿고 일주일이 지나면 뜬다")
    func offersAfterAWeek() {
        #expect(shouldOffer(daysSinceReach: 7))
        #expect(shouldOffer(daysSinceReach: 30))
    }

    @Test("일주일이 안 됐으면 안 뜬다. 닿자마자 들이밀지 않는다")
    func waitsAFullWeek() {
        #expect(shouldOffer(daysSinceReach: 0) == false)
        #expect(shouldOffer(daysSinceReach: 6.9) == false)
    }

    @Test("한 칸 앞에 닿은 적이 없으면 안 뜬다")
    func requiresReachingTheEdge() {
        #expect(DiscountOfferManager.shouldOffer(now: now,
                                                 reachedAt: nil,
                                                 alreadyShown: false,
                                                 hasPro: false,
                                                 discountAvailable: true) == false)
    }

    @Test("이미 한 번 띄웠으면 다시 뜨지 않는다")
    func showsOnlyOnce() {
        #expect(shouldOffer(alreadyShown: true) == false)
    }

    @Test("이미 Pro 인 사람에게는 뜨지 않는다")
    func neverOffersToPro() {
        #expect(shouldOffer(hasPro: true) == false)
    }

    /// ⚠️ 가장 중요한 줄. 반값 상품이 없는데 창이 뜨면 **정가를 반값이라 부르게 된다.**
    @Test("반값 상품이 로드되지 않았으면 아예 뜨지 않는다")
    func neverAdvertisesAnUnavailableDiscount() {
        #expect(shouldOffer(discountAvailable: false) == false)
    }

    @Test("겨냥하는 개수는 무료 한도 바로 한 칸 앞이다")
    func targetsTheSlotBeforeTheLimit() {
        #expect(DiscountOfferManager.limitEdgeCount == ProFeatureManager.freeMemoLimit - 1)
        #expect(DiscountOfferManager.limitEdgeCount == 9)
    }

    // MARK: - 기록

    @Test("한 칸 앞에 처음 닿은 시각만 남고, 그 뒤 개수가 늘거나 줄어도 시계는 그대로다")
    func recordsTheFirstTimeOnly() {
        DiscountOfferManager.resetForTesting()
        defer { DiscountOfferManager.resetForTesting() }

        DiscountOfferManager.noteShortcutCount(3)
        #expect(DiscountOfferManager.reachedLimitEdgeAt == nil, "한도 앞에 닿기 전에는 기록하지 않는다")

        DiscountOfferManager.noteShortcutCount(9)
        let first = DiscountOfferManager.reachedLimitEdgeAt
        #expect(first != nil)

        // 하나 지웠다 다시 만들어도 시계가 되감기면 안 된다 - 오래 쓴 사람이 손해를 본다.
        DiscountOfferManager.noteShortcutCount(8)
        DiscountOfferManager.noteShortcutCount(12)
        #expect(DiscountOfferManager.reachedLimitEdgeAt == first)
    }

    @Test("띄운 것을 못박으면 다시 대상이 되지 않는다")
    func markShownSticks() {
        DiscountOfferManager.resetForTesting()
        defer { DiscountOfferManager.resetForTesting() }

        #expect(DiscountOfferManager.wasShown == false)
        DiscountOfferManager.markShown()
        #expect(DiscountOfferManager.wasShown)
    }
}
