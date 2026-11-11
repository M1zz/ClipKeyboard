//
//  KanaFlickInput.swift
//  ClipKeyboardExtension
//
//  **일본어 플릭 자판의 배열.** 키 열둘과, 누른 채 밀면 들어가는 가나를 적어 둔 표다.
//
//  기본 키보드의 「日本語 - かな」(플릭만) 와 같다. 키를 누르면 그 행의 あ단, 밀면 い(←) う(↑) え(→) お(↓) 단.
//  글자를 넣는 일은 `KanaTypingEngine` 이 한다(로마자 자판과 같은 엔진이라 한자 후보도 같이 쓴다).
//  손가락을 받는 일은 `TypingKeyboardView` 의 밀어 넣기 키가 한다. 여기는 표와 산수뿐이다.
//
//  ⚠️ 같은 키를 거듭 눌러 다음 단으로 넘기는 방식(あ あ = い)은 받지 않는다. 플릭으로 치는 사람에게는
//     같은 글자를 이어 칠 때(ああ · かか)마다 걸리는 방식이라, 기본 키보드에서도 끄고 쓰는 설정이다.
//

import Foundation

/// 일본어 자판 모양. 설정(`DefaultsKey.keyboardJapaneseLayout`)에 rawValue 로 남는다.
enum JapaneseTypingLayout: String, CaseIterable {
    case romaji, flick
}

enum KanaFlickInput {

    // MARK: - 배열

    /// 가나 키. 위에서 아래로, 한 줄에 셋. 마지막 줄 양옆은 `modifierKey` 와 `punctuationKey` 다.
    static let rows: [[String]] = [
        ["あ", "か", "さ"],
        ["た", "な", "は"],
        ["ま", "や", "ら"],
        [modifierKey, "わ", punctuationKey]
    ]

    /// 탁점 · 반탁점 · 작은 글자 키. 바로 앞 가나를 돌린다(は → ば → ぱ → は).
    static let modifierKey = "小゛゜"
    /// 문장 부호 키. 누르면 、 밀면 。 ？ ！
    static let punctuationKey = "、"

    /// 키를 누른 채 밀면 들어가는 글자. 기본 키보드와 같은 자리다.
    static func flicks(for key: String) -> [CheonjiinInput.Flick: String] {
        if let row = columns[key] {
            return [.left: row[0], .up: row[1], .right: row[2], .down: row[3]]
        }
        switch key {
        case "や": return [.left: "「", .up: "ゆ", .right: "」", .down: "よ"]
        case "わ": return [.left: "を", .up: "ん", .right: "ー"]
        case punctuationKey: return [.left: "。", .up: "？", .right: "！"]
        default: return [:]
        }
    }

    /// 다섯 단이 다 있는 행: い · う · え · お 단(← ↑ → ↓ 순서).
    private static let columns: [String: [String]] = [
        "あ": ["い", "う", "え", "お"],
        "か": ["き", "く", "け", "こ"],
        "さ": ["し", "す", "せ", "そ"],
        "た": ["ち", "つ", "て", "と"],
        "な": ["に", "ぬ", "ね", "の"],
        "は": ["ひ", "ふ", "へ", "ほ"],
        "ま": ["み", "む", "め", "も"],
        "ら": ["り", "る", "れ", "ろ"]
    ]

    // MARK: - 탁점 · 작은 글자

    /// 돌림 묶음. 한 번 누를 때마다 묶음 안에서 다음 글자로 간다(끝이면 처음으로).
    /// 순서는 기본 키보드와 같다: つ → っ → づ, は → ば → ぱ.
    private static let cycles: [[Character]] = [
        "あぁ", "いぃ", "うぅゔ", "えぇ", "おぉ",
        "かが", "きぎ", "くぐ", "けげ", "こご",
        "さざ", "しじ", "すず", "せぜ", "そぞ",
        "ただ", "ちぢ", "つっづ", "てで", "とど",
        "はばぱ", "ひびぴ", "ふぶぷ", "へべぺ", "ほぼぽ",
        "やゃ", "ゆゅ", "よょ", "わゎ"
    ].map(Array.init)

    private static let nextInCycle: [Character: Character] = {
        var next: [Character: Character] = [:]
        for cycle in cycles {
            for (i, ch) in cycle.enumerated() { next[ch] = cycle[(i + 1) % cycle.count] }
        }
        return next
    }()

    /// 이 가나의 다음 모양. 바꿀 것이 없는 글자(な · ん · ー)면 nil.
    static func modified(_ kana: Character) -> Character? { nextInCycle[kana] }

    // MARK: - 엔진이 묻는 것

    /// 엔진이 읽기(가나)에 그대로 붙일 글자인가. 히라가나와 긴소리표.
    static func isKana(_ key: String) -> Bool {
        !key.isEmpty && key.unicodeScalars.allSatisfy { (0x3041...0x309F).contains($0.value) || $0.value == 0x30FC }
    }
}
