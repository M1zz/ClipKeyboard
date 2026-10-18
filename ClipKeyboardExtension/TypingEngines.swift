//
//  TypingEngines.swift
//  ClipKeyboard
//
//  **자판의 글자 넣기.** 키를 누르면 엔진이 받아 입력칸에 무엇을 넣고 지울지 정한다.
//
//  ⚠️ 언어가 무엇을 쓰는지는 `TypingLanguage.engine` 이 정한다. 화면(`TypingKeyboardView`)은
//     어느 엔진인지 모른 채 `input` · `backspace` · `commit` 만 부른다.
//  ⚠️ 조합 중인 글자는 **지웠다 다시 쓰는 방식**으로 보인다(한글 조합기와 같은 길).
//     키보드 탭의 무대도 같은 `TypingInputProxy` 를 받으므로 진짜 키보드와 똑같이 움직인다.
//

import UIKit

// MARK: - 입력칸

/// 자판 → 입력칸. 진짜 키보드는 `KeyboardViewController`, 키보드 탭의 무대는 `InAppKeyboardHost` 가 구현한다.
protocol TypingInputProxy: AnyObject {
    func insertText(_ text: String)
    func deleteBackward()
    func insertNewline()

    /// ⚠️ **지구본 키에 쓰지 말 것.** 이 API 는 글자 키보드만 순서대로 돌고
    ///    **이모지 키보드는 건너뛴다.** 타사 키보드를 함께 쓰는 사람이 지구본을
    ///    눌러도 이모지가 나오지 않던 원인이 이것이었다.
    ///    지구본은 `attachInputModeSwitch(to:)` 로 붙인다.
    func advanceToNextInputMode()

    /// 지구본 키에 iOS 표준 전환 동작을 붙인다.
    ///
    /// 탭이면 다음 키보드, 길게 누르면 **이모지를 포함한** 키보드 목록이 뜬다.
    /// 이 동작은 `handleInputModeList(from:with:)` 가 붙은 UIControl 에서만 나온다.
    func attachInputModeSwitch(to button: UIButton)

    func cursorRight()
    func clearAll()
}

// MARK: - 엔진

/// 키를 받아 글자를 넣는 것. 언어마다 하나.
protocol TypingEngine: AnyObject {
    /// 글자 키 하나.
    func input(_ key: String)
    /// 지우기. 조합 중이면 한 단계 되돌리고, 아니면 입력칸의 한 글자를 지운다.
    func backspace()
    /// 조합을 끝낸다(스페이스 · 보내기 · 언어 바꾸기 · 층 바꾸기 앞에서).
    func commit()
    /// 새 입력칸으로 왔다. 조합 상태만 비운다(이미 들어간 글자는 그대로).
    func reset()
    /// 조합 중인 글자가 있는가. 스페이스가 조합을 끝내기만 할지 빈칸도 넣을지 가른다.
    var isComposing: Bool { get }
    /// 지금 고를 수 있는 후보(일본어 한자 · 중국어 한자). 없으면 빈 배열.
    var candidates: [String] { get }
    /// 후보 하나를 고른다.
    func selectCandidate(at index: Int)
}

extension TypingEngine {
    var candidates: [String] { [] }
    func selectCandidate(at index: Int) {}
}

/// 엔진을 만드는 곳. 화면은 언어만 알고 여기서 엔진을 받는다.
enum TypingEngineFactory {
    static func make(for language: TypingLanguage,
                     proxy: TypingInputProxy,
                     koreanLayout: KoreanTypingLayout,
                     dictionary: ConversionDictionary? = nil) -> TypingEngine {
        switch language.engine {
        case .direct:
            return DirectTypingEngine(proxy: proxy)
        case .hangul:
            return HangulTypingEngine(proxy: proxy, layout: koreanLayout)
        case .telex:
            return TelexTypingEngine(proxy: proxy)
        case .kana:
            return KanaTypingEngine(proxy: proxy, dictionary: dictionary)
        case .pinyin, .zhuyin:
            return ReadingTypingEngine(proxy: proxy, dictionary: dictionary)
        }
    }
}

/// 한국어 자판 모양. 설정(`DefaultsKey.keyboardKoreanLayout`)에 rawValue 로 남는다.
enum KoreanTypingLayout: String, CaseIterable {
    case dubeolsik, cheonjiin
}

