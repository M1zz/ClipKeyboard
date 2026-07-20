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

    func testContainerIdentifierMatchesBackupContainer() {
        // CloudKitBackupService와 같은 컨테이너를 써야 Dashboard 한 곳에서 관리된다
        XCTAssertEqual(ClipKeyboardSpec.feedback.containerIdentifier, "iCloud.com.Ysoup.TokenMemo")
    }

    func testRecordTypeIsStable() {
        // Dashboard의 Record Type 이름 — 바꾸면 기존 피드백이 전부 조회에서 빠진다
        XCTAssertEqual(ClipKeyboardSpec.feedback.recordType, "Feedback")
    }

    func testNewFeedbackSubscriptionIDIsStable() {
        // 서버에 저장된 구독 ID — 바꾸면 기존 기기의 구독을 해제할 수 없게 된다
        XCTAssertEqual(ClipKeyboardSpec.feedback.subscriptionID, "feedback-new-v1")
    }

    func testAppIdentifierStaysNilForLegacySchema() {
        // appId 필드는 Production 스키마에 없다 — 공용 허브 전환 전까지 nil 유지
        XCTAssertNil(ClipKeyboardSpec.feedback.appIdentifier)
    }

    func testAppNameAndDeveloperEmail() {
        XCTAssertEqual(ClipKeyboardSpec.appName, "ClipKeyboard")
        XCTAssertEqual(ClipKeyboardSpec.developerEmail, Constants.developerEmail)
    }
}
