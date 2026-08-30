//
//  TemplateVariableProcessor.swift
//  ClipKeyboard
//
//  Template auto-variable substitution. Shared between main app, keyboard
//  extension, and combo flow. Replaces scattered `processTemplateVariables`
//  duplicates that previously lived inline in every caller.
//
//  v4.0: Added timezone / currency / greeting_time and English aliases for
//  existing Korean tokens so global users get natural variables out of the box.
//

import Foundation

// MARK: - 토큰 모양 (v5.0.6)

/// 서식 한 가지를 만드는 법. `DateFormatter` 에 무엇을 얹을지만 말한다.
enum TokenFormatRecipe: Equatable {
    /// 패턴 문자열을 그대로 (`"yyyy-MM-dd"`).
    case pattern(String)
    /// 시스템이 언어에 맞춰 만드는 모양 (`.long` 이면 "August 31, 2026" · "2026년 8월 31일").
    case style(DateFormatter.Style)
    /// **언어·지역이 정한다.** 목록의 첫 줄이자 기본값.
    case automatic
}

/// `{날짜}` · `{시간}` 처럼 **모양을 고를 수 있는 토큰**의 설정.
///
/// 왜 protocol 인가: 날짜와 시각이 하는 일이 똑같다. 고른 값을 App Group 에 적고,
/// 안 골랐으면 언어·지역에 맞춰 정하고, 고르는 화면에는 지금 값을 그려서 보여준다.
/// 두 벌로 적어 두면 한쪽만 고치는 날이 반드시 온다(이 저장소가 여러 번 겪은 일이다).
///
/// ⚠️ 앱과 키보드 익스텐션이 **같은 값을 읽어야 한다.** 그래서 App Group 에 적는다.
///    표준 UserDefaults 에 적으면 키보드는 영영 못 본다.
protocol TokenFormat: RawRepresentable, CaseIterable, Identifiable, Hashable where RawValue == String {

    /// App Group 에 적을 자리.
    static var storageKey: String { get }

    /// 고른 적이 없을 때 쓰는 보기. 언제나 `.automatic` 에 해당하는 것.
    static var automaticCase: Self { get }

    /// 한국어·중국어·일본어에서 **지금까지 넣어 온 모양.**
    ///
    /// ⚠️ 여기를 바꾸면 쓰던 사람의 결과가 어느 날 갑자기 달라진다. 이 기능을 만든 요청은
    ///    "미국이 어색하다"였지 "한국을 바꿔 달라"가 아니었다.
    static var cjkPattern: String { get }

    /// 그 지역이 쓰는 모양을 시스템에 물을 때 넘기는 뼈대.
    /// (`"yyyyMMdd"` → 미국 `MM/dd/yyyy` · 영국 `dd/MM/yyyy`, `"jmm"` → 미국 `h:mm a`)
    static var localeSkeleton: String { get }

    /// 이 보기를 만드는 법.
    var recipe: TokenFormatRecipe { get }
}

extension TokenFormat {

    var id: String { rawValue }

    // MARK: - 저장

    /// 지금 고른 모양. 고른 적이 없거나 알 수 없는 값이면 자동.
    static var current: Self {
        get {
            AppGroup.defaults?.string(forKey: storageKey).flatMap(Self.init(rawValue:)) ?? automaticCase
        }
        set {
            AppGroup.defaults?.set(newValue.rawValue, forKey: storageKey)
        }
    }

    // MARK: - 서식

    /// 이 모양의 글자로.
    func string(from date: Date, locale: Locale = TokenFormatLocale.current) -> String {
        Self.formatter(for: recipe, locale: locale).string(from: date)
    }

    /// 글자를 다시 날짜로. 못 읽으면 nil.
    ///
    /// ⚠️ **모든 모양을 다 시도한다.** 사람이 날짜를 고른 뒤에 형식을 바꿀 수 있고, 그때
    ///    예전 모양으로 저장된 글자를 못 읽으면 고른 값이 조용히 오늘로 되돌아간다.
    static func date(from text: String, locale: Locale = TokenFormatLocale.current) -> Date? {
        let ordered = [current] + allCases.filter { $0 != current }
        for format in ordered {
            if let date = formatter(for: format.recipe, locale: locale).date(from: text) { return date }
        }
        return nil
    }

