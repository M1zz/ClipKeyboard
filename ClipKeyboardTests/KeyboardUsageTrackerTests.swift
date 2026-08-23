//
//  KeyboardUsageTrackerTests.swift
//  ClipKeyboardTests
//
//  Created by Claude Code on 2026-06-11.
//  키보드 사용 통계(일일 횟수 + 평생 절약 시간) 테스트.
//
//  사용자 시나리오: 키보드/앱에서 메모를 쓸 때마다 오늘 사용 횟수가 +1,
//  절약 시간이 메모 길이 기반으로 누적된다. 설정의 통계 화면이 이 값을 보여준다.
//

import XCTest
@testable import ClipKeyboard

final class KeyboardUsageTrackerTests: XCTestCase {

    private var groupDefaults: UserDefaults? {
        AppGroup.defaults
    }

    private func dailyKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return "kb.usage.daily." + formatter.string(from: date)
    }

    private var todayKey: String { dailyKey(for: Date()) }

    override func setUp() {
        super.setUp()
        clearStats()
    }

    override func tearDown() {
        clearStats()
        super.tearDown()
    }

    private func clearStats() {
        groupDefaults?.removeObject(forKey: todayKey)
        // 어제 키도 정리 - 전날 테스트 실행이 남긴 잔존값이 시뮬레이터에 누적되어
        // testDailyUsageCount_IsScopedToDate의 "어제 = 0" 단언을 다음 날 깨뜨린다.
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) {
            groupDefaults?.removeObject(forKey: dailyKey(for: yesterday))
        }
        // 내역 조각과 "방금 쓴 것" 기록까지 지운다 - 남아 있으면 다음 실행이
        // 첫 사용을 반복 사용으로 보고 찾아오는 시간을 빼 버린다.
        for key in ["kb.timeSaved.totalSeconds", "kb.timeSaved.retrievalSeconds",
                    "kb.timeSaved.handlingSeconds", "kb.timeSaved.typingSeconds",
                    "kb.timeSaved.verificationSeconds", "kb.timeSaved.baselineSeconds",
                    "kb.timeSaved.tapCostSeconds", "kb.timeSaved.recentUse"] {
            groupDefaults?.removeObject(forKey: key)
        }
        // 잰 타자 속도도 지운다 - 남아 있으면 이 클래스가 기대하는 초가 흔들린다.
        TypingSpeedMeter.reset()
        let allKeys = Array(groupDefaults?.dictionaryRepresentation().keys ?? Dictionary<String, Any>().keys)
        for key in allKeys where key.hasPrefix("kb.ledger.") {
            groupDefaults?.removeObject(forKey: key)
        }
    }

    func testRecordMemoUse_IncrementsTodayCount() {
        // When
        KeyboardUsageTracker.recordMemoUse(value: "안녕하세요 반갑습니다")
        KeyboardUsageTracker.recordMemoUse(value: "두 번째 사용")

        // Then
        XCTAssertEqual(KeyboardUsageTracker.dailyUsageCount(), 2)
    }

    func testRecordMemoUse_AccumulatesTimeSaved() {
        // Given - 40자 메모: 치는 시간 10초 - 탭 값 1초 = 9초. 밑값에 못 미치므로
        // 모자란 21초가 채워져 회당 30초가 된다.
        let fortyChars = String(repeating: "가", count: 40)

        // When
        KeyboardUsageTracker.recordMemoUse(value: fortyChars)
        KeyboardUsageTracker.recordMemoUse(value: fortyChars)

        // Then
        XCTAssertEqual(KeyboardUsageTracker.totalTimeSavedSeconds(),
                       TimeSavedModel.minimumSavedSeconds * 2, accuracy: 0.001)
    }

    func testRecordMemoUse_ShortValue_NeverGoesNegative() {
        // Given - 2자 메모: 0.5초 - 1초 = 음수 → 0으로 clamp
        KeyboardUsageTracker.recordMemoUse(value: "안녕")

        // Then - 절약 시간은 음수가 되면 안 됨 (통계 화면에 마이너스 노출 방지)
        XCTAssertEqual(KeyboardUsageTracker.totalTimeSavedSeconds(), 0.0, accuracy: 0.001)
        XCTAssertEqual(KeyboardUsageTracker.dailyUsageCount(), 1, "횟수는 그래도 1 증가")
    }

    /// 한 번의 수고를 여러 번으로 세지 않는다.
    ///
    /// 계좌번호를 한 서식에 두 번 넣었다고 은행 앱을 두 번 연 것은 아니다. 두 번째는
    /// 값이 이미 손에 있었으므로, 찾아오는 시간과 옮겨 담는 시간이 붙으면 안 된다.
    func testRecordMemoUse_RepeatWithinWindow_DoesNotChargeRetrievalTwice() {
        let account = "110-234-567890"
        let id = UUID()

        KeyboardUsageTracker.recordMemoUse(value: account, type: .bankAccount, memoID: id)
        let afterFirst = KeyboardUsageTracker.totalTimeSavedSeconds()
        KeyboardUsageTracker.recordMemoUse(value: account, type: .bankAccount, memoID: id)
        let afterSecond = KeyboardUsageTracker.totalTimeSavedSeconds()

        let secondUse = afterSecond - afterFirst
        XCTAssertGreaterThan(secondUse, 0, "두 번째도 붙여넣은 것은 맞으니 0은 아니다")
        XCTAssertLessThan(secondUse, afterFirst,
                          "두 번째에도 은행 앱을 여는 값을 물리면 한 번의 수고가 두 번이 된다")
        XCTAssertEqual(secondUse,
                       TimeSavedModel.breakdown(value: account, type: .bankAccount, isRepeat: true).total,
                       accuracy: 0.001)
    }

    /// 다른 문구를 쓴 것은 반복이 아니다. 창이 문구별이 아니면 서로 다른 값을 잇달아
    /// 넣은 사람의 찾아오는 시간이 통째로 사라진다.
    func testRecordMemoUse_DifferentShortcut_IsNotARepeat() {
        let account = "110-234-567890"

        KeyboardUsageTracker.recordMemoUse(value: account, type: .bankAccount, memoID: UUID())
        let afterFirst = KeyboardUsageTracker.totalTimeSavedSeconds()
        KeyboardUsageTracker.recordMemoUse(value: account, type: .bankAccount, memoID: UUID())

        XCTAssertEqual(KeyboardUsageTracker.totalTimeSavedSeconds(), afterFirst * 2, accuracy: 0.001)
    }

    /// 화면이 펼쳐 보이는 내역의 합에서 뺀 값을 빼면 위의 큰 숫자가 나와야 한다.
    /// 안 맞으면 그 화면은 근거가 아니라 거짓말이 된다.
    func testSavedBreakdown_ReconcilesWithTotal() {
        KeyboardUsageTracker.recordMemoUse(value: "서울시 강남구 테헤란로 123", type: .address, memoID: UUID())
        KeyboardUsageTracker.recordMemoUse(value: "1234-5678-9012-3456", type: .creditCard, memoID: UUID())

        let parts = KeyboardUsageTracker.savedBreakdown()

        XCTAssertGreaterThan(parts.tapCost, 0, "뺀 값을 안 쌓으면 줄의 합이 늘 크게 나온다")
        XCTAssertEqual(parts.retrieval + parts.handling + parts.typing
                        + parts.verification + parts.baseline - parts.tapCost,
                       KeyboardUsageTracker.totalTimeSavedSeconds(),
                       accuracy: 0.001)
    }

    /// 아껴 준 것이 없는 사용은 조각도 쌓지 않는다. 합계는 그대로인데 내역만 늘면
    /// 펼친 줄들이 위의 큰 숫자보다 커진다.
    ///
    /// ⚠️ 밑값이 생긴 뒤로 0이 나오는 경우는 **글자 수 문턱 아래**뿐이다. 밑값은 못 센
    ///    것을 채우는 것이지, 안 아낀 것을 아꼈다고 하는 게 아니다.
    func testSavedBreakdown_ZeroNetUse_DoesNotGrowTheParts() {
        KeyboardUsageTracker.recordMemoUse(value: "네", type: .text, memoID: UUID())

        let parts = KeyboardUsageTracker.savedBreakdown()

        XCTAssertEqual(KeyboardUsageTracker.totalTimeSavedSeconds(), 0, accuracy: 0.001)
        XCTAssertEqual(parts.typing, 0, accuracy: 0.001,
                       "합계에 안 들어간 시간이 내역에만 남으면 셈이 안 맞는다")
        XCTAssertEqual(parts.baseline, 0, accuracy: 0.001,
                       "문턱 아래인 것에 밑값을 붙이면 \"네\" 한 글자가 30초가 된다")
        XCTAssertEqual(KeyboardUsageTracker.dailyUsageCount(), 1, "횟수는 그래도 1 증가")
    }

    func testDailyUsageCount_IsScopedToDate() {
        // Given - 오늘 1회 사용
        KeyboardUsageTracker.recordMemoUse(value: "오늘 메모")

        // Then - 어제 날짜로 조회하면 0 (자정에 자연 초기화되는 구조)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertEqual(KeyboardUsageTracker.dailyUsageCount(for: yesterday), 0)
        XCTAssertEqual(KeyboardUsageTracker.dailyUsageCount(), 1)
    }
}

