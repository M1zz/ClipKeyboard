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

    /// 단축어 개수 한도를 끈다. 실행마다 단축어가 하나씩 쌓여, 열 개를 넘은 시뮬레이터에서는
    /// 저장이 결제 화면으로 바뀌어 "만들면 첫 화면에 선다" 를 볼 수 없다(2026-11-21 실패 원인).
    /// 실행 인자는 App Group 설정에도 보이므로 앱이 Pro 로 읽는다(`ProFeatureManager.purchasedTier`).
    static let asPaidUser = ["-clipkeyboard_is_pro", "YES"]

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
        ] + Self.asPaidUser
        app.launch()
        return app
    }

    private func openAddShortcut(in app: XCUIApplication) {
        let add = app.buttons["단축어 추가"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 20), "첫 화면에 단축어 추가 단추가 없다")
        add.tap()
        // 쓰던 사람에게 + 는 메뉴를 연다(새 단축어 만들기 · 단축어 마트 · 한번에 정리 · 빈칸 관리).
        // 백지로 시작한 사람에게는 메뉴 없이 곧바로 만들기 화면이 뜬다. 두 경우를 다 받는다.
        let create = app.buttons["새 단축어 만들기"].firstMatch
        if create.waitForExistence(timeout: 5) { create.tap() }
        XCTAssertTrue(app.textFields["키보드에 표시할 이름"].waitForExistence(timeout: 20),
                      "새 단축어 화면이 열리지 않았다")
    }

    /// 붙여넣을 내용 칸. 처음에는 한 줄 입력칸이고, 길어지면 여러 줄 편집기로 바뀐다. 있는 쪽을 쓴다.
    private func bodyField(in app: XCUIApplication) -> XCUIElement {
        let field = app.textFields["붙여넣을 내용"]
        return field.exists ? field : app.textViews["붙여넣을 내용"]
    }

    // MARK: - 핵심 흐름

    /// 단축어를 하나 만들면 시트가 닫히고, 그 이름이 첫 화면에 선다.
    func testCreatingShortcutShowsItOnHome() throws {
        let app = launchApp()
        openAddShortcut(in: app)

        // 실행마다 다른 이름 - 시뮬레이터에 지난 실행의 단축어가 남아 있어도 이번 것을 찾는다.
        let title = "UI시험 \(Int(Date().timeIntervalSince1970) % 100_000)"
        app.textFields["키보드에 표시할 이름"].typeText(title)
        let body = bodyField(in: app)
        body.tap()
        body.typeText("안녕하세요, 반갑습니다")

        let save = app.buttons["저장"].firstMatch
        XCTAssertTrue(save.isEnabled, "이름과 내용을 넣었는데 저장 단추가 꺼져 있다")
        save.tap()

        XCTAssertTrue(app.textFields["키보드에 표시할 이름"].waitForNonExistence(timeout: 10),
                      "저장 뒤에도 새 단축어 화면이 남아 있다")
        // 새 카드는 즐겨찾기 뒤에 앉는다. 단축어가 많은 시뮬레이터에서는 화면 아래에 있어서
        // (격자가 게을러 아직 만들어지지 않았다) 보일 때까지 내려 본다.
        let card = app.buttons[title].firstMatch
        var found = card.waitForExistence(timeout: 10)
        for _ in 0..<8 where !found {
            app.swipeUp()
            found = card.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(found, "저장한 단축어가 첫 화면에 보이지 않는다")
    }

    /// 목록 화면에서 단축어를 만들어도 첫 화면이 **제자리에 있다.**
    ///
    /// 새 단축어 시트가 뜨고 닫히는 사이 갈래 페이저가 세로로 밀린 채 굳어, 첫 화면이 통째로 약 115pt
    /// 올라가던 일을 지킨다(사용자 신고 2026-10-18, `PagerVerticalPin`). 맨 위 키보드 켜기 띠를 잣대로
    /// 쓴다. 시뮬레이터에서는 이 키보드를 켜지 않으므로 늘 서 있다.
    func testCreatingShortcutKeepsListInPlace() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR",
            "-startedFresh.v444", "NO", "-firstShortcut.done.v1", "YES",
            "-tutorialChaptersDone.v1", "YES", "-keyboardStageOffered.v1", "YES",
            "-didYouKnow.optOut.v1", "YES", "-ghostSuggestionsOff_v1", "YES",
            "-defaultSamplesInserted_v1", "YES", "-demoSampleOfferResolved_v1", "YES",
            "-snippetsTabStyle.v1", "list",
        ] + Self.asPaidUser
        app.launch()

        let banner = app.staticTexts["아직 다른 앱에서는 못 써요"].firstMatch
        guard banner.waitForExistence(timeout: 20) else {
            throw XCTSkip("키보드 켜기 띠가 없다(이 기기에서 키보드가 켜져 있다). 잣대가 없어 건너뛴다.")
        }
        let before = banner.frame.minY

        app.buttons["단축어 추가"].firstMatch.tap()
        app.buttons["새 단축어 만들기"].firstMatch.tap()
        let name = app.textFields["키보드에 표시할 이름"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "새 단축어 화면이 열리지 않았다")
        let title = "제자리 \(Int(Date().timeIntervalSince1970) % 100_000)"
        name.typeText(title)
        let body = bodyField(in: app)
        body.tap()
        body.typeText("안녕하세요")
        app.buttons["저장"].firstMatch.tap()

        XCTAssertTrue(app.buttons[title].firstMatch.waitForExistence(timeout: 10), "저장한 단축어가 보이지 않는다")
        sleep(1)
        XCTAssertEqual(banner.frame.minY, before, accuracy: 1,
                       "단축어를 만든 뒤 첫 화면이 밀렸다(\(before) → \(banner.frame.minY))")
    }

    /// 키보드 탭에서 자판으로 바꿔 두벌식으로 치면 입력칸에 조합된 한글이 들어간다.
    func testTypingKeyboardComposesHangul() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR",
            "-startedFresh.v444", "NO", "-firstShortcut.done.v1", "YES",
            "-tutorialChaptersDone.v1", "YES", "-keyboardStageOffered.v1", "YES",
            "-didYouKnow.optOut.v1", "YES", "-ghostSuggestionsOff_v1", "YES",
            "-defaultSamplesInserted_v1", "YES", "-demoSampleOfferResolved_v1", "YES",
            // ⚠️ 판(자판 · 단축어)은 실행 인자로 박지 않는다. 박으면 자판 키로 바꾼 값보다 인자가 이겨서
            //    판이 안 바뀐다. 어느 판에서 시작하든 아래에서 맞춘다.
            "-snippetsTabStyle.v1", "keyboard",
            "-keyboardTypingLanguages.v1", "ko,en", "-keyboardTypingCurrent.v1", "ko",
            "-keyboardKoreanLayout", "dubeolsik",
        ]
        app.launch()
        let element = { (label: String) in
            app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
        }
        // 지난번에 자판에서 끝났으면 단축어 판으로 돌려 두고 시작한다.
        if element("단축어").waitForExistence(timeout: 8), element("ㅎ").exists { element("단축어").tap() }
        let typingKey = element("자판")
        XCTAssertTrue(typingKey.waitForExistence(timeout: 20), "단축어 판에 자판 키가 없다")
        typingKey.tap()
        XCTAssertTrue(element("ㅎ").waitForExistence(timeout: 5), "자판으로 바뀌지 않았다")
        for key in ["ㅎ", "ㅏ", "ㄴ", "ㄱ", "ㅡ", "ㄹ"] { element(key).tap() }
        let typed = app.descendants(matching: .any)
            .matching(NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "한글", "한글")).firstMatch
        XCTAssertTrue(typed.waitForExistence(timeout: 5), "입력칸에 '한글' 이 들어가지 않았다")

        element("단축어").tap()
        XCTAssertTrue(element("자판").waitForExistence(timeout: 5), "단축어 판으로 돌아오지 않았다")
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
