//
//  ClipboardSplitterTests.swift
//  ClipKeyboardTests
//
//  복사한 것에서 **필요한 데까지만** 넣는 기능이 지키는 약속.
//
//  왜 생겼나: 사용자 요청 두 줄.
//
//    "웹페이지에서 내용을 복사한 후 일부만 붙여넣고 싶을 때,
//     단어 분할 버튼을 길게 눌러 원하는 부분을 선택할 수 있도록"
//
//  여기서 지키는 약속.
//   ① 띄어쓰기가 없는 말(중국어·일본어)도 조각으로 잘린다 - 이 요청을 보낸 사람의 말이다
//   ② 고른 범위는 **원문 그대로** 이어진다 (사이의 띄어쓰기·문장부호가 살아 있다)
//   ③ 아주 긴 글이 와도 키보드가 감당할 만큼만 자른다
//

import XCTest
@testable import ClipKeyboard

final class ClipboardSplitterTests: XCTestCase {

    // MARK: - ① 띄어쓰기가 없어도 잘린다

    /// 공백으로 잘랐다면 통째로 한 덩어리가 된다. 이 요청을 보낸 사람이 쓰는 말이 그 말이다.
    func test_중국어는_띄어쓰기가_없어도_단어로_잘린다() {
        let pieces = ClipboardSplitter.pieces(of: "今天天气很好我们去公园散步", unit: .word)

        XCTAssertGreaterThan(pieces.count, 3,
                             "공백으로 잘랐다면 1개다. 중국어는 띄어쓰기가 없다")
        XCTAssertFalse(pieces.contains { $0.text.contains(" ") })
    }

    func test_일본어도_단어로_잘린다() {
        let pieces = ClipboardSplitter.pieces(of: "今日は天気がいいので公園を散歩します", unit: .word)
        XCTAssertGreaterThan(pieces.count, 3)
    }

    func test_한국어와_영어도_단어로_잘린다() {
        XCTAssertGreaterThan(ClipboardSplitter.pieces(of: "오늘 날씨가 좋아서 공원에 갑니다", unit: .word).count, 3)
        XCTAssertGreaterThan(ClipboardSplitter.pieces(of: "The weather is nice today", unit: .word).count, 3)
    }

    func test_문장과_줄로도_자를_수_있다() {
        let text = "첫 문장입니다. 둘째 문장입니다.\n다른 줄입니다."
        XCTAssertGreaterThanOrEqual(ClipboardSplitter.pieces(of: text, unit: .sentence).count, 3)
        XCTAssertEqual(ClipboardSplitter.pieces(of: text, unit: .paragraph).count, 2)
    }

    func test_빈_글은_조각이_없다() {
        XCTAssertTrue(ClipboardSplitter.pieces(of: "", unit: .word).isEmpty)
        XCTAssertTrue(ClipboardSplitter.pieces(of: "   \n  ", unit: .word).isEmpty)
    }

    // MARK: - ② 고른 범위는 원문 그대로

    /// 조각의 글자를 이어 붙이면 "운송장번호는1234입니다" 처럼 붙어 버린다.
    func test_고른_범위는_사이의_띄어쓰기까지_원문_그대로다() {
        let source = "안녕하세요, 주문번호는 12345 입니다. 감사합니다."
        let pieces = ClipboardSplitter.pieces(of: source, unit: .word)
        guard let start = pieces.firstIndex(where: { $0.text == "주문번호는" }),
              let end = pieces.firstIndex(where: { $0.text == "12345" }) else {
            return XCTFail("조각을 못 찾음: \(pieces.map(\.text))")
        }

        let picked = ClipboardSplitter.text(from: source, pieces: pieces,
                                            range: pieces[start].id...pieces[end].id)

        XCTAssertEqual(picked, "주문번호는 12345")
    }

    func test_한_조각만_고르면_그것만_나온다() {
        let source = "The weather is nice today"
        let pieces = ClipboardSplitter.pieces(of: source, unit: .word)
        let picked = ClipboardSplitter.text(from: source, pieces: pieces, range: 0...0)
        XCTAssertEqual(picked, "The")
    }

    func test_전체를_고르면_처음부터_끝까지다() {
        let source = "하나 둘 셋"
        let pieces = ClipboardSplitter.pieces(of: source, unit: .word)
        let picked = ClipboardSplitter.text(from: source, pieces: pieces,
                                            range: pieces[0].id...pieces[pieces.count - 1].id)
        XCTAssertEqual(picked, source)
    }

    // MARK: - ③ 키보드가 감당할 만큼만

    /// 키보드 익스텐션은 메모리가 빠듯하다. 천 개를 그려 봐야 아무도 못 고른다.
    func test_아주_긴_글도_상한_안에서_자른다() {
        let long = String(repeating: "word ", count: 5000)
        let pieces = ClipboardSplitter.pieces(of: long, unit: .word)
        XCTAssertLessThanOrEqual(pieces.count, ClipboardSplitter.maxPieces)
        XCTAssertFalse(pieces.isEmpty)
    }
}
