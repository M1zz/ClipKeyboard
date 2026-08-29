//
//  TypingSpeedMeter.swift
//  ClipKeyboard
//
//  **가정 하나를 관측으로 바꾼다.**
//
//  이 앱이 "얼마나 아꼈나"를 말할 때, 그 숫자는 전부 일어나지 않은 세상의 소요 시간이다.
//  손으로 했을 세상은 존재한 적이 없으니 우리는 그걸 잰 적이 없다. 그래서 `TimeSavedModel`
//  의 상수는 전부 **가정**이고, 그 사실을 화면에 적어 두는 것이 지금까지 할 수 있는
//  최선이었다.
//
//  ⚠️ 그런데 딱 한 순간, 그 반사실이 **실제로 관측된다.** 사용자가 문구를 만들 때
//     그 값을 우리 편집기에 직접 쳐 넣는다. 그때 걸린 시간을 재면 "이 사람이 이 문자열을
//     치는 데 실제로 걸리는 시간"이 나온다. 서버도 필요 없고, 우리 앱 안에서 일어나는
//     일이라 새로 수집하는 것도 없다. 이 앱에서 가정을 관측으로 바꿀 수 있는 유일한
//     지점이라, 여기만큼은 재서 쓴다.
//
//  ⚠️ 잰 값을 그대로 믿지는 않는다. 편집기에서 치는 시간에는 **고민하는 시간**이 섞인다.
//     무슨 값을 넣을지 생각하다 멈춘 30초까지 "치는 시간"으로 세면 이 앱이 아껴 준 시간이
//     엉뚱하게 부푼다. 그래서 손이 멈춘 구간은 잘라 낸다(`maxGap`).
//
//  ⚠️ 붙여넣은 것은 안 센다. 한 번에 여러 글자가 들어오면 그건 친 게 아니다. 문구를 만들 때
//     값을 어딘가에서 복사해 오는 일이 오히려 흔해서, 이걸 안 거르면 "초당 200자"가 된다.
//
//  ⚠️ 잰 값에도 **울타리를 친다**(`slowest`~`fastest`). 표본이 적을 때 한 번 이상하게
//     나온 값이 전체 셈을 흔들면 안 되고, 특히 글 치는 속도가 숫자 치는 속도보다 느려지면
//     모델의 앞뒤가 뒤집힌다. 울타리는 그 뒤집힘을 막는 최소한이다.
//

import Foundation

enum TypingSpeedMeter {

    // MARK: - 가정과 울타리

    /// 잰 것이 없을 때 쓰는 값(자/초). `TimeSavedModel` 이 쓰던 그 가정이다.
    static let assumedCharsPerSecond: Double = 4.0

    /// 잰 값을 이 밖으로는 안 내보낸다(자/초).
    ///
    /// ⚠️ 아래쪽이 `TimeSavedModel.digitCharsPerSecond`(2.0)보다 반드시 커야 한다.
    ///    안 그러면 "숫자가 글보다 치기 어렵다"는 모델의 앞뒤가 뒤집힌다.
    static let slowest: Double = 2.5
    static let fastest: Double = 8.0

    /// 손이 이만큼 멈추면 그 사이는 **치는 시간이 아니라 고민하는 시간**으로 본다(초).
    static let maxGap: Double = 2.5

    /// 한 번에 이보다 많이 늘면 친 게 아니라 붙여넣은 것이다(자).
    static let pasteJump = 3

    /// 이 길이 아래의 표본은 안 쓴다(자). 짧으면 오차가 값을 통째로 흔든다.
    static let minimumSampleCharacters = 12

    /// 이만큼 모이기 전에는 잰 값을 안 쓴다(자). 한두 번 친 것으로 사람의 속도를 단정하지 않는다.
    static let minimumTotalCharacters = 60

    // MARK: - 쌓인 것

    private static let charsKey = "kb.typing.totalChars"
    private static let secondsKey = "kb.typing.totalSeconds"

    private static var defaults: UserDefaults? { AppGroup.defaults }

    /// 지금까지 잰 것으로 낸 속도(자/초). 표본이 모자라면 nil.
    static var measured: Double? {
        guard let d = defaults else { return nil }
        let chars = d.double(forKey: charsKey)
        let seconds = d.double(forKey: secondsKey)
        guard chars >= Double(minimumTotalCharacters), seconds > 0 else { return nil }
        return min(fastest, max(slowest, chars / seconds))
    }

    /// 셈에 쓸 속도. 잰 것이 있으면 잰 것, 없으면 가정.
    static var charsPerSecond: Double { measured ?? assumedCharsPerSecond }

    /// 잰 값을 쓰고 있는가 - 화면이 "재서 쓰는 중"이라고 밝힐 수 있게.
    static var isMeasured: Bool { measured != nil }

