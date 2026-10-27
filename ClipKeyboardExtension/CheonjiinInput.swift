//
//  CheonjiinInput.swift
//  ClipKeyboardExtension
//
//  천지인 (3x3+) 입력 처리. 자음 multi-tap 사이클 + 모음 stroke 결합.
//  HangulComposer를 통해 syllable 합성.
//

import Foundation

final class CheonjiinInput {

    /// 강한 참조 - TypingKeyboardView가 @State로 hangulComposer를 보유하므로 cycle 없음.
    var composer: HangulComposer?

    // MARK: - State

    /// 자음 돌림. 같은 키를 이어 누르면 ㄱ → ㅋ → ㄲ. 시간이 아니라 **다른 키**(모음 · 다른 자음 · →)가 끊는다.
    ///
    /// ⚠️ 예전에는 0.5초가 지나면 끊었다. 천천히 치면 ㅋ 대신 ㄱㄱ 이 되고, 빨리 치면 맞아서
    ///    같은 손놀림이 속도에 따라 다른 글자가 됐다. 기본 10키처럼 끊는 것은 → 키의 몫이다.
    private var lastConsonantKey: String?
    private var consonantTapIndex: Int = 0

    /// 지금 짓는 모음이 어디에 보이는가.
    private enum Place {
        /// 아직 모음이 못 된 점(ㆍ · ᆢ). 입력칸에 그 글자 그대로 보인다.
        case dots
        /// 조합기의 음절 안(오).
        case medial
        /// 초성 없이 홀로(ㅗ).
        case raw
    }

    /// 지금 짓는 모음. 모음 키가 아닌 키를 누르면 비운다.
    private var vowel: (char: Character, place: Place)?
    /// 이 모음이 되기까지 거쳐 온 모음들. 지우기가 획 하나씩 되돌린다(야 → 아 → 이).
    private var history: [Character] = []

    // MARK: - Tables

    /// 자음 키 → cycle 자모 시퀀스
    private static let consonantCycles: [String: [Character]] = [
        "ㄱㅋ": ["ㄱ", "ㅋ", "ㄲ"],
        "ㄴㄹ": ["ㄴ", "ㄹ"],
        "ㄷㅌ": ["ㄷ", "ㅌ", "ㄸ"],
        "ㅂㅍ": ["ㅂ", "ㅍ", "ㅃ"],
        "ㅅㅎ": ["ㅅ", "ㅎ", "ㅆ"],
        "ㅈㅊ": ["ㅈ", "ㅊ", "ㅉ"],
        "ㅇㅁ": ["ㅇ", "ㅁ"]
    ]

    /// 지금 모음 + 획 → 새 모음. **획을 누른 순서가 아니라 지금 보이는 모음**에서 간다.
    ///
    /// ⚠️ 예전에는 획 순서를 통째로 외운 표(ㆍㆍㅡ = ㅛ)를 0.6초 안에 친 것만 읽었다. 그래서
    ///    "오" 를 치고 ㆍ 를 더하면(ㆍㅡㆍ) 표에 없어 요가 되지 않았고, 조금만 늦어도 모음이 끊겼다
    ///    (2026-10 사용자 신고). 기본 10키는 보이는 모음에 획을 더한다: 오 + ㆍ = 요.
    private static let transitions: [Character: [Character: Character]] = [
        "ㆍ": ["ㆍ": "ᆢ", "ㅣ": "ㅓ", "ㅡ": "ㅗ"],
        "ᆢ": ["ㆍ": "ㆍ", "ㅣ": "ㅕ", "ㅡ": "ㅛ"],
        "ㅣ": ["ㆍ": "ㅏ"],
        "ㅏ": ["ㆍ": "ㅑ", "ㅣ": "ㅐ"],
        "ㅑ": ["ㅣ": "ㅒ"],
        "ㅓ": ["ㅣ": "ㅔ"],
        "ㅕ": ["ㅣ": "ㅖ"],
        "ㅡ": ["ㆍ": "ㅜ", "ㅣ": "ㅢ"],
        "ㅜ": ["ㆍ": "ㅠ", "ㅣ": "ㅟ"],
        "ㅠ": ["ㅣ": "ㅝ"],
        "ㅝ": ["ㅣ": "ㅞ"],
        "ㅗ": ["ㆍ": "ㅛ", "ㅣ": "ㅚ"],
        "ㅚ": ["ㆍ": "ㅘ"],
        "ㅘ": ["ㅣ": "ㅙ"]
    ]

    /// 아직 모음이 아닌 점.
    private static func isDots(_ ch: Character) -> Bool { ch == "ㆍ" || ch == "ᆢ" }

    // MARK: - Public API

    /// → 키. 기본 10키의 '다음 글자' 키와 같다.
    static let advanceKey = "→"

