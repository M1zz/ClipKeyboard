//
//  KeyboardSetupBannerGate.swift
//  ClipKeyboard
//
//  무대의 "아직 다른 앱에서는 못 써요" 띠를 **언제** 보여줄 것인가.
//
//  ⚠️ 켜야 한다는 말은 반드시 해야 한다. 키보드를 켜지 않으면 이 앱은 아무것도 아니다.
//     그래서 켜지 않은 동안에는 **늘** 선다. 목록 탭의 띠(`KeyboardSetupRequiredBanner`)와
//     같은 약속이다 - 닫는 단추가 없고, 켜는 것 말고는 사라지는 길이 없다.
//
//  ⚠️ 예외는 하나, **튜토리얼을 걷는 동안**이다. 튜토리얼은 무대 위에 화살표와 안내를
//     띄워 한 걸음씩 데려간다. 그 사이에 띠가 끼면 둘 다 안 읽힌다. 끝나는 순간부터 선다.
//
//  예전에는 더 미뤘다. 튜토리얼을 끝내고 한 시간 쉬기, 자기 단축어가 없는 사람·휴면인
//  사람에게는 숨기기, 다른 안내가 서 있으면 비켜 주기. 그러자 키보드를 켜지 않은 사람이
//  키보드 탭에서는 켜라는 말을 못 듣는 때가 생겼다(신고: 키보드가 설정되지 않았을 때
//  키보드 탭에도 목록 탭에도 안내를 계속 보여줘). 켜라는 말은 미룰수록 손해다.
//

import Foundation

enum KeyboardSetupBannerGate {

    /// 지금 띠를 보여줄 자리인가.
    ///
    /// - Parameters:
    ///   - keyboardUsable: 켜져 있는가. 켜져 있으면 무슨 일이 있어도 안 띄운다.
    ///   - startedFresh: 이 기기가 튜토리얼을 걷는 중이(었)는가.
    ///   - tutorialFinished: 튜토리얼을 끝냈는가.
    static func shows(keyboardUsable: Bool,
                      startedFresh: Bool,
                      tutorialFinished: Bool) -> Bool {
        // 하나뿐인 종료 조건 - 켜져 있으면 켜는 법을 말하지 않는다.
        guard !keyboardUsable else { return false }
        // 배우는 도중에 끼어들면 둘 다 안 읽힌다.
        let walkingTutorial = startedFresh && !tutorialFinished
        return !walkingTutorial
    }
}
