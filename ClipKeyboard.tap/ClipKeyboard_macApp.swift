//
//  ClipKeyboard_macApp.swift
//  ClipKeyboard.tap
//
//  Created by hyunho lee on 11/28/25.
//

import SwiftUI

@main
struct ClipKeyboard_macApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            // 클립키보드 전용 메뉴
            CommandMenu("클립키보드") {
                Button("메모 목록") {
                    NotificationCenter.default.post(name: .showMemoList, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.control, .option])

                Button("새 메모") {
                    NotificationCenter.default.post(name: .showNewMemo, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.control, .option])

                Divider()

                Button("클립보드 히스토리") {
                    NotificationCenter.default.post(name: .showClipboardHistory, object: nil)
                }
                .keyboardShortcut("h", modifiers: [.control, .option])

                Divider()

                Button("iCloud 백업") {
                    NotificationCenter.default.post(name: .showCloudBackup, object: nil)
                }
                .keyboardShortcut("b", modifiers: [.control, .option])

                Button("설정") {
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandGroup(replacing: .help) {
                Button("온보딩 다시 보기") {
                    WindowManager.shared.openOnboardingWindow()
                }

                Button("도움말") {
                    if let url = URL(string: "https://leeo75.notion.site/ClipKeyboard-tutorial-70624fccc524465f99289c89bd0261a4?pvs=4") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}

// App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 [APP] ClipKeyboard 시작")

        // 기본 창 숨기기 (메뉴바 앱으로 동작)
        NSApp.setActivationPolicy(.accessory)

        // 메뉴바 아이콘 설정
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            MenuBarManager.shared.setupMenuBar()
        }

        // 전역 핫키 등록
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            GlobalHotkeyManager.shared.registerGlobalHotkey()
        }

        // WindowManager 초기화 (알림 리스너 등록)
        _ = WindowManager.shared

        // 클립보드 모니터링 시작
        ClipboardMonitorService.shared.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("🛑 [APP] 앱 종료 중...")

        // 클립보드 모니터링 중지
        ClipboardMonitorService.shared.stopMonitoring()

        // 메인 스레드에서 동기적으로 핫키 해제
        if Thread.isMainThread {
            GlobalHotkeyManager.shared.unregisterGlobalHotkey()
        } else {
            DispatchQueue.main.sync {
                GlobalHotkeyManager.shared.unregisterGlobalHotkey()
            }
        }

        print("✅ [APP] 정리 작업 완료")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 창을 닫아도 앱은 계속 실행 (메뉴바 앱처럼 동작)
        return false
    }
}
