//
//  AppTheme.swift
//  ClipKeyboard
//
//  Design handoff 기반 - Dusk + Paper 두 테마, 각각 light/dark.
//  SwiftUI Environment으로 주입해 전 화면에서 동일 토큰 사용.
//
//  **키컬러는 사용자가 고른다**(`AppAccent`). 기본은 **아이폰이 쓰는 그 파랑**이다.
//
//  ⚠️ 기본이 시스템 색인 것은 이 앱의 정체가 "조용한 도구 · 시스템과 동화"이기 때문이다
//     (`docs/design/DESIGN_GUIDE.md` 의 Native Neutral). 키보드 확장으로 남의 앱 안에
//     올라가 있는 시간이 대부분인 물건이라, 어느 앱에서 왔는지 티가 안 나는 편이 맞다.
//
//  ⚠️ 규칙 하나만 기억하면 된다: **카테고리 색은 "무슨 갈래", 키컬러는 "누를 곳".**
//     둘은 서로 다른 줄에 서야 한다. 카테고리 칩이 이미 파랑·초록·주황을 쓰고 있어서,
//     키컬러가 그 줄에 서면 튜토리얼이 "여기를 누르세요"로 감싼 테두리가 강조가 아니라
//     **또 하나의 카테고리 칩**으로 읽힐 수 있다(인디고로 실제로 겪었다).
//     시스템 파랑은 그 문제를 **자리로** 푼다 - 사람들이 이미 "누를 곳"으로 배운 색이라
//     같은 파랑이어도 칩이 아니라 버튼으로 읽힌다.
//
//  ⚠️ 지나온 색들: 마스코트 악어의 녹색(#1F7A67) → 테라코타(#C85A3A, 채도가 낮아 눌러야
//     할 것으로 안 읽혔다) → 주황(#E8501C) → 먹(흑백) → 지금의 시스템 파랑.
//     지나온 것들은 전부 설정의 목록에 남아 있다.
//
//  ⚠️ `Color.accentColor`(Assets 의 AccentColor)도 같은 파랑이다. 다만 **사용자가 고른
//     색은 애셋이 모른다** - 그래서 루트에서 `.tint(theme.accent)` 로 환경에 심는다
//     (`AppThemedContainer`). 애셋은 그 값이 안 닿는 자리(런치 스크린 등)의 바탕값이다.
//

import SwiftUI
import LeeoKit
#if canImport(UIKit)
// 기본 키컬러(`AppAccent.system`)를 **애플이 정한 값 그대로** 받아 오기 위해서만 쓴다.
// 직접 #007AFF 를 적어 두면 iOS 가 그 색을 손볼 때 우리만 옛 파랑으로 남는다.
import UIKit
#endif

// MARK: - 키컬러 (사용자가 고른다)

/// **누를 곳을 가리키는 색.** 설정 > 화면과 표시 > 키 컬러에서 고른다.
///
/// ⚠️ 고른 값은 **App Group** 에 산다. 키보드 익스텐션·위젯도 같은 값을 읽어야
///    앱과 키보드가 두 색으로 갈리지 않는다. 표준 UserDefaults 에 두면 익스텐션이
///    못 읽어서, 앱만 바뀌고 키보드는 예전 색으로 남는다.
///
/// ⚠️ 기본은 `.system` - **아이폰이 쓰는 그 파랑**이다. 값을 적어 두지 않고 시스템에서
///    받아 오므로, 애플이 그 색을 손보면 이 앱도 따라간다.
///
/// ⚠️ 카테고리 칩도 파랑을 쓰는데 왜 겹치지 않나: 시스템 파랑은 사람들이 이미
///    **"누를 곳"으로 배운 색**이라 같은 파랑이어도 칩이 아니라 버튼으로 읽힌다.
///    직접 고른 인디고(`.indigo`)로는 그게 안 됐다 - 그건 그냥 파란 칩이었다.
///
/// ⚠️ 다른 색을 고른 사람에게는 겹칠 수 있다. 그건 **고른 사람의 몫**이다.
///    기본으로 밀어 넣는 것과 골라서 쓰는 것은 다르다.
enum AppAccent: String, CaseIterable, Identifiable {
    /// **기본.** 아이폰이 쓰는 그 파랑(`UIColor.systemBlue`).
    ///
    /// ⚠️ 값을 적어 두지 않고 **시스템에서 받아 온다.** 애플이 그 파랑을 손보면 이 앱도
    ///    같이 따라가야 한다. `#007AFF` 를 박아 두면 어느 날 우리만 옛 파랑으로 남는다.
    ///
    /// ⚠️ 이 앱의 정체성이 "조용한 도구 · 시스템과 동화"(`docs/design/DESIGN_GUIDE.md`)라,
    ///    기본값이 시스템 색인 것이 그 말과 같은 뜻이다. 색을 갖고 싶은 사람은 고르면 된다.
    case system
    /// 색이 없다. 라이트에서는 먹, 다크에서는 백지.
    case ink
    /// 4.4.x 까지 쓰던 색. 되돌릴 길을 남긴다.
    case terracotta
    case indigo
    case pine
    case plum
    case amber

