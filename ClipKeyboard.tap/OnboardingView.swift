//
//  OnboardingView.swift
//  TokenMemo.tap
//
//  Created by Claude on 2025-12-14.
//

import SwiftUI
import AppKit

struct OnboardingView: View {
    let onComplete: () -> Void

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

            VStack(spacing: 30) {
                Spacer()

                // App Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)

                // Welcome Text
                VStack(spacing: 12) {
                    Text(NSLocalizedString("ClipKeyboard에 오신 것을 환영합니다", comment: "Welcome title"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(NSLocalizedString("macOS에서 가장 빠르고 편리한\n메모 및 클립보드 관리 앱", comment: "Welcome subtitle"))
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 60)

                // Features
                VStack(spacing: 16) {
                    MacFeatureRow(
                        icon: "square.and.pencil",
                        title: NSLocalizedString("빠른 메모", comment: "Quick memo feature"),
                        description: NSLocalizedString("자주 사용하는 텍스트를 저장하고 빠르게 붙여넣기", comment: "Quick memo description")
                    )

                    MacFeatureRow(
                        icon: "clock.arrow.circlepath",
                        title: NSLocalizedString("클립보드 히스토리", comment: "Clipboard history feature"),
                        description: NSLocalizedString("복사한 내용을 자동으로 저장하고 관리", comment: "Clipboard history description")
                    )

                    MacFeatureRow(
                        icon: "keyboard",
                        title: NSLocalizedString("전역 단축키", comment: "Global shortcuts feature"),
                        description: NSLocalizedString("⌃⌥K로 어디서나 빠르게 접근", comment: "Global shortcuts description")
                    )

                    MacFeatureRow(
                        icon: "icloud.fill",
                        title: NSLocalizedString("iCloud 동기화", comment: "iCloud sync feature"),
                        description: NSLocalizedString("모든 기기에서 데이터 동기화", comment: "iCloud sync description")
                    )
                }
                .padding(.horizontal, 60)

                Spacer()

                // Get Started Button
                Button(action: {
                    completeOnboarding()
                }) {
                    HStack(spacing: 10) {
                        Text(NSLocalizedString("시작하기", comment: "Get started button"))
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 60)
                .padding(.bottom, 30)
            }
        }
        .frame(width: 600, height: 550)
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        onComplete()
    }
}

// MARK: - Mac Feature Row
struct MacFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView {
        print("Onboarding completed")
    }
}
