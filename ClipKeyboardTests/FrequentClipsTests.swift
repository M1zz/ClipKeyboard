//
//  FrequentClipsTests.swift
//  ClipKeyboardTests
//
//  '최근' 에서 자주 넣는 글을 단축어로 권하는 판정(`FrequentClips`).
//

import Testing
import Foundation
@testable import ClipKeyboard

struct FrequentClipsTests {

    private func clip(_ text: String) -> SmartClipboardHistory {
        SmartClipboardHistory(content: text)
    }

    private func used(_ text: String, _ times: Int, in ledger: FrequentClips.Ledger = .init()) -> FrequentClips.Ledger {
        (0..<times).reduce(ledger) { l, _ in FrequentClips.recordingUse(of: text, in: l) }
    }

    @Test func 세_번_넣어야_묻는다() {
        let clips = [clip("서울시 강남구 테헤란로 1")]
        #expect(FrequentClips.suggestion(among: clips, ledger: used("서울시 강남구 테헤란로 1", 2), savedValues: []) == nil)
        #expect(FrequentClips.suggestion(among: clips, ledger: used("서울시 강남구 테헤란로 1", 3), savedValues: [])?.content
                == "서울시 강남구 테헤란로 1")
    }

    @Test func 답을_들은_글은_다시_묻지_않는다() {
        let text = "010-1234-5678"
        let settled = FrequentClips.settling(text, in: used(text, 5))
        #expect(FrequentClips.suggestion(among: [clip(text)], ledger: settled, savedValues: []) == nil)
        // 답한 뒤 또 넣어도 다시 세지 않는다.
        #expect(FrequentClips.suggestion(among: [clip(text)], ledger: used(text, 5, in: settled), savedValues: []) == nil)
    }

    @Test func 이미_단축어인_글은_묻지_않는다() {
        let text = "hello@example.com"
        #expect(FrequentClips.suggestion(among: [clip(text)], ledger: used(text, 4), savedValues: [text + "\n"]) == nil)
    }

    @Test func 앞뒤_빈칸이_달라도_같은_글이다() {
        let ledger = used("주소 \n", 2)
        #expect(FrequentClips.suggestion(among: [clip("주소")], ledger: used("  주소", 1, in: ledger), savedValues: [])?.content == "주소")
    }

    @Test func 여럿이면_가장_많이_넣은_것() {
        var ledger = used("가", 3)
        ledger = used("나", 5, in: ledger)
        #expect(FrequentClips.suggestion(among: [clip("가"), clip("나")], ledger: ledger, savedValues: [])?.content == "나")
    }

    @Test func 기록에_글이_남지_않는다() throws {
        let card = "4111 1111 1111 1111"
        let data = try JSONEncoder().encode(used(card, 3))
        let stored = String(decoding: data, as: UTF8.self)
        #expect(!stored.contains("4111"))
    }

    @Test func 세는_글의_수는_상한을_넘지_않는다() {
        var ledger = FrequentClips.Ledger()
        for i in 0..<(FrequentClips.capacity + 20) {
            ledger = FrequentClips.recordingUse(of: "글 \(i)", in: ledger)
        }
        #expect(ledger.counts.count == FrequentClips.capacity)
        // 방금 넣은 글은 버려지지 않는다.
        #expect(ledger.counts[FrequentClips.fingerprint("글 \(FrequentClips.capacity + 19)")] == 1)
    }
}
