//
//  KeyboardSetupOnboardingView.swift
//  ClipKeyboard
//
//  Tips 앱 스타일 단계별 키보드 설정 가이드
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Main View

struct KeyboardSetupOnboardingView: View {
    var exitAction: () -> Void

    @State private var currentPage = 0
    @State private var setupStatus: SetupStatus = .idle
    @State private var isWaitingForReturn = false
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum SetupStatus { case idle, checking, confirmed, notFound }

    private let steps = SetupStep.all

    var body: some View {
        ZStack(alignment: .top) {
            theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button row
                HStack {
                    Spacer()
                    Button(action: exitAction) {
                        Image(systemName: "xmark")
                            .font(.callout.weight(.semibold))
                            .foregroundColor(theme.textMuted)
                            .padding(9)
                            .background(theme.surfaceAlt)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(NSLocalizedString("닫기", comment: "Close"))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)

                // Step pages
                TabView(selection: $currentPage) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                        StepPageView(step: step, setupStatus: setupStatus, theme: theme)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: currentPage)

                // Bottom controls
                VStack(spacing: 16) {
                    // Page dots
                    HStack(spacing: 5) {
                        ForEach(0..<steps.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage ? theme.accent : theme.divider)
                                .frame(width: i == currentPage ? 22 : 7, height: 7)
                                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(format: NSLocalizedString("%d단계 중 %d단계", comment: "Step X of Y"), currentPage + 1, steps.count))

                    // Action buttons
                    HStack(spacing: 12) {
                        // "설정 열기" 버튼 — step 2(index 1)와 step 3(index 2)에서 표시
                        if currentPage == 1 || currentPage == 2 {
                            Button(action: openSettings) {
                                HStack(spacing: 6) {
                                    Image(systemName: "gear")
                                        .accessibilityHidden(true)
                                    Text(NSLocalizedString("설정 열기", comment: "Open Settings button"))
                                }
                                .font(.headline)
                                .foregroundColor(theme.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(theme.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                            }
                        }

                        // Next / Done
                        if currentPage < steps.count - 1 {
                            Button {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                                    currentPage += 1
                                }
                            } label: {
                                Text(currentPage == 2
                                     ? NSLocalizedString("설정 완료", comment: "Setup done button")
                                     : NSLocalizedString("다음", comment: "Next button"))
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(theme.accentFg)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(theme.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                            }
                        } else {
                            Button(action: exitAction) {
                                Text(NSLocalizedString("시작하기", comment: "Get started button"))
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(theme.accentFg)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(theme.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            guard isWaitingForReturn, currentPage == 2 else { return }
            isWaitingForReturn = false
            setupStatus = .checking
            let loaded = UserDefaults(suiteName: AppGroup.identifier)?.bool(forKey: "keyboard_extension_did_load") ?? false
            withAnimation(.easeInOut(duration: 0.3)) {
                setupStatus = loaded ? .confirmed : .notFound
            }
            if loaded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { currentPage = steps.count - 1 }
                }
            }
        }
    }

    private func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
            isWaitingForReturn = true
        }
        #endif
    }
}

// MARK: - Step Data

struct SetupStep {
    let title: String
    let description: String
    let path: [String]       // 경로 표시용 (예: ["설정", "일반", "키보드"])
    let kind: Kind

    enum Kind {
        case welcome
        case addKeyboard
        case fullAccess
        case done
    }

    static let all: [SetupStep] = [
        SetupStep(
            title: NSLocalizedString("키보드를 추가해요", comment: "Setup step 1 title"),
            description: NSLocalizedString("iPhone 설정에서 클립키보드 키보드를 추가하세요. 딱 한 번만 하면 됩니다.", comment: "Setup step 1 description"),
            path: [
                NSLocalizedString("설정", comment: "iOS Settings"),
                NSLocalizedString("일반", comment: "iOS Settings: General"),
                NSLocalizedString("키보드", comment: "iOS Settings: Keyboard"),
                NSLocalizedString("새로운 키보드 추가…", comment: "iOS Settings: Add New Keyboard")
            ],
            kind: .addKeyboard
        ),
        SetupStep(
            title: NSLocalizedString("ClipKeyboard를 선택해요", comment: "Setup step 2 title"),
            description: NSLocalizedString("서드파티 키보드 목록에서 'ClipKeyboard'를 찾아 탭하세요.", comment: "Setup step 2 description"),
            path: [
                NSLocalizedString("ClipKeyboard", comment: "Keyboard name in list")
            ],
            kind: .addKeyboard
        ),
        SetupStep(
            title: NSLocalizedString("전체 접근을 허용해요", comment: "Setup step 3 title"),
            description: NSLocalizedString("키보드 목록에서 ClipKeyboard를 탭한 후, '전체 접근 허용'을 켜주세요.\n저장된 메모에 접근하기 위해 꼭 필요합니다.", comment: "Setup step 3 description"),
            path: [
                NSLocalizedString("ClipKeyboard", comment: "Keyboard name"),
                NSLocalizedString("전체 접근 허용", comment: "Allow Full Access toggle")
            ],
            kind: .fullAccess
        ),
        SetupStep(
            title: NSLocalizedString("준비 완료!", comment: "Setup done title"),
            description: NSLocalizedString("이제 키보드에서 메모를 바로 불러올 수 있어요.\n키보드를 열고 🌐를 길게 눌러 ClipKeyboard로 전환하세요.", comment: "Setup done description"),
            path: [],
            kind: .done
        )
    ]
}

// MARK: - Single Step Page

private struct StepPageView: View {
    let step: SetupStep
    let setupStatus: KeyboardSetupOnboardingView.SetupStatus
    let theme: AppTheme

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Illustration
                illustrationArea
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .background(theme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg))
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                // Text content
                VStack(alignment: .leading, spacing: 12) {
                    Text(step.title)
                        .font(.title2.weight(.bold))
                        .foregroundColor(theme.text)

                    Text(step.description)
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    if !step.path.isEmpty && step.kind != .done {
                        pathCard
                    }

                    if step.kind == .fullAccess {
                        setupStatusBadge
                    }

                    privacyNote
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: Illustration

    @ViewBuilder
    private var illustrationArea: some View {
        switch step.kind {
        case .welcome:
            EmptyView()

        case .addKeyboard:
            if step.path.count > 1 {
                // Step 1: Settings path illustration
                SettingsPathIllustration(
                    path: [
                        NSLocalizedString("설정", comment: "iOS Settings"),
                        NSLocalizedString("일반", comment: "General"),
                        NSLocalizedString("키보드", comment: "Keyboard"),
                        NSLocalizedString("새로운 키보드 추가…", comment: "Add New Keyboard")
                    ],
                    theme: theme
                )
            } else {
                // Step 2: keyboard list with ClipKeyboard highlighted
                KeyboardListIllustration(theme: theme)
            }

        case .fullAccess:
            FullAccessIllustration(theme: theme)

        case .done:
            DoneIllustration(theme: theme)
        }
    }

    // MARK: Path Card

    private var pathCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(step.path.enumerated()), id: \.offset) { i, item in
                HStack(spacing: 10) {
                    if step.kind == .fullAccess && i == step.path.count - 1 {
                        // Toggle ON
                        RoundedRectangle(cornerRadius: theme.radiusSm)
                            .fill(theme.success)
                            .frame(width: 40, height: 24)
                            .overlay(
                                Circle()
                                    .fill(.white)
                                    .frame(width: 20, height: 20)
                                    .offset(x: 8)
                            )
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: i == step.path.count - 1 ? "checkmark.circle.fill" : "arrow.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(i == step.path.count - 1 ? theme.success : theme.accent)
                            .accessibilityHidden(true)
                    }

                    Text(item)
                        .font(i == step.path.count - 1 ? .subheadline.weight(.semibold) : .subheadline)
                        .foregroundColor(i == step.path.count - 1 ? theme.text : theme.textMuted)
                }
                .padding(.vertical, 8)

                if i < step.path.count - 1 {
                    Divider()
                        .padding(.leading, 34)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
    }

    // MARK: Setup Status

    @ViewBuilder
    private var setupStatusBadge: some View {
        switch setupStatus {
        case .confirmed:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.success)
                    .accessibilityHidden(true)
                Text(NSLocalizedString("키보드가 확인됐어요! 다음으로 넘어갈게요.", comment: "Setup confirmed"))
                    .font(.body)
                    .foregroundColor(theme.text)
            }
            .padding(12)
            .background(theme.success.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm))
            .transition(.move(edge: .bottom).combined(with: .opacity))

        case .notFound:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(theme.warn)
                    .accessibilityHidden(true)
                Text(NSLocalizedString("아직 설정이 완료되지 않은 것 같아요. 다시 확인해볼까요?", comment: "Setup not found"))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
            }
            .padding(12)
            .background(theme.warn.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm))
            .transition(.move(edge: .bottom).combined(with: .opacity))

