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

enum TemplateVariableProcessor {

    /// App Group UserDefaults keys for user-configured values (set in onboarding).
    /// When empty, falls back to Locale/TimeZone.current.
    static let userTimezoneKey = "clipkeyboard_user_timezone"
    static let userCurrencyKey = "clipkeyboard_user_currency"

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
        "{city}", "{도시}"
    ]

    /// Substitute all known auto-variables in `text`. Custom placeholders ({이름},
    /// {name}, etc.) are left untouched — they're handled elsewhere after the
    /// user provides values.
    static func process(_ text: String, at reference: Date = Date()) -> String {
        var result = text

        let calendar = Calendar.current
        let year = String(calendar.component(.year, from: reference))
        let month = String(format: "%02d", calendar.component(.month, from: reference))
        let day = String(format: "%02d", calendar.component(.day, from: reference))

        let dateFormatter = DateFormatter()

        // ISO date
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let isoDate = dateFormatter.string(from: reference)

        // 24h time
        dateFormatter.dateFormat = "HH:mm:ss"
        let isoTime = dateFormatter.string(from: reference)

        // Date/time (ko + en aliases)
        let dateTokens: [String] = ["{날짜}", "{date}"]
        let timeTokens: [String] = ["{시간}", "{time}"]
        let yearTokens: [String] = ["{연도}", "{year}"]
        let monthTokens: [String] = ["{월}", "{month}"]
        let dayTokens: [String] = ["{일}", "{day}"]

        for token in dateTokens { result = result.replacingOccurrences(of: token, with: isoDate) }
        for token in timeTokens { result = result.replacingOccurrences(of: token, with: isoTime) }
        for token in yearTokens { result = result.replacingOccurrences(of: token, with: year) }
        for token in monthTokens { result = result.replacingOccurrences(of: token, with: month) }
        for token in dayTokens { result = result.replacingOccurrences(of: token, with: day) }

        // Timezone identifier (e.g. "Asia/Seoul")
        let groupDefaults = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")
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

        // Greeting time — "Good morning/afternoon/evening" (locale-aware)
        let greeting = localizedGreeting(for: reference)
        result = result.replacingOccurrences(of: "{greeting_time}", with: greeting)
        result = result.replacingOccurrences(of: "{인사}", with: greeting)

        // City — derived from timezone identifier (e.g. "Asia/Bangkok" → "Bangkok")
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
            return NSLocalizedString("Good morning", comment: "Greeting — morning")
        case 12..<18:
            return NSLocalizedString("Good afternoon", comment: "Greeting — afternoon")
        default:
            return NSLocalizedString("Good evening", comment: "Greeting — evening/night")
        }
    }
}

// MARK: - Helpers

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
