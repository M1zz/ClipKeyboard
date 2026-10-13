//
//  AccessTierTests.swift
//  ClipKeyboardTests
//
//  어떤 상품이 어느 트림을 여는가. 여기가 틀리면 돈을 받고 덜 열거나, 덜 받고 더 연다.
//

import XCTest
@testable import ClipKeyboard

final class AccessTierTests: XCTestCase {

    func testNothingOwned_IsFree() {
        XCTAssertEqual(AccessTier.purchased(from: []), .free)
    }

    /// 옵션(칸 팩 · 두 대째)은 트림이 아니다.
    func testOptions_DoNotOpenATier() {
        XCTAssertEqual(AccessTier.purchased(from: [SlotPack.consumableProductID, TwoDevicePack.productID]), .free)
    }

    /// 플러스는 예전 칸 상품 `slots5` 다. 그걸 산 사람은 플러스를 받는다.
    func testPlus_IsTheLegacySlotProduct() {
        XCTAssertEqual(AccessTier.plusProductID, SlotPack.productID)
        XCTAssertEqual(AccessTier.purchased(from: [SlotPack.productID]), .plus)
    }

    /// 플러스 → 프로는 예전 업그레이드 상품이다.
    func testPlusToPro_IsTheLegacyUpgrade() {
        XCTAssertEqual(AccessTier.plusToProProductID, ProUpgrade.productID)
    }

    /// 예전에 판 Pro 넷(정가 · 연 구독 · 반값 · 칸 산 사람의 업그레이드)은 전부 프로다.
    func testLegacyProProducts_AreProTier() {
        for id in [StoreManager.proProductID, StoreManager.yearlyProductID,
                   DiscountOfferManager.discountedProProductID, ProUpgrade.productID] {
            XCTAssertEqual(AccessTier.purchased(from: [id]), .pro, id)
        }
    }

    func testUpgrades_OpenTheirTarget() {
        XCTAssertEqual(AccessTier.purchased(from: [AccessTier.plusProductID, AccessTier.plusToProProductID]), .pro)
        XCTAssertEqual(AccessTier.purchased(from: [StoreManager.proProductID, AccessTier.proToMasterProductID]), .master)
        XCTAssertEqual(AccessTier.purchased(from: [AccessTier.masterProductID]), .master)
    }

    /// 여럿을 가졌으면 가장 높은 것.
    func testHighestWins() {
        XCTAssertEqual(AccessTier.purchased(from: [AccessTier.plusProductID, AccessTier.masterProductID]), .master)
    }

    /// Pro 키(`proStatus`)를 켜는 판정과 트림 판정이 같은 답을 내야 한다.
    /// 둘이 갈리면 키보드(Pro 키를 보는 곳)와 앱(트림을 보는 곳)이 다른 권한을 본다.
    func testProKeyAgreesWithTier() {
        for id in AccessTier.allTierProductIDs {
            let tier = AccessTier.purchased(from: [id])
            XCTAssertEqual(StoreManager.grantsPro([id]), tier >= .pro, id)
        }
    }

    /// 상품 ID 는 영수증과의 계약이다. 바뀌면 산 사람이 잠긴다.
    func testProductIDsAreStable() {
        XCTAssertEqual(AccessTier.plusProductID, "com.Ysoup.TokenMemo.slots5")
        XCTAssertEqual(AccessTier.plusToProProductID, "com.Ysoup.TokenMemo.pro.upgrade")
        XCTAssertEqual(AccessTier.masterProductID, "com.Ysoup.TokenMemo.tier.master")
        XCTAssertEqual(AccessTier.proToMasterProductID, "com.Ysoup.TokenMemo.up.pro.master")
        XCTAssertEqual(AccessTier.legacyProProductIDs,
                       [StoreManager.proProductID, StoreManager.yearlyProductID,
                        DiscountOfferManager.discountedProProductID])
    }
}
