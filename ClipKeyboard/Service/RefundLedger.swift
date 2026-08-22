//
//  RefundLedger.swift
//  ClipKeyboard
//
//  **월 원장** - 어느 달에 어떤 문구가 얼마를 돌려줬는지.
//
//  왜 새로 쌓나: 기존에 기기에 있던 건 평생 누적(`kb.timeSaved.totalSeconds`)과
//  일별 **횟수**뿐이었다. 둘 다 "이번 달에 얼마 돌려받았나"에 답하지 못한다.
//
//  ⚠️ **원장을 쪼갠 단위와 기간이 정확히 맞아야 한다.** 월 원장에서 한 주를 오려 내면
//     그 달 전체가 딸려와 **틀린 수를 찍는다.** 그래서 주는 월 원장에서 뽑지 않고
//     **일 원장**(아래 dailySeconds/dailyUses)에서 모은다. 정확하지 않은 기간은 만들지 않는다.
//
//  ⚠️ **일 원장은 짧게만 보관한다.** 한 주를 세는 데 필요한 건 7일이라, 45일만 남기고
//     나머지는 청소한다. 오래 보면 볼수록 키가 늘고 익스텐션이 매번 그걸 통째로 읽는다.
//     달 단위 기록은 그대로 월 원장에 남으니 잃는 것이 없다.
//
//  ⚠️ 한 달 = 키 하나다(문구마다 키를 만들지 않는다). 값은 [문구 UUID: 초] 사전이라
//     문구가 100개여도 사전 하나이고, 1년에 키 12개만 는다.
//
//  ⚠️ 쓰기는 **키보드 익스텐션에서도** 일어난다(메모리 상한 60MB). 그래서 쓰기 경로는
//     사전 하나를 읽고 고쳐 쓰는 것뿐이고, 청소는 앱에서만 한다.
//
//  ⚠️ 예전부터 쓰던 사용자에게는 **원장 이전 기록이 없다.** 그 사람의 지난달을 0원으로
//     보여주면 거짓말이라, 시작일(`startedAt`)을 남겨 영수증이 "여기서부터 셌다"고 밝힌다.
//     일 원장도 나중에 들어와서 시작일을 따로 남긴다(`dailyStartedAt`).
//

import Foundation

enum RefundLedger {

    /// 달별 [문구 UUID: 돌려준 초].
    private static let monthKeyPrefix = "kb.ledger.month."
    /// 달별 [문구 UUID: 쓴 횟수]. 초와 나눠 두는 건 영수증 줄의 "×N" 때문이다
    /// 초를 회당 금액으로 나눠 역산하면 문구를 고친 순간부터 어긋난다.
    private static let usesKeyPrefix = "kb.ledger.uses."
    /// 날짜별 [문구 UUID: 돌려준 초]. **주 단위를 정확히 세기 위한 것**이고, 45일만 산다.
    private static let dailySecondsPrefix = "kb.ledger.dayseconds."
    /// 날짜별 [문구 UUID: 쓴 횟수].
    private static let dailyUsesPrefix = "kb.ledger.dayuses."
    private static let startedAtKey = "kb.ledger.startedAt"
    /// 일 원장을 처음 적은 날. 월 원장보다 늦게 들어와서 따로 남긴다.
    private static let dailyStartedAtKey = "kb.ledger.dailyStartedAt"
    private static let prunedOnKey = "kb.ledger.prunedOn"
    private static let dailyCountPrefix = "kb.usage.daily."

    /// 보관할 달 수. 2년치 + 여유. 넘는 건 지운다
    /// App Group UserDefaults 는 키보드 익스텐션이 매번 통째로 읽어서, 무한히 불면 익스텐션이 느려진다.
    static let retainedMonths = 25
    /// 일별 횟수 키 보관 일수.
    static let retainedDays = 400
    /// 일 원장(문구별) 보관 일수. 한 주를 세는 데 7일이면 되고, 넉넉히 잡아도 이 정도다.
    /// 이걸 늘리면 익스텐션이 매번 읽는 사전이 그만큼 커진다.
    static let retainedLedgerDays = 45

