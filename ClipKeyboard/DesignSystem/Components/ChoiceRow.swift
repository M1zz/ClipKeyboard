//
//  ChoiceRow.swift
//  ClipKeyboard
//
//  여럿 중 하나를 고르는 줄, 그리고 화면 아래를 가로지르는 강조 단추.
//
//  ⚠️ 둘 다 **세 곳에 똑같이 적혀 있던 것**이다. 같은 그림이 세 벌이면 한 벌만 고쳐지고
//     나머지는 그대로 남는다. 실제로 설정의 고르는 줄은 화면마다 여백이 조금씩 달랐다.
//     여기 한 벌만 두고 셋이 같이 쓴다.
//

import SwiftUI
import LeeoKit

// MARK: - 고르는 줄

/// 이름 · 설명 · (덧말) · 고른 표시로 이뤄진 한 줄. 왼쪽에는 미리보기든 아이콘이든 들어간다.
///
/// 키보드 살결, 단축어 스킨, 첫 화면 고르기가 이 줄을 함께 쓴다.
struct ChoiceRow<Leading: View>: View {

    let name: String
    let detail: String
    /// 이름·설명 아래 한 줄 더. 없으면 그리지 않는다(단축어 스킨만 쓴다).
    var trait: String?
    let isSelected: Bool
    /// 왼쪽 자리와 글 사이. 미리보기가 크면 14, 아이콘만이면 12.
    var spacing: CGFloat = 14

    @ViewBuilder let leading: () -> Leading
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            HStack(spacing: spacing) {
                leading()
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.text)
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let trait {
                        Text(trait)
                            .font(.caption2)
                            .foregroundColor(theme.accent)
                    }
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: AppSymbol.checkmark)
                        .font(.body.weight(.semibold))
                        .foregroundColor(Color.checkGreen)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - 강조 단추의 바닥

/// 화면 폭을 가로지르는 강조 단추의 바닥 - 여백, 둥근 모서리, 강조색 면.
///
/// 글자와 아이콘은 부르는 쪽이 정한다. 여기서 정하는 것은 **면**뿐이다.
struct FilledAccentSurface: ViewModifier {
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                    .fill(theme.accent)
            )
            .contentShape(Rectangle())
    }
}

extension View {
    /// 화면 폭을 가로지르는 강조 단추의 바닥을 깐다.
    func filledAccentSurface() -> some View {
        modifier(FilledAccentSurface())
    }
}

// MARK: - 공유 단추

/// "공유하기" 단추. 금고 영수증과 영상 시트가 **글자 하나까지 같은 것**을 쓰고 있었다.
struct ShareActionButton: View {
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: AppSymbol.squareAndArrowUp)
                    .font(.body.weight(.semibold))
                Text(NSLocalizedString("공유하기", comment: "Button: share"))
                    .font(.body.weight(.semibold))
                Spacer(minLength: 0)
            }
            .foregroundColor(theme.accentFg)
            .filledAccentSurface()
        }
        .buttonStyle(.plain)
    }
}
