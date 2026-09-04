//
//  EditPatternTests.swift
//  ClipKeyboardTests
//
//  "넣고 나서 고친 자리"를 읽는 판정을 시험한다.
//  말을 걸어야 하는 경우보다 **말을 걸면 안 되는 경우**를 더 많이 적었다.
//  확신 없이 제안하면 그때부터 잔소리라서다.
//

import Testing
import Foundation
@testable import ClipKeyboard

struct EditPatternTests {

    // MARK: - 고친 자리 읽기

    @Test("가운데 한 군데를 고치면 그 자리를 집어낸다")
    func findsMiddleEdit() {
        let d = EditPattern.diff(inserted: "안녕하세요 지호님", edited: "안녕하세요 서연님")
        #expect(d?.original == "지호")
        #expect(d?.replacement == "서연")
        #expect(d?.prefixLength == 6)
        #expect(d?.suffixLength == 1)
    }

    @Test("자리가 같으면 값이 달라도 같은 자리로 본다")
    func sameSlotAcrossValues() {
        let a = EditPattern.diff(inserted: "안녕하세요 지호님", edited: "안녕하세요 서연님")
        let b = EditPattern.diff(inserted: "안녕하세요 지호님", edited: "안녕하세요 하준님")
        #expect(a?.slot == b?.slot)
    }

    @Test("안 고쳤으면 볼 것이 없다")
    func noEditMeansNil() {
        #expect(EditPattern.diff(inserted: "안녕하세요", edited: "안녕하세요") == nil)
    }

    @Test("통째로 갈아치운 것은 고친 것이 아니다")
    func fullReplacementIsIgnored() {
        // 앞뒤로 공통된 글자가 하나도 없다 = 딴 글을 쓴 것.
        #expect(EditPattern.diff(inserted: "안녕하세요", edited: "반갑습니다") == nil)
    }

    @Test("너무 긴 글은 보지 않는다")
    func tooLongIsIgnored() {
        let long = String(repeating: "가", count: EditPattern.maxTextLength + 1)
        #expect(EditPattern.diff(inserted: long, edited: long + "나") == nil)
    }

    @Test("빈 글은 보지 않는다")
    func emptyIsIgnored() {
        #expect(EditPattern.diff(inserted: "", edited: "안녕") == nil)
    }

    @Test("뒤에 덧붙인 것도 고친 자리로 읽는다")
    func appendIsAnEdit() {
        let d = EditPattern.diff(inserted: "계좌 1234", edited: "계좌 1234 입니다")
        #expect(d?.original == "")
        #expect(d?.replacement == " 입니다")
    }

    // MARK: - 무엇을 제안하는가

    @Test("같은 자리에 매번 다른 값이면 템플릿을 제안한다")
    func differentValuesSuggestTemplate() {
        let inserted = "안녕하세요 지호님"
        var record: EditPattern.Record?
        for name in ["서연", "하준", "민서"] {
            let d = EditPattern.diff(inserted: inserted, edited: "안녕하세요 \(name)님")!
            record = EditPattern.merging(record, diff: d, textLength: inserted.count)
        }
        #expect(record?.hits == 3)
        #expect(record?.suggestion == .makeTemplate)
    }

    @Test("같은 자리에 매번 같은 값이면 원본을 고치자고 한다")
    func sameValueSuggestsUpdate() {
        let inserted = "계좌 110-1234-5678"
        var record: EditPattern.Record?
        for _ in 1...3 {
            let d = EditPattern.diff(inserted: inserted, edited: "계좌 110-9999-5678")!
            record = EditPattern.merging(record, diff: d, textLength: inserted.count)
        }
        #expect(record?.suggestion == .updateOriginal)
    }

    @Test("고친 자리가 매번 다르면 아무 말도 안 한다")
    func movingSlotStaysSilent() {
        let inserted = "안녕하세요 지호님 반갑습니다"
        var record: EditPattern.Record?
        let edits = ["안녕하세요 서연님 반갑습니다",
                     "안녕하세요 지호님 고맙습니다",
                     "안녕하세요 지호님 반갑네요"]
        for edited in edits {
            let d = EditPattern.diff(inserted: inserted, edited: edited)!
            record = EditPattern.merging(record, diff: d, textLength: inserted.count)
        }
        // 자리가 계속 바뀌어 셋이 안 쌓인다.
        #expect(record?.hits == 1)
        #expect(record?.suggestion == nil)
    }

