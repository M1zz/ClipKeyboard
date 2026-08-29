//
//  TemplatePreviewSegmentTests.swift
//  ClipKeyboardTests
//
//  미리보기가 **결과와 같은 그림**을 그리는지 지킨다.
//
//  ⚠️ 이 시험들이 지키는 한 문장: **빈칸으로 보이는 자리 수 = 채우라고 내주는 칸 수.**
//     둘이 어긋나면 사람은 "칸이 하나 빠졌다"고 읽는다. 실제로 빠진 적이 없어도 그렇다.
//

import XCTest
@testable import ClipKeyboard

final class TemplatePreviewSegmentTests: XCTestCase {

    /// 미리보기에서 아직 빈칸으로 보이는 토큰들.
    private func blanks(_ text: String, inputs: [String: String] = [:]) -> [String] {
        TemplatePlaceholder.previewSegments(of: text, inputs: inputs)
            .filter { $0.kind == .blank }
            .map(\.text)
    }

    // MARK: - 핵심 불변식

    func test_빈칸으로_보이는_수와_채울_칸_수가_같다() {
        let cases = [
            "Hi {name}, thanks for reaching out.\nI'll reply by {date}.",
            "{이름}님, {날짜}까지 답변드릴게요.",
            "{금액}을 {수신인}에게 보냅니다\nIBAN: {iban}\nSWIFT: {swift}\n참조: {참조번호}",
            "오늘은 {날짜}입니다",                       // 자동 변수만 - 채울 칸 0
            "{a} {b} {c}",
        ]
        for text in cases {
            let inputCount = TemplatePlaceholder.customTokens(in: text).count
            XCTAssertEqual(blanks(text).count, inputCount,
                           "'\(text)' 에서 구멍은 \(blanks(text).count)개인데 채울 칸은 \(inputCount)개다")
        }
    }

    // MARK: - 자동 변수

    func test_자동_변수는_구멍이_아니라_값으로_보인다() {
        let segs = TemplatePlaceholder.previewSegments(
            of: "I'll reply by {date}.", inputs: [:],
            now: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertFalse(segs.contains { $0.kind == .blank },
                       "시스템이 채우는 자리를 빈칸으로 그리면 채울 칸이 하나 없어진 것처럼 보인다")
        let auto = segs.filter { $0.kind == .automatic }
        XCTAssertEqual(auto.count, 1)
        XCTAssertFalse(auto[0].text.contains("{"), "값으로 바뀌어야 한다: \(auto[0].text)")
    }

    func test_커서_토큰은_자리를_차지하지_않는다() {
        let segs = TemplatePlaceholder.previewSegments(of: "앞{커서}뒤", inputs: [:])
        XCTAssertEqual(segs.map(\.text).joined(), "앞뒤",
                       "위치를 가리키는 토큰이 글자 자리를 차지하면 문장에 이유 없는 틈이 생긴다")
    }

    // MARK: - 사람이 채운 값

    func test_고른_값과_알아서_채워진_값을_갈라_준다() {
        let segs = TemplatePlaceholder.previewSegments(
            of: "Hi {name}, reply by {date}.", inputs: ["{name}": "team"])
        XCTAssertEqual(segs.filter { $0.kind == .filled }.map(\.text), ["team"])
        XCTAssertEqual(segs.filter { $0.kind == .automatic }.count, 1)
        XCTAssertTrue(segs.filter { $0.kind == .blank }.isEmpty)
    }

    func test_구멍이_둘이면_둘_다_보인다() {
        // 사용자가 직접 만든 토큰 둘. 하나만 채우면 나머지 하나가 빈칸으로 남아야 한다.
        let text = "{보내는사람} 드림 / {받는사람} 귀하"
        XCTAssertEqual(blanks(text).count, 2)
        XCTAssertEqual(blanks(text, inputs: ["{보내는사람}": "이현호"]), ["{받는사람}"])
    }

    func test_같은_토큰이_두_번_나와도_채울_칸은_하나다() {
        let text = "{이름}님, {이름}님께 보냅니다"
        XCTAssertEqual(TemplatePlaceholder.customTokens(in: text), ["{이름}"])
        // 그린 자리는 둘이지만 둘 다 같은 값으로 채워진다.
        let segs = TemplatePlaceholder.previewSegments(of: text, inputs: ["{이름}": "홍"])
        XCTAssertEqual(segs.filter { $0.kind == .filled }.count, 2)
        XCTAssertTrue(segs.filter { $0.kind == .blank }.isEmpty)
    }

    // MARK: - 글은 그대로

    func test_토큰이_없으면_글이_그대로_나온다() {
        let segs = TemplatePlaceholder.previewSegments(of: "안녕하세요", inputs: [:])
        XCTAssertEqual(segs, [.init(text: "안녕하세요", kind: .plain)])
    }
}
