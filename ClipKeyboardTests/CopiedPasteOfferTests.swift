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
        AppGroup.defaults?.removeObject(forKey: DefaultsKey.keyboardPasteOfferSeen)
        super.tearDown()
    }

    /// 새로 복사한 글이면 칩이 서고, 넣은 뒤(쓴 번호)에는 다시 서지 않고, 다음 복사에는 또 선다.
    func test_새로_복사하면_칩이_서고_넣은_뒤에는_같은_복사로_다시_서지_않는다() {
        let now = Date()
        XCTAssertTrue(KeyboardPrefs.pasteOffer.fallback, "기본은 켬")

        let seen = CopiedPasteOffer.firstSeen(for: 41, now: now)
        XCTAssertTrue(CopiedPasteOffer.shouldOffer(changeCount: 41, text: "leeo@kakao.com",
                                                   consumedCount: CopiedPasteOffer.consumedCount,
                                                   firstSeen: seen, now: now))

        CopiedPasteOffer.markConsumed(41)
        XCTAssertFalse(CopiedPasteOffer.shouldOffer(changeCount: 41, text: "leeo@kakao.com",
                                                    consumedCount: CopiedPasteOffer.consumedCount,
                                                    firstSeen: seen, now: now),
                       "넣은 뒤에도 남으면 두 번 넣게 된다")

        XCTAssertTrue(CopiedPasteOffer.shouldOffer(changeCount: 42, text: "다른 글",
                                                   consumedCount: CopiedPasteOffer.consumedCount,
                                                   firstSeen: CopiedPasteOffer.firstSeen(for: 42, now: now), now: now))
    }

    /// 빈 글은 세우지 않고, 처음 본 뒤 3분이 지나면 내린다. 키보드를 다시 띄워도 처음 본 때는 그대로다.
    func test_빈_글은_안_서고_처음_본_뒤_시간이_지나면_내린다() {
        let start = Date()
        XCTAssertFalse(CopiedPasteOffer.shouldOffer(changeCount: 7, text: "  \n", consumedCount: nil, firstSeen: start, now: start))
        XCTAssertFalse(CopiedPasteOffer.shouldOffer(changeCount: 7, text: nil, consumedCount: nil, firstSeen: start, now: start))

        let seen = CopiedPasteOffer.firstSeen(for: 9, now: start)
        let later = start.addingTimeInterval(CopiedPasteOffer.lifetime + 1)
        XCTAssertEqual(CopiedPasteOffer.firstSeen(for: 9, now: later), seen, "다시 떠도 처음 본 때를 잊지 않는다")
        XCTAssertFalse(CopiedPasteOffer.shouldOffer(changeCount: 9, text: "값", consumedCount: nil, firstSeen: seen, now: later))
    }

    /// 칩은 한 줄. 카드번호처럼 남이 보면 곤란한 것은 끝 네 자리만.
    func test_칩은_한_줄이고_민감한_글은_끝_네_자리만() {
        XCTAssertEqual(CopiedPasteOffer.preview("서울 마포구\n월드컵북로 396", isSensitive: false), "서울 마포구 월드컵북로 396")
        XCTAssertEqual(CopiedPasteOffer.preview("1234 5678 9012 3456", isSensitive: true), "\u{2022}\u{2022}\u{2022}\u{2022} 3456")
    }
}
