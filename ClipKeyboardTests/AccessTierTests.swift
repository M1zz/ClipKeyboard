//
//  AccessTierTests.swift
//  ClipKeyboardTests
//
//  어떤 상품이 어느 트림을 여는가. 여기가 틀리면 돈을 받고 덜 열거나, 덜 받고 더 연다.
//

import XCTest
import LeeoKit
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
    /// 반값은 2026-10 에 판매를 멈췄지만 산 사람의 권한은 그대로다.
    func testLegacyProProducts_AreProTier() {
        for id in [StoreManager.proProductID, AccessTier.proYearlyProductID,
                   "com.Ysoup.TokenMemo.pro.halfoff", ProUpgrade.productID] {
            XCTAssertEqual(AccessTier.purchased(from: [id]), .pro, id)
        }
    }

    // MARK: - 2026-10 요금제 사다리

    /// 연 구독은 같은 칸의 평생과 같은 권한이다.
    func testYearly_OpensTheSamePlanAsLifetime() {
        XCTAssertEqual(AccessTier.purchased(from: [AccessTier.plusYearlyProductID]), .plus)
        XCTAssertEqual(AccessTier.purchased(from: [AccessTier.plusProductID]), .plus)
        XCTAssertEqual(AccessTier.purchased(from: [AccessTier.proYearlyProductID]), .pro)
        XCTAssertEqual(AccessTier.purchased(from: [AccessTier.proProductID]), .pro)
    }

    /// Plus 를 구독하다가 Pro 를 구독하면 Pro. 둘 다 있어도 높은 쪽이다.
    func testPlusAndProSubscriptions_HighestWins() {
        XCTAssertEqual(AccessTier.purchased(from: AccessTier.subscriptionProductIDs), .pro)
        XCTAssertEqual(AccessTier.subscriptionProductIDs,
                       [AccessTier.plusYearlyProductID, AccessTier.proYearlyProductID])
    }

    /// 구독 졸업 상품은 Pro 평생이다.
    func testGraduate_IsLifetimePro() {
        XCTAssertEqual(AccessTier.purchased(from: [AccessTier.proGraduateProductID]), .pro)
        XCTAssertTrue(AccessTier.ownsLifetimePro([AccessTier.proGraduateProductID]))
        // 졸업하고 남은 구독 기간이 같이 있어도 평생 Pro 다.
        XCTAssertTrue(AccessTier.ownsLifetimePro([AccessTier.proGraduateProductID, AccessTier.proYearlyProductID]))
    }

    /// 올리기(Plus 평생 → Pro 평생)는 Pro 평생이다.
    func testUpgrade_IsLifetimePro() {
        XCTAssertEqual(AccessTier.purchased(from: [AccessTier.plusProductID, AccessTier.plusToProProductID]), .pro)
        XCTAssertTrue(AccessTier.ownsLifetimePro([AccessTier.plusToProProductID]))
    }

    /// 구독만으로는 평생을 가진 것이 아니다. 평생 Plus 만 산 사람에게 올리기 값이 보인다.
    func testLifetimeOwnership_IgnoresSubscriptions() {
        XCTAssertFalse(AccessTier.ownsLifetimePro([AccessTier.proYearlyProductID]))
        XCTAssertFalse(AccessTier.ownsLifetimePro([AccessTier.plusProductID]))
        XCTAssertTrue(AccessTier.ownsLifetimePlus([AccessTier.plusProductID]))
        XCTAssertFalse(AccessTier.ownsLifetimePlus([AccessTier.plusYearlyProductID]))
    }

    /// 언제나 평생 패스는 이 앱의 가장 높은 유료 칸(Pro)을 연다. 이미 더 높으면 그대로.
    func testForeverPass_OpensPro() {
        XCTAssertEqual(AccessTier.purchased(from: [], foreverPass: true), .pro)
        XCTAssertEqual(AccessTier.purchased(from: [AccessTier.plusYearlyProductID], foreverPass: true), .pro)
        XCTAssertEqual(AccessTier.purchased(from: [AccessTier.masterProductID], foreverPass: true), .master)
        XCTAssertEqual(AccessTier.purchased(from: [], foreverPass: false), .free)
    }

    /// 패스 상품 ID 는 이 앱의 권한 목록에 없다. 패스는 `LeeoForeverPass` 가 따로 판정한다.
    func testForeverPassProducts_AreNotTierProducts() {
        let pass = LeeoForeverPassRule.productIDs(bundleID: "com.Ysoup.TokenMemo")
        XCTAssertEqual(pass.count, 4)
        XCTAssertTrue(AccessTier.allTierProductIDs.isDisjoint(with: pass))
        XCTAssertEqual(AccessTier.purchased(from: Set(pass)), .free)
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
        XCTAssertEqual(AccessTier.plusYearlyProductID, "com.Ysoup.TokenMemo.plus.yearly")
        XCTAssertEqual(AccessTier.proProductID, "com.Ysoup.TokenMemo.pro")
        XCTAssertEqual(AccessTier.proYearlyProductID, "com.Ysoup.TokenMemo.pro.yearly")
        XCTAssertEqual(AccessTier.proGraduateProductID, "com.Ysoup.TokenMemo.pro.graduate")
        XCTAssertEqual(AccessTier.retiredProProductIDs, ["com.Ysoup.TokenMemo.pro.halfoff"])
    }
}
