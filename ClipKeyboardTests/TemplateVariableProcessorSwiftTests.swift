//
//  TemplateVariableProcessorSwiftTests.swift
//  ClipKeyboardTests
//
//  Swift Testing 스위트 — 자동 변수 치환, 커스텀 토큰 추출, 입력값 치환,
//  메모+템플릿 합성, 숫자 토큰 판정.
//
//  명세: docs/FEATURE_SPEC.md §3
//

import Testing
import Foundation
@testable import ClipKeyboard

@Suite("TemplateVariableProcessor — 변수 처리")
struct TemplateVariableProcessorSwiftTests {

    /// 결정적 검증을 위한 고정 기준 시각 (현재 캘린더/타임존 기준 컴포넌트로 구성).
    private func fixedDate() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 3; c.day = 7
        c.hour = 9; c.minute = 5; c.second = 3
        return Calendar.current.date(from: c)!
    }

    // MARK: - 자동 변수 치환 (날짜/시간)

    @Test("{날짜}/{date}는 yyyy-MM-dd로 치환된다")
    func dateTokenSubstitution() {
        let out = TemplateVariableProcessor.process("오늘은 {날짜} ({date})", at: fixedDate())
        #expect(out == "오늘은 2026-03-07 (2026-03-07)")
    }

    @Test("{시간}/{time}는 HH:mm:ss로 치환된다")
    func timeTokenSubstitution() {
        let out = TemplateVariableProcessor.process("{시간} / {time}", at: fixedDate())
        #expect(out == "09:05:03 / 09:05:03")
    }

    @Test("{연도}/{월}/{일}이 각각 치환된다")
    func ymdTokens() {
        let out = TemplateVariableProcessor.process("{연도}.{월}.{일}", at: fixedDate())
        #expect(out == "2026.03.07")
    }

    @Test("사용자 정의 토큰은 자동 치환에서 그대로 남는다")
    func customTokensUntouchedByProcess() {
        let out = TemplateVariableProcessor.process("{이름}님 {금액}원", at: fixedDate())
        #expect(out == "{이름}님 {금액}원")
    }

    // MARK: - 커스텀 토큰 추출

    @Test("커스텀 토큰만 추출하고 자동 변수는 제외한다")
    func extractCustomTokensExcludesAutoVariables() {
        let tokens = TemplateVariableProcessor.extractCustomTokens(
            in: "{이름}님 {금액}원 {날짜} {이름}")
        // 자동 변수 {날짜} 제외, 중복 {이름} 제거, 등장 순서 보존.
        #expect(tokens == ["{이름}", "{금액}"])
    }

    @Test("토큰이 없으면 빈 배열")
    func extractCustomTokensEmpty() {
        #expect(TemplateVariableProcessor.extractCustomTokens(in: "변수 없는 평범한 글").isEmpty)
    }

    // MARK: - 입력값 치환

    @Test("substitute는 입력값으로 토큰을 치환한다")
    func substituteReplacesTokens() {
        let out = TemplateVariableProcessor.substitute(
            "{이름}님께 {금액}원 송금",
            with: ["{이름}": "홍길동", "{금액}": "5000"])
        #expect(out == "홍길동님께 5000원 송금")
    }

    @Test("substitute는 치환 후 남은 자동 변수도 처리한다")
    func substituteAlsoResolvesAutoVariables() {
        let out = TemplateVariableProcessor.substitute(
            "{이름} {date}", with: ["{이름}": "A"])
        #expect(out.contains("A"))
        #expect(!out.contains("{이름}"))
        #expect(!out.contains("{date}"))   // 자동 변수까지 치환됨
    }

    // MARK: - 합성 (compose)

    @Test("compose는 메모 본문 + 줄바꿈 + 치환된 템플릿을 잇는다")
    func composeJoinsMemoAndTemplate() {
        let out = TemplateVariableProcessor.compose(
            memoValue: "안녕하세요", templateBody: "{이름}님",
            templateInputs: ["{이름}": "철수"])
        #expect(out == "안녕하세요\n철수님")
    }

    @Test("templateBody가 nil이면 메모 본문만 반환")
    func composeWithNilTemplate() {
        let out = TemplateVariableProcessor.compose(
            memoValue: "본문만", templateBody: nil, templateInputs: [:])
        #expect(out == "본문만")
    }

    @Test("메모 본문이 비면 치환된 템플릿만 반환")
    func composeWithEmptyMemo() {
        let out = TemplateVariableProcessor.compose(
            memoValue: "", templateBody: "{x}", templateInputs: ["{x}": "끝"])
        #expect(out == "끝")
    }

    // MARK: - 숫자 토큰 판정

    @Test("숫자 의도 토큰 판정", arguments: [
        ("{금액}", true),
        ("{수량}", true),
        ("{가격}", true),
        ("{전화번호}", true),   // "번호" 키워드 포함
        ("{amount_total}", true),
        ("{Price}", true),       // 대소문자 무시
        ("{이름}", false),
        ("{메모}", false),
        ("{주소}", false),
    ])
    func numericTokenDetection(token: String, expected: Bool) {
        #expect(TemplateVariableProcessor.isNumericToken(token) == expected)
    }

    @Test("tokenKind는 숫자/텍스트를 구분한다")
    func tokenKindDistinguishes() {
        #expect(TemplateVariableProcessor.tokenKind("{금액}") == .number)
        #expect(TemplateVariableProcessor.tokenKind("{이름}") == .text)
    }
}