    /// `.automatic` 이 실제로 쓰는 서식 패턴.
    ///
    /// 나라 목록을 손으로 들고 있지 않고 시스템에 묻는다. 손으로 적어 두면 빠뜨린 나라가
    /// 반드시 생긴다.
    static func automaticPattern(for locale: Locale = TokenFormatLocale.current) -> String {
        if let code = locale.language.languageCode?.identifier,
           TokenFormatLocale.keepsLegacyPattern(code) {
            return cjkPattern
        }
        return DateFormatter.dateFormat(fromTemplate: localeSkeleton, options: 0, locale: locale)
            ?? cjkPattern
    }

    private static func formatter(for recipe: TokenFormatRecipe, locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        switch recipe {
        case .pattern(let pattern):
            formatter.dateFormat = pattern
        case .style(let style):
            formatter.dateStyle = style
            formatter.timeStyle = .none
        case .automatic:
            formatter.dateFormat = automaticPattern(for: locale)
        }
        return formatter
    }

    // MARK: - 고르는 화면

    /// 목록에 세울 이름. **지금 값을 그 모양으로 그려서** 보여준다.
    /// 패턴 글자("MM/DD/YYYY")는 개발자만 읽는다. `08/31/2026` 은 누구나 읽는다.
    func sampleText(at reference: Date = Date()) -> String {
        let rendered = string(from: reference)
        guard recipe == .automatic else { return rendered }
        return String(format: NSLocalizedString("자동 (%@)", comment: "Date format: automatic option, %@ is today rendered"),
                      rendered)
    }

    var sampleText: String { sampleText() }
}

/// 서식을 고를 때 쓰는 로케일과, 예전 모양을 지켜야 하는 언어.
enum TokenFormatLocale {

    /// 언어는 **앱에서 고른 언어**, 지역은 **기기 지역**을 쓴다.
    ///
    /// 미국에 살면서 한국어로 쓰는 사람과 한국에 살면서 영어로 쓰는 사람이 각각
    /// 자기에게 맞는 것을 받는다.
    static var current: Locale {
        guard let code = AppLanguage.current.bundleCode else { return .current }
        let language = code.replacingOccurrences(of: "-", with: "_")
        guard let region = Locale.current.region?.identifier else {
            return Locale(identifier: language)
        }
        return Locale(identifier: "\(language)_\(region)")
    }

    /// 이 언어는 예전 모양을 그대로 둔다(`TokenFormat.cjkPattern`).
    static func keepsLegacyPattern(_ languageCode: String) -> Bool {
        ["ko", "zh", "ja"].contains(languageCode)
    }
}

// MARK: - 날짜

/// `{날짜}` / `{date}` 를 어떤 모양으로 넣을지.
///
/// 왜 생겼나: 미국 사용자에게서 이런 이야기가 왔다.
///
/// > Can the Date variable be changed to display in different formats?
/// > We use Month-Day-Year in the US.
///
/// 그때까지 `{날짜}` 는 언제 어디서나 `yyyy-MM-dd` 였다. 한국에서는 그게 자연스럽지만
/// 미국에서는 아무도 그렇게 안 쓴다. 날짜를 넣어 주는 기능인데 **그 나라 모양이 아니면
/// 넣어 주나 마나**라, 손으로 고쳐 쓰게 된다.
enum DateTokenFormat: String, TokenFormat {
    /// 언어·지역에 맞춰 고른다. **기본값.**
    case automatic
    /// 2026-08-31
    case isoDash
    /// 08/31/2026
    case monthDayYear
    /// 31/08/2026
    case dayMonthYear
    /// 2026. 08. 31.
    case yearMonthDayDot
    /// August 31, 2026 · 2026년 8월 31일
    case long

    static let storageKey = DefaultsKey.templateDateFormat
    static let automaticCase = DateTokenFormat.automatic
    static let cjkPattern = "yyyy-MM-dd"
    /// 네 자리 연도를 달라고 명시한다. 그냥 short 로 받으면 나라에 따라 두 자리가 온다.
    static let localeSkeleton = "yyyyMMdd"