        default:
            EmptyView()
        }
    }

    // MARK: Privacy Note

    private var privacyNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.body)
                .foregroundColor(theme.textFaint)
                .accessibilityHidden(true)
            Text(NSLocalizedString("개인정보를 수집하지 않습니다.", comment: "Privacy assurance"))
                .font(.body)
                .foregroundColor(theme.textFaint)
        }
    }
}

// MARK: - Illustrations

private struct SettingsPathIllustration: View {
    let path: [String]
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 0) {
            // Fake Settings rows
            ForEach(Array(path.enumerated()), id: \.offset) { i, label in
                HStack {
                    if i == 0 {
                        Image(systemName: "gear")
                            .font(.body)
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
                            .accessibilityHidden(true)
                    } else {
                        Spacer().frame(width: 28)
                    }

                    Text(label)
                        .font(.body)
                        .foregroundColor(i == path.count - 1 ? theme.accent : theme.text)
                        .fontWeight(i == path.count - 1 ? .semibold : .regular)

                    Spacer()

                    Image(systemName: i < path.count - 1 ? "chevron.right" : "plus.circle.fill")
                        .font(.body)
                        .foregroundColor(i == path.count - 1 ? theme.accent : theme.textFaint)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if i < path.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
        .padding(20)
    }
}

private struct KeyboardListIllustration: View {
    let theme: AppTheme

    // iOS 설정의 키보드 목록을 흉내낸 예시 — 사용자 언어에 맞는 이름으로 표시(영어 유저는 Korean/English (US)/Emoji).
    private var keyboards: [String] {
        [NSLocalizedString("한국어", comment: "Keyboard name: Korean"),
         NSLocalizedString("영어(미국)", comment: "Keyboard name: English (US)"),
         NSLocalizedString("이모티콘", comment: "Keyboard name: Emoji")]
    }
    private let clipKeyboard = "ClipKeyboard"

    var body: some View {
        VStack(spacing: 0) {
            Text(NSLocalizedString("키보드", comment: "Keyboard list header"))
                .font(.body)
                .foregroundColor(theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

            ForEach(keyboards, id: \.self) { kb in
                HStack {
                    Text(kb)
                        .font(.body)
                        .foregroundColor(theme.text)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.body)
                        .foregroundColor(theme.textFaint)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                Divider().padding(.leading, 16)
            }

            // Highlighted row
            HStack {
                Text(clipKeyboard)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.accent)
                Spacer()
                Image(systemName: "arrow.left.circle.fill")
                    .foregroundColor(theme.accent)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(theme.accentSoft)
        }
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
        .padding(20)
    }
}

private struct FullAccessIllustration: View {
    let theme: AppTheme
    @State private var toggled = true

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Image(systemName: "keyboard")
                    .font(.title3)
                    .foregroundColor(theme.accent)
                    .accessibilityHidden(true)
                Text("ClipKeyboard")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.text)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.leading, 16)

            // Toggle row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("전체 접근 허용", comment: "Allow Full Access"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(theme.text)
                    Text(NSLocalizedString("메모 접근에 필요합니다", comment: "Required for memo access"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
                Spacer()
                // Animated toggle
                ZStack(alignment: toggled ? .trailing : .leading) {
                    Capsule()
                        .fill(toggled ? theme.success : theme.divider)
                        .frame(width: 50, height: 30)
                    Circle()
                        .fill(.white)
                        .frame(width: 26, height: 26)
                        .padding(.horizontal, 2)
                        .shadow(radius: 2)
                }
                .onAppear {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.6)) {
                        toggled = true
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
        .padding(20)
    }
}

private struct DoneIllustration: View {
    let theme: AppTheme
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.accentSoft)
                    .frame(width: 100, height: 100)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)

                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(theme.accent)
                    .scaleEffect(appeared ? 1 : 0.3)
                    .opacity(appeared ? 1 : 0)
            }

            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.title3)
                    .foregroundColor(theme.textMuted)
                    .accessibilityHidden(true)
                Text(NSLocalizedString("🌐 길게 눌러 전환", comment: "Long press globe to switch"))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.surfaceAlt)
            .clipShape(Capsule())
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.2)) {
                appeared = true
            }
        }
    }
}

