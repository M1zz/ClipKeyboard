//
//  AppTheme.swift
//  ClipKeyboard
//
//  Design handoff 기반 — Dusk (default) + Paper 두 테마, 각각 light/dark.
//  SwiftUI Environment으로 주입해 전 화면에서 동일 토큰 사용.
//

import SwiftUI

// MARK: - Theme Kind

enum AppThemeKind: String, CaseIterable, Identifiable {
    case dusk
    case paper

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dusk: return NSLocalizedString("Dusk", comment: "Theme name")
        case .paper: return NSLocalizedString("Paper", comment: "Theme name")
        }
    }
}

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return NSLocalizedString("System", comment: "Theme mode: follow system")
        case .light: return NSLocalizedString("Light", comment: "Theme mode: light")
        case .dark: return NSLocalizedString("Dark", comment: "Theme mode: dark")
        }
    }
}

// MARK: - Theme struct

/// 현재 해석된 테마 토큰 묶음. View에서 `@Environment(\.appTheme)`로 읽는다.
struct AppTheme: Equatable {
    let kind: AppThemeKind
    let isDark: Bool

    // Colors
    let bg: Color
    let surface: Color
    let surfaceAlt: Color
    let text: Color
    let textMuted: Color
    let textFaint: Color
    let accent: Color
    let accentSoft: Color
    let accentFg: Color
    let danger: Color
    let success: Color
    let warn: Color
    let pink: Color
    let divider: Color

    // Hero gradient stops
    let heroGradientStops: [Color]
    let heroGradientAngle: Double  // degrees

    // Radius scale
    let radiusSm: CGFloat
    let radiusMd: CGFloat
    let radiusLg: CGFloat
    let radiusXl: CGFloat

    // Typography
    /// display 용 폰트 이름 (Fraunces for Paper, Inter/system for Dusk).
    let displayFontName: String?
    /// 본문/UI 폰트 이름 (system if nil).
    let bodyFontName: String?

    // MARK: Static instances

    static let duskLight = AppTheme(
        kind: .dusk,
        isDark: false,
        bg: hx("F4F1FA"),
        surface: .white,
        surfaceAlt: hx("EDE7F7"),
        text: hx("14121B"),
        textMuted: hx("6B6577"),
        textFaint: hx("716B7D"),
        accent: hx("6B4EFF"),
        accentSoft: hx("E7E0FF"),
        accentFg: .white,
        danger: hx("E5484D"),
        success: hx("22C55E"),
        warn: hx("F59E0B"),
        pink: hx("EC4899"),
        divider: Color.black.opacity(0.08),
        heroGradientStops: [
            hx("B5C7FF"),
            hx("C9B5FF"),
            hx("E8B5E8")
        ],
        heroGradientAngle: 155,
        radiusSm: 10, radiusMd: 14, radiusLg: 20, radiusXl: 28,
        displayFontName: nil,   // Inter → system fallback
        bodyFontName: nil
    )

    static let duskDark = AppTheme(
        kind: .dusk,
        isDark: true,
        bg: hx("0E0B17"),
        surface: hx("1A1524"),
        surfaceAlt: hx("221B30"),
        text: hx("F4F1FA"),
        textMuted: hx("A39AB2"),
        textFaint: hx("6B6577"),
        accent: hx("8A6FFF"),
        accentSoft: hx("2A2142"),
        accentFg: .white,
        danger: hx("FF6369"),
        success: hx("3BD97B"),
        warn: hx("FBBF24"),
        pink: hx("F472B6"),
        divider: Color.white.opacity(0.08),
        heroGradientStops: [
            hx("2E2560"),
            hx("4B2E73"),
            hx("6B2E6B")
        ],
        heroGradientAngle: 155,
        radiusSm: 10, radiusMd: 14, radiusLg: 20, radiusXl: 28,
        displayFontName: nil,
        bodyFontName: nil
    )

    static let paperLight = AppTheme(
        kind: .paper,
        isDark: false,
        bg: hx("EFEFF4"),
        surface: .white,
        surfaceAlt: hx("E5E5EA"),
        text: hx("1B1814"),
        textMuted: hx("6A6358"),
        textFaint: hx("8E8E93"),
        accent: hx("C85A3A"),
        accentSoft: hx("F7E4DB"),
        accentFg: .white,
        danger: hx("C8423A"),
        success: hx("4A8A5A"),
        warn: hx("C88A3A"),
        pink: hx("C85A80"),
        divider: Color.black.opacity(0.07),
        heroGradientStops: [
            hx("FBE8D9"),
            hx("F5D5C2"),
            hx("E8B79E")
        ],
        heroGradientAngle: 160,
        radiusSm: 10, radiusMd: 18, radiusLg: 24, radiusXl: 32,
        displayFontName: "Fraunces-Bold",
        bodyFontName: "InstrumentSans-Regular"
    )

