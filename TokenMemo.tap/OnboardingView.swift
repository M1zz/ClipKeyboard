//
//  OnboardingView.swift
//  TokenMemo.tap
//
//  Created by Claude on 2025-12-14.
//

import SwiftUI
import AppKit

// MARK: - Main Onboarding View
struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showAccessibilityAlert = false
    let onComplete: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "doc.on.clipboard.fill",
            title: "클립키보드에 오신 것을 환영합니다",
            subtitle: "macOS에서 가장 빠르고 편리한\n메모 및 클립보드 관리 앱",
            color: .blue,
            type: .welcome
        ),
        OnboardingPage(
            icon: "keyboard",
            title: "전역 단축키로 빠른 접근",
            subtitle: "⌃⌥K를 눌러 언제 어디서나\n메모 목록을 즉시 열 수 있습니다",
            color: .purple,
            type: .feature
        ),
        OnboardingPage(
            icon: "clock.arrow.circlepath",
            title: "클립보드 히스토리",
            subtitle: "복사한 내용이 자동으로 저장됩니다\n(최대 100개, 7일간 유지)",
            color: .green,
            type: .feature
        ),
        OnboardingPage(
            icon: "menubar.rectangle",
            title: "메뉴바에서 언제든지",
            subtitle: "메뉴바 🛶 아이콘을 클릭하면\n모든 기능에 바로 접근할 수 있습니다",
            color: .orange,
            type: .feature
        ),
        OnboardingPage(
            icon: "hand.raised.fill",
            title: "접근성 권한 필요",
            subtitle: "전역 단축키 사용을 위해\n접근성 권한이 필요합니다",
            color: .red,
            type: .permission
        )
    ]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    pages[currentPage].color.opacity(0.3),
                    pages[currentPage].color.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.automatic)
                .frame(maxHeight: .infinity)

                // Bottom section
                VStack(spacing: 20) {
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? pages[currentPage].color : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(currentPage == index ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    .padding(.bottom, 10)

                    // Action buttons
                    HStack(spacing: 12) {
                        if currentPage > 0 {
                            Button(action: {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }) {
                                Text("이전")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(pages[currentPage].color)
                                    .frame(width: 100, height: 44)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        Button(action: {
                            if currentPage == pages.count - 1 {
                                // Last page - handle permissions
                                handlePermissionRequest()
                            } else {
                                withAnimation {
                                    currentPage += 1
                                }
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text(currentPage == pages.count - 1 ? "권한 허용하기" : "다음")
                                    .font(.system(size: 16, weight: .semibold))

                                if currentPage < pages.count - 1 {
                                    Image(systemName: "arrow.right")
                                }
                            }
                            .foregroundColor(.white)
                            .frame(width: currentPage == pages.count - 1 ? 160 : 100, height: 44)
                            .background(pages[currentPage].color)
                            .cornerRadius(12)
                            .shadow(color: pages[currentPage].color.opacity(0.3), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 40)

                    // Skip button
                    if currentPage < pages.count - 1 {
                        Button(action: {
                            // Skip to last page
                            withAnimation {
                                currentPage = pages.count - 1
                            }
                        }) {
                            Text("건너뛰기")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 30)
                .background(.ultraThinMaterial)
            }
        }
        .frame(width: 600, height: 500)
        .alert("접근성 권한 설정", isPresented: $showAccessibilityAlert) {
            Button("취소", role: .cancel) {
                // Complete onboarding anyway
                completeOnboarding()
            }
            Button("시스템 설정 열기") {
                openAccessibilitySettings()
                // Complete onboarding
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    completeOnboarding()
                }
            }
        } message: {
            Text("전역 단축키를 사용하려면 시스템 설정에서 접근성 권한을 허용해주세요.\n\n시스템 설정 > 개인 정보 보호 및 보안 > 접근성")
        }
    }

    private func handlePermissionRequest() {
        // Check if accessibility is already enabled
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isAccessibilityEnabled = AXIsProcessTrustedWithOptions(options)

        if isAccessibilityEnabled {
            // Permission already granted
            completeOnboarding()
        } else {
            // Show alert to guide user
            showAccessibilityAlert = true
        }
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        onComplete()
    }
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.2))
                    .frame(width: 140, height: 140)

                Image(systemName: page.icon)
                    .font(.system(size: 64))
                    .foregroundStyle(page.color)
            }

            // Title
            Text(page.title)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)

            // Subtitle
            Text(page.subtitle)
                .font(.system(size: 18))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .padding(.horizontal, 60)

            // Extra content for specific pages
            if page.type == .feature {
                FeatureDetailView(page: page)
            } else if page.type == .permission {
                PermissionDetailView()
            }

            Spacer()
        }
        .padding(40)
    }
}

// MARK: - Feature Detail View
struct FeatureDetailView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 12) {
            if page.icon == "keyboard" {
                // Keyboard shortcuts
                ShortcutRow(key: "⌃⌥K", description: "메모 목록 열기")
                ShortcutRow(key: "⌃⌥N", description: "새 메모 만들기")
                ShortcutRow(key: "⌃⌥H", description: "클립보드 히스토리")
            } else if page.icon == "clock.arrow.circlepath" {
                // Clipboard features
                VStack(spacing: 8) {
                    FeatureBadge(icon: "checkmark.circle.fill", text: "자동 저장", color: .green)
                    FeatureBadge(icon: "clock.fill", text: "7일간 보관", color: .orange)
                    FeatureBadge(icon: "tray.fill", text: "최대 100개", color: .blue)
                }
            } else if page.icon == "menubar.rectangle" {
                // Menu bar features
                Text("🛶")
                    .font(.system(size: 40))
                Text("메뉴바에서 이 아이콘을 찾아보세요")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Permission Detail View
struct PermissionDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                PermissionStep(number: 1, text: "시스템 설정 열기")
                PermissionStep(number: 2, text: "개인 정보 보호 및 보안 > 접근성")
                PermissionStep(number: 3, text: "TokenMemo 활성화")
            }
            .padding(20)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)

            Text("⚠️ 이 권한은 전역 단축키 사용에만 필요합니다")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Supporting Views
struct ShortcutRow: View {
    let key: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Text(key)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.2))
                .cornerRadius(8)

            Text(description)
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(width: 280)
    }
}

struct FeatureBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .cornerRadius(20)
    }
}

struct PermissionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 28, height: 28)

                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.red)
            }

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

// MARK: - Models
struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let type: PageType

    enum PageType {
        case welcome
        case feature
        case permission
    }
}

// MARK: - Preview
#Preview {
    OnboardingView {
        print("Onboarding completed")
    }
}