    var recipe: TokenFormatRecipe {
        switch self {
        case .automatic: return .automatic
        case .isoDash: return .pattern("yyyy-MM-dd")
        case .monthDayYear: return .pattern("MM/dd/yyyy")
        case .dayMonthYear: return .pattern("dd/MM/yyyy")
        case .yearMonthDayDot: return .pattern("yyyy. MM. dd.")
        case .long: return .style(.long)
        }
    }
}

// MARK: - 시각

/// `{시간}` / `{time}` 을 어떤 모양으로 넣을지.
///
/// 날짜와 같은 이야기다(`DateTokenFormat` 머리말 참고). 24시간제 `HH:mm:ss` 는
/// 한국에서는 읽히지만 미국에서는 아무도 그렇게 안 적는다.
enum TimeTokenFormat: String, TokenFormat {
    /// 언어·지역에 맞춰 고른다. **기본값.**
    case automatic
    /// 21:57
    case twentyFour
    /// 21:57:03
    case twentyFourWithSeconds
    /// 9:57 PM
    case twelveHour
    /// 9:57:03 PM
    case twelveHourWithSeconds

    static let storageKey = DefaultsKey.templateTimeFormat
    static let automaticCase = TimeTokenFormat.automatic
    static let cjkPattern = "HH:mm:ss"
    /// 초는 넣지 않는다 - 문장에 붙여넣는 시각에 초까지 적는 사람은 드물다.
    static let localeSkeleton = "jmm"

    var recipe: TokenFormatRecipe {
        switch self {
        case .automatic: return .automatic
        case .twentyFour: return .pattern("HH:mm")
        case .twentyFourWithSeconds: return .pattern("HH:mm:ss")
        case .twelveHour: return .pattern("h:mm a")
        case .twelveHourWithSeconds: return .pattern("h:mm:ss a")
        }
    }
}


enum TemplateVariableProcessor {

    /// App Group UserDefaults keys for user-configured values (set in onboarding).
    /// When empty, falls back to Locale/TimeZone.current.
    static let userTimezoneKey = DefaultsKey.userTimezone
    static let userCurrencyKey = DefaultsKey.userCurrency

    /// All auto-variable tokens the processor substitutes. Callers that extract
    /// custom placeholders should skip anything in this set.
    static let autoVariableTokens: Set<String> = [
        // date/time (ko + en alias)
        "{날짜}", "{date}",
        "{시간}", "{time}",
        "{연도}", "{year}",
        "{월}", "{month}",
        "{일}", "{day}",
        // v4.0 global
        "{timezone}", "{타임존}",
        "{timezone_offset}",
        "{currency}", "{통화}",
        "{greeting_time}", "{인사}",
        // v4.0.3 city
        "{city}", "{도시}",
        // v4.4.4 클립보드 - 복사해 둔 것을 문장 안에 그대로 꽂는다
        "{clipboard}", "{클립보드}",
        // v4.4.4 커서 - 값이 아니라 **위치**를 가리키는 제어 토큰.
        // 여기 들어 있어야 "값을 입력하세요" 오버레이가 뜨지 않는다(모든 추출부가 이 집합을 제외한다).
        "{cursor}", "{커서}"
    ]

    /// 클립보드 토큰 (ko/en).
    static let clipboardTokens: [String] = ["{clipboard}", "{클립보드}"]

    /// 커서 위치 토큰 (ko/en).
    static let cursorTokens: [String] = ["{cursor}", "{커서}"]

    /// 이 텍스트가 클립보드 값을 필요로 하는가.
    ///
    /// 호출부는 이걸 먼저 확인하고 **필요할 때만** `UIPasteboard`를 읽어야 한다.
    /// iOS 16+ 는 클립보드를 읽을 때마다 붙여넣기 허용 프롬프트를 띄우므로,
    /// 토큰이 없는데 미리 읽어 두면 아무 이유 없이 프롬프트가 뜬다.
    static func containsClipboardToken(_ text: String) -> Bool {
        clipboardTokens.contains { text.contains($0) }
    }

    /// 이 텍스트가 커서 위치를 지정하는가.
    static func containsCursorToken(_ text: String) -> Bool {
        cursorTokens.contains { text.contains($0) }
    }

