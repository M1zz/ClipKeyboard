//
//  ClipKeyboardSpecTests.swift
//  ClipKeyboardTests
//
//  LeeoAppSpec 준수값의 리그레션 테스트 - CloudKit Dashboard·기존 사용자 기기와의 계약.
//  일반 피드백 로직 테스트는 LeeoKit(LeeoFeedbackServiceTests)으로 이동했다.
//

import XCTest
import LeeoKit
@testable import ClipKeyboard

final class ClipKeyboardSpecTests: XCTestCase {

    func testContainerIdentifierMatchesEntitlements() {
        // 공용 피드백 허브(FeedbackHub)로 전환됨 - entitlements와 어긋나면 제출이 조용히 실패한다
        XCTAssertEqual(ClipKeyboardSpec.feedback.containerIdentifier, "iCloud.com.Ysoup.FeedbackHub")
    }

    func testRecordTypeIsStable() {
        // Dashboard의 Record Type 이름 - 바꾸면 기존 피드백이 전부 조회에서 빠진다
        XCTAssertEqual(ClipKeyboardSpec.feedback.recordType, "Feedback")
    }

    func testNewFeedbackSubscriptionIDIsStable() {
        // 서버에 저장된 구독 ID - 바꾸면 기존 기기의 구독을 해제할 수 없게 된다
        XCTAssertEqual(ClipKeyboardSpec.feedback.subscriptionID, "feedback-new-v1")
    }

    func testAppIdentifierForSharedHub() {
        // 공용 허브 전환 완료 - appIdentifier로 앱을 구분한다
        XCTAssertEqual(ClipKeyboardSpec.feedback.appIdentifier, "com.Ysoup.TokenMemo")
    }

    func testAppNameAndDeveloperEmail() {
        XCTAssertEqual(ClipKeyboardSpec.appName, "ClipKeyboard")
        XCTAssertEqual(ClipKeyboardSpec.developerEmail, Constants.developerEmail)
    }

    // MARK: - 결제 계약 (LeeoKit 3.x: monetization 에서 페이월이 유도된다)

    /// ⚠️ `paywall` 을 직접 선언하지 않고 `monetization` 에서 받아 쓴다. 유도가 끊기면
    ///    `StoreManager.init` 의 `ClipKeyboardSpec.paywall!` 이 nil 을 강제 언랩해
    ///    **앱이 실행 즉시 죽는다.** 그래서 있다/없다부터 붙잡아 둔다.
    func testPaywallIsDerivedFromMonetization() {
        XCTAssertNotNil(ClipKeyboardSpec.paywall)
        XCTAssertTrue(ClipKeyboardSpec.monetization.requiresPaywall)
        XCTAssertTrue(ClipKeyboardSpec.monetization.requiresRestore, "비소모성 판매 - 복원 경로는 심사 필수")
    }

    /// 파는 물건은 여섯(정가·반값·업그레이드·칸 추가 둘·두 대째),
    /// **Pro 권한은 평생을 여는 셋뿐**이다.
    ///
    /// ⚠️ 이 테스트가 이 저장소에서 가장 비싼 사고를 막는다. LeeoKit 은 `entitlementIDs` 를
    ///    안 주면 파는 상품 전체를 권한으로 보므로, 칸 추가나 두 대째가 권한에 섞이면
    ///    작은 결제로 평생 Pro 가 열린다. 그리고 한 번 준 권한은 되돌릴 방법이 없다.
    func testSmallProductsNeverGrantPro() {
        let paywall = ClipKeyboardSpec.paywall
        XCTAssertEqual(paywall?.productIDs, [StoreManager.proProductID,
                                             DiscountOfferManager.discountedProProductID,
                                             ProUpgrade.productID,
                                             SlotPack.productID,
                                             SlotPack.consumableProductID,
                                             TwoDevicePack.productID])
        XCTAssertEqual(paywall?.entitlementIDs, [StoreManager.proProductID,
                                                 DiscountOfferManager.discountedProProductID,
                                                 ProUpgrade.productID])
        for small in [SlotPack.productID, SlotPack.consumableProductID, TwoDevicePack.productID] {
            XCTAssertFalse(paywall?.entitlementIDs.contains(small) ?? true,
                           "\(small) 가 Pro 권한이 되면 안 된다")
        }
    }

