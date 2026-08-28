//
//  PlaceholderRenameTests.swift
//  ClipKeyboardTests
//
//  빈칸 이름 바꾸기 시험.
//
//  왜 따로 두나: 이름 바꾸기는 지우기와 달리 **본문을 고친다**. 값만 옮기고 본문을 두면
//  바꾼 빈칸이 그 자리에서 고아가 되고, 단축어들은 여전히 옛 이름을 가리킨다.
//  그 어긋남을 여기서 붙잡는다.
//

import XCTest
@testable import ClipKeyboard

final class PlaceholderRenameTests: XCTestCase {

    private let old = "{옛이름_xctest_unique}"
    private let new = "{새이름_xctest_unique}"

    override func setUp() {
        super.setUp()
        wipe()
    }

    override func tearDown() {
        wipe()
        super.tearDown()
    }

    private func wipe() {
        for token in [old, new] {
            AppGroup.defaults?.removeObject(forKey: "placeholder_values_\(token)")
            UserDefaults.standard.removeObject(forKey: "placeholder_values_\(token)")
        }
    }

    // MARK: - 값이 새 이름을 따라간다

    func testRenameMovesStoredValues() {
        MemoStore.shared.addPlaceholderValue("홍길동", for: old, sourceMemoId: UUID(), sourceMemoTitle: "시험")

        let result = MemoStore.shared.renamePlaceholder(old, to: "새이름_xctest_unique")

        XCTAssertEqual(result, .renamed(memosTouched: 0))
        XCTAssertTrue(MemoStore.shared.loadPlaceholderValues(for: old).isEmpty)
        XCTAssertEqual(MemoStore.shared.loadPlaceholderValues(for: new).map(\.value), ["홍길동"])
    }

    func testRenamedPlaceholderReplacesOldNameInList() {
        MemoStore.shared.addPlaceholderValue("값", for: old, sourceMemoId: UUID(), sourceMemoTitle: "시험")

        MemoStore.shared.renamePlaceholder(old, to: new)

        let tokens = MemoStore.shared.storedPlaceholderTokens()
        XCTAssertFalse(tokens.contains(old), "옛 이름이 목록에 남으면 안 된다")
        XCTAssertTrue(tokens.contains(new))
    }

    /// 중괄호를 붙여 적어도, 안 붙여 적어도 같은 결과여야 한다.
    func testBracesInTypedNameAreForgiven() {
        MemoStore.shared.addPlaceholderValue("값", for: old, sourceMemoId: UUID(), sourceMemoTitle: "시험")

        MemoStore.shared.renamePlaceholder(old, to: "  {새이름_xctest_unique}  ")

        XCTAssertEqual(MemoStore.shared.loadPlaceholderValues(for: new).count, 1)
    }

    // MARK: - 쓸 수 없는 이름

    func testEmptyNameIsRejected() {
        XCTAssertEqual(MemoStore.shared.renamePlaceholder(old, to: "   "), .invalidName)
    }

    func testSameNameChangesNothing() {
        XCTAssertEqual(MemoStore.shared.renamePlaceholder(old, to: "옛이름_xctest_unique"), .unchanged)
    }

    /// `{날짜}` 처럼 앱이 알아서 채우는 이름으로 바꾸면 그 빈칸은 값을 물어보지 않게 된다.
    /// 사용자가 저장해 둔 값이 조용히 무시되므로 막는다.
    func testAutoVariableNameIsRejected() {
        XCTAssertEqual(MemoStore.shared.renamePlaceholder(old, to: "날짜"), .reservedName)
    }

    // MARK: - 본문이 함께 바뀐다
    //
    // 저장소를 건드리지 않고 순수 함수(MemoStore.rename)만 본다.
    // 시험이 사람의 단축어 파일을 덮어쓰지 않게 하기 위해서다.

    func testBodyTextFollowsTheNewName() {
        var memo = Memo(title: "인사", value: "안녕하세요 \(old)님, \(old) 님께")

        let changed = MemoStore.rename(&memo, from: old, to: new)

        XCTAssertTrue(changed)
        XCTAssertEqual(memo.value, "안녕하세요 \(new)님, \(new) 님께", "본문의 옛 이름이 모두 바뀌어야 한다")
        XCTAssertFalse(memo.value.contains(old))
    }

    func testTemplateVariableListFollowsTheNewName() {
        var memo = Memo(title: "인사", value: "안녕 \(old)", templateVariables: [old, "{도시}"])

        XCTAssertTrue(MemoStore.rename(&memo, from: old, to: new))

        XCTAssertEqual(memo.templateVariables, [new, "{도시}"], "남의 변수는 그대로 둔다")
        XCTAssertTrue(memo.isTemplate, "변수가 남아 있으면 템플릿 그대로다")
    }

    func testAttachedValueCopiesFollowTheNewName() {
        var memo = Memo(title: "인사", value: "안녕 \(old)")
        memo.placeholderValues = [old: ["홍길동"], "{도시}": ["서울"]]

        XCTAssertTrue(MemoStore.rename(&memo, from: old, to: new))

        XCTAssertNil(memo.placeholderValues[old], "옛 이름의 사본이 남으면 키보드가 되살린다")
        XCTAssertEqual(memo.placeholderValues[new], ["홍길동"])
        XCTAssertEqual(memo.placeholderValues["{도시}"], ["서울"])
    }

    func testUnrelatedMemoIsLeftAlone() {
        var memo = Memo(title: "다른 것", value: "여기엔 그 빈칸이 없다 {다른빈칸}")
        let before = memo

        XCTAssertFalse(MemoStore.rename(&memo, from: old, to: new), "바꿀 것이 없으면 손대지 않는다")
        XCTAssertEqual(memo.value, before.value)
    }

    func testExistingNameIsRejected() {
        MemoStore.shared.addPlaceholderValue("값", for: new, sourceMemoId: UUID(), sourceMemoTitle: "시험")

        XCTAssertEqual(MemoStore.shared.renamePlaceholder(old, to: new), .nameTaken,
                       "이미 있는 이름으로 바꾸면 두 빈칸의 값이 섞인다. 막아야 한다")
        XCTAssertEqual(MemoStore.shared.loadPlaceholderValues(for: new).count, 1, "남의 값이 사라지면 안 된다")
    }
}