    /// Substitute all known auto-variables in `text`. Custom placeholders ({이름},
    /// {name}, etc.) are left untouched - they're handled elsewhere after the
    /// user provides values.
    ///
    /// - Parameters:
    ///   - clipboard: `{clipboard}` 에 꽂을 값. 호출부가 `containsClipboardToken`으로
    ///     **필요할 때만** 읽어서 넘긴다(무조건 읽으면 붙여넣기 프롬프트가 뜬다).
    ///     nil이면 토큰을 빈 문자열로 지운다 - 문장에 `{clipboard}` 가 그대로 남는 것보다 낫다.
    ///   - keepCursorToken: 커서 토큰을 남길지. **기본은 false(제거)** 다.
    ///     커서를 옮길 수 있는 곳은 키보드 익스텐션뿐이고, 나머지 경로(클립보드 복사·미리보기·
    ///     콤보 실행)에서 토큰이 살아 있으면 사용자 눈에 `{커서}` 가 그대로 붙여넣어진다.
    ///     즉 **안전한 쪽이 기본**이고, 키보드만 true로 열어 쓴다.
    ///   - dateFormat: `{날짜}` 모양. nil 이면 사용자가 설정에서 고른 것을 쓴다.
    ///   - timeFormat: `{시간}` 모양. 같은 이유로 열어 둔다.
    ///     ⚠️ 시험에서만 넘긴다. 넘길 수 있게 열어 둔 이유는, 안 그러면 시험이 App Group 의
    ///     공용 값을 바꿔 가며 돌아야 하고 그러면 **다른 시험과 부딪힌다**(실제로 부딪혔다).
    static func process(_ text: String,
                        at reference: Date = Date(),
                        clipboard: String? = nil,
                        keepCursorToken: Bool = false,
                        dateFormat: DateTokenFormat? = nil,
                        timeFormat: TimeTokenFormat? = nil) -> String {
        var result = text

        // 클립보드 - 값이 없으면 지운다(빈칸이 남는 게 토큰이 노출되는 것보다 낫다).
        let clipboardValue = clipboard ?? ""
        for token in clipboardTokens {
            result = result.replacingOccurrences(of: token, with: clipboardValue)
        }

        if !keepCursorToken {
            for token in cursorTokens {
                result = result.replacingOccurrences(of: token, with: "")
            }
        }

        let calendar = Calendar.current
        let year = String(calendar.component(.year, from: reference))
        let month = String(format: "%02d", calendar.component(.month, from: reference))
        let day = String(format: "%02d", calendar.component(.day, from: reference))

        // 날짜 모양은 사람이 고른다. 고른 적이 없으면 언어·지역에 맞춰 알아서
        // (`DateTokenFormat` 머리말 참고 - 미국은 08/31/2026, 한국은 2026-08-31).
        let dateText = (dateFormat ?? DateTokenFormat.current).string(from: reference)

        // 시각도 사람이 고른다. 고른 적이 없으면 언어·지역에 맞춰.
        let timeText = (timeFormat ?? TimeTokenFormat.current).string(from: reference)

        // Date/time (ko + en aliases)
        let dateTokens: [String] = ["{날짜}", "{date}"]
        let timeTokens: [String] = ["{시간}", "{time}"]
        let yearTokens: [String] = ["{연도}", "{year}"]
        let monthTokens: [String] = ["{월}", "{month}"]
        let dayTokens: [String] = ["{일}", "{day}"]

        for token in dateTokens { result = result.replacingOccurrences(of: token, with: dateText) }
        for token in timeTokens { result = result.replacingOccurrences(of: token, with: timeText) }
        for token in yearTokens { result = result.replacingOccurrences(of: token, with: year) }
        for token in monthTokens { result = result.replacingOccurrences(of: token, with: month) }
        for token in dayTokens { result = result.replacingOccurrences(of: token, with: day) }

        // Timezone identifier (e.g. "Asia/Seoul")
        let groupDefaults = AppGroup.defaults
        let timezoneValue = groupDefaults?.string(forKey: userTimezoneKey)?.nonEmpty
            ?? TimeZone.current.identifier
        result = result.replacingOccurrences(of: "{timezone}", with: timezoneValue)
        result = result.replacingOccurrences(of: "{타임존}", with: timezoneValue)

        // Timezone offset (e.g. "GMT+9")
        let offsetSeconds = TimeZone.current.secondsFromGMT(for: reference)
        let offsetHours = offsetSeconds / 3600
        let offsetString = offsetHours >= 0 ? "GMT+\(offsetHours)" : "GMT\(offsetHours)"
        result = result.replacingOccurrences(of: "{timezone_offset}", with: offsetString)

        // Currency (e.g. "USD", "KRW")
        let currencyValue = groupDefaults?.string(forKey: userCurrencyKey)?.nonEmpty
            ?? Locale.current.currency?.identifier
            ?? "USD"
        result = result.replacingOccurrences(of: "{currency}", with: currencyValue)
        result = result.replacingOccurrences(of: "{통화}", with: currencyValue)

        // Greeting time - "Good morning/afternoon/evening" (locale-aware)
        let greeting = localizedGreeting(for: reference)
        result = result.replacingOccurrences(of: "{greeting_time}", with: greeting)
        result = result.replacingOccurrences(of: "{인사}", with: greeting)

        // City - derived from timezone identifier (e.g. "Asia/Bangkok" → "Bangkok")
        let city = cityFromTimezone(timezoneValue)
        result = result.replacingOccurrences(of: "{city}", with: city)
        result = result.replacingOccurrences(of: "{도시}", with: city)

        return result
    }

