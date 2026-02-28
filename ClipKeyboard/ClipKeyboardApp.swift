//
//  ClipKeyboardApp.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/05/14.
//

import SwiftUI

@main
struct ClipKeyboardApp: App {
    @ObservedObject var manager = DataManager()
    @StateObject private var storeManager = StoreManager.shared
    @State private var showReviewRequest = false

    init() {
        print("🚀 [APP INIT] ClipKeyboardApp 초기화 시작")
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

                ClipKeyboardList()
                    .environmentObject(storeManager)
                    .onOpenURL { url in
                        handleOpenURL(url)
                    }
                    .onAppear() {
                        print("🎯 [APP BODY] 온보딩 완료 상태 -> ClipKeyboardList 표시")

                        // 리뷰 요청 체크 (1초 지연)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            if ReviewManager.shared.shouldShowReview() {
                                showReviewRequest = true
                            }
                        }
                    }
                    .sheet(isPresented: $showReviewRequest) {
                        ReviewRequestView()
                            .presentationDetents([.medium])
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
                Button(NSLocalizedString("도움말", comment: "Help")) {
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

    // MARK: - URL Scheme Handler

    private func handleOpenURL(_ url: URL) {
        guard url.scheme == "clipkeyboard" else { return }
        print("🔗 [URL] App opened with URL: \(url)")

        if url.host == "copy", let idString = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "id" })?.value,
           let memoId = UUID(uuidString: idString) {
            // 위젯에서 메모 복사 요청
            copyMemoToClipboard(memoId: memoId)
        }
    }

    private func copyMemoToClipboard(memoId: UUID) {
        let store = MemoStore.shared
        if store.memos.isEmpty {
            try? store.memos = store.load(type: .tokenMemo)
        }

        guard let memo = store.memos.first(where: { $0.id == memoId }) else {
            print("⚠️ [Widget Copy] 메모를 찾을 수 없음: \(memoId)")
            return
        }

        #if os(iOS)
        UIPasteboard.general.string = memo.value
        print("✅ [Widget Copy] 클립보드에 복사됨: \(memo.title)")

        // 복사 완료 햅틱 피드백
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
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
