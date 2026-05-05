//
//  PlaceholderValueTests.swift
//  ClipKeyboardTests
//
//  템플릿 플레이스홀더 값 저장/로드/삭제 테스트.
//  저장 위치: App Group UserDefaults `placeholder_values_{토큰}` 키.
//

import XCTest
@testable import ClipKeyboard

final class PlaceholderValueTests: XCTestCase {

    var sut: MemoStore!
    let testPlaceholder = "{테스트변수_xctest_unique}"
    let testMemoId = UUID()
    let testMemoTitle = "테스트 템플릿"

    override func setUp() {
        super.setUp()
        sut = MemoStore.shared
        // 격리: 테스트용 키 초기화
        UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?
            .removeObject(forKey: "placeholder_values_\(testPlaceholder)")
    }

    override func tearDown() {
        UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?
            .removeObject(forKey: "placeholder_values_\(testPlaceholder)")
        sut = nil
        super.tearDown()
    }

    // MARK: - Save / Load

    func testSaveAndLoadPlaceholderValues() {
        let values = [
            PlaceholderValue(value: "홍길동", sourceMemoId: testMemoId, sourceMemoTitle: testMemoTitle),
            PlaceholderValue(value: "김철수", sourceMemoId: testMemoId, sourceMemoTitle: testMemoTitle)
        ]
        sut.savePlaceholderValues(values, for: testPlaceholder)

        let loaded = sut.loadPlaceholderValues(for: testPlaceholder)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].value, "홍길동")
        XCTAssertEqual(loaded[1].value, "김철수")
    }

    func testLoadPlaceholderValues_EmptyKey_ReturnsEmpty() {
        let loaded = sut.loadPlaceholderValues(for: "{never_saved_xctest_token}")
        XCTAssertTrue(loaded.isEmpty)
    }

    // MARK: - Add (most-recent-first + dedup)

    func testAddPlaceholderValue_PrependsToFront() {
        sut.addPlaceholderValue("첫번째", for: testPlaceholder, sourceMemoId: testMemoId, sourceMemoTitle: testMemoTitle)
        sut.addPlaceholderValue("두번째", for: testPlaceholder, sourceMemoId: testMemoId, sourceMemoTitle: testMemoTitle)

        let loaded = sut.loadPlaceholderValues(for: testPlaceholder)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].value, "두번째", "최근값이 앞에 와야 함")
        XCTAssertEqual(loaded[1].value, "첫번째")
    }

    func testAddPlaceholderValue_Duplicate_DedupsAndMovesToFront() {
        sut.addPlaceholderValue("A", for: testPlaceholder, sourceMemoId: testMemoId, sourceMemoTitle: testMemoTitle)
        sut.addPlaceholderValue("B", for: testPlaceholder, sourceMemoId: testMemoId, sourceMemoTitle: testMemoTitle)
        sut.addPlaceholderValue("A", for: testPlaceholder, sourceMemoId: testMemoId, sourceMemoTitle: testMemoTitle)

        let loaded = sut.loadPlaceholderValues(for: testPlaceholder)
        XCTAssertEqual(loaded.count, 2, "중복은 제거되고 1개만 남아야 함")
        XCTAssertEqual(loaded[0].value, "A")
        XCTAssertEqual(loaded[1].value, "B")
    }

    // MARK: - Delete by valueId

    func testDeletePlaceholderValue_ById() {
        let v1 = PlaceholderValue(value: "유지", sourceMemoId: testMemoId, sourceMemoTitle: testMemoTitle)
        let v2 = PlaceholderValue(value: "삭제대상", sourceMemoId: testMemoId, sourceMemoTitle: testMemoTitle)
        sut.savePlaceholderValues([v1, v2], for: testPlaceholder)

        sut.deletePlaceholderValue(valueId: v2.id, for: testPlaceholder)

        let loaded = sut.loadPlaceholderValues(for: testPlaceholder)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].value, "유지")
    }

    // MARK: - Encoding

    func testPlaceholderValue_Codable() throws {
        let original = PlaceholderValue(
            value: "테스트값",
            sourceMemoId: UUID(),
            sourceMemoTitle: "원본 메모"
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PlaceholderValue.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.value, original.value)
        XCTAssertEqual(decoded.sourceMemoId, original.sourceMemoId)
        XCTAssertEqual(decoded.sourceMemoTitle, original.sourceMemoTitle)
    }
}
