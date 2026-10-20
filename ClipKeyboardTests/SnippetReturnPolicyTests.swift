//
//  SnippetReturnPolicyTests.swift
//  ClipKeyboardTests
//
//  단축어를 넣은 뒤 쓰던 키보드로 돌아가는 규칙(`SnippetReturnPolicy`).
//  키보드를 실제로 바꾸는 일은 익스텐션에서만 돌아 시험이 닿지 않는다. 언제 바꿀지만 지킨다.
//
//  ⚠️ 여기 시험 이름은 docs/engineering/USER_JOURNEYS.md 의 표에 걸려 있다.
//

import XCTest
@testable import ClipKeyboard

final class SnippetReturnPolicyTests: XCTestCase {

    /// 켜 두면 단축어를 다 넣은 뒤에만 넘긴다. 스택 중간 · 값 하나 넣기 · 우리 자판으로 친 판에서는 넘기지 않는다.
    func test_단축어를_다_넣으면_쓰던_키보드로_돌아가고_끄면_그대로다() {
        XCTAssertTrue(SnippetReturnPolicy.shouldSwitch(after: .snippetFinished, enabled: true, typedOnTypingPanel: false))
        XCTAssertFalse(SnippetReturnPolicy.shouldSwitch(after: .stackStep, enabled: true, typedOnTypingPanel: false),
                       "스택 중간에 넘기면 남은 값이 들어갈 곳이 사라진다")
        XCTAssertFalse(SnippetReturnPolicy.shouldSwitch(after: .stackSingleValue, enabled: true, typedOnTypingPanel: false),
                       "값 하나 넣기는 다음 칸에 다음 값을 넣으러 다시 오는 자리다")
        XCTAssertFalse(SnippetReturnPolicy.shouldSwitch(after: .snippetFinished, enabled: true, typedOnTypingPanel: true),
                       "우리 자판으로 치던 사람에게는 우리가 쓰던 키보드다")
        XCTAssertFalse(SnippetReturnPolicy.shouldSwitch(after: .snippetFinished, enabled: false, typedOnTypingPanel: false),
                       "끈 사람은 넘기지 않는다")
    }

    /// 앱 주인이 바란 동작이라 기본은 켬이다. 설정 화면과 키보드가 같은 기본값을 본다.
    func test_기본은_켬이고_설정과_키보드가_같은_키를_본다() {
        XCTAssertTrue(KeyboardPrefs.returnAfterSnippet.fallback)
        XCTAssertEqual(KeyboardPrefs.returnAfterSnippet.key, DefaultsKey.keyboardReturnAfterSnippet)
    }
}
