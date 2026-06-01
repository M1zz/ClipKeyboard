//
//  SettingView.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/06/05.
//

import SwiftUI
import StoreKit

struct SettingView: View {
    
    @Environment(\.requestReview) var requestReview
    @Environment(\.appTheme) private var theme
    @ObservedObject private var proManager = StoreManager.shared
    @State private var showPaywall = false
    @State private var showKeyboardGuide = false
    @State private var securePINSet = false

    private func refreshSecurePINState() {
        let hash = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.string(forKey: "keyboard_secure_pin_hash") ?? ""
        securePINSet = !hash.isEmpty
    }

    var body: some View {
        List {

            // MARK: Pro 상태
            // StoreManager.isPro(결제 entitlement만)가 아니라 hasPermanentPro를 본다.
            // → 그랜드파더/TestFlight 유저도 "Pro 활성화됨"으로 올바르게 표시 (업그레이드 안내 X)
            if ProFeatureManager.hasPermanentPro {
                Section {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("Pro 활성화됨", comment: "Pro activated"))
                            .font(.headline)
                        Spacer()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(NSLocalizedString("Pro 활성화됨", comment: "Pro activated"))
                }
            } else if ProFeatureManager.isInTrial {
                Section {
                    Button { showPaywall = true } label: {
                        HStack {
                            Image(systemName: "clock.badge.checkmark.fill")
                                .font(.title2)
                                .foregroundStyle(.green.gradient)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: NSLocalizedString("체험 활성 — %d일 남음", comment: "Trial active days remaining"), ProFeatureManager.trialDaysRemaining))
                                    .font(.headline).foregroundColor(.primary)
                                Text(NSLocalizedString("지금 Pro로 업그레이드하면 평생 사용", comment: "Trial upsell"))
                                    .font(.body).foregroundColor(theme.textMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.body)
                                .foregroundColor(theme.textMuted).accessibilityHidden(true)
                        }
                    }
                    .accessibilityHint(NSLocalizedString("Pro 업그레이드 화면을 엽니다", comment: "Open paywall hint"))

                    Button {
                        Task { await proManager.restorePurchases() }
                    } label: {
                        Label(NSLocalizedString("이전 구매 복원", comment: "Restore"), systemImage: "arrow.clockwise")
                            .foregroundStyle(Color.secondary)
                    }
                    .disabled(proManager.isLoading)
                    .accessibilityLabel(NSLocalizedString("이전 구매 복원", comment: "Restore"))
                    .accessibilityHint(NSLocalizedString("이전에 구매한 Pro를 복원합니다", comment: "Restore purchases accessibility hint"))
                }
            } else {
                Section {
                    Button { showPaywall = true } label: {
                        HStack {
                            Image(systemName: "star.circle.fill")
                                .font(.title2)
                                .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("Pro 업그레이드", comment: "Pro upgrade"))
                                    .font(.headline).foregroundColor(.primary)
                                Text(ProFeatureManager.canStartTrial
                                     ? String(format: NSLocalizedString("%d일 무료 체험 + 무제한 메모, iCloud 백업", comment: "Pro features w/ trial"), ProFeatureManager.trialDurationDays)
                                     : NSLocalizedString("무제한 메모, iCloud 백업 등", comment: "Pro features"))
                                    .font(.body).foregroundColor(theme.textMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.body)
                                .foregroundColor(theme.textMuted).accessibilityHidden(true)
                        }
                    }
                    .accessibilityHint(NSLocalizedString("Pro 업그레이드 화면을 엽니다", comment: "Open paywall hint"))

                    Button {
                        Task { await proManager.restorePurchases() }
                    } label: {
                        Label(NSLocalizedString("이전 구매 복원", comment: "Restore"), systemImage: "arrow.clockwise")
                            .foregroundStyle(Color.secondary)
                    }
                    .disabled(proManager.isLoading)
                    .accessibilityLabel(NSLocalizedString("이전 구매 복원", comment: "Restore"))
                    .accessibilityHint(NSLocalizedString("이전에 구매한 Pro를 복원합니다", comment: "Restore purchases accessibility hint"))
                }
            }

            // MARK: 키보드 (선택 기능)
            // iOS 설정 > 일반 > 키보드에서 ClipKeyboard를 추가한 사용자를 위한 설정
            Section(header: VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("키보드", comment: "Settings section: keyboard"))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
                    .textCase(.uppercase)
                Text(NSLocalizedString("iOS 설정 > 일반 > 키보드에서 추가할 수 있어요", comment: "Keyboard optional section footer"))
                    .font(.caption2)
                    .foregroundColor(theme.textFaint)
                    .textCase(.none)
            }) {
                // 시트 버튼 — Label 텍스트에 .primary를 명시해 파란색 tint 방지
                Button {
                    HapticManager.shared.light()
                    showKeyboardGuide = true
                } label: {
                    HStack {
                        Label {
                            Text(NSLocalizedString("키보드 설정 가이드", comment: "Keyboard setup guide"))
                                .foregroundStyle(Color.primary)
                        } icon: {
                            Image(systemName: "keyboard.badge.eye")
                        }
                        Spacer()
                        // 시스템 디스클로저 인디케이터와 동일한 톤·크기로 맞춤
                        // (형제 NavigationLink 행들의 기본 chevron과 일치시키기 위함)
                        Image(systemName: "chevron.forward")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityHint(NSLocalizedString("단계별 키보드 설정 가이드를 엽니다", comment: "Open keyboard setup guide hint"))

                NavigationLink(destination: KeyboardPracticeView()) {
                    Label(NSLocalizedString("키보드 연습하기", comment: "Keyboard practice settings entry"),
                          systemImage: "hand.tap")
                }
                NavigationLink(destination: KeyboardLayoutSettings()) {
                    Label(NSLocalizedString("키보드 레이아웃", comment: "Keyboard layout"),
                          systemImage: "rectangle.3.group")
                }
            }

            // MARK: 개인화
            // 사용자가 취향에 맞게 바꾸는 값
            Section(NSLocalizedString("개인화", comment: "Settings section: personalization")) {
                NavigationLink(destination: PersonaSettingsContainer()) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("페르소나", comment: "Persona setting row title"))
                            if let p = CategoryStore.shared.selectedPersona {
                                Text(p.localizedTitle)
                                    .font(.body)
                                    .foregroundColor(theme.textMuted)
                            }
                        }
                    } icon: {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                    }
                }
            }

            // MARK: 카테고리 (메모 표시)
            // 앱 테마/화면 모드는 제거 — 앱은 Paper + 시스템 라이트/다크를 따름.
            Section(NSLocalizedString("카테고리", comment: "Settings section: category")) {
                // 카테고리 관리 — 추가/이름변경/색상/표시 토글 (설정 페이지 안으로 통합)
                NavigationLink(destination: CategorySettings()) {
                    Label(NSLocalizedString("카테고리 관리", comment: "Manage categories settings entry"),
                          systemImage: "folder.badge.gearshape")
                }
                // 카테고리 심볼 — 카드 우상단에 카테고리 심볼 표시 켜고 끄기
                NavigationLink(destination: CategoryBadgeSettingsView()) {
                    Label(NSLocalizedString("카테고리 심볼", comment: "Settings: show category symbol on cards"),
                          systemImage: "tag.circle.fill")
                }
                // 카테고리 아이콘은 메모·키보드 양쪽에서 쓰는 공용 설정
                NavigationLink(destination: CategoryIconSettings()) {
                    Label(NSLocalizedString("카테고리 아이콘", comment: "Category icon settings"),
                          systemImage: "square.grid.2x2.fill")
                }
            }

            // MARK: 데이터 & 보안
            // 실제 앱 동작에 영향을 주는 설정
            Section(NSLocalizedString("데이터 & 보안", comment: "Settings section: data and security")) {
                NavigationLink(destination: CloudBackupView()) {
                    Label(NSLocalizedString("백업 및 복원", comment: "Backup and restore"),
                          systemImage: "icloud.and.arrow.up")
                }
                NavigationLink(destination: SecurePINSettings()) {
                    HStack {
                        Label(NSLocalizedString("보안 메모 PIN", comment: "Secure memo PIN"),
                              systemImage: "lock.shield")
                        Spacer()
                        Text(securePINSet
                             ? NSLocalizedString("설정됨", comment: "PIN is set")
                             : NSLocalizedString("없음", comment: "PIN not set / none"))
                            .foregroundColor(theme.textMuted).font(.body)
                    }
                }
                NavigationLink(destination: CopyPasteView()) {
                    Label(NSLocalizedString("붙여넣기 알림 설정", comment: "Paste notification settings title"),
                          systemImage: "doc.on.clipboard")
                }
            }

            // MARK: 도움말
            // 사용법 안내 및 정보 전달
            Section(NSLocalizedString("도움말", comment: "Settings section: help")) {
                NavigationLink(destination: UsageGuideView()) {
                    Label(NSLocalizedString("활용 사례", comment: "Use cases / usage scenarios"),
                          systemImage: "lightbulb")
                }
                NavigationLink(destination: TutorialView()) {
                    Label(NSLocalizedString("사용 가이드", comment: "User guide"),
                          systemImage: "book.closed")
                }
                NavigationLink(destination: AccessibilityGuideView()) {
                    Label(NSLocalizedString("손쉬운 사용", comment: "Accessibility guide settings entry"),
                          systemImage: "figure.walk.circle")
                }
            }

            // MARK: 지원
            // 리뷰 및 개발자 소통
            Section(NSLocalizedString("지원", comment: "Settings section: support")) {
                NavigationLink(destination: ReviewWriteView()) {
                    Label(NSLocalizedString("리뷰 남기기", comment: "Leave review"),
                          systemImage: "star")
                }
                NavigationLink(destination: FeedbackView()) {
                    Label(NSLocalizedString("피드백 보내기", comment: "Send feedback settings entry"),
                          systemImage: "envelope.badge")
                }
            }

            // MARK: 다른 기기에서 사용 (iOS 전용)
            #if !targetEnvironment(macCatalyst)
            Section(NSLocalizedString("다른 기기에서 사용", comment: "Cross-device section")) {
                NavigationLink(destination: MacAppIntroView()) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: theme.radiusSm)
                                .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 32, height: 32)
                            Image(systemName: "macbook")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.white)
                                .accessibilityHidden(true)
                        }
                        .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("ClipKeyboard for Mac", comment: "Mac app intro title"))
                                .font(.body).fontWeight(.semibold)
                            Text(NSLocalizedString("Menu bar access · Global hotkey · iCloud sync", comment: "Mac promo subtitle"))
                                .font(.body).foregroundColor(theme.textMuted)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            #endif

            // MARK: 앱 정보
            Section(NSLocalizedString("앱 정보", comment: "App info section")) {
                HStack {
                    Text(NSLocalizedString("버전", comment: "Version label"))
                        .foregroundColor(theme.textMuted)
                    Spacer()
                    Text(appVersion).foregroundColor(.primary)
                }
            }
        }
        .navigationTitle(NSLocalizedString("설정", comment: "Settings nav title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshSecurePINState() }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.bg.ignoresSafeArea())
        .contentMargins(.top, 16, for: .scrollContent)
        .contentMargins(.bottom, 24, for: .scrollContent)
        .toolbarBackground(theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showKeyboardGuide) {
            KeyboardSetupOnboardingView { showKeyboardGuide = false }
                .presentationDetents([.large])
        }
    }

    // 앱 버전 정보를 Info.plist에서 자동으로 가져오기
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
}

