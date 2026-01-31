//
//  KeyboardSetupOnboardingView.swift
//  Token memo
//
//  Created by Claude on 2025-12-16.
//

import SwiftUI

struct KeyboardSetupOnboardingView: View {
    var exitAction: () -> Void
    @State private var currentStep = 0

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.6),
                    Color.purple.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Step content
                TabView(selection: $currentStep) {
                    WelcomeStep()
                        .tag(0)

                    OpenSettingsStep()
                        .tag(1)

                    AddKeyboardStep()
                        .tag(2)

                    EnableFullAccessStep()
                        .tag(3)

                    HowToUseStep()
                        .tag(4)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button(action: {
                            withAnimation {
                                currentStep -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text(NSLocalizedString("이전", comment: "Previous button"))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                        }
                    }

                    Button(action: {
                        if currentStep < 4 {
                            withAnimation {
                                currentStep += 1
                            }
                        } else {
                            exitAction()
                        }
                    }) {
                        HStack {
                            Text(currentStep < 4
                                ? NSLocalizedString("다음", comment: "Next button")
                                : NSLocalizedString("시작하기", comment: "Get started button"))
                            if currentStep < 4 {
                                Image(systemName: "chevron.right")
                            }
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
        }
    }
}

// MARK: - Step 1: Welcome
struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // App Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
            }
            .shadow(color: .black.opacity(0.1), radius: 20, y: 10)

            // Welcome Text
            VStack(spacing: 16) {
                Text(NSLocalizedString("ClipKeyboard에 오신 것을 환영합니다", comment: "Welcome title"))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(NSLocalizedString("iOS에서 가장 빠르고 편리한\n메모 및 클립보드 관리 앱", comment: "Welcome subtitle"))
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 40)

            // Features
            VStack(spacing: 20) {
                FeatureRow(
                    icon: "square.and.pencil",
                    title: NSLocalizedString("빠른 메모", comment: "Quick memo feature"),
                    description: NSLocalizedString("자주 사용하는 텍스트를 저장하고 빠르게 붙여넣기", comment: "Quick memo description")
                )

                FeatureRow(
                    icon: "clock.arrow.circlepath",
                    title: NSLocalizedString("클립보드 히스토리", comment: "Clipboard history feature"),
                    description: NSLocalizedString("복사한 내용을 자동으로 저장하고 관리", comment: "Clipboard history description")
                )

                FeatureRow(
                    icon: "icloud.fill",
                    title: NSLocalizedString("iCloud 동기화", comment: "iCloud sync feature"),
                    description: NSLocalizedString("모든 기기에서 데이터 동기화", comment: "iCloud sync description")
                )
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Step 2: Open Settings
struct OpenSettingsStep: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Settings Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "gear")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
            }
            .shadow(color: .black.opacity(0.1), radius: 20, y: 10)

            // Title
            Text(NSLocalizedString("설정 앱을 열어주세요", comment: "Open Settings title"))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Instructions
            VStack(spacing: 16) {
                InstructionRow(
                    number: "1",
                    text: NSLocalizedString("iPhone의 설정 앱을 실행하세요", comment: "Open Settings instruction 1")
                )

                InstructionRow(
                    number: "2",
                    text: NSLocalizedString("일반 > 키보드 메뉴로 이동하세요", comment: "Open Settings instruction 2")
                )
            }
            .padding(.horizontal, 40)

            // Open Settings Button
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "gear")
                    Text(NSLocalizedString("설정 열기", comment: "Open Settings button"))
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Step 3: Add Keyboard
struct AddKeyboardStep: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Keyboard Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "keyboard")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
            }
            .shadow(color: .black.opacity(0.1), radius: 20, y: 10)

            // Title
            Text(NSLocalizedString("ClipKeyboard 키보드 추가", comment: "Add Keyboard title"))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Instructions
            VStack(spacing: 16) {
                InstructionRow(
                    number: "1",
                    text: NSLocalizedString("키보드 메뉴에서 '키보드' 탭을 선택하세요", comment: "Add Keyboard instruction 1")
                )

                InstructionRow(
                    number: "2",
                    text: NSLocalizedString("'새로운 키보드 추가...' 를 탭하세요", comment: "Add Keyboard instruction 2")
                )

                InstructionRow(
                    number: "3",
                    text: NSLocalizedString("목록에서 ClipKeyboard를 찾아 선택하세요", comment: "Add Keyboard instruction 3")
                )
            }
            .padding(.horizontal, 40)

            // Tip
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)

                Text(NSLocalizedString("타사 키보드 섹션에서 찾을 수 있어요", comment: "Add Keyboard tip"))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.2))
            .cornerRadius(10)
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Step 4: Enable Full Access
struct EnableFullAccessStep: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Shield Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
            }
            .shadow(color: .black.opacity(0.1), radius: 20, y: 10)

            // Title
            Text(NSLocalizedString("전체 액세스 허용", comment: "Full Access title"))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Instructions
            VStack(spacing: 16) {
                InstructionRow(
                    number: "1",
                    text: NSLocalizedString("키보드 목록에서 ClipKeyboard를 탭하세요", comment: "Full Access instruction 1")
                )

                InstructionRow(
                    number: "2",
                    text: NSLocalizedString("'전체 액세스 허용'을 켜주세요", comment: "Full Access instruction 2")
                )
            }
            .padding(.horizontal, 40)

            // Why Full Access
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.white)
                    Text(NSLocalizedString("전체 액세스가 필요한 이유", comment: "Why Full Access title"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }

                VStack(spacing: 8) {
                    FullAccessReasonRow(
                        icon: "arrow.up.doc.on.clipboard",
                        text: NSLocalizedString("클립보드 데이터 접근", comment: "Full Access reason 1")
                    )

                    FullAccessReasonRow(
                        icon: "icloud.fill",
                        text: NSLocalizedString("iCloud 동기화", comment: "Full Access reason 2")
                    )

                    FullAccessReasonRow(
                        icon: "doc.text.fill",
                        text: NSLocalizedString("저장된 메모 불러오기", comment: "Full Access reason 3")
                    )
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.2))
            .cornerRadius(12)
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Step 5: How to Use
struct HowToUseStep: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Checkmark Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
            }
            .shadow(color: .black.opacity(0.1), radius: 20, y: 10)

            // Title
            Text(NSLocalizedString("사용 방법", comment: "How to use title"))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Instructions
            VStack(spacing: 20) {
                UsageStep(
                    icon: "globe",
                    title: NSLocalizedString("키보드 전환", comment: "Switch keyboard title"),
                    description: NSLocalizedString("지구본 아이콘을 길게 눌러 ClipKeyboard를 선택하세요", comment: "Switch keyboard description")
                )

                UsageStep(
                    icon: "doc.on.clipboard.fill",
                    title: NSLocalizedString("메모 붙여넣기", comment: "Paste memo title"),
                    description: NSLocalizedString("키보드에서 저장된 메모를 선택하면 바로 입력돼요", comment: "Paste memo description")
                )

                UsageStep(
                    icon: "clock.arrow.circlepath",
                    title: NSLocalizedString("클립보드 히스토리", comment: "Clipboard history title"),
                    description: NSLocalizedString("최근 복사한 내용을 언제든지 다시 사용할 수 있어요", comment: "Clipboard history description")
                )
            }
            .padding(.horizontal, 40)

            // Success message
            Text(NSLocalizedString("모든 준비가 완료되었습니다!", comment: "Setup complete message"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(.top, 10)

            Spacer()
        }
    }
}

// MARK: - Helper Views
struct InstructionRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 36)

                Text(number)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)

            Spacer()
        }
    }
}

struct FullAccessReasonRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 20)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))

            Spacer()
        }
    }
}

struct UsageStep: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }

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
