//
//  AppThemePreference.swift
//  ClipKeyboard
//
//  사용자 테마 선택 저장 (kind: Dusk/Paper) + 모드(System/Light/Dark).
//  SwiftUI View에서 `@EnvironmentObject`로 주입받아 AppTheme 계산.
//

import SwiftUI
import Combine

@MainActor
final class AppThemePreference: ObservableObject {
    static let shared = AppThemePreference()

    private let kindKey = "app_theme_kind"
    private let modeKey = "app_theme_mode"

    @Published var kind: AppThemeKind {
        didSet { UserDefaults.standard.set(kind.rawValue, forKey: kindKey) }
    }

    @Published var mode: AppThemeMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: modeKey) }
    }

    /// 사용자가 고른 **키컬러.** 기본은 먹(흑백).
    ///
    /// ⚠️ 저장은 App Group 에 한다(`AppAccent.select`) - 키보드 익스텐션·위젯이 같은 값을
    ///    읽어야 앱과 키보드가 두 색으로 갈리지 않는다.
    ///
    /// ⚠️ `@Published` 로 한 겹 더 두는 이유: `AppTheme.resolve` 는 그릴 때마다
    ///    UserDefaults 를 읽는데, SwiftUI 는 그 값이 바뀐 걸 스스로 모른다. 이 프로퍼티가
    ///    바뀌면서 화면이 다시 그려져야 **앱 전체**가 새 색으로 넘어간다.
    ///    (뷰 트리를 `.id` 로 갈아 끼우는 방법도 있지만, 그러면 설정을 보던 자리가
    ///     통째로 되감겨 색을 고르자마자 화면 밖으로 튕겨 나간다)
    @Published var accent: AppAccent {
        didSet {
            guard oldValue != accent else { return }
            AppAccent.select(accent)
        }
    }

    init() {
        // v4.3: 테마/화면모드 선택 기능 제거 - 앱은 Paper 테마 + 시스템 라이트/다크를 따른다.
        // (다크모드를 완벽 지원하므로 별도 모드 선택이 불필요.)
        self.kind = .paper
        self.mode = .system
        self.accent = .current
    }

    /// 주어진 시스템 colorScheme과 사용자 설정을 종합해 AppTheme 인스턴스 반환.
    ///
    /// - Parameter increasedContrast: 설정 > 손쉬운 사용 > 대비 증가. 흐린 글자와 선을 끌어올린다.
    func theme(for systemColorScheme: ColorScheme,
               increasedContrast: Bool = false) -> AppTheme {
        let isDark: Bool
        switch mode {
        case .system:
            isDark = (systemColorScheme == .dark)
        case .light:
            isDark = false
        case .dark:
            isDark = true
        }
        return AppTheme.resolve(kind: kind, isDark: isDark,
                                increasedContrast: increasedContrast,
                                accent: accent)
    }

    /// View에서 `preferredColorScheme`에 전달할 값. system일 땐 nil(시스템 따름).
    var preferredColorScheme: ColorScheme? {
        switch mode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - View helper

/// 루트 뷰에서 사용: 시스템 colorScheme 관찰 + Preference 조합으로
/// AppTheme을 environment에 주입. 자식 View는 `@Environment(\.appTheme)`만.
struct AppThemedContainer<Content: View>: View {
    @ObservedObject private var prefs = AppThemePreference.shared
    @Environment(\.colorScheme) private var systemColorScheme
    /// 설정 > 손쉬운 사용 > 디스플레이 > 대비 증가.
    @Environment(\.colorSchemeContrast) private var contrast
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        let theme = prefs.theme(for: systemColorScheme, increasedContrast: contrast == .increased)
        content()
            .environmentObject(prefs)
            .environment(\.appTheme, theme)
            // `Color.accentColor` 는 Assets 의 **고정값**을 본다. 사용자가 고른 색을
            // 환경에 심어야 `.accentColor` 를 쓰는 화면들도 같은 색을 따라온다.
            // (이게 없으면 앱의 절반은 애셋 색, 절반은 고른 색이 된다)
            .tint(theme.accent)
            .preferredColorScheme(prefs.preferredColorScheme)
            // ⚠️ .themedNavigationTitle(전역 UINavigationBar.appearance 폰트 오버라이드)를 제거함.
            // iOS 26: 커스텀 appearance 객체가 설정된 바는 시스템 Liquid Glass에서 제외(구형
            // 렌더링 강등)되어 앱 전체 네비바가 불투명해 보이는 원인이었다. 순정 glass 우선.
    }
}
