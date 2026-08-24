//
//  SmearTextPickTests.swift
//  ClipKeyboardTests
//
//  사진 위를 문질러 고른 글자가 **사진에 보이던 모습 그대로** 값이 되는지 지킨다.
//
//  ⚠️ 여기서 깨지면 사용자는 담은 뒤에 손으로 고치게 된다. 그러면 사진을 찍은 보람이 없다.
//     특히 조심할 것은 셋이다: 순서 · 띄어쓰기 · 줄바꿈.
//

import XCTest
@testable import ClipKeyboard

final class SmearTextPickTests: XCTestCase {

    // MARK: - 거들기

    /// 한 줄을 만든다. 띄어쓰기로 나뉜 조각들이 왼쪽부터 놓인 것으로 친다.
    private func makeLine(_ tokens: [String], y: CGFloat = 0) -> RecognizedTextLine {
        var pieces: [RecognizedTextPiece] = []
        var x: CGFloat = 0
        for (index, token) in tokens.enumerated() {
            let width = CGFloat(token.count) * 0.02
            pieces.append(RecognizedTextPiece(
                text: token,
                box: CGRect(x: x, y: y, width: width, height: 0.03),
                hasTrailingSpace: index < tokens.count - 1
            ))
            x += width + 0.01
        }
        return RecognizedTextLine(text: tokens.joined(separator: " "),
                                  box: CGRect(x: 0, y: y, width: x, height: 0.03),
                                  pieces: pieces)
    }

    // MARK: - 이어 붙이기

    func testKeepsReadingOrderAndSpacing() {
        let line = makeLine(["국민", "123456-78-901234"])
        let layout = RecognizedTextLayout(lines: [line])

        let all = Set(layout.allPieces.map(\.id))
        XCTAssertEqual(layout.joinedText(selecting: all, keepLineBreaks: false),
                       "국민 123456-78-901234")
    }

    /// 가운데를 건너뛰고 문질렀다면 띄어쓰기는 살아 있어야 한다.
    /// (이름과 전화번호 사이에 직함이 끼어 있는 명함이 흔하다)
    func testSkippedWordInTheMiddleKeepsOneSpace() {
        let line = makeLine(["홍길동", "과장", "010-1234-5678"])
        let layout = RecognizedTextLayout(lines: [line])

        let picked = Set([line.pieces[0].id, line.pieces[2].id])
        XCTAssertEqual(layout.joinedText(selecting: picked, keepLineBreaks: false),
                       "홍길동 010-1234-5678")
    }

    /// 고르지 않은 줄은 통째로 빠진다. 빈 줄이 값 사이에 끼면 안 된다.
    func testUnselectedLinesLeaveNoBlanks() {
        let first = makeLine(["서울시", "강남구", "테헤란로", "123"], y: 0.1)
        let second = makeLine(["예금주", "홍길동"], y: 0.2)
        let third = makeLine(["4층", "401호"], y: 0.3)
        let layout = RecognizedTextLayout(lines: [first, second, third])

        let picked = Set(first.pieces.map(\.id)).union(third.pieces.map(\.id))
        XCTAssertEqual(layout.joinedText(selecting: picked, keepLineBreaks: true),
                       "서울시 강남구 테헤란로 123\n4층 401호")
    }

    /// 줄바꿈을 끄면 한 줄로 이어 붙는다.
    /// 두 줄에 걸쳐 찍힌 계좌번호를 담을 때 이 길이 없으면 값이 쪼개진다.
    func testLineBreaksOffJoinsWithSpace() {
        let first = makeLine(["서울시", "강남구"], y: 0.1)
        let second = makeLine(["테헤란로", "123"], y: 0.2)
        let layout = RecognizedTextLayout(lines: [first, second])

        let all = Set(layout.allPieces.map(\.id))
        XCTAssertEqual(layout.joinedText(selecting: all, keepLineBreaks: false),
                       "서울시 강남구 테헤란로 123")
    }

    /// 긴 어절을 쪼갠 조각들은 **붙여서** 나와야 한다. 사이에 띄어쓰기가 끼면 계좌번호가 깨진다.
    func testSplitChunksOfOneTokenJoinWithoutSpace() {
        let pieces = [
            RecognizedTextPiece(text: "11020", box: CGRect(x: 0, y: 0, width: 0.1, height: 0.03), hasTrailingSpace: false),
            RecognizedTextPiece(text: "45678", box: CGRect(x: 0.1, y: 0, width: 0.1, height: 0.03), hasTrailingSpace: false),
            RecognizedTextPiece(text: "9012", box: CGRect(x: 0.2, y: 0, width: 0.08, height: 0.03), hasTrailingSpace: false),
        ]
        let line = RecognizedTextLine(text: "11020456789012",
                                      box: CGRect(x: 0, y: 0, width: 0.28, height: 0.03),
                                      pieces: pieces)
        let layout = RecognizedTextLayout(lines: [line])

        XCTAssertEqual(layout.joinedText(selecting: Set(pieces.map(\.id)), keepLineBreaks: false),
                       "11020456789012")
    }

    func testNothingSelectedGivesEmptyText() {
        let layout = RecognizedTextLayout(lines: [makeLine(["가", "나"])])
        XCTAssertTrue(layout.joinedText(selecting: [], keepLineBreaks: false).isEmpty)
    }

    // MARK: - 줄 목록으로 가는 길

    /// 문지르기 어려운 사람에게 넘기는 줄 목록. 빈 줄은 넘기지 않는다.
    func testPlainLinesTrimsAndDropsEmpty() {
        let blank = RecognizedTextLine(text: "   ",
                                       box: CGRect(x: 0, y: 0.4, width: 0.1, height: 0.03),
                                       pieces: [])
        let layout = RecognizedTextLayout(lines: [makeLine(["가나다"]), blank])

        XCTAssertEqual(layout.plainLines, ["가나다"])
    }
}
