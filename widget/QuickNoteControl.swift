//
//  QuickNoteControl.swift
//  widget
//
//  Control Center / 잠금화면 컨트롤 — 한 번 탭하면 ClipKeyboard 를 열어 빠른 메모 보관함(Inbox)으로
//  바로 이동한다. 애플 "빠른 메모"처럼 앱을 일일이 찾지 않고 어디서든 캡처를 시작하게 한다.
//
//  컨트롤의 인텐트는 위젯 익스텐션 프로세스에서 실행되므로, 인앱 NotificationCenter 로는 신호가
//  닿지 않는다. 대신 App Group UserDefaults 에 보류 플래그를 켜두고, 앱이 활성화될 때 소비한다.
//

import WidgetKit
import SwiftUI
import AppIntents

@available(iOS 18.0, *)
struct OpenQuickNoteInboxControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Open ClipKeyboard Inbox"
    static var description = IntentDescription("Open your ClipKeyboard quick note inbox.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // 위젯 프로세스에서 실행 → App Group 플래그만 켜고 앱은 시스템이 열어준다(openAppWhenRun).
        UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?
            .set(true, forKey: "pendingOpenQuickNoteInbox")
        return .result()
    }
}

@available(iOS 18.0, *)
struct QuickNoteInboxControl: ControlWidget {
    static let kind = "com.Ysoup.TokenMemo.QuickNoteInboxControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenQuickNoteInboxControlIntent()) {
                Label("Quick Note", systemImage: "tray.and.arrow.down.fill")
            }
        }
        .displayName("ClipKeyboard Inbox")
        .description("Capture a quick note into your ClipKeyboard inbox.")
    }
}
