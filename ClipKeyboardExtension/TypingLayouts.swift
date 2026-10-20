//
//  TypingLayouts.swift
//  ClipKeyboard
//
//  **자판 언어표.** 언어마다 글자 배열 · 길게 눌러 나오는 글자 · 숫자 층 · 입력 방식을 적는다.
//
//  ⚠️ 키보드(익스텐션)와 앱(설정 화면 · 키보드 탭 미리보기)이 같은 표를 본다. 그래서 여기에는
//     화면을 그리는 코드가 없다. 그리는 일은 `TypingKeyboardView`, 글자를 넣는 일은 `TypingEngines`.
//  ⚠️ 언어는 앱이 켠 언어(`i18n/config.json` 의 enabled)와 같은 23개다. 앱 말을 켜면 자판도 같이 켠다.
//  ⚠️ 배열은 각 나라 iOS 기본 자판을 따른다. 사람 손이 이미 그 자리를 안다.
//

import Foundation

// MARK: - 언어

/// 자판으로 칠 수 있는 언어. rawValue 는 앱 언어 코드와 같다(설정에 그대로 저장한다).
enum TypingLanguage: String, CaseIterable, Identifiable, Codable {
    case ko, en, ja
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case es
    case ptBR = "pt-BR"
    case de, fr, it, ru
    case id, tr, vi, th, pl, nl, sv, da, nb, fi, cs, el

    var id: String { rawValue }

    /// 그 언어 사람이 자기 말을 부르는 이름. 설정 목록과 스페이스 바에 쓴다.
    ///
    /// ⚠️ 번역하지 않는다. 언어 고르기는 어느 나라에서나 그 언어의 제 이름으로 보인다(iOS 설정과 같다).
    ///    한국어 화면에서 "Deutsch" 를 "독일어" 로 바꾸면 독일 사람이 못 찾는다.
    var nativeName: String {
        switch self {
        case .ko: return "한국어"
        case .en: return "English"
        case .ja: return "日本語"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .es: return "Español"
        case .ptBR: return "Português (Brasil)"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .it: return "Italiano"
        case .ru: return "Русский"
        case .id: return "Bahasa Indonesia"
        case .tr: return "Türkçe"
        case .vi: return "Tiếng Việt"
        case .th: return "ไทย"
        case .pl: return "Polski"
        case .nl: return "Nederlands"
        case .sv: return "Svenska"
        case .da: return "Dansk"
        case .nb: return "Norsk bokmål"
        case .fi: return "Suomi"
        case .cs: return "Čeština"
        case .el: return "Ελληνικά"
        }
    }

    /// 언어 키에 붙는 짧은 이름(두세 글자).
    var shortLabel: String {
        switch self {
        case .ko: return "한"
        case .en: return "EN"
        case .ja: return "あ"
        case .zhHans: return "拼"
        case .zhHant: return "注"
        case .ru: return "РУ"
        case .el: return "ΕΛ"
        case .th: return "ไท"
        case .ptBR: return "PT"
        case .nb: return "NO"
        default: return rawValue.uppercased()
        }
    }

    /// 대문자로 바꿀 때 쓰는 말. 터키어의 i → İ 처럼 언어마다 다르다.
    var locale: Locale { Locale(identifier: rawValue) }

    /// 이 언어를 치는 방식.
    var engine: TypingEngineKind {
        switch self {
        case .ko: return .hangul
        case .vi: return .telex
        case .ja: return .kana
        case .zhHans: return .pinyin
        case .zhHant: return .zhuyin
        default: return .direct
        }
    }

    /// 한자 변환 사전을 받아야 제대로 쓰는 언어(일본어 · 중국어). 사전이 없으면 가나 · 병음 · 주음까지만 친다.
    var needsConversionDictionary: Bool {
        switch engine {
        case .kana, .pinyin, .zhuyin: return true
        default: return false
        }
    }

    /// 대소문자가 있는 문자인가. 없으면 Shift 는 '다른 글자 줄' 로만 쓴다(한글 쌍자음 · 태국어 윗줄).
    var hasCase: Bool {
        switch self {
        case .ko, .ja, .zhHans, .zhHant, .th: return false
        default: return true
        }
    }