    /// 시간대 식별자에서 도시명 추출. "Asia/Bangkok" → "Bangkok"
    /// 언더스코어는 공백으로 변환 ("America/Los_Angeles" → "Los Angeles")
    private static func cityFromTimezone(_ tz: String) -> String {
        guard let last = tz.split(separator: "/").last else { return tz }
        return last.replacingOccurrences(of: "_", with: " ")
    }

    // MARK: - Greeting helper

    private static func localizedGreeting(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12:
            return NSLocalizedString("Good morning", comment: "Greeting: morning")
        case 12..<18:
            return NSLocalizedString("Good afternoon", comment: "Greeting: afternoon")
        default:
            return NSLocalizedString("Good evening", comment: "Greeting: evening/night")
        }
    }
}

// MARK: - Token kind detection (v4.0.8)

extension TemplateVariableProcessor {
    /// 토큰 종류 - 입력 UI에서 키패드 종류를 결정.
    enum TokenKind {
        case text
        case number
    }

    /// 숫자 의도 토큰 키워드 (대소문자/공백 무시 부분 매칭).
    /// 예: `{금액}`, `{amount_total}`, `{Price}`, `{TotalCount}` → .number
    /// `금액`/`amount` 등이 토큰명 어딘가에 있으면 숫자로 간주.
    private static let numericKeywords: [String] = [
        // 한국어
        "금액", "수량", "갯수", "개수", "가격", "번호", "원", "값",
        // 영어
        "amount", "price", "quantity", "qty", "count", "number", "num", "value", "total"
    ]

    /// 토큰 (`{이름}` 같은 wrapping 포함 또는 미포함)이 숫자 입력 의도인지 판정.
    static func tokenKind(_ token: String) -> TokenKind {
        let stripped = token
            .trimmingCharacters(in: CharacterSet(charactersIn: "{} "))
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        for keyword in numericKeywords {
            if stripped.contains(keyword.lowercased()) {
                return .number
            }
        }
        return .text
    }

    /// 토큰이 숫자 의도면 true.
    static func isNumericToken(_ token: String) -> Bool {
        tokenKind(token) == .number
    }
}

// MARK: - Memo + attached template composition (v4.0.8)

extension TemplateVariableProcessor {
    /// 메모 본문에서 사용자 정의 토큰만 추출 (autoVariableTokens 제외).
    /// 중복 제거 + 등장 순서 보존.
    static func extractCustomTokens(in text: String) -> [String] {
        TemplatePlaceholder.customTokens(in: text)
    }
}

