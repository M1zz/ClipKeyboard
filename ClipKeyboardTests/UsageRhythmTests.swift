//
//  UsageRhythmTests.swift
//  ClipKeyboardTests
//
//  "같은 때 쓰는 단축어" 를 알아보는 판정.
//  알아봐야 하는 경우만큼 **알아보면 안 되는 경우**(매일 쓰는 것을 매달로 오인)를 적었다.
//

import Testing
import Foundation
@testable import ClipKeyboard

struct UsageRhythmTests {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 10, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // MARK: - 박자 알아보기

    @Test("세 달 연속 같은 날짜 즈음 쓰면 매달이다")
    func monthlyDay() {
        let stamps = [date(2026, 6, 15), date(2026, 7, 16), date(2026, 8, 14)]
        #expect(UsageRhythm.pattern(of: stamps, calendar: calendar) == .monthly(day: 14))
    }

    @Test("세 달 모두 마지막 주에 쓰면 월말이다")
    func monthEnd() {
        let stamps = [date(2026, 6, 29), date(2026, 7, 27), date(2026, 8, 31)]
        #expect(UsageRhythm.pattern(of: stamps, calendar: calendar) == .monthEnd)
    }

    @Test("두 달뿐이면 우연이다")
    func twoMonthsIsNotARhythm() {
        let stamps = [date(2026, 7, 15), date(2026, 8, 15)]
        #expect(UsageRhythm.pattern(of: stamps, calendar: calendar) == nil)
    }

    @Test("매일 쓰는 단축어를 월말로 오인하지 않는다")
    func dailyUseIsNotMonthEnd() {
        // 석 달 동안 한 달에 여러 번 - 그달의 마지막 사용은 늘 말일 근처에 있다.
        var stamps: [Date] = []
        for month in 6...8 {
            for day in [3, 9, 14, 20, 27, 29] { stamps.append(date(2026, month, day, 10 + day % 5)) }
        }
        let pattern = UsageRhythm.pattern(of: stamps, calendar: calendar)
        #expect(pattern != .monthEnd)
        if case .monthly = pattern { Issue.record("매달로 오인했다: \(String(describing: pattern))") }
    }

    @Test("서로 다른 세 주의 금요일에 쓰면 매주 금요일이다")
    func weeklyFriday() {
        // 2026-08-28, 09-04, 09-11 은 금요일
        let stamps = [date(2026, 8, 28, 17), date(2026, 9, 4, 18), date(2026, 9, 11, 17)]
        #expect(UsageRhythm.pattern(of: stamps, calendar: calendar) == .weekly(weekday: 6))
    }

    @Test("요일이 흩어져 있으면 매주가 아니다")
    func scatteredWeekdays() {
        let stamps = [date(2026, 8, 24), date(2026, 9, 2), date(2026, 9, 10), date(2026, 9, 17)]
        let pattern = UsageRhythm.pattern(of: stamps, calendar: calendar)
        if case .weekly = pattern { Issue.record("매주로 오인했다") }
    }

    @Test("네 날 이상 같은 시각에 쓰면 매일 그 시각이다")
    func dailyHour() {
        let stamps = (10...14).map { date(2026, 9, $0, 9, 5) }
        #expect(UsageRhythm.pattern(of: stamps, calendar: calendar) == .daily(hour: 9))
    }

    @Test("자정을 넘나드는 시각도 한 무리로 본다")
    func dailyHourWrapsMidnight() {
        let stamps = [date(2026, 9, 10, 23), date(2026, 9, 11, 0), date(2026, 9, 12, 23), date(2026, 9, 13, 23)]
        #expect(UsageRhythm.pattern(of: stamps, calendar: calendar) == .daily(hour: 23))
    }

    // MARK: - 지금인가

