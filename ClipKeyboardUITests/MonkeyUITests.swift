//
//  MonkeyUITests.swift
//  ClipKeyboardUITests
//
//  앱을 **죽이려고** 아무 데나 누르는 시험(몽키 테스트). 사람은 정해진 길로만 다니지 않는다.
//  아무 단추나 누르고, 밀고, 시트를 열다 말고 닫고, 글을 치다 만다. 그러다 앱이 죽으면
//  죽기 직전에 한 일 20개를 남기고 실패한다. 시드를 고정해 같은 순서를 다시 돌릴 수 있다.
//
//  돌리기: xcodebuild test -scheme ClipKeyboardUITests -only-testing:ClipKeyboardUITests/MonkeyUITests
//  횟수 · 시드는 환경 변수 MONKEY_STEPS · MONKEY_SEED 로 바꾼다.
//

import XCTest

final class MonkeyUITests: XCTestCase {

    private struct SeededRandom: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    private let words = ["안녕하세요", "{날짜}", "{커서}", "👍🏽", "e\u{301}", "010-1234-5678", "{", "}", "a",
                         "아주 긴 글 아주 긴 글 아주 긴 글 아주 긴 글 아주 긴 글 아주 긴 글", ""]

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR",
            "-startedFresh.v444", "NO", "-firstShortcut.done.v1", "YES",
            "-tutorialChaptersDone.v1", "YES", "-keyboardStageOffered.v1", "YES",
            "-didYouKnow.optOut.v1", "YES", "-ghostSuggestionsOff_v1", "YES",
            "-defaultSamplesInserted_v1", "NO", "-demoSampleOfferResolved_v1", "YES",
        ]
        app.launch()
        return app
    }

    func testMonkey() throws {
        let env = ProcessInfo.processInfo.environment
        let steps = Int(env["MONKEY_STEPS"] ?? "") ?? 400
        // 몽키가 고른 단추 · 칸이 누르기 직전에 사라지는 건 흔하다(시트가 닫히는 중 등).
        // 그건 앱의 잘못이 아니니 시험을 멈추지 않는다. 실패로 치는 것은 **앱이 죽었을 때**뿐이다.
        continueAfterFailure = true
        var random = SeededRandom(state: UInt64(env["MONKEY_SEED"] ?? "") ?? 2026)

        // 권한 묻기(사진 · 알림 · 붙여넣기)가 앞을 막으면 거절하고 지나간다.
        addUIInterruptionMonitor(withDescription: "권한") { alert in
            for label in ["허용 안 함", "Don't Allow", "허용 안 함 ", "취소", "Cancel", "확인", "OK"] {
                let button = alert.buttons[label]
                if button.exists { button.tap(); return true }
            }
            return false
        }

        var app = launch()
        var log: [String] = []
        var deaths: [String] = []

        func note(_ s: String) {
            log.append(s)
            if log.count > 20 { log.removeFirst() }
            print("🐒 \(s)")
        }

        for step in 0..<steps {
            switch app.state {
            case .notRunning, .unknown:
                deaths.append("[\(step)] 앱이 죽었다. 직전 동작:\n  " + log.joined(separator: "\n  "))
                log.removeAll()
                app = launch()
                continue
            case .runningBackground, .runningBackgroundSuspended:
                // 공유 시트 · 사파리 · 설정으로 나갔다. 다시 앞으로.
                note("앞으로 다시 데려옴")
                app.activate()
                continue
            default:
                break
            }

            let frame = app.windows.firstMatch.frame
            guard frame.width > 0 else { continue }
            let roll = Int.random(in: 0..<100, using: &random)
            XCTExpectFailure("몽키가 고른 요소가 누르기 전에 사라졌다(앱 잘못 아님)", strict: false) {
                switch roll {
                case 0..<45:
                    let x = CGFloat.random(in: 0.04...0.96, using: &random)
                    let y = CGFloat.random(in: 0.06...0.96, using: &random)
                    note("누름 (\(String(format: "%.2f", x)), \(String(format: "%.2f", y)))")
                    app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
                case 45..<62:
                    let buttons = app.buttons.allElementsBoundByIndex.prefix(60).filter { $0.isHittable }
                    if let button = buttons.randomElement(using: &random) {
                        let label = button.label
                        // 결제 · 밖으로 나가는 단추는 건드리지 않는다(시험이 할 일이 아니다).
                        if ["구매", "구독", "결제", "Buy", "Subscribe", "복원", "리뷰", "평가", "공유", "메일", "dictation", "받아쓰기", "사진", "카메라"].contains(where: label.contains) { return }
                        note("단추 '\(label)'")
                        button.tap()
                    }
                case 62..<74:
                    let directions: [(String, () -> Void)] = [
                        ("위로 밀기", { app.swipeUp() }), ("아래로 밀기", { app.swipeDown() }),
                        ("왼쪽 밀기", { app.swipeLeft() }), ("오른쪽 밀기", { app.swipeRight() }),
                    ]
                    let pick = directions.randomElement(using: &random)!
                    note(pick.0)
                    pick.1()
                case 74..<84:
                    // 시트 닫기 · 뒤로.
                    let close = ["닫기", "취소", "완료", "뒤로", "Back", "Close", "Cancel", "Done"]
                        .map { app.buttons[$0].firstMatch }
                        .first { $0.exists && $0.isHittable }
                    if let close {
                        note("닫기 '\(close.label)'")
                        close.tap()
                    } else {
                        note("왼쪽 끝에서 밀어 뒤로")
                        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
                        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
                    }
                case 84..<94:
                    let fields = app.textFields.allElementsBoundByIndex.prefix(10) + app.textViews.allElementsBoundByIndex.prefix(10)
                    if let field = fields.filter({ $0.isHittable }).randomElement(using: &random) {
                        let text = words.randomElement(using: &random)!
                        note("글 넣기 '\(text.prefix(12))'")
                        field.tap()
                        field.typeText(text)
                    }
                default:
                    note("길게 누름")
                    app.coordinate(withNormalizedOffset: CGVector(dx: CGFloat.random(in: 0.1...0.9, using: &random),
                                                                  dy: CGFloat.random(in: 0.2...0.9, using: &random)))
                        .press(forDuration: 1.0)
                }
            }
            // 알림창이 떴으면 모니터가 처리하도록 한 번 건드린다.
            if step % 15 == 0 { XCTExpectFailure(strict: false) { app.tap() } }
        }

        if !deaths.isEmpty {
            XCTFail("몽키가 앱을 \(deaths.count)번 죽였다:\n\n" + deaths.joined(separator: "\n\n"))
        }
    }
}
