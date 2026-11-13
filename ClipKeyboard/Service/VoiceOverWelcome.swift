//
//  VoiceOverWelcome.swift
//  ClipKeyboard
//
//  VoiceOver 를 켜고 앱에 들어온 사람에게만 소리로 들려주는 짧은 안내.
//
//  사용자 요청(2026-11): 화면에는 아무것도 띄우지 않고, VoiceOver 로만 앱이 어떻게 생겼는지
//  알려 준다. 예전에는 같은 때에 '손쉬운 사용' 시트를 띄웠는데, 시트는 초점을 빼앗고
//  눈으로 보는 사람에게도 보였다. 자세한 안내는 설정 ▸ 사용법과 문의 ▸ 손쉬운 사용에 그대로 있다.
//
//  - 처음 한 번은 저절로 읽는다(`isDue`)
//  - 그다음은 목록 맨 위 카테고리 이름의 VoiceOver 동작 "앱 안내 다시 듣기" 로 다시 듣는다
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

enum VoiceOverWelcome {

    /// 저절로 읽어 준 적이 있는가 (standard UD).
    /// ⚠️ 예전 시트의 표식(`a11y_guide_nudge_shown_v1`)과 다른 키다. 시트를 본 사람도 소리 안내는 한 번 듣는다.
    static let heardKey = "a11y.voiceOverWelcome.heard.v1"

    /// 저절로 읽을 때인가. VoiceOver 가 켜져 있고 아직 들은 적이 없을 때 한 번.
    static func isDue(voiceOverRunning: Bool, heard: Bool) -> Bool {
        voiceOverRunning && !heard
    }

    /// 다시 듣는 VoiceOver 동작의 이름. 안내 끝에서도 이 이름을 그대로 말한다.
    static var replayActionName: String {
        NSLocalizedString("앱 안내 다시 듣기", comment: "VoiceOver custom action on the list title: hear the short spoken app guide again")
    }

    /// 읽을 글. 단축어 칸을 두 번 탭했을 때 무엇이 되는지는 설정(카드를 누르면 메뉴 열기)을 따른다.
    static func message(cardTapOpensMenu: Bool) -> String {
        let intro = NSLocalizedString(
            "클립키보드예요. 자주 쓰는 글을 단축어로 담아 두고 키보드에서 바로 넣는 앱이에요. 화면 맨 위에는 지금 보는 카테고리 이름이 있고, 두 번 탭하면 다른 카테고리를 고를 수 있어요. 오른쪽 위 추가 단추로 새 단축어를 만들어요.",
            comment: "VoiceOver-only spoken app guide, part 1: what the app is and the top of the list screen. Spoken, never shown. Keep it natural for listening")
        let cards = cardTapOpensMenu
            ? NSLocalizedString("그 아래로 단축어가 이어져요. 두 번 탭하면 편집과 삭제 메뉴가 열리고, 위아래로 쓸어 복사를 고르면 복사돼요.",
                                comment: "VoiceOver-only spoken app guide, part 2 when the user swapped tap and long press: double tap opens the menu, the Copy action copies")
            : NSLocalizedString("그 아래로 단축어가 이어져요. 두 번 탭하면 복사되고, 위아래로 쓸어 더 보기를 고르면 편집과 삭제를 할 수 있어요.",
                                comment: "VoiceOver-only spoken app guide, part 2: double tap a phrase to copy it, the More action opens edit and delete")
        let tabs = NSLocalizedString("맨 아래 탭에는 목록, 설정, 검색이 있어요.",
                                     comment: "VoiceOver-only spoken app guide, part 3: the bottom tabs are List, Settings and Search")
        let replay = String(
            format: NSLocalizedString("이 안내는 맨 위 카테고리 이름에서 위아래로 쓸어 %@를 고르면 다시 들을 수 있어요.",
                                      comment: "VoiceOver-only spoken app guide, last part: how to hear it again. %@ is the action name 'Hear app guide again'"),
            replayActionName)
        return [intro, cards, tabs, replay].joined(separator: " ")
    }

    /// 읽는다. 지금 VoiceOver 가 읽던 것을 끊지 않고 그 뒤에 잇는다.
    static func speak(cardTapOpensMenu: Bool) {
        #if os(iOS)
        let text = NSAttributedString(
            string: message(cardTapOpensMenu: cardTapOpensMenu),
            attributes: [.accessibilitySpeechQueueAnnouncement: true])
        UIAccessibility.post(notification: .announcement, argument: text)
        #endif
    }

    /// 지금 저장된 설정으로 읽는다.
    static func speakWithCurrentSettings() {
        speak(cardTapOpensMenu: UserDefaults.standard.object(forKey: AppPrefs.cardTapOpensMenu.key) as? Bool
              ?? AppPrefs.cardTapOpensMenu.fallback)
    }
}
