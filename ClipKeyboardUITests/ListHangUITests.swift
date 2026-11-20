//
//  ListHangUITests.swift
//  ClipKeyboardUITests
//
//  단축어가 많은 목록을 굴리고 넘기는 동안 **메인 스레드가 멈추는지** 본다.
//
//  몽키 시험은 "앱이 죽었는가" 를 본다. 그런데 이 앱의 사고는 죽기 전에 먼저 **굳는다**:
//  한 프레임의 갱신이 몇 초씩 끝나지 않다가 워치독이 끈다. 굳은 앱은 몽키가 지나가도 살아 있다.
//  이 시험은 앱 안의 탐침(`HangProbe`)이 잰 멈춘 시간을 읽어, 2.5초를 넘긴 것이 있으면 실패한다.
//  (docs/postmortem/LAUNCH_INCOMPLETE_BACKGROUND_WAKE_5_1_24.md 4절)
//
//  돌리기:
//    xcodebuild test -scheme ClipKeyboardUITests -only-testing:ClipKeyboardUITests/ListHangUITests
//  환경 변수(xcodebuild 에는 TEST_RUNNER_ 를 앞에 붙인다):
//    HANG_STEPS(동작 수, 기본 120) · HANG_SEED(순서, 기본 2026) · HANG_MEMOS(단축어 수, 기본 300)
//    HANG_FAIL_SECONDS(실패로 치는 멈춤, 기본 2.5)
//
//  멈춤을 찾았으면: 기록 파일(`/tmp/clipkeyboard-hang-*.log`)에 `hang-start` 가 찍히는 순간
//  `sample ClipKeyboard 3` 을 돌리면 메인 스레드가 어디서 도는지 나온다. 같은 시드로 다시 돌리면 같은 순서다.
//
//  ⚠️ 시뮬레이터의 단축어를 시험용 300개로 갈아 끼운다. 원래 것은 백업되고,
//     시험이 끝나면 되돌린다(`tearDown` · `HangProbe` 의 `-HangProbeRestore`).
//

import XCTest

final class ListHangUITests: XCTestCase {

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

    /// 탐침이 적는 파일. 시뮬레이터에서는 앱과 시험이 같은 맥의 파일을 본다.
    private let reportPath = "/tmp/clipkeyboard-hang-\(UUID().uuidString.prefix(8)).log"

