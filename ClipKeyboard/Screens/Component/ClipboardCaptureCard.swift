//
//  ClipboardCaptureCard.swift
//  ClipKeyboard
//

import SwiftUI

/// 상단 인라인 캡처 카드: 방금 복사한 클립보드를 메모로 저장할 수 있는 액션 카드.
struct ClipboardCaptureCard: View {

    @Environment(\.appTheme) private var theme

    let value: String
    let detectedType: ClipboardItemType
    let confidence: Double
    let onDismiss: () -> Void
    let onSaveTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            typeIcon

            VStack(alignment: .leading, spacing: 6) {
                headerRow
                preview
                actionRow
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.blue.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Subviews

    private var typeIcon: some View {
        Image(systemName: detectedType.icon)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(Color.fromName(detectedType.color))
            .frame(width: 40, height: 40)
            .background(Color.fromName(detectedType.color).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Text(NSLocalizedString("Just copied", comment: "Inline capture card: just copied hint"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textMuted)

            Text(detectedType.localizedName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.fromName(detectedType.color))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.fromName(detectedType.color).opacity(0.15))
                .clipShape(Capsule())

            if confidence > 0.8 {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
            }

            Spacer(minLength: 0)
        }
    }

    private var preview: some View {
        Text(value)
            .font(.system(size: 14))
            .foregroundColor(theme.text)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            NavigationLink {
                MemoAdd(insertedValue: value)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                    Text(NSLocalizedString("Save as memo", comment: "Inline capture card: save button"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.blue)
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(TapGesture().onEnded {
                onSaveTap()
            })

            Button(action: onDismiss) {
                Text(NSLocalizedString("Dismiss", comment: "Inline capture card: dismiss button"))
                    .font(.system(size: 13))
                    .foregroundColor(theme.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }
}

#if DEBUG
struct ClipboardCaptureCard_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ClipboardCaptureCard(
                value: "example@test.com",
                detectedType: .email,
                confidence: 0.95,
                onDismiss: {},
                onSaveTap: {}
            )
            .padding()
        }
    }
}
#endif
