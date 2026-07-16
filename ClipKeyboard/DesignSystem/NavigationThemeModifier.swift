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

    /// (구) 네비게이션 바를 테마 배경색으로 불투명하게 만들던 모디파이어.
    /// iOS 26 Liquid Glass 전환: 불투명 강제를 걷어내고 시스템 기본(맨 위 투명 →
    /// 스크롤 시 glass)에 맡긴다. 27개 호출부를 유지한 채 이 한 곳만 바꿔
    /// 앱 전체 네비게이션 바가 한 번에 glass로 전환된다.
    @ViewBuilder
    func solidNavBar(_ color: Color) -> some View {
        self
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
        // ⚠️ Liquid Glass(iOS 26): 배경은 절대 건드리지 않는다.
        // configureWithOpaqueBackground()+backgroundColor를 전역 appearance에 넣으면
        // 앱의 모든 네비게이션 바가 불투명해져 시스템 glass가 통째로 죽는다.
        // 폰트(테마 서체)만 오버라이드하고 배경은 시스템 기본에 맡긴다.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()

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

        // 스크롤 최상단(콘텐츠가 바에 안 닿았을 때)은 투명 — 시스템과 동일한
        // "맨 위 투명 → 스크롤하면 glass" 동작을 폰트 오버라이드와 함께 유지.
        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        edge.largeTitleTextAttributes = appearance.largeTitleTextAttributes
        edge.titleTextAttributes = appearance.titleTextAttributes

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = edge
        UINavigationBar.appearance().compactAppearance = appearance
    }
    #endif
}
