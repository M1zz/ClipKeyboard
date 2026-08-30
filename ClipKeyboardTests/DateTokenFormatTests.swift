//
//  DateTokenFormatTests.swift
//  ClipKeyboardTests
//
//  `{날짜}` 가 어떤 모양으로 들어가는지 고정한다.
//
//  왜 생겼나: 미국 사용자 피드백.
//
//    Can the Date variable be changed to display in different formats?
//    We use Month-Day-Year in the US.
//
//  그때까지 `{날짜}` 는 어디서나 `yyyy-MM-dd` 였다. 날짜를 대신 넣어 주는 기능인데
//  그 나라 모양이 아니면 결국 손으로 고치게 된다.
//
//  여기서 지키는 약속.
//   ① 고른 모양이 그대로 들어간다
//   ② 자동은 **언어·지역에 따라 다르다** (미국 08/31 · 영국 31/08 · 한국 2026-08-31)
//   ③ 한국어·중국어·일본어의 자동값은 예전 그대로다 (쓰던 사람의 결과가 안 바뀐다)
//   ④ 넣은 글자를 다시 날짜로 읽을 수 있다 (모양을 바꿔도 고른 날짜가 안 날아간다)
//

import XCTest
@testable import ClipKeyboard

final class DateTokenFormatTests: XCTestCase {

    /// 2026-08-31
    private var sample: Date {
        var c = DateComponents()
        c.year = 2026; c.month = 8; c.day = 31; c.hour = 12
        return Calendar.current.date(from: c)!
    }

    private var saved: String?

    override func setUp() {
        super.setUp()
        saved = AppGroup.defaults?.string(forKey: DefaultsKey.templateDateFormat)
    }

    /// ⚠️ 이 값은 App Group 에 진짜로 적힌다. 시험이 쓴 값을 남기면 안 된다.
    override func tearDown() {
        if let saved {
            AppGroup.defaults?.set(saved, forKey: DefaultsKey.templateDateFormat)
        } else {
            AppGroup.defaults?.removeObject(forKey: DefaultsKey.templateDateFormat)
        }
        super.tearDown()
    }

    // MARK: - ① 고른 모양이 그대로 들어간다

    func test_고른_모양대로_적힌다() {
        let us = Locale(identifier: "en_US")
        XCTAssertEqual(DateTokenFormat.isoDash.string(from: sample, locale: us), "2026-08-31")
        XCTAssertEqual(DateTokenFormat.monthDayYear.string(from: sample, locale: us), "08/31/2026")
        XCTAssertEqual(DateTokenFormat.dayMonthYear.string(from: sample, locale: us), "31/08/2026")
        XCTAssertEqual(DateTokenFormat.yearMonthDayDot.string(from: sample, locale: us), "2026. 08. 31.")
    }

    /// 긴 모양은 언어를 탄다. 패턴을 고정하지 않고 "그 언어로 읽히는가"만 본다.
    func test_긴_모양은_언어를_탄다() {
        let en = DateTokenFormat.long.string(from: sample, locale: Locale(identifier: "en_US"))
        let ko = DateTokenFormat.long.string(from: sample, locale: Locale(identifier: "ko_KR"))
        XCTAssertTrue(en.contains("2026"))
        XCTAssertTrue(ko.contains("2026"))
        XCTAssertNotEqual(en, ko, "긴 모양인데 언어가 달라도 같으면 현지화가 안 된 것이다")
    }

    // MARK: - ② 자동은 언어·지역에 따라 다르다

