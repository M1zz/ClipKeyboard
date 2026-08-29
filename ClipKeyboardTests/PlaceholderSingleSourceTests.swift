//
//  PlaceholderSingleSourceTests.swift
//  ClipKeyboardTests
//
//  빈칸 값의 **본진이 하나**인지 지킨다.
//
//  값은 두 곳에 있다. 공용 저장소(`placeholder_values_{이름}`)가 본진이고, 단축어에 붙은
//  사본(`Memo.placeholderValues`)은 옛 데이터를 위한 폴백이다. 키보드는 본진이 비었을 때만
//  사본을 본다.
//
//  ⚠️ 여기가 깨지면 **지운 값이 키보드에서 되살아난다.** 사용자가 지웠다는 것을 믿지 못하게
//     되는 순간이라, 값 하나 남는 것보다 훨씬 큰 문제다.
//

import XCTest
@testable import ClipKeyboard

final class PlaceholderSingleSourceTests: XCTestCase {

    private let token = "{시험빈칸}"

    override func setUp() {
        super.setUp()
        try? MemoStore.shared.save(memos: [], type: .memo, recordHistory: false)
        MemoStore.shared.savePlaceholderValues([], for: token)
    }

    override func tearDown() {
        try? MemoStore.shared.save(memos: [], type: .memo, recordHistory: false)
        AppGroup.defaults?.removeObject(forKey: "placeholder_values_\(token)")
        super.tearDown()
    }

    /// 지우면 단축어에 붙은 사본에서도 함께 사라진다. 폴백이 지운 값을 되살리면 안 된다.
    func test_지운_값은_단축어에_붙은_사본에서도_사라진다() throws {
        var memo = Memo(title: "인사", value: "\(token)님 안녕하세요")
        memo.placeholderValues = [token: ["홍길동", "김민수"]]
        try MemoStore.shared.save(memos: [memo], type: .memo, recordHistory: false)

        MemoStore.shared.addPlaceholderValue("홍길동", for: token,
                                             sourceMemoId: memo.id, sourceMemoTitle: memo.title)

        let saved = try XCTUnwrap(MemoStore.shared.loadPlaceholderValues(for: token).first)
        MemoStore.shared.deletePlaceholderValue(valueId: saved.id, for: token)

        let after = try MemoStore.shared.load(type: .memo).first?.placeholderValues[token] ?? []
        XCTAssertFalse(after.contains("홍길동"), "사본에 남아 있으면 키보드에서 되살아난다")
        XCTAssertTrue(after.contains("김민수"), "지우라고 한 적 없는 값까지 없애면 안 된다")
    }

    /// 사본에만 있던 빈칸이 통째로 비면 키 자체를 걷어낸다. 빈 배열이 남으면 "값 0개"가
    /// 목록에 서서, 지웠는데도 뭔가 남은 것처럼 보인다.
    func test_사본이_비면_키까지_걷어낸다() throws {
        var memo = Memo(title: "인사", value: "\(token)님")
        memo.placeholderValues = [token: ["하나뿐"]]
        try MemoStore.shared.save(memos: [memo], type: .memo, recordHistory: false)

        MemoStore.shared.addPlaceholderValue("하나뿐", for: token,
                                             sourceMemoId: memo.id, sourceMemoTitle: memo.title)
        let saved = try XCTUnwrap(MemoStore.shared.loadPlaceholderValues(for: token).first)
        MemoStore.shared.deletePlaceholderValue(valueId: saved.id, for: token)

        let copies = try MemoStore.shared.load(type: .memo).first?.placeholderValues
        XCTAssertNil(copies?[token])
    }

    /// 사본이 없는 단축어를 지울 때도 조용히 지나간다(저장 파일을 건드리지 않는다).
    func test_사본이_없어도_지우기는_그냥_된다() throws {
        let memo = Memo(title: "인사", value: "\(token)님")
        try MemoStore.shared.save(memos: [memo], type: .memo, recordHistory: false)

        MemoStore.shared.addPlaceholderValue("값", for: token,
                                             sourceMemoId: memo.id, sourceMemoTitle: memo.title)
        let saved = try XCTUnwrap(MemoStore.shared.loadPlaceholderValues(for: token).first)
        MemoStore.shared.deletePlaceholderValue(valueId: saved.id, for: token)

        XCTAssertTrue(MemoStore.shared.loadPlaceholderValues(for: token).isEmpty)
        XCTAssertEqual(try MemoStore.shared.load(type: .memo).count, 1)
    }
}
