//
//  ReviewBannerView.swift
//  ClipKeyboard
//
//  소프트 리뷰 요청 배너
//

import SwiftUI

struct ReviewBannerView: View {
    @State private var isVisible = true

    var body: some View {
        if ReviewManager.shared.shouldShowBanner && isVisible {
            VStack(spacing: 12) {
                Text(NSLocalizedString("클립 키보드를 잘 쓰고 계신가요?", comment: "Review banner question"))
                    .font(.headline)

                Text(NSLocalizedString("짧은 리뷰 하나가 다른 사용자에게 앱을 알리는 데 도움이 됩니다!", comment: "Review banner description"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Button(NSLocalizedString("App Store에서 평가", comment: "Rate on App Store button")) {
                        openAppStoreReview()
                        ReviewManager.shared.dismissBannerPermanently()
                        withAnimation { isVisible = false }
                    }
                    .buttonStyle(.borderedProminent)

                    Button(NSLocalizedString("나중에", comment: "Maybe later button")) {
                        ReviewManager.shared.dismissBannerTemporarily()
                        withAnimation { isVisible = false }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    private func openAppStoreReview() {
        if let url = URL(string: Constants.appStoreReviewURL) {
            #if os(iOS)
            UIApplication.shared.open(url)
            #endif
        }
    }
}
