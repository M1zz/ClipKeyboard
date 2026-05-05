//
//  ClipboardClassificationServiceTests.swift
//  ClipKeyboardTests
//
//  ClipboardClassificationService 직접 호출 테스트.
//  ClipboardDetectionTests는 헬퍼 기반 단순 정규식이라 25종 전체와 우선순위 검증이 부족함.
//  이 파일은 service.classify(content:) 를 직접 호출하여 실제 동작을 검증한다.
//

import XCTest
@testable import ClipKeyboard

final class ClipboardClassificationServiceTests: XCTestCase {

    var sut: ClipboardClassificationService!

    override func setUp() {
        super.setUp()
        sut = ClipboardClassificationService.shared
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Empty / Edge

    func testClassify_EmptyString_ReturnsTextWithZeroConfidence() {
        let result = sut.classify(content: "")
        XCTAssertEqual(result.type, .text)
        XCTAssertEqual(result.confidence, 0.0, accuracy: 0.001)
    }

    func testClassify_WhitespaceOnly_ReturnsTextWithZeroConfidence() {
        let result = sut.classify(content: "   \n  ")
        XCTAssertEqual(result.type, .text)
        XCTAssertEqual(result.confidence, 0.0, accuracy: 0.001)
    }

    func testClassify_RandomText_ReturnsText() {
        let result = sut.classify(content: "hello world this is some random text")
        XCTAssertEqual(result.type, .text)
        XCTAssertLessThanOrEqual(result.confidence, 0.5)
    }

    // MARK: - IBAN

    func testClassify_ValidIBAN_GB() {
        // GB82 WEST 1234 5698 7654 32 — 표준 mod-97 검증 통과 테스트 IBAN
        let result = sut.classify(content: "GB82WEST12345698765432")
        XCTAssertEqual(result.type, .iban)
        XCTAssertGreaterThan(result.confidence, 0.9)
    }

    func testClassify_ValidIBAN_WithSpaces() {
        let result = sut.classify(content: "GB82 WEST 1234 5698 7654 32")
        XCTAssertEqual(result.type, .iban)
    }

    func testClassify_InvalidIBAN_FailsChecksum() {
        // 잘못된 체크 자릿수 → mod-97 통과 안 함 → IBAN 아님
        let result = sut.classify(content: "GB99WEST12345698765432")
        XCTAssertNotEqual(result.type, .iban)
    }

    // MARK: - SWIFT/BIC

    func testClassify_ValidSWIFT_8Char() {
        let result = sut.classify(content: "DEUTDEFF")
        XCTAssertEqual(result.type, .swift)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.85)
    }

    func testClassify_ValidSWIFT_11Char() {
        let result = sut.classify(content: "BOFAUS3NXXX")
        XCTAssertEqual(result.type, .swift)
    }

    // MARK: - VAT

    func testClassify_ValidVAT_DE() {
        let result = sut.classify(content: "DE123456789")
        XCTAssertEqual(result.type, .vat)
    }

    func testClassify_ValidVAT_GB() {
        let result = sut.classify(content: "GB123456789")
        // GB는 SWIFT가 8/11자리 알파벳이므로 9자리에서 SWIFT로 안 잡힘
        XCTAssertEqual(result.type, .vat)
    }

    // MARK: - Crypto Wallet

    func testClassify_EthereumWallet() {
        let result = sut.classify(content: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e")
        XCTAssertEqual(result.type, .cryptoWallet)
        XCTAssertGreaterThan(result.confidence, 0.9)
    }

    func testClassify_BitcoinLegacyWallet() {
        // P2PKH 시작 1
        let result = sut.classify(content: "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")
        XCTAssertEqual(result.type, .cryptoWallet)
    }

    func testClassify_BitcoinBech32Wallet() {
        let result = sut.classify(content: "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq")
        XCTAssertEqual(result.type, .cryptoWallet)
    }

    func testClassify_TronWallet() {
        let result = sut.classify(content: "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t")
        XCTAssertEqual(result.type, .cryptoWallet)
    }

    // MARK: - PayPal Link

    func testClassify_PayPalMeLink_HTTPS() {
        let result = sut.classify(content: "https://paypal.me/johndoe")
        XCTAssertEqual(result.type, .paypalLink)
    }

    func testClassify_PayPalMeLink_NoProtocol() {
        let result = sut.classify(content: "paypal.me/jane.doe")
        XCTAssertEqual(result.type, .paypalLink)
    }

    // MARK: - Credit Card (Luhn)

    func testClassify_ValidCreditCard_Luhn() {
        // 4242424242424242 (Stripe 테스트 카드, Luhn 통과)
        let result = sut.classify(content: "4242424242424242")
        XCTAssertEqual(result.type, .creditCard)
        XCTAssertGreaterThan(result.confidence, 0.7)
    }

    func testClassify_ValidCreditCard_WithDashes() {
        let result = sut.classify(content: "4242-4242-4242-4242")
        XCTAssertEqual(result.type, .creditCard)
    }

    // MARK: - Email

    func testClassify_SimpleEmail() {
        let result = sut.classify(content: "test@example.com")
        XCTAssertEqual(result.type, .email)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.85)
    }

    func testClassify_EmailWithPlusTag() {
        let result = sut.classify(content: "user+filter@gmail.com")
        XCTAssertEqual(result.type, .email)
    }

    // MARK: - URL

    func testClassify_HTTPSUrl() {
        let result = sut.classify(content: "https://www.example.com/path?q=1")
        XCTAssertEqual(result.type, .url)
    }

    // MARK: - Passport Number

