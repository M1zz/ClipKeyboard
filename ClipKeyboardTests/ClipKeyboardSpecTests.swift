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

    /// 파는 물건은 둘(정가·반값), 주는 권한은 하나. 어느 쪽을 샀든 Pro 로 인정돼야 한다.
    func testBothProductsGrantPro() {
        let paywall = ClipKeyboardSpec.paywall
        XCTAssertEqual(paywall?.productIDs, [StoreManager.proProductID,
                                             DiscountOfferManager.discountedProProductID])
        XCTAssertEqual(paywall?.entitlementIDs, [StoreManager.proProductID,
                                                 DiscountOfferManager.discountedProProductID])
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
