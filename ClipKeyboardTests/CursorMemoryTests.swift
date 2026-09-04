//
//  CursorMemoryTests.swift
//  ClipKeyboardTests
//
//  캐럿 자리 배우기의 **판정**을 시험한다.
//  저장소(App Group)는 건드리지 않고 순수 함수 둘만 본다
//  (`offsetFromCaretMove` · `merging`). 틀린 자동화는 없는 것만 못해서,
//  "안 배워야 하는 경우"를 배우는 경우보다 많이 적었다.
//

import Testing
import Foundation
@testable import ClipKeyboard

struct CursorMemoryTests {

    // MARK: - 캐럿 이동 읽기

    @Test("넣은 글 안쪽으로 캐럿을 옮기면 그 거리를 낸다")
    func detectsCaretMoveInsideInsertedText() {
        // "안녕하세요 님" 을 넣고, 캐럿을 "님" 앞으로 옮겼다.
        let inserted = "안녕하세요 님"
        let offset = CursorMemory.offsetFromCaretMove(
            insertedText: inserted,
            beforeContextAtInsert: "안녕하세요 님",
            beforeContextNow: "안녕하세요 "
        )
        #expect(offset == 1)
    }

    @Test("앞에 이미 있던 글이 있어도 거리는 넣은 글 기준이다")
    func detectsCaretMoveWithPrecedingText() {
        let offset = CursorMemory.offsetFromCaretMove(
            insertedText: "계좌 1234-5678 입니다",
            beforeContextAtInsert: "받는 곳: 계좌 1234-5678 입니다",
            beforeContextNow: "받는 곳: 계좌 1234-5678 "
        )
        #expect(offset == "입니다".count)
    }

    @Test("캐럿이 그대로면 배울 것이 없다")
    func noMoveMeansNothingToLearn() {
        // 이게 핵심이다. 넣고 나서 그냥 이어 쓰는 사람은 기본 동작이 이미 맞다.
        let offset = CursorMemory.offsetFromCaretMove(
            insertedText: "안녕하세요",
            beforeContextAtInsert: "안녕하세요",
            beforeContextNow: "안녕하세요"
        )
        #expect(offset == nil)
    }

    @Test("캐럿이 넣은 글보다 더 앞으로 가면 배우지 않는다")
    func caretOutsideInsertedTextIsIgnored() {
        // 넣은 글을 지나 원래 있던 문장까지 올라간 경우.
        let offset = CursorMemory.offsetFromCaretMove(
            insertedText: "계좌",
            beforeContextAtInsert: "받는 곳: 계좌",
            beforeContextNow: "받는 "
        )
        #expect(offset == nil)
    }

    @Test("사이 글이 바뀌었으면 배우지 않는다")
    func changedTextIsIgnored() {
        // 캐럿 앞 글이 넣은 글의 꼬리와 안 맞는다. 사용자가 그 사이 글을 고쳤다는 뜻.
        let offset = CursorMemory.offsetFromCaretMove(
            insertedText: "안녕하세요 님",
            beforeContextAtInsert: "안녕하세요 님",
            beforeContextNow: "반갑"
        )
        #expect(offset == nil)
    }

    @Test("캐럿이 뒤로 갔으면 배우지 않는다")
    func forwardMoveIsIgnored() {
        let offset = CursorMemory.offsetFromCaretMove(
            insertedText: "안녕",
            beforeContextAtInsert: "안녕",
            beforeContextNow: "안녕하세요"
        )
        #expect(offset == nil)
    }

    @Test("빈 글은 배우지 않는다")
    func emptyInsertIsIgnored() {
        let offset = CursorMemory.offsetFromCaretMove(
            insertedText: "",
            beforeContextAtInsert: "안녕",
            beforeContextNow: "안"
        )
        #expect(offset == nil)
    }

    // MARK: - 몇 번 만에 해 주는가

    @Test("같은 자리를 세 번 봐야 해 준다")
    func readyOnlyAtThreshold() {
        var learned: CursorMemory.Learned?
        for _ in 1...(CursorMemory.threshold - 1) {
            learned = CursorMemory.merging(learned, offsetFromEnd: 3, textLength: 20)
            #expect(learned?.isReady == false)
        }
        learned = CursorMemory.merging(learned, offsetFromEnd: 3, textLength: 20)
        #expect(learned?.isReady == true)
        #expect(learned?.hits == CursorMemory.threshold)
    }

    @Test("다른 자리로 가면 처음부터 다시 센다")
    func differentOffsetResetsCount() {
        var learned = CursorMemory.merging(nil, offsetFromEnd: 3, textLength: 20)
        learned = CursorMemory.merging(learned, offsetFromEnd: 3, textLength: 20)
        #expect(learned.hits == 2)

        learned = CursorMemory.merging(learned, offsetFromEnd: 7, textLength: 20)
        #expect(learned.hits == 1)
        #expect(learned.offsetFromEnd == 7)
        #expect(learned.isReady == false)
    }

    @Test("본문이 바뀌면 배운 것을 버린다")
    func editedBodyDropsLearning() {
        var learned = CursorMemory.merging(nil, offsetFromEnd: 3, textLength: 20)
        learned = CursorMemory.merging(learned, offsetFromEnd: 3, textLength: 20)
        learned = CursorMemory.merging(learned, offsetFromEnd: 3, textLength: 20)
        #expect(learned.isReady == true)

        // 사용자가 단축어를 고쳐 길이가 달라졌다.
        learned = CursorMemory.merging(learned, offsetFromEnd: 3, textLength: 31)
        #expect(learned.hits == 1)
        #expect(learned.isReady == false)
    }

    @Test("꺼 둔 것은 다시 배우지 않는다")
    func turnedOffStaysOff() {
        var learned = CursorMemory.Learned(offsetFromEnd: 0, hits: 0, textLength: 0)
        learned.off = true

        let after = CursorMemory.merging(learned, offsetFromEnd: 4, textLength: 20)
        #expect(after.off == true)
        #expect(after.hits == 0)
        #expect(after.isReady == false)
    }

    @Test("거리가 0이면 해 줄 것이 없다")
    func zeroOffsetIsNeverReady() {
        var learned = CursorMemory.merging(nil, offsetFromEnd: 0, textLength: 20)
        learned = CursorMemory.merging(learned, offsetFromEnd: 0, textLength: 20)
        learned = CursorMemory.merging(learned, offsetFromEnd: 0, textLength: 20)
        #expect(learned.isReady == false)
    }
}
