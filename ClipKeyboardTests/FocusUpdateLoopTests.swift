//
//  FocusUpdateLoopTests.swift
//  ClipKeyboardTests
//
//  **뷰를 그리는 도중에 입력 포커스를 바꾸지 않는가.**
//
//  5.0.4 워치독 종료 리포트 하나를 심볼로 확정했더니 이 스택이었다.
//
//      -[UIResponder _setFirstResponder:] ↔ -[UIView _setFirstResponder:]
//        → _UIHostingView._didChange(toFirstResponder:)
//        → ViewGraphRootValueUpdater.updateGraph()
//
//  UIKit 이 호스팅 뷰에 "first responder 가 바뀌었다" 고 알리면 SwiftUI 는 뷰 그래프를
//  다시 계산한다. 그 갱신이 `updateUIView` 로 들어오고 거기서 다시 first responder 를
//  바꾸면 고리가 닫힌다. `HighlightedTextEditor` 가 정확히 그러고 있었다.
//
//  여기서 지키는 것은 값이 아니라 **시점**이다. 포커스를 바꾸는 일이 갱신 밖으로
//  나가 있는가. 되돌아가면 앱이 다시 스스로를 갱신하며 CPU 를 태운다.
//

import XCTest
import SwiftUI
@testable import ClipKeyboard

@MainActor
final class FocusUpdateLoopTests: XCTestCase {

    private var window: UIWindow!
    private var textView: UITextView!

    override func setUp() {
        super.setUp()
        // 창에 붙어 있지 않으면 becomeFirstResponder 가 애초에 실패해서
        // 미룬 것과 구분이 안 된다. 진짜 창을 하나 세운다.
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        } else {
            window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        }
        textView = UITextView(frame: window.bounds)
        window.addSubview(textView)
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        textView.resignFirstResponder()
        window.isHidden = true
        window = nil
        textView = nil
        super.tearDown()
    }

    private func makeCoordinator(focused: Bool) -> HighlightedTextEditor.Coordinator {
        let editor = HighlightedTextEditor(text: .constant("값"), isFocused: .constant(focused))
        return HighlightedTextEditor.Coordinator(editor)
    }

    /// 부른 그 자리에서 포커스를 옮기지 않는다.
    ///
    /// `updateUIView` 안에서 곧바로 옮기면 그게 곧 "갱신 도중의 상태 변경" 이다.
    func test_부른_자리에서_바로_옮기지_않는다() {
        let coordinator = makeCoordinator(focused: true)

        coordinator.syncFocus(textView, desired: true)

        XCTAssertFalse(textView.isFirstResponder,
                       "갱신 도중에 first responder 를 바꿨다. updateUIView 안에서 직접 부르고 있는지 확인할 것")
    }

    /// 한 박자 뒤에는 제대로 옮긴다. 미루기만 하고 안 하면 키보드가 안 올라온다.
    func test_한_박자_뒤에는_옮긴다() async throws {
        let coordinator = makeCoordinator(focused: true)

        coordinator.syncFocus(textView, desired: true)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(textView.isFirstResponder, "미루기만 하고 실제로 옮기지 않았다")
    }

    /// 이미 그 상태면 아무것도 하지 않는다. 같은 값을 다시 쓰면 갱신만 한 번 더 돈다.
    func test_이미_같은_상태면_건드리지_않는다() async throws {
        let coordinator = makeCoordinator(focused: false)

        // 먼저 포커스를 준다.
        coordinator.syncFocus(textView, desired: true)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(textView.isFirstResponder)

        // 같은 값을 다시 요청해도 포커스는 그대로다.
        coordinator.syncFocus(textView, desired: true)
        try await Task.sleep(nanoseconds: 60_000_000)
        XCTAssertTrue(textView.isFirstResponder)
    }

    /// 놓는 쪽도 같은 규칙이다.
    func test_놓을_때도_한_박자_뒤에_놓는다() async throws {
        let coordinator = makeCoordinator(focused: true)
        textView.becomeFirstResponder()
        XCTAssertTrue(textView.isFirstResponder)

        coordinator.syncFocus(textView, desired: false)
        XCTAssertTrue(textView.isFirstResponder, "부른 자리에서 바로 놓았다")

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(textView.isFirstResponder, "미룬 뒤에도 놓지 않았다")
    }
}
