//
//  ClipboardCaptureTests.swift
//  ClipKeyboardTests
//
//  '버튼 한 번으로 담기' 의 순수한 부분: 어느 기종에 동작 버튼이 있는가, 담은 뒤 무엇을 말하는가.
//  끝에서 끝까지의 길은 `BasicScenarioTests/test_복사하고_버튼을_누르면_키보드_최근에_담긴다`.
//

import Foundation
import Testing
@testable import ClipKeyboard

@Suite("버튼 한 번으로 담기")
struct ClipboardCaptureTests {

    @Test("동작 버튼은 15 Pro 부터, 15 · 15 Plus 와 그 이전 · 아이패드에는 없다",
          arguments: [
            ("iPhone16,1", true), ("iPhone16,2", true),      // 15 Pro · 15 Pro Max
            ("iPhone17,1", true), ("iPhone17,5", true),      // 16 Pro · 16e
            ("iPhone18,3", true),                            // 17
            ("iPhone15,4", false), ("iPhone15,5", false),    // 15 · 15 Plus
            ("iPhone14,2", false),                           // 13 Pro
            ("iPad16,3", false), ("arm64", false), ("", false)
          ])
    func actionButtonModels(model: String, expected: Bool) {
        #expect(ActionButtonSupport.hasActionButton(model: model) == expected)
    }

    @Test("담은 글은 첫 줄만, 길면 줄여서 알린다")
    func capturedMessageShowsShortPreview() {
        let long = String(repeating: "가", count: 40) + "\n둘째 줄"
        let message = ClipboardCapture.message(for: .captured(long))
        #expect(!message.contains("둘째 줄"))
        #expect(message.contains("…"))
    }

    @Test("못 담은 까닭마다 다른 말을 한다(거절한 사람에게 '복사한 글이 없다' 고 하지 않는다)")
    func failureMessagesDiffer() {
        let messages = Set([ClipboardCapture.Outcome.empty, .refused, .failed].map(ClipboardCapture.message(for:)))
        #expect(messages.count == 3)
    }
}