    /// 처음 켤 언어. **영어 하나**다. 다른 언어는 앱의 설정 ▸ 키보드 ▸ 입력 언어에서 더한다.
    ///
    /// ⚠️ 예전에는 기기 언어에서 골랐다(`deviceLanguages`). 기존 사용자는 그 목록을 한 번 저장해
    ///    그대로 쓴다(`TypingPrefs.keepLegacyDefaultIfNeeded`). 업데이트가 쓰던 자판을 빼앗지 않게.
    static func defaults() -> [TypingLanguage] { [.en] }

    /// 기기 언어 중 우리가 아는 것 + 영어. 예전의 처음 목록이다(기존 사용자를 그대로 두는 데만 쓴다).
    static func deviceLanguages(preferred: [String] = Locale.preferredLanguages) -> [TypingLanguage] {
        var picked: [TypingLanguage] = []
        for code in preferred {
            if let lang = match(code), !picked.contains(lang) { picked.append(lang) }
        }
        if !picked.contains(.en) { picked.append(.en) }
        return picked
    }

    /// "ko-KR", "zh-Hans-CN", "pt-BR", "nb-NO" 같은 코드를 우리 언어로.
    static func match(_ code: String) -> TypingLanguage? {
        if let exact = TypingLanguage(rawValue: code) { return exact }
        let lower = code.lowercased()
        if lower.hasPrefix("zh-hant") || lower.hasPrefix("zh-tw") || lower.hasPrefix("zh-hk") { return .zhHant }
        if lower.hasPrefix("zh") { return .zhHans }
        if lower.hasPrefix("pt") { return .ptBR }
        if lower.hasPrefix("no") || lower.hasPrefix("nn") { return .nb }
        let base = String(lower.split(separator: "-").first ?? "")
        return TypingLanguage(rawValue: base)
    }
}

/// 글자를 넣는 방식.
enum TypingEngineKind: Equatable {
    /// 누른 글자를 그대로 넣는다(라틴 · 키릴 · 그리스 · 태국 문자).
    case direct
    /// 한글 자모를 음절로 모은다(두벌식 · 천지인).
    case hangul
    /// 베트남어 Telex: aa → â, s → 성조 같은 규칙으로 글자를 바꾼다.
    case telex
    /// 일본어: 로마자를 가나로, 사전이 있으면 한자 후보까지.
    case kana
    /// 중국어 간체: 병음을 치고 사전에서 한자 후보를 고른다.
    case pinyin
    /// 중국어 번체: 주음(ㄅㄆㄇ)을 치고 사전에서 한자 후보를 고른다.
    case zhuyin
}

// MARK: - 배열

/// 한 언어의 글자 판. 줄마다 키가 놓인다.
struct TypingLayout {
    /// 글자 줄. 보통 셋, 태국어는 넷.
    let rows: [[String]]
    /// Shift 를 눌렀을 때의 줄. nil 이면 `rows` 를 그 언어 규칙으로 대문자로 바꾼다.
    let shiftedRows: [[String]]?
    /// 둘째 줄을 안쪽으로 들이는가(QWERTY 처럼 9개 줄). 키가 꽉 찬 줄은 들이지 않는다.
    let indentsMiddleRow: Bool

    init(rows: [[String]], shiftedRows: [[String]]? = nil, indentsMiddleRow: Bool? = nil) {
        self.rows = rows
        self.shiftedRows = shiftedRows
        if let indentsMiddleRow {
            self.indentsMiddleRow = indentsMiddleRow
        } else if rows.count >= 2 {
            self.indentsMiddleRow = rows[1].count < rows[0].count
        } else {
            self.indentsMiddleRow = false
        }
    }

    /// 지금 보일 줄.
    func rows(shifted: Bool, locale: Locale, hasCase: Bool) -> [[String]] {
        guard shifted else { return rows }
        if let shiftedRows { return shiftedRows }
        guard hasCase else { return rows }
        return rows.map { $0.map { $0.uppercased(with: locale) } }
    }
}

extension TypingLanguage {

