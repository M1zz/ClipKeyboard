//
//  ClipboardSuggestionBanner.swift
//  ClipKeyboard
//

import SwiftUI

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
                // 이미지 또는 아이콘
                if let history = clipboardHistory,
                   history.contentType == .image,
                   let imageData = history.imageData,
                   let uiImage = UIImage.from(base64: imageData) {
                    // 이미지 썸네일
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipped()
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                        )
                } else {
                    // 텍스트 아이콘
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(10)
                }

                // 내용
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(clipboardHistory?.contentType == .image
                             ? NSLocalizedString("이미지 감지", comment: "Image detected")
                             : NSLocalizedString("클립보드 감지", comment: "Clipboard detected"))
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if clipboardHistory?.contentType != .image {
                            Image(systemName: detectedType.icon)
                                .font(.caption)
                                .foregroundColor(Color.fromName(detectedType.color))

                            Text(detectedType.localizedName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(Color.fromName(detectedType.color))
                        }
                    }

                    Text(previewText)
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                // 액션 버튼들
                VStack(spacing: 8) {
                    Button {
                        onAccept()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                            Text(NSLocalizedString("사용", comment: "Use"))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(theme.radiusSm)
                    }

                    Button {
                        onDismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.caption)
                            Text(NSLocalizedString("무시", comment: "Ignore"))
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(theme.surfaceAlt)
                        .foregroundColor(theme.textMuted)
                        .cornerRadius(theme.radiusSm)
                    }
                }
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
