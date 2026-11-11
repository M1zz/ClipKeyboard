//
//  KanaFlickInputTests.swift
//  ClipKeyboardTests
//
//  일본어 플릭 자판(`KanaFlickInput` + `KanaTypingEngine`) 시험.
//  키를 누르거나 민 결과 = 가짜 입력칸의 글.
//

import XCTest
@testable import ClipKeyboard

final class KanaFlickInputTests: XCTestCase {

    private func engine() -> (KanaTypingEngine, FakeTypingProxy) {
        let proxy = FakeTypingProxy()
        return (KanaTypingEngine(proxy: proxy, dictionary: nil), proxy)
    }

    /// 사용자 요청(2026-11): "일본어 플릭 입력 가능한 키보드". 누르면 あ단, 밀면 그쪽 단이 들어간다.
    func testFlickTypesKanaDirectly() {
        let (engine, proxy) = engine()
        // こ(か ↓) ん(わ ↑) に(な ←) ち(た ←) は(は 누름)
        engine.input(KanaFlickInput.flicks(for: "か")[.down]!)
        engine.input(KanaFlickInput.flicks(for: "わ")[.up]!)
        engine.input(KanaFlickInput.flicks(for: "な")[.left]!)
        engine.input(KanaFlickInput.flicks(for: "た")[.left]!)
        engine.input("は")
        XCTAssertEqual(proxy.text, "こんにちは")
        XCTAssertTrue(engine.isComposing)
        engine.commit()
        XCTAssertEqual(proxy.text, "こんにちは")
        XCTAssertFalse(engine.isComposing)
    }

    /// 판에는 가나 46자가 한 번씩 다 있다(빠진 글자가 있으면 그 글자는 칠 길이 없다).
    func testPadCoversEveryBasicKana() {
        var typed: [String] = []
        for key in KanaFlickInput.rows.flatMap({ $0 }) where key != KanaFlickInput.modifierKey && key != KanaFlickInput.punctuationKey {
            typed.append(key)
            typed += KanaFlickInput.flicks(for: key).values
        }
        let kana = typed.filter { KanaFlickInput.isKana($0) && $0 != "ー" }
        let all = "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん".map(String.init)
        XCTAssertEqual(kana.sorted(), all.sorted())
    }

    /// 탁점 · 작은 글자 키는 바로 앞 가나를 기본 키보드와 같은 순서로 돌린다.
    func testModifierCyclesLastKana() {
        let (engine, proxy) = engine()
        engine.input("は")
        engine.input(KanaFlickInput.modifierKey)
        XCTAssertEqual(proxy.text, "ば")
        engine.input(KanaFlickInput.modifierKey)
        XCTAssertEqual(proxy.text, "ぱ")
        engine.input(KanaFlickInput.modifierKey)
        XCTAssertEqual(proxy.text, "は")

        engine.input("つ")
        engine.input(KanaFlickInput.modifierKey)
        XCTAssertEqual(proxy.text, "はっ")
        engine.input(KanaFlickInput.modifierKey)
        XCTAssertEqual(proxy.text, "はづ")
    }

    /// 바꿀 것이 없는 글자나 빈 칸에서는 아무 일도 없다. 확정한 글자도 건드리지 않는다.
    func testModifierLeavesOtherTextAlone() {
        let (engine, proxy) = engine()
        engine.input(KanaFlickInput.modifierKey)
        XCTAssertEqual(proxy.text, "")
        engine.input("な")
        engine.input(KanaFlickInput.modifierKey)
        XCTAssertEqual(proxy.text, "な")
        engine.commit()
        engine.input(KanaFlickInput.modifierKey)
        XCTAssertEqual(proxy.text, "な")
    }

    /// 문장 부호와 괄호는 짓던 글을 마치고 그대로 들어간다.
    func testPunctuationCommitsReading() {
        let (engine, proxy) = engine()
        engine.input("は")
        engine.input("い")
        engine.input(KanaFlickInput.flicks(for: KanaFlickInput.punctuationKey)[.left]!)
        XCTAssertEqual(proxy.text, "はい。")
        XCTAssertFalse(engine.isComposing)
    }

    /// 긴소리표는 가나처럼 읽기에 붙는다(らーめん).
    func testLongVowelMarkJoinsReading() {
        let (engine, proxy) = engine()
        engine.input("ら")
        engine.input(KanaFlickInput.flicks(for: "わ")[.right]!)
        engine.input("め")
        XCTAssertEqual(proxy.text, "らーめ")
        XCTAssertTrue(engine.isComposing)
    }

    /// 지우기는 가나 하나씩 지운다.
    func testBackspaceRemovesOneKana() {
        let (engine, proxy) = engine()
        engine.input("か")
        engine.input("き")
        engine.backspace()
        XCTAssertEqual(proxy.text, "か")
    }

    /// 설정을 건드리지 않은 사람은 지금까지의 로마자 자판 그대로다.
    func testRomajiStaysDefault() {
        XCTAssertEqual(KeyboardPrefs.japaneseLayout.fallback, JapaneseTypingLayout.romaji.rawValue)
    }
}
