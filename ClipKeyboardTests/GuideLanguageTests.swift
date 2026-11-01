//
//  GuideLanguageTests.swift
//  ClipKeyboardTests
//
//  사용법 페이지가 앱 언어로 열린다.
//
//  ⚠️ 여기 시험 이름은 docs/engineering/USER_JOURNEYS.md 의 표에 걸려 있다.
//

import XCTest
@testable import ClipKeyboard

final class GuideLanguageTests: XCTestCase {

    /// 고를 수 있는 언어마다 그 언어 주소로 열리고, 그 페이지가 저장소에 실제로 있다.
    func test_사용법_페이지는_앱_언어로_열리고_모든_언어에_있다() {
        XCTAssertEqual(Constants.tutorialURL(language: "ja"),
                       "https://m1zz.github.io/ClipKeyboard/ja/tutorial.html")

        let docs = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs")
        for language in AppLanguage.allCases {
            guard let code = language.bundleCode else { continue }
            let page = docs.appendingPathComponent(code).appendingPathComponent("tutorial.html")
            XCTAssertTrue(FileManager.default.fileExists(atPath: page.path), "\(code) 사용법 페이지가 없다")
        }
    }
}
