//
//  InAppKeyboardHostTests.swift
//  ClipKeyboardTests
//
//  앱 안 무대(InAppKeyboardStage)가 글을 받는 자리의 계약을 고정한다.
//
//  왜 이 테스트가 필요한가: 같은 `KeyboardView`가 익스텐션과 앱 두 곳에서 산다.
//  익스텐션 쪽 종착지(`KeyboardViewController`)는 사람이 키보드를 띄워야만 돌아가므로
//  테스트가 닿지 않는다. 앱 쪽 종착지는 순수한 객체라 여기서 붙잡아 둘 수 있고,
//  **두 종착지가 같은 규칙을 지키는가**가 이 화면의 전부다.
//
//  특히 캐럿: `{커서}` 토큰이 있는 문구를 넣고 나면 캐럿이 그 자리로 되돌아와야 한다.
//  이게 깨지면 "템플릿을 넣었는데 커서가 문장 끝에 있다"가 되어 손으로 되돌아가야 한다.
//

import Testing
import Foundation
@testable import ClipKeyboard

// ⚠️ `.serialized` — 문구 삽입은 **알림**으로 전달된다(익스텐션과 같은 경로).
//    병렬로 돌리면 A 테스트가 쏜 알림을 B 테스트의 무대가 받아 서로의 입력창에 글이 섞인다.
//    실제 앱에서는 무대가 한 번에 하나뿐이라 생기지 않는 상황이다.
@Suite("InAppKeyboardHost — 앱 안 키보드가 글을 넣는 자리", .serialized)
@MainActor
struct InAppKeyboardHostTests {

    // MARK: - 타이핑

    @Test("글자를 넣으면 캐럿이 뒤따라 온다")
    func insertMovesCaret() {
        let host = InAppKeyboardHost()
        host.insertText("안녕")
        #expect(host.text == "안녕")
        #expect(host.caret == 2)
    }

    @Test("지우기는 캐럿 **앞** 글자를 지운다 — 문장 끝이 아니라")
    func deleteRemovesBeforeCaret() {
        let host = InAppKeyboardHost()
        host.insertText("가나다")
        host.deleteBackward()          // 캐럿은 맨 뒤 → '다'가 지워진다
        #expect(host.text == "가나")

        // 캐럿을 앞으로 돌린 뒤 지우면 그 자리 앞 글자가 지워져야 한다.
        host.clearAll()
        host.insertText("가나다")
        host.deleteBackward()          // "가나"
        host.deleteBackward()          // "가"
        #expect(host.text == "가")
        #expect(host.caret == 1)
    }

    @Test("빈 칸에서 지우기를 눌러도 무너지지 않는다")
    func deleteOnEmptyIsSafe() {
        let host = InAppKeyboardHost()
        host.deleteBackward()
        #expect(host.text.isEmpty)
        #expect(host.caret == 0)
    }

    @Test("전체 삭제는 글과 캐럿을 함께 되돌린다")
    func clearAllResetsCaret() {
        let host = InAppKeyboardHost()
        host.insertText("지워질 글")
        host.clearAll()
        #expect(host.text.isEmpty)
        #expect(host.caret == 0)
    }

    @Test("X(전체 삭제) 버튼은 글이 있을 때만 나타난다")
    func documentStateFollowsText() {
        let host = InAppKeyboardHost()
        #expect(host.documentState.hasText == false)
        host.insertText("가")
        #expect(host.documentState.hasText == true)
        host.deleteBackward()
        #expect(host.documentState.hasText == false)
    }

    @Test("커서 오른쪽 이동은 글 끝을 넘지 않는다")
    func cursorRightStopsAtEnd() {
        let host = InAppKeyboardHost()
        host.insertText("가나")
        host.cursorRight()                  // 이미 끝 — 그대로
        #expect(host.caret == 2)
    }

    // MARK: - 문구 삽입 (KeyboardView가 쏘는 알림 경로)

    @Test("문구를 누르면 입력창에 들어간다")
    func addTextEntryInserts() async {
        let host = InAppKeyboardHost()
        NotificationCenter.default.post(name: .addTextEntry,
                                        object: "leeo@kakao.com",
                                        userInfo: ["memoId": UUID()])
        await settle()
        #expect(host.text == "leeo@kakao.com")
    }

    @Test("`{커서}` 가 있으면 캐럿이 그 자리로 되돌아온다")
    func cursorTokenPlacesCaret() async {
        let host = InAppKeyboardHost()
        NotificationCenter.default.post(name: .addTextEntry,
                                        object: "안녕하세요 {커서} 드림",
                                        userInfo: ["memoId": UUID()])
        await settle()
        // 토큰은 사라지고, 캐럿은 토큰이 있던 자리에 선다.
        #expect(!host.text.contains("{커서}"))
        #expect(host.caret == host.text.count - " 드림".count)
    }

    @Test("사용자가 채워야 할 변수가 있으면 **바로 넣지 않는다** — 물어보러 간다")
    func placeholderDefersInsertion() async {
        let host = InAppKeyboardHost()
        NotificationCenter.default.post(name: .addTextEntry,
                                        object: "{이름}님 안녕하세요",
                                        userInfo: ["memoId": UUID()])
        await settle()
        // 값을 묻는 오버레이가 뜨는 경로 — 입력창은 아직 비어 있어야 한다.
        // (여기서 넣어 버리면 "{이름}" 이 그대로 붙여넣어진다)
        #expect(host.text.isEmpty)
    }

    @Test("값을 다 채우면 그때 들어간다")
    func templateCompletionInserts() async {
        let host = InAppKeyboardHost()
        NotificationCenter.default.post(
            name: .templateInputComplete,
            object: nil,
            userInfo: ["text": "{이름}님 안녕하세요", "inputs": ["{이름}": "이영훈"]]
        )
        await settle()
        #expect(host.text == "이영훈님 안녕하세요")
    }

    // MARK: - 무대

    @Test("보내면 말풍선이 되고 입력창은 비워진다")
    func sendMovesTextToBubble() {
        let host = InAppKeyboardHost()
        let before = host.messages.count
        host.insertText("보낼 말")
        host.send()
        #expect(host.messages.count == before + 1)
        #expect(host.messages.last?.side == .outgoing)
        #expect(host.messages.last?.text == "보낼 말")
        #expect(host.text.isEmpty)
    }

    @Test("빈 입력은 보내지지 않는다 — 빈 말풍선이 쌓이면 안 된다")
    func sendIgnoresEmpty() {
        let host = InAppKeyboardHost()
        let before = host.messages.count
        host.send()
        host.insertText("   ")
        host.send()
        #expect(host.messages.count == before)
    }

    // MARK: - 앱에서는 클립보드가 항상 열려 있다

    @Test("무대를 만들면 전체 접근이 켜진 것으로 본다 — 앱에는 그 제한이 없다")
    func appHostHasFullAccess() {
        _ = InAppKeyboardHost()
        #expect(KeyboardCapability.hasFullAccess)
        // 지구본(다음 키보드)은 앱 안에서 갈 곳이 없다.
        #expect(KeyboardCapability.needsInputModeSwitchKey == false)
    }

    /// 알림은 메인 큐로 전달되므로 한 바퀴 양보한다.
    private func settle() async {
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))
    }
}
