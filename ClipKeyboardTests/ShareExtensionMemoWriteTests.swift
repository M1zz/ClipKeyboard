//
//  ShareExtensionMemoWriteTests.swift
//  ClipKeyboardTests
//
//  공유 익스텐션이 손으로 쓴 JSON 을 앱이 제대로 읽는지 — **두 타겟이 코드를 공유하지 않아서**
//  스키마가 어긋나도 컴파일러가 잡아 주지 못하는 자리다.
//
//  특히 날짜: 앱은 기본 `JSONEncoder` 를 쓰므로 Date 가 **2001 기준 초**로 저장된다.
//  익스텐션이 epoch(1970)로 적으면 31년 어긋난 시각이 되어 최근순 정렬이 무너진다.
//  화면에서는 "왜 맨 아래에 있지"로만 보이고 원인을 짐작하기 어렵다.
//

import XCTest
@testable import ClipKeyboard

final class ShareExtensionMemoWriteTests: XCTestCase {

    /// 공유 익스텐션(`ShareViewController.saveAsShortcut`)이 만드는 것과 **같은 모양**의 딕셔너리.
    /// ⚠️ 저쪽을 고치면 여기도 같이 고칠 것 — 이 테스트가 두 타겟을 잇는 유일한 끈이다.
    private func shareExtensionPayload(id: String = UUID().uuidString,
                                       title: String = "계좌번호",
                                       value: String = "110-234-567890",
                                       now: Date = Date(),
                                       category: String = "기본",
                                       contentType: String = "text",
                                       imageFileNames: [String] = []) -> [String: Any] {
        [
            "id": id,
            "title": title,
            "value": value,
            "lastEdited": now.timeIntervalSinceReferenceDate,
            "category": category,
            "contentType": contentType,
            "imageFileNames": imageFileNames,
            "isFavorite": false
        ]
    }

    private func decode(_ payloads: [[String: Any]]) throws -> [Memo] {
        let data = try JSONSerialization.data(withJSONObject: payloads, options: [])
        return try JSONDecoder().decode([Memo].self, from: data)
    }

    // MARK: - 왕복

    func testSharedPayloadDecodesIntoMemo() throws {
        let id = UUID()
        let memos = try decode([shareExtensionPayload(id: id.uuidString)])

        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos[0].id, id)
        XCTAssertEqual(memos[0].title, "계좌번호")
        XCTAssertEqual(memos[0].value, "110-234-567890")
        XCTAssertEqual(memos[0].category, "기본")
        XCTAssertFalse(memos[0].isFavorite)
    }

    /// 31년 어긋남을 막는 테스트 — epoch 로 적었다면 여기서 걸린다.
    func testLastEditedUsesReferenceDateNotEpoch() throws {
        let now = Date()
        let memos = try decode([shareExtensionPayload(now: now)])

        XCTAssertEqual(memos[0].lastEdited.timeIntervalSinceReferenceDate,
                       now.timeIntervalSinceReferenceDate,
                       accuracy: 1,
                       "공유로 넣은 단축어의 시각이 지금과 같아야 최근순에서 맨 위에 온다")

        // epoch 로 적었을 때 얼마나 어긋나는지 — 실수하면 30년 이상 벌어진다.
        let epochMistake = try decode([[
            "id": UUID().uuidString, "title": "t", "value": "v",
            "lastEdited": now.timeIntervalSince1970
        ]])
        XCTAssertGreaterThan(epochMistake[0].lastEdited.timeIntervalSince(now), 60 * 60 * 24 * 365 * 20,
                             "epoch 로 적으면 20년 이상 미래로 밀린다 — 이 테스트가 그 실수를 잡는다")
    }

    // MARK: - 관용적 디코더가 실제로 관용적인가

    /// 익스텐션은 앱의 모든 필드를 알지 못한다. 빠진 키 때문에 **배열 전체**가 실패하면
    /// 앱의 폴백이 OldMemo(제목/값만)로 떨어져 카테고리·즐겨찾기·콤보가 통째로 날아간다.
    func testMissingKeysDoNotBreakTheWholeArray() throws {
        let minimal: [String: Any] = ["id": UUID().uuidString, "title": "최소", "value": "값"]
        let full = shareExtensionPayload(title: "정상")

        let memos = try decode([minimal, full])

        XCTAssertEqual(memos.count, 2, "키가 빠진 항목이 섞여도 나머지가 살아야 한다")
        XCTAssertEqual(memos[0].title, "최소")
        XCTAssertEqual(memos[0].category, "기본", "빠진 키는 기본값으로 채워진다")
        XCTAssertEqual(memos[1].title, "정상")
    }

    // MARK: - 이미지 공유

    func testImageShareDecodesWithFileNamesAndContentType() throws {
        let memos = try decode([shareExtensionPayload(value: "",
                                                      contentType: "image",
                                                      imageFileNames: ["abc.jpg", "abc_1.jpg"])])

        XCTAssertEqual(memos[0].imageFileNames, ["abc.jpg", "abc_1.jpg"])
        XCTAssertEqual(memos[0].contentType, .image)
    }

    func testTextWithImageIsMixed() throws {
        let memos = try decode([shareExtensionPayload(value: "설명",
                                                      contentType: "mixed",
                                                      imageFileNames: ["abc.jpg"])])
        XCTAssertEqual(memos[0].contentType, .mixed)
    }

    // MARK: - 맨 앞에 꽂기

    /// 방금 담은 것이 목록 위에 보여야 "들어갔구나"가 확인된다.
    func testInsertedAtFrontStaysAtFront() throws {
        let existing = shareExtensionPayload(title: "예전 것", now: Date().addingTimeInterval(-3600))
        var all = [existing]
        all.insert(shareExtensionPayload(title: "방금 공유"), at: 0)

        let memos = try decode(all)
        XCTAssertEqual(memos.first?.title, "방금 공유")
    }
}
