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

    func testDeviceLanguagesMatchOurLanguages() {
        XCTAssertEqual(TypingLanguage.deviceLanguages(preferred: ["ko-KR", "ja-JP"]), [.ko, .ja, .en])
        XCTAssertEqual(TypingLanguage.deviceLanguages(preferred: ["zh-Hant-TW"]), [.zhHant, .en])
        XCTAssertEqual(TypingLanguage.deviceLanguages(preferred: ["pt-PT", "nb-NO"]), [.ptBR, .nb, .en])
        XCTAssertEqual(TypingLanguage.deviceLanguages(preferred: ["ar-SA"]), [.en])
    }

    /// 처음 켤 언어는 그 사람의 언어 + 영어. 영어는 늘 들어간다.
    func testFirstLanguagesAreUserLanguagesPlusEnglish() {
        XCTAssertEqual(TypingLanguage.defaults(userLanguages: ["ko-KR"]), [.ko, .en])
        XCTAssertEqual(TypingLanguage.defaults(userLanguages: ["en-US", "ko-KR"]), [.en, .ko])
        XCTAssertEqual(TypingLanguage.defaults(userLanguages: ["ar-SA"]), [.en])
        XCTAssertEqual(TypingLanguage.defaults(userLanguages: []), [.en])
    }

    /// 그 사람의 언어: 앱에서 고른 언어 → 기기 언어 → iOS 에 켜 둔 키보드의 언어.
    func testUserLanguagesComeFromAppDeviceAndKeyboards() {
        let d = freshDefaults()
        d.set("ja", forKey: DefaultsKey.appLanguage)
        d.set(["vi-VN"], forKey: DefaultsKey.keyboardUserKeyboardLanguages)
        let codes = TypingPrefs.userLanguageCodes(defaults: d, preferred: ["ko-KR"])
        XCTAssertEqual(TypingLanguage.defaults(userLanguages: codes), [.ja, .ko, .vi, .en])
        // 앱 언어가 "기기 따라감" 이면 건너뛴다.
        d.set(AppLanguage.system.rawValue, forKey: DefaultsKey.appLanguage)
        XCTAssertEqual(TypingLanguage.defaults(userLanguages: TypingPrefs.userLanguageCodes(defaults: d, preferred: ["ko-KR"])),
                       [.ko, .vi, .en])
    }

    func testKeyboardLanguagesParsedFromAppleKeyboards() {
        let keyboards = ["ko_KR@sw=Korean;hw=Automatic", "zh_Hans-Pinyin@sw=Pinyin10;hw=Automatic",
                         "ja_JP-Kana@sw=Kana;hw=Automatic", "emoji@sw=Emoji",
                         "com.Ysoup.TokenMemo.ClipKeyboardExtension", "en_US@sw=QWERTY;hw=Automatic"]
        XCTAssertEqual(TypingLanguage.languageCodes(fromAppleKeyboards: keyboards), ["ko-KR", "zh-Hans", "ja-JP", "en-US"])
        XCTAssertEqual(TypingLanguage.defaults(userLanguages: TypingLanguage.languageCodes(fromAppleKeyboards: keyboards)),
                       [.ko, .zhHans, .ja, .en])
    }

    func testEnabledKeyboardsAreNotedForTheKeyboard() {
        let d = freshDefaults()
        TypingPrefs.noteEnabledKeyboards(["th_TH@sw=Thai;hw=Automatic", "emoji@sw=Emoji"], defaults: d)
        XCTAssertEqual(d.stringArray(forKey: DefaultsKey.keyboardUserKeyboardLanguages), ["th-TH"])
    }

    private func freshDefaults() -> UserDefaults {
        let name = "TypingPrefsTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    /// 키보드를 띄운 적 있는 사람은 업데이트해도 쓰던 자판(기기 언어 + 영어)이 그대로다.
    func testExistingKeyboardUserKeepsDeviceLanguages() {
        let d = freshDefaults()
        d.set(true, forKey: DefaultsKey.keyboardExtensionDidLoad)
        TypingPrefs.keepLegacyDefaultIfNeeded(defaults: d, preferred: ["ko-KR"])
        XCTAssertEqual(d.string(forKey: TypingPrefs.languagesKey), "ko,en")
    }

    /// 새로 깐 사람은 아무것도 적지 않는다. 그래서 새 규칙(그 사람의 언어 + 영어)으로 시작한다.
    func testNewInstallStartsWithEnglish() {
        let d = freshDefaults()
        TypingPrefs.keepLegacyDefaultIfNeeded(defaults: d, preferred: ["ko-KR"])
        XCTAssertNil(d.string(forKey: TypingPrefs.languagesKey))
        // 한 번만 돈다. 나중에 키보드를 띄워도 예전 목록을 적지 않는다.
        d.set(true, forKey: DefaultsKey.keyboardExtensionDidLoad)
        TypingPrefs.keepLegacyDefaultIfNeeded(defaults: d, preferred: ["ko-KR"])
        XCTAssertNil(d.string(forKey: TypingPrefs.languagesKey))
    }

    /// 설정에서 이미 고른 목록은 건드리지 않는다.
    func testChosenListIsNeverOverwritten() {
        let d = freshDefaults()
        d.set(true, forKey: DefaultsKey.keyboardExtensionDidLoad)
        d.set("ja,en", forKey: TypingPrefs.languagesKey)
        TypingPrefs.keepLegacyDefaultIfNeeded(defaults: d, preferred: ["ko-KR"])
        XCTAssertEqual(d.string(forKey: TypingPrefs.languagesKey), "ja,en")
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

    /// 천지인 → 키: 같은 자음 키를 이어 눌러도 ㅋ 로 돌지 않고 새 ㄱ 이 된다(기본 10키와 같다).
    func testCheonjiinAdvanceKeyBreaksConsonantCycle() {
        let proxy = FakeTypingProxy()
        let engine = HangulTypingEngine(proxy: proxy, layout: .cheonjiin)
        type(["ㄱㅋ", CheonjiinInput.advanceKey, "ㄱㅋ"], into: engine)
        XCTAssertEqual(proxy.text, "ㄱㄱ")
    }

    /// 돌림이 없을 때 → 키는 글을 넣지 않는다(커서만 옮긴다).
    func testCheonjiinAdvanceKeyInsertsNothing() {
        let proxy = FakeTypingProxy()
        let engine = HangulTypingEngine(proxy: proxy, layout: .cheonjiin)
        engine.input(CheonjiinInput.advanceKey)
        XCTAssertEqual(proxy.text, "")
    }

    /// 밑줄은 짓는 음절 하나에만 선다. 앞 글자는 바로 확정된다(기본 키보드와 같다).
    func testOnlyComposingSyllableIsMarked() {
        let proxy = MarkedTextProxy()
        let engine = HangulTypingEngine(proxy: proxy, layout: .cheonjiin)
        type(["ㅇㅁ", "ㆍ", "ㅡ", "ㆍ"], into: engine)
        XCTAssertEqual(proxy.marked, "요")
        XCTAssertEqual(proxy.committed, "")
        type(["ㄱㅋ", "ㅣ", "ㆍ", "ㄴㄹ"], into: engine)
        XCTAssertEqual(proxy.committed, "요")
        XCTAssertEqual(proxy.marked, "간")
        type(["ㅣ"], into: engine)
        XCTAssertEqual(proxy.text, "요가니", "받침이 다음 음절로 옮겨 가도 글은 그대로")
        XCTAssertEqual(proxy.marked, "니")
        engine.commit()
        XCTAssertEqual(proxy.text, "요가니")
        XCTAssertEqual(proxy.marked, "")
        engine.backspace()
        XCTAssertEqual(proxy.text, "요가", "확정한 뒤 지우기는 입력칸의 글자를 지운다")
    }

    /// 두벌식도 같다. 모음이 못 된 천지인 점도 밑줄 안에 있다.
    func testMarkedTailIncludesPendingDots() {
        let proxy = MarkedTextProxy()
        let engine = HangulTypingEngine(proxy: proxy, layout: .cheonjiin)
        type(["ㄱㅋ", "ㆍ", "ㅣ", "ㆍ"], into: engine)
        XCTAssertEqual(proxy.text, "거ㆍ")
        XCTAssertEqual(proxy.marked, "거ㆍ")
        let dubeol = MarkedTextProxy()
        let engine2 = HangulTypingEngine(proxy: dubeol, layout: .dubeolsik)
        type(["ㅎ", "ㅏ", "ㄴ", "ㄱ", "ㅡ", "ㄹ"], into: engine2)
        XCTAssertEqual(dubeol.committed, "한")
        XCTAssertEqual(dubeol.marked, "글")
    }

    // MARK: - 저절로 대문자

    /// 기본 키보드처럼 빈 칸 · 문장 끝 뒤에서만 대문자를 켠다.
    func testAutoCapitalizationFollowsSentences() {
        let rule = UITextAutocapitalizationType.sentences
        XCTAssertTrue(TypingKeyboardPanel.wantsCapital(before: nil, rule: rule))
        XCTAssertTrue(TypingKeyboardPanel.wantsCapital(before: "", rule: rule))
        XCTAssertTrue(TypingKeyboardPanel.wantsCapital(before: "Hi. ", rule: rule))
        XCTAssertTrue(TypingKeyboardPanel.wantsCapital(before: "Hi\n", rule: rule))
        XCTAssertFalse(TypingKeyboardPanel.wantsCapital(before: "Hi", rule: rule))
        XCTAssertFalse(TypingKeyboardPanel.wantsCapital(before: "Hi ", rule: rule))
        XCTAssertFalse(TypingKeyboardPanel.wantsCapital(before: "", rule: .none))
        XCTAssertTrue(TypingKeyboardPanel.wantsCapital(before: "a ", rule: .words))
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

/// 밑줄 친 글을 받는 가짜 입력칸(진짜 키보드처럼).
final class MarkedTextProxy: TypingInputProxy {
    private(set) var committed = ""
    private(set) var marked = ""
    private(set) var edits = 0
    var text: String { committed + marked }
    func insertText(_ t: String) { committed += marked + t; marked = "" }
    func deleteBackward() { if !committed.isEmpty { committed.removeLast() } }
    func setComposingText(_ text: String, replacing shown: String) { marked = text; edits += 1 }
    func finishComposingText() { committed += marked; marked = "" }
    func insertNewline() {}
    func advanceToNextInputMode() {}
    func attachInputModeSwitch(to button: UIButton) {}
    func cursorRight() {}
    func clearAll() {}
}

// MARK: - 한글 자판을 끝까지 쳐 보기

/// 모든 음절 · 받침 두 개 · 무작위 치고 지우기로 한글 자판을 훑는다(2026-10 사용자: "특정 글자가 안 써지고,
/// 요를 쓰고 지우면 쓰레기 글자가 튀어나온다"). 진짜 키보드처럼 밑줄 친 글을 받는 입력칸(`MarkedTextProxy`)으로 친다.
final class HangulKeyboardSweepTests: XCTestCase {

    private static let initials: [Character] = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
    private static let medials: [Character] = Array("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ")
    private static let finals: [Character?] = [nil] + Array("ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ").map { Optional($0) }

    private static func syllable(_ i: Int, _ m: Int, _ f: Int) -> String {
        String(Character(UnicodeScalar(0xAC00 + i * 21 * 28 + m * 28 + f)!))
    }

    // MARK: 천지인 키

    /// 자음 하나 → 천지인 키 누름들.
    private static func cheonjiinKeys(consonant c: Character) -> [String] {
        let table: [(String, [Character])] = [
            ("ㄱㅋ", ["ㄱ", "ㅋ", "ㄲ"]), ("ㄴㄹ", ["ㄴ", "ㄹ"]), ("ㄷㅌ", ["ㄷ", "ㅌ", "ㄸ"]),
            ("ㅂㅍ", ["ㅂ", "ㅍ", "ㅃ"]), ("ㅅㅎ", ["ㅅ", "ㅎ", "ㅆ"]), ("ㅈㅊ", ["ㅈ", "ㅊ", "ㅉ"]), ("ㅇㅁ", ["ㅇ", "ㅁ"]),
        ]
        for (key, cycle) in table {
            if let n = cycle.firstIndex(of: c) { return Array(repeating: key, count: n + 1) }
        }
        fatalError("천지인 키에 없는 자음 \(c)")
    }

    private static let compoundFinals: [Character: (Character, Character)] = [
        "ㄳ": ("ㄱ", "ㅅ"), "ㄵ": ("ㄴ", "ㅈ"), "ㄶ": ("ㄴ", "ㅎ"), "ㄺ": ("ㄹ", "ㄱ"), "ㄻ": ("ㄹ", "ㅁ"),
        "ㄼ": ("ㄹ", "ㅂ"), "ㄽ": ("ㄹ", "ㅅ"), "ㄾ": ("ㄹ", "ㅌ"), "ㄿ": ("ㄹ", "ㅍ"), "ㅀ": ("ㄹ", "ㅎ"), "ㅄ": ("ㅂ", "ㅅ"),
    ]

    private static let cheonjiinVowels: [Character: String] = [
        "ㅏ": "ㅣㆍ", "ㅐ": "ㅣㆍㅣ", "ㅑ": "ㅣㆍㆍ", "ㅒ": "ㅣㆍㆍㅣ", "ㅓ": "ㆍㅣ", "ㅔ": "ㆍㅣㅣ", "ㅕ": "ㆍㆍㅣ",
        "ㅖ": "ㆍㆍㅣㅣ", "ㅗ": "ㆍㅡ", "ㅘ": "ㆍㅡㅣㆍ", "ㅙ": "ㆍㅡㅣㆍㅣ", "ㅚ": "ㆍㅡㅣ", "ㅛ": "ㆍㆍㅡ", "ㅜ": "ㅡㆍ",
        "ㅝ": "ㅡㆍㆍㅣ", "ㅞ": "ㅡㆍㆍㅣㅣ", "ㅟ": "ㅡㆍㅣ", "ㅠ": "ㅡㆍㆍ", "ㅡ": "ㅡ", "ㅢ": "ㅡㅣ", "ㅣ": "ㅣ",
    ]

    private static func cheonjiinKeys(i: Int, m: Int, f: Int) -> [String] {
        var keys = cheonjiinKeys(consonant: initials[i])
        keys += cheonjiinVowels[medials[m]]!.map(String.init)
        if let fin = finals[f] {
            if let (a, b) = compoundFinals[fin] {
                keys += cheonjiinKeys(consonant: a) + cheonjiinKeys(consonant: b)
            } else {
                keys += cheonjiinKeys(consonant: fin)
            }
        }
        return keys
    }

    // MARK: 두벌식 키

    private static let dubeolsikVowels: [Character: String] = [
        "ㅘ": "ㅗㅏ", "ㅙ": "ㅗㅐ", "ㅚ": "ㅗㅣ", "ㅝ": "ㅜㅓ", "ㅞ": "ㅜㅔ", "ㅟ": "ㅜㅣ", "ㅢ": "ㅡㅣ",
    ]

    private static func dubeolsikKeys(i: Int, m: Int, f: Int) -> [String] {
        var keys = [String(initials[i])]
        keys += (dubeolsikVowels[medials[m]] ?? String(medials[m])).map(String.init)
        if let fin = finals[f] {
            if let (a, b) = compoundFinals[fin] { keys += [String(a), String(b)] } else { keys.append(String(fin)) }
        }
        return keys
    }

    private func typed(_ keys: [String], layout: KoreanTypingLayout, after prefix: [String] = []) -> String {
        let proxy = MarkedTextProxy()
        let engine = HangulTypingEngine(proxy: proxy, layout: layout)
        for key in prefix { engine.input(key) }
        if !prefix.isEmpty { engine.commit() }
        for key in keys { engine.input(key) }
        engine.commit()
        return proxy.text
    }

    // MARK: 모든 음절

    /// 초성 19 × 중성 21 × 종성 28 = 11,172 음절을 천지인으로 하나씩 쳐서 그 글자가 되는지.
    func testEverySyllableTypesOnCheonjiin() {
        var wrong: [String] = []
        for i in 0..<19 { for m in 0..<21 { for f in 0..<28 {
            let want = Self.syllable(i, m, f)
            let got = typed(Self.cheonjiinKeys(i: i, m: m, f: f), layout: .cheonjiin)
            if got != want { wrong.append("\(want)→\(got)") }
        } } }
        XCTAssertTrue(wrong.isEmpty, "천지인으로 못 치는 음절 \(wrong.count)개: \(wrong.prefix(30))")
    }

    func testEverySyllableTypesOnDubeolsik() {
        var wrong: [String] = []
        for i in 0..<19 { for m in 0..<21 { for f in 0..<28 {
            let want = Self.syllable(i, m, f)
            let got = typed(Self.dubeolsikKeys(i: i, m: m, f: f), layout: .dubeolsik)
            if got != want { wrong.append("\(want)→\(got)") }
        } } }
        XCTAssertTrue(wrong.isEmpty, "두벌식으로 못 치는 음절 \(wrong.count)개: \(wrong.prefix(30))")
    }

    /// 앞 음절 뒤에 이어 칠 때(받침이 될 뻔한 자음, 옮겨 가는 받침)도 맞는지. 앞 글자 "아" 를 확정하지 않고 바로 잇는다.
    func testSyllablesAfterAnOpenSyllable() {
        var wrong: [String] = []
        let a = ["ㅇㅁ", "ㅣ", "ㆍ"]
        for i in 0..<19 { for m in stride(from: 0, to: 21, by: 4) { for f in [0, 1, 4, 6, 8, 10, 15, 21] {
            let want = "아" + Self.syllable(i, m, f)
            // 같은 키가 이어지면 → 로 끊는다(기본 10키와 같다).
            var keys = a
            let next = Self.cheonjiinKeys(i: i, m: m, f: f)
            keys += next
            let proxy = MarkedTextProxy()
            let engine = HangulTypingEngine(proxy: proxy, layout: .cheonjiin)
            for key in keys { engine.input(key) }
            engine.commit()
            if proxy.text != want { wrong.append("\(want)→\(proxy.text)") }
        } } }
        XCTAssertTrue(wrong.isEmpty, "이어 치면 틀리는 것 \(wrong.count)개: \(wrong.prefix(30))")
    }

    /// 받침 두 개 낱말. ㄶ · ㄻ · ㄾ 는 같은 키를 돌리는 사이 앞 글자에서 떨어져 나가 칠 수 없었다.
    func testDoubleFinalWords() {
        let words: [(String, [String])] = [
            ("않", ["ㅇㅁ", "ㅣ", "ㆍ", "ㄴㄹ", "ㅅㅎ", "ㅅㅎ"]),
            ("많", ["ㅇㅁ", "ㅇㅁ", "ㅣ", "ㆍ", "ㄴㄹ", "ㅅㅎ", "ㅅㅎ"]),
            ("삶", ["ㅅㅎ", "ㅣ", "ㆍ", "ㄴㄹ", "ㄴㄹ", "ㅇㅁ", "ㅇㅁ"]),
            ("핥", ["ㅅㅎ", "ㅅㅎ", "ㅣ", "ㆍ", "ㄴㄹ", "ㄴㄹ", "ㄷㅌ", "ㄷㅌ"]),
            ("닭", ["ㄷㅌ", "ㅣ", "ㆍ", "ㄴㄹ", "ㄴㄹ", "ㄱㅋ"]),
            ("값", ["ㄱㅋ", "ㅣ", "ㆍ", "ㅂㅍ", "ㅅㅎ"]),
            ("싫어", ["ㅅㅎ", "ㅣ", "ㄴㄹ", "ㄴㄹ", "ㅅㅎ", "ㅅㅎ", CheonjiinInput.advanceKey, "ㅇㅁ", "ㆍ", "ㅣ"]),
            ("많이", ["ㅇㅁ", "ㅇㅁ", "ㅣ", "ㆍ", "ㄴㄹ", "ㅅㅎ", "ㅅㅎ", "ㅣ"]),
        ]
        for (want, keys) in words {
            XCTAssertEqual(typed(keys, layout: .cheonjiin), want == "많이" ? "만히" : want, want)
        }
    }

    // MARK: 지우기

    /// 요를 쓰고 지우면 요 → 오 → ㅇ → 빈칸. 지운 점(ㆍ)이 다시 튀어나오지 않는다(2026-10 사용자 신고).
    func testDeletingYoNeverRevivesDots() {
        let proxy = MarkedTextProxy()
        let engine = HangulTypingEngine(proxy: proxy, layout: .cheonjiin)
        for key in ["ㅇㅁ", "ㆍ", "ㅡ", "ㆍ"] { engine.input(key) }
        XCTAssertEqual(proxy.text, "요")
        var seen: [String] = []
        for _ in 0..<5 { engine.backspace(); seen.append(proxy.text) }
        XCTAssertEqual(seen, ["오", "ㅇ", "", "", ""])
    }

    /// 받침이 옮겨 간 모음을 지우면 옮겨 간 자음이 남는다(가니 → 가ㄴ). 두벌식 · 기본 키보드와 같고,
    /// 앞 글자는 이미 확정돼 밑줄은 한 글자에만 선다.
    func testDeletingVowelAfterMovedFinal() {
        let proxy = MarkedTextProxy()
        let engine = HangulTypingEngine(proxy: proxy, layout: .cheonjiin)
        for key in ["ㄱㅋ", "ㅣ", "ㆍ", "ㄴㄹ", "ㅣ"] { engine.input(key) }
        XCTAssertEqual(proxy.text, "가니")
        XCTAssertEqual(proxy.marked, "니")
        engine.backspace()
        XCTAssertEqual(proxy.text, "가ㄴ")
        engine.input("ㅣ")
        XCTAssertEqual(proxy.text, "가니")
    }

    /// 점 두 개는 앞 음절과 한 글자로 합쳐지지 않는다. 옛한글 ᆢ 를 쓰던 때는 "븨" + ᆢ 가 한 글자가 되어
    /// 점을 지우면 븨 까지 지워지거나, 지운 글자가 다시 튀어나왔다(2026-10 사용자 신고).
    func testDoubleDotNeverMergesWithSyllable() {
        XCTAssertEqual(("븨" + String(CheonjiinInput.doubleDot)).count, 2)
        XCTAssertEqual(("가" + String(CheonjiinInput.doubleDot)).count, 2)
        let proxy = MarkedTextProxy()
        let engine = HangulTypingEngine(proxy: proxy, layout: .cheonjiin)
        for key in ["ㅂㅍ", "ㅡ", "ㅣ", CheonjiinInput.advanceKey, "ㆍ", "ㆍ"] { engine.input(key) }
        XCTAssertEqual(proxy.text, "븨" + String(CheonjiinInput.doubleDot))
        engine.backspace()
        XCTAssertEqual(proxy.text, "븨")
        for key in ["ㅇㅁ", "ㆍ", "ㆍ", "ㅣ"] { engine.input(key) }
        XCTAssertEqual(proxy.text, "븨여")
    }

    // MARK: 무작위

    private struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    private static func allowed(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy { s in
            (0xAC00...0xD7A3).contains(s.value) || (0x3131...0x318E).contains(s.value) || s == "\u{2025}" || s == " " || s == "."
        }
    }

    /// 아무렇게나 치고 지워도: 지우기는 글을 늘리지 않고 앞 글자를 바꾸지 않는다, 확정하면 점이 남지 않는다,
    /// 밑줄은 두 글자를 넘지 않는다, 밑줄 방식과 지우고 쓰는 방식이 같은 글이 된다.
    func testRandomCheonjiinKeepsInvariants() {
        fuzz(.cheonjiin, keys: ["ㄱㅋ", "ㄴㄹ", "ㄷㅌ", "ㅂㅍ", "ㅅㅎ", "ㅈㅊ", "ㅇㅁ", "ㅣ", "ㆍ", "ㅡ", "ㅣ", "ㆍ", "ㅡ",
                                "ㅏ", "ㅓ", "ㅑ", "ㅕ", "ㅗ", "ㅜ",
                                CheonjiinInput.advanceKey, "⌫", "⌫", "␣", "."])
    }

    // MARK: 밀어서 넣기

    /// ㅣ 키를 누른 채 밀면 기본 10키처럼 ← ㅓ · → ㅏ · ↑ ㅕ · ↓ ㅑ, ㅡ 키는 ↑ ㅗ · ↓ ㅜ.
    func testFlickTable() {
        XCTAssertEqual(CheonjiinInput.flicks(for: "ㅣ"), [.left: "ㅓ", .right: "ㅏ", .up: "ㅕ", .down: "ㅑ"])
        XCTAssertEqual(CheonjiinInput.flicks(for: "ㅡ"), [.up: "ㅗ", .down: "ㅜ"])
        XCTAssertTrue(CheonjiinInput.flicks(for: "ㆍ").isEmpty)
    }

    /// 덜 밀면 탭, 많이 간 쪽이 고른 쪽, 모음이 없는 쪽은 고르지 않는다.
    func testFlickDirection() {
        let i = CheonjiinInput.flicks(for: "ㅣ"), eu = CheonjiinInput.flicks(for: "ㅡ")
        XCTAssertNil(CheonjiinInput.flick(for: CGSize(width: 10, height: -5), in: i))
        XCTAssertEqual(CheonjiinInput.flick(for: CGSize(width: -30, height: 8), in: i), .left)
        XCTAssertEqual(CheonjiinInput.flick(for: CGSize(width: 25, height: 3), in: i), .right)
        XCTAssertEqual(CheonjiinInput.flick(for: CGSize(width: 4, height: -40), in: i), .up)
        XCTAssertEqual(CheonjiinInput.flick(for: CGSize(width: -6, height: 22), in: i), .down)
        XCTAssertNil(CheonjiinInput.flick(for: CGSize(width: 30, height: 0), in: eu))
        XCTAssertEqual(CheonjiinInput.flick(for: CGSize(width: 3, height: -30), in: eu), .up)
    }

    /// 밀어서 넣은 모음은 앞 자음과 음절이 되고, 받침도 다음 음절로 넘어가고, 뒤의 획이 더해진다.
    func testFlickVowelsCompose() {
        XCTAssertEqual(typed(["ㄱㅋ", "ㅏ"], layout: .cheonjiin), "가")
        XCTAssertEqual(typed(["ㅇㅁ", "ㅏ", "ㄴㄹ", "ㅣ"], layout: .cheonjiin), "아니")
        XCTAssertEqual(typed(["ㅇㅁ", "ㅏ", "ㄴㄹ", "ㄴㄹ", "ㅕ"], layout: .cheonjiin), "아려")
        XCTAssertEqual(typed(["ㅅㅎ", "ㅅㅎ", "ㅏ", "ㄴㄹ", "ㄱㅋ", "ㅜ", "ㄱㅋ"], layout: .cheonjiin), "한국")
        XCTAssertEqual(typed(["ㄱㅋ", "ㅏ", "ㅣ"], layout: .cheonjiin), "개")
        XCTAssertEqual(typed(["ㄱㅋ", "ㅗ", "ㅏ"], layout: .cheonjiin), "과")
        XCTAssertEqual(typed(["ㅇㅁ", "ㅑ"], layout: .cheonjiin), "야")
        XCTAssertEqual(typed(["ㅇㅁ", "ㅕ", "ㅇㅁ", CheonjiinInput.advanceKey, "ㅇㅁ", "ㅓ"], layout: .cheonjiin), "영어")
        // 점을 찍다 밀어 넣으면 점은 버린다.
        XCTAssertEqual(typed(["ㄱㅋ", "ㆍ", "ㅏ"], layout: .cheonjiin), "가")
    }

    /// 자음을 돌리던 중 밀어 넣으면 돌림이 끊긴다(다음 ㄱ 은 ㅋ 이 아니라 새 ㄱ).
    func testFlickBreaksConsonantCycle() {
        XCTAssertEqual(typed(["ㄱㅋ", "ㅏ", "ㄱㅋ", "ㅏ"], layout: .cheonjiin), "가가")
        XCTAssertEqual(typed(["ㄱㅋ", "ㄱㅋ", "ㅗ"], layout: .cheonjiin), "코")
    }

    /// 지우면 밀어 넣은 모음이 통째로 지워진다(점이나 획으로 돌아가지 않는다).
    func testDeletingFlickVowel() {
        let proxy = MarkedTextProxy()
        let engine = HangulTypingEngine(proxy: proxy, layout: .cheonjiin)
        for key in ["ㄱㅋ", "ㅑ"] { engine.input(key) }
        XCTAssertEqual(proxy.text, "갸")
        engine.backspace()
        XCTAssertEqual(proxy.text, "ㄱ")
        engine.input("ㅕ")
        XCTAssertEqual(proxy.text, "겨")
    }

    func testRandomDubeolsikKeepsInvariants() {
        fuzz(.dubeolsik, keys: Array("ㄱㄴㄷㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎㄲㅆㅏㅓㅗㅜㅡㅣㅐㅔㅑㅕㅛㅠ").map(String.init) + ["⌫", "⌫", "␣", "."])
    }

    private func fuzz(_ layout: KoreanTypingLayout, keys: [String]) {
        for seed in 1...1000 {
            var rng = Seeded(state: UInt64(seed))
            let marked = MarkedTextProxy()
            let plain = FakeTypingProxy()
            let a = HangulTypingEngine(proxy: marked, layout: layout)
            let b = HangulTypingEngine(proxy: plain, layout: layout)
            var log: [String] = []
            for _ in 0..<80 {
                let key = keys.randomElement(using: &rng)!
                log.append(key)
                let before = marked.text
                for (engine, proxy) in [(a, marked as TypingInputProxy), (b, plain as TypingInputProxy)] {
                    switch key {
                    case "⌫": engine.backspace()
                    case "␣": engine.commit(); proxy.insertText(" ")
                    default: engine.input(key)
                    }
                }
                let where_ = "seed \(seed): \(log.joined(separator: " "))"
                XCTAssertTrue(Self.allowed(marked.text), "엉뚱한 글자 \(marked.text) · \(where_)")
                XCTAssertLessThanOrEqual(marked.marked.count, 2, "밑줄이 길다 \(marked.marked) · \(where_)")
                XCTAssertEqual(marked.text, plain.text, "밑줄 방식과 결과가 다르다 · \(where_)")
                if key == "⌫" {
                    XCTAssertLessThanOrEqual(marked.text.count, before.count, "지웠는데 글이 늘었다 \(before)→\(marked.text) · \(where_)")
                    XCTAssertTrue(marked.text.hasPrefix(String(before.dropLast(2))), "지웠는데 앞 글이 바뀌었다 \(before)→\(marked.text) · \(where_)")
                }
                if key == "␣" {
                    XCTAssertFalse(marked.text.contains("ㆍ") || marked.text.contains(CheonjiinInput.doubleDot), "확정했는데 점이 남았다 · \(where_)")
                    XCTAssertEqual(marked.marked, "")
                }
                if marked.text != plain.text || !Self.allowed(marked.text) { return }
            }
            // 끝까지 지우면 빈칸이 된다(지우기가 멈추지 않는다).
            for _ in 0..<(marked.text.count * 3 + 10) { a.backspace() }
            XCTAssertEqual(marked.text, "", "끝까지 지워지지 않는다 · seed \(seed)")
        }
    }
}