/// 지웠다 다시 쓰는 조합 글자. 지금 입력칸에 몇 글자를 써 두었는지 기억한다.
private struct ComposingText {
    private(set) var shown: String = ""

    /// `next` 를 보이게 한다. 앞부분이 같으면 다른 부분만 지우고 쓴다.
    mutating func show(_ next: String, on proxy: TypingInputProxy) {
        let old = Array(shown)
        let new = Array(next)
        var same = 0
        while same < old.count, same < new.count, old[same] == new[same] { same += 1 }
        for _ in same..<old.count { proxy.deleteBackward() }
        if same < new.count { proxy.insertText(String(new[same...])) }
        shown = next
    }

    /// 보이던 것을 그대로 두고 잊는다(확정).
    mutating func forget() { shown = "" }
}

// MARK: - 바로 넣기

final class DirectTypingEngine: TypingEngine {
    private let proxy: TypingInputProxy
    init(proxy: TypingInputProxy) { self.proxy = proxy }

    var isComposing: Bool { false }
    func input(_ key: String) { proxy.insertText(key) }
    func backspace() { proxy.deleteBackward() }
    func commit() {}
    func reset() {}
}

// MARK: - 한글

/// 두벌식은 `HangulComposer`, 천지인은 `CheonjiinInput` 이 그 위에서 돈다.
final class HangulTypingEngine: TypingEngine {
    private let composer = HangulComposer()
    private let cheonjiin = CheonjiinInput()
    private let layout: KoreanTypingLayout

    init(proxy: TypingInputProxy, layout: KoreanTypingLayout) {
        self.layout = layout
        composer.proxy = HangulProxyAdapter(typing: proxy)
        cheonjiin.composer = composer
    }

    var isComposing: Bool { composer.isComposing }

    func input(_ key: String) {
        switch layout {
        case .dubeolsik:
            guard let jamo = key.first, key.count == 1 else {
                composer.commit()
                composer.proxy?.insertText(key)
                return
            }
            composer.input(jamo)
        case .cheonjiin:
            if CheonjiinInput.handles(key) {
                cheonjiin.tap(key)
            } else {
                cheonjiin.commit()
                composer.proxy?.insertText(key)
            }
        }
    }

    func backspace() {
        switch layout {
        case .dubeolsik: composer.backspace()
        case .cheonjiin: cheonjiin.backspace()
        }
    }

    func commit() {
        if layout == .cheonjiin { cheonjiin.commit() }
        composer.commit()
    }

    func reset() {
        cheonjiin.reset()
        composer.reset()
    }
}

/// 한글 조합기는 제 프록시를 쓴다. 자판 프록시를 그 모양으로 잇는다.
final class HangulProxyAdapter: HangulInputProxy {
    let typing: TypingInputProxy
    init(typing: TypingInputProxy) { self.typing = typing }
    func insertText(_ text: String) { typing.insertText(text) }
    func deleteBackward() { typing.deleteBackward() }
}

// MARK: - 베트남어 Telex

/// Telex 규칙으로 한 낱말을 모은다.
///
/// - 모양: aa → â, aw → ă, ee → ê, oo → ô, ow → ơ, uw → ư, uow → ươ, dd → đ, 홀로 w → ư
/// - 성조: s 날카로운(á) · f 내리는(à) · r 물음(ả) · x 물결(ã) · j 무거운(ạ) · z 지우기
/// - 같은 키를 한 번 더 누르면 되돌리고 그 글자를 그대로 친다(ss → s, aaa → aa).
/// 낱말은 스페이스 · 기호 · 언어 바꾸기에서 끝난다.
final class TelexTypingEngine: TypingEngine {
    private let proxy: TypingInputProxy
    private var text = ComposingText()
    /// 모양까지만 붙은 글자들(성조 없음).
    private var letters: [Character] = []
    private var tone: VietTone = .none

    init(proxy: TypingInputProxy) { self.proxy = proxy }

    var isComposing: Bool { !letters.isEmpty }

    func input(_ key: String) {
        guard key.count == 1, let ch = key.first, ch.isLetter else {
            commit()
            proxy.insertText(key)
            return
        }
        apply(ch)
        text.show(VietSyllable.render(letters: letters, tone: tone), on: proxy)
    }

    func backspace() {
        guard !letters.isEmpty else {
            proxy.deleteBackward()
            return
        }
        letters.removeLast()
        if letters.isEmpty { tone = .none }
        text.show(VietSyllable.render(letters: letters, tone: tone), on: proxy)
        if letters.isEmpty { text.forget() }
    }

