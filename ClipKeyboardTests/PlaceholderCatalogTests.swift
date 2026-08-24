//
//  PlaceholderCatalogTests.swift
//  ClipKeyboardTests
//
//  빈칸이 **이름 하나로 묶이는지**를 지킨다.
//
//  ⚠️ 여기가 깨지면 사용자는 같은 빈칸을 템플릿마다 새로 만들게 된다.
//     값 저장이 이름 기준(`placeholder_values_{이름}`)인데 화면이 그렇게 안 보이면,
//     이름이 갈라지고 값도 갈라진다.
//

import XCTest
@testable import ClipKeyboard

final class PlaceholderCatalogTests: XCTestCase {

    private func makeMemo(_ title: String, _ value: String) -> Memo {
        Memo(title: title, value: value)
    }

    /// 서로 다른 단축어의 같은 이름은 **하나로** 묶인다. 이게 이 화면의 전제다.
    func test_같은_이름은_한_빈칸으로_묶인다() {
        let memos = [
            makeMemo("새해인사", "{이름}님, 새해 복 많이 받으세요"),
            makeMemo("안부", "{이름}님 잘 지내시죠?")
        ]

        let summaries = PlaceholderCatalog.summaries(from: memos)
        let name = summaries.first { $0.token == "{이름}" }

        XCTAssertNotNil(name)
        XCTAssertEqual(name?.memos.count, 2, "같은 이름인데 둘로 갈렸다")
    }

    /// 쓰임이 많은 것이 앞에 온다. 고를 때 손이 먼저 닿는 자리다.
    func test_많이_쓰는_빈칸이_앞에_온다() {
        let memos = [
            makeMemo("가", "{회사명} 드림"),
            makeMemo("나", "{회사명} 담당 {이름}"),
            makeMemo("다", "{회사명}")
        ]

        let tokens = PlaceholderCatalog.summaries(from: memos).map(\.token)
        XCTAssertEqual(tokens.first, "{회사명}")
        XCTAssertTrue(tokens.contains("{이름}"))
    }

    /// 자동 변수는 빈칸이 아니다. 채울 것이 없는데 목록에 서면 고르라고 내미는 셈이 된다.
    func test_자동_변수는_빈칸으로_치지_않는다() {
        let memos = [makeMemo("영수증", "{날짜} {시간} {클립보드} {금액}")]

        let tokens = PlaceholderCatalog.summaries(from: memos).map(\.token)
        XCTAssertFalse(tokens.contains("{날짜}"))
        XCTAssertFalse(tokens.contains("{시간}"))
        XCTAssertFalse(tokens.contains("{클립보드}"))
        XCTAssertTrue(tokens.contains("{금액}"), "금액은 사용자가 채우는 칸이다")
    }

    /// 금액·수량은 숫자 칸이다. 값을 저장하지 않으므로 화면도 다르게 그린다.
    func test_금액은_숫자_칸으로_본다() {
        let memos = [makeMemo("입금", "{금액}원 보내주세요. 받는 분 {이름}")]
        let summaries = PlaceholderCatalog.summaries(from: memos)

        XCTAssertEqual(summaries.first { $0.token == "{금액}" }?.isNumeric, true)
        XCTAssertEqual(summaries.first { $0.token == "{이름}" }?.isNumeric, false)
    }

    /// 쓰는 곳이 없고 값도 없는 이름은 **골라 넣는 목록에 세우지 않는다.**
    /// (오타로 한 번 만들어진 이름이 영영 남으면 고르라고 내민 것이 헷갈리게 한다)
    func test_고를_목록에는_쓰이는_것만_올린다() {
        let memos = [makeMemo("인사", "{이름}님 안녕하세요")]

        let insertable = PlaceholderCatalog.insertable(from: memos)
        XCTAssertTrue(insertable.allSatisfy { !$0.memos.isEmpty || $0.valueCount > 0 })
        XCTAssertTrue(insertable.contains { $0.token == "{이름}" })
    }

    /// 목록은 끝이 있어야 한다. 스무 개가 가로로 늘어서면 고르는 일이 아니라 훑는 일이 된다.
    func test_고를_목록에는_끝이_있다() {
        let memos = (1...30).map { makeMemo("메모\($0)", "{빈칸\($0)} 자리") }
        XCTAssertLessThanOrEqual(PlaceholderCatalog.insertable(from: memos).count, 12)
    }

    /// 빈칸이 없는 단축어는 목록에 아무것도 보태지 않는다.
    ///
    /// ⚠️ "목록이 비어 있다"로 재지 않는다. 기기에 예전 값이 남아 있으면 그것들이 목록에
    ///    서 있을 수 있고, 그건 이 시험이 볼 일이 아니다. **이 단축어들 때문에 늘었는지**만 본다.
    func test_빈칸이_없는_단축어는_목록을_늘리지_않는다() {
        let before = PlaceholderCatalog.insertable(from: []).map(\.token)
        let after = PlaceholderCatalog.insertable(from: [makeMemo("계좌", "1002-345-678901")]).map(\.token)
        XCTAssertEqual(before, after)
    }
}
