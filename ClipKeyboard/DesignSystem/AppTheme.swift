//
//  AppTheme.swift
//  ClipKeyboard
//
//  Design handoff 기반 - Dusk + Paper 두 테마, 각각 light/dark.
//  SwiftUI Environment으로 주입해 전 화면에서 동일 토큰 사용.
//
//  키컬러: 주황(#E8501C). 어두운 바탕에서 읽히도록 띄운 #FF7A4D 가 다크.
//  짝이 되는 짙은 쪽(#B83A0F)은 Color.clipBrandDeep 으로 ColorExtension 에 있다.
//
//  ⚠️ **따뜻한 계열이어야 하는 이유가 있다.** 카테고리 칩과 키 자체가 이미
//     파랑·분홍 계열이다(카테고리 팔레트). 키컬러까지 그 줄에 서면, 튜토리얼이
//     "여기를 누르세요"로 감싼 테두리가 강조가 아니라 **또 하나의 카테고리 칩**으로
//     읽힌다. 실제로 인디고·블루로 칠해 보고 확인했다.
//
//     그래서 규칙은 이렇다: **카테고리 색은 "무슨 갈래", 키컬러는 "누를 곳".**
//     둘은 서로 다른 줄에 서야 한다. 키컬러를 고를 때 이 조건을 먼저 볼 것.
//
//  ⚠️ 한동안 마스코트 악어의 녹색(#1F7A67)이었다. 캐릭터를 걷어낸 뒤로 그 녹색은
//     가리키는 것이 없었고, 되돌린 테라코타(#C85A3A)는 채도가 낮아 눌러야 할 것으로
//     읽히지 않았다. 지금 값은 그 둘을 지나 정한 것이다.
//
//  같은 값이 Assets 의 AccentColor 에도 들어가 있어 `Color.accentColor` 와
//  `theme.accent` 가 같은 색을 가리킨다. 한쪽만 바꾸면 앱이 두 색으로 갈린다.
//

import SwiftUI
import LeeoKit

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

    // Radius scale - 화면 코너의 단일 소스. raw 숫자 대신 이 토큰만 사용한다.
    //  xs: 배지·칩·작은 인디케이터 / sm: 버튼·인풋·작은 컨테이너
    //  md: 카드·시트 본문·주요 버튼 / lg: 큰 카드·강조 컨테이너 / xl: 히어로·풀시트
    let radiusXs: CGFloat
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
        radiusXs: 6, radiusSm: 10, radiusMd: 14, radiusLg: 20, radiusXl: 28,
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
        radiusXs: 6, radiusSm: 10, radiusMd: 14, radiusLg: 20, radiusXl: 28,
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
        accent: hx("E8501C"),
        accentSoft: hx("FFE6DC"),
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
        radiusXs: 6, radiusSm: 10, radiusMd: 18, radiusLg: 24, radiusXl: 32,
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
        accent: hx("FF7A4D"),
        accentSoft: hx("3A1A0E"),
        // 밝은 테라코타 위의 흰 글자는 대비가 얕다. 짙은 갈색을 얹어 읽히게 둔다
        // (라이트의 #E8501C 위에서는 흰 글자가 제 몫을 한다).
        accentFg: hx("2A0E03"),
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
        radiusXs: 6, radiusSm: 10, radiusMd: 18, radiusLg: 24, radiusXl: 32,
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

    /// 대비 증가(설정 > 손쉬운 사용 > 디스플레이 > 대비 증가)를 켠 사람의 테마.
    ///
    /// ⚠️ **흐린 것만 고친다.** 배경·본문·키컬러는 그대로 둔다. 그 셋은 이미 대비가 나오고,
    ///    건드리면 앱이 다른 앱처럼 보인다. 대비 증가는 "화면을 바꿔 달라"가 아니라
    ///    "안 보이는 것을 보이게 해 달라"는 요청이다.
    ///
    /// ⚠️ 이 앱에서 안 보이는 것은 셋이다.
    ///    · `textMuted` - 설명 한 줄, 부제. 본문 옆에서 흐리라고 만든 색이다.
    ///    · `textFaint` - 시간·횟수 같은 곁들이는 글. 가장 흐리다.
    ///    · `divider` - 선. 라이트에서 검정 7% 라 대비 증가를 켠 사람에게는 없는 선이다.
    ///
    /// ⚠️ 흐린 글자는 **본문 색 쪽으로 당긴다.** 회색을 더 진하게 하는 것이 아니라
    ///    본문에 가깝게 섞어야, 테마가 바뀌어도(종이/저녁) 그 테마의 글자색을 따라간다.
    static func resolve(kind: AppThemeKind, isDark: Bool, increasedContrast: Bool) -> AppTheme {
        let base = resolve(kind: kind, isDark: isDark)
        guard increasedContrast else { return base }
        return base.withIncreasedContrast()
    }

    /// 흐린 세 가지를 끌어올린 사본.
    func withIncreasedContrast() -> AppTheme {
        AppTheme(
            kind: kind, isDark: isDark,
            bg: bg, surface: surface, surfaceAlt: surfaceAlt,
            text: text,
            // 본문 쪽으로 크게 당긴다. 설명 글이 본문만큼은 아니어도 확실히 읽혀야 한다.
            textMuted: text.mixed(with: textMuted, amount: 0.35),
            textFaint: text.mixed(with: textFaint, amount: 0.5),
            accent: accent, accentSoft: accentSoft, accentFg: accentFg,
            danger: danger, success: success, warn: warn, pink: pink,
            // 없는 것처럼 보이던 선을 실제로 보이게.
            divider: isDark ? Color.white.opacity(0.3) : Color.black.opacity(0.32),
            heroGradientStops: heroGradientStops, heroGradientAngle: heroGradientAngle,
            radiusXs: radiusXs, radiusSm: radiusSm, radiusMd: radiusMd,
            radiusLg: radiusLg, radiusXl: radiusXl,
            displayFontName: displayFontName, bodyFontName: bodyFontName
        )
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
    /// 포인트 크기에서 가장 가까운 TextStyle을 반환 - Dynamic Type 스케일링에 사용.
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
        case .subheadline: return 15
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

    /// 앱 공통의 둥근 입력 필드 스타일. 시스템 `.roundedBorder`(작은 시스템 라운딩) 대신
    /// 테마 radius·색을 써 다른 둥근 박스들과 일관되게 한다. TextField에 적용.
    func clipRoundedField() -> some View {
        modifier(ClipRoundedField())
    }
}

