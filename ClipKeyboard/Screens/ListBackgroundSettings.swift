//
//  ListBackgroundSettings.swift
//  ClipKeyboard
//
//  **배경 이미지** - 단축어 목록 뒤에 깔리는 사진.
//
//  ⚠️ 예전에는 목록 화면 ⋯ 메뉴에서만 열 수 있었다. 그 메뉴를 설정으로 옮기면서
//     여기로 왔다(⋯·+·금고를 바에 다 두려니 시스템이 오버플로 ⋯ 를 하나 더 만들었다).
//
//  ⚠️ 목록 화면의 선택기와 다른 점이 하나 있다: 거기서는 "현재 탭만/모든 탭"을 고를 수
//     있지만 여기서는 **모든 탭**에 적용한다. 설정 화면에는 '현재 탭'이라는 것이 없어서,
//     탭별 적용을 흉내 내면 무엇에 적용되는지 아무도 모른다.
//     그래서 여기서 고르면 탭별 덮어쓰기는 지운다 - 고른 대로 보이는 게 먼저다.
//

import SwiftUI
#if canImport(UIKit)
import LeeoKit
#endif

struct ListBackgroundSettings: View {

    @Environment(\.appTheme) private var theme

    @AppStorage(DefaultsKey.listBackgroundImageV1, store: AppGroup.defaults)
    private var listBackgroundImage: String = ""

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                thumbnail(name: "", label: NSLocalizedString("없음", comment: "Living skin name: none"))
                ForEach(ClipKeyboardList.backgroundOptions, id: \.self) { name in
                    thumbnail(name: name, label: nil)
                }
            }
            .padding(16)
        }
        .background(theme.bg.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("배경 이미지", comment: "Menu: list background image"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func thumbnail(name: String, label: String?) -> some View {
        Button {
            HapticManager.shared.selection()
            withAnimation(.easeInOut(duration: 0.2)) { apply(name) }
        } label: {
            ZStack {
                if name.isEmpty {
                    RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                        .fill(theme.surfaceAlt)
                    Text(label ?? "")
                        .font(.footnote)
                        .foregroundColor(theme.textMuted)
                } else {
                    Image(name)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
            .overlay {
                if listBackgroundImage == name {
                    RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 3)
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: AppSymbol.checkmarkCircleFill)
                                .font(.title3)
                                .foregroundStyle(.white, Color.accentColor)
                                .padding(6)
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? NSLocalizedString("배경 이미지", comment: "Menu: list background image"))
        .accessibilityAddTraits(listBackgroundImage == name ? [.isButton, .isSelected] : .isButton)
    }

    private func apply(_ name: String) {
        listBackgroundImage = name
        // 탭별 덮어쓰기를 남겨 두면 여기서 고른 것이 어떤 탭에서는 안 보인다.
        AppGroup.defaults?
            .removeObject(forKey: DefaultsKey.listBackgroundPerTabV1)
    }
}
