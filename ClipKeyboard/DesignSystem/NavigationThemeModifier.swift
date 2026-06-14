//
//  NavigationThemeModifier.swift
//  ClipKeyboard
//
//  Paper 테마일 때 네비게이션 largeTitle을 Fraunces 폰트로 교체.
//  Dusk 테마는 변경 없이 시스템 기본 폰트 사용.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {
    /// Paper 테마일 때 네비게이션 largeTitle에 Fraunces 폰트 적용.
    func themedNavigationTitle(_ theme: AppTheme) -> some View {
        modifier(ThemedNavTitleModifier(theme: theme))
    }

    /// 네비게이션 바를 테마 배경색으로 불투명하게 — 여러 시트/화면에서 반복되던
    /// toolbarBackground 2줄 보일러플레이트를 한 줄로.
    @ViewBuilder
    func solidNavBar(_ color: Color) -> some View {
        #if os(iOS)
        self
            .toolbarBackground(color, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        #else
        self
        #endif
    }
}

struct ThemedNavTitleModifier: ViewModifier {
    let theme: AppTheme

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .onAppear { applyNavBarFont(theme) }
            .onChange(of: theme.kind) { _, _ in applyNavBarFont(theme) }
            .onChange(of: theme.isDark) { _, _ in applyNavBarFont(theme) }
            #endif
    }

    #if os(iOS)
    private func applyNavBarFont(_ theme: AppTheme) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(theme.bg)

        if theme.kind == .paper, let font = UIFont(name: "Fraunces-Bold", size: 34) {
            appearance.largeTitleTextAttributes = [
                .font: font,
                .foregroundColor: UIColor(theme.text)
            ]
        } else {
            appearance.largeTitleTextAttributes = [
                .foregroundColor: UIColor(theme.text)
            ]
        }

        // inline title
        let inlineFont: UIFont = theme.kind == .paper
            ? (UIFont(name: "InstrumentSans-SemiBold", size: 17) ?? .systemFont(ofSize: 17, weight: .semibold))
            : .systemFont(ofSize: 17, weight: .semibold)

        appearance.titleTextAttributes = [
            .font: inlineFont,
            .foregroundColor: UIColor(theme.text)
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
    #endif
}