// MARK: - 아낀 시간의 근거

/// ⚠️ 이 테스트들이 지키는 것은 숫자가 아니라 **말이 되는가**이다.
///    상수는 가정이라 언제든 조정될 수 있지만, "계좌번호가 같은 길이의 인사말보다
///    많이 아껴 준다" 같은 관계가 뒤집히면 그건 모델이 틀린 것이다.
final class TimeSavedModelTests: XCTestCase {

    /// ⚠️ 예전에는 "계좌번호가 인사말의 **두 배** 넘게"였다. 밑값이 2분으로 올라가면서
    ///    그 단언은 못 지킨다. 인사말이 이미 120초라 두 배는 240초이고, 그걸 넘기려면
    ///    은행 앱 여는 값을 4분 넘게 잡아야 하는데 그건 변호할 수 없는 숫자다.
    ///    밑값을 높게 잡기로 한 이상 **갈래 사이가 좁아지는 것은 값이 아니라 결과**다.
    ///    그래서 지금 지키는 것은 배수가 아니라 **순서**다.
    func test_찾아와야_하는_값이_같은_길이의_글보다_크다() {
        let length = 20
        let prose = String(repeating: "가", count: length)
        let digits = String(repeating: "1", count: length)

        let greeting = TimeSavedModel.breakdown(value: prose, type: .text).total
        let account = TimeSavedModel.breakdown(value: digits, type: .bankAccount).total

        XCTAssertGreaterThan(account, greeting,
                             "은행 앱을 열어 찾아오던 값이 인사말보다 싸면 모델이 뒤집힌 것이다")
    }