    @Test("매달 박자는 그 날짜 ±2일에만 차례다")
    func monthlyDueWindow() {
        let p = UsageRhythm.Pattern.monthly(day: 15)
        #expect(UsageRhythm.isDue(p, lastUsed: date(2026, 8, 15), now: date(2026, 9, 13), calendar: calendar))
        #expect(!UsageRhythm.isDue(p, lastUsed: date(2026, 8, 15), now: date(2026, 9, 12), calendar: calendar))
    }

    @Test("이번 달 몫을 이미 썼으면 차례가 아니다")
    func monthlyCooldown() {
        let p = UsageRhythm.Pattern.monthly(day: 15)
        #expect(!UsageRhythm.isDue(p, lastUsed: date(2026, 9, 14), now: date(2026, 9, 16), calendar: calendar))
    }

    @Test("31일에 쓰던 것은 30일까지인 달에는 30일 즈음이다")
    func monthlyClampsToShortMonth() {
        let p = UsageRhythm.Pattern.monthly(day: 31)
        #expect(UsageRhythm.isDue(p, lastUsed: date(2026, 8, 31), now: date(2026, 9, 30), calendar: calendar))
    }

    @Test("매주 박자는 그 요일에, 오늘 아직 안 썼을 때만")
    func weeklyDue() {
        let p = UsageRhythm.Pattern.weekly(weekday: 6)
        let friday = date(2026, 9, 18, 16)
        #expect(UsageRhythm.isDue(p, lastUsed: date(2026, 9, 11), now: friday, calendar: calendar))
        #expect(!UsageRhythm.isDue(p, lastUsed: date(2026, 9, 18, 9), now: friday, calendar: calendar))
        #expect(!UsageRhythm.isDue(p, lastUsed: date(2026, 9, 11), now: date(2026, 9, 17), calendar: calendar))
    }

    @Test("매일 박자는 그 시각 ±1시간, 세 시간 안에 쓴 적이 없을 때")
    func dailyDue() {
        let p = UsageRhythm.Pattern.daily(hour: 9)
        #expect(UsageRhythm.isDue(p, lastUsed: date(2026, 9, 16, 9), now: date(2026, 9, 17, 8, 30), calendar: calendar))
        #expect(!UsageRhythm.isDue(p, lastUsed: date(2026, 9, 17, 8), now: date(2026, 9, 17, 9, 30), calendar: calendar))
        #expect(!UsageRhythm.isDue(p, lastUsed: nil, now: date(2026, 9, 17, 12), calendar: calendar))
    }

    // MARK: - 줄 세우기

    @Test("드문 박자가 앞에 선다")
    func dueOrderPrefersRarerRhythm() {
        let monthly = UUID(), daily = UUID()
        let log: [UUID: [Date]] = [
            daily: (10...16).map { date(2026, 9, $0, 17) },
            monthly: [date(2026, 6, 18), date(2026, 7, 17), date(2026, 8, 18)]
        ]
        let now = date(2026, 9, 18, 17, 30)
        #expect(UsageRhythm.dueMemoIDs(log: log, now: now, calendar: calendar) == [monthly, daily])
    }

    @Test("미래 시각은 판정에 넣지 않는다")
    func ignoresFutureStamps() {
        let id = UUID()
        let log: [UUID: [Date]] = [id: [date(2026, 6, 15), date(2026, 7, 15), date(2026, 10, 15)]]
        #expect(UsageRhythm.dueMemoIDs(log: log, now: date(2026, 9, 15), calendar: calendar).isEmpty)
    }

    @Test("기록은 상한만큼만 남고 오래된 것부터 빠진다")
    func logIsCapped() {
        var stamps: [Date] = []
        for i in 0..<(UsageRhythmLog.perMemoLimit + 5) {
            stamps = UsageRhythmLog.appending(date(2026, 1, 1).addingTimeInterval(Double(i) * 3600), to: stamps)
        }
        #expect(stamps.count == UsageRhythmLog.perMemoLimit)
        #expect(stamps.first == date(2026, 1, 1).addingTimeInterval(5 * 3600))
    }
}