    func commit() {
        letters.removeAll()
        tone = .none
        text.forget()
    }

    func reset() { commit() }

    /// 키 하나를 규칙에 맞춰 반영한다. 시험에서 바로 부를 수 있게 남긴다.
    func apply(_ ch: Character) {
        let lower = Character(ch.lowercased())
        let upper = ch.isUppercase

        // 성조 키(낱말에 모음이 있을 때만)
        if let newTone = VietTone(key: lower), VietSyllable.hasVowel(letters) {
            if newTone == .none {
                if tone != .none { tone = .none; return }
            } else if tone == newTone {
                // 같은 성조를 또 누르면 성조를 빼고 그 글자를 친다(ss → s).
                tone = .none
                letters.append(ch)
                return
            } else {
                tone = newTone
                return
            }
        }

        // 같은 모음을 또 치면 모자(^)를 씌운다: aa → â, ee → ê, oo → ô.
        // 바로 앞 글자가 아니어도 된다(tienef → tiến). 그 모음 뒤로 모음이 없을 때만.
        if "aeo".contains(lower), let i = Self.lastIndex(of: lower, in: letters, onlyFollowedByConsonants: true) {
            let target: Character = lower == "a" ? "â" : lower == "e" ? "ê" : "ô"
            Self.replace(&letters, at: i, with: target)
            return
        }
        // 모자를 한 번 더 치면 벗기고 그 글자를 친다: â + a → aa.
        if "aeo".contains(lower), let last = letters.last {
            let base: [Character: Character] = ["â": "a", "ê": "e", "ô": "o"]
            if let plain = base[Character(last.lowercased())], plain == lower {
                Self.replace(&letters, at: letters.count - 1, with: plain)
                letters.append(ch)
                return
            }
        }
        // dd → đ. 첫소리 d 에만 붙는다(dungd → đung).
        if lower == "d", let first = letters.first {
            let firstLower = Character(first.lowercased())
            if firstLower == "d" { Self.replace(&letters, at: 0, with: "đ"); return }
            if firstLower == "đ", letters.count == 1 { Self.replace(&letters, at: 0, with: "d"); letters.append(ch); return }
        }
        // w: 낱말 안의 uo → ươ, 아니면 마지막 a · o · u → ă · ơ · ư. 이미 붙었으면 벗기고 w 를 친다.
        if lower == "w" {
            let lowered = letters.map { Character($0.lowercased()) }
            if let undo = lowered.lastIndex(where: { "ăơư".contains($0) }), !Self.hasVowel(after: undo, in: lowered) || lowered[undo] == "ơ" {
                let base: [Character: Character] = ["ă": "a", "ơ": "o", "ư": "u"]
                if lowered[undo] == "ơ", undo > 0, lowered[undo - 1] == "ư" {
                    Self.replace(&letters, at: undo - 1, with: "u")
                }
                Self.replace(&letters, at: undo, with: base[lowered[undo]]!)
                letters.append(ch)
                return
            }
            if let o = lowered.lastIndex(of: "o"), o > 0, lowered[o - 1] == "u" {
                Self.replace(&letters, at: o - 1, with: "ư")
                Self.replace(&letters, at: o, with: "ơ")
                return
            }
            if let i = lowered.lastIndex(where: { "aou".contains($0) }) {
                let target: Character = lowered[i] == "a" ? "ă" : lowered[i] == "o" ? "ơ" : "ư"
                Self.replace(&letters, at: i, with: target)
                return
            }
            // 홀로 친 w 는 ư (Telex 관례).
            letters.append(upper ? "Ư" : "ư")
            return
        }
        letters.append(ch)
    }

    /// 지금 보이는 낱말(시험용).
    var rendered: String { VietSyllable.render(letters: letters, tone: tone) }

    /// 대소문자를 지키며 바꾼다.
    private static func replace(_ letters: inout [Character], at index: Int, with c: Character) {
        letters[index] = letters[index].isUppercase ? Character(c.uppercased()) : c
    }

    /// `vowel` 과 같은(모자 없는) 마지막 모음. `onlyFollowedByConsonants` 면 그 뒤에 모음이 없어야 한다.
    private static func lastIndex(of vowel: Character, in letters: [Character], onlyFollowedByConsonants: Bool) -> Int? {
        let lowered = letters.map { Character($0.lowercased()) }
        guard let i = lowered.lastIndex(of: vowel) else { return nil }
        if onlyFollowedByConsonants, hasVowel(after: i, in: lowered) { return nil }
        return i
    }

