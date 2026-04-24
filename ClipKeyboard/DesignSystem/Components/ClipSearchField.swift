//
//  ClipSearchField.swift
//  ClipKeyboard
//
//  Pill-shaped surfaceAlt 배경의 검색 필드. 돋보기 + TextField + clear.
//

import SwiftUI

struct ClipSearchField: View {
    @Binding var text: String
    var placeholder: String = NSLocalizedString("Search clips", comment: "Search placeholder")

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme.textMuted)
                .font(.system(size: 15))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .foregroundColor(theme.text)
                .font(theme.bodyFont(size: 15))
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.textFaint)
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(theme.surfaceAlt)
        )
    }
}