// MARK: - 자동 변수를 뺀 토큰 고르기
//
// 토큰을 **찾는** 일은 TemplatePlaceholder(어느 타겟에서나 돈다)가 하고,
// 그중 무엇이 자동 변수인지 **아는** 것은 여기다. 그래서 이 걸러내기만 이 파일에 있다.
//
// ⚠️ 예전에는 이 걸러내기가 여섯 군데에 각자 적혀 있었다(본문 처리·무대·키보드·저장소·
//    단축어 편집·플레이스홀더 설정). 자동 변수 목록이 다섯 개에서 스무 개 넘게 늘었을 때
//    한 곳(단축어 편집)이 옛 목록을 그대로 들고 있어서, `{도시}` 같은 자동 변수가
//    "값을 채워야 하는 칸"으로 잡혔다.

extension TemplatePlaceholder {
    /// 사용자가 값을 채워야 하는 토큰만. 자동 변수(`{날짜}`·`{클립보드}` 등)는 뺀다.
    static func customTokens(in text: String) -> [String] {
        tokens(in: text).filter { !TemplateVariableProcessor.autoVariableTokens.contains($0) }
    }
}

extension String {
    /// 사용자가 채워야 하는 토큰만(자동 변수 제외).
    func extractTemplatePlaceholders() -> [String] { TemplatePlaceholder.customTokens(in: self) }
}

// MARK: - 미리보기 조각내기

extension TemplatePlaceholder {

    /// 미리보기 한 조각이 **어떤 상태인지.**
    enum PreviewKind: Equatable {
        /// 그냥 글.
        case plain
        /// 사람이 채운 값.
        case filled
        /// **시스템이 대신 채운 값**(오늘 날짜·통화 등). 사람이 할 일이 없다.
        case automatic
        /// 아직 빈칸. 사람이 채워야 한다.
        case blank
    }

    struct PreviewSegment: Equatable {
        let text: String
        let kind: PreviewKind
    }

    /// 템플릿 본문을 **넣으면 이렇게 된다**로 조각낸다.
    ///
    /// ⚠️ 이 함수가 있는 이유: 예전 미리보기는 `inputs` 에 없는 토큰을 전부 **빈칸**으로 그렸다.
    ///    그런데 `{날짜}` 같은 자동 변수는 넣는 순간 시스템이 채운다. 그래서 화면에는
    ///    **구멍이 둘로 보이는데 채우는 칸은 하나**뿐이었다. 하나가 사라진 것처럼 보이지만
    ///    사라진 적이 없다 - 미리보기가 결과와 다른 그림을 그리고 있었을 뿐이다.
    ///
    /// ⚠️ 그래서 미리보기는 **실제로 들어갈 것**을 그린다. 자동 변수는 값으로 바꿔 보여주되
    ///    사람이 채운 값과 다른 색을 입힐 수 있게 `.automatic` 으로 갈라 준다.
    ///    "내가 채운 것"과 "알아서 채워진 것"은 다른 이야기라서다.
    ///
    /// ⚠️ `{커서}` 는 값이 아니라 **위치**라 빈 문자열이 된다. 조각 자체를 내보내지 않는다
    ///    보이지 않는 것을 자리만 차지하게 두면 문장에 이유 없는 틈이 생긴다.
    static func previewSegments(of text: String,
                                inputs: [String: String],
                                clipboard: String? = nil,
                                now: Date = Date()) -> [PreviewSegment] {
        let ns = text as NSString
        var segments: [PreviewSegment] = []
        var cursor = 0

        func appendPlain(_ piece: String) {
            guard !piece.isEmpty else { return }
            segments.append(PreviewSegment(text: piece, kind: .plain))
        }

        for match in matches(in: text) {
            let full = match.range
            if full.location > cursor {
                appendPlain(ns.substring(with: NSRange(location: cursor, length: full.location - cursor)))
            }
            cursor = full.location + full.length
            let token = ns.substring(with: full)

            if let value = inputs[token], !value.isEmpty {
                segments.append(PreviewSegment(text: value, kind: .filled))
                continue
            }
            guard TemplateVariableProcessor.autoVariableTokens.contains(token) else {
                segments.append(PreviewSegment(text: token, kind: .blank))
                continue
            }
            // 위치를 가리키는 토큰은 글자를 만들지 않는다.
            if TemplateVariableProcessor.cursorTokens.contains(token) { continue }

            let resolved = TemplateVariableProcessor.process(token,
                                                             at: now,
                                                             clipboard: clipboard,
                                                             keepCursorToken: false)
            if resolved.isEmpty { continue }
            segments.append(PreviewSegment(text: resolved, kind: .automatic))
        }
        if cursor < ns.length {
            appendPlain(ns.substring(from: cursor))
        }
        return segments
    }
}