    /// 글자 판. 각 나라 iOS 기본 자판 배열이다.
    var layout: TypingLayout {
        switch self {
        case .en, .id, .nl, .it, .ptBR, .vi, .ja, .zhHans:
            // 일본어(로마자) · 중국어(병음)도 QWERTY 로 친다. 가나 · 한자로 바꾸는 일은 엔진 몫이다.
            return TypingLayout(rows: TypingLayoutBook.qwerty)
        case .es:
            return TypingLayout(rows: [
                ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ñ"],
                ["z", "x", "c", "v", "b", "n", "m"],
            ])
        case .de:
            return TypingLayout(rows: [
                ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p", "ü"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ö", "ä"],
                ["y", "x", "c", "v", "b", "n", "m"],
            ])
        case .fr:
            return TypingLayout(rows: [
                ["a", "z", "e", "r", "t", "y", "u", "i", "o", "p"],
                ["q", "s", "d", "f", "g", "h", "j", "k", "l", "m"],
                ["w", "x", "c", "v", "b", "n", "'"],
            ])
        case .sv, .fi:
            return TypingLayout(rows: [
                ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "å"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ö", "ä"],
                ["z", "x", "c", "v", "b", "n", "m"],
            ])
        case .da:
            return TypingLayout(rows: [
                ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "å"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l", "æ", "ø"],
                ["z", "x", "c", "v", "b", "n", "m"],
            ])
        case .nb:
            return TypingLayout(rows: [
                ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "å"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ø", "æ"],
                ["z", "x", "c", "v", "b", "n", "m"],
            ])
        case .tr:
            // 터키어 Q 배열. 점 없는 ı 와 점 있는 i 가 따로 있다. 대문자는 터키어 규칙(i → İ, ı → I).
            return TypingLayout(rows: [
                ["q", "w", "e", "r", "t", "y", "u", "ı", "o", "p", "ğ", "ü"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ş", "i"],
                ["z", "x", "c", "v", "b", "n", "m", "ö", "ç"],
            ])
        case .pl:
            // 폴란드 사람은 QWERTY 를 쓰고 ą ę ł 같은 글자는 길게 눌러 친다(iOS 와 같다).
            return TypingLayout(rows: TypingLayoutBook.qwerty)
        case .cs:
            return TypingLayout(rows: [
                ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p", "ú"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ů"],
                ["y", "x", "c", "v", "b", "n", "m"],
            ])
        case .ru:
            return TypingLayout(rows: [
                ["й", "ц", "у", "к", "е", "н", "г", "ш", "щ", "з", "х"],
                ["ф", "ы", "в", "а", "п", "р", "о", "л", "д", "ж", "э"],
                ["я", "ч", "с", "м", "и", "т", "ь", "б", "ю"],
            ])
        case .el:
            return TypingLayout(rows: [
                ["ς", "ε", "ρ", "τ", "υ", "θ", "ι", "ο", "π"],
                ["α", "σ", "δ", "φ", "γ", "η", "ξ", "κ", "λ"],
                ["ζ", "χ", "ψ", "ω", "β", "ν", "μ"],
            ], indentsMiddleRow: false)
        case .th:
            // 태국어 Kedmanee. 글자가 많아 넷째 줄까지 쓰고, Shift 는 대문자가 아니라 **다른 글자 판**이다.
            return TypingLayout(
                rows: [
                    ["ๅ", "/", "-", "ภ", "ถ", "ุ", "ึ", "ค", "ต", "จ", "ข", "ช"],
                    ["ๆ", "ไ", "ำ", "พ", "ะ", "ั", "ี", "ร", "น", "ย", "บ", "ล"],
                    ["ฟ", "ห", "ก", "ด", "เ", "้", "่", "า", "ส", "ว", "ง"],
                    ["ผ", "ป", "แ", "อ", "ิ", "ื", "ท", "ม", "ใ", "ฝ"],
                ],
                shiftedRows: [
                    ["+", "๑", "๒", "๓", "๔", "ู", "฿", "๕", "๖", "๗", "๘", "๙"],
                    ["๐", "\"", "ฎ", "ฑ", "ธ", "ํ", "๊", "ณ", "ฯ", "ญ", "ฐ", ","],
                    ["ฤ", "ฆ", "ฏ", "โ", "ฌ", "็", "๋", "ษ", "ศ", "ซ", "."],
                    ["(", ")", "ฉ", "ฮ", "ฺ", "์", "?", "ฒ", "ฬ", "ฦ"],
                ],
                indentsMiddleRow: false)
        case .ko:
            return TypingLayout(
                rows: TypingLayoutBook.dubeolsik,
                shiftedRows: TypingLayoutBook.dubeolsikShifted)
        case .zhHant:
            // 주음 배열(대만 iOS 와 같은 4줄). 성조 ˊ ˇ ˋ ˙ 는 숫자 자리에 있다.
            return TypingLayout(rows: [
                ["ㄅ", "ㄉ", "ˇ", "ˋ", "ㄓ", "ˊ", "˙", "ㄚ", "ㄞ", "ㄢ", "ㄦ"],
                ["ㄆ", "ㄊ", "ㄍ", "ㄐ", "ㄔ", "ㄗ", "ㄧ", "ㄛ", "ㄟ", "ㄣ"],
                ["ㄇ", "ㄋ", "ㄎ", "ㄑ", "ㄕ", "ㄘ", "ㄨ", "ㄜ", "ㄠ", "ㄤ"],
                ["ㄈ", "ㄌ", "ㄏ", "ㄒ", "ㄖ", "ㄙ", "ㄩ", "ㄝ", "ㄡ", "ㄥ"],
            ], indentsMiddleRow: false)
        }
    }

    /// 길게 누르면 나오는 글자. 키 하나에 여럿. 첫 칸이 손가락 바로 위에 선다.
    func alternates(for key: String) -> [String] {
        let lower = key.lowercased(with: locale)
        let isUpper = hasCase && key != lower
        guard let list = alternateTable[lower], !list.isEmpty else { return [] }
        return isUpper ? list.map { $0.uppercased(with: locale) } : list
    }

    /// 언어마다 자주 쓰는 순서로 앞에 놓는다. 나머지는 공통 라틴 표에서.
    private var alternateTable: [String: [String]] {
        switch self {
        case .ko, .ja, .zhHans, .zhHant, .th:
            return [:]
        case .ru:
            return ["е": ["ё"], "ь": ["ъ"]]
        case .el:
            return ["α": ["ά"], "ε": ["έ"], "η": ["ή"], "ι": ["ί", "ϊ", "ΐ"],
                    "ο": ["ό"], "υ": ["ύ", "ϋ", "ΰ"], "ω": ["ώ"]]
        case .vi:
            // 베트남어는 Telex 로 치지만, 길게 눌러 바로 고를 수도 있게 둔다.
            return ["a": ["ă", "â", "á", "à", "ả", "ã", "ạ"], "e": ["ê", "é", "è", "ẻ", "ẽ", "ẹ"],
                    "o": ["ô", "ơ", "ó", "ò", "ỏ", "õ", "ọ"], "u": ["ư", "ú", "ù", "ủ", "ũ", "ụ"],
                    "i": ["í", "ì", "ỉ", "ĩ", "ị"], "y": ["ý", "ỳ", "ỷ", "ỹ", "ỵ"], "d": ["đ"]]
        case .pl:
            return TypingLayoutBook.latinAlternates.merging(
                ["a": ["ą"], "c": ["ć"], "e": ["ę"], "l": ["ł"], "n": ["ń"],
                 "o": ["ó"], "s": ["ś"], "z": ["ż", "ź"]]) { common, mine in Self.front(mine, common) }
        case .cs:
            return TypingLayoutBook.latinAlternates.merging(
                ["a": ["á"], "c": ["č"], "d": ["ď"], "e": ["ě", "é"], "i": ["í"], "n": ["ň"],
                 "o": ["ó"], "r": ["ř"], "s": ["š"], "t": ["ť"], "u": ["ú", "ů"], "y": ["ý"], "z": ["ž"]]) { common, mine in Self.front(mine, common) }
        case .tr:
            return ["c": ["ç"], "g": ["ğ"], "o": ["ö"], "s": ["ş"], "u": ["ü"], "a": ["â"]]
        case .de:
            return TypingLayoutBook.latinAlternates.merging(["s": ["ß"]]) { common, mine in Self.front(mine, common) }
        case .es:
            return TypingLayoutBook.latinAlternates.merging(
                ["a": ["á"], "e": ["é"], "i": ["í"], "o": ["ó"], "u": ["ú", "ü"], "n": ["ñ"]]) { common, mine in Self.front(mine, common) }
        case .ptBR:
            return TypingLayoutBook.latinAlternates.merging(
                ["a": ["á", "ã", "â", "à"], "c": ["ç"], "e": ["é", "ê"], "i": ["í"],
                 "o": ["ó", "õ", "ô"], "u": ["ú"]]) { common, mine in Self.front(mine, common) }
        case .fr:
            return TypingLayoutBook.latinAlternates.merging(
                ["a": ["à", "â", "æ"], "c": ["ç"], "e": ["é", "è", "ê", "ë"], "i": ["î", "ï"],
                 "o": ["ô", "œ"], "u": ["ù", "û", "ü"], "y": ["ÿ"]]) { common, mine in Self.front(mine, common) }
        case .it:
            return TypingLayoutBook.latinAlternates.merging(
                ["a": ["à"], "e": ["è", "é"], "i": ["ì"], "o": ["ò"], "u": ["ù"]]) { common, mine in Self.front(mine, common) }
        default:
            return TypingLayoutBook.latinAlternates
        }
    }

    /// 그 언어 글자를 앞에, 공통 표의 나머지를 뒤에. 겹치는 것은 한 번만.
    /// (`merging` 의 닫힘은 (원래 값, 새 값) 순서로 받는다. 원래 값이 공통 표다.)
    private static func front(_ mine: [String], _ common: [String]) -> [String] {
        mine + common.filter { !mine.contains($0) }
    }

    /// 숫자 층 둘째 줄의 돈 기호. 그 나라 돈을 앞에 둔다.
    var currencySymbol: String {
        switch self {
        case .ko: return "₩"
        case .ja, .zhHans: return "¥"
        case .zhHant: return "$"
        case .ru: return "₽"
        case .th: return "฿"
        case .vi: return "₫"
        case .tr: return "₺"
        case .pl: return "zł"
        case .cs: return "Kč"
        case .id: return "Rp"
        case .ptBR: return "R$"
        case .sv, .da, .nb: return "kr"
        case .de, .fr, .it, .es, .nl, .fi, .el: return "€"
        case .en: return "$"
        }
    }
}