    var id: String { rawValue }

    /// 지금 고른 키컬러. 저장된 값이 없거나 모르는 값이면 **기본**(아이폰 파랑).
    static var current: AppAccent {
        let raw = AppGroup.defaults?.string(forKey: DefaultsKey.appAccent) ?? ""
        return AppAccent(rawValue: raw) ?? .system
    }

    /// 시스템 색을 **그 밝기에 맞춰** 풀어 준다.
    ///
    /// ⚠️ `Color(uiColor:)` 를 그냥 넘기면 그리는 자리의 트레이트를 따라간다. 이 앱은
    ///    테마를 스스로 정하는 자리가 있어서(`AppThemeMode.light/.dark`) 화면 밝기와
    ///    테마가 어긋날 수 있고, 그러면 다크 테마 위에 라이트용 파랑이 얹힌다.
    ///    받는 쪽이 이미 `isDark` 를 알고 있으니 여기서 못박아 푼다.
    private static func resolvedSystem(_ ui: UIColor, isDark: Bool) -> Color {
        Color(ui.resolvedColor(with: UITraitCollection(userInterfaceStyle: isDark ? .dark : .light)))
    }

    /// 고른 값을 적어 둔다 - 앱과 키보드가 같이 본다.
    static func select(_ accent: AppAccent) {
        AppGroup.defaults?.set(accent.rawValue, forKey: DefaultsKey.appAccent)
        NotificationCenter.postOnMain(name: .appAccentChanged, object: nil)
        print("🎨 [AppAccent] 키컬러 \(accent.rawValue)")
    }

    /// 누를 곳의 색.
    func accent(isDark: Bool) -> Color {
        switch self {
        case .system:     return Self.resolvedSystem(.systemBlue, isDark: isDark)
        case .ink:        return isDark ? hx("F2F2F4") : hx("17171A")
        case .terracotta: return isDark ? hx("FF7A4D") : hx("E8501C")
        case .indigo:     return isDark ? hx("7C93F0") : hx("2F4BB8")
        case .pine:       return isDark ? hx("4FB39C") : hx("1F7A67")
        case .plum:       return isDark ? hx("D97BA8") : hx("8B3A62")
        case .amber:      return isDark ? hx("D9AF63") : hx("8A6A2F")
        }
    }

    /// 키컬러를 옅게 깐 바탕 - 칩·뱃지·강조 박스가 앉는 자리.
    func accentSoft(isDark: Bool) -> Color {
        switch self {
        // 아이폰이 옅은 파랑 바탕에 쓰는 그 느낌 - 파랑을 바탕색 쪽으로 크게 당긴 값.
        //
        // ⚠️ 라이트 쪽이 이만큼 밝아야 하는 이유: 시스템 파랑은 **P3 라 sRGB 의
        //    #007AFF 보다 밝다.** 눈으로 고른 #DEEAFD 위에서는 대비가 2.9:1 로 떨어져
        //    칩 글자가 뭉갰다(시험이 잡았다). 여기서 한 톤이라도 어둡게 하면 다시 걸린다.
        case .system:     return isDark ? hx("16233D") : hx("EBF3FF")
        case .ink:        return isDark ? hx("2C2C30") : hx("E4E4E7")
        case .terracotta: return isDark ? hx("3A1A0E") : hx("FFE6DC")
        case .indigo:     return isDark ? hx("1B2145") : hx("E1E6FA")
        case .pine:       return isDark ? hx("0E2C26") : hx("DCEEE9")
        case .plum:       return isDark ? hx("2E1220") : hx("F7E2EC")
        case .amber:      return isDark ? hx("2C2312") : hx("F5EBD6")
        }
    }

    /// 키컬러 **위에** 얹는 글자색.
    ///
    /// ⚠️ 밝은 키컬러 위의 흰 글자는 대비가 얕다. 다크의 밝은 색들에는 짙은 쪽을 얹는다
    ///    (시험이 3:1 을 지킨다 - `AccessibilityContrastTests`).
    func accentFg(isDark: Bool) -> Color {
        switch self {
        // 시스템 파랑 위는 라이트·다크 모두 흰 글자다(아이폰이 그렇게 쓴다).
        case .system:     return .white
        case .ink:        return isDark ? hx("0D0D0E") : .white
        case .terracotta: return isDark ? hx("2A0E03") : .white
        case .indigo:     return isDark ? hx("0E1330") : .white
        case .pine:       return isDark ? hx("06231C") : .white
        case .plum:       return isDark ? hx("2B0B1B") : .white
        case .amber:      return isDark ? hx("2A1F08") : .white
        }
    }

