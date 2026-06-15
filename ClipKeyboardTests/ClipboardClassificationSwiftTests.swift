//
//  ClipboardClassificationSwiftTests.swift
//  ClipKeyboardTests
//
//  Swift Testing 스위트 — classify(content:)의 타입 판정과 우선순위.
//  기존 XCTest(ClipboardClassificationServiceTests)와 상호 보완하며,
//  파라미터라이즈드 테이블로 핵심 타입을 한눈에 검증한다.
//
//  명세: docs/FEATURE_SPEC.md §2
//

import Testing
import Foundation
@testable import ClipKeyboard

@Suite("ClipboardClassificationService — 자동 분류")
struct ClipboardClassificationSwiftTests {

    private var sut: ClipboardClassificationService { .shared }

    // MARK: - 타입 판정 (파라미터라이즈드)

    @Test("대표 입력은 기대 타입으로 분류된다", arguments: [
        ("test@example.com", ClipboardItemType.email),
        ("user+filter@gmail.com", .email),
        ("https://www.example.com/path?q=1", .url),
        ("4242424242424242", .creditCard),          // Luhn 통과
        ("GB82WEST12345698765432", .iban),          // mod-97 통과
        ("DEUTDEFF", .swift),
        ("192.168.1.1", .ipAddress),
        ("1990-05-15", .birthDate),
        ("P123456789012", .declarationNumber),
        ("0x742d35Cc6634C0532925a3b844Bc454e4438f44e", .cryptoWallet),
        ("https://paypal.me/johndoe", .paypalLink),
        ("M12345678", .passportNumber)
    ])
    func classifiesToExpectedType(input: String, expected: ClipboardItemType) {
        let result = sut.classify(content: input)
        #expect(result.type == expected)
        #expect(result.confidence > 0.0)
    }

    // MARK: - 빈/랜덤 입력

    @Test("빈 문자열은 텍스트, confidence 0")
    func emptyIsText() {
        let result = sut.classify(content: "")
        #expect(result.type == .text)
        #expect(result.confidence == 0.0)
    }

    @Test("공백만 있는 문자열은 텍스트, confidence 0")
    func whitespaceIsText() {
        let result = sut.classify(content: "   \n  ")
        #expect(result.type == .text)
        #expect(result.confidence == 0.0)
    }

    @Test("의미 없는 문장은 텍스트로 분류된다")
    func randomTextIsText() {
        let result = sut.classify(content: "hello world this is some random text")
        #expect(result.type == .text)
    }

    // MARK: - 우선순위 / 체크섬

    @Test("8자리 숫자는 계좌번호가 아니라 생년월일로 분류된다")
    func eightDigitsIsBirthDateNotBankAccount() {
        let result = sut.classify(content: "20240101")
        #expect(result.type == .birthDate)
        #expect(result.type != .bankAccount)
    }

    @Test("체크섬 실패 IBAN은 IBAN으로 분류되지 않는다")
    func invalidIBANRejected() {
        let result = sut.classify(content: "GB99WEST12345698765432")
        #expect(result.type != .iban)
    }

    @Test("유효하지 않은 octet의 IP는 IP주소가 아니다")
    func invalidIPRejected() {
        let result = sut.classify(content: "192.168.1.256")
        #expect(result.type != .ipAddress)
    }

    @Test("카드번호는 대시가 있어도 분류된다")
    func creditCardWithDashes() {
        let result = sut.classify(content: "4242-4242-4242-4242")
        #expect(result.type == .creditCard)
    }

    // MARK: - 타입 메타데이터

    @Test("모든 ClipboardItemType은 비어있지 않은 rawValue를 가진다")
    func allTypesHaveRawValue() {
        for type in ClipboardItemType.allCases {
            #expect(!type.rawValue.isEmpty)
        }
    }
}