    func testClassify_PassportNumber_M() {
        let result = sut.classify(content: "M12345678")
        XCTAssertEqual(result.type, .passportNumber)
    }

    func testClassify_PassportNumber_S() {
        let result = sut.classify(content: "S98765432")
        XCTAssertEqual(result.type, .passportNumber)
    }

    // MARK: - Declaration Number

    func testClassify_DeclarationNumber() {
        let result = sut.classify(content: "P123456789012")
        XCTAssertEqual(result.type, .declarationNumber)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.9)
    }

    // MARK: - IP Address

    func testClassify_IPv4_Valid() {
        let result = sut.classify(content: "192.168.1.1")
        XCTAssertEqual(result.type, .ipAddress)
    }

    func testClassify_IPv4_InvalidOctet() {
        // 256은 유효하지 않은 octet
        let result = sut.classify(content: "192.168.1.256")
        XCTAssertNotEqual(result.type, .ipAddress)
    }

    func testClassify_IPv6_Valid() {
        // Full form (압축형 `::`은 서비스 정규식이 빈 그룹을 backtrack 처리 못 해 false negative 발생)
        let result = sut.classify(content: "2001:0db8:0000:0000:0000:0000:8a2e:7334")
        XCTAssertEqual(result.type, .ipAddress)
    }

    // MARK: - Birth Date

    func testClassify_BirthDate_Hyphen() {
        let result = sut.classify(content: "1990-05-15")
        XCTAssertEqual(result.type, .birthDate)
    }

    func testClassify_BirthDate_Slash() {
        let result = sut.classify(content: "1990/05/15")
        XCTAssertEqual(result.type, .birthDate)
    }

    func testClassify_BirthDate_8Digit() {
        let result = sut.classify(content: "19900515")
        XCTAssertEqual(result.type, .birthDate)
    }

    func testClassify_BirthDate_BeforeBankAccount() {
        // 8자리 숫자는 우선순위에서 birthDate로 잡혀야 함 (계좌번호 오인 방지)
        let result = sut.classify(content: "20240101")
        XCTAssertEqual(result.type, .birthDate)
    }

    // MARK: - Postal Code

    func testClassify_PostalCode_5Digit() {
        let result = sut.classify(content: "12345")
        XCTAssertEqual(result.type, .postalCode)
    }

    func testClassify_PostalCode_UK() {
        let result = sut.classify(content: "SW1A 1AA")
        XCTAssertEqual(result.type, .postalCode)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.8)
    }

    func testClassify_PostalCode_Canada() {
        let result = sut.classify(content: "K1A 0B1")
        XCTAssertEqual(result.type, .postalCode)
    }

    // MARK: - Phone

    func testClassify_PhoneKR_Hyphen() {
        let result = sut.classify(content: "010-1234-5678")
        XCTAssertEqual(result.type, .phone)
    }

    func testClassify_PhoneE164() {
        let result = sut.classify(content: "+821012345678")
        XCTAssertEqual(result.type, .phone)
    }

    // MARK: - Name

    func testClassify_KoreanName() {
        let result = sut.classify(content: "홍길동")
        XCTAssertEqual(result.type, .name)
    }

    func testClassify_EnglishName() {
        let result = sut.classify(content: "John Smith")
        XCTAssertEqual(result.type, .name)
    }

    // MARK: - Priority Tests

    func testPriority_IBANBeforeOther() {
        // IBAN 형식이면 SWIFT/VAT 둘 다 가능해 보일 수 있는데 IBAN이 먼저
        let validIBAN = "DE89370400440532013000"
        let result = sut.classify(content: validIBAN)
        XCTAssertEqual(result.type, .iban)
    }

    func testPriority_CreditCardBeforeBankAccount() {
        // 16자리 숫자는 카드(Luhn) 또는 계좌일 수 있음. Luhn 통과면 카드.
        let result = sut.classify(content: "4242424242424242")
        XCTAssertEqual(result.type, .creditCard)
    }

    func testPriority_EmailBeforeURL() {
        // 이메일이 URL보다 우선
        let result = sut.classify(content: "user@example.com")
        XCTAssertEqual(result.type, .email)
    }

    // MARK: - resolvedType cache

    func testResolvedType_UsesAutoDetectedTypeIfPresent() {
        var memo = Memo(title: "테스트", value: "test@example.com")
        memo.autoDetectedType = .email

        let resolved = sut.resolvedType(for: memo)
        XCTAssertEqual(resolved, .email)
    }

    func testResolvedType_FallsBackToClassification() {
        let memo = Memo(title: "전화번호", value: "010-1234-5678")
        let resolved = sut.resolvedType(for: memo)
        XCTAssertEqual(resolved, .phone)
    }

    func testResolvedType_Memoizes() {
        let memo = Memo(title: "캐시 테스트", value: "user@example.com")
        let first = sut.resolvedType(for: memo)
        let second = sut.resolvedType(for: memo)
        XCTAssertEqual(first, second)
    }

    func testInvalidateResolvedType_ClearsCache() {
        let memo = Memo(title: "캐시 무효화", value: "user@example.com")
        _ = sut.resolvedType(for: memo)
        sut.invalidateResolvedType(for: memo.id)
        // 호출이 에러 없이 동작해야 함 (캐시 비워진 후 재계산)
        let again = sut.resolvedType(for: memo)
        XCTAssertEqual(again, .email)
    }

    // MARK: - updateClassificationModel (smoke)

    func testUpdateClassificationModel_DoesNotCrash() {
        sut.updateClassificationModel(content: "test", correctedType: .email)
        XCTAssertTrue(true)
    }
}
