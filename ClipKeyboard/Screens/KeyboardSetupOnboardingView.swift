//
//  KeyboardSetupOnboardingView.swift
//  ClipKeyboard
//
//  Multi-step keyboard setup onboarding
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct KeyboardSetupOnboardingView: View {
    var exitAction: () -> Void
    @State private var currentPage = 0

    private let totalPages = 4

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Skip Button
                HStack {
                    Spacer()
                    if currentPage < totalPages - 1 {
                        Button {
                            exitAction()
                        } label: {
                            Text(NSLocalizedString("건너뛰기", comment: "Skip onboarding button"))
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 8)

                // MARK: - Page Content
                TabView(selection: $currentPage) {
                    OnboardingWelcomePage()
                        .tag(0)
                    OnboardingAddKeyboardPage()
                        .tag(1)
                    OnboardingFullAccessPage()
                        .tag(2)
                    OnboardingCompletionPage()
                        .tag(3)
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // MARK: - Bottom Controls
                VStack(spacing: 20) {
                    // Page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.white : Color.white.opacity(0.35))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentPage ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: currentPage)
                        }
                    }

                    // Action buttons
                    if currentPage < totalPages - 1 {
                        HStack(spacing: 12) {
                            if currentPage == 1 || currentPage == 2 {
                                Button {
                                    openSettings()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "gear")
                                        Text(NSLocalizedString("설정 열기", comment: "Open settings button"))
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.white.opacity(0.25))
                                    .cornerRadius(12)
                                }
                            }

                            Button {
                                nextPage()
                            } label: {
                                HStack(spacing: 6) {
                                    Text(NSLocalizedString("다음", comment: "Next button"))
                                    Image(systemName: "arrow.right")
                                }
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                        }
                    } else {
                        Button {
                            exitAction()
                        } label: {
                            HStack(spacing: 8) {
                                Text(NSLocalizedString("시작하기", comment: "Get started button"))
                                Image(systemName: "arrow.right")
                            }
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
    }

    private func nextPage() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage = min(currentPage + 1, totalPages - 1)
        }
    }

    private func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

// MARK: - Welcome Page
private struct OnboardingWelcomePage: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 120, height: 120)
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
            }

            VStack(spacing: 12) {
                Text(NSLocalizedString("클립키보드에\n오신 것을 환영합니다!", comment: "Onboarding welcome title"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(NSLocalizedString("키보드에서 바로 메모를 불러와\n빠르게 입력할 수 있어요", comment: "Onboarding welcome subtitle"))
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 30)

            VStack(spacing: 14) {
                OnboardingFeatureRow(
                    icon: "keyboard",
                    text: NSLocalizedString("키보드에서 바로 메모 입력", comment: "Onboarding feature: keyboard input")
                )
                OnboardingFeatureRow(
                    icon: "doc.on.clipboard",
                    text: NSLocalizedString("클립보드 자동 저장 및 관리", comment: "Onboarding feature: clipboard management")
                )
                OnboardingFeatureRow(
                    icon: "lock.shield",
                    text: NSLocalizedString("생체인증으로 안전하게 보호", comment: "Onboarding feature: biometric protection")
                )
            }
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Add Keyboard Page
private struct OnboardingAddKeyboardPage: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(NSLocalizedString("설정 1/2", comment: "Setup step 1 of 2"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.7))

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 100, height: 100)
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }

            Text(NSLocalizedString("키보드를 추가해주세요", comment: "Add keyboard title"))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            // Step-by-step path visualization
            VStack(spacing: 0) {
                OnboardingPathRow(
                    text: NSLocalizedString("설정", comment: "Onboarding path: Settings"),
                    icon: "gear",
                    showArrow: true
                )
                OnboardingPathRow(
                    text: NSLocalizedString("일반", comment: "Onboarding path: General"),
                    icon: "gearshape",
                    showArrow: true
                )
                OnboardingPathRow(
                    text: NSLocalizedString("키보드", comment: "Onboarding path: Keyboard"),
                    icon: "keyboard",
                    showArrow: true
                )
                OnboardingPathRow(
                    text: NSLocalizedString("키보드 목록", comment: "Onboarding path: Keyboards list"),
                    icon: "list.bullet",
                    showArrow: true
                )
                OnboardingPathRow(
                    text: NSLocalizedString("새로운 키보드 추가...", comment: "Onboarding path: Add New Keyboard"),
                    icon: "plus.circle",
                    showArrow: true
                )
                OnboardingPathRow(
                    text: NSLocalizedString("'클립키보드' 선택", comment: "Onboarding path: Select ClipKeyboard"),
                    icon: "checkmark.circle.fill",
                    showArrow: false,
                    isHighlighted: true
                )
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.12))
            .cornerRadius(16)
            .padding(.horizontal, 30)

            // Info box
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.white.opacity(0.8))
                Text(NSLocalizedString("설정에서 키보드를 추가한 후\n이 화면으로 돌아와 다음 단계를 진행하세요", comment: "Onboarding: return after adding keyboard"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.white.opacity(0.12))
            .cornerRadius(10)
            .padding(.horizontal, 30)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Full Access Page
private struct OnboardingFullAccessPage: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(NSLocalizedString("설정 2/2", comment: "Setup step 2 of 2"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.7))

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 100, height: 100)
                Image(systemName: "hand.raised.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }

            VStack(spacing: 8) {
                Text(NSLocalizedString("'전체 접근 허용'을 켜주세요", comment: "Enable Full Access title"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(NSLocalizedString("키보드에서 저장된 메모를 불러오려면\n전체 접근 권한이 필요합니다", comment: "Full Access explanation"))
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            // Step-by-step path
            VStack(spacing: 0) {
                OnboardingPathRow(
                    text: NSLocalizedString("설정 → 일반 → 키보드 → 키보드 목록", comment: "Full access path"),
                    icon: "gear",
                    showArrow: true
                )
                OnboardingPathRow(
                    text: NSLocalizedString("'클립키보드'를 탭", comment: "Full access: tap ClipKeyboard"),
                    icon: "hand.tap",
                    showArrow: true
                )
                OnboardingPathRow(
                    text: NSLocalizedString("'전체 접근 허용' 토글 켜기", comment: "Full access: toggle on"),
                    icon: "togglepower",
                    showArrow: false,
                    isHighlighted: true
                )
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.12))
            .cornerRadius(16)
            .padding(.horizontal, 30)

            // Visual toggle mockup
            VStack(spacing: 0) {
                HStack {
                    Text(NSLocalizedString("전체 접근 허용", comment: "Full Access toggle label"))
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    Spacer()
                    ZStack(alignment: .trailing) {
                        Capsule()
                            .fill(Color.green)
                            .frame(width: 51, height: 31)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 27, height: 27)
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                            .padding(.trailing, 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color.white)
            .cornerRadius(10)
            .padding(.horizontal, 40)

            // Privacy assurance
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.white.opacity(0.9))
                Text(NSLocalizedString("개인정보를 수집하지 않습니다.\n안심하고 사용하세요.", comment: "Privacy assurance message"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.white.opacity(0.12))
            .cornerRadius(10)
            .padding(.horizontal, 30)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Completion Page
private struct OnboardingCompletionPage: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
            }

            VStack(spacing: 12) {
                Text(NSLocalizedString("준비 완료!", comment: "Onboarding completion title"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text(NSLocalizedString("이제 키보드에서 메모를 바로 입력할 수 있어요", comment: "Onboarding completion subtitle"))
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 30)

            // Tips
            VStack(alignment: .leading, spacing: 14) {
                OnboardingFeatureRow(
                    icon: "globe",
                    text: NSLocalizedString("키보드 전환: 🌐 길게 누르기", comment: "Tip: keyboard switching")
                )
                OnboardingFeatureRow(
                    icon: "plus.circle",
                    text: NSLocalizedString("메모를 추가하고 키보드에서 사용하세요", comment: "Tip: add memos and use from keyboard")
                )
            }
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Reusable Components
private struct OnboardingPathRow: View {
    let text: String
    let icon: String
    var showArrow: Bool = true
    var isHighlighted: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: isHighlighted ? .bold : .regular))
                    .foregroundColor(isHighlighted ? .yellow : .white.opacity(0.8))
                    .frame(width: 24)

                Text(text)
                    .font(.system(size: 15, weight: isHighlighted ? .semibold : .regular))
                    .foregroundColor(isHighlighted ? .yellow : .white)

                Spacer()
            }
            .padding(.vertical, 8)

            if showArrow {
                HStack {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.leading, 6)
                    Spacer()
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct OnboardingFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 32)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))

            Spacer()
        }
    }
}

