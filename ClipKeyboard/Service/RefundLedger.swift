//
//  RefundLedger.swift
//  ClipKeyboard
//
//  **월 원장** - 어느 달에 어떤 문구가 얼마를 돌려줬는지.
//
//  왜 새로 쌓나: 기존에 기기에 있던 건 평생 누적(`kb.timeSaved.totalSeconds`)과
//  일별 **횟수**뿐이었다. 둘 다 "이번 달에 얼마 돌려받았나"에 답하지 못한다.
//
//  ⚠️ **월 단위인 이유.** 문구별 줄 항목까지 정확하려면 원장을 쪼갠 단위와 영수증 기간이
//     정확히 맞아야 한다. 일 단위로 문구별을 쌓으면 키가 (문구 수 × 날짜 수)로 불어나고,
//     월 원장에서 임의 구간(최근 7일 등)을 뽑으면 그 달 전체가 딸려와 **틀린 수를 찍는다.**
//     그래서 기간을 월로 못박았다. 정확하지 않은 기간을 보여주느니 기간을 줄인다.
//
//  ⚠️ 한 달 = 키 하나다(문구마다 키를 만들지 않는다). 값은 [문구 UUID: 초] 사전이라
//     문구가 100개여도 사전 하나이고, 1년에 키 12개만 는다.
//
//  ⚠️ 쓰기는 **키보드 익스텐션에서도** 일어난다(메모리 상한 60MB). 그래서 쓰기 경로는
//     사전 하나를 읽고 고쳐 쓰는 것뿐이고, 청소는 앱에서만 한다.
//
//  ⚠️ 예전부터 쓰던 사용자에게는 **원장 이전 기록이 없다.** 그 사람의 지난달을 0원으로
//     보여주면 거짓말이라, 시작일(`startedAt`)을 남겨 영수증이 "여기서부터 셌다"고 밝힌다.
//

import Foundation

enum RefundLedger {

    /// 달별 [문구 UUID: 돌려준 초].
    private static let monthKeyPrefix = "kb.ledger.month."
    /// 달별 [문구 UUID: 쓴 횟수]. 초와 나눠 두는 건 영수증 줄의 "×N" 때문이다
    /// 초를 회당 금액으로 나눠 역산하면 문구를 고친 순간부터 어긋난다.
    private static let usesKeyPrefix = "kb.ledger.uses."
    private static let startedAtKey = "kb.ledger.startedAt"
    private static let prunedOnKey = "kb.ledger.prunedOn"
    private static let dailyCountPrefix = "kb.usage.daily."

    /// 보관할 달 수. 2년치 + 여유. 넘는 건 지운다
    /// App Group UserDefaults 는 키보드 익스텐션이 매번 통째로 읽어서, 무한히 불면 익스텐션이 느려진다.
    static let retainedMonths = 25
    /// 일별 횟수 키 보관 일수.
    static let retainedDays = 400

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
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

        guard seconds > 0 else { return }

        let id = memoID.uuidString
        let stamp = monthString(date)

        var month = defaults.dictionary(forKey: monthKeyPrefix + stamp) as? [String: Double] ?? [:]
        month[id, default: 0] += seconds
        defaults.set(month, forKey: monthKeyPrefix + stamp)

        var uses = defaults.dictionary(forKey: usesKeyPrefix + stamp) as? [String: Int] ?? [:]
        uses[id, default: 0] += 1
        defaults.set(uses, forKey: usesKeyPrefix + stamp)
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
        guard let defaults, let interval = calendar.dateInterval(of: .month, for: date) else { return 0 }

        var total = 0
        var day = interval.start
        while day < interval.end {
            total += defaults.integer(forKey: dailyCountPrefix + dayString(day))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return total
    }

    /// 원장을 처음 적은 날. 없으면 아직 한 번도 안 썼다는 뜻.
    static var startedAt: Date? {
        guard let raw = defaults?.object(forKey: startedAtKey) as? Double else { return nil }
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
              let dayCutoff = calendar.date(byAdding: .day, value: -retainedDays, to: now) else { return 0 }

        let oldestMonth = monthString(monthCutoff)
        let oldestDay = dayString(dayCutoff)

        var removed = 0
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix(monthKeyPrefix) || key.hasPrefix(usesKeyPrefix) {
                // "yyyy-MM" 은 사전순 비교가 곧 시간순 비교다.
                let prefix = key.hasPrefix(monthKeyPrefix) ? monthKeyPrefix : usesKeyPrefix
                if String(key.dropFirst(prefix.count)) < oldestMonth {
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

/// 영수증을 끊을 기간.
///
/// ⚠️ 임의 구간(최근 7일 등)이 없는 건 게을러서가 아니다 - 월 원장에서 뽑으면 그 달 전체가
///    딸려와 **틀린 수**가 찍힌다. 정확하지 않은 기간은 아예 만들지 않는다.
enum RefundPeriod: String, CaseIterable, Identifiable {
    /// 이번 달.
    case thisMonth
    /// 지난달.
    case lastMonth
    /// 전체 - 원장 이전까지 포함한 평생 누적. 이건 예전 값이 있어서 언제나 완전하다.
    case allTime

    var id: String { rawValue }

    /// 이 기간이 가리키는 달. 전체는 달이 없다.
    func month(from now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .thisMonth: return now
        case .lastMonth: return calendar.date(byAdding: .month, value: -1, to: now)
        case .allTime:   return nil
        }
    }

    var localizedName: String {
        switch self {
        case .thisMonth: return NSLocalizedString("이번 달", comment: "Refund period: this month")
        case .lastMonth: return NSLocalizedString("지난달", comment: "Refund period: last month")
        case .allTime:   return NSLocalizedString("전체", comment: "Refund period: all time")
        }
    }

    /// 영수증에 찍히는 기간 이름 - "2026년 8월" 처럼 실제 달을 쓴다.
    /// "이번 달"이라고 찍으면 나중에 그 종이를 다시 봤을 때 언제 것인지 알 수 없다.
    func label(from now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let month = month(from: now, calendar: calendar) else {
            return NSLocalizedString("전체 기간", comment: "Refund receipt period: all time")
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: month)
    }
}
