//
//  ForeignerTraceTests.swift
//  ClipKeyboardTests
//
//  한국어를 모르는 사람이 "한국 사람이 만들어서 한국어가 나오네" 라고 느낄 곳을 지킨다.
//

import XCTest
import LeeoKit
@testable import ClipKeyboard

@MainActor
final class ForeignerTraceTests: XCTestCase {

    override func tearDown() {
        AppLanguage.select(.system)
        super.tearDown()
    }

    func test_다른_언어_사용자에게_한국_흔적이_보이지_않는다() {
        let hangul = /[가-힣]/
        let languages = AppLanguage.available.filter { $0 != .system && $0 != .ko }
        XCTAssertEqual(languages.count, 22)

        // 언어 목록 맨 앞(기기 설정 다음)에 한국어가 서지 않는다.
        XCTAssertNotEqual(AppLanguage.available[1], .ko)

        for language in languages {
            AppLanguage.select(language)
            let name = language.rawValue

            // 공용 화면(LeeoKit)도 앱 언어를 따른다.
            XCTAssertNil(LeeoRoadmapText.entry.firstMatch(of: hangul), "\(name): LeeoKit")

            // 예시 값
            let phone = Constants.sampleValue(for: ClipboardItemType.phone.rawValue) ?? ""
            XCTAssertFalse(phone.hasPrefix("010"), "\(name): 전화번호 예시")
            XCTAssertFalse(PlaceholderExamples.suggestions(for: "phone").contains { $0.hasPrefix("010") }, name)
            for key in ["서울시 강남구 테헤란로 123", "서울시 강남구 …", "서울특별시 종로구 청와대로 1", "김서연", "박서연", "홍길동"] {
                let value = NSLocalizedString(key, comment: "")
                XCTAssertNil(value.firstMatch(of: hangul), "\(name): \(key)")
                XCTAssertNil(value.firstMatch(of: /Seoul|Gangnam|Teheran|\bKim\b/), "\(name): \(value)")
            }

            // 변경 내역에 한글 자판 이야기가 없다.
            let notes = ChangelogData.visibleEntries.flatMap(\.highlights)
            XCTAssertFalse(notes.isEmpty, name)
            XCTAssertLessThan(notes.count, ChangelogData.entries.flatMap(\.highlights).count, name)
            for note in notes { XCTAssertNil(note.firstMatch(of: hangul), "\(name): \(note)") }
        }

        AppLanguage.select(.ko)
        XCTAssertEqual(ChangelogData.visibleEntries.flatMap(\.highlights).count,
                       ChangelogData.entries.flatMap(\.highlights).count, "한국어는 그대로 다 본다")
    }
}