// MARK: - Preview

struct KeyboardSetupOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        KeyboardSetupOnboardingView(exitAction: { })
    }
}

// MARK: - Persona (same file to avoid Xcode project registration)

import Foundation

enum Persona: String, CaseIterable, Codable {
    case nomad = "nomad"
    case business = "business"
    case student = "student"
    case general = "general"

    static let `default`: Persona = .nomad

    var icon: String {
        switch self {
        case .nomad: return "globe"
        case .business: return "briefcase.fill"
        case .student: return "graduationcap.fill"
        case .general: return "person.fill"
        }
    }

    var localizedTitle: String {
        switch self {
        case .nomad: return NSLocalizedString("디지털 노마드 / 프리랜서", comment: "Persona: Digital Nomad title")
        case .business: return NSLocalizedString("비즈니스 / 직장인", comment: "Persona: Business title")
        case .student: return NSLocalizedString("학생", comment: "Persona: Student title")
        case .general: return NSLocalizedString("일반 / 개인", comment: "Persona: General title")
        }
    }

    var localizedDescription: String {
        switch self {
        case .nomad:
            return NSLocalizedString("국제 송금, 비자, 여행 정보를 자주 입력하는 분께 추천", comment: "Persona: Nomad description")
        case .business:
            return NSLocalizedString("회사 이메일, 명함 정보, 미팅 관련 입력이 잦은 분께 추천", comment: "Persona: Business description")
        case .student:
            return NSLocalizedString("학번, 학교 이메일, 과제 템플릿이 필요한 분께 추천", comment: "Persona: Student description")
        case .general:
            return NSLocalizedString("일상에서 자주 쓰는 기본 정보만 빠르게 입력", comment: "Persona: General description")
        }
    }

