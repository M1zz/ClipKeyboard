//
//  TagBadge.swift
//  ClipKeyboard
//
//  Template/Combo 등 메모 row 인라인 배지. accentSoft 배경 + accent 글자.
//

import SwiftUI

struct TagBadge: View {
    let label: String
    /// v4.0.8: 옵션 색상. nil이면 테마 accent 사용 (기본).
    var tint: Color? = nil

    @Environment(\.appTheme) private var theme

    var body: some View {
        let fg = tint ?? theme.accent
        let bg = tint?.opacity(0.15) ?? theme.accentSoft
        Text(label.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .kerning(0.4)
            .foregroundColor(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(bg)
            )
    }
}