// MARK: - Memo + attached template composition (v4.0.8)

extension TemplateVariableProcessor {
    /// 사용자 입력값으로 토큰을 치환한 후 자동 변수까지 처리한 최종 문자열을 반환.
    /// `inputs` key는 토큰 wrapping 포함 (예: `{금액}`).
    static func substitute(_ text: String, with inputs: [String: String]) -> String {
        var result = text
        for (token, value) in inputs {
            result = result.replacingOccurrences(of: token, with: value)
        }
        return process(result)
    }

    /// 옵션 X (이어 붙이기): 메모 본문 + 줄바꿈 + 입력값 치환된 템플릿 본문.
    /// templateBody가 nil이거나 빈 문자열이면 메모 본문만 반환.
    static func compose(memoValue: String, templateBody: String?, templateInputs: [String: String]) -> String {
        guard let body = templateBody, !body.isEmpty else {
            return memoValue
        }
        let resolvedTemplate = substitute(body, with: templateInputs)
        if memoValue.isEmpty { return resolvedTemplate }
        return memoValue + "\n" + resolvedTemplate
    }
}

// MARK: - Helpers

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

// MARK: - 커서 위치 토큰 (v4.4.4)

extension TemplateVariableProcessor {

    /// 커서 토큰을 해석한 결과.
    struct CursorPlacement: Equatable {
        /// 실제로 입력할 텍스트 (토큰 제거됨).
        let text: String
        /// 입력이 끝난 뒤 캐럿을 **끝에서 몇 글자 앞으로** 옮길지. 0이면 이동 없음.
        let offsetFromEnd: Int

        var needsCursorMove: Bool { offsetFromEnd > 0 }
    }

    /// `{커서}` / `{cursor}` 를 해석해 "넣을 텍스트"와 "캐럿을 되돌릴 거리"로 나눈다.
    ///
    /// 삽입 후 커서를 빈칸으로 보내주는 것만으로 체감이 크게 달라진다
    /// "{이름}님 안녕하세요"를 넣고 나서 캐럿이 문장 끝에 남으면 결국 손으로 되돌아가야 한다.
    ///
    /// 규칙:
    /// - **첫 번째** 토큰만 커서 위치로 쓴다. 캐럿은 하나뿐이라 두 개를 지정할 수 없다.
    /// - 나머지 토큰은 조용히 지운다(사용자 눈에 `{커서}` 가 남으면 안 된다).
    /// - 토큰이 없으면 offsetFromEnd = 0.
    ///
    /// ⚠️ 거리는 `Character` 개수로 센다. `adjustTextPosition(byCharacterOffset:)` 이
    ///    받는 단위와 맞추기 위해서다. 이모지 같은 결합 문자가 토큰 **뒤에** 오면
    ///    시스템이 세는 단위와 어긋날 수 있다(알려진 한계 - 한글·영문에서는 일치).
    static func resolveCursor(in text: String) -> CursorPlacement {
        // 가장 앞선 토큰 하나를 고른다(ko/en 어느 쪽이 먼저 나오든).
        var firstRange: Range<String.Index>?
        for token in cursorTokens {
            guard let range = text.range(of: token) else { continue }
            if firstRange == nil || range.lowerBound < firstRange!.lowerBound {
                firstRange = range
            }
        }

        guard let cursorRange = firstRange else {
            return CursorPlacement(text: text, offsetFromEnd: 0)
        }

        let before = String(text[text.startIndex..<cursorRange.lowerBound])
        // 뒷부분에 남은 토큰들은 위치로 쓰지 않고 제거만 한다.
        var after = String(text[cursorRange.upperBound...])
        for token in cursorTokens {
            after = after.replacingOccurrences(of: token, with: "")
        }

        return CursorPlacement(text: before + after, offsetFromEnd: after.count)
    }
}
