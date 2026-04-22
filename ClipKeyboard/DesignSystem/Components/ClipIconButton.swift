//
//  ClipIconButton.swift
//  ClipKeyboard
//
//  42×42 원형 surface 버튼. 카드 스타일 드롭섀도우.
//

import SwiftUI

struct ClipIconButton: View {
    var icon: String
    var size: CGFloat = 42
    var iconSize: CGFloat = 18
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(theme.text)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(theme.surface)
                )
                .shadow(
                    color: Color.black.opacity(theme.isDark ? 0.35 : 0.06),
                    radius: 2, x: 0, y: 1
                )
                .shadow(
                    color: Color.black.opacity(theme.isDark ? 0.0 : 0.04),
                    radius: 8, x: 0, y: 2
                )
        }
        .buttonStyle(.plain)
    }
}
