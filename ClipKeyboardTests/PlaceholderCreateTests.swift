//
//  PlaceholderCreateTests.swift
//  ClipKeyboardTests
//
//  빈칸을 **손으로 만드는** 길의 시험.
//
//  왜 필요한가: 빈칸 관리에는 이름을 바꾸고 지우는 길만 있었다. 그래서 새 빈칸 하나를
//  만들려면 단축어 본문에 `{이름}` 을 적었다가 지우는 우회가 필요했다(사용자 제보).
//
//  여기서 못박는 것은 둘이다.
//   · 값이 하나도 없어도 목록에 남는다(저장소에 열쇠가 있어야 한다).
//   · 이름 규칙이 이름 바꾸기와 **같다**. 한쪽만 느슨하면 만들 수는 있는데 못 바꾸는 이름이 생긴다.
//

import XCTest
@testable import ClipKeyboard

final class PlaceholderCreateTests: XCTestCase {

    // ⚠️ `name` 은 XCTestCase 가 이미 쓰는 이름이라 겹치면 안 된다(시험 이름).
    private let bare = "새빈칸_xctest_unique"
    private var token: String { "{\(bare)}" }

    override func setUp() {
        super.setUp()
        wipe()
    }

    override func tearDown() {
        wipe()
        super.tearDown()
    }

    private func wipe() {
        AppGroup.defaults?.removeObject(forKey: "placeholder_values_\(token)")
        UserDefaults.standard.removeObject(forKey: "placeholder_values_\(token)")
    }

    // MARK: - 만들어진다

    func testCreatesEmptyPlaceholder() {
        let result = MemoStore.shared.createPlaceholder(bare)

        XCTAssertEqual(result, .created(token: token))
        XCTAssertTrue(MemoStore.shared.loadPlaceholderValues(for: token).isEmpty)
    }

    /// 값이 없어도 목록에 서야 한다. 목록은 저장소의 열쇠를 훑어 모은다.
    func testEmptyPlaceholderStillListed() {
        MemoStore.shared.createPlaceholder(bare)

        XCTAssertTrue(MemoStore.shared.storedPlaceholderTokens().contains(token))
        let summaries = PlaceholderCatalog.summaries(from: [])
        XCTAssertTrue(summaries.contains { $0.token == token })
    }

    /// 중괄호를 함께 적어도, 앞뒤에 공백이 있어도 같은 하나로 만든다.
    func testAcceptsBracesAndWhitespace() {
        XCTAssertEqual(MemoStore.shared.createPlaceholder("  {\(bare)}  "), .created(token: token))
    }

    // MARK: - 막는다

    func testRejectsEmptyName() {
        XCTAssertEqual(MemoStore.shared.createPlaceholder("   "), .invalidName)
    }

    func testRejectsAutoVariableName() {
        // `{날짜}` 는 앱이 알아서 채우는 자리라 사용자가 만들 수 없다.
        XCTAssertEqual(MemoStore.shared.createPlaceholder("날짜"), .reservedName)
    }

    func testRejectsExistingName() {
        MemoStore.shared.createPlaceholder(bare)

        XCTAssertEqual(MemoStore.shared.createPlaceholder(bare), .nameTaken)
        // 두 번째 시도가 막혔다고 해서 먼저 만든 것이 사라지면 안 된다.
        XCTAssertTrue(MemoStore.shared.storedPlaceholderTokens().contains(token))
    }

    /// 이름을 만들고 나서 **바꿀 수도** 있어야 한다. 규칙이 같은 곳을 보는지 확인한다.
    func testCreatedPlaceholderCanBeRenamed() {
        MemoStore.shared.createPlaceholder(bare)
        defer {
            AppGroup.defaults?.removeObject(forKey: "placeholder_values_{\(bare)2}")
            UserDefaults.standard.removeObject(forKey: "placeholder_values_{\(bare)2}")
        }

        let result = MemoStore.shared.renamePlaceholder(token, to: "\(bare)2")

        XCTAssertEqual(result, .renamed(memosTouched: 0))
    }
}
