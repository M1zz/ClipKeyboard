//
//  FoldNavigationTests.swift
//  ClipKeyboardTests
//
//  펼친 듀오의 목록 | 자세히(`FoldColumns`) 약속.
//
//   ① 뿌리에서 고르면 다음 장이 하나 열린다. 같은 줄을 다시 고르면 아무 일도 없다
//   ② 앞 장에서 다른 줄을 고르면 그 뒤 장은 버리고 새로 연다(결과 쪽만 바뀐다)
//   ③ 결과 쪽에서 고르면 한 칸 밀리고, 뒤로는 한 장씩 되돌린다
//

import XCTest
import SwiftUI
@testable import ClipKeyboard

@MainActor
final class FoldNavigationTests: XCTestCase {

    private func page(_ name: String) -> AnyView { AnyView(Text(verbatim: name)) }

    // ①
    func test_뿌리에서_고르면_한_장이_열리고_같은_줄은_다시_열지_않는다() {
        let columns = FoldColumns()
        let link = UUID()
        columns.open(page("키보드"), from: 0, sourceID: link)
        XCTAssertEqual(columns.pages.count, 1)
        let first = columns.pages[0].id

        columns.open(page("키보드"), from: 0, sourceID: link)
        XCTAssertEqual(columns.pages.map(\.id), [first], "같은 줄을 다시 눌러도 새로 만들지 않는다")
        XCTAssertEqual(columns.openedSource(after: 0), link)
    }

    // ②
    func test_앞_장에서_다른_줄을_고르면_결과_쪽만_바뀐다() {
        let columns = FoldColumns()
        columns.open(page("키보드"), from: 0, sourceID: UUID())
        columns.open(page("레이아웃"), from: 1, sourceID: UUID())
        XCTAssertEqual(columns.pages.count, 2)

        let other = UUID()
        columns.open(page("화면과 표시"), from: 0, sourceID: other)
        XCTAssertEqual(columns.pages.count, 1, "뿌리에서 다시 고르면 그 뒤에 쌓인 장은 버린다")
        XCTAssertEqual(columns.openedSource(after: 0), other)
    }

    // ③
    func test_결과_쪽에서_고르면_밀리고_뒤로는_한_장씩() {
        let columns = FoldColumns()
        columns.open(page("키보드"), from: 0, sourceID: UUID())
        columns.open(page("레이아웃"), from: 1, sourceID: UUID())
        columns.open(page("언어"), from: 2, sourceID: UUID())
        XCTAssertEqual(columns.pages.count, 3)

        columns.goBack()
        XCTAssertEqual(columns.pages.count, 2)
        columns.goBack(); columns.goBack(); columns.goBack()
        XCTAssertTrue(columns.pages.isEmpty, "뿌리보다 더 뒤로 가지 않는다")
    }

    func test_짝을_가진_화면은_짝과_함께_열린다() {
        let columns = FoldColumns()
        columns.open(page("키보드 레이아웃"), companion: page("키보드 미리보기"), from: 0, sourceID: UUID())
        XCTAssertNotNil(columns.pages.last?.companion)
        XCTAssertTrue(KeyboardLayoutSettings() is any FoldCompanionProviding,
                      "키보드 레이아웃은 펼치면 미리보기를 결과 쪽 판에 세운다")
    }
}