// MARK: - Category Badge Settings

/// '카테고리 색상 배지' 토글 + 설명 + 켜짐/꺼짐 미리보기.
struct CategoryBadgeSettingsView: View {
    @Environment(\.appTheme) private var theme
    @State private var visible = UserDefaults.standard.object(forKey: "categoryBadgeVisible") as? Bool ?? true

    var body: some View {
        List {
            Section {
                Toggle(isOn: $visible) {
                    Label(NSLocalizedString("카테고리 심볼", comment: "Category symbol"), systemImage: "tag.circle.fill")
                }
                .onChange(of: visible) { _, v in
                    UserDefaults.standard.set(v, forKey: "categoryBadgeVisible")
                }
            } footer: {
                Text(NSLocalizedString("메모 카드 오른쪽 위에 그 메모가 속한 카테고리를 색과 심볼로 표시해요. 색맹이어도 심볼로 구분할 수 있어요. 카드를 더 깔끔하게 보고 싶다면 끄세요.", comment: "Category badge explanation"))
                    .font(.body)
            }

            Section(header: Text(NSLocalizedString("미리보기", comment: "Preview"))) {
                HStack(spacing: 20) {
                    miniCard(withBadge: true, label: NSLocalizedString("켜짐", comment: "On"))
                    miniCard(withBadge: false, label: NSLocalizedString("꺼짐", comment: "Off"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
        }
        .navigationTitle(NSLocalizedString("카테고리 심볼", comment: "Category symbol"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbarBackground(theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func miniCard(withBadge: Bool, label: String) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                    .fill(theme.accent)
                    .frame(width: 116, height: 84)
                    .overlay(alignment: .bottomLeading) {
                        Text(NSLocalizedString("메모", comment: "Memo"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(10)
                    }
                if withBadge {
                    Image(systemName: "folder.fill")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(10)
                }
            }
            Text(label)
                .font(.footnote)
                .foregroundColor(theme.textMuted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

// MARK: - Persona Settings (v4.0.8)
/// 설정 → 사용 패턴 진입점. PersonaSelectionView를 settings 모드로 감싸 dismiss 처리.
struct PersonaSettingsContainer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var theme
    @State private var showAppliedToast = false

    var body: some View {
        PersonaSelectionView(onContinue: {
            showAppliedToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                dismiss()
            }
        }, mode: .settings)
        .navigationTitle(NSLocalizedString("페르소나", comment: "Persona setting nav title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbarBackground(theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .overlay(alignment: .bottom) {
            if showAppliedToast {
                Text(NSLocalizedString("페르소나 변경됨", comment: "Persona changed toast"))
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.8))
                    .clipShape(Capsule())
                    .padding(.bottom, 60)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: showAppliedToast) { _, visible in
            if visible {
                UIAccessibility.post(notification: .announcement,
                    argument: NSLocalizedString("페르소나 변경됨", comment: "Persona changed toast"))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showAppliedToast)
    }
}

struct CopyPasteView: View {

    @Environment(\.appTheme) private var theme

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("📋 붙여넣기 허용 설정", comment: "Paste permission settings title"))
                        .font(.headline)
                        .padding(.bottom, 4)

                    Text(NSLocalizedString("앱 실행 시 '붙여넣기 허용' 팝업이 뜬 경우, 아래 경로로 설정을 변경할 수 있습니다.", comment: "Paste permission settings description"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
                .padding(.vertical, 8)
            }

            Section(header: Text(NSLocalizedString("설정 경로", comment: "Settings path section header"))) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                            .foregroundColor(.blue)
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("설정", comment: "Settings"))
                            .fontWeight(.medium)
                    }

                    Image(systemName: "chevron.down")
                        .font(.body)
                        .foregroundColor(theme.textFaint)
                        .padding(.leading, 8)
                        .accessibilityHidden(true)

                    HStack(spacing: 8) {
                        Image(systemName: "app.fill")
                            .foregroundColor(.blue)
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("클립키보드", comment: "ClipKeyboard app name"))
                            .fontWeight(.medium)
                    }

                    Image(systemName: "chevron.down")
                        .font(.body)
                        .foregroundColor(theme.textFaint)
                        .padding(.leading, 8)
                        .accessibilityHidden(true)

                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundColor(.blue)
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("다른 앱에서 붙여넣기", comment: "Paste from other apps"))
                            .fontWeight(.medium)
                    }
                }
                .padding(.vertical, 8)
            }

            Section(header: Text(NSLocalizedString("옵션 설명", comment: "Options description section header"))) {
                VStack(alignment: .leading, spacing: 16) {
                    // 묻기
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("묻기", comment: "Ask option"))
                                .font(.headline)
                            Text(NSLocalizedString("복사/붙여넣기 시 매번 팝업이 표시됩니다.", comment: "Ask option description"))
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                        }
                    }

                    Divider()

                    // 거부
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("거부", comment: "Deny option"))
                                .font(.headline)
                            Text(NSLocalizedString("자동 붙여넣기가 차단됩니다. 하지만 길게 눌러서 수동으로 붙여넣기는 가능합니다.", comment: "Deny option description"))
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                        }
                    }

                    Divider()

                    // 허용 (권장)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(NSLocalizedString("허용", comment: "Allow option"))
                                    .font(.headline)
                                Text(NSLocalizedString("(권장)", comment: "Recommended badge"))
                                    .font(.body)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(theme.radiusXs)
                            }
                            Text(NSLocalizedString("팝업 없이 복사한 텍스트를 바로 확인하고 붙여넣을 수 있습니다. 클립보드 자동 분류 기능을 사용하려면 이 옵션을 권장합니다.", comment: "Allow option description"))
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                Button(action: {
                    if let url = URL.init(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text(NSLocalizedString("설정으로 이동", comment: "Go to Settings button"))
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("붙여넣기 알림 설정", comment: "Paste notification settings title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct ReviewWriteView: View {

    @Environment(\.dismiss) var dismiss
    @Environment(\.requestReview) var requestReview
    @Environment(\.appTheme) private var theme
    @State private var showingOptions = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("⭐️ 리뷰 및 평점 매기기", comment: "Review and rating header"))
                        .font(.headline)
                        .padding(.bottom, 4)

                    Text(NSLocalizedString("클립키보드가 마음에 드셨나요? 여러분의 리뷰는 앱을 더 발전시키는 데 큰 도움이 됩니다.", comment: "Review description"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
                .padding(.vertical, 8)
            }

            Section {
                Button(action: {
                    requestReview()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        dismiss()
                    }
                }) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("앱 내에서 리뷰 작성", comment: "In-app review button"))
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(NSLocalizedString("빠르고 간편하게 리뷰를 남길 수 있습니다 (권장)", comment: "In-app review description"))
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.body)
                            .foregroundColor(theme.textMuted)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 4)
                }

                Button(action: {
                    dismiss()
                    if let url = URL(string: Constants.appStoreReviewURL) {
                        #if os(iOS)
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        #elseif os(macOS)
                        NSWorkspace.shared.open(url)
                        #endif
                    }
                }) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.blue)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("App Store에서 리뷰 작성", comment: "App Store review button"))
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(NSLocalizedString("App Store 페이지에서 직접 작성합니다", comment: "App Store review description"))
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.body)
                            .foregroundColor(theme.textMuted)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityHint(NSLocalizedString("App Store 페이지로 이동합니다", comment: "Open App Store hint"))
            } footer: {
                Text(NSLocalizedString("리뷰는 다른 사용자에게 앱을 추천하는 데 도움이 되며, 개발자에게는 큰 힘이 됩니다.", comment: "Review footer message"))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
            }
        }
        .navigationTitle(NSLocalizedString("리뷰 남기기", comment: "Leave review"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbarBackground(theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct TutorialView: View {
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Button("Open Web Page") {
                
            }
            .onAppear(perform: {
                dismiss()

                if let url = URL(string: Constants.tutorialURL) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            })
        }
    }
}

#if canImport(MessageUI)
import MessageUI

class EmailController: NSObject, MFMailComposeViewControllerDelegate {
    public static let shared = EmailController()
    private override init() { }

    static var canSendMail: Bool { MFMailComposeViewController.canSendMail() }

    func sendEmail(subject: String, body: String, to: String) {
        guard MFMailComposeViewController.canSendMail() else {
            print("⚠️ [EmailController.sendEmail] 이 기기는 메일 발송을 지원하지 않음")
            return
        }
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = self
        mailComposer.setToRecipients([to])
        mailComposer.setSubject(subject)
        mailComposer.setMessageBody(body, isHTML: false)
        EmailController.getRootViewController()?.present(mailComposer, animated: true, completion: nil)
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        EmailController.getRootViewController()?.dismiss(animated: true, completion: nil)
    }

    static func getRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.rootViewController
    }
}
#else
class EmailController: NSObject {
    public static let shared = EmailController()
    private override init() { }
    static var canSendMail: Bool { false }

    func sendEmail(subject: String, body: String, to: String) {}
}
#endif

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}
