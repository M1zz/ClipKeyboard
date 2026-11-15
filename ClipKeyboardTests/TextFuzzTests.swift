//
//  TextFuzzTests.swift
//  ClipKeyboardTests
//
//  밖에서 들어온 글을 다루는 곳을 **죽이려고** 두드리는 시험.
//  단축어 값 · 템플릿 · 붙여 넣은 글은 무엇이든 될 수 있다, 짝 없는 중괄호, 결합 문자,
//  가족 이모지, 아주 긴 글, 빈 글. 어떤 글에서도 죽지 않아야 한다.
//

import XCTest
@testable import ClipKeyboard

private struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// 위험한 조각들. 이어 붙여 무작위 글을 만든다.
private let pieces = ["{", "}", "{{", "}}", "{날짜}", "{시간}", "{커서}", "{cursor}", "{클립보드}", "{clipboard}",
                      "{이름}", "{", "{날짜:", "{:}", "{}", "{ }", "{{커서}}", "{커서}{커서}",
                      "a", "가", "ㄱ", "e\u{301}", "\u{301}", "👨‍👩‍👧", "👍🏽", "🇰🇷", "\u{200D}", "\u{FE0F}",
                      "\n", "\r\n", "\t", " ", "%@", "%d", "%", "\\", "\"", "'", "\0", "\u{FFFD}",
                      "https://", "010-1234-5678", "1234 5678 9012 3456", "ﷺ", "𝒜", "‮", "‭"]

private func randomText(_ random: inout SeededRandom, maxPieces: Int = 30) -> String {
    let count = Int.random(in: 0...maxPieces, using: &random)
    return (0..<count).map { _ in pieces.randomElement(using: &random)! }.joined()
}

final class TextFuzzTests: XCTestCase {

    /// 템플릿 처리 · 커서 자리 · 칩 찾기, 아무 글이나.
    func testTemplateProcessingSurvivesAnyText() {
        var random = SeededRandom(seed: 42)
        for _ in 0..<3_000 {
            let text = randomText(&random)
            _ = TemplateVariableProcessor.process(text, clipboard: randomText(&random, maxPieces: 4))
            _ = TemplateVariableProcessor.process(text, keepCursorToken: true)
            _ = TemplateVariableProcessor.resolveCursor(in: text)
            _ = TemplateVariableProcessor.containsCursorToken(text)
            _ = TemplatePlaceholder.tokens(in: text)
            _ = TemplatePlaceholder.names(in: text)
            _ = TemplatePlaceholder.strip(text)
        }
    }

    /// 값 모양(전화 · 카드 · 생년월일 …) 맞추기와 검사, 아무 글이나.
    func testValueFormatsSurviveAnyText() {
        var random = SeededRandom(seed: 7)
        for _ in 0..<2_000 {
            let text = randomText(&random, maxPieces: 12)
            for format in ValueFormat.allCases {
                _ = format.format(text)
                _ = format.check(text)
            }
        }
    }

    /// 미리보기, 아주 긴 글, 자르는 자리에 결합 문자 · 중괄호가 걸려도.
    func testPreviewSurvivesAnyText() {
        var random = SeededRandom(seed: 99)
        for _ in 0..<1_500 {
            let memo = Memo(title: randomText(&random, maxPieces: 5), value: randomText(&random, maxPieces: 120))
            _ = MemoPreviewFormatter.preview(for: memo, resolvedType: nil)
            _ = MemoPreviewFormatter.accessibilityPreview(for: memo, resolvedType: nil)
        }
    }

    /// 앱 안 연습 입력칸, 결합 문자 · 이모지 조각을 넣고 지우고 커서를 옮긴다.
    @MainActor
    func testInAppFieldSurvivesAnyEditing() {
        var random = SeededRandom(seed: 2026)
        let host = InAppKeyboardHost(typesOut: false)
        defer { host.stop() }
        for _ in 0..<5_000 {
            switch Int.random(in: 0..<10, using: &random) {
            case 0..<5: host.insertText(pieces.randomElement(using: &random)!)
            case 5..<8: host.deleteBackward()
            case 8: host.cursorRight()
            default:
                if Int.random(in: 0..<20, using: &random) == 0 { host.clearAll() }
                _ = host.typingContextBefore
            }
            XCTAssertLessThanOrEqual(host.caret, host.text.count, "커서가 글 끝을 넘었다")
            XCTAssertGreaterThanOrEqual(host.caret, 0)
        }
    }
}
