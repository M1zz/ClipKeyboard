//
//  LivingSkinSettings.swift
//  ClipKeyboard
//
//  **단축어 스킨** 고르기 - 단축어 카드 위에 무엇이 얹히는지.
//  (내부 타입 이름은 LivingSkin 그대로다. UI 명칭만 바꿨다.)
//
//  ⚠️ 이 설정은 **단축어 목록 화면**에 대한 것이라 '키보드 레이아웃'이 아니라
//     '디스플레이' 아래에 둔다. 처음에는 키캡 스킨 옆에 뒀는데, 키보드 설정을 열어야
//     목록 화면 꾸밈을 바꿀 수 있는 건 앞뒤가 맞지 않는다.
//

import SwiftUI
#if canImport(UIKit)
import LeeoKit
#endif

struct LivingSkinSettings: View {

    @AppStorage(DefaultsKey.livingSkin, store: UserDefaults(suiteName: AppGroup.identifier))
    private var livingSkinRaw: String = LivingSkin.none.rawValue

    @Environment(\.appTheme) private var theme

    var body: some View {
        List {
            Section {
                ForEach(LivingSkin.allCases) { candidate in
                    row(for: candidate)
                }
            } footer: {
                Text(NSLocalizedString("단축어 목록 화면에만 나타나요. 키보드는 그대로예요. '동작 줄이기'나 저전력 모드에서는 움직이는 것들이 쉬어요.",
                                       comment: "Living skin section footer"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("단축어 스킨", comment: "Section: shortcut card skin"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func row(for candidate: LivingSkin) -> some View {
        Button {
            HapticManager.shared.light()
            livingSkinRaw = candidate.rawValue
        } label: {
            HStack(spacing: 14) {
                LivingSkinPreview(skin: candidate)
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.localizedName)
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.text)
                    Text(candidate.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let trait = candidate.localizedTrait {
                        Text(trait)
                            .font(.caption2)
                            .foregroundColor(theme.accent)
                    }
                }
                Spacer(minLength: 0)
                if livingSkinRaw == candidate.rawValue {
                    Image(systemName: AppSymbol.checkmark)
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(livingSkinRaw == candidate.rawValue ? [.isSelected] : [])
    }
}

// MARK: - 미리보기

/// 스킨 행에 붙는 작은 카드 - 무엇이 사는지 그림으로 보여준다.
/// 설명을 읽게 하는 대신 **결과를 보여주는** 쪽이 고르기 쉽다
/// (마을은 이미 자란 모습으로 그린다 - 빈 카드를 보여주면 무엇인지 알 수 없다).
struct LivingSkinPreview: View {
    let skin: LivingSkin

    @Environment(\.appTheme) private var theme

    private var size: CGSize { CGSize(width: 46, height: 34) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(theme.surfaceAlt)

            switch skin {
            case .none:
                EmptyView()
            case .vault:
                // 이미 벌어들인 모습으로 - 빈 자리를 보여주면 무엇인지 알 수 없다.
                // 카드에 실제로 붙는 모양 그대로여야 고르고 나서 "이게 아닌데"가 없다.
                VaultCardBadge(savedSeconds: 3600 * 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(4)
            case .geode:
                // 이미 금이 간 모습으로 - 온전한 돌만 보여주면 무엇이 일어나는지 알 수 없다.
                GeodeBadge(useCount: 2, size: 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .village:
                VillageStrip(useCount: 27, pixel: 1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(4)
            case .snow:
                ZStack {
                    SnowTexture(seed: 7)
                    FootprintLayer(useCount: 4, size: 6)
                }
            case .bird:
                Image(systemName: AppSymbol.birdFill)
                    .font(.system(size: 15))
                    .foregroundColor(theme.text.opacity(0.75))
            case .cat:
                Image(systemName: AppSymbol.pawprintFill)
                    .font(.system(size: 15))
                    .foregroundColor(theme.text.opacity(0.75))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(theme.divider, lineWidth: 0.5)
        )
        .accessibilityHidden(true)
    }
}
