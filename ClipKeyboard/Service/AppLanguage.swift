//
//  AppLanguage.swift
//  ClipKeyboard
//
//  앱 언어를 시스템과 **따로** 고를 수 있게 한다.
//
//  왜 필요한가: 한국에서 아이폰을 쓰는 중국어 사용자, 미국에서 쓰는 한국어 사용자처럼
//  기기 언어와 읽고 싶은 언어가 다른 사람이 있다. iOS 설정 > 앱 > 언어로도 되지만
//  앱을 나갔다 와야 하고, 그 자리가 있다는 걸 아는 사람이 드물다.
//
//  어떻게 도는가: 고른 언어의 `.lproj` 번들을 `Bundle.main` 앞에 세운다(아래 `LocalizedBundle`).
//  `NSLocalizedString` 은 결국 `Bundle.localizedString(forKey:value:table:)` 를 부르므로,
//  그 한 곳만 가로채면 앱 전체 문자열이 즉시 바뀐다. 다시 켜지 않아도 된다.
//
//  ⚠️ 키보드 익스텐션은 **다른 프로세스**다. 그래서 고른 값은 App Group 에 적고,
//     익스텐션도 뜰 때 `applyStored()` 를 부른다. 표준 UserDefaults 에 적으면
//     키보드는 그 값을 영영 못 본다.
//

import Foundation
import ObjectiveC

// MARK: - 고를 수 있는 언어

enum AppLanguage: String, CaseIterable, Identifiable {
    /// 기기 설정을 따른다(기본값). 고른 적이 없으면 언제나 이것이다.
    case system
    case korean = "ko"
    case english = "en"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"

    var id: String { rawValue }

    /// 번들에서 찾을 `.lproj` 이름. 시스템을 따를 때는 없다.
    var bundleCode: String? { self == .system ? nil : rawValue }

    /// 목록에 적을 이름은 **그 언어로** 적는다. 영어만 읽는 사람에게 "한국어"를
    /// "Korean"으로 보여주면 정작 그 언어를 찾는 사람이 못 알아본다.
    var displayName: String {
        switch self {
        case .system:
            return NSLocalizedString("기기 설정 따르기", comment: "Language option: follow system setting")
        case .korean: return "한국어"
        case .english: return "English"
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        }
    }

    /// 지금 이 빌드에 실제로 들어 있는 언어만 보여준다.
    /// 번역이 아직 안 붙은 언어를 목록에 세워두면 골랐을 때 아무것도 안 바뀐다.
    static var available: [AppLanguage] {
        let inBundle = Set(Bundle.main.localizations)
        return allCases.filter { $0 == .system || inBundle.contains($0.rawValue) }
    }

    // MARK: - 저장과 적용

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }

    /// 지금 고른 언어. 고른 적이 없거나 값이 이상하면 `.system`.
    static var current: AppLanguage {
        guard let raw = defaults?.string(forKey: DefaultsKey.appLanguage),
              let language = AppLanguage(rawValue: raw) else { return .system }
        return language
    }

    /// 언어를 고른다. 저장하고, 지금 화면에 곧바로 반영하고, 바뀌었다고 알린다.
    static func select(_ language: AppLanguage) {
        if language == .system {
            defaults?.removeObject(forKey: DefaultsKey.appLanguage)
        } else {
            defaults?.set(language.rawValue, forKey: DefaultsKey.appLanguage)
        }
        apply(language)
        NotificationCenter.default.post(name: .appLanguageChanged, object: nil)
    }

    /// 저장된 선택을 번들에 얹는다. 앱과 키보드 익스텐션 모두 뜰 때 한 번 부른다.
    static func applyStored() {
        apply(current)
    }

    /// SwiftUI 의 `.environment(\.locale)` 에 넣을 값. 날짜·숫자 서식이 글과 어긋나지 않게 한다.
    static var locale: Locale {
        guard let code = current.bundleCode else { return .current }
        return Locale(identifier: code)
    }

    private static func apply(_ language: AppLanguage) {
        LocalizedBundle.install()
        LocalizedBundle.override = language.bundleCode.flatMap { code in
            // "zh-Hans" 처럼 지역이 붙은 이름이 그대로 폴더명이 되는 경우가 대부분이지만,
            // 빌드에 따라 "zh-Hans-CN" 으로 떨어지기도 한다. 앞에서부터 맞는 것을 쓴다.
            let candidates = [code] + Bundle.main.localizations.filter { $0.hasPrefix(code) }
            for name in candidates {
                if let path = Bundle.main.path(forResource: name, ofType: "lproj"),
                   let bundle = Bundle(path: path) {
                    return bundle
                }
            }
            print("⚠️ [AppLanguage.apply] '\(code)' 번들을 못 찾음, 기기 설정을 따른다")
            return nil
        }
    }
}

// MARK: - Bundle.main 가로채기

/// `Bundle.main` 의 클래스를 이걸로 바꿔 끼워, 문자열을 고른 언어의 번들에서 먼저 찾게 한다.
///
/// ⚠️ `object_setClass` 는 딱 한 번만 한다. 여러 번 갈아 끼우면 원래 클래스로 되돌릴 수 없다.
private final class LocalizedBundle: Bundle, @unchecked Sendable {
    private static var installed = false

    /// 지금 앞에 세운 번들. nil 이면 원래대로 기기 설정을 따른다.
    static var override: Bundle?

    static func install() {
        guard !installed else { return }
        object_setClass(Bundle.main, LocalizedBundle.self)
        installed = true
    }

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = LocalizedBundle.override else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Notification.Name {
    /// 앱 언어가 바뀌었다. 화면은 이걸 받아 통째로 다시 그린다.
    static let appLanguageChanged = Notification.Name("appLanguageChanged")
}
