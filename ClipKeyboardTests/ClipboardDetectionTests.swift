//
//  ClipboardDetectionTests.swift
//  ClipKeyboardTests
//
//  Created by Claude Code on 2026-01-16.
//  클립보드 자동 분류 테스트
//

import XCTest
@testable import ClipKeyboard

final class ClipboardDetectionTests: XCTestCase {

    // MARK: - Email Detection Tests

    func testEmailDetection_ValidEmails() {
        // Given
        let validEmails = [
            "test@example.com",
            "user.name@domain.co.kr",
            "admin+tag@company.com",
            "contact@sub.domain.com"
        ]

        // When & Then
        for email in validEmails {
            let detected = detectClipboardType(email)
            XCTAssertEqual(detected.type, .email, "'\(email)' should be detected as email")
            XCTAssertGreaterThan(detected.confidence, 0.8)
        }
    }

    func testEmailDetection_InvalidEmails() {
        // Given - service의 detectEmail은 anchor `^...$` 사용. 부분 매치 불가.
        let invalidEmails = [
            "not an email",
            "@example.com",
            "user@",
        ]

        // When & Then
        for text in invalidEmails {
            let detected = detectClipboardType(text)
            XCTAssertNotEqual(detected.type, .email, "'\(text)' should not be detected as email")
        }
    }

    // MARK: - Phone Number Detection Tests

    func testPhoneDetection_ValidPhones() {
        // Given
        let validPhones = [
            "010-1234-5678",
            "01012345678",
            "02-1234-5678",
            "031-123-4567",
            "+82-10-1234-5678"
        ]

        // When & Then
        for phone in validPhones {
            let detected = detectClipboardType(phone)
            XCTAssertEqual(detected.type, .phone, "'\(phone)' should be detected as phone")
            XCTAssertGreaterThan(detected.confidence, 0.8)
        }
    }

    func testPhoneDetection_InvalidPhones() {
        // Given
        let invalidPhones = [
            "123",
            "abcd-efgh-ijkl",
            "010-123-456" // 너무 짧음
        ]

        // When & Then
        for text in invalidPhones {
            let detected = detectClipboardType(text)
            XCTAssertNotEqual(detected.type, .phone, "'\(text)' should not be detected as phone")
        }
    }

    // MARK: - URL Detection Tests

    func testURLDetection_ValidURLs() {
        // Given
        let validURLs = [
            "https://www.example.com",
            "http://example.com",
            "https://sub.domain.com/path",
            "www.example.com"
        ]

        // When & Then
        for url in validURLs {
            let detected = detectClipboardType(url)
            XCTAssertEqual(detected.type, .url, "'\(url)' should be detected as URL")
            XCTAssertGreaterThan(detected.confidence, 0.8)
        }
    }

    // MARK: - Credit Card Detection Tests

    func testCreditCardDetection_ValidCards() {
        // Given - service의 detectCreditCard는 Luhn 체크섬을 검증하므로 임의 16자리는 거부.
        // Stripe 테스트 카드(4242...)는 Luhn 통과 보장.
        let validCards = [
            "4242-4242-4242-4242",
            "4242424242424242",
            "4242 4242 4242 4242"
        ]

        // When & Then
        for card in validCards {
            let detected = detectClipboardType(card)
            XCTAssertEqual(detected.type, .creditCard, "'\(card)' should be detected as credit card")
            XCTAssertGreaterThan(detected.confidence, 0.7)
        }
    }

    // MARK: - IP Address Detection Tests

    func testIPAddressDetection_ValidIPs() {
        // Given
        let validIPs = [
            "192.168.0.1",
            "10.0.0.1",
            "255.255.255.255",
            "127.0.0.1"
        ]

        // When & Then
        for ip in validIPs {
            let detected = detectClipboardType(ip)
            XCTAssertEqual(detected.type, .ipAddress, "'\(ip)' should be detected as IP address")
            XCTAssertGreaterThan(detected.confidence, 0.9)
        }
    }

    func testIPAddressDetection_InvalidIPs() {
        // Given
        let invalidIPs = [
            "256.256.256.256",
            "192.168.0",
            "192.168.0.1.1",
            "abc.def.ghi.jkl"
        ]

        // When & Then
        for text in invalidIPs {
            let detected = detectClipboardType(text)
            XCTAssertNotEqual(detected.type, .ipAddress, "'\(text)' should not be detected as IP")
        }
    }

    // MARK: - Postal Code Detection Tests

    func testPostalCodeDetection_ValidCodes() {
        // Given
        let validCodes = [
            "12345",
            "06234",
            "01234"
        ]

        // When & Then
        for code in validCodes {
            let detected = detectClipboardType(code)
            XCTAssertEqual(detected.type, .postalCode, "'\(code)' should be detected as postal code")
        }
    }

    // MARK: - Multiple Type Priority Tests

    func testDetectionPriority_EmailOverText() {
        // Given - service의 detectEmail은 anchor `^...$` 기반이라 순수 입력만 인식
        let text = "test@example.com"

        // When
        let detected = detectClipboardType(text)

        // Then
        XCTAssertEqual(detected.type, .email)
    }

    func testDetectionPriority_PhoneOverText() {
        // Given - service의 detector는 anchor `^...$` 기반이라 순수 전화번호만 인식.
        // 자연어 안의 전화번호 추출은 별도 NSDataDetector 작업 영역이므로 여기서는 순수 입력만 검증.
        let text = "010-1234-5678"

        // When
        let detected = detectClipboardType(text)

        // Then
        XCTAssertEqual(detected.type, .phone)
    }

    // MARK: - Confidence Score Tests

    func testConfidenceScore_HighConfidence() {
        // Given
        let clearEmail = "admin@company.com"

        // When
        let detected = detectClipboardType(clearEmail)

        // Then
        XCTAssertGreaterThanOrEqual(detected.confidence, 0.9)
    }

    func testConfidenceScore_MediumConfidence() {
        // Given
        let ambiguousText = "1234-5678" // 전화번호인지 다른 번호인지 애매함

        // When
        let detected = detectClipboardType(ambiguousText)

        // Then
        XCTAssertLessThan(detected.confidence, 0.9)
    }

    // MARK: - Helper Method

    /// 실제 ClipboardClassificationService를 호출 — 이전엔 자체 정규식이 약해 service 동작과 어긋났음
    private func detectClipboardType(_ content: String) -> (type: ClipboardItemType, confidence: Double) {
        return ClipboardClassificationService.shared.classify(content: content)
    }
}
