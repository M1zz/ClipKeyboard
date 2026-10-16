//
//  TipAskAndRoadmapTests.swift
//  ClipKeyboardTests
//
//  팁 부탁 카드가 언제 서는가(`TipAskMoments`)와 로드맵 원본(`ClipKeyboardRoadmap.swift`)이 성한가.
//

import Foundation
import Testing
import LeeoKit
@testable import ClipKeyboard

@Suite("팁 부탁 · 로드맵")
struct TipAskAndRoadmapTests {

    @Test("숫자가 아직 작으면 묻지 않는다")
    func nothingBeforeValue() {
        #expect(TipAskMoments.reached(timeSavedSeconds: 59 * 60, pasteCount: 99).isEmpty)
    }

    @Test("넘어선 순간은 아낀 시간부터, 큰 것부터")
    func impressiveFirst() {
        let reached = TipAskMoments.reached(timeSavedSeconds: 6 * 3600, pasteCount: 600)
        #expect(reached.map(\.id) == ["saved.5h", "saved.1h", "paste.500", "paste.100"])
        #expect(reached.first?.message.contains("6") == true, "그 사람의 실제 숫자를 말한다")
    }

    @Test("한 번 물으면 함께 넘은 작은 순간까지 끝나고, 60일 동안 다시 묻지 않는다")
    func asksRarely() {
        let now = Date()
        let reached = TipAskMoments.reached(timeSavedSeconds: 6 * 3600, pasteCount: 600)
        let first = LeeoTipAskPolicy.pick(reached: reached, seen: [], lastAskedAt: nil, lastTipAt: nil, laters: 0, now: now)
        #expect(first?.id == "saved.5h")
        let seen = Set(reached.map(\.id))
        #expect(LeeoTipAskPolicy.pick(reached: reached, seen: seen, lastAskedAt: now, lastTipAt: nil, laters: 0,
                                      now: now.addingTimeInterval(90 * 86400)) == nil)
        // 다음 순간(20시간)은 60일이 지난 뒤에야
        let more = TipAskMoments.reached(timeSavedSeconds: 21 * 3600, pasteCount: 600)
        #expect(LeeoTipAskPolicy.pick(reached: more, seen: seen, lastAskedAt: now, lastTipAt: nil, laters: 0,
                                      now: now.addingTimeInterval(30 * 86400)) == nil)
        #expect(LeeoTipAskPolicy.pick(reached: more, seen: seen, lastAskedAt: now, lastTipAt: nil, laters: 0,
                                      now: now.addingTimeInterval(61 * 86400))?.id == "saved.20h")
    }

    @Test("로드맵: id 가 겹치지 않고 이름이 비지 않는다")
    func roadmapIsSound() {
        let ids = ClipKeyboardSpec.roadmap.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(!LeeoPreflight.audit(ClipKeyboardSpec.self).contains { $0.code.hasPrefix("roadmap.") })
        #expect(ClipKeyboardSpec.roadmap.allSatisfy { !$0.title.isEmpty })
    }
}
