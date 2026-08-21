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
    static func process(_ text: String,
                        at reference: Date = Date(),
                        clipboard: String? = nil,
                        keepCursorToken: Bool = false) -> String {
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
