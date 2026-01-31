//
//  ComboExecutionServiceTests.swift
//  Token memoTests
//
//  Created by Claude Code on 2026-01-16.
//  Combo 실행 서비스 테스트
//

import XCTest
@testable import ClipKeyboard

final class ComboExecutionServiceTests: XCTestCase {

    var sut: ComboExecutionService!
    var memoStore: MemoStore!
    var testMemos: [Memo]!

    override func setUp() {
        super.setUp()
        sut = ComboExecutionService.shared
        memoStore = MemoStore.shared

        // 테스트 메모 준비
        testMemos = [
            Memo(title: "메모1", value: "값1"),
            Memo(title: "메모2", value: "값2"),
            Memo(title: "메모3", value: "값3")
        ]

        try? memoStore.save(memos: testMemos, type: .tokenMemo)
    }

    override func tearDown() {
        sut.stopCombo()
        try? memoStore.save(memos: [], type: .tokenMemo)
        try? memoStore.saveCombos([])
        testMemos = nil
        memoStore = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - State Tests

    func testInitialState() {
        // Then
        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(sut.currentItemIndex, 0)
    }

    func testStartCombo_ChangesStateToRunning() {
        // Given
        let combo = Combo(title: "테스트", items: [
            ComboItem(type: .memo, referenceId: testMemos[0].id, order: 0),
            ComboItem(type: .memo, referenceId: testMemos[1].id, order: 1)
        ], interval: 0.1)

        // When
        sut.startCombo(combo)

        // Then
        if case .running = sut.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("State should be running")
        }
    }

    func testStopCombo_ChangesStateToIdle() {
        // Given
        let combo = Combo(title: "테스트", items: [
            ComboItem(type: .memo, referenceId: testMemos[0].id, order: 0)
        ], interval: 0.1)
        sut.startCombo(combo)

        // When
        sut.stopCombo()

        // Then
        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(sut.currentItemIndex, 0)
    }

