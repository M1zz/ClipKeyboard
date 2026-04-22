//
//  ClipChip.swift
//  ClipKeyboard
//
//  카테고리 필터 Chip — 아이콘 + 라벨 + 카운트 배지.
//  Active 상태에서 accent 배경으로 전환.
//

import SwiftUI

struct ClipChip: View {
    let label: String
    var icon: String? = nil
    var count: Int? = nil
    var isActive: Bool = false
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                }
                Text(label)
                    .font(theme.bodyFont(size: 14, weight: .medium))
                if let count {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(minWidth: 18, minHeight: 18)
                        .padding(.horizontal, 5)
                        .background(
                            Capsule().fill(
                                isActive
                                ? Color.white.opacity(0.25)
                                : (theme.isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))
                            )
                        )
                        .foregroundColor(isActive ? theme.accentFg : theme.textMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundColor(isActive ? theme.accentFg : theme.text)
            .background(
                Capsule().fill(isActive ? theme.accent : theme.surfaceAlt)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}
