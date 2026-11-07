//
//  MemoStoreTests.swift
//  ClipKeyboardTests
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
        try? sut.save(memos: [], type: .memo)
        try? ClipboardHistoryStore.shared.save([])
        try? sut.saveCombos([])
        testMemos = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Memo Save & Load Tests

    func testSaveAndLoadMemos() throws {
        // When
        try sut.save(memos: testMemos, type: .memo)
        let loadedMemos = try sut.load(type: .memo)

        // Then
        XCTAssertEqual(loadedMemos.count, testMemos.count)
        XCTAssertEqual(loadedMemos[0].title, "테스트1")
        XCTAssertEqual(loadedMemos[1].title, "테스트2")
        XCTAssertEqual(loadedMemos[2].title, "테스트3")
    }

    func testLoadEmptyMemos() throws {
        // Given
        try sut.save(memos: [], type: .memo)

        // When
        let loadedMemos = try sut.load(type: .memo)

        // Then
        XCTAssertTrue(loadedMemos.isEmpty)
    }

    func testUpdateMemo() throws {
        // Given
        try sut.save(memos: testMemos, type: .memo)

        // When
        var updatedMemos = try sut.load(type: .memo)
        updatedMemos[0].title = "수정된 제목"
        updatedMemos[0].value = "수정된 값"
        try sut.save(memos: updatedMemos, type: .memo)

        let loadedMemos = try sut.load(type: .memo)

        // Then
        XCTAssertEqual(loadedMemos[0].title, "수정된 제목")
        XCTAssertEqual(loadedMemos[0].value, "수정된 값")
    }

    func testDeleteMemo() throws {
        // Given
        try sut.save(memos: testMemos, type: .memo)

        // When
        var loadedMemos = try sut.load(type: .memo)
        loadedMemos.remove(at: 1) // "테스트2" 삭제
        try sut.save(memos: loadedMemos, type: .memo)

        let finalMemos = try sut.load(type: .memo)

        // Then
        XCTAssertEqual(finalMemos.count, 2)
        XCTAssertEqual(finalMemos[0].title, "테스트1")
        XCTAssertEqual(finalMemos[1].title, "테스트3")
    }

    /// 어느 길로 지웠든 저장을 지나면, 그 단축어에 대해 배운 커서 자리도 같이 지워진다.
    func testDeletingMemoForgetsWhatWasLearnedAboutIt() throws {
        try sut.save(memos: testMemos, type: .memo)
        _ = try sut.load(type: .memo)   // 캐시가 디스크와 같아진다(덮기 직전 목록을 여기서 본다)
        let gone = testMemos[1].id, kept = testMemos[0].id
        for _ in 0..<3 {
            _ = CursorMemory.observe(memoId: gone, offsetFromEnd: 2, textLength: 10)
            _ = CursorMemory.observe(memoId: kept, offsetFromEnd: 2, textLength: 10)
        }
        XCTAssertNotNil(CursorMemory.learned(for: gone))

        var memos = try sut.load(type: .memo)
        memos.removeAll { $0.id == gone }
        try sut.save(memos: memos, type: .memo)

        XCTAssertNil(CursorMemory.learned(for: gone), "지운 단축어에 대해 배운 것은 남지 않는다")
        XCTAssertNotNil(CursorMemory.learned(for: kept), "남은 단축어의 것은 그대로다")
        CursorMemory.forget(for: kept)
    }

    // MARK: - SmartClipboardHistory Tests

    func testSaveAndLoadSmartClipboardHistory() throws {
        // Given
        let history = [
            SmartClipboardHistory(content: "test@example.com", detectedType: .email),
            SmartClipboardHistory(content: "010-1234-5678", detectedType: .phone)
        ]

        // When
        try ClipboardHistoryStore.shared.save(history)
        let loadedHistory = try ClipboardHistoryStore.shared.load()

        // Then
        XCTAssertEqual(loadedHistory.count, 2)
        XCTAssertEqual(loadedHistory[0].content, "test@example.com")
        XCTAssertEqual(loadedHistory[0].detectedType, .email)
        XCTAssertEqual(loadedHistory[1].detectedType, .phone)
    }

    func testLoadEmptySmartClipboardHistory() throws {
        // Given
        try ClipboardHistoryStore.shared.save([])

        // When
        let loadedHistory = try ClipboardHistoryStore.shared.load()

        // Then
        XCTAssertTrue(loadedHistory.isEmpty)
    }

    // MARK: - Combo Tests

    func testSaveAndLoadStacks() throws {
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
        let loadedStacks = try sut.loadCombos()

        // Then
        XCTAssertEqual(loadedStacks.count, 2)
        XCTAssertEqual(loadedStacks[0].title, "Combo1")
        XCTAssertEqual(loadedStacks[0].items.count, 1)
        XCTAssertEqual(loadedStacks[1].title, "Combo2")
        XCTAssertEqual(loadedStacks[1].items.count, 2)
    }

    func testUpdateStack() throws {
        // Given
        let stack = Combo(title: "원본 Combo", items: [])
        try sut.saveCombos([stack])

        // When
        var loadedStacks = try sut.loadCombos()
        loadedStacks[0].title = "수정된 Combo"
        loadedStacks[0].items = [
            ComboItem(type: .memo, referenceId: UUID(), order: 0)
        ]
        try sut.saveCombos(loadedStacks)

        let finalStacks = try sut.loadCombos()

        // Then
        XCTAssertEqual(finalStacks[0].title, "수정된 Combo")
        XCTAssertEqual(finalStacks[0].items.count, 1)
    }

    func testDeleteStack() throws {
        // Given
        let combos = [
            Combo(title: "Combo1", items: []),
            Combo(title: "Combo2", items: []),
            Combo(title: "Combo3", items: [])
        ]
        try sut.saveCombos(combos)

        // When
        var loadedStacks = try sut.loadCombos()
        loadedStacks.remove(at: 1) // Combo2 삭제
        try sut.saveCombos(loadedStacks)

        let finalStacks = try sut.loadCombos()

        // Then
        XCTAssertEqual(finalStacks.count, 2)
        XCTAssertEqual(finalStacks[0].title, "Combo1")
        XCTAssertEqual(finalStacks[1].title, "Combo3")
    }

    // MARK: - Combo Validation Tests

    func testValidateStackItem_ValidMemo() throws {
        // Given
        try sut.save(memos: testMemos, type: .memo)
        let item = ComboItem(type: .memo, referenceId: testMemos[0].id, order: 0)

        // When
        let isValid = try sut.validateStackItem(item)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidateStackItem_InvalidMemo() throws {
        // Given
        try sut.save(memos: testMemos, type: .memo)
        let invalidItem = ComboItem(type: .memo, referenceId: UUID(), order: 0)

        // When
        let isValid = try sut.validateStackItem(invalidItem)

        // Then
        XCTAssertFalse(isValid)
    }

    func testCleanupStack_RemovesInvalidItems() throws {
        // Given
        try sut.save(memos: testMemos, type: .memo)

        let validId = testMemos[0].id
        let invalidId = UUID()

        let stack = Combo(title: "테스트 Combo", items: [
            ComboItem(type: .memo, referenceId: validId, order: 0),
            ComboItem(type: .memo, referenceId: invalidId, order: 1), // 유효하지 않음
            ComboItem(type: .memo, referenceId: testMemos[1].id, order: 2)
        ])

        // When
        let cleanedStack = try sut.cleanupStack(stack)

        // Then
        XCTAssertEqual(cleanedStack.items.count, 2) // 유효하지 않은 항목 제거됨
        XCTAssertEqual(cleanedStack.items[0].referenceId, validId)
        XCTAssertEqual(cleanedStack.items[1].referenceId, testMemos[1].id)
    }

    // MARK: - Combo Item Value Tests

    func testGetStackItemValue_Memo() throws {
        // Given
        try sut.save(memos: testMemos, type: .memo)
        let item = ComboItem(type: .memo, referenceId: testMemos[0].id, order: 0)

        // When
        let value = try sut.getStackItemValue(item)

        // Then
        XCTAssertEqual(value, "값1")
    }

    func testGetStackItemValue_Template() throws {
        // Given
        let template = Memo(title: "템플릿", value: "안녕하세요 {이름}님", templateVariables: ["{이름}"])
        try sut.save(memos: [template], type: .memo)

        let item = ComboItem(
            type: .template,
            referenceId: template.id,
            order: 0,
            displayValue: "안녕하세요 홍길동님"
        )

        // When
        let value = try sut.getStackItemValue(item)

        // Then
        XCTAssertEqual(value, "안녕하세요 홍길동님")
    }

    func testGetStackItemValue_ClipboardHistory() throws {
        // Given
        let history = [
            SmartClipboardHistory(content: "복사된 텍스트", detectedType: .text)
        ]
        try ClipboardHistoryStore.shared.save(history)
        let item = ComboItem(type: .clipboardHistory, referenceId: history[0].id, order: 0)

        // When
        let value = try sut.getStackItemValue(item)

        // Then
        XCTAssertEqual(value, "복사된 텍스트")
    }

    // MARK: - Increment Use Count Tests

    func testIncrementStackUseCount() throws {
        // Given
        let stack = Combo(title: "사용 횟수 테스트", items: [], useCount: 0)
        try sut.saveCombos([stack])

        // When
        try sut.incrementStackUseCount(id: stack.id)
        let loadedStacks = try sut.loadCombos()

        // Then
        XCTAssertEqual(loadedStacks[0].useCount, 1)
    }

    func testIncrementStackUseCount_Multiple() throws {
        // Given
        let stack = Combo(title: "다중 사용 테스트", items: [], useCount: 0)
        try sut.saveCombos([stack])

        // When
        try sut.incrementStackUseCount(id: stack.id)
        try sut.incrementStackUseCount(id: stack.id)
        try sut.incrementStackUseCount(id: stack.id)
        let loadedStacks = try sut.loadCombos()

        // Then
        XCTAssertEqual(loadedStacks[0].useCount, 3)
    }
}