// MARK: - Preview
struct KeyboardSetupOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        KeyboardSetupOnboardingView(exitAction: { })
    }
}

// MARK: - Persona (Onboarding Step 2)
// Persona enum + PersonaSelectionView를 본 파일 끝에 합쳤다 — 별도 파일로 두면
// Xcode 프로젝트에 수동 등록이 필요해 빌드가 깨지므로 자동으로 컴파일되도록 같은 파일에 둠.

import Foundation

enum Persona: String, CaseIterable, Codable {
    case nomad = "nomad"
    case business = "business"
    case student = "student"
    case general = "general"

    /// 1차 타깃 페르소나 — 기본 선택값
    static let `default`: Persona = .nomad

    /// SF Symbol
    var icon: String {
        switch self {
        case .nomad: return "globe"
        case .business: return "briefcase.fill"
        case .student: return "graduationcap.fill"
        case .general: return "person.fill"
        }
    }

    /// UI 노출용 제목
    var localizedTitle: String {
        switch self {
        case .nomad: return NSLocalizedString("디지털 노마드 / 프리랜서", comment: "Persona: Digital Nomad title")
        case .business: return NSLocalizedString("비즈니스 / 직장인", comment: "Persona: Business title")
        case .student: return NSLocalizedString("학생", comment: "Persona: Student title")
        case .general: return NSLocalizedString("일반 / 개인", comment: "Persona: General title")
        }
    }

