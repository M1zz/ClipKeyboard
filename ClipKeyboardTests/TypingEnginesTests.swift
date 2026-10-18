//
//  TypingEnginesTests.swift
//  ClipKeyboardTests
//
//  자판(`TypingLayouts` · `TypingEngines`) 시험. 키를 누른 결과 = 가짜 입력칸의 글.
//

import XCTest
import UIKit
@testable import ClipKeyboard

/// 입력칸 대역. 넣고 지운 결과를 글 하나로 모은다.
final class FakeTypingProxy: TypingInputProxy {
    private(set) var text = ""
    func insertText(_ t: String) { text += t }
    func deleteBackward() { if !text.isEmpty { text.removeLast() } }
    func insertNewline() { text += "\n" }
    func advanceToNextInputMode() {}
    func attachInputModeSwitch(to button: UIButton) {}
    func cursorRight() {}
    func clearAll() { text = "" }
}

final class TypingEnginesTests: XCTestCase {

    private func type(_ keys: [String], into engine: TypingEngine) {
        keys.forEach { engine.input($0) }
    }

    private func letters(_ s: String) -> [String] { s.map { String($0) } }

    // MARK: - 언어표

    /// 23개 언어 모두 판이 있고, 한 줄이 12칸을 넘지 않는다(그보다 많으면 키가 손가락보다 좁다).
    func testEveryLanguageHasAUsableLayout() {
        XCTAssertEqual(TypingLanguage.allCases.count, 23)
        for lang in TypingLanguage.allCases {
            let rows = lang.layout.rows
            XCTAssertFalse(rows.isEmpty, "\(lang) 판이 비었다")
            for row in rows {
                XCTAssertLessThanOrEqual(row.count, 12, "\(lang) 한 줄이 너무 길다: \(row.count)")
                XCTAssertFalse(row.contains(""), "\(lang) 빈 키")
            }
            if let shifted = lang.layout.shiftedRows {
                XCTAssertEqual(shifted.map(\.count), rows.map(\.count), "\(lang) Shift 판의 모양이 다르다")
            }
            XCTAssertFalse(lang.nativeName.isEmpty)
            XCTAssertFalse(lang.shortLabel.isEmpty)
        }
    }