    private static func hasVowel(after index: Int, in lowered: [Character]) -> Bool {
        lowered.indices.contains(where: { $0 > index && VietSyllable.vowels.contains(lowered[$0]) })
    }
}

enum VietTone: Equatable {
    case none, acute, grave, hook, tilde, dot

    init?(key: Character) {
        switch key {
        case "s": self = .acute
        case "f": self = .grave
        case "r": self = .hook
        case "x": self = .tilde
        case "j": self = .dot
        case "z": self = .none
        default: return nil
        }
    }

    /// 결합 부호. 모음 뒤에 붙인 뒤 NFC 로 합친다.
    var combining: String {
        switch self {
        case .none: return ""
        case .acute: return "\u{0301}"
        case .grave: return "\u{0300}"
        case .hook: return "\u{0309}"
        case .tilde: return "\u{0303}"
        case .dot: return "\u{0323}"
        }
    }
}

/// 베트남어 음절에 성조를 어디에 얹는지.
enum VietSyllable {
    static let vowels: Set<Character> = ["a", "ă", "â", "e", "ê", "i", "o", "ô", "ơ", "u", "ư", "y"]
    /// 모양이 붙은 모음. 있으면 성조는 여기에 간다.
    static let marked: Set<Character> = ["ă", "â", "ê", "ô", "ơ", "ư"]

    static func isVowel(_ c: Character) -> Bool { vowels.contains(Character(c.lowercased())) }

    static func hasVowel(_ letters: [Character]) -> Bool { letters.contains(where: isVowel) }

    /// 성조가 갈 글자 자리.
    static func tonePosition(_ letters: [Character]) -> Int? {
        let lower = letters.map { Character($0.lowercased()) }
        guard var start = lower.firstIndex(where: { vowels.contains($0) }) else { return nil }
        // qu · gi 의 u · i 는 첫소리의 일부다(그 뒤에 모음이 더 있을 때).
        if start > 0, start + 1 < lower.count, vowels.contains(lower[start + 1]) {
            let prev = lower[start - 1]
            if (prev == "q" && lower[start] == "u") || (prev == "g" && lower[start] == "i") { start += 1 }
        }
        var end = start
        while end + 1 < lower.count, vowels.contains(lower[end + 1]) { end += 1 }
        let cluster = Array(start...end)
        // 모양 붙은 모음이 있으면 거기(ươ 는 ơ).
        if let markedIndex = cluster.last(where: { marked.contains(lower[$0]) }) { return markedIndex }
        if cluster.count == 1 { return cluster[0] }
        // 모음 뒤에 끝소리가 있으면 마지막 모음, 없으면 셋이면 가운데 · 둘이면 앞.
        let hasFinal = end + 1 < lower.count
        if hasFinal { return cluster.last }
        return cluster.count >= 3 ? cluster[1] : cluster[0]
    }

    static func render(letters: [Character], tone: VietTone) -> String {
        guard tone != .none, let pos = tonePosition(letters) else { return String(letters) }
        var out = ""
        for (i, c) in letters.enumerated() {
            out.append(c)
            if i == pos { out += tone.combining }
        }
        return out.precomposedStringWithCanonicalMapping
    }
}

// MARK: - 일본어(로마자 → 가나)

/// 로마자를 치면 히라가나로 바꾼다. 사전이 있으면 그 읽기로 한자 후보를 낸다.
///
/// ⚠️ 사전은 앱이 필요할 때 받아 App Group 에 둔다(`ConversionDictionary`). 없으면 가나까지만 친다.
final class KanaTypingEngine: TypingEngine {
    private let proxy: TypingInputProxy
    private let dictionary: ConversionDictionary?
    private var text = ComposingText()
    /// 확정 전 읽기(가나)와 아직 가나가 못 된 로마자.
    private(set) var kana: String = ""
    private(set) var pending: String = ""

    init(proxy: TypingInputProxy, dictionary: ConversionDictionary?) {
        self.proxy = proxy
        self.dictionary = dictionary
    }

    var isComposing: Bool { !kana.isEmpty || !pending.isEmpty }

    var candidates: [String] {
        guard pending.isEmpty, !kana.isEmpty, let dictionary else { return [] }
        return dictionary.candidates(for: kana, limit: 30)
    }

