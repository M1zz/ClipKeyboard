//
//  ClipKeyboardApp.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/05/14.
//

import SwiftUI
// 키보드 ext에서는 Firebase 미사용 (KEYBOARD_EXTENSION 플래그로 제외)
#if !KEYBOARD_EXTENSION && canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct ClipKeyboardApp: App {
    @ObservedObject var manager = DataManager()
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var deps = AppDependencies.shared
    @State private var showReviewRequest = false

    init() {
        print("🚀 [APP INIT] ClipKeyboardApp 초기화 시작")
        print("📱 [APP INIT] DataManager 생성됨")

        // Firebase 초기화 — GoogleService-Info.plist 자동 로드
        // Analytics 데이터 수집 여부는 Firebase Console 설정에 따름
        #if !KEYBOARD_EXTENSION && canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("🔥 [APP INIT] FirebaseApp 초기화 완료")
        }
        #endif

        // 키보드 익스텐션이 App Group에 기록한 사용 비콘을 Firebase로 보냄
        AnalyticsService.flushKeyboardBeacon()

        // 백그라운드 새로고침 task 등록 — 메인 앱이 안 열려도 주기적으로 비콘 flush
        // (키보드만 쓰는 유저의 DAU 추적용)
        BeaconBackgroundScheduler.registerAndScheduleIfNeeded()

        // 앱 실행 횟수 증가
        ReviewManager.shared.incrementAppLaunchCount()

        // v4.0 그랜드파더 플래그 초기화 (최초 1회만 효과 있음, 이후는 no-op)
        bootstrapV4GrandfatherFlags()

        #if targetEnvironment(macCatalyst)
        setupMacCatalystCommands()
        #endif
    }

    /// v3.x → v4.0 업그레이드 유저에게 그랜드파더 상태를 부여한다.
    /// - Pro 구매 이력 있으면 영구 unlock
    /// - 메모를 하나라도 보유했다면 기존 무료 유저로 기록 (키보드 익스텐션 접근 유지)
    /// - 메모가 새 freeMemoLimit 초과면 grace 플래그
    private func bootstrapV4GrandfatherFlags() {
        // 이미 한 번 초기화됐으면 skip
        let defaults = UserDefaults(suiteName: ProFeatureManager.appGroupSuite)
        let initKey = "clipkeyboard_v4_grandfather_bootstrap_done"
        if defaults?.bool(forKey: initKey) == true { return }

        let currentMemoCount: Int
        if let memos = try? MemoStore.shared.load(type: .memo) {
            currentMemoCount = memos.count
        } else {
            currentMemoCount = 0
        }

        ProStatusManager.shared.bootstrapV4GrandfatherFlags(
            existingMemoCount: currentMemoCount,
            isProNow: ProFeatureManager.isPro
        )

        defaults?.set(true, forKey: initKey)
        print("✅ [APP INIT] v4.0 그랜드파더 부트스트랩 완료 (memos=\(currentMemoCount), isPro=\(ProFeatureManager.isPro))")
    }

    var body: some Scene {
        WindowGroup {
            AppThemedContainer {
            if manager.didShowOnboarding && manager.didShowUseCaseSelection {

                ClipKeyboardList()
                    .environmentObject(storeManager)
                    .environmentObject(deps)
                    #if targetEnvironment(macCatalyst)
                    .frame(minWidth: 520, minHeight: 640)
                    #endif
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
            } else if !manager.didShowOnboarding {
                // 1단계: 키보드 셋업 온보딩
                KeyboardSetupOnboardingView {
                    print("✅ [ONBOARDING] 키보드 온보딩 완료 -> 페르소나 선택으로")
                    manager.didShowOnboarding = true
                }
                #if targetEnvironment(macCatalyst)
                .frame(minWidth: 520, minHeight: 640)
                #endif
                .onAppear() {
                    print("🎯 [APP BODY] 첫 실행 -> 키보드 온보딩 표시")
                }
            } else {
                // 2단계: 페르소나 선택 → 카테고리 선제 시드
                PersonaSelectionView {
                    print("✅ [ONBOARDING] 페르소나 선택 완료 -> 메인 진입")
                    manager.didShowUseCaseSelection = true
                }
                #if targetEnvironment(macCatalyst)
                .frame(minWidth: 520, minHeight: 640)
                #endif
                .onAppear() {
                    print("🎯 [APP BODY] 페르소나 선택 화면 표시")
                }
            }
            } // AppThemedContainer

        }
        #if targetEnvironment(macCatalyst)
        .defaultSize(width: 620, height: 780)
        #endif
        #if targetEnvironment(macCatalyst)
        .commands {
            // 클립키보드 전용 메뉴
            // v4.2: ⌃⇧ (Control+Shift) + 영문자 3-key 조합으로 통일.
            // Mac에서 Control+Shift 계열 단축키는 거의 표준 바인딩이 없어
            // 타 유틸(Raycast/Maccy/Alfred 등)과 충돌 가능성이 낮음.
            CommandMenu(NSLocalizedString("ClipKeyboard", comment: "App menu name")) {
                Button(NSLocalizedString("Memo List", comment: "Menu: memo list")) {
                    NotificationCenter.default.post(name: .showMemoList, object: nil)
                }
                .keyboardShortcut("m", modifiers: [.control, .shift])

                Button(NSLocalizedString("New Memo", comment: "Menu: new memo")) {
                    NotificationCenter.default.post(name: .showNewMemo, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.control, .shift])

                Divider()

                Button(NSLocalizedString("Clipboard History", comment: "Menu: clipboard history")) {
                    NotificationCenter.default.post(name: .showClipboardHistory, object: nil)
                }
                .keyboardShortcut("h", modifiers: [.control, .shift])

                Button(NSLocalizedString("Paywall", comment: "Menu: paywall")) {
                    NotificationCenter.default.post(name: .showPaywall, object: nil)
                }

                Divider()

                Button(NSLocalizedString("Preferences…", comment: "Menu: preferences")) {
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandGroup(replacing: .help) {
                Button(NSLocalizedString("ClipKeyboard Help", comment: "Menu: help")) {
                    if let url = URL(string: "https://m1zz.github.io/ClipKeyboard/tutorial.html") {
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
        } else if url.host == "paywall" {
            // 키보드 익스텐션에서 paywall 직행 요청 (v4.0)
            NotificationCenter.default.post(name: .showPaywall, object: nil)
        }
    }

    private func copyMemoToClipboard(memoId: UUID) {
        let store = MemoStore.shared
        if store.memos.isEmpty {
            try? store.memos = store.load(type: .memo)
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
