//
//  KeyboardFuzzTests.swift
//  ClipKeyboardTests
//
//  키보드를 **죽이려고** 두드리는 시험. 사람은 정해진 순서로 누르지 않는다.
//  지우기를 연타하고, 조합 중에 언어를 바꾸고, 후보를 고르다 말고, 다른 언어의 글자가
//  붙여 넣기로 들어온다. 그 어떤 순서에서도 엔진이 죽지 않아야 한다.
//
//  시드를 고정해 실패하면 같은 순서로 다시 돌 수 있다.
//

import XCTest
@testable import ClipKeyboard

/// 고정 시드 난수(SplitMix64). 실패한 순서를 그대로 다시 돌리려고 쓴다.
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

/// 무슨 읽기에든 후보를 몇 개 내주는 사전. 후보 고르기 길을 늘 열어 둔다.
private final class AnythingDict: ConversionDictionary {
    func candidates(for reading: String, limit: Int) -> [String] {
        reading.isEmpty ? [] : Array(["漢", "字", reading, reading + reading].prefix(max(0, limit)))
    }
    func noteChosen(_ word: String, for reading: String) {}
}

final class KeyboardFuzzTests: XCTestCase {

    /// 판에 없는 글자들, 붙여 넣기 · 다른 언어 · 이모지 · 결합 문자 · 빈 글.
    private let strangers = ["", " ", "\n", "👍🏽", "👨‍👩‍👧", "é", "e\u{301}", "ㄱ", "ㅏ", "ㆍ", "가", "あ", "ア", "你",
                             "ß", "İ", "ı", "ё", "ς", "ﾞ", "゛", "゜", "ー", "1", "#", "\u{200B}", "ㄳ", "ㅢ", "ᄀ", "ힰ"]

    private func keys(for language: TypingLanguage) -> [String] {
        let layout = language.layout
        let plain = layout.rows.flatMap { $0 }
        let shifted = (layout.shiftedRows ?? []).flatMap { $0 }
        return plain + shifted
    }

    /// 23개 언어 × 한국어 자판 모양 전부에 무작위 동작 4,000번.
    func testEveryEngineSurvivesRandomTyping() {
        for language in TypingLanguage.allCases {
            for koreanLayout in KoreanTypingLayout.allCases {
                if language != .ko, koreanLayout != KoreanTypingLayout.allCases.first { continue }
                for seed in UInt64(1)...3 {
                    hammer(language, koreanLayout: koreanLayout, seed: seed)
                }
            }
        }
    }

    private func hammer(_ language: TypingLanguage, koreanLayout: KoreanTypingLayout, seed: UInt64) {
        var random = SeededRandom(seed: seed &* 7919 &+ UInt64(language.rawValue.hashValue & 0xFFFF))
        // 밑줄 글(marked text)을 쓰는 입력칸과 바로 넣는 입력칸 둘 다.
        let proxy: TypingInputProxy = seed % 2 == 0 ? FakeTypingProxy() : MarkedTextProxy()
        let engine = TypingEngineFactory.make(for: language, proxy: proxy,
                                              koreanLayout: koreanLayout, dictionary: AnythingDict())
        let own = keys(for: language)
        let cheonjiinKeys = koreanLayout == .cheonjiin ? ["ㅣ", "ㆍ", "ㅡ", "ㄱㅋ", "ㄴㄹ", "ㄷㅌ", "ㅂㅍ", "ㅅㅎ", "ㅈㅊ", "ㅇㅁ"] : []

        for _ in 0..<4_000 {
            switch Int.random(in: 0..<100, using: &random) {
            case 0..<60:
                let pool = own + cheonjiinKeys
                engine.input(pool.randomElement(using: &random) ?? "a")
            case 60..<68:
                engine.input(strangers.randomElement(using: &random)!)
            case 68..<84:
                engine.backspace()
            case 84..<89:
                engine.commit()
            case 89..<92:
                engine.reset()
            case 92..<97:
                // 후보 줄이 바뀐 틈에 누른 손가락, 범위 밖 번호도 온다.
                let count = engine.candidates.count
                engine.selectCandidate(at: Int.random(in: -2...(count + 2), using: &random))
            default:
                // 사용자가 입력칸을 통째로 지웠다(엔진은 모른다).
                proxy.clearAll()
            }
        }
        engine.commit()
    }

    /// 천지인을 따로, 같은 키 연타(ㄱ→ㅋ→ㄲ) · 획 모음 · 지우기가 뒤섞여도.
    func testCheonjiinSurvivesRandomStrokes() {
        let keys = ["ㅣ", "ㆍ", "ㅡ", "ㄱㅋ", "ㄴㄹ", "ㄷㅌ", "ㅂㅍ", "ㅅㅎ", "ㅈㅊ", "ㅇㅁ", "x", "", "가"]
        for seed in UInt64(1)...20 {
            var random = SeededRandom(seed: seed)
            let proxy = FakeHangulProxy()
            let composer = HangulComposer()
            composer.proxy = proxy
            let cheonjiin = CheonjiinInput()
            cheonjiin.composer = composer
            for _ in 0..<3_000 {
                switch Int.random(in: 0..<10, using: &random) {
                case 0..<6: cheonjiin.tap(keys.randomElement(using: &random)!)
                case 6..<8: cheonjiin.backspace()
                case 8: cheonjiin.commit()
                default:
                    if Bool.random(using: &random) { cheonjiin.reset() } else { _ = cheonjiin.advance() }
                }
            }
        }
    }

    /// 한글 조합기에 자모가 아닌 것까지, 옛 한글 · 겹자모 · 완성형 · 라틴.
    func testHangulComposerSurvivesAnyCharacter() {
        let pool: [Character] = Array("ㄱㄲㄳㄴㄵㄶㄷㄸㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅃㅄㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ가a1각 ")
        for seed in UInt64(1)...20 {
            var random = SeededRandom(seed: seed)
            let proxy = FakeHangulProxy()
            let composer = HangulComposer()
            composer.proxy = proxy
            var saved: HangulComposer.Snapshot?
            for _ in 0..<3_000 {
                switch Int.random(in: 0..<12, using: &random) {
                case 0..<7: composer.input(pool.randomElement(using: &random)!)
                case 7..<9: composer.backspace()
                case 9: composer.commit()
                case 10: saved = composer.snapshot()
                default:
                    if let saved { composer.restore(saved) } else { composer.reset() }
                }
            }
        }
    }

    /// 플릭 방향 계산, 0 · 무한 · NaN 이동도 들어온다(손가락이 화면 밖으로 나간 순간).
    func testFlickDirectionWithAnyTranslation() {
        let flicks = CheonjiinInput.flicks(for: "ㄱㅋ")
        let values: [CGFloat] = [0, 1, -1, 1e9, -1e9, .infinity, -.infinity, .nan, .ulpOfOne]
        for x in values {
            for y in values {
                _ = CheonjiinInput.flick(for: CGSize(width: x, height: y), in: flicks)
            }
        }
        for key in ["あ", "か", "わ", "", "x"] {
            _ = KanaFlickInput.flicks(for: key)
        }
    }
}
