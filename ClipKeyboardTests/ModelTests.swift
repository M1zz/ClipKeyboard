//
//  ModelTests.swift
//  Token memoTests
//
//  Created by Claude Code on 2026-01-16.
//  데이터 모델 단위 테스트
//

import XCTest
@testable import ClipKeyboard

final class ModelTests: XCTestCase {

    // MARK: - Memo Tests

    func testMemoCreation() {
        // Given
        let title = "테스트 메모"
        let value = "테스트 내용"

        // When
        let memo = Memo(title: title, value: value)

        // Then
        XCTAssertNotNil(memo.id)
        XCTAssertEqual(memo.title, title)
        XCTAssertEqual(memo.value, value)
        XCTAssertFalse(memo.isChecked)
        XCTAssertFalse(memo.isFavorite)
        XCTAssertEqual(memo.clipCount, 0)
        XCTAssertEqual(memo.category, "기본")
    }

    func testMemoEncodingDecoding() throws {
        // Given
        let memo = Memo(
            title: "인코딩 테스트",
            value: "테스트 값",
            isFavorite: true,
            category: "업무",
            isTemplate: true,
            templateVariables: ["{이름}", "{날짜}"]
        )

        // When
        let encoded = try JSONEncoder().encode(memo)
        let decoded = try JSONDecoder().decode(Memo.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.id, memo.id)
        XCTAssertEqual(decoded.title, memo.title)
        XCTAssertEqual(decoded.value, memo.value)
        XCTAssertEqual(decoded.isFavorite, memo.isFavorite)
        XCTAssertEqual(decoded.category, memo.category)
        XCTAssertEqual(decoded.isTemplate, memo.isTemplate)
        XCTAssertEqual(decoded.templateVariables, memo.templateVariables)
    }

    func testMemoWithPlaceholderValues() {
        // Given
        let memo = Memo(title: "템플릿", value: "안녕하세요 {이름}님", isTemplate: true)

        // When
        var memoWithValues = memo
        memoWithValues.placeholderValues["{이름}"] = ["홍길동", "김철수", "이영희"]

        // Then
        XCTAssertTrue(memoWithValues.isTemplate)
        XCTAssertEqual(memoWithValues.placeholderValues["{이름}"]?.count, 3)
        XCTAssertTrue(memoWithValues.placeholderValues["{이름}"]!.contains("홍길동"))
    }

    // MARK: - SmartClipboardHistory Tests

    func testSmartClipboardHistoryCreation() {
        // Given
        let content = "test@example.com"

        // When
        let history = SmartClipboardHistory(
            content: content,
            detectedType: .email,
            confidence: 0.95
        )

        // Then
        XCTAssertEqual(history.content, content)
        XCTAssertEqual(history.detectedType, .email)
        XCTAssertEqual(history.confidence, 0.95)
        XCTAssertTrue(history.isTemporary)
        XCTAssertEqual(history.contentType, .text)
    }

    func testSmartClipboardEncodingDecoding() throws {
        // Given
        let history = SmartClipboardHistory(
            content: "010-1234-5678",
            detectedType: .phone,
            confidence: 0.9
        )

        // When
        let encoded = try JSONEncoder().encode(history)
        let decoded = try JSONDecoder().decode(SmartClipboardHistory.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.id, history.id)
        XCTAssertEqual(decoded.content, history.content)
        XCTAssertEqual(decoded.detectedType, history.detectedType)
        XCTAssertEqual(decoded.confidence, history.confidence)
    }

    // MARK: - Combo Tests

    func testComboCreation() {
        // Given
        let title = "회원가입 정보"
        let items = [
            ComboItem(type: .memo, referenceId: UUID(), order: 0),
            ComboItem(type: .memo, referenceId: UUID(), order: 1),
            ComboItem(type: .template, referenceId: UUID(), order: 2)
        ]

        // When
        let combo = Combo(title: title, items: items, interval: 2.0)

        // Then
        XCTAssertEqual(combo.title, title)
        XCTAssertEqual(combo.items.count, 3)
        XCTAssertEqual(combo.interval, 2.0)
        XCTAssertEqual(combo.useCount, 0)
        XCTAssertFalse(combo.isFavorite)
    }

    func testComboItemsAreSorted() {
        // Given
        let items = [
            ComboItem(type: .memo, referenceId: UUID(), order: 2),
            ComboItem(type: .memo, referenceId: UUID(), order: 0),
            ComboItem(type: .memo, referenceId: UUID(), order: 1)
        ]

        // When
        let combo = Combo(title: "정렬 테스트", items: items)

        // Then
        XCTAssertEqual(combo.items[0].order, 0)
        XCTAssertEqual(combo.items[1].order, 1)
        XCTAssertEqual(combo.items[2].order, 2)
    }

    func testComboEncodingDecoding() throws {
        // Given
        let items = [
            ComboItem(type: .memo, referenceId: UUID(), order: 0, displayTitle: "이름"),
            ComboItem(type: .template, referenceId: UUID(), order: 1, displayTitle: "이메일")
        ]
        let combo = Combo(title: "테스트 Combo", items: items, interval: 1.5)

        // When
        let encoded = try JSONEncoder().encode(combo)
        let decoded = try JSONDecoder().decode(Combo.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.id, combo.id)
        XCTAssertEqual(decoded.title, combo.title)
        XCTAssertEqual(decoded.items.count, combo.items.count)
        XCTAssertEqual(decoded.interval, combo.interval)
        XCTAssertEqual(decoded.items[0].displayTitle, "이름")
    }

    func testComboSortItems() {
        // Given
        var combo = Combo(title: "정렬 테스트", items: [
            ComboItem(type: .memo, referenceId: UUID(), order: 3),
            ComboItem(type: .memo, referenceId: UUID(), order: 1),
            ComboItem(type: .memo, referenceId: UUID(), order: 2)
        ])

        // When
        combo.sortItems()

        // Then
        XCTAssertEqual(combo.items[0].order, 1)
        XCTAssertEqual(combo.items[1].order, 2)
        XCTAssertEqual(combo.items[2].order, 3)
    }

    // MARK: - ClipboardItemType Tests

    func testClipboardItemTypeIcons() {
        // Then
        XCTAssertEqual(ClipboardItemType.email.icon, "envelope.fill")
        XCTAssertEqual(ClipboardItemType.phone.icon, "phone.fill")
        XCTAssertEqual(ClipboardItemType.url.icon, "link")
        XCTAssertEqual(ClipboardItemType.creditCard.icon, "creditcard.fill")
    }

    func testClipboardItemTypeColors() {
        // Then
        XCTAssertEqual(ClipboardItemType.email.color, "blue")
        XCTAssertEqual(ClipboardItemType.phone.color, "green")
        XCTAssertEqual(ClipboardItemType.url.color, "orange")
        XCTAssertEqual(ClipboardItemType.creditCard.color, "red")
    }

    func testClipboardContentType() {
        // When
        let textType = ClipboardContentType.text
        let imageType = ClipboardContentType.image
        let mixedType = ClipboardContentType.mixed

        // Then
        XCTAssertEqual(textType.rawValue, "text")
        XCTAssertEqual(imageType.rawValue, "image")
        XCTAssertEqual(mixedType.rawValue, "mixed")
    }
}
