//
//  DiscountOfferManagerTests.swift
//  ClipKeyboardTests
//
//  반값 제안이 **언제, 어느 자리에서** 뜨는가를 못박는다.
//
//  왜 테스트로 붙잡는가: 이 판정이 틀리면 두 방향 모두 사고다.
//   · 너무 자주 뜨면  → 결제 창이 따라다니는 앱이 된다(고친 티도 안 나고 미움만 남는다).
//   · 안 뜨면        → 아무도 모르고 지나간다. 화면은 멀쩡한데 조건 하나가 조용히 막고 있다.
//  기회가 둘이 되면서 "한쪽을 봤다고 다른 쪽이 막히지 않는가"까지 지켜야 할 것이 늘었다.
//  판정을 순수 함수로 떼어 둔 이유가 이것이라, 그 계약을 여기서 고정한다.
//

import Testing
import Foundation
@testable import ClipKeyboard

// ⚠️ `.serialized` - 기록을 확인하는 두 테스트가 **같은 App Group UserDefaults** 를 만진다.
//    나란히 돌리면 한쪽의 reset 이 다른 쪽이 방금 쓴 값을 지운다(실제 앱에는 기기가 하나뿐이라
//    생기지 않는 상황이다).
@Suite("DiscountOfferManager, 반값 제안이 뜨는 자리", .serialized)
struct DiscountOfferManagerTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func daysAgo(_ days: Double) -> Date {
        now.addingTimeInterval(-days * 86_400)
    }

    /// 기본은 "설치한 지 얼마 안 됐고, 한도에는 안 닿은" 새 사용자.
    /// 각 테스트는 한 조건만 바꿔 그 조건의 힘을 본다.
    private func due(installedDaysAgo: Double? = 1,
                     reachedDaysAgo: Double? = nil,
                     shown: Set<DiscountOfferManager.Occasion> = [],
                     hasPro: Bool = false,
                     discountAvailable: Bool = true,
                     isMidFirstShortcut: Bool = false) -> DiscountOfferManager.Occasion? {
        DiscountOfferManager.dueOccasion(now: now, context: .init(
            installedAt: installedDaysAgo.map { daysAgo($0) },
            reachedLimitEdgeAt: reachedDaysAgo.map { daysAgo($0) },
            shownOccasions: shown,
            hasPro: hasPro,
            discountAvailable: discountAvailable,
            isMidFirstShortcut: isMidFirstShortcut
        ))
    }

    // MARK: - ① 설치 직후

    @Test("설치하고 얼마 안 된 사람에게는 첫 기회가 온다")
    func offersRightAfterInstall() {
        #expect(due(installedDaysAgo: 0) == .firstRun)
        #expect(due(installedDaysAgo: 6.9) == .firstRun)
    }

    @Test("첫 주가 지나면 그 기회는 닫힌다. 설치 제안이 한 달째 따라다니면 안 된다")
    func firstRunWindowCloses() {
        #expect(due(installedDaysAgo: 8) == nil)
    }

    @Test("첫 단축어를 만들기 전에는 뜨지 않는다. 튜토리얼 위에 결제 창을 얹지 않는다")
    func yieldsToTheFirstShortcutTutorial() {
        #expect(due(isMidFirstShortcut: true) == nil)
        // 만들거나 건너뛰고 나면 그때 온다.
        #expect(due(isMidFirstShortcut: false) == .firstRun)
    }

    @Test("설치 시각을 모르면 첫 기회는 건너뛴다")
    func skipsFirstRunWithoutInstallDate() {
        #expect(due(installedDaysAgo: nil) == nil)
    }

    // MARK: - ② 한도 한 칸 앞

    @Test("한 칸 앞에 닿고 일주일이 지나면 두 번째 기회가 온다")
    func offersAfterAWeekAtTheEdge() {
        #expect(due(installedDaysAgo: 60, reachedDaysAgo: 7) == .limitEdge)
        #expect(due(installedDaysAgo: 60, reachedDaysAgo: 30) == .limitEdge)
    }

    @Test("일주일이 안 됐으면 안 뜬다. 닿자마자 들이밀지 않는다")
    func waitsAFullWeek() {
        #expect(due(installedDaysAgo: 60, reachedDaysAgo: 0) == nil)
        #expect(due(installedDaysAgo: 60, reachedDaysAgo: 6.9) == nil)
    }

    @Test("한 칸 앞에 닿은 적이 없으면 두 번째 기회는 오지 않는다")
    func requiresReachingTheEdge() {
        #expect(due(installedDaysAgo: 60, reachedDaysAgo: nil) == nil)
    }

    // MARK: - 두 기회의 관계

    @Test("기회는 각각 한 번씩. 첫 기회를 봤어도 두 번째는 그대로 온다")
    func eachOccasionFiresOnce() {
        // 설치 제안을 이미 봤지만, 한도 제안은 아직이다.
        #expect(due(installedDaysAgo: 60, reachedDaysAgo: 7, shown: [.firstRun]) == .limitEdge)
        // 둘 다 봤으면 끝이다.
        #expect(due(installedDaysAgo: 60, reachedDaysAgo: 7, shown: [.firstRun, .limitEdge]) == nil)
        // 설치 제안만 안 봤으면 그것만 온다.
        #expect(due(installedDaysAgo: 1, shown: [.limitEdge]) == .firstRun)
    }

    @Test("둘 다 자격이 되면 한도 쪽이 이긴다. 써 보고 닿은 사람이 더 뚜렷한 신호다")
    func limitEdgeWinsWhenBothAreDue() {
        #expect(due(installedDaysAgo: 2, reachedDaysAgo: 7) == .limitEdge)
    }

    // MARK: - 공통으로 막는 것

    @Test("이미 Pro 인 사람에게는 어느 자리에서도 뜨지 않는다")
    func neverOffersToPro() {
        #expect(due(hasPro: true) == nil)
        #expect(due(installedDaysAgo: 60, reachedDaysAgo: 7, hasPro: true) == nil)
    }

    /// ⚠️ 가장 중요한 줄. 반값 상품이 없는데 창이 뜨면 **정가를 반값이라 부르게 된다.**
    @Test("반값 상품이 로드되지 않았으면 아예 뜨지 않는다")
    func neverAdvertisesAnUnavailableDiscount() {
        #expect(due(discountAvailable: false) == nil)
        #expect(due(installedDaysAgo: 60, reachedDaysAgo: 7, discountAvailable: false) == nil)
    }

    @Test("두 번째 기회가 겨냥하는 개수는 무료 한도 바로 한 칸 앞이다")
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

    @Test("본 기회만 기록되고, 나머지 기회는 그대로 남는다")
    func markShownRecordsOneOccasionAtATime() {
        DiscountOfferManager.resetForTesting()
        defer { DiscountOfferManager.resetForTesting() }

        #expect(DiscountOfferManager.shownOccasions.isEmpty)

        DiscountOfferManager.markShown(.firstRun)
        #expect(DiscountOfferManager.shownOccasions == [.firstRun])

        DiscountOfferManager.markShown(.limitEdge)
        #expect(DiscountOfferManager.shownOccasions == [.firstRun, .limitEdge])
    }
}
