//
//  UsageRhythm.swift
//  ClipKeyboard / ClipKeyboardExtension
//
//  **같은 단축어가 같은 때 쓰이면, 그때가 오기 전에 앞에 세운다.**
//
//  왜 필요한가: 주간 보고는 금요일 오후에, 인보이스는 월말에, 출석 학번은 아침 9시에 쓴다.
//  이런 순간은 사람이 아니라 달력이 정한다. 그런데 키보드는 지금까지 "최근에 쓴 것" 만 알았다.
//  지난달 말에 한 번 쓴 인보이스는 이번 달 말이 오면 최근 목록에서 이미 사라져 있다.
//  정확히 필요한 날에 가장 멀리 가 있는 셈이다.
//
//  세 가지 박자만 본다.
//
//  | 박자 | 무엇을 보고 아나 | 언제 앞에 세우나 |
//  | --- | --- | --- |
//  | 매달 | 서로 다른 세 달 이상, 같은 날짜 ±2일 (또는 전부 월말 7일) | 그 날짜 ±2일 |
//  | 매주 | 서로 다른 세 주 이상, 같은 요일 | 그 요일 |
//  | 매일 | 서로 다른 네 날 이상, 같은 시각 ±1시간 | 그 시각 ±1시간 |
//
//  ⚠️ **말을 걸지 않는다.** 하는 일은 키보드 빠른 줄의 맨 앞자리를 내주는 것뿐이다
//     (`QuickRowPlanner`). 틀려도 칩 하나가 앞에 서 있을 뿐이라 잔소리가 되지 않는다.
//
//  ⚠️ **기기 밖으로 나가지 않는다.** 남기는 것은 단축어 id 와 시각뿐이고 내용은 없다.
//
//  ⚠️ 판정은 순수 함수다. 기록을 읽고 쓰는 일은 `UsageRhythmLog` 가 따로 한다.
//

import Foundation

// MARK: - 기록

/// 단축어를 쓴 시각. 단축어마다 최근 몇 번만 App Group 에 남긴다.
///
/// ⚠️ 쓰는 자리는 `MemoStore.incrementClipCount` 한 곳이다. 앱·키보드의 모든 사용이
///    그 함수를 지나므로(`ActiveDayLedger` 와 같은 이유) 여기 한 곳이면 된다.
enum UsageRhythmLog {

    /// 단축어 하나에 남기는 시각 수. 매달 박자를 보려면 몇 달치가 남아야 한다.
    /// 매일 쓰는 단축어는 금방 차지만, 그 사람의 박자는 최근 24번으로 충분히 보인다.
    static let perMemoLimit = 24

    private static var defaults: UserDefaults? { AppGroup.defaults }

    /// 한 번 썼다고 적는다.
    static func record(memoID: UUID, at date: Date = Date()) {
        guard let defaults else { return }
        var raw = defaults.dictionary(forKey: DefaultsKey.usageRhythmLog) as? [String: [Double]] ?? [:]
        let stamps = (raw[memoID.uuidString] ?? []).map { Date(timeIntervalSince1970: $0) }
        raw[memoID.uuidString] = appending(date, to: stamps).map(\.timeIntervalSince1970)
        defaults.set(raw, forKey: DefaultsKey.usageRhythmLog)
    }

    /// 전부 읽는다. 알아볼 수 없는 id 는 건너뛴다.
    static func load() -> [UUID: [Date]] {
        let raw = defaults?.dictionary(forKey: DefaultsKey.usageRhythmLog) as? [String: [Double]] ?? [:]
        var result: [UUID: [Date]] = [:]
        for (key, values) in raw {
            guard let id = UUID(uuidString: key) else { continue }
            result[id] = values.map { Date(timeIntervalSince1970: $0) }
        }
        return result
    }

    /// 지워진 단축어의 기록을 걷어 낸다. 남겨 두면 아무도 안 읽는 시각이 계속 쌓인다.
    static func prune(keeping ids: Set<UUID>) {
        guard let defaults,
              var raw = defaults.dictionary(forKey: DefaultsKey.usageRhythmLog) as? [String: [Double]] else { return }
        let before = raw.count
        raw = raw.filter { key, _ in UUID(uuidString: key).map(ids.contains) ?? false }
        guard raw.count != before else { return }
        defaults.set(raw, forKey: DefaultsKey.usageRhythmLog)
        print("🧹 [UsageRhythmLog.prune] 지워진 단축어 기록 \(before - raw.count)개 정리")
    }

    /// 시각 하나를 붙이고 상한만큼만 남긴다 - **순수 함수.**
    static func appending(_ date: Date, to stamps: [Date]) -> [Date] {
        var next = stamps
        next.append(date)
        next.sort()
        if next.count > perMemoLimit { next = Array(next.suffix(perMemoLimit)) }
        return next
    }
}

