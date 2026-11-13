//
//  SnippetIconTests.swift
//  ClipKeyboardTests
//
//  단축어 · 카테고리 아이콘(이모지 · 심볼 · 내 그림). 저장 글자와 하위 호환을 지킨다.
//

import XCTest
@testable import ClipKeyboard

final class SnippetIconTests: XCTestCase {

    private let probeCategory = "아이콘시험카테고리"

    override func tearDown() {
        var dict = AppGroup.defaults?.dictionary(forKey: DefaultsKey.userCategoryIconsV1) as? [String: String] ?? [:]
        dict[probeCategory] = nil
        AppGroup.defaults?.set(dict, forKey: DefaultsKey.userCategoryIconsV1)
        super.tearDown()
    }

    // MARK: - 저장 글자

    func test_세_가지_아이콘이_저장_글자를_거쳐_그대로_돌아온다() {
        for icon in [SnippetIcon.symbol("star.fill"), .emoji("🐶"), .image("A.png")] {
            XCTAssertEqual(SnippetIcon(raw: icon.raw), icon)
        }
        XCTAssertNil(SnippetIcon(raw: nil))
        XCTAssertNil(SnippetIcon(raw: ""))
        XCTAssertNil(SnippetIcon(raw: "emoji:"), "접두사만 있으면 아이콘이 아니다")
    }

    /// 예전 카테고리 아이콘은 심볼 이름이 접두사 없이 저장돼 있다. 그대로 심볼로 읽혀야 한다.
    func test_예전에_저장한_심볼_이름은_심볼로_읽힌다() {
        XCTAssertEqual(SnippetIcon(raw: "briefcase.fill"), .symbol("briefcase.fill"))
    }

    // MARK: - 단축어

    /// 아이콘이 없던 예전 파일도 읽히고, 아이콘을 단 단축어는 저장했다 읽어도 그대로다.
    func test_단축어_아이콘은_저장했다_읽어도_남고_없던_파일도_읽힌다() throws {
        var memo = Memo(title: "인사", value: "안녕하세요")
        memo.icon = SnippetIcon.emoji("👋").raw
        let decoded = try JSONDecoder().decode(Memo.self, from: JSONEncoder().encode(memo))
        XCTAssertEqual(SnippetIcon(raw: decoded.icon), .emoji("👋"))

        let legacy = #"{"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","title":"옛것","value":"값"}"#
        let old = try JSONDecoder().decode(Memo.self, from: Data(legacy.utf8))
        XCTAssertNil(old.icon)
    }

    // MARK: - 카테고리

    /// 이모지를 고른 카테고리도 심볼만 그릴 수 있는 자리(메뉴)에서는 기본 심볼로 물러난다.
    /// 물러나지 않으면 `Image(systemName: "emoji:🐶")` 이 빈칸으로 그려진다.
    func test_이모지를_고른_카테고리도_메뉴에서는_심볼이다() {
        let list = [probeCategory]
        let fallback = defaultIcon(for: probeCategory, in: list)
        var dict = AppGroup.defaults?.dictionary(forKey: DefaultsKey.userCategoryIconsV1) as? [String: String] ?? [:]

        dict[probeCategory] = SnippetIcon.emoji("🐶").raw
        AppGroup.defaults?.set(dict, forKey: DefaultsKey.userCategoryIconsV1)
        XCTAssertEqual(customCategoryIcon(for: probeCategory), .emoji("🐶"))
        XCTAssertEqual(categorySymbol(for: probeCategory, in: list), fallback)

        dict[probeCategory] = "star.fill"
        AppGroup.defaults?.set(dict, forKey: DefaultsKey.userCategoryIconsV1)
        XCTAssertEqual(categorySymbol(for: probeCategory, in: list), "star.fill")
    }
}