    /// UI 노출용 설명 (한 줄)
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

    /// 언어별 페르소나 시드 카테고리.
    /// - 라벨은 사용자가 추후 자유롭게 수정 가능 (CategoryStore가 단순 String 배열을 영속).
    /// - 국가 시드(CategoryStore.localeDefaults)와 합쳐져 최종 카테고리가 결정됨.
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
            default: // en + fallback
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

import SwiftUI

struct PersonaSelectionView: View {
    /// 완료 콜백 — 부모 뷰가 didShowUseCaseSelection = true 처리
    let onContinue: () -> Void

    @State private var selected: Persona = .default

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            VStack(spacing: 8) {
                Text(NSLocalizedString("어떻게 사용하실 예정인가요?", comment: "Persona onboarding title"))
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)

                Text(NSLocalizedString("자주 쓰는 카테고리를 미리 만들어 드릴게요. 나중에 자유롭게 바꿀 수 있어요.", comment: "Persona onboarding subtitle"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 40)
            .padding(.bottom, 24)

            // 페르소나 카드 리스트
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

            // 미리보기 + 시작 버튼
            VStack(spacing: 12) {
                PreviewChips(persona: selected)

                Button {
                    apply()
                } label: {
                    Text(NSLocalizedString("시작하기", comment: "Onboarding continue button"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .font(.headline)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .padding(.top, 12)
        }
    }

    private func apply() {
        let lang = Locale.current.language.languageCode?.identifier
        CategoryStore.shared.applyPersona(selected, language: lang)
        print("✅ [PersonaSelectionView] 페르소나=\(selected.rawValue) 적용 후 메인으로")
        onContinue()
    }
}

// MARK: - Persona Card

private struct PersonaCard: View {
    let persona: Persona
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.gray.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor.opacity(0.06) : Color.gray.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview Chips

private struct PreviewChips: View {
    let persona: Persona

    private var seeds: [String] {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        return persona.seedCategories(language: lang)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("자동 추가될 카테고리", comment: "Preview categories header"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(seeds, id: \.self) { seed in
                        Text(seed)
                            .font(.caption)
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