    func test_짧아도_찾아와야_하는_값이면_0이_아니다() {
        // 8자짜리 계좌번호 - 치는 시간만 세면 탭 값에 먹혀 3초가 되고, 밑값이 받친다.
        let short = "12345678"
        XCTAssertEqual(TimeSavedModel.breakdown(value: short, type: .text).total,
                       TimeSavedModel.minimumSavedSeconds, accuracy: 0.001,
                       "못 센 것을 0으로 적지 않는다")
        XCTAssertGreaterThan(TimeSavedModel.breakdown(value: short, type: .bankAccount).total,
                             TimeSavedModel.minimumSavedSeconds,
                             "은행 앱을 열던 값이 밑값과 같아지면 갈래를 나눈 뜻이 없다")
    }

    /// 밑값이 받쳐 주지만, **밑값 위에서는 갈래가 살아 있어야 한다.**
    /// 전부 밑값으로 뭉개지면 이 모델은 상수 하나와 다를 게 없다.
    ///
    /// ⚠️ 밑값이 2분으로 올라가면서 실제로 밑값을 넘는 갈래는 **잠긴 앱과 실물** 둘뿐이다.
    ///    이메일·주소·깃 토큰은 전부 정확히 2분이 된다. 그건 모델이 고장 난 게 아니라
    ///    "제일 조금 아껴도 2분"이라는 약속이 그만큼 세다는 뜻이다. 다만 **그 둘마저**
    ///    밑값과 같아지면 갈래를 나눈 뜻이 사라지므로, 그 선은 여기서 지킨다.
    func test_밑값_위에서는_갈래가_살아_있다() {
        let account = TimeSavedModel.breakdown(value: "110-234-567890", type: .bankAccount).total
        let passport = TimeSavedModel.breakdown(value: "M12345678", type: .passportNumber).total
        let greeting = TimeSavedModel.breakdown(value: "안녕하세요 반갑습니다", type: .text).total

        XCTAssertEqual(greeting, TimeSavedModel.minimumSavedSeconds, accuracy: 0.001)
        XCTAssertGreaterThan(account, TimeSavedModel.minimumSavedSeconds,
                             "은행 앱을 열던 값까지 밑값으로 뭉개지면 갈래를 나눈 뜻이 없다")
        XCTAssertGreaterThan(passport, account,
                             "지갑에서 꺼내 오던 것이 앱에서 꺼내 오던 것보다 싸면 순서가 뒤집힌 것이다")
    }

