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
                        .cornerRadius(theme.radiusSm)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.radiusSm)
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
                        .cornerRadius(theme.radiusSm)
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

                // 액션 버튼들
                VStack(spacing: 8) {
                    Button {
                        onAccept()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.body)
                            Text(NSLocalizedString("사용", comment: "Use"))
                                .font(.body)
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
                                .font(.body)
                            Text(NSLocalizedString("무시", comment: "Ignore"))
                                .font(.body)
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
