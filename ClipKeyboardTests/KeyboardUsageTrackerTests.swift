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
        groupDefaults?.removeObject(forKey: "kb.timeSaved.totalSeconds")
    }

    func testRecordMemoUse_IncrementsTodayCount() {
        // When
        KeyboardUsageTracker.recordMemoUse(value: "안녕하세요 반갑습니다")
        KeyboardUsageTracker.recordMemoUse(value: "두 번째 사용")

        // Then
        XCTAssertEqual(KeyboardUsageTracker.dailyUsageCount(), 2)
    }

    func testRecordMemoUse_AccumulatesTimeSaved() {
        // Given - 40자 메모: 40자 ÷ 4자/초 - 1초(탭 오버헤드) = 9초 절약
        let fortyChars = String(repeating: "가", count: 40)

        // When
        KeyboardUsageTracker.recordMemoUse(value: fortyChars)
        KeyboardUsageTracker.recordMemoUse(value: fortyChars)

        // Then
        XCTAssertEqual(KeyboardUsageTracker.totalTimeSavedSeconds(), 18.0, accuracy: 0.001)
    }

    func testRecordMemoUse_ShortValue_NeverGoesNegative() {
        // Given - 2자 메모: 0.5초 - 1초 = 음수 → 0으로 clamp
        KeyboardUsageTracker.recordMemoUse(value: "안녕")

        // Then - 절약 시간은 음수가 되면 안 됨 (통계 화면에 마이너스 노출 방지)
        XCTAssertEqual(KeyboardUsageTracker.totalTimeSavedSeconds(), 0.0, accuracy: 0.001)
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

    func test_찾아와야_하는_값이_같은_길이의_글보다_크다() {
        let length = 20
        let prose = String(repeating: "가", count: length)
        let digits = String(repeating: "1", count: length)

        let greeting = TimeSavedModel.breakdown(value: prose, type: .text).total
        let account = TimeSavedModel.breakdown(value: digits, type: .bankAccount).total

        XCTAssertGreaterThan(account, greeting * 2,
                             "은행 앱을 열어 찾아오던 값이 인사말과 비슷하게 세어지면 모델이 틀린 것이다")
    }

    func test_짧아도_찾아와야_하는_값이면_0이_아니다() {
        // 8자짜리 계좌번호 - 치는 시간만 세면 탭 값에 먹혀 0이 된다.
        let short = "12345678"
        XCTAssertEqual(TimeSavedModel.breakdown(value: short, type: .text).total,
                       max(0, 8 / TimeSavedModel.digitCharsPerSecond - 1), accuracy: 0.001)
        XCTAssertGreaterThan(TimeSavedModel.breakdown(value: short, type: .bankAccount).total, 30,
                             "짧다고 0으로 세면 이 앱이 가장 쓸모 있는 경우를 못 센다")
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
        let b = TimeSavedModel.breakdown(value: "1234-5678-9012-3456", type: .creditCard)
        XCTAssertEqual(b.total,
                       b.retrieval + b.handling + b.typing + b.verification - b.tapCost,
                       accuracy: 0.001,
                       "화면이 내역을 펼쳐 보이는데 합이 안 맞으면 그 화면은 거짓말이 된다")
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
        XCTAssertGreaterThan(email.total, sameLengthProse.total * 2,
                             "이메일이 같은 길이의 인사말과 비슷하게 세어지면 모델이 현실을 못 보는 것이다")
    }

    func test_손해_본_것을_이득으로_적지_않는다() {
        // 탭 값보다 적게 아끼는 경우 - 음수가 아니라 0이어야 한다.
        let b = TimeSavedModel.breakdown(value: "1234", type: .text)
        XCTAssertGreaterThanOrEqual(b.total, 0)
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