    /// 업그레이드는 **반드시** 권한이어야 한다.
    /// 빠지면 돈을 받고 아무것도 안 열어 주는 상품이 된다(반대 방향의 같은 크기 사고다).
    func testUpgradeGrantsPro() {
        XCTAssertTrue(ClipKeyboardSpec.paywall?.entitlementIDs.contains(ProUpgrade.productID) ?? false,
                      "업그레이드를 사고도 Pro 가 안 되면 안 된다")
    }

    /// 앱 그룹 Pro 키에 새기는 판정도 권한 상품 **셋 모두**를 봐야 한다.
    ///
    /// 한때 이 판정은 정가 ID 하나만 봤다. 스펙의 권한 목록은 맞았는데 새기는 쪽이
    /// 달라서, 반값·업그레이드로 산 사람은 `clipkeyboard_is_pro` 가 false 로 남았다.
    func testEveryEntitlementProductIsMirroredAsPro() {
        for id in [StoreManager.proProductID, DiscountOfferManager.discountedProProductID, ProUpgrade.productID] {
            XCTAssertTrue(StoreManager.grantsPro([id]), "\(id) 를 사면 Pro 키가 켜져야 한다")
        }
        for small in [SlotPack.productID, SlotPack.consumableProductID, TwoDevicePack.productID] {
            XCTAssertFalse(StoreManager.grantsPro([small]), "\(small) 로 Pro 키가 켜지면 안 된다")
        }
        XCTAssertFalse(StoreManager.grantsPro([]))
    }

    /// 가족 공유로만 받은 Pro 는 통계에서 결제가 아니다. 한 번이라도 직접 샀으면 결제다.
    func testFamilySharedOnlyProIsNotPayment() {
        let pro = StoreManager.proProductID
        XCTAssertTrue(StoreManager.proIsFamilySharedOnly([(pro, true)]))
        XCTAssertFalse(StoreManager.proIsFamilySharedOnly([(pro, false)]))
        XCTAssertFalse(StoreManager.proIsFamilySharedOnly([(pro, true), (ProUpgrade.productID, false)]))
        XCTAssertFalse(StoreManager.proIsFamilySharedOnly([]), "권한이 없으면 가족 공유도 아니다")
        XCTAssertFalse(StoreManager.proIsFamilySharedOnly([(TwoDevicePack.productID, true)]),
                       "Pro 가 아닌 상품의 가족 공유는 따지지 않는다")
    }

    /// 권한 캐시는 앱 그룹에 있어야 한다 - 아니면 키보드 익스텐션이 오프라인에서 Pro 를 잊는다.
    func testEntitlementCacheIsSharedWithExtensions() {
        XCTAssertEqual(ClipKeyboardSpec.paywall?.cacheSuiteName, AppGroup.identifier)
    }

    /// 무료 한도가 게이트로 선언돼 있어야 페이월에 도달할 경로가 생긴다.
    func testFreeLimitIsDeclaredAsAGate() {
        XCTAssertEqual(ClipKeyboardSpec.gate.freeLimits["shortcut"], ProFeatureManager.freeMemoLimit)
        XCTAssertTrue(ClipKeyboardSpec.gate.hasAnyGate)
    }

    /// LeeoKit 계약의 자체 감사 - 선언끼리 어긋나는 것을 잡는다(예: 팔 물건은 있는데 게이트가 없음).
    func testPreflightHasNoErrors() {
        let errors = LeeoPreflight.audit(ClipKeyboardSpec.self).filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty, "LeeoKit 프리플라이트 오류: \(errors)")
    }
}
