//
//  MemoRowView.swift
//  Token memo
//
//  Created by Leeo on 12/11/25.
//

import SwiftUI

// Separate view for memo row to reduce complexity
struct MemoRowView: View {
    let memo: Memo
    let fontSize: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label(memo.title,
                      systemImage: memo.isChecked ? "checkmark.square.fill" : "doc.on.doc.fill")
                .font(.system(size: fontSize))

                HStack(spacing: 8) {
                // 자동 분류 타입 표시 (우선순위)
                if let detectedType = memo.autoDetectedType {
                    HStack(spacing: 4) {
                        Image(systemName: detectedType.icon)
                            .font(.caption2)
                        Text(detectedType.localizedName)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(colorFor(detectedType.color).opacity(0.2))
                    .foregroundColor(colorFor(detectedType.color))
                    .cornerRadius(8)
                } else {
                    // 자동 분류가 없으면 카테고리 표시
                    Text(categoryLocalizedName(memo.category))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }

                if memo.clipCount > 0 {
                    Label("\(memo.clipCount)", systemImage: "chart.bar.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                if memo.isSecure {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                if memo.isTemplate {
                    Image(systemName: "doc.text.fill")
                        .font(.caption)
                        .foregroundColor(.purple)
                }

                }
            }

            // 이미지 썸네일 (이미지 메모인 경우)
            if (memo.contentType == .image || memo.contentType == .mixed),
               let firstImageFileName = memo.imageFileNames.first {
                #if os(iOS)
                if let thumbnailImage = MemoStore.shared.loadImage(fileName: firstImageFileName) {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                #endif
            }
        }
    }

    /// 카테고리명을 다국어 지원 이름으로 변환
    private func categoryLocalizedName(_ category: String) -> String {
        // 카테고리가 ClipboardItemType의 rawValue와 일치하는지 확인
        if let type = ClipboardItemType.allCases.first(where: { $0.rawValue == category }) {
            return type.localizedName
        }
        // 일치하지 않으면 카테고리명을 그대로 번역 시도
        return NSLocalizedString(category, comment: "Category name")
    }

    /// 색상 이름을 Color로 변환
    private func colorFor(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "indigo": return .indigo
        case "brown": return .brown
        case "cyan": return .cyan
        case "teal": return .teal
        case "pink": return .pink
        case "mint": return .mint
        case "yellow": return .yellow
        default: return .gray
        }
    }
}
