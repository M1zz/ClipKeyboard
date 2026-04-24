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
    @Published var editingEntry: String = ""
    @Published var textEntries = [String]() {
        didSet { saveTextEntries() }
    }
    
    @Published var didShowOnboarding: Bool = UserDefaults.standard.bool(forKey: "onboarding") {
        didSet {
            print("📝 [DataManager] didShowOnboarding 변경: \(didShowOnboarding)")
            UserDefaults.standard.setValue(didShowOnboarding, forKey: "onboarding")
            UserDefaults.standard.synchronize()
        }
    }

    @Published var didShowUseCaseSelection: Bool = UserDefaults.standard.bool(forKey: "useCaseSelection") {
        didSet {
            print("📝 [DataManager] didShowUseCaseSelection 변경: \(didShowUseCaseSelection)")
            UserDefaults.standard.setValue(didShowUseCaseSelection, forKey: "useCaseSelection")
            UserDefaults.standard.synchronize()
        }
    }

    static var didRemoveAds: Bool = UserDefaults.standard.bool(forKey: "didRemoveAds") {
        didSet {
            print("📝 [DataManager] didRemoveAds 변경: \(didRemoveAds)")
            UserDefaults.standard.setValue(didRemoveAds, forKey: "didRemoveAds")
            UserDefaults.standard.synchronize()
        }
    }

    /// Fetch saved entries
    init() {
        print("🔧 [DataManager] init() 시작")
        let savedOnboarding = UserDefaults.standard.bool(forKey: "onboarding")
        print("📖 [DataManager] 온보딩 상태 로드: \(savedOnboarding)")

        textEntries = UserDefaults(suiteName: AppConfig.appGroup)!.stringArray(forKey: "entries") ?? [String]()
        print("📖 [DataManager] textEntries 로드 완료: \(textEntries.count)개")
        print("✅ [DataManager] init() 완료")
    }
    
    /// Save text entries to `UserDefaults`
    private func saveTextEntries() {
        UserDefaults(suiteName: AppConfig.appGroup)!.setValue(textEntries, forKey: "entries")
        UserDefaults(suiteName: AppConfig.appGroup)!.synchronize()
    }
}

/// Generic configurations for the app
class AppConfig {

    // MARK: - App Group
    static let appGroup = "group.com.Ysoup.TokenMemo"
    
    /// Custom keyboard background color
    static let keyboardColor = Color(#colorLiteral(red: 0.8392156863, green: 0.8470588235, blue: 0.8745098039, alpha: 1))
    static let keyboardTabColor = Color(#colorLiteral(red: 0.6980392157, green: 0.7137254902, blue: 0.7647058824, alpha: 1))
    
    /// Your email for support
    static let emailSupport = "leeo@kakao.com"
}


