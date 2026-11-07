//
//  DataManager.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/06/15.
//

import SwiftUI
import Foundation

/// Manager handling the text entries
class DataManager: ObservableObject {

    /// Dynamic properties that the UI will react to
    @Published var textEntries = [String]() {
        didSet { saveTextEntries() }
    }

    @Published var didShowOnboarding: Bool = UserDefaults.standard.bool(forKey: DefaultsKey.onboarding) {
        didSet {
            AppLog.info(.store, "📝 [DataManager] didShowOnboarding 변경: \(didShowOnboarding)")
            UserDefaults.standard.setValue(didShowOnboarding, forKey: DefaultsKey.onboarding)
            UserDefaults.standard.synchronize()
            // 온보딩을 끝까지 본 설치만 이벤트를 남긴다 - 퍼널의 첫 단계.
            // (false → true 로 바뀔 때만. 초기화 시점에는 didSet 이 안 불린다)
            if didShowOnboarding, !oldValue {
                AnalyticsService.log(.onboardingCompleted)
            }
        }
    }

    @Published var didShowUseCaseSelection: Bool = UserDefaults.standard.bool(forKey: DefaultsKey.useCaseSelection) {
        didSet {
            print("📝 [DataManager] didShowUseCaseSelection 변경: \(didShowUseCaseSelection)")
            UserDefaults.standard.setValue(didShowUseCaseSelection, forKey: DefaultsKey.useCaseSelection)
            UserDefaults.standard.synchronize()
        }
    }

    /// Fetch saved entries
    init() {
        print("🔧 [DataManager] init() 시작")
        let savedOnboarding = UserDefaults.standard.bool(forKey: DefaultsKey.onboarding)
        print("📖 [DataManager] 온보딩 상태 로드: \(savedOnboarding)")

        textEntries = AppConfig.sharedDefaults?.stringArray(forKey: DefaultsKey.entries) ?? []
        print("📖 [DataManager] textEntries 로드 완료: \(textEntries.count)개")
        print("✅ [DataManager] init() 완료")
    }

    /// Save text entries to `UserDefaults`
    private func saveTextEntries() {
        AppConfig.sharedDefaults?.setValue(textEntries, forKey: DefaultsKey.entries)
        AppConfig.sharedDefaults?.synchronize()
    }
}

/// Generic configurations for the app
class AppConfig {

    // MARK: - App Group
    static let sharedDefaults = AppGroup.defaults

    /// Your email for support
    static let emailSupport = "leeo@kakao.com"
}
