//
//  ClipFAB.swift
//  ClipKeyboard
//
//  56×56 accent-filled 원형 버튼. 누를 때 scale(0.94).
//

import SwiftUI

struct ClipFAB: View {
    var icon: String = "plus"
    var size: CGFloat = 56
    let action: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.39, weight: .semibold))
                .foregroundColor(theme.accentFg)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(theme.accent)
                )
                .shadow(color: theme.accent.opacity(0.33), radius: 10, x: 0, y: 6)
                .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
                .scaleEffect(isPressed ? 0.94 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(.easeOut(duration: 0.12), value: isPressed)
    }
}
