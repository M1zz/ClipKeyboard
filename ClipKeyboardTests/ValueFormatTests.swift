//
//  ValueFormatTests.swift
//  ClipKeyboardTests
//
//  딱 맞춰 적어야 하는 값의 입력 틀(`ValueFormat`).
//  적는 대로 모양이 잡히고, 지우기가 막히지 않고, 상태를 맞게 말하는지 본다.
//

import XCTest
@testable import ClipKeyboard

final class ValueFormatTests: XCTestCase {

    // MARK: - 카드번호

    func testCard_GroupsByFourWithHyphens() {
        XCTAssertEqual(ValueFormat.creditCard.format("4111111111111111"), "4111-1111-1111-1111")
        XCTAssertEqual(ValueFormat.creditCard.format("4111 1111"), "4111-1111")
    }

    func testCard_AmexGroupsFourSixFive() {
        XCTAssertEqual(ValueFormat.creditCard.format("378282246310005"), "3782-822463-10005")
    }

    /// 하이픈을 미리 붙이지 않는다. 붙이면 지우기로 하이픈을 지울 수 없다.
    func testCard_NoTrailingSeparatorSoBackspaceWorks() {
        XCTAssertEqual(ValueFormat.creditCard.format("1234"), "1234")
        XCTAssertEqual(ValueFormat.creditCard.format("1234-"), "1234")
    }

    func testCard_FormatIsIdempotent() {
        let once = ValueFormat.creditCard.format("4111111111111111")
        XCTAssertEqual(ValueFormat.creditCard.format(once), once)
    }

    func testCard_Status() {
        guard case .hint = ValueFormat.creditCard.check("4111-1111") else { return XCTFail("덜 적으면 안내") }
        guard case .ok = ValueFormat.creditCard.check("4111-1111-1111-1111") else { return XCTFail("Luhn 통과") }
        guard case .problem = ValueFormat.creditCard.check("4111-1111-1111-1112") else { return XCTFail("Luhn 실패") }
    }

    // MARK: - 생년월일

    func testBirthDate_InsertsHyphensWhileTyping() {
        XCTAssertEqual(ValueFormat.birthDate.format("1990"), "1990")
        XCTAssertEqual(ValueFormat.birthDate.format("19900"), "1990-0")
        XCTAssertEqual(ValueFormat.birthDate.format("19900101"), "1990-01-01")
    }

    /// 자기 모양으로 적는 사람(1990.01.01)의 글은 건드리지 않는다.
    func testBirthDate_LeavesOtherStylesAlone() {
        XCTAssertEqual(ValueFormat.birthDate.format("1990.01.01"), "1990.01.01")
        guard case .ok = ValueFormat.birthDate.check("1990.01.01") else { return XCTFail("점 표기도 날짜로 읽는다") }
    }

    func testBirthDate_RejectsImpossibleAndFutureDates() {
        guard case .problem = ValueFormat.birthDate.check("1990-02-30") else { return XCTFail("없는 날") }
        guard case .problem = ValueFormat.birthDate.check("2999-01-01") else { return XCTFail("미래") }
        guard case .hint = ValueFormat.birthDate.check("1990-01") else { return XCTFail("덜 적음") }
    }

    // MARK: - 여권번호

    func testPassport_UppercasesAndCapsAtNine() {
        XCTAssertEqual(ValueFormat.passport.format("m123 a4567"), "M123A4567")
        XCTAssertEqual(ValueFormat.passport.format("M1234567890"), "M12345678")
    }

    func testPassport_Status() {
        guard case .ok = ValueFormat.passport.check("M12345678") else { return XCTFail("한국 옛 여권") }
        guard case .ok = ValueFormat.passport.check("M123A4567") else { return XCTFail("한국 새 여권") }
        guard case .ok = ValueFormat.passport.check("123456789") else { return XCTFail("미국 여권") }
        guard case .hint = ValueFormat.passport.check("M12") else { return XCTFail("덜 적음") }
    }

    // MARK: - IBAN

    func testIBAN_GroupsByFourWithSpaces() {
        XCTAssertEqual(ValueFormat.iban.format("gb82west12345698765432"), "GB82 WEST 1234 5698 7654 32")
    }

    func testIBAN_Status() {
        guard case .ok = ValueFormat.iban.check("GB82 WEST 1234 5698 7654 32") else { return XCTFail("mod-97 통과") }
        guard case .problem = ValueFormat.iban.check("GB83 WEST 1234 5698 7654 32") else { return XCTFail("mod-97 실패") }
        guard case .hint = ValueFormat.iban.check("GB82 WEST") else { return XCTFail("덜 적음") }
    }

    // MARK: - 전화번호

    func testPhone_LengthStatus() {
        guard case .ok = ValueFormat.phone.check("010-1234-5678") else { return XCTFail("보통 번호") }
        guard case .hint = ValueFormat.phone.check("010") else { return XCTFail("덜 적음") }
        guard case .problem = ValueFormat.phone.check("+82 10 1234 5678 9999 0") else { return XCTFail("너무 김") }
    }

    /// 국제 표기는 어느 지역에서도 손대지 않는다.
    func testPhone_LeavesInternationalAlone() {
        XCTAssertEqual(ValueFormat.phone.format("+44 7700 900123"), "+44 7700 900123")
    }

    // MARK: - 어느 값에 씌우나

    func testFindsFormatByCategoryAndPlaceholderName() {
        XCTAssertEqual(ValueFormat(category: "카드번호"), .creditCard)
        XCTAssertNil(ValueFormat(category: "텍스트"))
        XCTAssertEqual(ValueFormat(placeholder: "{여권번호}"), .passport)
        XCTAssertEqual(ValueFormat(placeholder: "{IBAN}"), .iban)
        // 이름이 똑같을 때만. 비슷한 이름에 틀을 씌우면 글자를 못 적는다.
        XCTAssertNil(ValueFormat(placeholder: "{카드 메모}"))
    }

    /// 템플릿 칸이 섞인 글에는 아무 말도 하지 않는다.
    func testTemplateTextIsIgnored() {
        XCTAssertNil(ValueFormat.creditCard.check("{카드번호}"))
    }
}
