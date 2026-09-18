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
                     isMidFirstShortcut: Bool = false,
                     awayOrJustBack: Bool = false,
                     hoards: Bool = false,
                     fits: Bool = true) -> DiscountOfferManager.Occasion? {
        DiscountOfferManager.dueOccasion(now: now, context: .init(
            installedAt: installedDaysAgo.map { daysAgo($0) },
            reachedLimitEdgeAt: reachedDaysAgo.map { daysAgo($0) },
            shownOccasions: shown,
            hasPro: hasPro,
            discountAvailable: discountAvailable,
            isMidFirstShortcut: isMidFirstShortcut,
            isAwayOrJustBack: awayOrJustBack,
            hoardsUnusedShortcuts: hoards,
            fitsDiscountOffer: fits
        ))
    }

    // MARK: - 상태가 막는 자리

    /// 돌아온 것 자체가 좋은 신호다. 그 첫 화면이 결제 창이면 다시 나간다.
    @Test("오랜만에 돌아온 사람에게는 두 기회 모두 꺼내지 않는다")
    func silentForSomeoneComingBack() {
        #expect(due(awayOrJustBack: true) == nil)
        #expect(due(reachedDaysAgo: 8, awayOrJustBack: true) == nil)
    }

    /// 만들어만 두고 대부분 안 쓰는 사람에게 "칸이 한 칸 남았다" 는 틀린 말이다.
    /// 모자란 것은 칸이 아니라 찾는 길이라, 칸을 사면 못 찾는 것이 하나 더 늘 뿐이다.
    @Test("쌓아만 두는 사람에게는 한도 기회를 꺼내지 않는다")
    func silentAboutRoomForHoarders() {
        #expect(due(installedDaysAgo: 30, reachedDaysAgo: 8) == .limitEdge)
        #expect(due(installedDaysAgo: 30, reachedDaysAgo: 8, hoards: true) == nil)
    }

    // MARK: - 설치 직후는 더 이상 기회가 아니다 (5.2)

    /// 가치를 보기 전의 할인은 **정가에 대한 정보만** 남긴다.
    /// 사는 사람은 반값에 사고, 안 사는 사람은 정가가 제값이 아니라는 것만 배우고 간다.
    /// 일시불 앱에서 기다리기 시작한 사람은 대개 영영 안 산다.
    @Test("쓰임새로 보아 값을 깎아 권할 사람이 아니면 꺼내지 않는다 (학생으로 확신)")
    func silentWhenTheFitSaysNo() {
        #expect(due(reachedDaysAgo: 8) == .limitEdge)
        #expect(due(reachedDaysAgo: 8, fits: false) == nil)
    }

    @Test("설치 직후에는 아무 제안도 하지 않는다")
    func neverOffersRightAfterInstall() {
        #expect(due(installedDaysAgo: 0) == nil)
        #expect(due(installedDaysAgo: 1) == nil)
        #expect(due(installedDaysAgo: 6.9) == nil)
        #expect(due(installedDaysAgo: 8) == nil)
    }

    /// ⚠️ 기록이 남아 있는 기기가 있어서 케이스 자체는 지우지 않았다.
    ///    그래도 **판정은 다시는 그것을 돌려주지 않는다.** 여기가 그 계약이다.
    @Test("설치 직후 기회는 어떤 조합으로도 돌아오지 않는다")
    func firstRunNeverComesBack() {
        for days in [0.0, 0.5, 3, 6.9, 7, 30] {
            #expect(due(installedDaysAgo: days) != .firstRun)
            #expect(due(installedDaysAgo: days, hoards: true) != .firstRun)
            #expect(due(installedDaysAgo: days, reachedDaysAgo: 8) != .firstRun)
        }
    }

    @Test("첫 단축어를 만들기 전에는 뜨지 않는다. 튜토리얼 위에 결제 창을 얹지 않는다")
    func yieldsToTheFirstShortcutTutorial() {
        #expect(due(installedDaysAgo: 60, reachedDaysAgo: 8, isMidFirstShortcut: true) == nil)
        // 만들거나 건너뛰고 나면 그때 온다.
        #expect(due(installedDaysAgo: 60, reachedDaysAgo: 8, isMidFirstShortcut: false) == .limitEdge)
    }

    @Test("설치 시각을 몰라도 한도 기회는 그대로 온다. 그 판정은 설치일을 보지 않는다")
    func limitEdgeDoesNotNeedInstallDate() {
        #expect(due(installedDaysAgo: nil, reachedDaysAgo: 8) == .limitEdge)
    }

    // MARK: - 한도 한 칸 앞

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

    // MARK: - 한 번뿐이라는 것

    @Test("기회는 평생 한 번. 예전에 설치 제안을 봤던 기기에서도 한도 제안은 그대로 온다")
    func theOfferFiresOnce() {
        // 예전 버전에서 설치 제안을 본 기록이 남아 있어도 한도 제안은 막히지 않는다.
        #expect(due(installedDaysAgo: 60, reachedDaysAgo: 7, shown: [.firstRun]) == .limitEdge)
        // 한도 제안까지 봤으면 끝이다.
        #expect(due(installedDaysAgo: 60, reachedDaysAgo: 7, shown: [.firstRun, .limitEdge]) == nil)
        #expect(due(installedDaysAgo: 60, reachedDaysAgo: 7, shown: [.limitEdge]) == nil)
    }

    @Test("설치한 지 얼마 안 됐어도, 한도에 닿고 일주일이 지났으면 그쪽으로 온다")
    func limitEdgeIsTheOnlyDoor() {
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
        // ⚠️ `limitEdgeCount` 를 그대로 보지 않는다. 그 값은 App Group 에 남아 있는
        //    Pro 권한·산 칸수를 읽어서, 주변에 무엇이 남았느냐에 따라 통과했다 실패했다 한다.
        //    (실제로 그랬다. `ProFeatureManagerTests` 가 먼저 돌아 키를 치워 줄 때만 초록이었다)
        //    전역을 잠깐 비우는 방법도 써 봤지만, 나란히 도는 `SlotPackTests` 가 그 틈에
        //    엉뚱한 값을 읽었다. 규칙은 상태 없이 본다.
        #expect(ProFeatureManager.freeMemoLimit == 10)
        #expect(DiscountOfferManager.limitEdge(forMemoLimit: ProFeatureManager.freeMemoLimit) == 9)
        // 칸을 산 사람은 그만큼 뒤에서 겨냥한다 - 9개에서 "한 칸 남았다"고 하면 거짓말이다.
        #expect(DiscountOfferManager.limitEdge(forMemoLimit: 15) == 14)
        // 한도가 아무리 작아도 0개를 겨냥하지는 않는다.
        #expect(DiscountOfferManager.limitEdge(forMemoLimit: 1) == 1)
    }

    // MARK: - 기록

    @Test("한 칸 앞에 처음 닿은 시각만 남고, 그 뒤 개수가 늘거나 줄어도 시계는 그대로다")
    func recordsTheFirstTimeOnly() {
        DiscountOfferManager.resetForTesting()
        defer { DiscountOfferManager.resetForTesting() }

        // 겨냥 개수를 직접 넘긴다. 기본값은 App Group 의 Pro 권한을 읽어서,
        // 주변에 남은 상태에 따라 9가 아닐 수 있다(위 시험의 주석 참고).
        let edge = 9

        DiscountOfferManager.noteShortcutCount(3, edge: edge)
        #expect(DiscountOfferManager.reachedLimitEdgeAt == nil, "한도 앞에 닿기 전에는 기록하지 않는다")

        DiscountOfferManager.noteShortcutCount(9, edge: edge)
        let first = DiscountOfferManager.reachedLimitEdgeAt
        #expect(first != nil)

        // 하나 지웠다 다시 만들어도 시계가 되감기면 안 된다 - 오래 쓴 사람이 손해를 본다.
        DiscountOfferManager.noteShortcutCount(8, edge: edge)
        DiscountOfferManager.noteShortcutCount(12, edge: edge)
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