    /// 저장된 갈래가 없어도 값을 보고 알아낸다.
    ///
    /// ⚠️ `Memo.autoDetectedType` 은 클립보드·공유 시트로 들어온 문구에만 채워진다.
    ///    "문구 추가"에서 계좌번호를 손으로 쳐 넣으면 끝까지 nil 이고, 그러면 이 모델이
    ///    인사말과 똑같이 셌다. 갈래를 나눠 놓고 정작 대부분의 문구에 갈래가 안 붙어
    ///    있던 것이라, 나눈 것이 통째로 죽어 있었다.
    func test_손으로_쳐_넣은_계좌번호도_갈래를_찾아낸다() {
        let account = "110-234-567890"

        XCTAssertEqual(TimeSavedModel.resolvedType(value: account, type: nil), .bankAccount,
                       "갈래가 안 붙은 문구를 그냥 글로 보면 나눠 놓은 갈래가 죽는다")
        XCTAssertEqual(TimeSavedModel.breakdown(value: account, type: nil).total,
                       TimeSavedModel.breakdown(value: account, type: .bankAccount).total,
                       accuracy: 0.001,
                       "같은 값이 어디서 만들어졌는지에 따라 다른 금액이 되면 안 된다")
    }

    /// 이미 갈래가 붙어 있으면 그것을 존중한다. 사용자가 고른 것을 덮어쓰지 않는다.
    func test_붙어_있는_갈래를_덮어쓰지_않는다() {
        XCTAssertEqual(TimeSavedModel.resolvedType(value: "110-234-567890", type: .text), .text)
    }

    func test_밑값은_모자란_만큼만_채운다() {
        // 이미 밑값을 넘긴 값에는 0이 붙는다 - 얹는 게 아니라 채우는 것이다.
        let account = TimeSavedModel.breakdown(value: "110-234-567890", type: .bankAccount)
        XCTAssertEqual(account.baseline, 0, accuracy: 0.001)

        // 못 미치는 값은 정확히 밑값까지만 올라간다.
        let greeting = TimeSavedModel.breakdown(value: "안녕하세요 반갑습니다", type: .text)
        XCTAssertGreaterThan(greeting.baseline, 0)
        XCTAssertEqual(greeting.total, TimeSavedModel.minimumSavedSeconds, accuracy: 0.001)
    }

    /// 사용자가 든 예 - 깃 토큰. 이 앱은 이걸 그냥 "글"로 보기 때문에 찾아오는 시간을
    /// 못 센다. 그렇다고 10초로 적으면 실제로 하던 일(깃허브를 열고 찾아서 복사)과 너무 멀다.
    func test_깃_토큰처럼_분류를_못_하는_값도_밑값은_받는다() {
        let token = "ghp_" + String(repeating: "a1B2", count: 9)
        let saved = TimeSavedModel.breakdown(value: token, type: nil).total

        XCTAssertGreaterThanOrEqual(saved, TimeSavedModel.minimumSavedSeconds,
                                    "못 본 것을 0에 가깝게 적으면 이 앱이 하는 일이 안 보인다")
    }

    func test_숫자는_글보다_치는_데_오래_걸린다() {
        let n = 24
        let prose = TimeSavedModel.breakdown(value: String(repeating: "가", count: n), type: .text)
        let digits = TimeSavedModel.breakdown(value: String(repeating: "7", count: n), type: .text)
        XCTAssertGreaterThan(digits.typing, prose.typing)
    }