    var exampleTags: [String] {
        switch self {
        case .nomad:
            return [
                NSLocalizedString("🏦 IBAN", comment: "Nomad example tag: IBAN"),
                NSLocalizedString("🛂 여권번호", comment: "Nomad example tag: passport"),
                NSLocalizedString("✈️ 비자", comment: "Nomad example tag: visa"),
                NSLocalizedString("💱 환전 메모", comment: "Nomad example tag: FX notes")
            ]
        case .business:
            return [
                NSLocalizedString("📧 회사 이메일", comment: "Business example tag: work email"),
                NSLocalizedString("🪪 명함", comment: "Business example tag: business card"),
                NSLocalizedString("💼 사업자번호", comment: "Business example tag: business number"),
                NSLocalizedString("📋 미팅 메모", comment: "Business example tag: meeting notes")
            ]
        case .student:
            return [
                NSLocalizedString("🎓 학번", comment: "Student example tag: student ID"),
                NSLocalizedString("📚 학교 이메일", comment: "Student example tag: school email"),
                NSLocalizedString("📝 과제 템플릿", comment: "Student example tag: assignment"),
                NSLocalizedString("🏠 기숙사 주소", comment: "Student example tag: dorm address")
            ]
        case .general:
            return [
                NSLocalizedString("📞 전화번호", comment: "General example tag: phone"),
                NSLocalizedString("📍 주소", comment: "General example tag: address"),
                NSLocalizedString("🔑 긴급 연락처", comment: "General example tag: emergency contact"),
                NSLocalizedString("✉️ 이메일", comment: "General example tag: email")
            ]
        }
    }

    func seedCategories(language: String) -> [String] {
        let lang = language.lowercased()
        switch self {
        case .nomad:
            switch lang {
            case "ko":
                return ["IBAN", "SWIFT/BIC", "VAT/세금번호", "PayPal", "Crypto Wallet",
                        "여권번호", "비자", "Frequent Flyer", "여행자보험", "환전 메모"]
            case "id":
                return ["IBAN", "SWIFT/BIC", "NPWP", "PayPal", "Crypto Wallet",
                        "Paspor", "Visa", "Frequent Flyer", "Asuransi Perjalanan", "Catatan Tukar Uang"]
            default:
                return ["IBAN", "SWIFT/BIC", "VAT / Tax ID", "PayPal", "Crypto Wallet",
                        "Passport", "Visa", "Frequent Flyer", "Travel Insurance", "FX Notes"]
            }
        case .business:
            switch lang {
            case "ko":
                return ["회사 이메일", "비즈니스 주소", "사업자번호", "명함 정보",
                        "미팅 메모", "영수증", "프로젝트 코드", "VPN/계정"]
            case "id":
                return ["Email Kantor", "Alamat Bisnis", "NPWP", "Info Kartu Nama",
                        "Catatan Rapat", "Tanda Terima", "Kode Proyek", "VPN/Akun"]
            default:
                return ["Work Email", "Business Address", "Tax / EIN", "Business Card Info",
                        "Meeting Notes", "Receipt", "Project Code", "VPN / Account"]
            }
        case .student:
            switch lang {
            case "ko":
                return ["학번", "학교 이메일", "학교 주소", "학생증 번호",
                        "과제 템플릿", "도서관 카드", "장학금 정보", "기숙사 주소"]
            case "id":
                return ["NIM", "Email Kampus", "Alamat Kampus", "Nomor KTM",
                        "Template Tugas", "Kartu Perpustakaan", "Beasiswa", "Alamat Asrama"]
            default:
                return ["Student ID", "School Email", "School Address", "Library Card #",
                        "Assignment Template", "Scholarship Info", "Dorm Address"]
            }
        case .general:
            switch lang {
            case "ko":
                return ["이메일", "전화번호", "주소", "비밀번호 힌트", "긴급 연락처"]
            case "id":
                return ["Email", "Nomor Telepon", "Alamat", "Petunjuk Kata Sandi", "Kontak Darurat"]
            default:
                return ["Email", "Phone", "Address", "Password Hint", "Emergency Contact"]
            }
        }
    }
}

