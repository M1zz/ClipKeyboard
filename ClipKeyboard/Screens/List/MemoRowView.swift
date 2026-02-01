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

                HStack(spacing: 6) {
                // 카테고리 표시 (category가 최종 확정된 값)
                if let categoryType = ClipboardItemType.allCases.first(where: { $0.rawValue == memo.category }) {
                    // category가 ClipboardItemType과 매치되면 아이콘과 함께 표시
                    HStack(spacing: 3) {
                        Image(systemName: categoryType.icon)
                            .font(.system(size: 9, weight: .medium))
                        Text(categoryType.localizedName)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .foregroundColor(.secondary)
                    .cornerRadius(4)
                } else {
                    // 일치하지 않으면 텍스트로만 표시
                    Text(categoryLocalizedName(memo.category))
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .foregroundColor(.secondary)
                        .cornerRadius(4)
                }

                if memo.isSecure {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                if memo.isTemplate {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
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
