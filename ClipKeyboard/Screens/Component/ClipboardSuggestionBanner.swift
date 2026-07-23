//
//  ClipboardSuggestionBanner.swift
//  ClipKeyboard
//

import SwiftUI
import LeeoKit

struct ClipboardSuggestionBanner: View {
    let content: String
    let detectedType: ClipboardItemType
    let clipboardHistory: SmartClipboardHistory?
    let onAccept: () -> Void
    let onDismiss: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 이미지일 때만 썸네일 표시. 텍스트는 아이콘 없이 내용부터(보라 그라데이션 심볼 제거 —
                // 공간만 차지했음).
                if let history = clipboardHistory,
                   history.contentType == .image,
                   let imageData = history.imageData,
                   let uiImage = UIImage.from(base64: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipped()
                        .cornerRadius(theme.radiusSm)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.radiusSm)
                                .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                        )
                }

                // 내용
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(clipboardHistory?.contentType == .image
                             ? NSLocalizedString("이미지 감지", comment: "Image detected")
                             : NSLocalizedString("클립보드 감지", comment: "Clipboard detected"))
                            .font(.body)
                            .fontWeight(.semibold)

                        if clipboardHistory?.contentType != .image {
                            Image(systemName: detectedType.icon)
                                .font(.body)
                                .foregroundColor(Color.fromName(detectedType.color))
                                .accessibilityHidden(true)

                            Text(detectedType.localizedName)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(Color.fromName(detectedType.color))
                        }
                    }

                    Text(previewText)
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                        .lineLimit(3)
                }

                Spacer()

                // 액션 버튼들 — "사용"이 주 동작이라 또렷하게, "무시"는 보조.
                VStack(spacing: 8) {
                    Button {
                        onAccept()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: AppSymbol.checkmark)
                                .font(.body.weight(.bold))
                                .accessibilityHidden(true)
                            Text(NSLocalizedString("사용", comment: "Use"))
                                .font(.body.weight(.bold))
                        }
                        .frame(minWidth: 92)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(theme.radiusSm)
                        .shadow(color: Color.blue.opacity(0.35), radius: 4, y: 2)
                    }

                    Button {
                        onDismiss()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: AppSymbol.xmark)
                                .font(.footnote)
                                .accessibilityHidden(true)
                            Text(NSLocalizedString("무시", comment: "Ignore"))
                                .font(.footnote)
                        }
                        .frame(minWidth: 92)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(theme.surfaceAlt)
                        .foregroundColor(theme.textMuted)
                        .cornerRadius(theme.radiusSm)
                    }
                }
                .fixedSize()
            }
            .padding(16)
            .background(theme.surface)

            Divider()
        }
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    private var previewText: String {
        content.count > 40 ? String(content.prefix(40)) + "..." : content
    }
}
