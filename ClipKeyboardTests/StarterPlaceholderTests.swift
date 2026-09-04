//
//  StarterPlaceholderTests.swift
//  ClipKeyboardTests
//
//  설치 첫 실행에 심는 샘플의 **빈칸과 값**을 지킨다.
//
//  ⚠️ 이 시험들이 지키는 것은 값의 내용이 아니라 **규칙**이다.
//     · 사람이 채울 빈칸에는 처음부터 고를 값이 있어야 한다
//       (없으면 튜토리얼에서 "저장된 값이 없어요"를 만난다)
//     · 시스템이 채우는 자리는 사람에게 묻지 않는다
//     · 남의 금융정보를 예시로 심지 않는다
//

import XCTest
@testable import ClipKeyboard

final class StarterPlaceholderTests: XCTestCase {

    // MARK: - 사람이 채울 빈칸

    func test_일반_샘플의_빈칸에는_고를_값이_있다() {
        for isKorean in [true, false] {
            let seeded = ClipKeyboardApp.starterPlaceholderValues(isKorean: isKorean)
            let token = isKorean ? "{이름}" : "{name}"
            XCTAssertFalse(seeded[token]?.isEmpty ?? true,
                           "\(token) 에 값이 없으면 처음 온 사람이 '저장된 값이 없어요'부터 본다")
        }
    }

    func test_심는_값은_그대로_써도_말이_된다() {
        // "홍길동" 같은 예시용 가짜를 넣으면 사용자는 그걸 지우는 것부터 배운다.
        // 빈 문자열이나 중괄호가 남은 값이 섞이면 그건 값이 아니다.
        for isKorean in [true, false] {
            for (token, values) in ClipKeyboardApp.starterPlaceholderValues(isKorean: isKorean) {
                for value in values {
                    XCTAssertFalse(value.trimmingCharacters(in: .whitespaces).isEmpty,
                                   "\(token) 에 빈 값이 섞였다")
                    XCTAssertFalse(value.contains("{") || value.contains("}"),
                                   "\(token) 의 값 '\(value)' 에 아직 토큰이 남아 있다")
                }
            }
        }
    }

    // MARK: - 시스템이 채우는 자리

    func test_내장_토큰에는_값을_심지_않는다() {
        // {날짜}·{시간}·{통화} 는 시스템이 채운다. 여기에 값을 심으면 이미 채워질 자리를
        // 사람에게 묻게 되고, 플레이스홀더 관리에는 고를 수 없는 값이 남는다.
        for isKorean in [true, false] {
            let all = ClipKeyboardApp.starterPlaceholderValues(isKorean: isKorean)
                .merging(ClipKeyboardApp.starterNomadPlaceholderValues(isKorean: isKorean)) { a, _ in a }
            for token in all.keys {
                XCTAssertFalse(TemplateVariableProcessor.autoVariableTokens.contains(token),
                               "\(token) 은 시스템이 채우는 자리다. 값을 심을 곳이 아니다")
            }
        }
    }

    // MARK: - 남의 금융정보를 심지 않는다

    func test_노마드_샘플에_계좌정보를_심지_않는다() {
        // 예시 IBAN 을 심어 두면 사용자가 자기 것으로 착각하고 청구서에 붙여넣을 수 있다.
        // 그러면 돈이 남에게 간다. 그 자리는 비워 두고, 값 화면에서 직접 적게 한다.
        //
        // ⚠️ 송장번호({참조번호})는 여기 없다. 그건 계좌가 아니라 **내가 붙이는 이름표**라
        //    틀려도 돈이 새지 않는다. 위험한 것과 그냥 개인적인 것을 같이 묶으면,
        //    안전하게 도와줄 수 있는 자리까지 빈칸으로 남는다.
        for isKorean in [true, false] {
            let seeded = ClipKeyboardApp.starterNomadPlaceholderValues(isKorean: isKorean)
            for banned in ["{iban}", "{swift}", "{수신인}", "{recipient}"] {
                XCTAssertNil(seeded[banned],
                             "\(banned) 은 틀리면 돈이 새는 자리다. 우리가 미리 채울 수 없다")
            }
        }
    }

    func test_틀려도_돈이_새지_않는_자리는_채워_준다() {
        // 금액·송장번호는 형태만 알려 주면 되는 자리다. 비워 두면 도와줄 수 있는데
        // 안 도와준 것이 된다.
        for isKorean in [true, false] {
            let seeded = ClipKeyboardApp.starterNomadPlaceholderValues(isKorean: isKorean)
            let amount = isKorean ? "{금액}" : "{amount}"
            let reference = isKorean ? "{참조번호}" : "{reference}"
            XCTAssertFalse(seeded[amount]?.isEmpty ?? true, "\(amount) 은 채워 줄 수 있다")
            XCTAssertFalse(seeded[reference]?.isEmpty ?? true, "\(reference) 은 채워 줄 수 있다")
        }
    }
}
