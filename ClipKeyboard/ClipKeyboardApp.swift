//
//  ClipKeyboardApp.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/05/14.
//

import SwiftUI
import TipKit
// 키보드 ext에서는 Firebase 미사용 (KEYBOARD_EXTENSION 플래그로 제외)
#if !KEYBOARD_EXTENSION && canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct ClipKeyboardApp: App {
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var deps = AppDependencies.shared
    @State private var showReviewRequest = false
    @State private var showAccessibilityGuide = false
    /// 기존 사용자에게 데모 샘플 체험을 1회 물어보는 알림
    @State private var showDemoSampleOffer = false

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

        // TestFlight 여부 비동기 감지 — isPro 체크 전에 완료되도록 최우선 실행
        Task { await ProFeatureManager.bootstrapIsTestFlight() }

        // v4.0 이전 유료 앱 구매자 그랜드파더 (AppTransaction 영수증 기반).
        // bootstrap_done 1회 가드와 무관하게 매 실행 검증 → 이미 업데이트 후 Pro를 잃은
        // 기존 구매자도 다음 실행에서 자동 복구된다. (이미 부여됐으면 즉시 no-op)
        Task { await ProFeatureManager.grandfatherPaidUserIfNeeded() }

        // DEBUG 빌드에서만 계정/구매 상태 진단 덤프 (Xcode 콘솔에서 "🩺 [Diag]"로 검색)
        #if DEBUG
        Task {
            // TestFlight 감지·그랜드파더 검증이 먼저 끝나도록 잠깐 양보
            await ProFeatureManager.bootstrapIsTestFlight()
            await ProFeatureManager.grandfatherPaidUserIfNeeded()
            await StoreManager.shared.logAccountDiagnostics()
        }
        #endif

        // 앱 실행 횟수 증가
        ReviewManager.shared.incrementAppLaunchCount()

        // v4.0 그랜드파더 플래그 초기화 (최초 1회만 효과 있음, 이후는 no-op)
        bootstrapV4GrandfatherFlags()

        // TipKit 설정 — 온보딩 대신 상황에 맞는 팁으로 안내
        try? Tips.configure([
            .datastoreLocation(.applicationDefault)
        ])

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

    // MARK: - Default Sample Data

    /// 최초 설치 후 온보딩 완료 시 4종(일반 메모·템플릿·콤보·일반메모+템플릿)을 1개씩 삽입한다.
    /// "이런 것도 되는구나"를 첫 화면에서 바로 보여주기 위한 시드 데이터.
    /// UserDefaults 플래그로 중복 삽입을 방지한다(기존 설치 유저에겐 재삽입 안 함).
    private let samplesInsertedKey = "defaultSamplesInserted_v1"
    /// 기존 사용자에게 "체험해 볼래요?"를 이미 물어봤는지(신규 설치는 자동 처리되어 묻지 않음).
    private let demoOfferResolvedKey = "demoSampleOfferResolved_v1"

    /// 현재 페르소나·로케일에 맞는 샘플 4종 + 카테고리 2개를 만들어 저장한다. 성공 여부 반환.
    /// 샘플이 속한 카테고리를 실제로 생성·활성화해 "색 = 카테고리 = 스와이프 페이지"가
    /// 첫 화면에서 일관되게 동작하도록 한다.
    @discardableResult
    private func performSampleInsertion() -> Bool {
        let isKorean = (Locale.current.language.languageCode?.identifier ?? "en") == "ko"
        let persona = CategoryStore.shared.selectedPersona ?? .general
        let result = persona == .nomad ? nomadSamples(isKorean: isKorean) : generalSamples(isKorean: isKorean)
        do {
            var memos = (try? MemoStore.shared.load(type: .memo)) ?? []
            memos.append(contentsOf: result.memos)
            try MemoStore.shared.save(memos: memos, type: .memo)
            SampleMemoStorage.save(ids: result.memos.map { $0.id })
            // 샘플이 속한 카테고리를 실제로 만들고 기능을 켜 → 스와이프 페이지(탭)가 생긴다.
            result.categories.forEach { CategoryStore.shared.add($0) }
            CategoryStore.shared.enableFeature()
            print("✅ [APP INIT] 샘플 \(result.memos.count)개 + 카테고리 \(result.categories.count)개 시드 (persona=\(persona.rawValue))")
            // 시딩 후 리스트가 카테고리/메모를 다시 읽도록 알림 (신규 설치·체험 수락 공통)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .demoSamplesInserted, object: nil)
            }
            return true
        } catch {
            print("❌ [APP INIT] 기본 샘플 삽입 실패: \(error)")
            return false
        }
    }

    /// 신규 설치에서만 자동 삽입. 신규 설치는 데모 질문 대상이 아니므로 resolved로 표시.
    /// 한국어 입력 토글 기본값은 OFF지만, 기존에 키보드 기본 언어를 한국어로 쓰던 사용자는
    /// 토글이 갑자기 사라지지 않도록 1회 자동 활성화한다. (영어 기본 사용자는 OFF 유지 → 한 안 보임)
    private func migrateKoreanEnabledIfNeeded() {
        let g = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")
        guard g?.bool(forKey: "koreanEnabledMigrated_v1") != true else { return }
        if g?.string(forKey: "keyboardTypingLang") == "korean" {
            g?.set(true, forKey: "keyboardKoreanEnabled")
            print("🔄 [APP INIT] 기존 한국어 사용자 — 한국어 입력 자동 활성화")
        }
        g?.set(true, forKey: "koreanEnabledMigrated_v1")
    }

    private func insertDefaultSamplesIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: samplesInsertedKey) else { return }
        if performSampleInsertion() {
            UserDefaults.standard.set(true, forKey: samplesInsertedKey)
            UserDefaults.standard.set(true, forKey: demoOfferResolvedKey)
        }
    }

    /// 이미 설치돼 자동 삽입을 못 받은 기존 사용자에게만 1회 체험을 묻는다.
    private func offerDemoSamplesToExistingUserIfNeeded() {
        guard UserDefaults.standard.bool(forKey: samplesInsertedKey),
              !UserDefaults.standard.bool(forKey: demoOfferResolvedKey) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showDemoSampleOffer = true
        }
    }

    private func generalSamples(isKorean: Bool) -> (memos: [Memo], categories: [String]) {
        let work = isKorean ? "업무" : "Work"
        let personal = isKorean ? "개인" : "Personal"
        // 1) 일반 메모 (즐겨찾기) — 기본 제공되는 즐겨찾기 탭에 바로 들어가 분홍으로 표시
        let memo = Memo(
            title: isKorean ? "내 이메일" : "My Email",
            value: "example@email.com",
            isFavorite: true
        )
        // 2) 템플릿 — {빈칸}을 채워 완성
        let template = Memo(
            title: isKorean ? "회신 템플릿" : "Reply Template",
            value: isKorean
                ? "{이름}님, 문의 주셔서 감사합니다.\n{날짜}까지 답변드릴게요."
                : "Hi {name}, thanks for reaching out.\nI'll reply by {date}.",
            category: work,
            isTemplate: true
        )
        // 3) 콤보 — 여러 값을 순서대로 입력
        let combo = Memo(
            title: isKorean ? "이름 + 연락처" : "Name + Contact",
            value: "",
            category: personal,
            isCombo: true,
            comboValues: isKorean ? ["홍길동", "010-0000-0000"] : ["John Doe", "555-0000"]
        )
        // 4) 일반 메모 + 템플릿 — 고정 인사말 뒤에 템플릿 빈칸이 함께 채워짐
        let memoWithTemplate = Memo(
            title: isKorean ? "인사말 + 회신 (탭)" : "Greeting + Reply (tap)",
            value: isKorean ? "안녕하세요, 연락 주셔서 반갑습니다!" : "Hi, great to hear from you!",
            category: work,
            attachedTemplateId: template.id
        )
        return ([memo, template, combo, memoWithTemplate], [work, personal])
    }

    private func nomadSamples(isKorean: Bool) -> (memos: [Memo], categories: [String]) {
        let finance = isKorean ? "금융" : "Finance"
        let travel = isKorean ? "여행" : "Travel"
        let template = Memo(
            title: isKorean ? "국제 송금 양식" : "Bank Transfer",
            value: isKorean
                ? "{금액}을 {수신인}에게 보냅니다\nIBAN: {iban}\nSWIFT: {swift}\n참조: {참조번호}"
                : "Pay {amount} to {recipient}\nIBAN: {iban}\nSWIFT: {swift}\nRef: {reference}",
            category: finance,
            isTemplate: true
        )
        let combo = Memo(
            title: isKorean ? "내 연락처" : "My Contact",
            value: "",
            category: travel,
            isCombo: true,
            comboValues: isKorean
                ? ["이름", "이메일", "전화번호"]
                : ["Full Name", "Email", "Phone"]
        )
        // 즐겨찾기 — 기본 제공되는 즐겨찾기 탭에 바로 들어가 분홍으로 표시
        let checklist = Memo(
            title: isKorean ? "여행 체크리스트" : "Travel Checklist",
            value: isKorean
                ? "여권 ✓\n비자 ✓\n여행자보험 ✓\n긴급 연락처: "
                : "Passport ✓\nVisa ✓\nTravel Insurance ✓\nEmergency Contact: ",
            isFavorite: true
        )
        // 일반 메모 + 템플릿 — 고정 안내문 뒤에 송금 양식 빈칸이 함께 채워짐
        let noteWithTemplate = Memo(
            title: isKorean ? "송금 안내 + 양식 (탭)" : "Payment note + form (tap)",
            value: isKorean ? "아래 계좌로 송금 부탁드립니다." : "Please send payment to the account below.",
            category: finance,
            attachedTemplateId: template.id
        )
        return ([template, combo, checklist, noteWithTemplate], [finance, travel])
    }

    var body: some Scene {
        WindowGroup {
            AppThemedContainer {
            ClipKeyboardList()
                .environmentObject(storeManager)
                .environmentObject(deps)
                #if targetEnvironment(macCatalyst)
                .frame(minWidth: 520, minHeight: 640)
                #endif
                .onOpenURL { url in
                    handleOpenURL(url)
                }
                .onAppear {
                    migrateKoreanEnabledIfNeeded()
                    insertDefaultSamplesIfNeeded()
                    offerDemoSamplesToExistingUserIfNeeded()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        // 데모 체험 질문이 떠 있으면 리뷰 요청은 양보 (모달 중첩 방지)
                        if !showDemoSampleOffer, ReviewManager.shared.shouldShowReview() {
                            showReviewRequest = true
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        checkVoiceOverAndNudge()
                    }
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIAccessibility.voiceOverStatusDidChangeNotification
                    )
                ) { _ in
                    checkVoiceOverAndNudge()
                }
                .sheet(isPresented: $showReviewRequest) {
                    ReviewRequestView()
                        .presentationDetents([.medium])
                }
                .sheet(isPresented: $showAccessibilityGuide) {
                    AccessibilityGuideView()
                }
                .alert(
                    NSLocalizedString("이런 기능도 있어요", comment: "Demo samples offer title"),
                    isPresented: $showDemoSampleOffer
                ) {
                    Button(NSLocalizedString("체험해 보기", comment: "Demo samples offer accept")) {
                        // performSampleInsertion 내부에서 .demoSamplesInserted 알림을 발행해 리스트가 갱신됨
                        performSampleInsertion()
                        UserDefaults.standard.set(true, forKey: demoOfferResolvedKey)
                    }
                    Button(NSLocalizedString("괜찮아요", comment: "Demo samples offer decline"), role: .cancel) {
                        UserDefaults.standard.set(true, forKey: demoOfferResolvedKey)
                    }
                } message: {
                    Text(NSLocalizedString("템플릿·콤보·메모+템플릿 예시 4개를 추가해 직접 써볼 수 있어요. 기존 메모는 그대로 유지돼요.", comment: "Demo samples offer message"))
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

    // MARK: - Accessibility Nudge

    /// VoiceOver가 켜진 상태로 앱에 진입하면 최초 1회 접근성 안내 시트를 띄운다.
    private func checkVoiceOverAndNudge() {
        #if os(iOS)
        let nudgeKey = "a11y_guide_nudge_shown_v1"
        guard UIAccessibility.isVoiceOverRunning,
              !(UserDefaults.standard.bool(forKey: nudgeKey)) else { return }
        UserDefaults.standard.set(true, forKey: nudgeKey)
        // 리뷰 시트와 겹치지 않도록 약간 지연
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showAccessibilityGuide = true
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
