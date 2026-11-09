//
//  ReplyStarterPackTests.swift
//  ClipKeyboardTests
//
//  답장 시작 세트(셀러 · 고객 응대용 단축어 다섯 개)가 무료 한도 안에 들고, 빈칸이 본문과 맞고,
//  두 번 눌러도 한 번만 들어가는지.
//

import XCTest
@testable import ClipKeyboard

final class ReplyStarterPackTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: ReplyStarterPack.addedKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ReplyStarterPack.addedKey)
        super.tearDown()
    }

    /// 무료 한도(단축어 10 · 템플릿 3) 안에 들어야 무료로 쓰는 기간이 끝난 사람에게도 가려지는 것이 없다.
    func test_답장_시작_세트는_무료_한도_안에_든다() {
        let pack = ReplyStarterPack.memos()
        XCTAssertEqual(pack.count, 5)
        XCTAssertLessThanOrEqual(pack.count, ProFeatureManager.freeMemoLimit)
        XCTAssertLessThanOrEqual(pack.filter(\.isTemplate).count, ProFeatureManager.freeTemplateLimit)
        XCTAssertEqual(pack.filter(\.isTemplate).count, 3, "배송 · 품절 · 교환이 빈칸 템플릿")
    }

    /// 빈칸 목록은 본문에서 읽는다. 번역에서 `{고객명}` 이 다른 말이 되어도 어긋나지 않는다.
    func test_빈칸_목록은_본문의_중괄호와_같다() {
        for memo in ReplyStarterPack.memos() {
            XCTAssertEqual(memo.templateVariables, memo.value.extractTemplatePlaceholders(), memo.title)
            XCTAssertFalse(memo.title.isEmpty)
            XCTAssertFalse(memo.value.isEmpty)
        }
        let titles = ReplyStarterPack.memos().map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count, "제목이 겹치면 목록에서 구분이 안 된다")
    }

    func test_한_번_넣으면_다시_넣지_않는다() throws {
        var stored = [Memo(title: "계좌", value: "110-123-456789")]
        let load = { stored }
        let save = { (memos: [Memo]) in stored = memos }

        XCTAssertEqual(try ReplyStarterPack.add(load: load, save: save), 5)
        XCTAssertEqual(stored.count, 6, "내 단축어 뒤에 다섯 개")
        XCTAssertTrue(ReplyStarterPack.isAdded)

        XCTAssertEqual(try ReplyStarterPack.add(load: load, save: save), 0, "두 번째는 아무것도 하지 않는다")
        XCTAssertEqual(stored.count, 6)
        XCTAssertEqual(stored.first?.title, "계좌", "원래 있던 것이 앞에 그대로")
    }

    func test_저장이_실패하면_넣었다고_적지_않는다() {
        struct Boom: Error {}
        XCTAssertThrowsError(try ReplyStarterPack.add(load: { [] }, save: { _ in throw Boom() }))
        XCTAssertFalse(ReplyStarterPack.isAdded, "다음에 다시 누를 수 있어야 한다")
    }
}
