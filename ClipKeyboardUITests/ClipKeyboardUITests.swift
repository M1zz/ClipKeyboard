//
//  ClipKeyboardUITests.swift
//  ClipKeyboardUITests
//
//  화면을 실제로 눌러 핵심 흐름이 끝까지 가는지 본다. 단위 시험이 못 보는 것(시트가 닫히는지,
//  저장한 것이 목록에 서는지)을 지킨다. 스킴 `ClipKeyboardUITests` 로 따로 돈다
//  (본 스킴의 단위 시험 · 커밋 훅을 느리게 하지 않게).
//

import XCTest

final class ClipKeyboardUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 첫 실행 안내 · 튜토리얼 · 제안 시트를 건너뛴 "쓰던 사람" 상태로 연다.
    /// 인자는 스토어 촬영(`scripts/take_screenshots.sh`)과 같다. 문구로 찾으므로 언어는 한국어로 고정한다.
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR",
            "-startedFresh.v444", "NO", "-firstShortcut.done.v1", "YES",
            "-tutorialChaptersDone.v1", "YES", "-keyboardStageOffered.v1", "YES",
            "-didYouKnow.optOut.v1", "YES", "-ghostSuggestionsOff_v1", "YES",
            "-defaultSamplesInserted_v1", "YES", "-demoSampleOfferResolved_v1", "YES",
        ]
        app.launch()
        return app
    }

    private func openAddShortcut(in app: XCUIApplication) {
        let add = app.buttons["단축어 추가"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 20), "첫 화면에 단축어 추가 단추가 없다")
        add.tap()
        XCTAssertTrue(app.textFields["키보드에 표시할 이름"].waitForExistence(timeout: 10),
                      "새 단축어 화면이 열리지 않았다")
    }

    // MARK: - 핵심 흐름

    /// 단축어를 하나 만들면 시트가 닫히고, 그 이름이 첫 화면에 선다.
    func testCreatingShortcutShowsItOnHome() throws {
        let app = launchApp()
        openAddShortcut(in: app)

        // 실행마다 다른 이름 - 시뮬레이터에 지난 실행의 단축어가 남아 있어도 이번 것을 찾는다.
        let title = "UI시험 \(Int(Date().timeIntervalSince1970) % 100_000)"
        app.textFields["키보드에 표시할 이름"].typeText(title)
        let body = app.textViews["붙여넣을 내용"]
        body.tap()
        body.typeText("안녕하세요, 반갑습니다")

        let save = app.buttons["저장"].firstMatch
        XCTAssertTrue(save.isEnabled, "이름과 내용을 넣었는데 저장 단추가 꺼져 있다")
        save.tap()

        XCTAssertTrue(app.buttons[title].firstMatch.waitForExistence(timeout: 10),
                      "저장한 단축어가 첫 화면에 보이지 않는다")
        XCTAssertFalse(app.textFields["키보드에 표시할 이름"].exists, "저장 뒤에도 새 단축어 화면이 남아 있다")
    }

    // MARK: - 접근성 자동 점검

    /// 새 단축어 화면(가장 많이 쓰는 입력 화면)의 접근성 자동 점검.
    ///
    /// 대비 · 글자 크기 · 글자 잘림은 여기서 보지 않는다. 테마 색표와 고정 높이 카드 전반의 일이라
    /// 로드맵 `a11y.contrast` · `a11y.largetext` 로 따로 다룬다. 그 일이 끝나면 이 걸러내기를 걷는다.
    /// 나머지(설명 없는 요소 · 누를 자리 크기 · 역할 · 요소 겹침)는 여기서 막는다.
    func testAddShortcutScreenPassesAccessibilityAudit() throws {
        let app = launchApp()
        openAddShortcut(in: app)

        let types: XCUIAccessibilityAuditType = .all
            .subtracting([.contrast, .dynamicType, .textClipped])
        try app.performAccessibilityAudit(for: types) { issue in
            // 이름 칸에 커서가 있어 시스템 키보드가 떠 있다. 그 위 자동 완성 줄의 빈 후보 단추는
            // 앱이 만든 것이 아니라 설명을 붙일 수 없다(오탐).
            if issue.auditType == .sufficientElementDescription,
               let element = issue.element,
               app.keyboards.firstMatch.exists,
               element.frame.minY >= app.keyboards.firstMatch.frame.minY - 60 {
                return true
            }
            return false
        }
    }
}