// MARK: - 판정

enum UsageRhythm {

    /// 알아본 박자.
    enum Pattern: Equatable {
        /// 매달 이 날짜 즈음.
        case monthly(day: Int)
        /// 매달 마지막 주.
        case monthEnd
        /// 매주 이 요일(`Calendar` 기준, 1 = 일요일).
        case weekly(weekday: Int)
        /// 매일 이 시각 즈음(0~23).
        case daily(hour: Int)

        /// 앞에 세울 때의 순서. 드문 박자일수록 앞이다 - 한 달에 한 번 오는 기회를 놓치면
        /// 다음 기회는 한 달 뒤지만, 매일 오는 기회는 내일 또 온다.
        var rank: Int {
            switch self {
            case .monthly, .monthEnd: return 0
            case .weekly: return 1
            case .daily: return 2
            }
        }
    }

    enum Threshold {
        /// 매달·매주로 보려면 서로 다른 달·주가 이만큼은 있어야 한다. 두 번은 우연이다.
        static let periodsMin = 3
        /// 매일로 보려면 서로 다른 날이 이만큼.
        static let daysMin = 4
        /// 같은 자리에 모인 비율. 넷 중 셋.
        static let share = 0.75
        /// 날짜의 너그러움(±일). 월말이 주말이면 하루이틀 당기거나 미룬다.
        static let dayTolerance = 2
        /// 시각의 너그러움(±시간).
        static let hourTolerance = 1
        /// 매달·매주 박자라면 한 기간에 이보다 많이 쓰지 않는다.
        /// 매일 쓰는 단축어를 "매달 말일" 로 오인하지 않게 하는 울타리다(그달의 마지막 사용은
        /// 늘 말일 근처에 있다).
        static let perPeriodMax = 2.0
        /// 매달 박자에서, 이 기간 안에 이미 썼으면 이번 달 몫은 끝난 것으로 본다.
        static let monthlyCooldownDays = 10
        /// 매일 박자에서, 이 시간 안에 이미 썼으면 오늘 몫은 끝난 것으로 본다.
        static let dailyCooldownHours = 3
    }

    // MARK: 박자 알아보기

    /// 시각들에서 박자를 알아본다. 없으면 nil - **순수 함수.**
    static func pattern(of stamps: [Date], calendar: Calendar) -> Pattern? {
        guard !stamps.isEmpty else { return nil }
        if let monthly = monthlyPattern(stamps, calendar: calendar) { return monthly }
        if let weekly = weeklyPattern(stamps, calendar: calendar) { return weekly }
        return dailyPattern(stamps, calendar: calendar)
    }

    private static func monthlyPattern(_ stamps: [Date], calendar: Calendar) -> Pattern? {
        let groups = Dictionary(grouping: stamps) { date -> Int in
            let c = calendar.dateComponents([.year, .month], from: date)
            return (c.year ?? 0) * 100 + (c.month ?? 0)
        }
        guard groups.count >= Threshold.periodsMin else { return nil }
        guard Double(stamps.count) / Double(groups.count) <= Threshold.perPeriodMax else { return nil }

        // 달마다 한 번(그달의 마지막 사용)으로 줄여서 본다.
        let representatives = groups.values.compactMap { $0.max() }
        let total = Double(representatives.count)

        let nearEnd = representatives.filter { date in
            guard let range = calendar.range(of: .day, in: .month, for: date) else { return false }
            return range.count - calendar.component(.day, from: date) < 7
        }
        if Double(nearEnd.count) / total >= Threshold.share { return .monthEnd }

        let days = representatives.map { calendar.component(.day, from: $0) }
        guard let (center, count) = bestCenter(days, tolerance: Threshold.dayTolerance, circular: nil),
              Double(count) / total >= Threshold.share else { return nil }
        return .monthly(day: center)
    }

    private static func weeklyPattern(_ stamps: [Date], calendar: Calendar) -> Pattern? {
        let groups = Dictionary(grouping: stamps) { date -> Int in
            let c = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return (c.yearForWeekOfYear ?? 0) * 100 + (c.weekOfYear ?? 0)
        }
        guard groups.count >= Threshold.periodsMin else { return nil }
        guard Double(stamps.count) / Double(groups.count) <= Threshold.perPeriodMax else { return nil }

        let weekdays = groups.values.compactMap { $0.max() }.map { calendar.component(.weekday, from: $0) }
        let counts = Dictionary(grouping: weekdays, by: { $0 }).mapValues(\.count)
        guard let (weekday, count) = counts.max(by: { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }),
              Double(count) / Double(weekdays.count) >= Threshold.share else { return nil }
        return .weekly(weekday: weekday)
    }