/// TextField를 테마 radius 기반 둥근 박스로 감싸는 모디파이어 (environment에서 테마를 읽음).
private struct ClipRoundedField: ViewModifier {
    @Environment(\.appTheme) private var theme
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusSm, style: .continuous)
                    .strokeBorder(theme.divider, lineWidth: 1)
            )
    }
}

// MARK: - File-scope helper
// LeeoKit 정의의 `Color.init?(hex:)`는 Optional을 반환.
// AppTheme static 상수에서는 항상 유효한 hex를 전달하므로 non-optional이 필요.
// 파일 스코프에서 강제 unwrap으로 감싸 간결하게 사용.
private func hx(_ hex: String) -> Color {
    Color(hex: hex) ?? .clear
}

// MARK: - Embeddable card chrome
// 템플릿 값 입력 칸 등에서 반복되던 "surfaceAlt 카드 + 강조 테두리" 패턴.
// embedded면 Form 섹션의 흰 카드에 녹이기 위해 자체 카드를 끈다.
extension View {
    @ViewBuilder
    func embeddableCard(embedded: Bool, isHighlighted: Bool, theme: AppTheme) -> some View {
        self
            .padding(embedded ? 0 : 16)
            .background(embedded ? Color.clear : theme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: embedded ? 0 : theme.radiusMd, style: .continuous))
            .overlay(
                Group {
                    if !embedded {
                        RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                            .strokeBorder(isHighlighted ? theme.accent : theme.divider,
                                          lineWidth: isHighlighted ? 2 : 1)
                    }
                }
            )
    }
}

// MARK: - 테마 색으로 그리는 `{변수}` 칩

// 칩을 그리는 코드는 TemplatePlaceholder.swift 한 곳에 있다(위젯 타겟에서도 돌아야 해서
// 테마를 모른다). 앱과 키보드는 거의 언제나 테마 색을 쓰므로, 그 편한 형태만 여기 둔다.
extension String {
    /// `{변수}` 를 테마 강조색 칩으로. 중괄호가 없으면 그대로 통과한다.
    func templateAwareAttributed(theme: AppTheme,
                                 font: Font = .body.weight(.semibold)) -> AttributedString {
        templateAwareAttributed(accent: theme.accent, accentSoft: theme.accentSoft, font: font)
    }
}
