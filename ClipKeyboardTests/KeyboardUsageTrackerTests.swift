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
        UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")
    }

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return "kb.usage.daily." + formatter.string(from: Date())
    }

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
        // Given — 40자 메모: 40자 ÷ 4자/초 - 1초(탭 오버헤드) = 9초 절약
        let fortyChars = String(repeating: "가", count: 40)

        // When
        KeyboardUsageTracker.recordMemoUse(value: fortyChars)
        KeyboardUsageTracker.recordMemoUse(value: fortyChars)

        // Then
        XCTAssertEqual(KeyboardUsageTracker.totalTimeSavedSeconds(), 18.0, accuracy: 0.001)
    }

    func testRecordMemoUse_ShortValue_NeverGoesNegative() {
        // Given — 2자 메모: 0.5초 - 1초 = 음수 → 0으로 clamp
        KeyboardUsageTracker.recordMemoUse(value: "안녕")

        // Then — 절약 시간은 음수가 되면 안 됨 (통계 화면에 마이너스 노출 방지)
        XCTAssertEqual(KeyboardUsageTracker.totalTimeSavedSeconds(), 0.0, accuracy: 0.001)
        XCTAssertEqual(KeyboardUsageTracker.dailyUsageCount(), 1, "횟수는 그래도 1 증가")
    }

    func testDailyUsageCount_IsScopedToDate() {
        // Given — 오늘 1회 사용
        KeyboardUsageTracker.recordMemoUse(value: "오늘 메모")

        // Then — 어제 날짜로 조회하면 0 (자정에 자연 초기화되는 구조)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertEqual(KeyboardUsageTracker.dailyUsageCount(for: yesterday), 0)
        XCTAssertEqual(KeyboardUsageTracker.dailyUsageCount(), 1)
    }
}
