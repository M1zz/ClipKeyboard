//
//  NewMemoIntroTests.swift
//  ClipKeyboardTests
//
//  방금 만든 단축어를 **빈 자리로 먼저 세웠다가** 내용을 들여보내는 연출의 약속.
//
//  왜 생겼나: 사용자 요청. "추가를 하면 너무 뷰가 바로 생기는데 (...) 빈 것을 생성하고
//  나서 1초 뒤에 그 안에 내용을 채우는 것과 같은 느낌을."
//
//  여기서 지키는 약속.
//   ① 만들면 그 자리가 비워진다
//   ② **화면에 나타나기 전에는 시간을 세지 않는다** - 저장 화면이 1초 뒤에 닫히므로,
//      저장한 순간부터 세면 그 1초가 시트 뒤에서 다 지나가고 아무도 못 본다
//   ③ 나타난 뒤 1초가 지나면 내용이 들어온다
//

import XCTest
@testable import ClipKeyboard

@MainActor
final class NewMemoIntroTests: XCTestCase {

    private let intro = NewMemoIntro.shared

    override func tearDown() async throws {
        intro.begin(UUID())          // 남은 연출을 끊는다
        intro.noticeAppeared(intro.blankMemoId ?? UUID())
        try? await Task.sleep(for: .seconds(NewMemoIntro.blankDuration + 0.3))
        try await super.tearDown()
    }

    func test_만들면_그_자리가_비워진다() {
        let id = UUID()
        intro.begin(id)
        XCTAssertTrue(intro.isBlank(id))
    }

    /// 저장 화면은 저장하고 1초 뒤에 닫힌다. 저장한 순간부터 세면 그 1초가 시트 뒤에서
    /// 다 지나가고, 사용자는 완성된 카드가 툭 나타나는 것만 본다. 요청의 반대다.
    func test_화면에_나타나기_전에는_시간을_세지_않는다() async throws {
        let id = UUID()
        intro.begin(id)

        try await Task.sleep(for: .seconds(NewMemoIntro.blankDuration + 0.3))

        XCTAssertTrue(intro.isBlank(id), "아직 안 나타났으면 비운 채로 기다려야 한다")
    }

    func test_나타난_뒤_1초가_지나면_내용이_들어온다() async throws {
        let id = UUID()
        intro.begin(id)
        intro.noticeAppeared(id)

        try await Task.sleep(for: .seconds(NewMemoIntro.blankDuration + 0.4))

        XCTAssertFalse(intro.isBlank(id))
        XCTAssertNil(intro.blankMemoId)
    }

    func test_다른_카드가_나타난_것은_세지_않는다() async throws {
        let id = UUID()
        intro.begin(id)
        intro.noticeAppeared(UUID())   // 남의 카드

        try await Task.sleep(for: .seconds(NewMemoIntro.blankDuration + 0.3))

        XCTAssertTrue(intro.isBlank(id), "그 자리가 나타난 것이 아니면 시간이 흐르면 안 된다")
    }

    /// 잇달아 만들면 마지막 것만 비운다. 앞의 것이 비워진 채로 남으면 그 카드는
    /// 내용 없이 서 있게 된다.
    func test_잇달아_만들면_마지막_것만_비운다() {
        let first = UUID()
        let second = UUID()
        intro.begin(first)
        intro.begin(second)

        XCTAssertFalse(intro.isBlank(first))
        XCTAssertTrue(intro.isBlank(second))
    }
}