    private func launch(memos: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR",
            "-startedFresh.v444", "NO", "-firstShortcut.done.v1", "YES",
            "-tutorialChaptersDone.v1", "YES", "-keyboardStageOffered.v1", "YES",
            "-didYouKnow.optOut.v1", "YES", "-ghostSuggestionsOff_v1", "YES",
            "-defaultSamplesInserted_v1", "YES", "-demoSampleOfferResolved_v1", "YES",
            "-HangProbe", "-HangProbeMemos", "\(memos)",
        ]
        app.launchEnvironment["HANG_PROBE_REPORT"] = reportPath
        app.launch()
        return app
    }

    /// 깔아 둔 단축어 300개를 걷고 시뮬레이터의 원래 데이터로 되돌린다.
    override func tearDown() {
        let app = XCUIApplication()
        app.launchArguments += ["-HangProbeRestore"]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 20)
        app.terminate()
        super.tearDown()
    }

    func testListDoesNotHang() throws {
        let env = ProcessInfo.processInfo.environment
        let steps = Int(env["HANG_STEPS"] ?? "") ?? 120
        let memos = Int(env["HANG_MEMOS"] ?? "") ?? 300
        var random = SeededRandom(state: UInt64(env["HANG_SEED"] ?? "") ?? 2026)
        // 고른 요소가 누르기 전에 사라지는 건 앱 잘못이 아니다. 실패는 멈춤 기록으로만 가린다.
        continueAfterFailure = true

        addUIInterruptionMonitor(withDescription: "권한") { alert in
            for label in ["허용 안 함", "Don't Allow", "붙여넣기 허용 안 함", "취소", "Cancel", "확인", "OK"] {
                let button = alert.buttons[label]
                if button.exists { button.tap(); return true }
            }
            return false
        }

        try? FileManager.default.removeItem(atPath: reportPath)
        var app = launch(memos: memos)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "앱이 뜨지 않았다")

        /// (시각, 한 일). 멈춤 기록의 시각과 맞춰 본다.
        var actions: [(TimeInterval, String)] = []
        func note(_ s: String) {
            actions.append((Date().timeIntervalSince1970, s))
            print("🧊 \(s)")
        }
        func point(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
            app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
        }

        note("앱을 켬 (단축어 \(memos)개)")
        // 켜는 동안의 멈춤은 여기서 세지 않는다. 설치 직후 첫 실행은 개발 빌드에서 몇 초씩 걸리고,
        // 그건 목록을 쓰는 중의 멈춤과 다른 일이다(켤 때는 단축어 수와 무관하게 1초 남짓으로 쟀다).
        let watchingSince = Date().timeIntervalSince1970

        for step in 0..<steps {
            switch app.state {
            case .notRunning, .unknown:
                note("앱이 죽어 다시 켬")
                app = launch(memos: memos)
                continue
            case .runningBackground, .runningBackgroundSuspended:
                note("앞으로 다시 데려옴")
                app.activate()
                continue
            default:
                break
            }

            let roll = Int.random(in: 0..<100, using: &random)
            XCTExpectFailure("고른 요소가 누르기 전에 사라졌다(앱 잘못 아님)", strict: false) {
                switch roll {
                case 0..<22:
                    // 제목이 접히는 문턱 근처를 천천히 오르내린다. 바 높이가 스크롤 판정을 다시 바꾸는 자리다.
                    let distance = CGFloat.random(in: 0.03...0.12, using: &random)
                    let up = Bool.random(using: &random)
                    note("천천히 \(up ? "올림" : "내림") \(String(format: "%.2f", distance))")
                    let from = point(0.5, 0.5)
                    let to = point(0.5, up ? 0.5 - distance : 0.5 + distance)
                    from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.1)
                case 22..<40:
                    let up = Bool.random(using: &random)
                    note(up ? "빠르게 위로 밀기" : "빠르게 아래로 밀기")
                    if up { app.swipeUp(velocity: .fast) } else { app.swipeDown(velocity: .fast) }
                case 40..<54:
                    // 왼쪽 위 제목(카테고리 고르기)을 열고, 뜬 목록에서 아무 줄이나 고른다.
                    note("카테고리 고르기 열기")
                    point(0.2, 0.1).tap()
                    let y = CGFloat.random(in: 0.35...0.9, using: &random)
                    note("고르기에서 누름 y=\(String(format: "%.2f", y))")
                    point(0.4, y).tap()
                case 54..<64:
                    let x = CGFloat.random(in: 0.1...0.9, using: &random)
                    let y = CGFloat.random(in: 0.25...0.8, using: &random)
                    note("카드 누름 (\(String(format: "%.2f", x)), \(String(format: "%.2f", y)))")
                    point(x, y).tap()
                case 64..<72:
                    let x = CGFloat.random(in: 0.1...0.9, using: &random)
                    let y = CGFloat.random(in: 0.25...0.8, using: &random)
                    note("카드 길게 누름 (\(String(format: "%.2f", x)), \(String(format: "%.2f", y)))")
                    point(x, y).press(forDuration: 0.9)
                case 72..<82:
                    // 떠 있는 시트 · 화면을 닫는다.
                    let close = ["닫기", "취소", "완료", "뒤로", "Back", "Close", "Cancel", "Done"]
                        .map { app.buttons[$0].firstMatch }
                        .first { $0.exists && $0.isHittable }
                    if let close {
                        note("닫기 '\(close.label)'")
                        close.tap()
                    } else {
                        note("아래로 끌어 닫기")
                        point(0.5, 0.2).press(forDuration: 0.05, thenDragTo: point(0.5, 0.95))
                    }
                case 82..<90:
                    // 아래 탭을 오간다. 목록 화면이 새로 만들어질 때도, 살아 있을 때도 있다.
                    let tabs = app.tabBars.buttons.allElementsBoundByIndex.filter { $0.isHittable }
                    if let tab = tabs.randomElement(using: &random) {
                        note("탭 '\(tab.label)'")
                        tab.tap()
                    }
                case 90..<95:
                    note("홈으로 나갔다 돌아옴")
                    XCUIDevice.shared.press(.home)
                    app.activate()
                default:
                    let landscape = XCUIDevice.shared.orientation.isLandscape
                    note(landscape ? "세로로 돌림" : "가로로 돌림")
                    XCUIDevice.shared.orientation = landscape ? .portrait : .landscapeLeft
                }
            }
            if step % 15 == 0 { XCTExpectFailure(strict: false) { app.tap() } }
        }
        XCUIDevice.shared.orientation = .portrait
        // 마지막 동작이 일으킨 멈춤이 끝나 기록될 틈을 준다.
        _ = app.wait(for: .runningForeground, timeout: 5)
        sleep(2)

        // MARK: 기록 읽기

        let report = (try? String(contentsOfFile: reportPath, encoding: .utf8)) ?? ""
        XCTAssertTrue(report.contains("probe-start"),
                      "탐침 기록이 없다. 앱이 `-HangProbe` 를 받지 못했거나 \(reportPath) 에 쓰지 못했다")

        func value(_ key: String, in line: String) -> Double? {
            line.split(separator: " ").first { $0.hasPrefix(key + "=") }
                .flatMap { Double($0.dropFirst(key.count + 1)) }
        }
        var ended: Set<Double> = []
        var hangs: [(at: Double, seconds: Double?)] = []
        for line in report.split(separator: "\n").map(String.init) where line.hasPrefix("hang-end") {
            if let at = value("at", in: line) {
                ended.insert(at)
                hangs.append((at, value("seconds", in: line)))
            }
        }
        // 시작만 찍히고 끝이 없는 것은 **끝까지 안 풀린** 멈춤이다(워치독이 끄는 그 사고).
        for line in report.split(separator: "\n").map(String.init) where line.hasPrefix("hang-start") {
            if let at = value("at", in: line), !ended.contains(at) { hangs.append((at, nil)) }
        }

        // 멈추지는 않아도 같은 화면이 1초에 200번 넘게 다시 그려졌으면 고리다(`HangProbe.noteRender`).
        let storms = report.split(separator: "\n").map(String.init).filter { $0.hasPrefix("render-storm") }
        XCTAssertTrue(storms.isEmpty, "화면이 끝없이 다시 그려졌다:\n" + storms.joined(separator: "\n"))

        hangs.removeAll { $0.at < watchingSince }
        // 탐침은 1초부터 적지만, 실패로 치는 것은 `failSeconds` 를 넘긴 것과 끝까지 안 풀린 것이다.
        // 개발 빌드 · 시뮬레이터에서는 홈에서 돌아오는 순간처럼 1초 남짓 걸리는 자리가 있고(실측 1.3초),
        // 그것까지 실패로 치면 시험이 오락가락해 아무도 안 믿게 된다. 기기를 끈 멈춤은 5초를 넘겼다.
        let failSeconds = Double(env["HANG_FAIL_SECONDS"] ?? "") ?? 2.5
        for hang in hangs where (hang.seconds ?? .infinity) < failSeconds {
            print("🧊 짧은 멈춤 \(String(format: "%.1f", hang.seconds ?? 0))초 (실패로 치지 않음)")
        }
        hangs.removeAll { ($0.seconds ?? .infinity) < failSeconds }
        guard !hangs.isEmpty else { return }
        let detail = hangs.sorted { $0.at < $1.at }.map { hang -> String in
            let before = actions.filter { $0.0 <= hang.at + 0.3 && $0.0 > hang.at - 6 }.map { "    " + $0.1 }
            let length = hang.seconds.map { String(format: "%.1f초", $0) } ?? "끝까지 안 풀림"
            return "멈춤 \(length). 직전 동작:\n" + before.joined(separator: "\n")
        }
        XCTFail("목록에서 메인 스레드가 \(hangs.count)번 멈췄다 (시드 \(env["HANG_SEED"] ?? "2026")):\n\n"
                + detail.joined(separator: "\n\n"))
    }
}