    func test_자동은_미국에서_월일년이다() {
        let out = DateTokenFormat.automatic.string(from: sample, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(out, "08/31/2026", "미국 사용자가 이걸 요청했다")
    }

    func test_자동은_영국에서_일월년이다() {
        let out = DateTokenFormat.automatic.string(from: sample, locale: Locale(identifier: "en_GB"))
        XCTAssertEqual(out, "31/08/2026", "같은 영어라도 지역이 다르면 순서가 다르다")
    }

    func test_자동은_독일에서_점으로_나눈다() {
        let out = DateTokenFormat.automatic.string(from: sample, locale: Locale(identifier: "de_DE"))
        XCTAssertEqual(out, "31.08.2026")
    }

    func test_자동은_두자리_연도를_쓰지_않는다() {
        for id in ["en_US", "en_GB", "de_DE", "fr_FR", "es_ES", "ko_KR"] {
            let out = DateTokenFormat.automatic.string(from: sample, locale: Locale(identifier: id))
            XCTAssertTrue(out.contains("2026"),
                          "\(id): 연도가 네 자리여야 한다(26 이면 문서에 남았을 때 읽기 어렵다) - \(out)")
        }
    }

    // MARK: - ③ 쓰던 사람의 결과는 안 바뀐다

    func test_한국어_중국어_일본어의_자동값은_예전_그대로다() {
        for id in ["ko_KR", "ko_US", "zh_Hans_CN", "zh_Hant_TW", "ja_JP"] {
            XCTAssertEqual(DateTokenFormat.automatic.string(from: sample, locale: Locale(identifier: id)),
                           "2026-08-31",
                           "\(id): 요청은 '미국이 어색하다'였지 '한국을 바꿔 달라'가 아니었다")
        }
    }

    /// ⚠️ 이 클래스가 **이 값을 만지는 유일한 곳**이다. 여러 곳에서 만지면 나란히 도는
    ///    시험끼리 부딪힌다. 다른 곳은 `process(dateFormat:)` 로 넘겨서 시험한다.
    func test_고른_적이_없으면_자동이다() {
        AppGroup.defaults?.removeObject(forKey: DefaultsKey.templateDateFormat)
        XCTAssertEqual(DateTokenFormat.current, .automatic)
    }

    /// 키보드 익스텐션은 **다른 프로세스**다. App Group 이 아니면 이 값을 영영 못 본다.
    func test_고른_모양은_App_Group_에_적힌다() {
        DateTokenFormat.current = .monthDayYear

        XCTAssertEqual(AppGroup.defaults?.string(forKey: DefaultsKey.templateDateFormat),
                       DateTokenFormat.monthDayYear.rawValue,
                       "표준 UserDefaults 에 적으면 키보드는 이 값을 못 본다")
        XCTAssertEqual(DateTokenFormat.current, .monthDayYear)
    }

    func test_알_수_없는_값이_적혀_있어도_자동으로_돈다() {
        AppGroup.defaults?.set("이건 없는 값", forKey: DefaultsKey.templateDateFormat)
        XCTAssertEqual(DateTokenFormat.current, .automatic)
    }

    // MARK: - ④ 다시 날짜로 읽을 수 있다

    func test_어떤_모양으로_적혔든_다시_읽는다() {
        for format in DateTokenFormat.allCases {
            let text = format.string(from: sample, locale: Locale(identifier: "en_US"))
            let back = DateTokenFormat.date(from: text, locale: Locale(identifier: "en_US"))
            XCTAssertNotNil(back, "\(format.rawValue): '\(text)' 를 다시 못 읽으면 고른 날짜가 날아간다")
        }
    }

    /// 모양을 바꾼 **뒤에도** 예전 모양으로 적힌 값을 읽어야 한다.
    func test_모양을_바꿔도_예전_글자를_읽는다() {
        DateTokenFormat.current = .monthDayYear
        let old = DateTokenFormat.isoDash.string(from: sample, locale: Locale(identifier: "en_US"))

        let back = DateTokenFormat.date(from: old, locale: Locale(identifier: "en_US"))

        XCTAssertNotNil(back, "'\(old)' 는 예전 모양이지만 여전히 사용자가 고른 날짜다")
    }

    // MARK: - 시간 (같은 규칙)

    func test_시간도_고른_모양대로_적힌다() {
        var c = DateComponents()
        c.year = 2026; c.month = 8; c.day = 31; c.hour = 21; c.minute = 57; c.second = 3
        let evening = Calendar.current.date(from: c)!
        let us = Locale(identifier: "en_US")

        XCTAssertEqual(TimeTokenFormat.twentyFour.string(from: evening, locale: us), "21:57")
        XCTAssertEqual(TimeTokenFormat.twentyFourWithSeconds.string(from: evening, locale: us), "21:57:03")
        XCTAssertTrue(TimeTokenFormat.twelveHour.string(from: evening, locale: us).hasPrefix("9:57"))
    }

    func test_시간_자동은_미국에서_열두시간제다() {
        var c = DateComponents()
        c.year = 2026; c.month = 8; c.day = 31; c.hour = 21; c.minute = 57
        let evening = Calendar.current.date(from: c)!

        let us = TimeTokenFormat.automatic.string(from: evening, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(us.contains("9:57"), "미국은 오후 9시를 21시라고 안 적는다 - \(us)")
        XCTAssertFalse(us.contains("21"), us)
    }

    func test_시간_자동은_한국_중국_일본에서_예전_그대로다() {
        var c = DateComponents()
        c.year = 2026; c.month = 8; c.day = 31; c.hour = 21; c.minute = 57; c.second = 3
        let evening = Calendar.current.date(from: c)!

        for id in ["ko_KR", "zh_Hans_CN", "ja_JP"] {
            XCTAssertEqual(TimeTokenFormat.automatic.string(from: evening, locale: Locale(identifier: id)),
                           "21:57:03", "\(id): 쓰던 사람의 결과가 갑자기 달라지면 안 된다")
        }
    }

    func test_시간_모양도_App_Group_에_적힌다() {
        let saved = AppGroup.defaults?.string(forKey: DefaultsKey.templateTimeFormat)
        defer {
            if let saved { AppGroup.defaults?.set(saved, forKey: DefaultsKey.templateTimeFormat) }
            else { AppGroup.defaults?.removeObject(forKey: DefaultsKey.templateTimeFormat) }
        }
        TimeTokenFormat.current = .twelveHour
        XCTAssertEqual(AppGroup.defaults?.string(forKey: DefaultsKey.templateTimeFormat),
                       TimeTokenFormat.twelveHour.rawValue)
    }

    // MARK: - 고르는 화면

    func test_보기_이름은_오늘_날짜를_그린다() {
        // 패턴 글자("MM/DD/YYYY")는 개발자만 읽는다. 실제 날짜는 누구나 읽는다.
        XCTAssertFalse(DateTokenFormat.isoDash.sampleText.contains("yyyy"))
        XCTAssertTrue(DateTokenFormat.isoDash.sampleText.contains("-"))
    }
}
