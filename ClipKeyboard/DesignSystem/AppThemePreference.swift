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

    init() {
        let storedKind = UserDefaults.standard.string(forKey: kindKey)
            .flatMap(AppThemeKind.init(rawValue:)) ?? .dusk
        let storedMode = UserDefaults.standard.string(forKey: modeKey)
            .flatMap(AppThemeMode.init(rawValue:)) ?? .system
        self.kind = storedKind
        self.mode = storedMode
    }

    /// 주어진 시스템 colorScheme과 사용자 설정을 종합해 AppTheme 인스턴스 반환.
    func theme(for systemColorScheme: ColorScheme) -> AppTheme {
        let isDark: Bool
        switch mode {
        case .system:
            isDark = (systemColorScheme == .dark)
        case .light:
            isDark = false
        case .dark:
            isDark = true
        }
        return AppTheme.resolve(kind: kind, isDark: isDark)
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
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        let theme = prefs.theme(for: systemColorScheme)
        content()
            .environmentObject(prefs)
            .environment(\.appTheme, theme)
            .preferredColorScheme(prefs.preferredColorScheme)
            .themedNavigationTitle(theme)
    }
}
