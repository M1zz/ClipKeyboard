//
//  PlaceholderDeletionTests.swift
//  ClipKeyboardTests
//
//  빈칸(플레이스홀더) **자체**를 지우는 것에 대한 시험.
//
//  왜 따로 두나: 값 하나를 지우는 것과 빈칸을 통째로 지우는 것은 지워야 할 자리가 다르다.
//  빈칸은 세 곳(App Group · 표준 UserDefaults 의 옛 값 · 단축어에 붙은 사본)에 흩어져 있고,
//  하나라도 남으면 관리 화면이나 키보드에서 되살아난다. 되살아나는 것을 여기서 붙잡는다.
//

import XCTest
@testable import ClipKeyboard

final class PlaceholderDeletionTests: XCTestCase {

    private let token = "{삭제시험_xctest_unique}"
    private var key: String { "placeholder_values_\(token)" }

    override func setUp() {
        super.setUp()
        wipe()
    }

    override func tearDown() {
        wipe()
        super.tearDown()
    }

    private func wipe() {
        AppGroup.defaults?.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - 값이 사라진다

    func testDeletePlaceholderRemovesStoredValues() {
        MemoStore.shared.addPlaceholderValue("값1", for: token, sourceMemoId: UUID(), sourceMemoTitle: "시험")
        MemoStore.shared.addPlaceholderValue("값2", for: token, sourceMemoId: UUID(), sourceMemoTitle: "시험")
        XCTAssertEqual(MemoStore.shared.loadPlaceholderValues(for: token).count, 2)

        MemoStore.shared.deletePlaceholder(token)

        XCTAssertTrue(MemoStore.shared.loadPlaceholderValues(for: token).isEmpty)
        XCTAssertNil(AppGroup.defaults?.data(forKey: key))
    }

    // MARK: - 목록에서도 사라진다

    func testDeletedPlaceholderIsNotListedAgain() {
        MemoStore.shared.addPlaceholderValue("값", for: token, sourceMemoId: UUID(), sourceMemoTitle: "시험")
        XCTAssertTrue(MemoStore.shared.storedPlaceholderTokens().contains(token))

        MemoStore.shared.deletePlaceholder(token)

        XCTAssertFalse(MemoStore.shared.storedPlaceholderTokens().contains(token),
                       "지운 빈칸이 관리 화면 목록에 유령으로 남으면 안 된다")
    }

    /// ⚠️ 옛 값은 **표준 UserDefaults** 에 있다. `storedPlaceholderTokens()` 가 양쪽을 훑으므로
    ///    이쪽을 안 지우면 값이 0인 이름으로 목록에 남는다.
    func testDeleteAlsoClearsLegacyStandardDefaults() {
        let legacy = [PlaceholderValue(value: "옛값", sourceMemoId: UUID(), sourceMemoTitle: "옛 시험")]
        UserDefaults.standard.set(try? JSONEncoder().encode(legacy), forKey: key)
        XCTAssertTrue(MemoStore.shared.storedPlaceholderTokens().contains(token))

        MemoStore.shared.deletePlaceholder(token)

        XCTAssertNil(UserDefaults.standard.data(forKey: key))
        XCTAssertFalse(MemoStore.shared.storedPlaceholderTokens().contains(token))
    }

    // MARK: - 없는 것을 지워도 조용하다

    func testDeletingUnknownPlaceholderIsHarmless() {
        MemoStore.shared.deletePlaceholder("{없는빈칸_xctest_unique}")
        XCTAssertTrue(MemoStore.shared.loadPlaceholderValues(for: "{없는빈칸_xctest_unique}").isEmpty)
    }

    // MARK: - 지워도 되는 것만 지운다

    /// 쓰는 단축어가 있는 빈칸은 본문에서 다시 읽히므로 지워도 되살아난다.
    /// 그래서 화면은 `isOrphan` 인 것만 지우게 한다. 그 판정이 뒤집히지 않는지 붙잡아 둔다.
    func testOnlyOrphanPlaceholdersAreDeletable() {
        let used = Memo(title: "인사", value: "안녕하세요 \(token)")
        let summaries = PlaceholderCatalog.summaries(from: [used])

        let mine = summaries.first { $0.token == token }
        XCTAssertNotNil(mine, "본문에 쓴 빈칸은 목록에 나와야 한다")
        XCTAssertFalse(mine?.isOrphan ?? true, "쓰는 단축어가 있으면 지울 수 있는 대상이 아니다")

        let orphanOnly = PlaceholderCatalog.summaries(from: []).first { $0.token == token }
        if let orphanOnly {
            XCTAssertTrue(orphanOnly.isOrphan, "쓰는 단축어가 없으면 지울 수 있는 대상이다")
        }
    }
}
