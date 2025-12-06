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
            } else if !manager.didShowUseCaseSelection {
                // 새로운 사용 사례 선택 온보딩
                UseCaseSelectionView {
                    print("✅ [USE CASE] 사용 사례 선택 완료")
                    manager.didShowUseCaseSelection = true
                }
                .onAppear() {
                    print("🎯 [APP BODY] 첫 실행 -> 사용 사례 선택 화면 표시")
                }
            } else {
                // 기존 키보드 설정 온보딩
                ColorfulOnboardingView(pages: OnboardingPages) {
                    print("✅ [ONBOARDING] 온보딩 완료 -> didShowOnboarding = true")
                    manager.didShowOnboarding = true
                }
                .onAppear() {
                    print("🎯 [APP BODY] 사용 사례 선택 후 -> 키보드 설정 온보딩 표시")
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

    /// Onboarding pages
    private var OnboardingPages: [ColorfulOnboardingView.PageDetails] {
        [
            .init(imageName: "step1", title: "Enable Keyboard", subtitle: "Go to Settings -> General -> Keyboard -> Keyboards then tap 'Add New Keyboard...' and select 'Token Memo'", color: Color(#colorLiteral(red: 0.4534527972, green: 0.5727163462, blue: 1, alpha: 1))),
            .init(imageName: "step2", title: "Allow full access", subtitle: "Allow Full Access to fully use the copy function!", color: Color(#colorLiteral(red: 0.4534527972, green: 0.7018411277, blue: 0.06370192308, alpha: 1))),
            .init(imageName: "step3", title: "Add your Text", subtitle: "In the Token Memo app, tap the '+' button to add your own text/phrase. To delete any added text, you can swipe left to delete.", color: Color(#colorLiteral(red: 0.9011964598, green: 0.5727163462, blue: 0, alpha: 1))),
            .init(imageName: "step4", title: "Use the Keyboard", subtitle: "In the messages app, email or any other app, you can tap the 'globe' icon to switch between keyboards. Enjoy!", color: Color(#colorLiteral(red: 0.9098039269, green: 0.4784313738, blue: 0.6431372762, alpha: 1)))
        ]
    }
}
