//
//  ClipSectionHeader.swift
//  ClipKeyboard
//
//  uppercase 섹션 헤더. 11pt / 600 / letter-spacing 0.6.
//

import SwiftUI

struct ClipSectionHeader: View {
    let label: String

    @Environment(\.appTheme) private var theme

    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.6)
            .foregroundColor(theme.textFaint)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