    var localizedName: String {
        switch self {
        // ⚠️ 열쇠를 "기본" 으로 두면 안 된다. 그건 **기본 카테고리 이름**이 이미 쓰고 있고
        //    영어로 "General" 로 번역돼 있다 - 색 이름 자리에 "General" 이 나온다.
        case .system:     return NSLocalizedString("기본색", comment: "Key color: iOS system blue")
        case .ink:        return NSLocalizedString("먹", comment: "Key color: monochrome ink")
        case .terracotta: return NSLocalizedString("테라코타", comment: "Key color: terracotta")
        case .indigo:     return NSLocalizedString("쪽", comment: "Key color: indigo")
        case .pine:       return NSLocalizedString("솔", comment: "Key color: pine green")
        case .plum:       return NSLocalizedString("자두", comment: "Key color: plum")
        case .amber:      return NSLocalizedString("노을", comment: "Key color: amber")
        }
    }

    /// 고르는 자리에서 그 색이 어떤 색인지 한 줄로.
    var localizedNote: String {
        switch self {
        case .system:
            return NSLocalizedString("아이폰이 쓰는 그 파랑이에요. 어느 앱에서 왔는지 티가 안 나는 색입니다.",
                                     comment: "Key color note: system blue")
        case .ink:
            return NSLocalizedString("색이 없어서 어디를 눌러야 하는지가 오히려 또렷해요. 갈래 색과 헷갈리지 않습니다.",
                                     comment: "Key color note: ink")
        case .terracotta:
            return NSLocalizedString("예전에 쓰던 주황이에요. 그대로 두고 싶으면 이걸 고르세요.",
                                     comment: "Key color note: terracotta")
        case .indigo:
            return NSLocalizedString("차분한 파랑이에요. 갈래 칩의 파랑과 나란히 서니 헷갈릴 수 있어요.",
                                     comment: "Key color note: indigo")
        case .pine:
            return NSLocalizedString("깊은 초록이에요. 어두운 화면에서 눈이 편합니다.",
                                     comment: "Key color note: pine")
        case .plum:
            return NSLocalizedString("어두운 바탕에서 가장 잘 읽히는 색이에요.",
                                     comment: "Key color note: plum")
        case .amber:
            return NSLocalizedString("종이 질감에 가장 가깝게 붙는 흙빛 노랑이에요.",
                                     comment: "Key color note: amber")
        }
    }
}

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
    )

    /// ⚠️ **따뜻한 기를 걷어냈다(5.0.3).** 예전 값은 배경도 글자도 조금씩 노랑·주황이
    ///    섞여 있었다(`#1B1814` · `#EFEFF4` 의 푸른 기, 복숭아빛 히어로). 키컬러가 주황일
    ///    때는 그게 한 벌로 읽혔는데, 키컬러가 먹으로 빠지자 **바탕만 혼자 따뜻해서**
    ///    빛바랜 종이처럼 보였다. 지금은 아주 옅은 청회색 쪽으로 세운 중립색이다.
    ///
    /// ⚠️ 그렇다고 **순수 회색은 아니다.** `#131315` 의 마지막 자리처럼 파랑을 한 톨씩
    ///    남겼다. 완전한 무채색은 화면에서 죽은 색으로 보이고, 애플의 시스템 회색들과도
    ///    나란히 서지 않는다.
    ///
    /// ⚠️ **빨강·초록·노랑은 남긴다.** 그건 취향이 아니라 신호다. 삭제가 저장과 똑같이
    ///    생기면 흑백으로 만든 대가를 사용자가 치른다. 대신 채도를 한 단계 낮춰
    ///    흑백 화면에서 혼자 튀지 않게 했다.
    ///
    /// ⚠️ 여기 적힌 `accent`·`accentSoft`·`accentFg` 는 **바탕값일 뿐이다.** 실제로 쓰이는
    ///    값은 사용자가 고른 키컬러가 덮어쓴다(`resolve` → `withAccent`).
    ///    적어 둔 것은 기본값(시스템 파랑)과 같은 값이라, 덮어쓰기가 빠져도 화면이
    ///    엉뚱한 색이 되지는 않는다.
    static let paperLight = AppTheme(
        kind: .paper,
        isDark: false,
        bg: hx("F2F2F3"),
        surface: .white,
        surfaceAlt: hx("E8E8EA"),
        text: hx("131315"),
        textMuted: hx("6B6B72"),
        textFaint: hx("9A9AA1"),
        accent: hx("007AFF"),
        accentSoft: hx("EBF3FF"),
        accentFg: .white,
        danger: hx("C4453E"),
        success: hx("4E8760"),
        warn: hx("B0873F"),
        pink: hx("B85E7E"),
        divider: Color.black.opacity(0.09),
        heroGradientStops: [
            hx("F5F5F6"),
            hx("E2E2E5"),
            hx("CFCFD4")
        ],
        heroGradientAngle: 160,
        radiusXs: 6, radiusSm: 10, radiusMd: 18, radiusLg: 24, radiusXl: 32,
    )

    static let paperDark = AppTheme(
        kind: .paper,
        isDark: true,
        bg: hx("0D0D0E"),
        surface: hx("1A1A1C"),
        surfaceAlt: hx("242427"),
        text: hx("F2F2F4"),
        textMuted: hx("9C9CA3"),
        textFaint: hx("68686F"),
        accent: hx("0A84FF"),
        accentSoft: hx("16233D"),
        accentFg: .white,
        danger: hx("E0655B"),
        success: hx("6FA983"),
        warn: hx("D2A462"),
        pink: hx("D2839E"),
        divider: Color.white.opacity(0.10),
        heroGradientStops: [
            hx("191A1C"),
            hx("26272A"),
            hx("34353A")
        ],
        heroGradientAngle: 160,
        radiusXs: 6, radiusSm: 10, radiusMd: 18, radiusLg: 24, radiusXl: 32,
    )

    /// 선택된 kind + mode + **고른 키컬러**에 따라 테마를 만든다.
    ///
    /// ⚠️ 키컬러를 **여기서** 얹는 것이 중요하다. 익스텐션은 앱의 `AppThemedContainer` 를
    ///    거치지 않고 이 함수를 직접 부른다(`KeyboardView.theme`). 앱 쪽에서만 색을
    ///    갈아 끼우면 키보드는 예전 색으로 남아, 같은 앱이 두 색으로 갈린다.
    ///
    /// - Parameter accent: 시험·미리보기에서 못박고 싶을 때만 넘긴다. 평소에는
    ///   저장된 값(`AppAccent.current`)을 그대로 쓴다.
    static func resolve(kind: AppThemeKind, isDark: Bool,
                        accent: AppAccent = .current) -> AppTheme {
        let base: AppTheme
        switch (kind, isDark) {
        case (.dusk, false): base = .duskLight
        case (.dusk, true): base = .duskDark
        case (.paper, false): base = .paperLight
        case (.paper, true): base = .paperDark
        }
        return base.withAccent(accent)
    }

    /// 키컬러 셋만 갈아 끼운 사본. 나머지 토큰은 그대로다.
    func withAccent(_ choice: AppAccent) -> AppTheme {
        AppTheme(
            kind: kind, isDark: isDark,
            bg: bg, surface: surface, surfaceAlt: surfaceAlt,
            text: text, textMuted: textMuted, textFaint: textFaint,
            accent: choice.accent(isDark: isDark),
            accentSoft: choice.accentSoft(isDark: isDark),
            accentFg: choice.accentFg(isDark: isDark),
            danger: danger, success: success, warn: warn, pink: pink,
            divider: divider,
            heroGradientStops: heroGradientStops, heroGradientAngle: heroGradientAngle,
            radiusXs: radiusXs, radiusSm: radiusSm, radiusMd: radiusMd,
            radiusLg: radiusLg, radiusXl: radiusXl
        )
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
    static func resolve(kind: AppThemeKind, isDark: Bool, increasedContrast: Bool,
                        accent: AppAccent = .current) -> AppTheme {
        let base = resolve(kind: kind, isDark: isDark, accent: accent)
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
            radiusLg: radiusLg, radiusXl: radiusXl
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

    /// Dynamic Type 시맨틱 스타일 기반 폰트.
    /// 숫자 크기 대신 TextStyle을 직접 지정해 시스템 접근성 크기에 완전히 연동한다.
    ///
    /// ⚠️ 예전에는 테마마다 글꼴 이름(Fraunces · InstrumentSans)을 들고 있었다. 그런데
    ///    그 글꼴 파일들이 **앱 번들에 들어간 적이 없어서**(Info.plist 의 UIAppFonts 에만
    ///    적혀 있었다) 언제나 시스템 글꼴로 되돌아왔다. 있지도 않은 갈래를 남겨 두면
    ///    다음 사람이 "종이 테마는 세리프"라고 읽고 그 전제 위에 무언가를 쌓는다.
    func bodyFont(style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        Font.system(style, weight: weight)
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
