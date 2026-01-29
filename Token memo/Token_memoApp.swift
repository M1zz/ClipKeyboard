//
//  Token_memoApp.swift
//  Token memo
//
//  Created by hyunho lee on 2023/05/14.
//

import SwiftUI

@main
struct Token_memoApp: App {
    @ObservedObject var manager = DataManager()

    init() {
        print("🚀 [APP INIT] Token_memoApp 초기화 시작")
        print("📱 [APP INIT] DataManager 생성됨")

        // 앱 실행 횟수 증가
        ReviewManager.shared.incrementAppLaunchCount()

        #if targetEnvironment(macCatalyst)
        setupMacCatalystCommands()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if manager.didShowOnboarding {

                TokenMemoList()
                    .onOpenURL { url in
                        // URL scheme으로 앱이 열렸을 때 처리
                        if url.scheme == "tokenMemo" {
                            // 키보드에서 앱을 열었을 때 메인 화면으로 이동
                            print("🔗 [URL] App opened from keyboard")
                        }
                    }
                    .onAppear() {
                        print("🎯 [APP BODY] 온보딩 완료 상태 -> TokenMemoList 표시")
                    }
            } else {
                // 온보딩
                KeyboardSetupOnboardingView {
                    print("✅ [ONBOARDING] 온보딩 완료 -> didShowOnboarding = true")
                    manager.didShowOnboarding = true
                }
                .onAppear() {
                    print("🎯 [APP BODY] 첫 실행 -> 온보딩 표시")
                }
            }

        }
        #if targetEnvironment(macCatalyst)
        .commands {
            // 클립키보드 전용 메뉴
            CommandMenu("클립키보드") {
                Button("메모 목록") {
                    NotificationCenter.default.post(name: .showMemoList, object: nil)
                }
                .keyboardShortcut("x", modifiers: [.command, .shift])

                Button("새 메모") {
                    NotificationCenter.default.post(name: .showNewMemo, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Divider()

                Button("클립보드 히스토리") {
                    NotificationCenter.default.post(name: .showClipboardHistory, object: nil)
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Divider()

                Button("설정") {
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandGroup(replacing: .help) {
                Button("도움말") {
                    if let url = URL(string: "https://leeo75.notion.site/ClipKeyboard-tutorial-70624fccc524465f99289c89bd0261a4?pvs=4") {
                        #if targetEnvironment(macCatalyst)
                        UIApplication.shared.open(url)
                        #endif
                    }
                }
            }
        }
        #endif
    }

    #if targetEnvironment(macCatalyst)
    private func setupMacCatalystCommands() {
        print("⌨️ [MAC CATALYST] 단축키 설정 완료")

        // 메뉴바 아이콘 설정
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            MenuBarManager.shared.setupMenuBar()
        }

        // 전역 핫키 등록
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            GlobalHotkeyManager.shared.registerGlobalHotkey()
        }
    }
    #endif
}
