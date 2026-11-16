//
//  CopiedPasteOfferTests.swift
//  ClipKeyboardTests
//
//  방금 복사한 글 붙여넣기 칩. 사용자 요청(2026-11): 복사해 왔으면 키보드 위에 떠 달라.
//

import XCTest
@testable import ClipKeyboard

final class CopiedPasteOfferTests: XCTestCase {

    override func tearDown() {
        AppGroup.defaults?.removeObject(forKey: DefaultsKey.keyboardPasteOfferConsumedCount)
        super.tearDown()
    }

    /// 클립보드에 글이 있으면 칩이 서고, 넣거나 X 로 닫은 복사는 다시 서지 않으며, 다음 복사에는 또 선다.
    /// 시간이 지났다고 저절로 내리지 않는다(사용자 2026-11: "클립보드에 값이 있으면 상단에 떠 줘야 하는데 X 버튼과 함께").
    func test_클립보드에_글이_있으면_서고_넣거나_닫은_복사는_다시_서지_않는다() {
        XCTAssertTrue(KeyboardPrefs.pasteOffer.fallback, "기본은 켬")
        XCTAssertTrue(CopiedPasteOffer.shouldOffer(changeCount: 41, text: "leeo@kakao.com",
                                                   consumedCount: CopiedPasteOffer.consumedCount))

        CopiedPasteOffer.markConsumed(41)
        XCTAssertFalse(CopiedPasteOffer.shouldOffer(changeCount: 41, text: "leeo@kakao.com",
                                                    consumedCount: CopiedPasteOffer.consumedCount),
                       "넣거나 닫은 뒤에도 남으면 두 번 넣게 되고 닫은 의미가 없다")

        XCTAssertTrue(CopiedPasteOffer.shouldOffer(changeCount: 42, text: "다른 글",
                                                   consumedCount: CopiedPasteOffer.consumedCount),
                      "새로 복사하면 다시 서야 한다")
    }

    /// 빈 글은 세우지 않는다.
    func test_빈_글은_세우지_않는다() {
        XCTAssertFalse(CopiedPasteOffer.shouldOffer(changeCount: 7, text: "  \n", consumedCount: nil))
        XCTAssertFalse(CopiedPasteOffer.shouldOffer(changeCount: 7, text: nil, consumedCount: nil))
    }

    /// 칩은 한 줄. 카드번호처럼 남이 보면 곤란한 것은 끝 네 자리만.
    func test_칩은_한_줄이고_민감한_글은_끝_네_자리만() {
        XCTAssertEqual(CopiedPasteOffer.preview("서울 마포구\n월드컵북로 396", isSensitive: false), "서울 마포구 월드컵북로 396")
        XCTAssertEqual(CopiedPasteOffer.preview("1234 5678 9012 3456", isSensitive: true), "\u{2022}\u{2022}\u{2022}\u{2022} 3456")
    }
}