    static let paperDark = AppTheme(
        kind: .paper,
        isDark: true,
        bg: hx("131210"),
        surface: hx("1E1C18"),
        surfaceAlt: hx("262320"),
        text: hx("F3EEE4"),
        textMuted: hx("A69E91"),
        textFaint: hx("6A6358"),
        accent: hx("E87555"),
        accentSoft: hx("3A221A"),
        accentFg: .white,
        danger: hx("E05A4F"),
        success: hx("6BAE7F"),
        warn: hx("E0A85A"),
        pink: hx("E07FA0"),
        divider: Color.white.opacity(0.07),
        heroGradientStops: [
            hx("2A1F18"),
            hx("3B2519"),
            hx("4A2A1A")
        ],
        heroGradientAngle: 160,
        radiusSm: 10, radiusMd: 18, radiusLg: 24, radiusXl: 32,
        displayFontName: "Fraunces-Bold",
        bodyFontName: "InstrumentSans-Regular"
    )

    /// 선택된 kind + mode에 따라 적절한 static instance 반환.
    static func resolve(kind: AppThemeKind, isDark: Bool) -> AppTheme {
        switch (kind, isDark) {
        case (.dusk, false): return .duskLight
        case (.dusk, true): return .duskDark
        case (.paper, false): return .paperLight
        case (.paper, true): return .paperDark
        }
    }

    // MARK: Gradient helper

    var heroGradient: LinearGradient {
        let radians = heroGradientAngle * .pi / 180
        let dx = cos(radians)
        let dy = sin(radians)
        return LinearGradient(
            gradient: Gradient(colors: heroGradientStops),
            startPoint: UnitPoint(x: 0.5 - dx * 0.5, y: 0.5 - dy * 0.5),
            endPoint: UnitPoint(x: 0.5 + dx * 0.5, y: 0.5 + dy * 0.5)
        )
    }

    // MARK: Font helpers

    func displayFont(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        if let name = displayFontName {
            return Font.custom(name, size: size, relativeTo: .title)
        }
        return Font.system(Font.TextStyle.nearest(to: size), weight: weight)
    }

    func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let name = bodyFontName {
            return Font.custom(name, size: size, relativeTo: .body)
        }
        return Font.system(Font.TextStyle.nearest(to: size), weight: weight)
    }

    /// Dynamic Type 시맨틱 스타일 기반 폰트.
    /// 숫자 크기 대신 TextStyle을 직접 지정해 시스템 접근성 크기에 완전히 연동.
    func bodyFont(style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        if let name = bodyFontName {
            let baseSize = style.basePointSize
            return Font.custom(name, size: baseSize, relativeTo: style)
        }
        return Font.system(style, weight: weight)
    }
}

extension Font.TextStyle {
    /// 포인트 크기에서 가장 가까운 TextStyle을 반환 — Dynamic Type 스케일링에 사용.
    static func nearest(to size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11.5: return .caption2
        case ..<12.5: return .caption
        case ..<14:   return .footnote
        case ..<15.5: return .subheadline
        case ..<16.5: return .callout
        case ..<18.5: return .body
        case ..<21:   return .title3
        case ..<25:   return .title2
        case ..<31:   return .title
        default:      return .largeTitle
        }
    }

    /// HIG 기준 각 텍스트 스타일의 기본 포인트 크기.
    var basePointSize: CGFloat {
        switch self {
        case .largeTitle: return 34
        case .title:      return 28
        case .title2:     return 22
        case .title3:     return 20
        case .headline:   return 17
        case .body:       return 17
        case .callout:    return 16
        case .subheadline:return 15
        case .footnote:   return 13
        case .caption:    return 12
        case .caption2:   return 11
        @unknown default: return 17
        }
    }
}

// MARK: - Environment

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .paperLight
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

extension View {
    func appTheme(_ theme: AppTheme) -> some View {
        environment(\.appTheme, theme)
    }
}

// MARK: - File-scope helper
// ColorExtension.swift 정의의 `Color.init?(hex:)`는 Optional을 반환.
// AppTheme static 상수에서는 항상 유효한 hex를 전달하므로 non-optional이 필요.
// 파일 스코프에서 강제 unwrap으로 감싸 간결하게 사용.
private func hx(_ hex: String) -> Color {
    Color(hex: hex) ?? .clear
}
