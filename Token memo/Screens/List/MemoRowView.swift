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
                        Text(detectedType.rawValue)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(colorFor(detectedType.color).opacity(0.2))
                    .foregroundColor(colorFor(detectedType.color))
                    .cornerRadius(8)
                } else {
                    // 자동 분류가 없으면 카테고리 표시
                    Text(memo.category)
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
