//
//  ReturnKeyLockTests.swift
//  ClipKeyboardTests
//
//  빈 검색창에서 리턴 키를 **잠그는** 규칙을 못박는다.
//
//  어떻게 생긴 문제인가: 조작 키 셋(보내기·지우기·X)을 글이 없어도 세우기로 했다.
//  무대와 익스텐션의 위줄이 서로 달라 보이던 것을 맞추려던 것이었는데, 그러고 나니
//  빈 검색창에 강조색 `검색` 이 눌리게 서 있었다. 눌러 봐야 줄바꿈 하나가 들어갈 뿐이라
//  아무 일도 일어나지 않는다. 이름이 있는 키는 그 이름의 일을 할 것처럼 보인다.
//
//  판단 근거는 우리가 지어내지 않는다. 호스트가 `enablesReturnKeyAutomatically` 로
//  말해 주고, 시스템 키보드도 같은 값을 보고 같이 잠근다.
//
//  ⚠️ 잠그는 것이지 **숨기는 것이 아니다.** 자리가 비면 줄이 흔들리고, 무엇을 누르면
//     되는지도 감춰진다. 그것이 애초에 늘 세우기로 한 이유다.
//

import Testing
@testable import ClipKeyboard

@Suite("리턴 키 잠금")
struct ReturnKeyLockTests {

    private func state(needsText: Bool, hasText: Bool) -> KeyboardDocumentState {
        let s = KeyboardDocumentState()
        s.returnNeedsText = needsText
        s.hasText = hasText
        return s
    }

    @Test("호스트가 시켰고 글이 비었으면 잠근다")
    func locksOnEmptySearchField() {
        #expect(state(needsText: true, hasText: false).returnKeyIsLocked)
    }

    @Test("글이 생기면 풀린다")
    func unlocksOnceThereIsText() {
        #expect(!state(needsText: true, hasText: true).returnKeyIsLocked)
    }

    @Test("호스트가 안 시켰으면 빈 칸에서도 잠그지 않는다")
    func neverLocksWhenHostDidNotAsk() {
        #expect(!state(needsText: false, hasText: false).returnKeyIsLocked)
        #expect(!state(needsText: false, hasText: true).returnKeyIsLocked)
    }

    /// 앱 안의 무대는 그 트레잇을 켜지 않는다. 거기서는 줄바꿈이 제 일을 한다.
    @Test("기본 상태는 잠기지 않는다. 무대가 이 상태다")
    func defaultStateIsUnlocked() {
        #expect(!KeyboardDocumentState().returnKeyIsLocked)
    }
}
