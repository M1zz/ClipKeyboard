//
//  QuickNoteAppIntents.swift
//  ClipKeyboard
//
//  빠른 메모(Inbox) 캡처를 위한 App Intents — Shortcuts·Siri·액션 버튼·Spotlight 어디서든
//  앱을 켜지 않고 보관함에 던져 넣을 수 있게 한다(애플 "빠른 메모"의 시스템-전역 캡처에 대응).
//

import AppIntents
import Foundation

// MARK: - Add Quick Note (background capture)

/// 텍스트를 받아 보관함에 추가하는 인텐트. 앱을 띄우지 않고 백그라운드에서 실행된다.
struct AddQuickNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Quick Note"
    static var description = IntentDescription("Quickly capture text into your ClipKeyboard inbox to decide later whether to keep it as a keyboard memo.")
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Note",
        description: "The text to capture.",
        requestValueDialog: "What do you want to capture?"
    )
    var text: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "Nothing to save.")
        }
        QuickNoteStore.shared.add(QuickNote(text: trimmed, source: "shortcut"))
        return .result(dialog: "Saved to your ClipKeyboard inbox.")
    }
}

// MARK: - Open Inbox (foreground)

/// 보관함 화면을 바로 여는 인텐트(Control Center 버튼·액션 버튼에서 "받은편지함 열기"용).
struct OpenQuickNoteInboxIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Inbox"
    static var description = IntentDescription("Open the ClipKeyboard inbox of quick notes.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .openQuickNoteInbox, object: nil)
        return .result()
    }
}

// MARK: - App Shortcuts

struct ClipKeyboardAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddQuickNoteIntent(),
            phrases: [
                "Add a quick note to \(.applicationName)",
                "Save to \(.applicationName) inbox",
                "New quick note in \(.applicationName)"
            ],
            shortTitle: "Add Quick Note",
            systemImageName: "tray.and.arrow.down.fill"
        )
        AppShortcut(
            intent: OpenQuickNoteInboxIntent(),
            phrases: [
                "Open \(.applicationName) inbox"
            ],
            shortTitle: "Open Inbox",
            systemImageName: "tray.full"
        )
    }
}
