//
//  PlaceholderSequenceTests.swift
//  ClipKeyboardTests
//
//  빈칸의 "다음 번호" 와 "고른 값을 앞으로".
//  전화번호·계좌번호처럼 숫자로 끝나지만 오르지 않는 값에 다음 번호를 내놓지 않는 것을 함께 고정한다.
//

import Testing
import Foundation
@testable import ClipKeyboard

struct PlaceholderSequenceTests {

    // MARK: - 다음 번호

    @Test("인보이스 번호는 하나 올린다")
    func invoiceNumber() {
        #expect(PlaceholderSequence.nextValue(after: ["INV-1042", "INV-1041"], token: "{인보이스 번호}") == "INV-1043")
    }

    @Test("앞자리 0 은 자릿수를 지킨다")
    func keepsZeroPadding() {
        #expect(PlaceholderSequence.nextValue(after: ["2026-009"], token: "{회차}") == "2026-010")
        #expect(PlaceholderSequence.nextValue(after: ["099"], token: "{No}") == "100")
    }

    @Test("이름이 차례를 뜻하지 않아도 최근 두 값이 1 차이면 다음을 내놓는다")
    func consecutiveHistory() {
        #expect(PlaceholderSequence.nextValue(after: ["Week 12", "Week 11"], token: "{주차 이름}") == "Week 13")
    }

    @Test("이름도 흐름도 없으면 내놓지 않는다")
    func noSignalNoSuggestion() {
        #expect(PlaceholderSequence.nextValue(after: ["Room 12", "Room 7"], token: "{장소}") == nil)
    }

    @Test("전화번호·계좌번호는 번호라는 말이 있어도 오르지 않는다")
    func fixedNumbersAreNotSequences() {
        #expect(PlaceholderSequence.nextValue(after: ["010-1234-5678"], token: "{전화번호}") == nil)
        #expect(PlaceholderSequence.nextValue(after: ["3333-01-2345678"], token: "{계좌번호}") == nil)
        #expect(PlaceholderSequence.nextValue(after: ["2023123456"], token: "{학번}") == nil)
    }

    @Test("숫자로 끝나지 않거나 너무 길면 내놓지 않는다")
    func notNumericOrTooLong() {
        #expect(PlaceholderSequence.nextValue(after: ["서울"], token: "{번호}") == nil)
        #expect(PlaceholderSequence.nextValue(after: ["4111111111111111"], token: "{주문번호}") == nil)
        #expect(PlaceholderSequence.nextValue(after: [], token: "{번호}") == nil)
    }

    @Test("짧은 영어 낱말은 낱말 단위로만 본다")
    func shortEnglishWordsNeedBoundaries() {
        #expect(PlaceholderSequence.isSequenceToken("{Order No}"))
        #expect(!PlaceholderSequence.isSequenceToken("{note}"))
        #expect(!PlaceholderSequence.isSequenceToken("{Phone number}"))
    }

    // MARK: - 다음 번호를 골랐나

    @Test("다음 번호를 고르면 새로 적는다")
    func rememberNext() {
        #expect(PlaceholderSequence.shouldRemember(chosen: "INV-1043", stored: ["INV-1042"], token: "{인보이스 번호}"))
    }

    @Test("이미 있는 값은 고른다고 자리를 옮기지 않는다 (5.0.7 에서 정한 것)")
    func existingValueIsNotMoved() {
        #expect(!PlaceholderSequence.shouldRemember(chosen: "서울", stored: ["리스본", "서울"], token: "{도시}"))
    }

    @Test("직접 친 한 번짜리 값은 적지 않는다")
    func oneOffIsNotRemembered() {
        #expect(!PlaceholderSequence.shouldRemember(chosen: "오늘 회의실", stored: ["3층"], token: "{장소}"))
        #expect(!PlaceholderSequence.shouldRemember(chosen: "  ", stored: ["3층"], token: "{장소}"))
    }
}
