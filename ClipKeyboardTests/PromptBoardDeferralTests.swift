//
//  PromptBoardDeferralTests.swift
//  ClipKeyboardTests
//
//  게시판(`PromptBoard`)이 **손이 오르내린 그 자리에서 고르지 않는다**는 약속.
//
//  띠는 화면이 갱신되는 도중에 손을 들고 내린다. 그 자리에서 고른 결과를 바꾸면 갱신 도중에 또 갱신이
//  걸리고, 그 결과가 띠를 세우거나 걷어 다시 손이 오르내린다. 그 고리가 한 프레임 안에서 돌면 화면이
//  끝나지 않는다(docs/postmortem/LAUNCH_INCOMPLETE_BACKGROUND_WAKE_5_1_24.md 4절).
//
//   ① 손을 들어도 그 자리에서는 고른 결과가 바뀌지 않는다. 다음 차례에 바뀐다
//   ② 같은 차례에 들었다 내린 손은 없던 일이다. 결과를 한 번도 바꾸지 않는다
//   ③ 한 차례에 손이 여러 번 올라도 결과는 한 번만 바뀐다
//

import XCTest
import Combine
@testable import ClipKeyboard

@MainActor
final class PromptBoardDeferralTests: XCTestCase {

    /// 다음 차례로 넘긴 일이 돌 때까지 기다린다.
    private func settle() async {
        for _ in 0..<5 { await Task.yield() }
        try? await Task.sleep(for: .milliseconds(50))
    }

    func testRaisingHandDoesNotPickSynchronously() async {
        let board = PromptBoard(order: [.accessEnding])

        board.set(.accessEnding, wants: true, token: UUID())
        XCTAssertFalse(board.isPicked(.accessEnding), "손을 든 그 자리에서 골랐다. 화면 갱신 도중에 또 갱신이 걸린다")

        await settle()
        XCTAssertTrue(board.isPicked(.accessEnding), "다음 차례에는 골라야 한다")
    }

    func testRaiseAndLowerInSameTurnChangesNothing() async {
        let board = PromptBoard(order: [.accessEnding])
        var publishes = 0
        let watching = board.objectWillChange.sink { publishes += 1 }
        let token = UUID()

        board.set(.accessEnding, wants: true, token: token)
        board.set(.accessEnding, wants: false, token: token)
        await settle()

        XCTAssertEqual(publishes, 0, "같은 차례에 들었다 내린 손이 결과를 바꿨다. 띠가 깜빡이며 고리의 재료가 된다")
        XCTAssertFalse(board.isPicked(.accessEnding))
        watching.cancel()
    }

    func testManyRaisesInOneTurnPublishOnce() async {
        let board = PromptBoard(order: [.accessEnding, .keyboardSetup])
        var publishes = 0
        let watching = board.objectWillChange.sink { publishes += 1 }

        for _ in 0..<10 { board.set(.accessEnding, wants: true, token: UUID()) }
        await settle()

        XCTAssertEqual(publishes, 1, "한 차례에 오른 손은 한 번에 모아 고른다")
        watching.cancel()
    }
}
