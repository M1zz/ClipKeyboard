//
//  SlotPackTests.swift
//  ClipKeyboardTests
//
//  칸 추가 상품이 **개수만** 늘리는지 못박는다.
//
//  이 상품의 위험은 두 방향이다.
//   · 너무 적게 열면: 산 사람이 11번째에서 그대로 막힌다(돈은 받고 기능은 안 준 셈).
//   · 너무 많이 열면: $3 에 평생 Pro 가 열린다(되돌릴 방법이 없다).
//  그래서 "한도는 늘어난다"와 "그 밖에는 그대로다"를 함께 붙잡는다.
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
