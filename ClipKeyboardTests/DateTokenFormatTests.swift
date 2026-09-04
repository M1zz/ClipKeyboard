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
    private var savedCustoms: Data?

    override func setUp() {
        super.setUp()
        saved = AppGroup.defaults?.string(forKey: DefaultsKey.templateDateFormat)
        savedCustoms = AppGroup.defaults?.data(forKey: DefaultsKey.templateDateCustomFormats)
    }

    /// ⚠️ 이 값은 App Group 에 진짜로 적힌다. 시험이 쓴 값을 남기면 안 된다.
    override func tearDown() {
        if let saved {
            AppGroup.defaults?.set(saved, forKey: DefaultsKey.templateDateFormat)
        } else {
            AppGroup.defaults?.removeObject(forKey: DefaultsKey.templateDateFormat)
        }
        if let savedCustoms {
            AppGroup.defaults?.set(savedCustoms, forKey: DefaultsKey.templateDateCustomFormats)
        } else {
            AppGroup.defaults?.removeObject(forKey: DefaultsKey.templateDateCustomFormats)
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
        XCTAssertEqual(DateTokenFormat.selection, TokenFormatOption(builtin: .automatic))
    }

    /// 키보드 익스텐션은 **다른 프로세스**다. App Group 이 아니면 이 값을 영영 못 본다.
    func test_고른_모양은_App_Group_에_적힌다() {
        DateTokenFormat.selection = TokenFormatOption(builtin: .monthDayYear)

        XCTAssertEqual(AppGroup.defaults?.string(forKey: DefaultsKey.templateDateFormat),
                       DateTokenFormat.monthDayYear.rawValue,
                       "표준 UserDefaults 에 적으면 키보드는 이 값을 못 본다")
        XCTAssertEqual(DateTokenFormat.selection, TokenFormatOption(builtin: .monthDayYear))
    }

    func test_알_수_없는_값이_적혀_있어도_자동으로_돈다() {
        AppGroup.defaults?.set("이건 없는 값", forKey: DefaultsKey.templateDateFormat)
        XCTAssertEqual(DateTokenFormat.selection, TokenFormatOption(builtin: .automatic))
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
        DateTokenFormat.selection = TokenFormatOption(builtin: .monthDayYear)
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
        TimeTokenFormat.selection = TokenFormatOption(builtin: .twelveHour)
        XCTAssertEqual(AppGroup.defaults?.string(forKey: DefaultsKey.templateTimeFormat),
                       TimeTokenFormat.twelveHour.rawValue)
    }

    // MARK: - 고르는 화면

    func test_보기_이름은_오늘_날짜를_그린다() {
        // 패턴 글자("MM/DD/YYYY")는 개발자만 읽는다. 실제 날짜는 누구나 읽는다.
        XCTAssertFalse(DateTokenFormat.isoDash.sampleText.contains("yyyy"))
        XCTAssertTrue(DateTokenFormat.isoDash.sampleText.contains("-"))
    }
    // MARK: - ⑤ 사람이 자기 모양을 만든다

    /// 준비한 대여섯 가지로 세상이 날짜 적는 법을 다 덮을 수 없다. 못 만들면 손으로 고쳐 쓰게 된다.
    func test_만든_모양이_그대로_들어간다() {
        DateTokenFormat.customPatterns = []
        XCTAssertTrue(DateTokenFormat.addCustomPattern("dd.MM.yy"))

        let option = TokenFormatOption<DateTokenFormat>(customPattern: "dd.MM.yy")
        XCTAssertEqual(option.string(from: sample, locale: Locale(identifier: "en_US")), "31.08.26")
    }

    /// 키보드 익스텐션은 **다른 프로세스**다. App Group 이 아니면 만든 서식을 영영 못 본다.
    func test_만든_모양은_App_Group_에_적힌다() {
        DateTokenFormat.customPatterns = []
        DateTokenFormat.addCustomPattern("yyyy'년' M'월'")

        XCTAssertNotNil(AppGroup.defaults?.data(forKey: DefaultsKey.templateDateCustomFormats),
                        "표준 UserDefaults 에 적으면 키보드는 이 서식을 못 본다")
        XCTAssertEqual(DateTokenFormat.customPatterns, ["yyyy'년' M'월'"])
    }

    func test_쓸_수_없는_모양은_안_받는다() {
        DateTokenFormat.customPatterns = []
        XCTAssertFalse(DateTokenFormat.addCustomPattern(""), "빈 것")
        XCTAssertFalse(DateTokenFormat.addCustomPattern("   "), "공백뿐")
        XCTAssertFalse(DateTokenFormat.addCustomPattern("오늘의 날짜"),
                       "날짜 글자가 없으면 언제 넣어도 같은 글자만 나온다")
        XCTAssertFalse(DateTokenFormat.addCustomPattern("'yyyy'"),
                       "따옴표 안은 그대로 찍히는 글자라 서식이 아니다")
        XCTAssertTrue(DateTokenFormat.customPatterns.isEmpty)
    }

    func test_같은_모양을_두_번_넣지_않는다() {
        DateTokenFormat.customPatterns = []
        XCTAssertTrue(DateTokenFormat.addCustomPattern("dd.MM.yy"))
        XCTAssertFalse(DateTokenFormat.addCustomPattern("dd.MM.yy"))
        XCTAssertEqual(DateTokenFormat.customPatterns.count, 1)
    }

    /// 지운 서식을 가리킨 채로 남으면 날짜 자리가 빈칸이 된다.
    func test_고른_모양을_지우면_자동으로_돌아온다() {
        DateTokenFormat.customPatterns = []
        DateTokenFormat.addCustomPattern("dd.MM.yy")
        DateTokenFormat.selection = TokenFormatOption(customPattern: "dd.MM.yy")

        DateTokenFormat.removeCustomPattern("dd.MM.yy")

        XCTAssertEqual(DateTokenFormat.selection, TokenFormatOption(builtin: .automatic))
    }

    /// 다른 기기에서 지운 서식을 이 기기가 가리키고 있을 수 있다.
    func test_없는_모양을_가리키면_자동으로_읽는다() {
        DateTokenFormat.customPatterns = []
        AppGroup.defaults?.set("custom:dd.MM.yy", forKey: DefaultsKey.templateDateFormat)

        XCTAssertEqual(DateTokenFormat.selection, TokenFormatOption(builtin: .automatic))
    }

    /// 만든 모양으로 적힌 글자도 다시 날짜로 읽어야 한다. 못 읽으면 고른 날짜가 오늘로 되돌아간다.
    func test_만든_모양으로_적힌_글자도_다시_읽는다() {
        DateTokenFormat.customPatterns = []
        DateTokenFormat.addCustomPattern("dd.MM.yyyy")
        let us = Locale(identifier: "en_US")
        let text = TokenFormatOption<DateTokenFormat>(customPattern: "dd.MM.yyyy").string(from: sample, locale: us)

        XCTAssertNotNil(DateTokenFormat.date(from: text, locale: us),
                        "'\(text)' 는 사용자가 만든 모양이지만 여전히 그 사람이 고른 날짜다")
    }

    /// `{날짜}` 를 실제로 바꿔 넣는 자리까지 이어지는지.
    func test_만든_모양이_토큰에_들어간다() {
        let option = TokenFormatOption<DateTokenFormat>(customPattern: "dd.MM.yy")
        let out = TemplateVariableProcessor.process("오늘은 {날짜} 입니다", at: sample, dateFormat: option)
        XCTAssertEqual(out, "오늘은 31.08.26 입니다")
    }

    func test_모양은_열_개까지만_쌓인다() {
        DateTokenFormat.customPatterns = []
        for i in 1...12 {
            DateTokenFormat.addCustomPattern("yyyy-MM-dd'\(i)'")
        }
        XCTAssertEqual(DateTokenFormat.customPatterns.count, DateTokenFormat.maxCustomPatterns)
    }
}

