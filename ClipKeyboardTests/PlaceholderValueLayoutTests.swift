//
//  PlaceholderValueLayoutTests.swift
//  ClipKeyboardTests
//
//  빈칸 값이 길면 세로 목록, 짧으면 가로 칩.
//  짧은 값을 쓰는 사람의 빠른 칩을 잃지 않는 것과, 한국어 주소를 글자 수로 재서 놓치지 않는 것을 고정한다.
//

import Testing
@testable import ClipKeyboard

struct PlaceholderValueLayoutTests {

    @Test("짧은 값만 있으면 가로 칩 그대로")
    func shortValuesStayChips() {
        #expect(PlaceholderValueLayout.resolve(for: ["김철수", "이영희", "50,000"]) == .chips)
        #expect(PlaceholderValueLayout.resolve(for: ["John", "Jane Doe", "INV-1043"]) == .chips)
    }

    @Test("긴 값이 하나라도 있으면 세로 목록")
    func oneLongValueMakesList() {
        let values = ["Home", "1600 Amphitheatre Parkway, Mountain View, CA 94043"]
        #expect(PlaceholderValueLayout.resolve(for: values) == .list)
    }

    @Test("한글은 영문 두 자 너비로 잰다")
    func koreanCountsWide() {
        // 글자 수로는 15자라 짧아 보이지만, 화면에서는 영문 20자보다 넓다.
        let address = "서울시 강남구 테헤란로 123"
        #expect(address.count <= PlaceholderValueLayout.longValueWidth)
        #expect(PlaceholderValueLayout.isLong(address))
    }

    @Test("줄바꿈이 있으면 짧아도 목록")
    func newlineIsLong() {
        #expect(PlaceholderValueLayout.isLong("A\nB"))
    }

    @Test("너비 경계: 20 은 짧고 21 은 길다")
    func boundary() {
        #expect(!PlaceholderValueLayout.isLong(String(repeating: "a", count: 20)))
        #expect(PlaceholderValueLayout.isLong(String(repeating: "a", count: 21)))
        #expect(PlaceholderValueLayout.displayWidth(of: "가a") == 3)
    }

    @Test("값이 없으면 칩(그릴 것이 없다)")
    func emptyIsChips() {
        #expect(PlaceholderValueLayout.resolve(for: []) == .chips)
    }
}