    @Test("세 번을 못 채우면 말을 걸지 않는다")
    func belowThresholdStaysSilent() {
        let inserted = "안녕하세요 지호님"
        var record: EditPattern.Record?
        for name in ["서연", "하준"] {
            let d = EditPattern.diff(inserted: inserted, edited: "안녕하세요 \(name)님")!
            record = EditPattern.merging(record, diff: d, textLength: inserted.count)
        }
        #expect(record?.suggestion == nil)
    }

    @Test("본문이 바뀌면 쌓인 것을 버린다")
    func editedBodyResets() {
        let inserted = "안녕하세요 지호님"
        var record: EditPattern.Record?
        for name in ["서연", "하준", "민서"] {
            let d = EditPattern.diff(inserted: inserted, edited: "안녕하세요 \(name)님")!
            record = EditPattern.merging(record, diff: d, textLength: inserted.count)
        }
        #expect(record?.suggestion == .makeTemplate)

        // 사용자가 단축어를 고쳐 길이가 달라졌다.
        let d = EditPattern.diff(inserted: inserted, edited: "안녕하세요 소윤님")!
        record = EditPattern.merging(record, diff: d, textLength: inserted.count + 5)
        #expect(record?.hits == 1)
        #expect(record?.suggestion == nil)
    }

    @Test("한 번 물었으면 다시 묻지 않는다")
    func asksOnlyOnce() {
        var record = EditPattern.Record(slot: "6/1", hits: 3, replacements: ["a", "b", "c"], textLength: 9)
        #expect(record.suggestion == .makeTemplate)
        record.asked = true
        #expect(record.suggestion == nil)
    }

    @Test("거절한 것은 다시 묻지 않고, 더 쌓지도 않는다")
    func declinedStaysSilent() {
        var record = EditPattern.Record(slot: "6/1", hits: 3, replacements: ["a"], textLength: 9)
        record.declined = true
        #expect(record.suggestion == nil)

        let d = EditPattern.diff(inserted: "안녕하세요 지호님", edited: "안녕하세요 서연님")!
        let after = EditPattern.merging(record, diff: d, textLength: 9)
        #expect(after.declined == true)
        #expect(after.hits == 3)
    }

    @Test("쌓인 값은 문턱 개수까지만 들고 있는다")
    func replacementsAreCapped() {
        let inserted = "안녕하세요 지호님"
        var record: EditPattern.Record?
        for name in ["서연", "하준", "민서", "소윤", "도윤"] {
            let d = EditPattern.diff(inserted: inserted, edited: "안녕하세요 \(name)님")!
            record = EditPattern.merging(record, diff: d, textLength: inserted.count)
        }
        #expect(record?.hits == 5)
        #expect(record?.replacements.count == EditPattern.threshold)
        #expect(record?.replacements.last == "도윤")
    }

    // MARK: - 만들어 주는 글

    @Test("고친 자리를 빈칸으로 판 글을 만든다")
    func buildsTemplateText() {
        let inserted = "안녕하세요 지호님"
        var record: EditPattern.Record?
        for name in ["서연", "하준", "민서"] {
            let d = EditPattern.diff(inserted: inserted, edited: "안녕하세요 \(name)님")!
            record = EditPattern.merging(record, diff: d, textLength: inserted.count)
        }
        let text = EditPattern.templateText(from: inserted, record: record!, placeholderName: "이름")
        #expect(text == "안녕하세요 {이름}님")
    }

    @Test("자리가 글 길이를 넘으면 만들지 않는다")
    func refusesImpossibleSlot() {
        let record = EditPattern.Record(slot: "99/99", hits: 3, replacements: ["a"], textLength: 9)
        #expect(EditPattern.templateText(from: "안녕", record: record, placeholderName: "이름") == nil)
    }
}
