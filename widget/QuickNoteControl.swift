//
//  QuickNoteControl.swift
//  widget
//
//  Control Center / 잠금화면 컨트롤 — 탭하면 ClipKeyboard 를 열어 빠른 메모 입력 시트를 띄운다.
//  애플 "빠른 메모"처럼 앱을 일일이 찾지 않고 어디서든 바로 캡처를 시작하게 한다.
//
//  컨트롤 인텐트는 위젯 익스텐션 프로세스에서 실행되므로 인앱 NotificationCenter 로는 신호가
//  닿지 않는다. 대신 App Group UserDefaults 에 보류 플래그를 켜두고(openAppWhenRun 으로 앱이 열림),
//  앱이 활성화될 때 그 플래그를 소비해 빠른 메모 입력 시트를 띄운다.
//

import WidgetKit
import SwiftUI
import AppIntents

@available(iOS 18.0, *)
struct AddQuickNoteControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Note"
    static var description = IntentDescription("Capture a quick note into ClipKeyboard.")

    // openAppWhenRun 은 제어센터 컨트롤에서 앱을 안 여는 경우가 있어,
    // 확실히 앱이 열리는 URL 딥링크(clipkeyboard://quicknote)로 연다.
    // (위젯의 copy 딥링크가 이미 같은 스킴으로 앱을 여는 게 검증됨.)
    func perform() async throws -> some IntentResult & OpensIntent {
        let url = URL(string: "clipkeyboard://quicknote")!
        return .result(opensIntent: OpenURLIntent(url))
    }
}

@available(iOS 18.0, *)
struct QuickNoteControl: ControlWidget {
    // kind 는 기존 컨트롤과 동일하게 유지(이미 추가한 사용자의 컨트롤이 갱신되도록).
    static let kind = "com.Ysoup.TokenMemo.QuickNoteInboxControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: AddQuickNoteControlIntent()) {
                Label("Quick Note", systemImage: "note.text.badge.plus")
            }
        }
        .displayName("Quick Note")
        .description("Capture a quick note into ClipKeyboard.")
    }
}
