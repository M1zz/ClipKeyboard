//
//  DirectPasteHelper.swift
//  ClipKeyboard.tap
//
//  Simulates ⌘V to paste the current clipboard into the frontmost app.
//  Requires Accessibility permission (handled separately via AXIsProcessTrustedWithOptions).
//

import AppKit
import Carbon.HIToolbox

enum DirectPasteHelper {

    /// 전경 앱으로 ⌘V keystroke를 발사한다.
    /// - 주의: Accessibility 권한이 없으면 조용히 실패.
    static func pasteToFrontmostApp() {
        guard hasAccessibilityPermission() else {
            print("⚠️ [Paste] Accessibility 권한 없음 — 직접 붙여넣기 생략")
            return
        }

        // ⌘V down/up
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = CGKeyCode(kVK_ANSI_V)

        let down = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)

        print("📋 [Paste] ⌘V 전송 완료")
    }

    static func hasAccessibilityPermission() -> Bool {
        // prompt=false: 권한 확인만 하고 시스템 prompt는 띄우지 않음
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// 권한 요청 시스템 대화상자를 띄운다 (Preferences에서 "Grant Access" 버튼 눌렀을 때).
    @discardableResult
    static func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
