//
//  ClipKeyboardSpecTests.swift
//  ClipKeyboardTests
//
//  LeeoAppSpec 준수값의 리그레션 테스트 — CloudKit Dashboard·기존 사용자 기기와의 계약.
//  일반 피드백 로직 테스트는 LeeoKit(LeeoFeedbackServiceTests)으로 이동했다.
//

import XCTest
import LeeoKit
@testable import ClipKeyboard

final class ClipKeyboardSpecTests: XCTestCase {

    func testContainerIdentifierMatchesEntitlements() {
        // 공용 피드백 허브(FeedbackHub)로 전환됨 — entitlements와 어긋나면 제출이 조용히 실패한다
        XCTAssertEqual(ClipKeyboardSpec.feedback.containerIdentifier, "iCloud.com.Ysoup.FeedbackHub")
    }

    func testRecordTypeIsStable() {
        // Dashboard의 Record Type 이름 — 바꾸면 기존 피드백이 전부 조회에서 빠진다
        XCTAssertEqual(ClipKeyboardSpec.feedback.recordType, "Feedback")
    }

    func testNewFeedbackSubscriptionIDIsStable() {
        // 서버에 저장된 구독 ID — 바꾸면 기존 기기의 구독을 해제할 수 없게 된다
        XCTAssertEqual(ClipKeyboardSpec.feedback.subscriptionID, "feedback-new-v1")
    }

    func testAppIdentifierForSharedHub() {
        // 공용 허브 전환 완료 — appIdentifier로 앱을 구분한다
        XCTAssertEqual(ClipKeyboardSpec.feedback.appIdentifier, "com.Ysoup.TokenMemo")
    }

    func testAppNameAndDeveloperEmail() {
        XCTAssertEqual(ClipKeyboardSpec.appName, "ClipKeyboard")
        XCTAssertEqual(ClipKeyboardSpec.developerEmail, Constants.developerEmail)
    }
}