// MARK: - 빈칸 한 칸씩 채우기

/// 키보드에서 빈칸이 여럿일 때 **다음에 펼칠 칸**을 고르는 규칙.
///
/// 왜 생겼나: 사용자 요청. "빈칸이 여러 개일 때 스크롤이 번거로워서요."
/// 키보드는 약 290pt 인데 빈칸 한 칸이 102pt 라 두 개도 다 안 보인다.
/// 한 칸만 펼치기로 했고, 그러면 **다음 칸으로 저절로 넘어가야** 손해가 아니다.
final class NextUnfilledPlaceholderTests: XCTestCase {

    private let all = ["{금액}", "{수신인}", "{IBAN}", "{SWIFT}"]

    func test_아무것도_안_채웠으면_첫_칸이다() {
        let next = TemplateInputState.nextUnfilled(in: all, inputs: [:], after: nil)
        XCTAssertEqual(next, "{금액}")
    }

    func test_채우면_바로_다음_칸으로_간다() {
        let next = TemplateInputState.nextUnfilled(in: all, inputs: ["{금액}": "10000"], after: "{금액}")
        XCTAssertEqual(next, "{수신인}")
    }

    /// 사람은 셋째 칸을 먼저 누를 수 있다. 그 다음은 넷째가 아니라 **아직 빈 첫째**다.
    /// 순서대로만 가면 건너뛴 칸이 영영 안 펼쳐지고, 왜 입력하기가 안 눌리는지 모르게 된다.
    func test_건너뛴_칸으로_되돌아온다() {
        let inputs = ["{IBAN}": "DE89", "{SWIFT}": "COBADEFF"]
        let next = TemplateInputState.nextUnfilled(in: all, inputs: inputs, after: "{SWIFT}")
        XCTAssertEqual(next, "{금액}", "뒤에 빈 칸이 없으면 앞으로 돌아가 찾아야 한다")
    }

