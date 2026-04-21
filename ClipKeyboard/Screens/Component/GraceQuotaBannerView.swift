//
//  GraceQuotaBannerView.swift
//  ClipKeyboard
//
//  v4.0에서 무료 한도가 줄어든 기존 유저에게 1회 노출되는 안내 배너.
//

import SwiftUI

struct GraceQuotaBannerView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString(
                        "Your existing items are safe",
                        comment: "v4 grace banner title"
                    ))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                    Text(NSLocalizedString(
                        "Free plan is now 5 items. Everything you've saved stays — just no new adds until you upgrade or delete.",
                        comment: "v4 grace banner description"
                    ))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(Text(NSLocalizedString("Dismiss", comment: "Dismiss banner")))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBlue).opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
        )
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}
