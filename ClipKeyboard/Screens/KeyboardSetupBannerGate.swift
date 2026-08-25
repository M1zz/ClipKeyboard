//
//  KeyboardSetupBannerGate.swift
//  ClipKeyboard
//
//  무대의 "아직 다른 앱에서는 못 써요" 띠를 **언제부터** 보여줄 것인가.
//
//  ⚠️ 켜야 한다는 말은 반드시 해야 한다. 키보드를 켜지 않으면 이 앱은 아무것도 아니다.
//     문제는 **타이밍**이다. 튜토리얼을 막 끝낸 사람은 방금 자기 단축어를 만들고
//     "다 했다" 하는 참인데, 그 자리에서 곧바로 "아직 못 쓴다"가 뜨면 방금 한 일이
//     헛일이었다는 말로 읽힌다. 한 호흡 쉬고 말한다.
//
//  ⚠️ 그렇다고 오래 미루지 않는다. 미룰수록 **한 번도 못 써 본 채로 떠나는** 사람이 는다.
//     한 호흡은 셋 중 하나면 된다 - 한 시간이 지났거나, 앱을 다시 열었거나,
//     **먼저 뜬 다른 안내를 읽고 넘겼거나.** 마지막 것이 실제로는 가장 흔한 길이다.
//     튜토리얼이 끝나는 그 자리에는 늘 "이 탭에는 화면이 둘이에요"가 먼저 서 있어서,
//     그걸 닫는 순간이 곧 한 호흡이 끝나는 순간이다.
//
//  ⚠️ **띠는 한 자리에 하나만.** 다른 안내가 그 자리를 쓰고 있으면 비켜 준다.
//     쌓아 올리면 무대가 밀려 내려가고, 무엇부터 읽어야 하는지도 알 수 없다.
//     대신 그 자리가 비면 **켤 때까지 여기가 채운다** - 이 띠는 다른 안내와 달리
//     닫는 단추가 없다. 켜는 것 말고는 사라지는 길이 없다.
//

import Foundation

enum KeyboardSetupBannerGate {

    /// 튜토리얼을 끝낸 뒤 이만큼 지나면 띠를 올린다.
    static let breather: TimeInterval = 60 * 60

    /// 지금 띠를 보여줄 자리인가.
    ///
    /// - Parameters:
    ///   - keyboardUsable: 켜져 있는가. 켜져 있으면 무슨 일이 있어도 안 띄운다.
    ///   - startedFresh: 이 기기가 튜토리얼을 걷는 중이(었)는가. 쓰던 사람은 곧바로 띄운다.
    ///   - finishedAt: 튜토리얼이 끝난 시각. nil 이면 아직 걷는 중이다.
    ///   - finishedAtLaunch: 튜토리얼이 끝나던 그 실행의 앱 실행 횟수.
    ///   - launchCount: 지금 실행의 앱 실행 횟수. 이게 더 크면 **앱을 다시 연 것**이다.
    ///   - otherBannerShowing: 그 자리에 이미 다른 안내가 서 있는가. 있으면 비켜 준다.
    ///   - switchHintSeen: 전환 안내를 읽고 넘겼는가. 그것도 한 호흡으로 친다.
    static func shows(keyboardUsable: Bool,
                      startedFresh: Bool,
                      finishedAt: Date?,
                      finishedAtLaunch: Int,
                      launchCount: Int,
                      otherBannerShowing: Bool = false,
                      switchHintSeen: Bool = false,
                      now: Date = Date()) -> Bool {
        // 하나뿐인 종료 조건 - 켜져 있으면 켜는 법을 말하지 않는다.
        guard !keyboardUsable else { return false }
        // 한 자리에 하나만. 다른 안내가 쓰고 있으면 비켜 준다.
        guard !otherBannerShowing else { return false }
        // 쓰던 사람은 튜토리얼을 걷지 않는다. 미룰 이유도 없다.
        guard startedFresh else { return true }
        // 아직 걷는 중이면 말하지 않는다 - 배우는 도중에 끼어들면 둘 다 안 읽힌다.
        guard let finishedAt else { return false }
        // 한 호흡 - 시간이 지났거나, 다시 열었거나, 먼저 뜬 안내를 읽고 넘겼거나.
        return now.timeIntervalSince(finishedAt) >= breather
            || launchCount > finishedAtLaunch
            || switchHintSeen
    }
}