    func test_이미_채운_칸은_건너뛴다() {
        let inputs = ["{금액}": "10000", "{수신인}": "홍길동"]
        let next = TemplateInputState.nextUnfilled(in: all, inputs: inputs, after: "{금액}")
        XCTAssertEqual(next, "{IBAN}")
    }

    /// 다 채웠으면 아무것도 펼치지 않는다. 그때는 채운 값이 한눈에 보이고 입력하기만 남는다.
    func test_다_채웠으면_펼칠_칸이_없다() {
        let inputs = ["{금액}": "1", "{수신인}": "2", "{IBAN}": "3", "{SWIFT}": "4"]
        XCTAssertNil(TemplateInputState.nextUnfilled(in: all, inputs: inputs, after: "{SWIFT}"))
        XCTAssertNil(TemplateInputState.nextUnfilled(in: all, inputs: inputs, after: nil))
    }

    /// 빈 값으로 적힌 것은 안 채운 것이다.
    func test_빈_문자열은_안_채운_것으로_본다() {
        let next = TemplateInputState.nextUnfilled(in: all, inputs: ["{금액}": ""], after: nil)
        XCTAssertEqual(next, "{금액}")
    }

    func test_빈칸이_없으면_nil() {
        XCTAssertNil(TemplateInputState.nextUnfilled(in: [], inputs: [:], after: nil))
    }

    /// 다른 템플릿을 열어 목록이 바뀌면, 앞 템플릿의 칸을 가리킨 채로 남을 수 있다.
    func test_목록에_없는_칸을_가리켜도_처음부터_찾는다() {
        let next = TemplateInputState.nextUnfilled(in: all, inputs: [:], after: "{옛날칸}")
        XCTAssertEqual(next, "{금액}")
    }
}
