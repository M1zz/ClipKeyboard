//
//  TagBadge.swift
//  ClipKeyboard
//
//  Template/Combo 등 메모 row 인라인 배지. accentSoft 배경 + accent 글자.
//

import SwiftUI

struct TagBadge: View {
    let label: String

    @Environment(\.appTheme) private var theme

    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .kerning(0.4)
            .foregroundColor(theme.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(theme.accentSoft)
            )
    }
}
