//
//  ReviewBannerView.swift
//  ClipKeyboard
//
//  소프트 리뷰 요청 배너
//

import SwiftUI

struct ReviewBannerView: View {
    @State private var isVisible = true
    @Environment(\.appTheme) private var theme

    var body: some View {
        if ReviewManager.shared.shouldShowBanner && isVisible {
            VStack(spacing: 12) {
                Text(NSLocalizedString("클립 키보드를 잘 쓰고 계신가요?", comment: "Review banner question"))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(NSLocalizedString("짧은 리뷰 하나가 다른 사용자에게 앱을 알리는 데 도움이 됩니다!", comment: "Review banner description"))
                    .font(.subheadline)
                    .foregroundColor(theme.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // 좁은 폭이면 세로 스택, 넓으면 가로 스택으로 자연스럽게 전환.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        rateButton
                        laterButton
                    }
                    VStack(spacing: 8) {
                        rateButton
                        laterButton
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(theme.surfaceAlt)
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }

    private var rateButton: some View {
        Button(NSLocalizedString("App Store에서 평가", comment: "Rate on App Store button")) {
            openAppStoreReview()
            ReviewManager.shared.dismissBannerPermanently()
            withAnimation { isVisible = false }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .frame(maxWidth: .infinity)
    }

    private var laterButton: some View {
        Button(NSLocalizedString("나중에", comment: "Maybe later button")) {
            ReviewManager.shared.dismissBannerTemporarily()
            withAnimation { isVisible = false }
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .frame(maxWidth: .infinity)
    }

    private func openAppStoreReview() {
        if let url = URL(string: Constants.appStoreReviewURL) {
            #if os(iOS)
            UIApplication.shared.open(url)
            #endif
        }
    }
}