    /// 앱이 켠 언어와 자판 언어가 같다(i18n/config.json 의 enabled).
    func testLanguagesMatchAppLanguages() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("i18n/config.json")
        let data = try Data(contentsOf: url)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let languages = try XCTUnwrap(json["languages"] as? [String: [String: Any]])
        let enabled = languages.filter { ($0.value["enabled"] as? Bool) == true }.map(\.key)
        XCTAssertEqual(Set(enabled), Set(TypingLanguage.allCases.map(\.rawValue)))
    }

    /// 터키어 대문자는 i → İ, ı → I.
    func testTurkishUppercaseKeepsDots() {
        let rows = TypingLanguage.tr.layout.rows(shifted: true, locale: TypingLanguage.tr.locale, hasCase: true)
        XCTAssertTrue(rows.joined().contains("İ"))
        XCTAssertTrue(rows.joined().contains("I"))
    }

    func testDubeolsikShiftGivesDoubleConsonants() {
        let rows = TypingLanguage.ko.layout.rows(shifted: true, locale: TypingLanguage.ko.locale, hasCase: false)
        XCTAssertEqual(Array(rows[0].prefix(5)), ["ㅃ", "ㅉ", "ㄸ", "ㄲ", "ㅆ"])
    }

    func testAlternatesFollowCase() {
        XCTAssertEqual(TypingLanguage.de.alternates(for: "s").first, "ß")
        XCTAssertEqual(TypingLanguage.fr.alternates(for: "E").first, "É")
        XCTAssertTrue(TypingLanguage.pl.alternates(for: "l").contains("ł"))
        XCTAssertTrue(TypingLanguage.ko.alternates(for: "ㄱ").isEmpty)
    }

    func testDefaultsComeFromDeviceLanguages() {
        XCTAssertEqual(TypingLanguage.defaults(preferred: ["ko-KR", "ja-JP"]), [.ko, .ja, .en])
        XCTAssertEqual(TypingLanguage.defaults(preferred: ["zh-Hant-TW"]), [.zhHant, .en])
        XCTAssertEqual(TypingLanguage.defaults(preferred: ["pt-PT", "nb-NO"]), [.ptBR, .nb, .en])
        XCTAssertEqual(TypingLanguage.defaults(preferred: ["ar-SA"]), [.en])
    }

    // MARK: - 바로 넣기 · 한글

    func testDirectEngineTypesAndDeletes() {
        let proxy = FakeTypingProxy()
        let engine = DirectTypingEngine(proxy: proxy)
        type(letters("hej"), into: engine)
        engine.backspace()
        XCTAssertEqual(proxy.text, "he")
    }

    func testHangulDubeolsikComposes() {
        let proxy = FakeTypingProxy()
        let engine = HangulTypingEngine(proxy: proxy, layout: .dubeolsik)
        type(["ㅎ", "ㅏ", "ㄴ", "ㄱ", "ㅡ", "ㄹ"], into: engine)
        XCTAssertEqual(proxy.text, "한글")
        XCTAssertTrue(engine.isComposing)
        engine.commit()
        XCTAssertFalse(engine.isComposing)
        engine.input(".")
        XCTAssertEqual(proxy.text, "한글.")
    }

    // MARK: - 베트남어 Telex

    private func telex(_ s: String) -> String {
        let proxy = FakeTypingProxy()
        let engine = TelexTypingEngine(proxy: proxy)
        type(letters(s), into: engine)
        return proxy.text
    }

    func testTelexShapes() {
        XCTAssertEqual(telex("aa"), "â")
        XCTAssertEqual(telex("aw"), "ă")
        XCTAssertEqual(telex("dd"), "đ")
        XCTAssertEqual(telex("uow"), "ươ")
        XCTAssertEqual(telex("w"), "ư")
        XCTAssertEqual(telex("aaa"), "aa")
        XCTAssertEqual(telex("tienef"), "tiền")
        XCTAssertEqual(telex("dungd"), "đung")
        XCTAssertEqual(telex("truongw"), "trương")
    }

    func testTelexTones() {
        XCTAssertEqual(telex("as"), "á")
        XCTAssertEqual(telex("viets"), "viét")
        XCTAssertEqual(telex("vieejt"), "việt")
        XCTAssertEqual(telex("Vieejt"), "Việt")
        XCTAssertEqual(telex("nams"), "nám")
        XCTAssertEqual(telex("hoaf"), "hòa")
        XCTAssertEqual(telex("nguoiwf"), "người")
        XCTAssertEqual(telex("quas"), "quá")
        XCTAssertEqual(telex("gias"), "giá")
        XCTAssertEqual(telex("ass"), "as")
        XCTAssertEqual(telex("asz"), "a")
    }

    func testTelexBackspaceAndCommit() {
        let proxy = FakeTypingProxy()
        let engine = TelexTypingEngine(proxy: proxy)
        type(letters("vieejt"), into: engine)
        engine.backspace()
        XCTAssertEqual(proxy.text, "việ")
        engine.commit()
        engine.input(" ")
        type(letters("as"), into: engine)
        XCTAssertEqual(proxy.text, "việ á")
    }

    // MARK: - 일본어 로마자

    func testRomajiToKana() {
        XCTAssertEqual(Romaji.convert("konnichiha").kana, "こんにちは")
        XCTAssertEqual(Romaji.convert("kitte").kana, "きって")
        XCTAssertEqual(Romaji.convert("shinbun").kana, "しんぶ")
        XCTAssertEqual(Romaji.convert("shinbun").rest, "n")
        XCTAssertEqual(Romaji.convert("kyouto").kana, "きょうと")
        XCTAssertEqual(Romaji.convert("k").rest, "k")
        XCTAssertEqual(Romaji.convert("onna").kana, "おんな")
        XCTAssertEqual(Romaji.convert("kanji").kana, "かんじ")
    }

    func testKanaEngineCommitsTrailingN() {
        let proxy = FakeTypingProxy()
        let engine = KanaTypingEngine(proxy: proxy, dictionary: nil)
        type(letters("nihon"), into: engine)
        XCTAssertEqual(proxy.text, "にほn")
        engine.commit()
        XCTAssertEqual(proxy.text, "にほん")
        XCTAssertFalse(engine.isComposing)
    }

    func testKanaEngineBackspace() {
        let proxy = FakeTypingProxy()
        let engine = KanaTypingEngine(proxy: proxy, dictionary: nil)
        type(letters("ka"), into: engine)
        engine.backspace()
        XCTAssertEqual(proxy.text, "")
        engine.backspace()
        XCTAssertEqual(proxy.text, "")
    }

    // MARK: - 중국어(사전 없음)

    func testReadingEngineWithoutDictionaryTypesLetters() {
        let proxy = FakeTypingProxy()
        let engine = ReadingTypingEngine(proxy: proxy, dictionary: nil)
        type(letters("ni"), into: engine)
        XCTAssertEqual(proxy.text, "ni")
        XCTAssertFalse(engine.isComposing)
    }

    func testReadingEngineWithDictionaryShowsCandidates() {
        final class TinyDict: ConversionDictionary {
            func candidates(for reading: String, limit: Int) -> [String] { reading == "ni" ? ["你", "呢"] : [] }
            func noteChosen(_ word: String, for reading: String) {}
        }
        let proxy = FakeTypingProxy()
        let engine = ReadingTypingEngine(proxy: proxy, dictionary: TinyDict())
        type(letters("ni"), into: engine)
        XCTAssertEqual(engine.candidates, ["你", "呢"])
        engine.selectCandidate(at: 1)
        XCTAssertEqual(proxy.text, "呢")
        XCTAssertFalse(engine.isComposing)
    }
}