// MARK: - 공통 판

enum TypingLayoutBook {
    static let qwerty: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
    ]

    static let dubeolsik: [[String]] = [
        ["ㅂ", "ㅈ", "ㄷ", "ㄱ", "ㅅ", "ㅛ", "ㅕ", "ㅑ", "ㅐ", "ㅔ"],
        ["ㅁ", "ㄴ", "ㅇ", "ㄹ", "ㅎ", "ㅗ", "ㅓ", "ㅏ", "ㅣ"],
        ["ㅋ", "ㅌ", "ㅊ", "ㅍ", "ㅠ", "ㅜ", "ㅡ"],
    ]

    /// 두벌식 Shift: 쌍자음과 ㅒ ㅖ. 나머지는 그대로.
    static let dubeolsikShifted: [[String]] = [
        ["ㅃ", "ㅉ", "ㄸ", "ㄲ", "ㅆ", "ㅛ", "ㅕ", "ㅑ", "ㅒ", "ㅖ"],
        ["ㅁ", "ㄴ", "ㅇ", "ㄹ", "ㅎ", "ㅗ", "ㅓ", "ㅏ", "ㅣ"],
        ["ㅋ", "ㅌ", "ㅊ", "ㅍ", "ㅠ", "ㅜ", "ㅡ"],
    ]

    /// 라틴 문자 공통의 길게 누르기(iOS 영어 자판과 같은 묶음).
    static let latinAlternates: [String: [String]] = [
        "a": ["à", "á", "â", "ä", "æ", "ã", "å", "ā"],
        "c": ["ç", "ć", "č"],
        "e": ["è", "é", "ê", "ë", "ē", "ė", "ę"],
        "i": ["î", "ï", "í", "ī", "į", "ì"],
        "l": ["ł"],
        "n": ["ñ", "ń"],
        "o": ["ô", "ö", "ò", "ó", "œ", "ø", "ō", "õ"],
        "s": ["ß", "ś", "š"],
        "u": ["û", "ü", "ù", "ú", "ū"],
        "y": ["ÿ"],
        "z": ["ž", "ź", "ż"],
    ]

    /// 숫자 층.
    static func numberRows(currency: String) -> [[String]] {
        [
            ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
            ["-", "/", ":", ";", "(", ")", currency, "&", "@", "\""],
            [".", ",", "?", "!", "'"],
        ]
    }

    /// 기호 층.
    static let symbolRows: [[String]] = [
        ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
        ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"],
        [".", ",", "?", "!", "'"],
    ]
}
