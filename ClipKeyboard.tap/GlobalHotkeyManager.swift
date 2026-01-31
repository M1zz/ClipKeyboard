//
//  GlobalHotkeyManager.swift
//  TokenMemo.tap
//
//  Created by Claude on 2025-11-28.
//

import AppKit
import Carbon

class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private init() {}

    private func checkAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        if accessEnabled {
            print("✅ [Global Hotkey] 접근성 권한이 허용되어 있습니다")
        } else {
            print("⚠️ [Global Hotkey] 접근성 권한이 필요합니다!")
            print("💡 시스템 설정 > 개인 정보 보호 및 보안 > 손쉬운 사용 에서 ClipKeyboard를 활성화하세요")

            // 접근성 설정 열기
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let alert = NSAlert()
                alert.messageText = "접근성 권한 필요"
                alert.informativeText = "전역 단축키를 사용하려면 접근성 권한이 필요합니다.\n\n시스템 설정 > 개인 정보 보호 및 보안 > 손쉬운 사용 에서 ClipKeyboard를 활성화하세요."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "시스템 설정 열기")
                alert.addButton(withTitle: "나중에")

                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }

    func registerGlobalHotkey() {
        // 접근성 권한 확인
        checkAccessibilityPermission()

        // Control + Option + K (^⌥K)
        let keyCode: UInt32 = 40 // K key
        let modifiers: UInt32 = UInt32(controlKey | optionKey)

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(("T" as Character).asciiValue! << 24 |
                                    ("M" as Character).asciiValue! << 16 |
                                    ("H" as Character).asciiValue! << 8 |
                                    ("K" as Character).asciiValue!)
        hotKeyID.id = 1

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)

        // 이벤트 핸들러 등록
        let handler: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            print("🔥 [Global Hotkey] Control+Option+K 전역 단축키 감지!")

            // 메인 스레드에서 앱 활성화
            DispatchQueue.main.async {
                GlobalHotkeyManager.shared.activateApp()
            }

            return noErr
        }

        var handlerRef: EventHandlerRef?
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &handlerRef
        )

        if installStatus == noErr {
            self.eventHandler = handlerRef
            print("✅ [Global Hotkey] 이벤트 핸들러 등록 성공")
        } else {
            print("❌ [Global Hotkey] 이벤트 핸들러 등록 실패: \(installStatus)")
            return
        }

        // 핫키 등록
        var hotKeyRefVar: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefVar
        )

        if status == noErr {
            self.hotKeyRef = hotKeyRefVar
            print("✅ [Global Hotkey] 전역 단축키 등록 성공 (^⌥K)")
            print("💡 [Global Hotkey] 이제 어디서나 ^⌥K를 눌러 앱을 활성화할 수 있습니다!")
        } else {
            print("❌ [Global Hotkey] 전역 단축키 등록 실패: \(status)")
        }
    }

    func unregisterGlobalHotkey() {
        // 핫키를 먼저 해제
        if let hotKeyRef = hotKeyRef {
            let status = UnregisterEventHotKey(hotKeyRef)
            if status == noErr {
                print("🔓 [Global Hotkey] 전역 단축키 해제 성공")
            } else {
                print("⚠️ [Global Hotkey] 전역 단축키 해제 실패: \(status)")
            }
            self.hotKeyRef = nil
        }

        // 이벤트 핸들러 해제
        if let eventHandler = eventHandler {
            let status = RemoveEventHandler(eventHandler)
            if status == noErr {
                print("🔓 [Global Hotkey] 이벤트 핸들러 해제 성공")
            } else {
                print("⚠️ [Global Hotkey] 이벤트 핸들러 해제 실패: \(status)")
            }
            self.eventHandler = nil
        }
    }

    private func activateApp() {
        // 메모 목록 윈도우 열기
        NotificationCenter.default.post(name: .openMemoListWindow, object: nil)

        print("✅ [Global Hotkey] 메모 목록 윈도우 열기")
    }

    deinit {
        unregisterGlobalHotkey()
    }
}

