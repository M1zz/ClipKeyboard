//
//  ColorfulOnboardingView.swift
//  Token memo
//
//  Created by hyunho lee on 2023/06/15.
//

import SwiftUI

struct ColorfulOnboardingView: View {
    var exitAction: () -> Void

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

            VStack(spacing: 40) {
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

                // Get Started Button
                Button(action: {
                    exitAction()
                }) {
                    HStack(spacing: 12) {
                        Text(NSLocalizedString("시작하기", comment: "Get started button"))
                            .font(.system(size: 18, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()
        }
    }
}

// MARK: - Preview
struct ColorfulOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        ColorfulOnboardingView(exitAction: { })
    }
}