    func input(_ key: String) {
        if key == "-" && isComposing {
            flushPending()
            kana += "ー"
        } else if key.count == 1, let ch = key.first, ch.isASCII, ch.isLetter {
            pending += ch.lowercased()
            let (out, rest) = Romaji.convert(pending)
            kana += out
            pending = rest
        } else {
            commit()
            proxy.insertText(key)
            return
        }
        render()
    }

    func backspace() {
        if !pending.isEmpty {
            pending.removeLast()
        } else if !kana.isEmpty {
            kana.removeLast()
        } else {
            proxy.deleteBackward()
            return
        }
        render()
        if !isComposing { text.forget() }
    }

    func commit() {
        flushPending()
        render()
        kana = ""
        pending = ""
        text.forget()
    }

    func reset() {
        kana = ""
        pending = ""
        text.forget()
    }

    func selectCandidate(at index: Int) {
        let list = candidates
        guard list.indices.contains(index) else { return }
        text.show(list[index], on: proxy)
        dictionary?.noteChosen(list[index], for: kana)
        kana = ""
        pending = ""
        text.forget()
    }

    /// 끝에 남은 n 은 ん 으로, 나머지 로마자는 그대로 둔다.
    private func flushPending() {
        if pending == "n" || pending == "nn" { kana += "ん"; pending = "" }
        kana += pending
        pending = ""
    }

    private func render() { text.show(kana + pending, on: proxy) }
}

/// 헵번 · 훈령 둘 다 받는 로마자 → 히라가나.
enum Romaji {
    private static let table: [String: String] = {
        var t: [String: String] = [
            "a": "あ", "i": "い", "u": "う", "e": "え", "o": "お",
            "ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ",
            "ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
            "sa": "さ", "si": "し", "shi": "し", "su": "す", "se": "せ", "so": "そ",
            "za": "ざ", "zi": "じ", "ji": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
            "ta": "た", "ti": "ち", "chi": "ち", "tu": "つ", "tsu": "つ", "te": "て", "to": "と",
            "da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
            "na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の",
            "ha": "は", "hi": "ひ", "hu": "ふ", "fu": "ふ", "he": "へ", "ho": "ほ",
            "ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ",
            "pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
            "ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
            "ya": "や", "yu": "ゆ", "yo": "よ",
            "ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ",
            "wa": "わ", "wi": "うぃ", "we": "うぇ", "wo": "を",
            "nn": "ん", "n'": "ん",
            "fa": "ふぁ", "fi": "ふぃ", "fe": "ふぇ", "fo": "ふぉ",
            "va": "ゔぁ", "vi": "ゔぃ", "vu": "ゔ", "ve": "ゔぇ", "vo": "ゔぉ",
            "la": "ぁ", "li": "ぃ", "lu": "ぅ", "le": "ぇ", "lo": "ぉ",
            "xa": "ぁ", "xi": "ぃ", "xu": "ぅ", "xe": "ぇ", "xo": "ぉ",
            "ltu": "っ", "xtu": "っ", "lya": "ゃ", "lyu": "ゅ", "lyo": "ょ", "xya": "ゃ", "xyu": "ゅ", "xyo": "ょ",
            "sha": "しゃ", "shu": "しゅ", "she": "しぇ", "sho": "しょ",
            "cha": "ちゃ", "chu": "ちゅ", "che": "ちぇ", "cho": "ちょ",
            "ja": "じゃ", "ju": "じゅ", "je": "じぇ", "jo": "じょ",
            "tsa": "つぁ", "thi": "てぃ", "dhi": "でぃ",
        ]
        // 요음: kya, gya, sya, zya(jya), tya, dya, nya, hya, bya, pya, mya, rya
        let youon: [(String, String)] = [("k", "き"), ("g", "ぎ"), ("s", "し"), ("z", "じ"), ("j", "じ"),
                                          ("t", "ち"), ("c", "ち"), ("d", "ぢ"), ("n", "に"), ("h", "ひ"),
                                          ("b", "び"), ("p", "ぴ"), ("m", "み"), ("r", "り")]
        for (c, base) in youon {
            t["\(c)ya"] = base + "ゃ"
            t["\(c)yu"] = base + "ゅ"
            t["\(c)yo"] = base + "ょ"
        }
        return t
    }()

    private static let maxKey = 3

