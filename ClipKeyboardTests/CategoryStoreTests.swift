//
//  CategoryStoreTests.swift
//  ClipKeyboardTests
//
//  사용자 정의 카테고리 CRUD 테스트.
//  주의: CategoryStore.shared는 싱글톤이라 테스트 간 상태가 누적된다.
//        각 테스트는 시작 시 사용자가 추가했을 가능성이 있는 자체 항목만 정리한다.
//

import XCTest
@testable import ClipKeyboard

final class CategoryStoreTests: XCTestCase {

    var sut: CategoryStore!

    private let testCategory = "_xctest_temp_category_"
    private let testCategory2 = "_xctest_temp_category_2_"

    override func setUp() {
        super.setUp()
        sut = CategoryStore.shared
        // 이전 테스트의 잔여물 제거
        _ = sut.remove(testCategory)
        _ = sut.remove(testCategory2)
    }

    override func tearDown() {
        _ = sut.remove(testCategory)
        _ = sut.remove(testCategory2)
        sut = nil
        super.tearDown()
    }

    // MARK: - Add

    func testAdd_NewCategory_Succeeds() {
        let added = sut.add(testCategory)
        XCTAssertTrue(added)
        XCTAssertTrue(sut.allCategories.contains(testCategory))
    }

    func testAdd_Duplicate_ReturnsFalse() {
        _ = sut.add(testCategory)
        let secondAdd = sut.add(testCategory)
        XCTAssertFalse(secondAdd)
    }

    func testAdd_EmptyString_ReturnsFalse() {
        let added = sut.add("")
        XCTAssertFalse(added)
    }

    func testAdd_WhitespaceOnly_ReturnsFalse() {
        let added = sut.add("   \n   ")
        XCTAssertFalse(added)
    }

    func testAdd_Trims() {
        let trimmed = "  \(testCategory)  "
        let added = sut.add(trimmed)
        XCTAssertTrue(added)
        XCTAssertTrue(sut.allCategories.contains(testCategory))
        XCTAssertFalse(sut.allCategories.contains(trimmed))
    }

    // MARK: - Rename

    func testRename_ExistingCategory_Succeeds() {
        _ = sut.add(testCategory)
        let renamed = sut.rename(from: testCategory, to: testCategory2)
        XCTAssertTrue(renamed)
        XCTAssertFalse(sut.allCategories.contains(testCategory))
        XCTAssertTrue(sut.allCategories.contains(testCategory2))
    }

    func testRename_ToDuplicate_Fails() {
        _ = sut.add(testCategory)
        _ = sut.add(testCategory2)
        let renamed = sut.rename(from: testCategory, to: testCategory2)
        XCTAssertFalse(renamed)
    }

    func testRename_NonExistent_Fails() {
        let renamed = sut.rename(from: "non_existent_xctest", to: testCategory)
        XCTAssertFalse(renamed)
    }

    func testRename_ToEmpty_Fails() {
        _ = sut.add(testCategory)
        let renamed = sut.rename(from: testCategory, to: "  ")
        XCTAssertFalse(renamed)
    }

    // MARK: - Remove

    func testRemove_ExistingCategory_Succeeds() {
        _ = sut.add(testCategory)
        let removed = sut.remove(testCategory)
        XCTAssertTrue(removed)
        XCTAssertFalse(sut.allCategories.contains(testCategory))
    }

    func testRemove_NonExistent_Fails() {
        let removed = sut.remove("non_existent_xctest")
        XCTAssertFalse(removed)
    }

    func testRemove_ProtectedCategory_Fails() {
        for protected in CategoryStore.protectedCategories {
            let removed = sut.remove(protected)
            XCTAssertFalse(removed, "보호 카테고리 \(protected)는 삭제 불가해야 함")
        }
    }

    // MARK: - Protected Categories Constant

    func testProtectedCategories_ContainsExpectedKeys() {
        XCTAssertTrue(CategoryStore.protectedCategories.contains("기본"))
        XCTAssertTrue(CategoryStore.protectedCategories.contains("텍스트"))
        XCTAssertTrue(CategoryStore.protectedCategories.contains("이미지"))
    }

    // MARK: - Locale defaults

    func testLocaleDefaults_NotEmpty() {
        let defaults = CategoryStore.localeDefaults()
        XCTAssertFalse(defaults.isEmpty, "Locale 기본 카테고리는 최소 글로벌 공통 항목이 있어야 함")
    }

    // MARK: - allCategories vs categories

    func testAllCategories_ReflectsCategoriesArray() {
        _ = sut.add(testCategory)
        XCTAssertEqual(sut.allCategories, sut.categories)
    }
}