struct PersonaSelectionView: View {
    enum Mode { case onboarding, settings }

    @Environment(\.appTheme) private var theme
    let onContinue: () -> Void
    var mode: Mode = .onboarding

    @State private var selected: Persona = .default

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(headerTitle)
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)

                Text(headerSubtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, mode == .onboarding ? 40 : 16)
            .padding(.bottom, 24)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Persona.allCases, id: \.self) { persona in
                        PersonaCard(persona: persona, isSelected: selected == persona) {
                            selected = persona
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            Divider()

            VStack(spacing: 12) {
                PreviewChips(persona: selected)

                // 안내: 페르소나를 골라도 메모/값이 추가되는 게 아니라, 그에 맞는 추천만 바뀐다.
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .accessibilityHidden(true)
                    Text(NSLocalizedString("페르소나를 골라도 메모가 추가되지 않아요. 여러분에게 맞는 추천(이런 메모 어때요? · 카테고리 이름)만 바뀝니다.", comment: "Persona is recommendation-only note"))
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

                Button {
                    apply()
                } label: {
                    Text(applyButtonTitle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .font(.headline)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .padding(.top, 12)
        }
        .onAppear {
            if let existing = CategoryStore.shared.selectedPersona {
                selected = existing
            }
        }
    }

    private var headerTitle: String {
        switch mode {
        case .onboarding: return NSLocalizedString("어떻게 사용하실 예정인가요?", comment: "Persona onboarding title")
        case .settings: return NSLocalizedString("페르소나 변경", comment: "Persona settings title")
        }
    }

    private var headerSubtitle: String {
        switch mode {
        case .onboarding: return NSLocalizedString("자주 쓰는 카테고리를 미리 만들어 드릴게요. 나중에 자유롭게 바꿀 수 있어요.", comment: "Persona onboarding subtitle")
        case .settings: return NSLocalizedString("추천 카테고리가 추가돼요. 처음엔 꺼져 있으니 카테고리 관리에서 원하는 것만 켜세요.", comment: "Persona settings subtitle")
        }
    }

    private var applyButtonTitle: String {
        switch mode {
        case .onboarding: return NSLocalizedString("시작하기", comment: "Onboarding continue button")
        case .settings: return NSLocalizedString("변경 적용", comment: "Apply persona change button")
        }
    }

    private func apply() {
        let lang = Locale.current.language.languageCode?.identifier
        CategoryStore.shared.applyPersona(selected, language: lang)
        // 설정에서 페르소나를 바꾸면 추천 카테고리를 추가하되 표시 토글은 OFF로 둔다.
        // 사용자가 카테고리 관리에서 직접 켜기 전까지 탭에 나타나지 않는다.
        if mode == .settings {
            selected.seedCategories(language: lang ?? "en").forEach {
                CategoryStore.shared.addHidden($0)
            }
        }
        onContinue()
    }
}

private struct PersonaCard: View {
    @Environment(\.appTheme) private var theme
    let persona: Persona
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: persona.icon)
                            .font(.title3)
                            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(persona.localizedTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Text(persona.localizedDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.gray.opacity(0.5))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(persona.exampleTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(isSelected ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.08))
                                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusMd)
                    .fill(isSelected ? Color.accentColor.opacity(0.06) : Color.gray.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusMd)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PreviewChips: View {
    let persona: Persona

    private var seeds: [String] {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        return persona.seedCategories(language: lang)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("자동 추가될 카테고리", comment: "Preview categories header"))
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(seeds, id: \.self) { seed in
                        Text(seed)
                            .font(.body)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.10))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

#if DEBUG
#Preview {
    PersonaSelectionView(onContinue: {})
}
#endif
