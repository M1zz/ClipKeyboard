//
//  ClipboardCaptureCard.swift
//  ClipKeyboard
//

import SwiftUI
import LeeoKit

/// 감지 타입 → 메모 제목(키) 자동 제안.
/// 이 앱의 핵심 루프는 "키(제목) 저장 → 탭하면 값 복사"이므로,
/// 복사한 내용의 타입에서 키를 추론해 제목 입력 마찰을 없앤다.
extension ClipboardItemType {
    /// "내 이메일", "내 계좌번호" 처럼 재사용 맥락의 제목을 제안한다.
    /// 개인 데이터성 타입은 "내 %@", 그 외(링크·송장 등)는 타입명 그대로.
    var suggestedMemoTitle: String {
        switch self {
        case .text, .image, .url, .trackingNumber, .confirmationCode,
             .declarationNumber, .ipAddress, .vehiclePlate, .medicalRecord:
            return localizedName
        default:
            return String(format: NSLocalizedString("내 %@", comment: "Suggested memo title: My <type>"), localizedName)
        }
    }
}

/// 상단 인라인 캡처 카드: 방금 복사한 클립보드를 한 탭으로 메모로 저장.
/// 제목(키)은 감지 타입에서 자동 제안되어, 별도 입력 없이 바로 저장된다.
struct ClipboardCaptureCard: View {

    @Environment(\.appTheme) private var theme

    let value: String
    let detectedType: ClipboardItemType
    let confidence: Double
    /// 자동 제안된 제목(키) — 원탭 저장 시 그대로 사용.
    let suggestedTitle: String
    let onDismiss: () -> Void
    /// 한 탭 즉시 저장 (제안된 제목으로).
    let onSaveDirect: () -> Void
    /// "편집"으로 진입 — 카드만 닫고 MemoAdd로 이동.
    let onEditTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            typeIcon

            VStack(alignment: .leading, spacing: 6) {
                headerRow
                preview
                suggestedTitleRow
                actionRow
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMd)
                .stroke(Color.blue.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Subviews

    private var typeIcon: some View {
        Image(systemName: detectedType.icon)
            .font(.system(.body, weight: .semibold))
            .foregroundColor(Color.fromName(detectedType.color))
            .frame(width: 40, height: 40)
            .background(Color.fromName(detectedType.color).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm))
            .accessibilityHidden(true)
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Text(NSLocalizedString("Just copied", comment: "Inline capture card: just copied hint"))
                .font(.body.weight(.semibold))
                .foregroundColor(theme.textMuted)

            Text(detectedType.localizedName)
                .font(.body.weight(.semibold))
                .foregroundColor(Color.fromName(detectedType.color))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.fromName(detectedType.color).opacity(0.15))
                .clipShape(Capsule())

            if confidence > 0.8 {
                Image(systemName: AppSymbol.sparkles)
                    .font(.system(.caption2))
                    .foregroundColor(.yellow)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 0)
        }
    }

    private var preview: some View {
        Text(value)
            .font(.body)
            .foregroundColor(theme.text)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 자동 제안된 제목(키)을 칩으로 노출 — 무엇으로 저장될지 미리 보여준다.
    private var suggestedTitleRow: some View {
        HStack(spacing: 6) {
            Text(NSLocalizedString("제목", comment: "Label: memo title (key)"))
                .font(.caption.weight(.medium))
                .foregroundColor(theme.textFaint)

            HStack(spacing: 4) {
                Image(systemName: AppSymbol.keyFill)
                    .font(.system(.caption2))
                    .accessibilityHidden(true)
                Text(suggestedTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.10))
            .clipShape(Capsule())

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(format: NSLocalizedString("제안된 제목 %@", comment: "VoiceOver: suggested title"), suggestedTitle)
        )
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            // 한 탭 즉시 저장 — 제안된 제목으로 바로 메모 생성.
            Button(action: onSaveDirect) {
                HStack(spacing: 4) {
                    Image(systemName: AppSymbol.plusCircleFill)
                        .font(.body)
                        .accessibilityHidden(true)
                    Text(NSLocalizedString("메모로 저장", comment: "Inline capture card: save as memo (one tap)"))
                        .font(.body.weight(.semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.blue)
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityHint(
                String(format: NSLocalizedString("%@ 제목으로 바로 저장", comment: "VoiceOver hint: save with suggested title"), suggestedTitle)
            )

            // 제목을 바꾸고 싶을 때만 — 편집 화면으로.
            NavigationLink {
                MemoAdd(insertedKeyword: suggestedTitle, insertedValue: value)
            } label: {
                Text(NSLocalizedString("편집", comment: "Inline capture card: edit before saving"))
                    .font(.body)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(TapGesture().onEnded { onEditTap() })

            Button(action: onDismiss) {
                Text(NSLocalizedString("Dismiss", comment: "Inline capture card: dismiss button"))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
                    .padding(.horizontal, 8)
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
                suggestedTitle: "내 이메일",
                onDismiss: {},
                onSaveDirect: {},
                onEditTap: {}
            )
            .padding()
        }
    }
}
#endif