    private static func dailyPattern(_ stamps: [Date], calendar: Calendar) -> Pattern? {
        // 하루에 한 번(그날 처음 쓴 때)으로 줄여서 본다. 한 시간에 열 번 쓴 날이 박자를 독차지하지 않게.
        let groups = Dictionary(grouping: stamps) { calendar.startOfDay(for: $0) }
        guard groups.count >= Threshold.daysMin else { return nil }
        let hours = groups.values.compactMap { $0.min() }.map { calendar.component(.hour, from: $0) }
        guard let (center, count) = bestCenter(hours, tolerance: Threshold.hourTolerance, circular: 24),
              Double(count) / Double(hours.count) >= Threshold.share else { return nil }
        return .daily(hour: center)
    }

    /// 값들 가운데 ±tolerance 안에 가장 많이 모이는 가운데 값과 그 수.
    /// 같은 수면 **정확히 그 값이 더 많은 쪽**, 그래도 같으면 작은 값(결과가 흔들리지 않게).
    /// 23시·0시·23시·23시 는 0시가 아니라 23시다.
    private static func bestCenter(_ values: [Int], tolerance: Int, circular: Int?) -> (Int, Int)? {
        var best: (value: Int, count: Int, exact: Int)?
        for candidate in Set(values).sorted() {
            let count = values.filter { distance($0, candidate, circular: circular) <= tolerance }.count
            let exact = values.filter { $0 == candidate }.count
            if let current = best, (count, exact) <= (current.count, current.exact) { continue }
            best = (candidate, count, exact)
        }
        return best.map { ($0.value, $0.count) }
    }

    private static func distance(_ a: Int, _ b: Int, circular: Int?) -> Int {
        let d = abs(a - b)
        guard let period = circular else { return d }
        return min(d, period - d)
    }

    // MARK: 지금인가

    /// 이 박자로 보아 지금 앞에 세울 때인가 - **순수 함수.**
    /// - Parameter lastUsed: 가장 최근에 쓴 시각. 이번 몫을 이미 썼으면 세우지 않는다.
    static func isDue(_ pattern: Pattern, lastUsed: Date?, now: Date, calendar: Calendar) -> Bool {
        switch pattern {
        case .monthly(let day):
            guard let range = calendar.range(of: .day, in: .month, for: now) else { return false }
            let target = min(day, range.count)
            let today = calendar.component(.day, from: now)
            guard abs(today - target) <= Threshold.dayTolerance else { return false }
            return !used(lastUsed, withinDays: Threshold.monthlyCooldownDays, of: now)

        case .monthEnd:
            guard let range = calendar.range(of: .day, in: .month, for: now) else { return false }
            guard range.count - calendar.component(.day, from: now) < 7 else { return false }
            return !used(lastUsed, withinDays: Threshold.monthlyCooldownDays, of: now)

        case .weekly(let weekday):
            guard calendar.component(.weekday, from: now) == weekday else { return false }
            guard let lastUsed else { return true }
            return !calendar.isDate(lastUsed, inSameDayAs: now)

        case .daily(let hour):
            let current = calendar.component(.hour, from: now)
            guard distance(current, hour, circular: 24) <= Threshold.hourTolerance else { return false }
            guard let lastUsed else { return true }
            return now.timeIntervalSince(lastUsed) >= TimeInterval(Threshold.dailyCooldownHours) * 3600
        }
    }

    private static func used(_ lastUsed: Date?, withinDays days: Int, of now: Date) -> Bool {
        guard let lastUsed else { return false }
        let elapsed = now.timeIntervalSince(lastUsed)
        return elapsed >= 0 && elapsed < TimeInterval(days) * 86_400
    }

    /// 지금 앞에 세울 단축어들. 드문 박자가 앞, 같은 박자면 많이 쓴 것이 앞 - **순수 함수.**
    static func dueMemoIDs(log: [UUID: [Date]],
                           now: Date,
                           calendar: Calendar = .current,
                           limit: Int = 3) -> [UUID] {
        let due: [(id: UUID, rank: Int, count: Int)] = log.compactMap { id, stamps in
            let past = stamps.filter { $0 <= now }
            guard let pattern = pattern(of: past, calendar: calendar),
                  isDue(pattern, lastUsed: past.max(), now: now, calendar: calendar) else { return nil }
            return (id, pattern.rank, past.count)
        }
        return due
            .sorted { ($0.rank, -$0.count, $0.id.uuidString) < ($1.rank, -$1.count, $1.id.uuidString) }
            .prefix(limit)
            .map(\.id)
    }
}
