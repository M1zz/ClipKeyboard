//
//  ChineseConversionTests.swift
//  ClipKeyboardTests
//
//  병음 · 주음을 치면 한자가 나오는가. 키보드에 실리는 진짜 사전 파일로 본다.
//  (2026-11 사용자 의견 "为什么用输入法无法输入汉字": 사전 자리가 비어 병음 글자만 들어갔다)
//

import XCTest
@testable import ClipKeyboard

final class ChineseConversionTests: XCTestCase {

    private func dictionaryURL(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ClipKeyboardExtension/Dictionaries/\(name).ckdict")
    }

    private func dictionary(_ name: String, learned: LearnedConversions? = nil) throws -> MappedConversionDictionary {
        try XCTUnwrap(MappedConversionDictionary(url: dictionaryURL(name), learned: learned),
                      "\(name) 사전을 열지 못했다. scripts/make_typing_dictionary.py 를 돌렸는가")
    }

    private func type(_ text: String, into engine: TypingEngine) {
        for ch in text { engine.input(String(ch)) }
    }

    // MARK: - 병음

    func testPinyinTurnsIntoHanzi() throws {
        let proxy = MarkedTextProxy()
        let engine = ReadingTypingEngine(proxy: proxy, dictionary: try dictionary("zh-Hans"))
        type("nihao", into: engine)
        XCTAssertEqual(proxy.text, "nihao", "고르기 전에는 읽기가 밑줄 친 채로 보인다")
        XCTAssertEqual(engine.candidates.first, "你好")
        engine.selectCandidate(at: 0)
        XCTAssertEqual(proxy.text, "你好")
        XCTAssertFalse(engine.isComposing)
    }

    func testSingleSyllableOffersCommonCharactersFirst() throws {
        let engine = ReadingTypingEngine(proxy: FakeTypingProxy(), dictionary: try dictionary("zh-Hans"))
        type("wo", into: engine)
        XCTAssertEqual(engine.candidates.first, "我")
        XCTAssertTrue(engine.candidates.contains("握"))
    }

    func testSpaceCommitsFirstCandidate() throws {
        let proxy = MarkedTextProxy()
        let engine = ReadingTypingEngine(proxy: proxy, dictionary: try dictionary("zh-Hans"))
        type("zhongguo", into: engine)
        engine.commit()
        XCTAssertEqual(proxy.text, "中国")
    }

    func testUnfinishedWordIsOffered() throws {
        let engine = ReadingTypingEngine(proxy: FakeTypingProxy(), dictionary: try dictionary("zh-Hans"))
        type("zhongg", into: engine)
        XCTAssertTrue(engine.candidates.prefix(5).contains("中国"), "\(engine.candidates.prefix(5))")
    }

    func testPickingFrontPartKeepsTheRest() throws {
        let proxy = MarkedTextProxy()
        let engine = ReadingTypingEngine(proxy: proxy, dictionary: try dictionary("zh-Hans"))
        type("nihaoshijie", into: engine)
        let index = try XCTUnwrap(engine.candidates.firstIndex(of: "你好"))
        engine.selectCandidate(at: index)
        XCTAssertEqual(proxy.text, "你好shijie")
        XCTAssertTrue(engine.isComposing)
        XCTAssertEqual(engine.candidates.first, "世界")
        engine.selectCandidate(at: 0)
        XCTAssertEqual(proxy.text, "你好世界")
        XCTAssertFalse(engine.isComposing)
    }

    func testLongReadingBecomesOneSentence() throws {
        let proxy = MarkedTextProxy()
        let engine = ReadingTypingEngine(proxy: proxy, dictionary: try dictionary("zh-Hans"))
        type("jintiantianqihenhao", into: engine)
        XCTAssertEqual(engine.candidates.first, "今天天气很好")
        engine.commit()
        XCTAssertEqual(proxy.text, "今天天气很好")
    }

    /// 병음 판에도 Shift 가 있다(왼쪽 아래가 비어 판이 찌그러져 보였다, 2026-11 사용자 의견).
    /// Shift 로 친 대문자는 읽기에 들어가지 않고 그대로 들어간다.
    func testShiftTypesLatinCapitalInsteadOfReading() throws {
        XCTAssertTrue(TypingLanguage.zhHans.shiftTypesLatinCapitals)
        XCTAssertTrue(TypingLanguage.ja.shiftTypesLatinCapitals)
        XCTAssertFalse(TypingLanguage.zhHant.shiftTypesLatinCapitals)
        XCTAssertFalse(TypingLanguage.zhHans.hasCase, "문장 첫 글자에서 Shift 가 저절로 켜지면 첫 글자가 한자가 못 된다")
        let shifted = TypingLanguage.zhHans.layout.rows(shifted: true, locale: TypingLanguage.zhHans.locale, hasCase: true)
        XCTAssertEqual(shifted.first?.first, "Q")

        let proxy = MarkedTextProxy()
        let engine = ReadingTypingEngine(proxy: proxy, dictionary: try dictionary("zh-Hans"))
        type("ni", into: engine)
        engine.input("A")
        XCTAssertEqual(proxy.text, "你A")
        XCTAssertFalse(engine.isComposing)

        let kanaProxy = MarkedTextProxy()
        let kana = KanaTypingEngine(proxy: kanaProxy, dictionary: nil)
        type("ka", into: kana)
        kana.input("B")
        XCTAssertEqual(kanaProxy.text, "かB")
    }

