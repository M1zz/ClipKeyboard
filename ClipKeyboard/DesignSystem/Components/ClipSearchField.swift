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
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .foregroundColor(theme.text)
                .font(theme.bodyFont(size: 15))
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .accessibilityLabel(NSLocalizedString("메모 검색", comment: "Search field accessibility label"))
                .accessibilityHint(NSLocalizedString("메모 제목 또는 내용으로 검색합니다", comment: "Search field accessibility hint"))

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.textFaint)
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NSLocalizedString("검색어 지우기", comment: "Clear search field"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(theme.surfaceAlt)
        )
    }
}
