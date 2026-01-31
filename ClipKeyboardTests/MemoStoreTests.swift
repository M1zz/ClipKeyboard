//
//  MemoStoreTests.swift
//  Token memoTests
//
//  Created by Claude Code on 2026-01-16.
//  MemoStore 저장/로드 테스트
//

import XCTest
@testable import ClipKeyboard

final class MemoStoreTests: XCTestCase {

    var sut: MemoStore!
    var testMemos: [Memo]!

    override func setUp() {
        super.setUp()
        sut = MemoStore.shared
        testMemos = [
            Memo(title: "테스트1", value: "값1"),
            Memo(title: "테스트2", value: "값2"),
            Memo(title: "테스트3", value: "값3")
        ]
    }

    override func tearDown() {
        // 테스트 후 데이터 정리
        try? sut.save(memos: [], type: .tokenMemo)
        try? sut.saveSmartClipboardHistory(history: [])
        try? sut.saveCombos([])
        testMemos = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Memo Save & Load Tests

    func testSaveAndLoadMemos() throws {
        // When
        try sut.save(memos: testMemos, type: .tokenMemo)
        let loadedMemos = try sut.load(type: .tokenMemo)

        // Then
        XCTAssertEqual(loadedMemos.count, testMemos.count)
        XCTAssertEqual(loadedMemos[0].title, "테스트1")
        XCTAssertEqual(loadedMemos[1].title, "테스트2")
        XCTAssertEqual(loadedMemos[2].title, "테스트3")
    }

    func testLoadEmptyMemos() throws {
        // Given
        try sut.save(memos: [], type: .tokenMemo)

        // When
        let loadedMemos = try sut.load(type: .tokenMemo)

        // Then
        XCTAssertTrue(loadedMemos.isEmpty)
    }

    func testUpdateMemo() throws {
        // Given
        try sut.save(memos: testMemos, type: .tokenMemo)

        // When
        var updatedMemos = try sut.load(type: .tokenMemo)
        updatedMemos[0].title = "수정된 제목"
        updatedMemos[0].value = "수정된 값"
        try sut.save(memos: updatedMemos, type: .tokenMemo)

        let loadedMemos = try sut.load(type: .tokenMemo)

        // Then
        XCTAssertEqual(loadedMemos[0].title, "수정된 제목")
        XCTAssertEqual(loadedMemos[0].value, "수정된 값")
    }

    func testDeleteMemo() throws {
        // Given
        try sut.save(memos: testMemos, type: .tokenMemo)

        // When
        var loadedMemos = try sut.load(type: .tokenMemo)
        loadedMemos.remove(at: 1) // "테스트2" 삭제
        try sut.save(memos: loadedMemos, type: .tokenMemo)

        let finalMemos = try sut.load(type: .tokenMemo)

        // Then
        XCTAssertEqual(finalMemos.count, 2)
        XCTAssertEqual(finalMemos[0].title, "테스트1")
        XCTAssertEqual(finalMemos[1].title, "테스트3")
    }

    // MARK: - SmartClipboardHistory Tests

    func testSaveAndLoadSmartClipboardHistory() throws {
        // Given
        let history = [
            SmartClipboardHistory(content: "test@example.com", detectedType: .email),
            SmartClipboardHistory(content: "010-1234-5678", detectedType: .phone)
        ]

        // When
        try sut.saveSmartClipboardHistory(history: history)
        let loadedHistory = try sut.loadSmartClipboardHistory()

        // Then
        XCTAssertEqual(loadedHistory.count, 2)
        XCTAssertEqual(loadedHistory[0].content, "test@example.com")
        XCTAssertEqual(loadedHistory[0].detectedType, .email)
        XCTAssertEqual(loadedHistory[1].detectedType, .phone)
    }

    func testLoadEmptySmartClipboardHistory() throws {
        // Given
        try sut.saveSmartClipboardHistory(history: [])

        // When
        let loadedHistory = try sut.loadSmartClipboardHistory()

        // Then
        XCTAssertTrue(loadedHistory.isEmpty)
    }

    // MARK: - Combo Tests

    func testSaveAndLoadCombos() throws {
        // Given
        let combos = [
            Combo(title: "Combo1", items: [
                ComboItem(type: .memo, referenceId: testMemos[0].id, order: 0)
            ]),
            Combo(title: "Combo2", items: [
                ComboItem(type: .memo, referenceId: testMemos[1].id, order: 0),
                ComboItem(type: .memo, referenceId: testMemos[2].id, order: 1)
            ])
        ]

        // When
        try sut.saveCombos(combos)
        let loadedCombos = try sut.loadCombos()

        // Then
        XCTAssertEqual(loadedCombos.count, 2)
        XCTAssertEqual(loadedCombos[0].title, "Combo1")
        XCTAssertEqual(loadedCombos[0].items.count, 1)
        XCTAssertEqual(loadedCombos[1].title, "Combo2")
        XCTAssertEqual(loadedCombos[1].items.count, 2)
    }

    func testUpdateCombo() throws {
        // Given
        let combo = Combo(title: "원본 Combo", items: [])
        try sut.saveCombos([combo])

        // When
        var loadedCombos = try sut.loadCombos()
        loadedCombos[0].title = "수정된 Combo"
        loadedCombos[0].items = [
            ComboItem(type: .memo, referenceId: UUID(), order: 0)
        ]
        try sut.saveCombos(loadedCombos)

        let finalCombos = try sut.loadCombos()

        // Then
        XCTAssertEqual(finalCombos[0].title, "수정된 Combo")
        XCTAssertEqual(finalCombos[0].items.count, 1)
    }

    func testDeleteCombo() throws {
        // Given
        let combos = [
            Combo(title: "Combo1", items: []),
            Combo(title: "Combo2", items: []),
            Combo(title: "Combo3", items: [])
        ]
        try sut.saveCombos(combos)

        // When
        var loadedCombos = try sut.loadCombos()
        loadedCombos.remove(at: 1) // Combo2 삭제
        try sut.saveCombos(loadedCombos)

        let finalCombos = try sut.loadCombos()

        // Then
        XCTAssertEqual(finalCombos.count, 2)
        XCTAssertEqual(finalCombos[0].title, "Combo1")
        XCTAssertEqual(finalCombos[1].title, "Combo3")
    }

    // MARK: - Combo Validation Tests

    func testValidateComboItem_ValidMemo() throws {
        // Given
        try sut.save(memos: testMemos, type: .tokenMemo)
        let item = ComboItem(type: .memo, referenceId: testMemos[0].id, order: 0)

        // When
        let isValid = try sut.validateComboItem(item)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidateComboItem_InvalidMemo() throws {
        // Given
        try sut.save(memos: testMemos, type: .tokenMemo)
        let invalidItem = ComboItem(type: .memo, referenceId: UUID(), order: 0)

        // When
        let isValid = try sut.validateComboItem(invalidItem)

        // Then
        XCTAssertFalse(isValid)
    }

    func testCleanupCombo_RemovesInvalidItems() throws {
        // Given
        try sut.save(memos: testMemos, type: .tokenMemo)

        let validId = testMemos[0].id
        let invalidId = UUID()

        let combo = Combo(title: "테스트 Combo", items: [
            ComboItem(type: .memo, referenceId: validId, order: 0),
            ComboItem(type: .memo, referenceId: invalidId, order: 1), // 유효하지 않음
            ComboItem(type: .memo, referenceId: testMemos[1].id, order: 2)
        ])

        // When
        let cleanedCombo = try sut.cleanupCombo(combo)

        // Then
        XCTAssertEqual(cleanedCombo.items.count, 2) // 유효하지 않은 항목 제거됨
        XCTAssertEqual(cleanedCombo.items[0].referenceId, validId)
        XCTAssertEqual(cleanedCombo.items[1].referenceId, testMemos[1].id)
    }

    // MARK: - Combo Item Value Tests

    func testGetComboItemValue_Memo() throws {
        // Given
        try sut.save(memos: testMemos, type: .tokenMemo)
        let item = ComboItem(type: .memo, referenceId: testMemos[0].id, order: 0)

        // When
        let value = try sut.getComboItemValue(item)

        // Then
        XCTAssertEqual(value, "값1")
    }

    func testGetComboItemValue_Template() throws {
        // Given
        let template = Memo(title: "템플릿", value: "안녕하세요 {이름}님", isTemplate: true)
        try sut.save(memos: [template], type: .tokenMemo)

        let item = ComboItem(
            type: .template,
            referenceId: template.id,
            order: 0,
            displayValue: "안녕하세요 홍길동님"
        )

        // When
        let value = try sut.getComboItemValue(item)

        // Then
        XCTAssertEqual(value, "안녕하세요 홍길동님")
    }

    func testGetComboItemValue_ClipboardHistory() throws {
        // Given
        let history = [
            SmartClipboardHistory(content: "복사된 텍스트", detectedType: .text)
        ]
        try sut.saveSmartClipboardHistory(history: history)
        let item = ComboItem(type: .clipboardHistory, referenceId: history[0].id, order: 0)

        // When
        let value = try sut.getComboItemValue(item)

        // Then
        XCTAssertEqual(value, "복사된 텍스트")
    }

    // MARK: - Increment Use Count Tests

    func testIncrementComboUseCount() throws {
        // Given
        let combo = Combo(title: "사용 횟수 테스트", items: [], useCount: 0)
        try sut.saveCombos([combo])

        // When
        try sut.incrementComboUseCount(id: combo.id)
        let loadedCombos = try sut.loadCombos()

        // Then
        XCTAssertEqual(loadedCombos[0].useCount, 1)
    }

    func testIncrementComboUseCount_Multiple() throws {
        // Given
        let combo = Combo(title: "다중 사용 테스트", items: [], useCount: 0)
        try sut.saveCombos([combo])

        // When
        try sut.incrementComboUseCount(id: combo.id)
        try sut.incrementComboUseCount(id: combo.id)
        try sut.incrementComboUseCount(id: combo.id)
        let loadedCombos = try sut.loadCombos()

        // Then
        XCTAssertEqual(loadedCombos[0].useCount, 3)
    }
}