    /// 표본 한 번을 더한다.
    ///
    /// ⚠️ 평균을 다시 내지 않고 **글자수와 초를 각각 쌓는다.** 표본마다 길이가 달라서,
    ///    평균의 평균을 내면 12자짜리 한 번이 200자짜리 한 번과 같은 무게를 갖는다.
    static func record(characters: Int, seconds: Double) {
        guard let d = defaults,
              characters >= minimumSampleCharacters,
              seconds > 0 else { return }

        // 표본 하나가 울타리 밖이면 그 표본을 통째로 버린다. 잘라서 넣으면 울타리 값이
        // 사실처럼 쌓여, 표본이 늘수록 오히려 울타리 쪽으로 끌려간다.
        let speed = Double(characters) / seconds
        guard speed >= slowest, speed <= fastest else { return }

        d.set(d.double(forKey: charsKey) + Double(characters), forKey: charsKey)
        d.set(d.double(forKey: secondsKey) + seconds, forKey: secondsKey)
    }

    /// 처음부터 다시 - 기록 초기화에서만.
    static func reset() {
        defaults?.removeObject(forKey: charsKey)
        defaults?.removeObject(forKey: secondsKey)
    }
}

// MARK: - 한 번의 입력

/// 편집기에서 값을 쳐 넣는 **한 판**을 지켜본다.
///
/// 쓰는 쪽은 값이 바뀔 때마다 `note(_:at:)` 를 부르고, 저장할 때 `finish()` 로 넘긴다.
/// 이 구조체는 시계를 스스로 보지 않는다(전부 인자로 받는다) - 그래야 테스트가
/// 실제로 몇 초를 기다리지 않고 검증할 수 있다.
struct TypingRun {

    /// 손으로 친 글자수.
    private(set) var typedCharacters = 0
    /// 손이 움직이고 있던 시간(초). 멈춘 구간은 안 들어간다.
    private(set) var activeSeconds: Double = 0
    /// 한 번이라도 붙여넣었는가. 그러면 이 판은 통째로 버린다.
    private(set) var didPaste = false

    private var lastLength = 0
    private var lastAt: Date?

    init(startingWith value: String = "") {
        lastLength = value.count
    }

    /// 값이 바뀌었다.
    ///
    /// ⚠️ **시간과 글자를 따로 센다.** 한글 때문이다. "안"을 치려면 ㅇ·ㅏ·ㄴ 세 번을
    ///    누르는데, 값은 "ㅇ" → "아" → "안" 으로 바뀌어 **글자수는 한 번만 는다.**
    ///    글자가 늘 때만 시간을 세면 세 번 누른 시간 중 한 번치만 세어져서, 한국어를
    ///    치는 사람이 실제보다 두세 배 빠른 것으로 잡힌다. 그러면 이 앱이 아껴 준 시간이
    ///    그만큼 깎인다.
    ///
    ///    그래서 **손이 움직인 시간은 전부 세고, 글자는 실제로 늘어난 만큼만 센다.**
    ///    `typing = 글자수 / 속도` 로 쓰이므로, 속도의 단위가 "초당 완성된 글자"가 되어
    ///    앞뒤가 맞는다.
    mutating func note(_ value: String, at now: Date) {
        let length = value.count
        defer { lastLength = length; lastAt = now }

        let delta = length - lastLength

        if delta >= TypingSpeedMeter.pasteJump {
            didPaste = true
            return
        }

        guard let lastAt else { return }
        let gap = now.timeIntervalSince(lastAt)
        // 멈춰 있던 구간은 치는 시간이 아니라 고민하는 시간이다. 음수(시계가 뒤로 감)도 버린다.
        guard gap > 0, gap <= TypingSpeedMeter.maxGap else { return }

        // 자모를 조합하는 중이거나(delta 0) 지우는 중(delta 음수)이어도 손은 움직였다.
        // 지우고 다시 치는 것도 손으로 옮겨 적을 때 실제로 드는 수고다.
        activeSeconds += gap
        if delta > 0 { typedCharacters += delta }
    }

    /// 쓸 만한 표본인가. 아니면 nil.
    func sample() -> (characters: Int, seconds: Double)? {
        guard !didPaste,
              typedCharacters >= TypingSpeedMeter.minimumSampleCharacters,
              activeSeconds > 0 else { return nil }
        return (typedCharacters, activeSeconds)
    }

    /// 표본을 미터에 넘긴다. 쓸 만하지 않으면 아무 일도 안 한다.
    func commit() {
        guard let sample = sample() else { return }
        TypingSpeedMeter.record(characters: sample.characters, seconds: sample.seconds)
    }
}
