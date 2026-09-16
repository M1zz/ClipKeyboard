//
//  SlotPackTests.swift
//  ClipKeyboardTests
//
//  칸 추가 상품이 **개수만** 늘리는지 못박는다.
//
//  이 상품의 위험은 두 방향이다.
//   · 너무 적게 열면: 산 사람이 11번째에서 그대로 막힌다(돈은 받고 기능은 안 준 셈).
//   · 너무 많이 열면: 작은 값에 평생 Pro 가 열린다(되돌릴 방법이 없다).
//  그래서 "한도는 늘어난다"와 "그 밖에는 그대로다"를 함께 붙잡는다.
//
//  5.2부터 상품이 둘이다(예전 비소모성 + 다시 살 수 있는 소모성). 여기서 지켜야 할 것이
//  둘 더 늘었다.
//   · 예전 상품을 산 사람의 다섯 칸이 사라지지 않는다.
//   · 두 상품을 합쳐도 **15칸에서 멈춘다.** 안 멈추면 평생 Pro 를 살 이유가 없어진다.
//

import Testing
import Foundation
@testable import ClipKeyboard

@Suite("SlotPack, 칸 추가 상품", .serialized)
@MainActor
struct SlotPackTests {

    private func withSlots(_ purchased: Bool, _ body: () -> Void) {
        let before = SlotPack.purchasedSlots
        SlotPack.mirror(purchased: purchased)
        body()
        SlotPack.mirror(purchased: before > 0)
    }

    @Test("사기 전에는 기본 한도 그대로")
    func limitBeforePurchase() {
        withSlots(false) {
            #expect(SlotPack.purchasedSlots == 0)
            #expect(SlotPack.isPurchased == false)
            // Pro 가 아니면 기본 한도, Pro 면 무제한.
            if !ProFeatureManager.hasFullAccess {
                #expect(ProFeatureManager.memoLimit == ProFeatureManager.freeMemoLimit)
            }
        }
    }

    @Test("사면 딱 다섯 칸이 늘어난다")
    func limitAfterPurchase() {
        withSlots(true) {
            #expect(SlotPack.purchasedSlots == SlotPack.slotsPerPack)
            if !ProFeatureManager.hasFullAccess {
                #expect(ProFeatureManager.memoLimit == ProFeatureManager.freeMemoLimit + 5)
                // 늘어난 칸이 **저장 관문**에도 반영돼야 한다. 여기가 빠지면 돈만 받은 셈이다.
                #expect(ProFeatureManager.canAddMemo(currentCount: ProFeatureManager.freeMemoLimit))
                #expect(ProFeatureManager.canAddMemo(currentCount: ProFeatureManager.freeMemoLimit + 4))
                #expect(ProFeatureManager.canAddMemo(currentCount: ProFeatureManager.freeMemoLimit + 5) == false)
            }
        }
    }

    @Test("칸을 사도 Pro 기능은 열리지 않는다")
    func slotsDoNotUnlockProFeatures() {
        let proBefore = ProFeatureManager.hasFullAccess
        withSlots(true) {
            #expect(ProFeatureManager.hasFullAccess == proBefore, "칸 추가는 Pro 권한과 무관하다")
        }
    }

    // MARK: - 다시 살 수 있는 팩 (5.2)

    /// 팩 수를 직접 세워 두고 본다(결제 없이 상태만 만든다).
    private func withPacks(legacy: Bool, packs: Int, _ body: () -> Void) {
        let d = AppGroup.defaults
        let beforeLegacy = d?.integer(forKey: DefaultsKey.purchasedExtraSlots) ?? 0
        let beforePacks = d?.integer(forKey: DefaultsKey.purchasedSlotPacks) ?? 0
        d?.set(legacy ? SlotPack.slotsPerPack : 0, forKey: DefaultsKey.purchasedExtraSlots)
        d?.set(packs, forKey: DefaultsKey.purchasedSlotPacks)
        body()
        d?.set(beforeLegacy, forKey: DefaultsKey.purchasedExtraSlots)
        d?.set(beforePacks, forKey: DefaultsKey.purchasedSlotPacks)
    }

    @Test("팩은 쌓인다. 한 번 샀다고 사다리가 끊기지 않는다")
    func packsAccumulate() {
        withPacks(legacy: false, packs: 0) {
            #expect(SlotPack.purchasedSlots == 0)
            #expect(SlotPack.canBuyMore)
        }
        withPacks(legacy: false, packs: 1) { #expect(SlotPack.purchasedSlots == 5) }
        withPacks(legacy: false, packs: 2) { #expect(SlotPack.purchasedSlots == 10) }
        withPacks(legacy: false, packs: 3) { #expect(SlotPack.purchasedSlots == 15) }
    }

    @Test("15칸에서 멈춘다. 그 위가 필요한 사람에게 팔 물건은 칸이 아니라 평생이다")
    func stopsAtTheCap() {
        withPacks(legacy: false, packs: 3) {
            #expect(SlotPack.canBuyMore == false)
            #expect(SlotPack.remainingPurchasableSlots == 0)
            #expect(SlotPack.purchasedSlots == SlotPack.maxExtraSlots)
        }
        // 어떤 이유로 기록이 더 커져도 한도는 넘지 않는다(iCloud 에서 이상한 값이 와도).
        withPacks(legacy: true, packs: 9) {
            #expect(SlotPack.purchasedSlots == SlotPack.maxExtraSlots)
        }
    }

    @Test("예전 상품을 산 사람의 다섯 칸은 그대로 남고, 두 칸을 더 살 수 있다")
    func legacyBuyerKeepsSlotsAndCanBuyTwoMore() {
        withPacks(legacy: true, packs: 0) {
            #expect(SlotPack.purchasedSlots == 5)
            #expect(SlotPack.isPurchased)
            #expect(SlotPack.canBuyMore)
            #expect(SlotPack.remainingPurchasableSlots == 10)
        }
        // 예전 것 + 새 팩 하나 = 열 칸.
        withPacks(legacy: true, packs: 1) {
            #expect(SlotPack.purchasedSlots == 10)
            #expect(SlotPack.remainingPurchasableSlots == 5)
        }
    }

    @Test("칸을 산 사람에게만 업그레이드 값을 보여 준다")
    func onlySlotBuyersSeeTheUpgrade() {
        guard !ProFeatureManager.hasPermanentPro else { return }
        withPacks(legacy: false, packs: 0) {
            #expect(ProUpgrade.isEligible == false, "안 산 사람에게 싼 값을 보이면 정가를 기다리기 시작한다")
        }
        withPacks(legacy: false, packs: 1) {
            #expect(ProUpgrade.isEligible)
        }
    }

    @Test("칸을 사도 두 대째(동기화)는 열리지 않는다")
    func slotsDoNotOpenSync() {
        let syncBefore = ProFeatureManager.isSyncAvailable
        withPacks(legacy: false, packs: 2) {
            #expect(ProFeatureManager.isSyncAvailable == syncBefore)
        }
    }

    @Test("반값 제안이 겨냥하는 자리도 늘어난 한도를 따라간다")
    func offerEdgeFollowsTheLimit() {
        guard !ProFeatureManager.hasFullAccess else { return }
        withSlots(false) {
            #expect(DiscountOfferManager.limitEdgeCount == ProFeatureManager.freeMemoLimit - 1)
        }
        withSlots(true) {
            #expect(DiscountOfferManager.limitEdgeCount == ProFeatureManager.freeMemoLimit + 4)
        }
    }
}