    /// 앞에서부터 바꿀 수 있는 만큼 바꾸고, 아직 모자란 로마자를 남긴다.
    static func convert(_ input: String) -> (kana: String, rest: String) {
        var out = ""
        var rest = Substring(input)
        while !rest.isEmpty {
            // 같은 자음 둘(n 제외) → っ
            if rest.count >= 2 {
                let a = rest[rest.startIndex], b = rest[rest.index(after: rest.startIndex)]
                if a == b, a != "n", a.isLetter, !"aiueo".contains(a) {
                    out += "っ"
                    rest = rest.dropFirst()
                    continue
                }
                // nn: 뒤에 모음 · y 가 오면 첫 n 만 ん(konnichiha → こんにちは), 아니면 둘이 ん.
                if a == "n", b == "n" {
                    let third = rest.dropFirst(2).first
                    if let third, "aiueoy".contains(third) {
                        out += "ん"
                        rest = rest.dropFirst()
                    } else if third == nil {
                        break
                    } else {
                        out += "ん"
                        rest = rest.dropFirst(2)
                    }
                    continue
                }
                // n 다음에 모음 · y 가 아닌 자음 → ん
                if a == "n", !"aiueony'".contains(b) {
                    out += "ん"
                    rest = rest.dropFirst()
                    continue
                }
            }
            var matched = false
            for len in stride(from: min(maxKey, rest.count), through: 1, by: -1) {
                let piece = String(rest.prefix(len))
                if let kana = table[piece] {
                    out += kana
                    rest = rest.dropFirst(len)
                    matched = true
                    break
                }
            }
            if matched { continue }
            // 더 칠 수 있는 앞부분이면 기다린다.
            if table.keys.contains(where: { $0.hasPrefix(String(rest)) && $0 != String(rest) }) || rest == "n" {
                break
            }
            // 어느 것도 못 되는 글자는 그대로 내보낸다.
            out.append(rest.removeFirst())
        }
        return (out, String(rest))
    }
}

// MARK: - 중국어(병음 · 주음)

/// 읽기(병음 알파벳 · 주음 기호)를 모아 사전에서 한자 후보를 낸다.
/// 사전이 없으면 읽기 그대로 넣는다.
final class ReadingTypingEngine: TypingEngine {
    private let proxy: TypingInputProxy
    private let dictionary: ConversionDictionary?
    private var text = ComposingText()
    private(set) var reading: String = ""

    init(proxy: TypingInputProxy, dictionary: ConversionDictionary?) {
        self.proxy = proxy
        self.dictionary = dictionary
    }

    var isComposing: Bool { dictionary != nil && !reading.isEmpty }

    var candidates: [String] {
        guard let dictionary, !reading.isEmpty else { return [] }
        return dictionary.candidates(for: reading, limit: 30)
    }

    func input(_ key: String) {
        guard dictionary != nil else {
            proxy.insertText(key)
            return
        }
        guard key.count == 1, let ch = key.first, ch.isLetter || "ˊˇˋ˙".contains(ch) else {
            commit()
            proxy.insertText(key)
            return
        }
        reading += ch.lowercased()
        text.show(reading, on: proxy)
    }

    func backspace() {
        guard !reading.isEmpty else {
            proxy.deleteBackward()
            return
        }
        reading.removeLast()
        text.show(reading, on: proxy)
        if reading.isEmpty { text.forget() }
    }

    /// 고르지 않고 끝내면 첫 후보로, 후보가 없으면 읽기 그대로 둔다.
    func commit() {
        if !candidates.isEmpty {
            selectCandidate(at: 0)
            return
        }
        reading = ""
        text.forget()
    }

    func reset() {
        reading = ""
        text.forget()
    }

    func selectCandidate(at index: Int) {
        let list = candidates
        guard list.indices.contains(index) else { return }
        text.show(list[index], on: proxy)
        dictionary?.noteChosen(list[index], for: reading)
        reading = ""
        text.forget()
    }
}

// MARK: - 변환 사전(일본어 · 중국어)

/// 읽기 → 후보 사전. 앱이 필요할 때 받아 App Group 에 둔 파일을 읽는다.
///
/// ⚠️ 이 단계에서는 자리만 둔다. 사전 파일 형식 · 받는 곳은 `docs/engineering/TYPING_KEYBOARD.md` 의 4단계.
protocol ConversionDictionary: AnyObject {
    func candidates(for reading: String, limit: Int) -> [String]
    /// 사용자가 고른 것. 다음에 같은 읽기에서 앞에 세운다.
    func noteChosen(_ word: String, for reading: String)
}
