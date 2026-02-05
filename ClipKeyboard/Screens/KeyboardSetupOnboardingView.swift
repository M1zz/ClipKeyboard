//
//  KeyboardSetupOnboardingView.swift
//  Token memo
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
                Text(NSLocalizedString("Token Memo에\n오신 것을 환영합니다!", comment: "Onboarding welcome title"))
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