    func testBackspaceShortensReading() throws {
        let proxy = MarkedTextProxy()
        let engine = ReadingTypingEngine(proxy: proxy, dictionary: try dictionary("zh-Hans"))
        type("nih", into: engine)
        engine.backspace()
        XCTAssertEqual(proxy.text, "ni")
        XCTAssertEqual(engine.candidates.first, "你")
        engine.backspace()
        engine.backspace()
        XCTAssertEqual(proxy.text, "")
        XCTAssertFalse(engine.isComposing)
    }

    func testReadingWithNoWordStaysAsTyped() throws {
        let proxy = MarkedTextProxy()
        let engine = ReadingTypingEngine(proxy: proxy, dictionary: try dictionary("zh-Hans"))
        type("xqzv", into: engine)
        engine.commit()
        XCTAssertFalse(proxy.text.isEmpty)
        XCTAssertFalse(engine.isComposing)
    }

    func testChosenWordComesFirstNextTime() throws {
        let suite = "ChineseConversionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = try dictionary("zh-Hans", learned: LearnedConversions(defaults: defaults, key: "learned"))
        let engine = ReadingTypingEngine(proxy: FakeTypingProxy(), dictionary: first)
        type("shi", into: engine)
        let index = try XCTUnwrap(engine.candidates.firstIndex(of: "市"))
        XCTAssertGreaterThan(index, 0)
        engine.selectCandidate(at: index)

        // 키보드가 다시 떠도(새 사전 객체) 기억한다.
        let again = try dictionary("zh-Hans", learned: LearnedConversions(defaults: defaults, key: "learned"))
        let next = ReadingTypingEngine(proxy: FakeTypingProxy(), dictionary: again)
        type("shi", into: next)
        XCTAssertEqual(next.candidates.first, "市")
    }

    // MARK: - 주음

    func testZhuyinTurnsIntoTraditionalHanzi() throws {
        let proxy = MarkedTextProxy()
        let engine = ReadingTypingEngine(proxy: proxy, dictionary: try dictionary("zh-Hant"))
        type("ㄋㄧˇㄏㄠˇ", into: engine)
        XCTAssertEqual(engine.candidates.first, "你好")
        engine.selectCandidate(at: 0)
        XCTAssertEqual(proxy.text, "你好")
    }

    func testZhuyinToneStaysWithItsSyllableWhenPickingFrontPart() throws {
        let proxy = MarkedTextProxy()
        let engine = ReadingTypingEngine(proxy: proxy, dictionary: try dictionary("zh-Hant"))
        type("ㄊㄞˊㄨㄢㄖㄣˊ", into: engine)
        let index = try XCTUnwrap(engine.candidates.firstIndex(of: "臺灣") ?? engine.candidates.firstIndex(of: "台灣"))
        engine.selectCandidate(at: index)
        XCTAssertTrue(proxy.text.hasSuffix("ㄖㄣˊ"), proxy.text)
        engine.commit()
        XCTAssertTrue(proxy.text.hasSuffix("人"), proxy.text)
    }

    // MARK: - 파일

    func testBrokenFileDoesNotOpenOrCrash() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("broken-\(UUID().uuidString).ckdict")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not a dictionary".utf8).write(to: url)
        XCTAssertNil(MappedConversionDictionary(url: url))

        // 머리는 맞지만 뒤가 잘린 파일. 열려도 읽다가 죽지 않는다.
        var cut = try Data(contentsOf: dictionaryURL("zh-Hans"))
        cut = cut.prefix(cut.count / 3)
        try cut.write(to: url)
        let dictionary = MappedConversionDictionary(url: url)
        for reading in ["ni", "zhongguo", "zz", "a", "jintiantianqihenhao"] {
            _ = dictionary?.matches(for: reading, limit: 30)
        }
    }

    /// 아무 키나 4,000번. 죽지 않고, 멈추지 않고, 키 하나에 오래 걸리지 않는다.
    func testRandomTypingNeverCrashesAndStaysFast() throws {
        for (name, keys) in [("zh-Hans", "abcdefghijklmnopqrstuvwxyz".map(String.init)),
                             ("zh-Hant", "ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙㄧㄨㄩㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦˊˇˋ˙".map(String.init))] {
            let proxy = MarkedTextProxy()
            let engine = ReadingTypingEngine(proxy: proxy, dictionary: try dictionary(name))
            var seed: UInt64 = 20261117
            func next(_ bound: Int) -> Int {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Int((seed >> 33) % UInt64(bound))
            }
            let started = Date()
            for _ in 0..<4_000 {
                switch next(20) {
                case 0: engine.backspace()
                case 1: engine.commit()
                case 2: engine.input("，")
                case 3, 4:
                    let count = engine.candidates.count
                    if count > 0 { engine.selectCandidate(at: next(count)) }
                default: engine.input(keys[next(keys.count)])
                }
                _ = engine.candidates
            }
            engine.commit()
            XCTAssertFalse(engine.isComposing)
            let perKey = Date().timeIntervalSince(started) / 4_000
            print("⏱ [ChineseConversionTests] \(name) 키 하나에 \(String(format: "%.2f", perKey * 1000))ms")
            XCTAssertLessThan(perKey, 0.02, "\(name): 키 하나에 20ms 를 넘으면 치는 손을 못 따라간다")
        }
    }

    func testStoreFindsBundledDictionaries() {
        XCTAssertNotNil(ConversionDictionaryStore.dictionary(for: .zhHans), "간체 사전이 앱 안 키보드 확장에 없다")
        XCTAssertNotNil(ConversionDictionaryStore.dictionary(for: .zhHant), "번체 사전이 앱 안 키보드 확장에 없다")
        XCTAssertNil(ConversionDictionaryStore.dictionary(for: .en))
    }
}