    func test_너무_짧은_것은_아예_세지_않는다() {
        XCTAssertEqual(TimeSavedModel.breakdown(value: "네", type: .text), .zero)
        XCTAssertEqual(TimeSavedModel.breakdown(value: "ok", type: .text), .zero)
    }

    func test_내역의_합에서_탭_값을_뺀_것이_총합이다() {
        for value in ["1234-5678-9012-3456", "안녕하세요 반갑습니다"] {
            let b = TimeSavedModel.breakdown(value: value, type: .creditCard)
            XCTAssertEqual(b.total,
                           b.retrieval + b.handling + b.typing + b.verification + b.baseline - b.tapCost,
                           accuracy: 0.001,
                           "화면이 내역을 펼쳐 보이는데 합이 안 맞으면 그 화면은 거짓말이 된다")
        }
    }

    func test_찾아온_값에는_옮겨_담는_시간이_붙는다() {
        // 이 앱이 없애 주는 일의 절반은 "찾은 다음"에 있다
        // 선택하고 복사하고 돌아와서 붙여넣는 손놀림.
        let account = TimeSavedModel.breakdown(value: "110-123-456789", type: .bankAccount)
        XCTAssertGreaterThan(account.handling, 0,
                             "다른 앱에서 가져오던 값이라면 복사·붙여넣기 시간이 반드시 붙는다")

        let greeting = TimeSavedModel.breakdown(value: "안녕하세요, 반갑습니다", type: .text)
        XCTAssertEqual(greeting.handling, 0,
                       "찾아올 곳이 없으면 복사할 원본도 없다")
    }

    func test_실물에서_오는_값은_복사할_수_없다() {
        // 여권은 복사가 안 된다. 눈으로 읽어 손으로 옮겨 적으므로 그 시간은
        // typing 이 이미 세고 있다. handling 까지 붙이면 같은 시간을 두 번 세는 것이다.
        let passport = TimeSavedModel.breakdown(value: "M12345678", type: .passportNumber)
        XCTAssertEqual(passport.handling, 0,
                       "실물에서 오는 값에 복사 시간을 붙이면 같은 시간을 두 번 센다")
        XCTAssertGreaterThan(passport.retrieval, 0)
    }

    func test_아는_값이어도_그냥_치는_것보다는_아껴_준다() {
        // 예전 식은 이메일 한 줄을 "치는 시간 - 탭 값" 으로만 셌다. 실제로 사람이 하던 일은
        // 지난 메일을 열어 주소를 확인하고, 선택해 복사해서 돌아오는 것이었다.
        let email = TimeSavedModel.breakdown(value: "hyunho.lee@example.com", type: .email)
        let sameLengthProse = TimeSavedModel.breakdown(
            value: String(repeating: "가", count: "hyunho.lee@example.com".count), type: .text)
        // ⚠️ 총합끼리 비교하지 않는다. 둘 다 밑값에 받쳐 30초로 같아지기 때문이다
        //    - 밑값 아래에서는 갈래를 안 나눈다는 것이 이 모델의 약속이다.
        //    확인할 것은 **밑값을 걷어낸 몫**이 다른가이다.
        XCTAssertGreaterThan(email.retrieval + email.handling,
                             sameLengthProse.retrieval + sameLengthProse.handling,
                             "이메일이 같은 길이의 인사말과 똑같이 세어지면 모델이 현실을 못 보는 것이다")
    }

    func test_손해_본_것을_이득으로_적지_않는다() {
        // 탭 값보다 적게 아끼는 경우 - 음수가 아니라 0이어야 한다.
        let b = TimeSavedModel.breakdown(value: "1234", type: .text)
        XCTAssertGreaterThanOrEqual(b.total, 0)
    }

