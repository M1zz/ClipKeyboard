//
//  BulkImportNudgeTests.swift
//  ClipKeyboardTests
//
//  "한 번에 정리하기"를 언제 내놓는지 시험한다.
//  저장소는 건드리지 않고 순수 함수만 본다.
//

import Testing
import Foundation
@testable import ClipKeyboard

struct BulkImportNudgeTests {

    // MARK: - 붙여넣은 글이 목록처럼 생겼는가

    @Test("여러 줄이면 줄 수를 센다")
    func countsLines() {
        let text = "김지호 010-1111-2222\n박서연 010-3333-4444\n최하준 010-5555-6666"
        #expect(BulkImportNudge.splittableLineCount(in: text) == 3)
    }

    @Test("빈 줄은 세지 않는다")
    func ignoresBlankLines() {
        // 사람이 옮겨 적은 목록은 줄 사이가 비어 있기 일쑤다.
        let text = "첫째\n\n둘째\n\n\n셋째\n"
        #expect(BulkImportNudge.splittableLineCount(in: text) == 3)
    }

    @Test("두 줄은 목록으로 보지 않는다")
    func twoLinesIsNotAList() {
        #expect(BulkImportNudge.splittableLineCount(in: "첫째\n둘째") == nil)
    }

    @Test("한 줄짜리는 목록이 아니다")
    func singleLineIsNotAList() {
        #expect(BulkImportNudge.splittableLineCount(in: "계좌번호 110-1234-5678") == nil)
    }

    @Test("줄이 너무 길면 목록이 아니라 글이다")
    func longLinesAreProse() {
        // 문단을 줄 단위로 쪼개 주겠다고 나서면 도움이 아니라 방해다.
        let paragraph = String(repeating: "가", count: 250)
        let text = "\(paragraph)\n\(paragraph)\n\(paragraph)"
        #expect(BulkImportNudge.splittableLineCount(in: text) == nil)
    }

    @Test("빈 글은 아무것도 아니다")
    func emptyIsNothing() {
        #expect(BulkImportNudge.splittableLineCount(in: "") == nil)
        #expect(BulkImportNudge.splittableLineCount(in: "\n\n\n") == nil)
    }

    // MARK: - 줄줄이 만드는 중인가

    @Test("짧은 사이에 이어 만들면 이어진 것으로 본다")
    func shortGapContinuesStreak() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let justBefore = now.addingTimeInterval(-60)
        #expect(BulkImportNudge.continuesStreak(lastAt: justBefore, now: now) == true)
    }

    @Test("한참 뒤면 이어진 것이 아니다")
    func longGapBreaksStreak() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let longAgo = now.addingTimeInterval(-(BulkImportNudge.manualStreakWindow + 1))
        #expect(BulkImportNudge.continuesStreak(lastAt: longAgo, now: now) == false)
    }

    @Test("처음 만드는 것은 이어진 것이 아니다")
    func firstCreateIsNotAStreak() {
        #expect(BulkImportNudge.continuesStreak(lastAt: nil, now: Date()) == false)
    }

    @Test("시계가 거꾸로 가도 이어진 것으로 치지 않는다")
    func negativeGapIsNotAStreak() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let future = now.addingTimeInterval(60)
        #expect(BulkImportNudge.continuesStreak(lastAt: future, now: now) == false)
    }

    // MARK: - 아직 몇 개 없는 사람

    @Test("몇 개 없으면 처음 온 사람으로 본다")
    func fewSnippetsMeansNewcomer() {
        #expect(BulkImportNudge.isNewcomer(memoCount: 0) == true)
        #expect(BulkImportNudge.isNewcomer(memoCount: BulkImportNudge.newcomerMaxCount) == true)
        #expect(BulkImportNudge.isNewcomer(memoCount: BulkImportNudge.newcomerMaxCount + 1) == false)
    }
}
