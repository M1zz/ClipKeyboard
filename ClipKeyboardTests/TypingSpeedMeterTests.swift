//
//  TypingSpeedMeterTests.swift
//  ClipKeyboardTests
//
//  치는 속도를 **재는** 부분의 계약을 고정한다.
//
//  이 파일이 지키는 것은 숫자가 아니라 "무엇을 표본으로 인정하는가"이다.
//  잘못 인정한 표본 하나가 이 앱의 모든 숫자를 흔든다
//   · 붙여넣기를 표본으로 세면 "초당 200자"가 되고, 아낀 시간이 0에 수렴한다.
//   · 고민하며 멈춘 30초를 세면 "초당 0.3자"가 되고, 아낀 시간이 터무니없이 부푼다.
//  둘 다 사용자가 화면을 못 믿게 만드는 방향이라, 애매하면 **표본을 버리는 쪽**이다.
//

import XCTest
@testable import ClipKeyboard

final class TypingSpeedMeterTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_770_000_000)

    override func setUp() {
        super.setUp()
        TypingSpeedMeter.reset()
    }

    override func tearDown() {
        TypingSpeedMeter.reset()
        super.tearDown()
    }

    /// 한 글자씩 일정한 간격으로 친 판을 만든다.
    private func steadyRun(characters: Int, secondsPerCharacter: Double) -> TypingRun {
        var run = TypingRun()
        var text = ""
        run.note(text, at: start)
        for i in 1...characters {
            text += "가"
            run.note(text, at: start.addingTimeInterval(Double(i) * secondsPerCharacter))
        }
        return run
    }

    // MARK: - 표본으로 인정하는 것

    func test_또박또박_친_것은_표본이_된다() {
        let run = steadyRun(characters: 40, secondsPerCharacter: 0.25)   // 초당 4자
        let sample = run.sample()

        XCTAssertEqual(sample?.characters, 40)
        XCTAssertEqual(sample?.seconds ?? 0, 10, accuracy: 0.001)
    }

    func test_붙여넣은_판은_통째로_버린다() {
        var run = TypingRun()
        run.note("", at: start)
        run.note("가가가", at: start.addingTimeInterval(0.2))            // 한 번에 세 글자
        for i in 1...40 {
            run.note("가가가" + String(repeating: "나", count: i),
                     at: start.addingTimeInterval(0.2 + Double(i) * 0.25))
        }

        XCTAssertTrue(run.didPaste)
        XCTAssertNil(run.sample(), "붙여넣기를 친 것으로 세면 초당 수백 자가 되어 아낀 시간이 0이 된다")
    }

    func test_고민하며_멈춘_시간은_안_센다() {
        var run = TypingRun()
        var text = ""
        run.note(text, at: start)
        // 20자를 치고 → 30초 멈췄다가 → 20자를 더 친다.
        for i in 1...20 {
            text += "가"
            run.note(text, at: start.addingTimeInterval(Double(i) * 0.25))
        }
        var t = 5.0 + 30.0
        for _ in 1...20 {
            text += "가"
            t += 0.25
            run.note(text, at: start.addingTimeInterval(t))
        }

        let sample = run.sample()
        XCTAssertEqual(sample?.characters, 39, "멈춘 뒤 첫 글자는 간격이 커서 안 세어진다")
        XCTAssertLessThan(sample?.seconds ?? 999, 12,
                          "멈춰 있던 30초를 치는 시간으로 세면 이 사람이 열 배 느린 것이 된다")
    }

    func test_지웠다_다시_친_것을_두_번_세지_않는다() {
        var run = TypingRun()
        var text = ""
        run.note(text, at: start)
        for i in 1...30 {
            text += "가"
            run.note(text, at: start.addingTimeInterval(Double(i) * 0.25))
        }
        // 열 글자를 지운다 - 시간은 흘렀지만 친 글자는 안 늘었다.
        text = String(text.dropLast(10))
        run.note(text, at: start.addingTimeInterval(9))

        XCTAssertEqual(run.sample()?.characters, 30, "지운 것을 빼면 실제로 친 수고가 사라진다")
    }

    func test_너무_짧은_판은_표본이_아니다() {
        XCTAssertNil(steadyRun(characters: 5, secondsPerCharacter: 0.25).sample(),
                     "다섯 글자로 사람의 속도를 단정할 수 없다")
    }

    /// ⚠️ 한글은 한 글자를 만드는 데 자판을 두세 번 누른다. 값은 "ㅇ"→"아"→"안" 으로
    ///    바뀌어 글자수는 한 번만 느는데, 손은 세 번 움직였다. 글자가 늘 때만 시간을 세면
    ///    한국어 사용자가 실제보다 두세 배 빠른 것으로 잡히고, 그만큼 아낀 시간이 깎인다.
    func test_한글_조합을_실제_속도로_잰다() {
        var run = TypingRun()
        run.note("", at: start)
        // 0.2초 간격으로 자판을 눌러 "안녕..." 을 만든다. 한 글자에 세 번씩.
        let syllables = ["안", "녕", "하", "세", "요"]
        var text = ""
        var t = 0.0
        for _ in 1...4 {                       // 20자를 채우려면 다섯 음절을 네 번
            for syllable in syllables {
                let jamoStates = ["ㅇ", "아", syllable]   // 자판을 세 번 누른 셈
                for (index, _) in jamoStates.enumerated() {
                    t += 0.2
                    // 마지막 눌림에서만 완성된 글자가 값에 남는다.
                    let shown = index == jamoStates.count - 1 ? text + syllable : text + "ㅇ"
                    run.note(shown, at: start.addingTimeInterval(t))
                }
                text += syllable
            }
        }

        let sample = run.sample()
        XCTAssertEqual(sample?.characters, 20, "완성된 글자만 센다")
        // 자판을 60번 눌렀으니 12초. 글자가 늘 때만 셌다면 4초로 잡혔을 것이다.
        XCTAssertEqual(sample?.seconds ?? 0, 11.8, accuracy: 0.3,
                       "자모를 조합하는 시간을 안 세면 한국어 사용자가 세 배 빠른 것으로 잡힌다")
    }

    // MARK: - 쌓기

    func test_표본이_모자라면_가정을_쓴다() {
        steadyRun(characters: 20, secondsPerCharacter: 0.25).commit()

        XCTAssertNil(TypingSpeedMeter.measured, "한 번 친 것으로 사람의 속도를 단정하지 않는다")
        XCTAssertEqual(TypingSpeedMeter.charsPerSecond,
                       TypingSpeedMeter.assumedCharsPerSecond, accuracy: 0.001)
    }

    func test_충분히_쌓이면_잰_값을_쓴다() {
        // 초당 2.86자 - 가정(4자)보다 느린 사람.
        for _ in 1...3 { steadyRun(characters: 40, secondsPerCharacter: 0.35).commit() }

        let measured = try? XCTUnwrap(TypingSpeedMeter.measured)
        XCTAssertNotNil(measured)
        XCTAssertEqual(TypingSpeedMeter.charsPerSecond, 1 / 0.35, accuracy: 0.05)
        XCTAssertTrue(TypingSpeedMeter.isMeasured)
    }

    func test_긴_표본이_짧은_표본보다_무겁다() {
        // 평균의 평균을 내면 둘이 같은 무게가 된다. 글자수와 초를 각각 쌓으면 안 그렇다.
        steadyRun(characters: 200, secondsPerCharacter: 0.25).commit()   // 초당 4자
        steadyRun(characters: 20, secondsPerCharacter: 0.4).commit()     // 초당 2.5자

        // 둘의 단순 평균은 3.25자. 글자수로 무게를 주면 4에 훨씬 가까워야 한다.
        XCTAssertGreaterThan(TypingSpeedMeter.charsPerSecond, 3.6)
    }

    // MARK: - 울타리

    func test_울타리_밖의_표본은_안_쌓는다() {
        // 초당 20자 - 사람이 낼 수 있는 속도가 아니다(못 거른 붙여넣기 같은 것).
        TypingSpeedMeter.record(characters: 200, seconds: 10 / 20 * 2)
        TypingSpeedMeter.record(characters: 400, seconds: 20)            // 초당 20자
        XCTAssertNil(TypingSpeedMeter.measured, "울타리 밖 표본을 잘라서 쌓으면 울타리 값이 사실처럼 쌓인다")
    }

    /// ⚠️ 이게 깨지면 모델의 앞뒤가 뒤집힌다. "숫자가 글보다 치기 어렵다"가 이 앱의
    ///    셈 전체에 깔려 있는데, 잰 글 속도가 숫자 속도보다 느려지면 그 전제가 무너진다.
    func test_잰_값이_숫자_속도보다_느려지지_않는다() {
        XCTAssertGreaterThan(TypingSpeedMeter.slowest, TimeSavedModel.digitCharsPerSecond)

        // 아주 느리게 친 표본만 쌓여도 울타리 아래로는 안 내려간다.
        for _ in 1...5 { TypingSpeedMeter.record(characters: 40, seconds: 16) }  // 초당 2.5자
        XCTAssertGreaterThanOrEqual(TypingSpeedMeter.charsPerSecond, TypingSpeedMeter.slowest)
        XCTAssertGreaterThan(TypingSpeedMeter.charsPerSecond, TimeSavedModel.digitCharsPerSecond)
    }

    // MARK: - 모델에 닿는가

    func test_느리게_치는_사람은_더_많이_아낀_것이_된다() {
        let text = String(repeating: "가", count: 400)
        let assumed = TimeSavedModel.breakdown(value: text, type: .text).typing

        for _ in 1...3 { steadyRun(characters: 40, secondsPerCharacter: 0.4).commit() }  // 초당 2.5자
        let measured = TimeSavedModel.breakdown(value: text, type: .text).typing

        XCTAssertGreaterThan(measured, assumed,
                             "실제로 느리게 치는 사람에게 평균 속도를 들이대면 그 사람이 아낀 것을 과소평가한다")
    }
}