    private static var defaults: UserDefaults? {
        AppGroup.defaults
    }

    // MARK: - 쓰기

    /// 문구 하나가 이 시점에 돌려준 시간을 원장에 적는다.
    ///
    /// `KeyboardUsageTracker.recordMemoUse` 안에서만 불린다 - 사용 기록과 원장이
    /// 따로 갱신되면 둘이 어긋나고, 그러면 잔고와 영수증이 서로 다른 말을 한다.
    static func record(memoID: UUID, seconds: Double, on date: Date = Date()) {
        guard let defaults else { return }

        // 시작일은 벌이가 0이어도 남긴다 - "언제부터 셌나"는 금액과 무관한 사실이다.
        if defaults.object(forKey: startedAtKey) == nil {
            defaults.set(date.timeIntervalSince1970, forKey: startedAtKey)
        }

        if defaults.object(forKey: dailyStartedAtKey) == nil {
            defaults.set(date.timeIntervalSince1970, forKey: dailyStartedAtKey)
        }

        let id = memoID.uuidString
        let stamp = monthString(date)
        let day = dayString(date)

        // 횟수는 벌이가 0초여도 적는다. 짧은 문구도 "다시 치지 않은" 한 번이고,
        // 여기서 빼면 영수증 머리의 총 횟수와 줄의 합이 어긋난다.
        var uses = defaults.dictionary(forKey: usesKeyPrefix + stamp) as? [String: Int] ?? [:]
        uses[id, default: 0] += 1
        defaults.set(uses, forKey: usesKeyPrefix + stamp)

        // 같은 한 번을 날짜 칸에도 적는다. 달과 날이 **같은 자리에서** 갱신돼야
        // "이번 주"와 "이번 달"이 서로 다른 말을 하지 않는다.
        var dayUses = defaults.dictionary(forKey: dailyUsesPrefix + day) as? [String: Int] ?? [:]
        dayUses[id, default: 0] += 1
        defaults.set(dayUses, forKey: dailyUsesPrefix + day)

        guard seconds > 0 else { return }

        var month = defaults.dictionary(forKey: monthKeyPrefix + stamp) as? [String: Double] ?? [:]
        month[id, default: 0] += seconds
        defaults.set(month, forKey: monthKeyPrefix + stamp)

        var daily = defaults.dictionary(forKey: dailySecondsPrefix + day) as? [String: Double] ?? [:]
        daily[id, default: 0] += seconds
        defaults.set(daily, forKey: dailySecondsPrefix + day)
    }

    // MARK: - 읽기

    /// 이 달에 문구별로 돌려준 시간(초).
    static func entries(forMonthOf date: Date) -> [UUID: Double] {
        guard let raw = defaults?.dictionary(forKey: monthKeyPrefix + monthString(date)) as? [String: Double] else {
            return [:]
        }
        return raw.reduce(into: [UUID: Double]()) { out, pair in
            guard let id = UUID(uuidString: pair.key) else { return }
            out[id] = pair.value
        }
    }

    /// 이 달에 문구별로 쓴 횟수.
    static func uses(forMonthOf date: Date) -> [UUID: Int] {
        guard let raw = defaults?.dictionary(forKey: usesKeyPrefix + monthString(date)) as? [String: Int] else {
            return [:]
        }
        return raw.reduce(into: [UUID: Int]()) { out, pair in
            guard let id = UUID(uuidString: pair.key) else { return }
            out[id] = pair.value
        }
    }

    /// 이 달에 돌려받은 시간 합계(초).
    static func total(forMonthOf date: Date) -> Double {
        entries(forMonthOf: date).values.reduce(0, +)
    }