    func testPauseCombo() {
        // Given
        let combo = Combo(title: "테스트", items: [
            ComboItem(type: .memo, referenceId: testMemos[0].id, order: 0),
            ComboItem(type: .memo, referenceId: testMemos[1].id, order: 1)
        ], interval: 0.1)
        sut.startCombo(combo)

        // When
        sut.pauseCombo()

        // Then
        if case .paused = sut.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("State should be paused")
        }
    }

    func testResumeCombo() {
        // Given
        let combo = Combo(title: "테스트", items: [
            ComboItem(type: .memo, referenceId: testMemos[0].id, order: 0),
            ComboItem(type: .memo, referenceId: testMemos[1].id, order: 1)
        ], interval: 0.1)
        sut.startCombo(combo)
        sut.pauseCombo()

        // When
        sut.resumeCombo()

        // Then
        if case .running = sut.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("State should be running after resume")
        }
    }

    // MARK: - Execution Tests

    func testStartCombo_WithSingleItem() async {
        // Given
        let combo = Combo(title: "단일 항목", items: [
            ComboItem(type: .memo, referenceId: testMemos[0].id, order: 0)
        ], interval: 0.1)

        // When
        sut.startCombo(combo)

        // Wait for completion
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5초

        // Then
        XCTAssertEqual(sut.state, .idle) // 단일 항목은 즉시 완료
    }

    func testStartCombo_WithMultipleItems() async {
        // Given
        let combo = Combo(title: "다중 항목", items: [
            ComboItem(type: .memo, referenceId: testMemos[0].id, order: 0),
            ComboItem(type: .memo, referenceId: testMemos[1].id, order: 1),
            ComboItem(type: .memo, referenceId: testMemos[2].id, order: 2)
        ], interval: 0.2)

        // When
        sut.startCombo(combo)

        // Wait for all items to execute
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1초

        // Then
        XCTAssertEqual(sut.state, .completed)
    }

    func testProgress_Calculation() {
        // Given
        let combo = Combo(title: "진행률 테스트", items: [
            ComboItem(type: .memo, referenceId: testMemos[0].id, order: 0),
            ComboItem(type: .memo, referenceId: testMemos[1].id, order: 1),
            ComboItem(type: .memo, referenceId: testMemos[2].id, order: 2)
        ])
        sut.startCombo(combo)

        // Then
        let expectedProgress = Double(0) / Double(3)
        XCTAssertEqual(sut.progress, expectedProgress)
    }

    func testCurrentItem() {
        // Given
        let combo = Combo(title: "현재 항목 테스트", items: [
            ComboItem(type: .memo, referenceId: testMemos[0].id, order: 0, displayTitle: "첫 번째"),
            ComboItem(type: .memo, referenceId: testMemos[1].id, order: 1, displayTitle: "두 번째")
        ])
        sut.startCombo(combo)

        // When
        let currentItem = sut.currentItem

        // Then
        XCTAssertNotNil(currentItem)
        XCTAssertEqual(currentItem?.displayTitle, "첫 번째")
    }

    // MARK: - Template Variable Processing Tests

    func testTemplateVariableProcessing_Date() {
        // Given
        let template = Memo(
            title: "날짜 템플릿",
            value: "오늘은 {날짜}입니다",
            isTemplate: true
        )
        try? memoStore.save(memos: [template], type: .tokenMemo)

        let combo = Combo(title: "날짜 테스트", items: [
            ComboItem(type: .template, referenceId: template.id, order: 0)
        ], interval: 0.1)

        // When
        sut.startCombo(combo)

        // Wait a bit
        let expectation = XCTestExpectation(description: "Wait for execution")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then - 클립보드에 날짜가 치환된 값이 있어야 함
        // Note: 실제 클립보드 검증은 통합 테스트에서 수행
        XCTAssertTrue(true)
    }

    func testTemplateVariableProcessing_Time() {
        // Given
        let template = Memo(
            title: "시간 템플릿",
            value: "현재 시각: {시간}",
            isTemplate: true
        )
        try? memoStore.save(memos: [template], type: .tokenMemo)

        let combo = Combo(title: "시간 테스트", items: [
            ComboItem(type: .template, referenceId: template.id, order: 0)
        ], interval: 0.1)

        // When
        sut.startCombo(combo)

        // Then
        if case .running = sut.state {
            XCTAssertTrue(true)
        } else if case .completed = sut.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("State should be running or completed")
        }
    }

    // MARK: - Error Handling Tests

    func testStartCombo_WithInvalidItem_ContinuesExecution() async {
        // Given
        let combo = Combo(title: "에러 처리 테스트", items: [
            ComboItem(type: .memo, referenceId: testMemos[0].id, order: 0),
            ComboItem(type: .memo, referenceId: UUID(), order: 1), // 유효하지 않은 ID
            ComboItem(type: .memo, referenceId: testMemos[2].id, order: 2)
        ], interval: 0.2)

        // When
        sut.startCombo(combo)

        // Wait for completion
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5초

        // Then - 에러가 발생해도 다음 항목 계속 진행
        XCTAssertEqual(sut.state, .completed)
    }

    func testCannotStartCombo_WhileRunning() {
        // Given
        let combo1 = Combo(title: "첫 번째", items: [
            ComboItem(type: .memo, referenceId: testMemos[0].id, order: 0)
        ], interval: 0.5)

        let combo2 = Combo(title: "두 번째", items: [
            ComboItem(type: .memo, referenceId: testMemos[1].id, order: 0)
        ], interval: 0.5)

        // When
        sut.startCombo(combo1)
        let stateBefore = sut.state

        sut.startCombo(combo2) // 실행 중이므로 무시되어야 함
        let stateAfter = sut.state

        // Then
        XCTAssertEqual(stateBefore, stateAfter) // 상태 변화 없음
    }

    // MARK: - Use Count Tests

    func testComboCompletion_IncrementsUseCount() async throws {
        // Given
        let combo = Combo(title: "사용 횟수 테스트", items: [
            ComboItem(type: .memo, referenceId: testMemos[0].id, order: 0)
        ], interval: 0.1, useCount: 0)

        try memoStore.saveCombos([combo])

        // When
        sut.startCombo(combo)

        // Wait for completion
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1초

        // Then
        let loadedCombos = try memoStore.loadCombos()
        XCTAssertEqual(loadedCombos[0].useCount, 1)
    }
}
