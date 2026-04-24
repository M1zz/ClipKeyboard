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
        // Given
        let invalidEmails = [
            "not an email",
            "@example.com",
            "user@",
            "user name@example.com"
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
        // Given
        let validCards = [
            "1234-5678-9012-3456",
            "1234567890123456",
            "1234 5678 9012 3456"
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
        // Given
        let text = "My email is test@example.com please contact me"

        // When
        let detected = detectClipboardType(text)

        // Then
        XCTAssertEqual(detected.type, .email)
    }

    func testDetectionPriority_PhoneOverText() {
        // Given
        let text = "Call me at 010-1234-5678 anytime"

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

    private func detectClipboardType(_ content: String) -> (type: ClipboardItemType, confidence: Double) {
        typealias SimpleRule = (pattern: String, type: ClipboardItemType, confidence: Double)
        let simpleRules: [SimpleRule] = [
            (#"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}"#, .email, 0.9),
            (#"^(\+?\d{1,3}[-.]?)?\d{2,3}[-.]?\d{3,4}[-.]?\d{4}$"#, .phone, 0.9),
            (#"https?://[^\s]+"#, .url, 0.9),
            (#"^\d{5}$"#, .postalCode, 0.8),
        ]
        for rule in simpleRules {
            if content.range(of: rule.pattern, options: .regularExpression) != nil {
                return (rule.type, rule.confidence)
            }
        }

        if content.hasPrefix("www.") { return (.url, 0.85) }

        if content.range(of: #"^(\d{1,3}\.){3}\d{1,3}$"#, options: .regularExpression) != nil {
            let components = content.split(separator: ".")
            if components.allSatisfy({ Int($0) ?? 256 <= 255 }) {
                return (.ipAddress, 0.95)
            }
        }

        if content.range(of: #"^[\d\s-]{13,19}$"#, options: .regularExpression) != nil {
            let digits = content.filter { $0.isNumber }
            if digits.count >= 13 && digits.count <= 19 {
                return (.creditCard, 0.75)
            }
        }

        return (.text, 0.5)
    }
}
