//
//  ChecksumVerifierTests.swift
//  ClipKeyboardTests
//
//  검증 각인이 **확실할 때만 말하는지**를 지킨다.
//  가장 중요한 규약: 형식이 모호하면 실패를 단언하지 않고 침묵(nil)한다.
//  이게 깨지면 아무 숫자에나 "체크섬 불일치"가 뜨는 잘못된 고발이 된다.
//

import Testing
@testable import ClipKeyboard

struct ChecksumVerifierTests {

    // MARK: - IBAN

    @Test("올바른 IBAN은 통과로 판정한다")
    func validIBANPasses() {
        let result = ChecksumVerifier.verify("DE89 3704 0044 0532 0130 00")
        #expect(result?.subject == .iban)
        #expect(result?.isValid == true)
    }

    @Test("체크 자리가 틀린 IBAN은 실패로 단언한다 — 형식이 고유해서 말해도 된다")
    func invalidIBANFails() {
        let result = ChecksumVerifier.verify("DE88 3704 0044 0532 0130 00")
        #expect(result?.subject == .iban)
        #expect(result?.isValid == false)
    }

    @Test("공백·하이픈 표기가 달라도 같은 결과를 낸다")
    func ibanNormalizesSeparators() {
        let spaced = ChecksumVerifier.verify("GB82 WEST 1234 5698 7654 32")
        let packed = ChecksumVerifier.verify("GB82WEST12345698765432")
        let dashed = ChecksumVerifier.verify("GB82-WEST-1234-5698-7654-32")
        #expect(spaced?.isValid == true)
        #expect(packed?.isValid == true)
        #expect(dashed?.isValid == true)
    }

    @Test("IBAN 형식이 아니면 IBAN으로 판정하지 않는다")
    func nonIBANIsNotClaimed() {
        #expect(ChecksumVerifier.verifyIBAN("안녕하세요") == nil)
        #expect(ChecksumVerifier.verifyIBAN("010-1234-5678") == nil)
        // 국가코드 뒤 검증번호가 숫자가 아니면 IBAN 형식이 아니다.
        #expect(ChecksumVerifier.verifyIBAN("DEXX37040044053201300") == nil)
    }

    // MARK: - 카드번호 (Luhn)

    @Test("Luhn을 통과하는 카드번호는 붙여 써도 인정한다")
    func validCardPasses() {
        let result = ChecksumVerifier.verify("4539578763621486")
        #expect(result?.subject == .creditCard)
        #expect(result?.isValid == true)
    }

    @Test("4-4-4-4로 끊어 적은 번호는 틀렸을 때도 말해 준다")
    func groupedCardCanFail() {
        let result = ChecksumVerifier.verify("4539 5787 6362 1487")
        #expect(result?.subject == .creditCard)
        #expect(result?.isValid == false)
    }

    @Test("붙여 쓴 숫자 뭉치가 Luhn을 통과 못 하면 아무 말도 하지 않는다 — 계좌번호일 수 있다")
    func packedNonCardStaysSilent() {
        // 16자리지만 카드가 아닌 숫자 — 여기서 "체크섬 불일치"를 띄우면 잘못된 고발이다.
        #expect(ChecksumVerifier.verify("1234567890123456") == nil)
    }

    @Test("자릿수가 카드 범위를 벗어나면 판정하지 않는다")
    func cardLengthBounds() {
        #expect(ChecksumVerifier.verifyCreditCard("123456789012") == nil)      // 12자리
        #expect(ChecksumVerifier.verifyCreditCard("12345678901234567890") == nil) // 20자리
    }

    // MARK: - 사업자등록번호

    @Test("올바른 사업자등록번호는 통과로 판정한다")
    func validBusinessNumberPasses() {
        // 국세청 체크섬을 만족하는 값.
        let result = ChecksumVerifier.verify("220-81-62517")
        #expect(result?.subject == .businessNumber)
        #expect(result?.isValid == true)
    }

    @Test("3-2-5 표기인데 체크섬이 틀리면 말해 준다")
    func dashedBusinessNumberCanFail() {
        let result = ChecksumVerifier.verify("220-81-62518")
        #expect(result?.subject == .businessNumber)
        #expect(result?.isValid == false)
    }

    @Test("붙여 쓴 10자리가 체크섬을 못 넘기면 침묵한다 — 전화번호일 수 있다")
    func packedTenDigitsStaySilent() {
        #expect(ChecksumVerifier.verifyBusinessNumber("0212345678") == nil)
    }

    @Test("체크섬 계산 자체를 직접 검증한다")
    func businessChecksumMath() {
        #expect(ChecksumVerifier.isValidBusinessNumber("2208162517") == true)
        #expect(ChecksumVerifier.isValidBusinessNumber("2208162518") == false)
        #expect(ChecksumVerifier.isValidBusinessNumber("22081625") == false)   // 자릿수 부족
    }

    // MARK: - 전체 진입점

    @Test("빈 값과 지나치게 긴 값은 판정하지 않는다")
    func guardsEmptyAndOverlong() {
        #expect(ChecksumVerifier.verify("") == nil)
        #expect(ChecksumVerifier.verify("   ") == nil)
        #expect(ChecksumVerifier.verify(String(repeating: "1", count: 200)) == nil)
    }

    @Test("일반 문장은 어떤 판정도 내지 않는다")
    func plainTextStaysSilent() {
        #expect(ChecksumVerifier.verify("늦어서 죄송합니다. 5분 내로 도착해요") == nil)
        #expect(ChecksumVerifier.verify("leeo@kakao.com") == nil)
    }

    @Test("통과·실패 문구가 서로 다르고 비어 있지 않다")
    func messagesDiffer() {
        let ok = ChecksumVerifier.Result(subject: .iban, isValid: true)
        let no = ChecksumVerifier.Result(subject: .iban, isValid: false)
        #expect(!ok.detail.isEmpty)
        #expect(!no.detail.isEmpty)
        #expect(ok.detail != no.detail)
        #expect(ok.stampLabel != no.stampLabel)
    }
}
