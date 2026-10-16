//
//  GiftSupportTests.swift
//  ClipKeyboardTests
//
//  선물이 안 될 때의 문의: 결제 문제로 시작하고, 어디서 왔는지가 붙는다.
//

import Foundation
import Testing
import LeeoKit
@testable import ClipKeyboard

@Suite("선물 문의")
struct GiftSupportTests {
    @Test("선물 화면에서 연 문의는 버그로 시작하고, 열린 자리가 '선물하기' 로 붙는다")
    func giftOrigin() {
        #expect(FeedbackOrigin.gift.rawValue == "gift")
        #expect(FeedbackOrigin.gift.suggestedType == .bug)
        #expect(FeedbackContext.lines(origin: .gift).joined().contains(FeedbackOrigin.gift.localizedName))
    }
}
