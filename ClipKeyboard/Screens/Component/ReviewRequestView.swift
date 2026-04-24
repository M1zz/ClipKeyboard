//
//  ReviewRequestView.swift
//  ClipKeyboard
//
//  Review request view per "Silent Partner" concept
//

import SwiftUI
import StoreKit

struct ReviewRequestView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.requestReview) var requestReview
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Simple icon
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .padding(.bottom, 8)

            // Simple question
            Text(NSLocalizedString("잘 쓰고 계신가요?", comment: "Review question"))
                .font(.title3)
                .fontWeight(.semibold)

            // Brief message
            Text(NSLocalizedString("별점 하나가\n1인 개발자에게 큰 힘이 됩니다.", comment: "Review message"))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(theme.textMuted)
                .lineSpacing(4)

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    HapticManager.shared.soft()
                    ReviewManager.shared.markReviewResponded()
                    dismiss()
                } label: {
                    Text(NSLocalizedString("나중에", comment: "Later button"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(theme.surfaceAlt)
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }

                Button {
                    HapticManager.shared.medium()
                    requestReview()
                    ReviewManager.shared.markReviewResponded()
                    // Dismiss after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                } label: {
                    Text(NSLocalizedString("별점 남기기", comment: "Leave rating button"))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(.bottom, 30)
        }
        .padding(.horizontal, 30)
    }
}

struct ReviewRequestView_Previews: PreviewProvider {
    static var previews: some View {
        ReviewRequestView()
    }
}