    /// 이 달에 다시 치지 않은 횟수 - 일별 횟수를 더한다(원장 이전부터 쌓이던 값이다).
    static func useCount(forMonthOf date: Date, calendar: Calendar = .current) -> Int {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return 0 }
        return useCount(in: interval, calendar: calendar)
    }

    /// 이 구간에 다시 치지 않은 횟수 - 일별 횟수(`kb.usage.daily.`)를 더한다.
    /// 이 값은 문구별이 아니라 총계라, 일 원장이 없던 시절에도 남아 있다.
    static func useCount(in interval: DateInterval, calendar: Calendar = .current) -> Int {
        guard let defaults else { return 0 }
        return reduceDays(in: interval, calendar: calendar, into: 0) { total, day in
            total += defaults.integer(forKey: dailyCountPrefix + day)
        }
    }

    // MARK: - 읽기 (일 원장)

    /// 이 구간에 문구별로 돌려준 시간(초). **날짜 칸을 더한다** - 주 단위는 이 길로만 정확하다.
    static func dailyEntries(in interval: DateInterval, calendar: Calendar = .current) -> [UUID: Double] {
        guard let defaults else { return [:] }
        return reduceDays(in: interval, calendar: calendar, into: [UUID: Double]()) { out, day in
            guard let raw = defaults.dictionary(forKey: dailySecondsPrefix + day) as? [String: Double] else { return }
            for (key, value) in raw {
                guard let id = UUID(uuidString: key) else { continue }
                out[id, default: 0] += value
            }
        }
    }

    /// 이 구간에 문구별로 쓴 횟수.
    static func dailyUses(in interval: DateInterval, calendar: Calendar = .current) -> [UUID: Int] {
        guard let defaults else { return [:] }
        return reduceDays(in: interval, calendar: calendar, into: [UUID: Int]()) { out, day in
            guard let raw = defaults.dictionary(forKey: dailyUsesPrefix + day) as? [String: Int] else { return }
            for (key, value) in raw {
                guard let id = UUID(uuidString: key) else { continue }
                out[id, default: 0] += value
            }
        }
    }

    /// 구간 안의 날짜 키("yyyy-MM-dd")를 하루씩 훑는다. 끝은 열린 구간이다.
    private static func reduceDays<T>(in interval: DateInterval,
                                      calendar: Calendar,
                                      into initial: T,
                                      _ body: (inout T, String) -> Void) -> T {
        var result = initial
        var day = interval.start
        while day < interval.end {
            body(&result, dayString(day))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    // MARK: - 읽기 (기간 하나)

    /// 기간 하나를 편 원장. 화면과 영수증이 **같은 값**을 보게 하는 단 하나의 창구다.
    ///
    /// ⚠️ 어디서 뽑을지는 기간이 정한다 - 달은 월 원장에서(옛 기록까지 있다), 주는 일
    ///    원장에서. 이 갈림을 화면마다 따로 쓰면 언젠가 한쪽만 고쳐져 서로 다른 말을 한다.
    /// - Returns: 전체 기간은 원장 밖(평생 누적)이라 nil.
    static func book(for period: RefundPeriod, now: Date = Date(), calendar: Calendar = .current) -> Book? {
        guard let interval = period.interval(from: now, calendar: calendar) else { return nil }

        let seconds: [UUID: Double]
        let uses: [UUID: Int]
        let start: Date?
        if period.readsDailyLedger {
            seconds = dailyEntries(in: interval, calendar: calendar)
            uses = dailyUses(in: interval, calendar: calendar)
            start = dailyStartedAt
        } else {
            seconds = entries(forMonthOf: interval.start)
            uses = self.uses(forMonthOf: interval.start)
            start = startedAt
        }

        // 세기 시작한 날이 기간 안쪽이면 합계가 기간 전체를 못 덮는다 - 그 사실을 들려보낸다.
        let coverage = (start.map { $0 > interval.start } ?? false) ? start : nil
        return Book(interval: interval, seconds: seconds, uses: uses, coverageStartedAt: coverage)
    }

    /// 한 기간의 원장 한 벌.
    struct Book: Equatable {
        let interval: DateInterval
        /// 문구별 돌려준 시간(초).
        let seconds: [UUID: Double]
        /// 문구별 쓴 횟수. 초에서 역산하지 않는다 - 문구를 고친 순간부터 어긋난다.
        let uses: [UUID: Int]
        /// 합계가 기간 전체를 못 덮을 때, 실제로 세기 시작한 날.
        let coverageStartedAt: Date?

        var totalSeconds: Double { seconds.values.reduce(0, +) }
        var totalUses: Int { uses.values.reduce(0, +) }
    }

    /// 원장을 처음 적은 날. 없으면 아직 한 번도 안 썼다는 뜻.
    static var startedAt: Date? {
        guard let raw = defaults?.object(forKey: startedAtKey) as? Double else { return nil }
        return Date(timeIntervalSince1970: raw)
    }

    /// 일 원장을 처음 적은 날. 월 원장보다 늦게 들어와서, 예전부터 쓰던 사람은
    /// 이 날 이전의 **주**를 셀 수 없다. 그 사실은 숨기지 않고 화면에 적는다.
    static var dailyStartedAt: Date? {
        guard let raw = defaults?.object(forKey: dailyStartedAtKey) as? Double else { return nil }
        return Date(timeIntervalSince1970: raw)
    }

    // MARK: - 청소

    /// 오래된 달·날짜 키를 지운다.
    ///
    /// ⚠️ **앱에서만** 부른다. 전체 사전을 훑는 일이라 익스텐션의 입력 경로에 두면 안 된다.
    /// ⚠️ 하루 한 번만 실제로 돈다 - 실행할 때마다 훑으면 켤 때마다 값을 치른다.
    @discardableResult
    static func pruneIfNeeded(now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let defaults else { return 0 }

        let today = dayString(now)
        guard defaults.string(forKey: prunedOnKey) != today else { return 0 }
        defaults.set(today, forKey: prunedOnKey)

        guard let monthCutoff = calendar.date(byAdding: .month, value: -retainedMonths, to: now),
              let dayCutoff = calendar.date(byAdding: .day, value: -retainedDays, to: now),
              let ledgerDayCutoff = calendar.date(byAdding: .day, value: -retainedLedgerDays, to: now) else { return 0 }

        let oldestMonth = monthString(monthCutoff)
        let oldestDay = dayString(dayCutoff)
        let oldestLedgerDay = dayString(ledgerDayCutoff)

        var removed = 0
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix(monthKeyPrefix) || key.hasPrefix(usesKeyPrefix) {
                // "yyyy-MM" 은 사전순 비교가 곧 시간순 비교다.
                let prefix = key.hasPrefix(monthKeyPrefix) ? monthKeyPrefix : usesKeyPrefix
                if String(key.dropFirst(prefix.count)) < oldestMonth {
                    defaults.removeObject(forKey: key); removed += 1
                }
            } else if key.hasPrefix(dailySecondsPrefix) || key.hasPrefix(dailyUsesPrefix) {
                // 일 원장은 주를 세는 데만 쓴다 - 한 달을 넘겨 들고 있을 이유가 없다.
                let prefix = key.hasPrefix(dailySecondsPrefix) ? dailySecondsPrefix : dailyUsesPrefix
                if String(key.dropFirst(prefix.count)) < oldestLedgerDay {
                    defaults.removeObject(forKey: key); removed += 1
                }
            } else if key.hasPrefix(dailyCountPrefix) {
                if String(key.dropFirst(dailyCountPrefix.count)) < oldestDay {
                    defaults.removeObject(forKey: key); removed += 1
                }
            }
        }
        if removed > 0 {
            print("🧹 [RefundLedger.prune] 오래된 원장 키 \(removed)개 정리")
        }
        return removed
    }

    // MARK: - 키

    static func monthKey(for date: Date) -> String { monthKeyPrefix + monthString(date) }

    /// 날짜 → "yyyy-MM". `KeyboardUsageTracker` 와 같은 고정 로캘을 쓴다
    /// 사용자 달력이 바뀌어도 키가 흔들리면 안 된다.
    private static func monthString(_ date: Date) -> String { formatted(date, "yyyy-MM") }
    private static func dayString(_ date: Date) -> String { formatted(date, "yyyy-MM-dd") }

    private static func formatted(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

// MARK: - 기간

/// 영수증을 끊고 사용 기록을 잘라 볼 기간.
///
/// ⚠️ 임의 구간(최근 10일 등)이 없는 건 게을러서가 아니다 - 원장을 쪼갠 단위와 기간이
///    어긋나면 **틀린 수**가 찍힌다. 여기 있는 기간은 전부 원장 한 칸에 정확히 맞는다.
enum RefundPeriod: String, CaseIterable, Identifiable {
    /// 이번 주 - 일 원장에서 모은다(월 원장에서 오려 내면 그 달 전체가 딸려온다).
    case thisWeek
    /// 이번 달.
    case thisMonth
    /// 지난달.
    case lastMonth
    /// 전체 - 원장 이전까지 포함한 평생 누적. 이건 예전 값이 있어서 언제나 완전하다.
    case allTime

    var id: String { rawValue }

    /// 사용 기록 화면에서 고르게 하는 기간.
    ///
    /// ⚠️ 지난달이 여기 없는 건 일부러다. 사용 기록은 "요즘 잘 쓰고 있나"에 답하는 화면이라
    ///    가까운 두 칸(이번 주·이번 달)과 평생 하나면 된다. 칸이 늘수록 고르는 일만 는다.
    ///    지난달은 금고 카드와 영수증에 그대로 남아 있다.
    static let selectable: [RefundPeriod] = [.thisWeek, .thisMonth, .allTime]

    /// 이 기간이 덮는 실제 구간. 전체는 구간이 없다.
    func interval(from now: Date = Date(), calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .thisWeek:  return calendar.dateInterval(of: .weekOfYear, for: now)
        case .thisMonth: return calendar.dateInterval(of: .month, for: now)
        case .lastMonth:
            guard let previous = calendar.date(byAdding: .month, value: -1, to: now) else { return nil }
            return calendar.dateInterval(of: .month, for: previous)
        case .allTime:   return nil
        }
    }

    /// 월 원장이 아니라 **일 원장**에서 읽어야 하는 기간인가.
    var readsDailyLedger: Bool { self == .thisWeek }

    /// 이 기간이 가리키는 달. 주와 전체는 달이 아니다.
    ///
    /// ⚠️ 여기서 nil 이 나온다고 "전체"로 넘기면 안 된다. 기간이 원장 어디를 보는지는
    ///    `interval(from:)` 과 `readsDailyLedger` 가 정한다.
    func month(from now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .thisMonth: return now
        case .lastMonth: return calendar.date(byAdding: .month, value: -1, to: now)
        case .thisWeek, .allTime: return nil
        }
    }

    var localizedName: String {
        switch self {
        case .thisWeek:  return NSLocalizedString("이번 주", comment: "Refund period: this week")
        case .thisMonth: return NSLocalizedString("이번 달", comment: "Refund period: this month")
        case .lastMonth: return NSLocalizedString("지난달", comment: "Refund period: last month")
        case .allTime:   return NSLocalizedString("전체", comment: "Refund period: all time")
        }
    }

    /// 영수증에 찍히는 기간 이름 - "2026년 8월", "8월 17일 ~ 8월 23일" 처럼 실제 날짜를 쓴다.
    /// "이번 주"라고 찍으면 나중에 그 종이를 다시 봤을 때 언제 것인지 알 수 없다.
    func label(from now: Date = Date(), calendar: Calendar = .current) -> String {
        if self == .allTime {
            return NSLocalizedString("전체 기간", comment: "Refund receipt period: all time")
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar

        if self == .thisWeek {
            guard let interval = interval(from: now, calendar: calendar) else { return localizedName }
            // 구간의 끝은 다음 주 첫날이다 - 하루를 빼야 사람이 아는 마지막 날이 된다.
            let last = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            formatter.setLocalizedDateFormatFromTemplate("MMMd")
            return String(format: NSLocalizedString("%1$@ ~ %2$@", comment: "Refund receipt period: date range"),
                          formatter.string(from: interval.start), formatter.string(from: last))
        }

        guard let month = month(from: now, calendar: calendar) else { return localizedName }
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: month)
    }
}