    /// 꾹 누르면 들어갈 숫자. 전화 자판의 같은 자리 숫자다(ㅣ ㆍ ㅡ 가 1 2 3, ㅇㅁ 이 0).
    static func digit(for key: String) -> String? {
        ["ㅣ": "1", "ㆍ": "2", "ㅡ": "3",
         "ㄱㅋ": "4", "ㄴㄹ": "5", "ㄷㅌ": "6",
         "ㅂㅍ": "7", "ㅅㅎ": "8", "ㅈㅊ": "9",
         "ㅇㅁ": "0"][key]
    }

    /// 천지인 키인가(자음 묶음 키 · ㅣ ㆍ ㅡ). 아니면 자판이 그대로 넣는다.
    static func handles(_ key: String) -> Bool {
        consonantCycles[key] != nil || key == "ㅣ" || key == "ㆍ" || key == "ㅡ"
    }

    /// → 키: 자음 돌림을 끊는다. 같은 자음 키를 다시 누르면 다음 자모(ㅋ)가 아니라 새 자음(ㄱ)이 된다.
    /// - Returns: 끊을 돌림이 있었으면 true. 없으면 부르는 쪽이 커서를 한 칸 옮긴다.
    @discardableResult
    func advance() -> Bool {
        guard lastConsonantKey != nil else { return false }
        lastConsonantKey = nil
        consonantTapIndex = 0
        return true
    }

    /// 천지인 키 탭. consonantCycles에 있으면 자음 multi-tap, 그 외엔 모음 stroke.
    func tap(_ key: String) {
        if let cycle = Self.consonantCycles[key] {
            handleConsonant(key: key, cycle: cycle)
        } else if key == "ㅣ" || key == "ㆍ" || key == "ㅡ" {
            handleVowelStroke(Character(key))
        }
    }

    /// 짓던 글자를 마친다. 모음이 못 된 점(ㆍ)은 버린다.
    func commit() {
        dropDots()
        composer?.commit()
        reset()
    }

    /// 지우기: 짓던 모음은 획 하나씩(야 → 아), 자음 돌림 중이면 그 자음째, 아니면 조합기에 맡긴다.
    func backspace() {
        if let current = vowel {
            if let previous = history.popLast() {
                show(previous, replacing: current)
            } else {
                show(nil, replacing: current)
                vowel = nil
            }
            return
        }
        lastConsonantKey = nil
        consonantTapIndex = 0
        composer?.backspace()
    }

    func reset() {
        lastConsonantKey = nil
        consonantTapIndex = 0
        vowel = nil
        history.removeAll()
    }

    // MARK: - Handlers

    private func handleConsonant(key: String, cycle: [Character]) {
        // 모음이 못 된 점은 버린다. 다 된 모음은 음절에 남는다.
        dropDots()
        vowel = nil
        history.removeAll()

        if lastConsonantKey == key {
            // 같은 키를 다시 → 다음 자모
            consonantTapIndex = (consonantTapIndex + 1) % cycle.count
            composer?.backspace()
            composer?.input(cycle[consonantTapIndex])
        } else {
            consonantTapIndex = 0
            composer?.input(cycle[0])
        }
        lastConsonantKey = key
    }

    private func handleVowelStroke(_ stroke: Character) {
        lastConsonantKey = nil
        consonantTapIndex = 0

        // 받침 없는 음절의 모음은 방금 친 것이 아니어도 이어 짓는다(받침을 지운 뒤 가 + ㆍ = 갸).
        let current = vowel ?? composer?.openMedial.map { ($0, Place.medial) }
        if let current, let next = Self.transitions[current.char]?[stroke] {
            history.append(current.char)
            show(next, replacing: current)
        } else {
            history.removeAll()
            vowel = nil
            show(stroke, replacing: nil)
        }
    }

    /// 모음 `next` 를 `old` 자리에 보인다. nil 이면 지우기만 한다.
    private func show(_ next: Character?, replacing old: (char: Character, place: Place)?) {
        // 받침 없는 음절 안의 모음은 그 자리에서 바꾼다. 음절이 깨지지 않는다.
        if let old, old.place == .medial, let next, !Self.isDots(next) {
            composer?.replaceOpenMedial(with: next)
            vowel = (next, .medial)
            return
        }
        if let old {
            switch old.place {
            case .medial: composer?.replaceOpenMedial(with: nil)
            case .dots, .raw: composer?.proxy?.deleteBackward()
            }
        }
        guard let next else { return }
        if Self.isDots(next) {
            composer?.proxy?.insertText(String(next))
            vowel = (next, .dots)
        } else {
            composer?.input(next)
            vowel = (next, composer?.openMedial == next ? .medial : .raw)
        }
    }

    /// 모음이 못 된 점을 입력칸에서 지운다.
    private func dropDots() {
        guard let current = vowel, current.place == .dots else { return }
        composer?.proxy?.deleteBackward()
        vowel = nil
        history.removeAll()
    }
}