    func test_잇달아_쓰면_찾아오는_값을_다시_물리지_않는다() {
        let account = "110-234-567890"
        let first = TimeSavedModel.breakdown(value: account, type: .bankAccount)
        let again = TimeSavedModel.breakdown(value: account, type: .bankAccount, isRepeat: true)

        XCTAssertEqual(again.retrieval, 0, "값은 이미 손에 있었다")
        XCTAssertEqual(again.handling, 0, "이미 꺼내 온 것을 다시 복사하지는 않는다")
        XCTAssertEqual(again.typing, first.typing, accuracy: 0.001,
                       "손으로 옮겨 적는 수고는 두 번째에도 그대로 든다")
        XCTAssertEqual(again.verification, first.verification, accuracy: 0.001,
                       "붙여넣을 때마다 자릿수는 다시 확인한다")
        XCTAssertGreaterThan(again.total, 0, "두 번째도 다시 치지 않은 것은 맞다")
    }

    func test_손으로_옮겨_적을_글이_아니면_그_위는_안_센다() {
        let veryLong = String(repeating: "가", count: 5000)
        let typing = TimeSavedModel.breakdown(value: veryLong, type: .text).typing

        XCTAssertEqual(typing, TimeSavedModel.typingCeilingSeconds, accuracy: 0.001,
                       "탭 한 번에 20분을 아꼈다고 찍으면 나머지 숫자까지 못 믿게 된다")
    }

    func test_상한_아래의_글은_길이만큼_그대로_센다() {
        // 천장이 멀쩡한 길이의 글까지 깎으면 안 된다.
        let paragraph = String(repeating: "가", count: 200)
        XCTAssertEqual(TimeSavedModel.breakdown(value: paragraph, type: .text).typing,
                       200 / TimeSavedModel.proseCharsPerSecond, accuracy: 0.001)
    }

    func test_갈래_분류() {
        XCTAssertEqual(TimeSavedModel.kind(value: "12345678", type: .bankAccount), .lookup)
        XCTAssertEqual(TimeSavedModel.kind(value: String(repeating: "가", count: 80), type: .text), .longText)
        XCTAssertEqual(TimeSavedModel.kind(value: "감사합니다", type: .text), .quick)
        // 시간은 후하게 세되 이름표는 정확하게 - 이메일까지 "찾아와야 했던 것"으로
        // 부르면 그 갈래가 부풀어, 정작 은행 앱을 열던 값이 묻힌다.
        XCTAssertEqual(TimeSavedModel.kind(value: "me@example.com", type: .email), .quick)
    }

    func test_여러_번_쓰면_그만큼_곱해진다() {
        let one = TimeSavedModel.breakdown(value: "서울시 강남구 테헤란로 123", type: .address)
        let five = TimeSavedModel.breakdown(value: "서울시 강남구 테헤란로 123", type: .address, useCount: 5)
        XCTAssertEqual(five.total, one.total * 5, accuracy: 0.001)
    }
}

// MARK: - 이정표

final class SavedTimeMilestoneTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SavedTimeMilestone.resetAll()
    }

    override func tearDown() {
        SavedTimeMilestone.resetAll()
        super.tearDown()
    }

    func test_넘어선_것_중_가장_큰_것_하나만_축하한다() {
        // 한 시간을 한 번에 넘겼다면 1분·5분·15분을 줄줄이 띄우지 않는다.
        let reached = SavedTimeMilestone.newlyReached(totalSeconds: 3600)
        XCTAssertEqual(reached, .oneHour)
    }

    func test_한_번_축하한_것은_다시_뜨지_않는다() {
        guard let first = SavedTimeMilestone.newlyReached(totalSeconds: 300) else {
            return XCTFail("5분을 넘겼으면 이정표가 나와야 한다")
        }
        SavedTimeMilestone.markReached(upTo: first)
        XCTAssertNil(SavedTimeMilestone.newlyReached(totalSeconds: 300),
                     "볼 때마다 축하하면 축하가 아니라 배너다")
    }

    func test_건너뛴_작은_칸이_뒤늦게_튀어나오지_않는다() {
        SavedTimeMilestone.markReached(upTo: .oneHour)
        // 그 뒤 잔고가 줄어든 것처럼 보여도(기기 이전 등) 작은 칸이 새로 뜨면 안 된다.
        XCTAssertNil(SavedTimeMilestone.newlyReached(totalSeconds: 120))
    }

    func test_아직_못_넘긴_칸은_나오지_않는다() {
        XCTAssertNil(SavedTimeMilestone.newlyReached(totalSeconds: 10))
    }
}
