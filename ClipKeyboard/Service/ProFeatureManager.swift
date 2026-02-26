//
//  ProFeatureManager.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2026/02/21.
//

import Foundation

/// Pro 기능 제한 관리
/// - 무료 사용자 제한 정의
/// - 제한 도달 여부 체크
/// - Pro 기능 게이팅
struct ProFeatureManager {
    
    // MARK: - 무료 제한 설정
    // 이 값들을 조정해서 무료/Pro 경계를 설정
    
    /// 무료 메모 최대 개수
    static let freeMemoLimit = 10
    
    /// 무료 콤보 최대 개수
    static let freeComboLimit = 2
    
    /// 무료 클립보드 히스토리 최대 개수
    static let freeClipboardHistoryLimit = 20
    
    /// 무료 템플릿 최대 개수
    static let freeTemplateLimit = 3
    
    // MARK: - Pro 전용 기능 플래그
    
    /// iCloud 백업 사용 가능 여부
    static var isCloudBackupAvailable: Bool { isPro }
    
    /// 생체인증 잠금 사용 가능 여부
    static var isBiometricLockAvailable: Bool { isPro }
    
    /// 테마 커스터마이징 사용 가능 여부
    static var isThemeCustomizationAvailable: Bool { isPro }
    
    /// 이미지 메모 사용 가능 여부
    static var isImageMemoAvailable: Bool { isPro }
    
    // MARK: - 상태 체크
    
    /// Pro 여부 (StoreManager에서 가져옴)
    static var isPro: Bool {
        // App Group UserDefaults에서 캐시 값 읽기 (동기적)
        return UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.bool(forKey: "clipkeyboard_is_pro") ?? false
    }
    
    // MARK: - 제한 체크
    
    /// 메모 추가 가능 여부
    static func canAddMemo(currentCount: Int) -> Bool {
        if isPro { return true }
        return currentCount < freeMemoLimit
    }
    
    /// 콤보 추가 가능 여부
    static func canAddCombo(currentCount: Int) -> Bool {
        if isPro { return true }
        return currentCount < freeComboLimit
    }
    
    /// 템플릿 추가 가능 여부
    static func canAddTemplate(currentCount: Int) -> Bool {
        if isPro { return true }
        return currentCount < freeTemplateLimit
    }
    
    /// 클립보드 히스토리 제한
    static func clipboardHistoryLimit() -> Int {
        return isPro ? 100 : freeClipboardHistoryLimit
    }
    
    // MARK: - 제한 도달 정보
    
    enum LimitType {
        case memo
        case combo
        case template
        case clipboardHistory
        case cloudBackup
        case biometricLock
        case themeCustomization
        case imageMemo
        
        var localizedTitle: String {
            switch self {
            case .memo:
                return NSLocalizedString("메모 개수 제한", comment: "Memo limit")
            case .combo:
                return NSLocalizedString("콤보 개수 제한", comment: "Combo limit")
            case .template:
                return NSLocalizedString("템플릿 개수 제한", comment: "Template limit")
            case .clipboardHistory:
                return NSLocalizedString("클립보드 히스토리 제한", comment: "Clipboard limit")
            case .cloudBackup:
                return NSLocalizedString("iCloud 백업", comment: "Cloud backup")
            case .biometricLock:
                return NSLocalizedString("생체인증 잠금", comment: "Biometric lock")
            case .themeCustomization:
                return NSLocalizedString("테마 설정", comment: "Theme customization")
            case .imageMemo:
                return NSLocalizedString("이미지 메모", comment: "Image memo")
            }
        }
        
        var localizedDescription: String {
            switch self {
            case .memo:
                return String(format: NSLocalizedString("무료 버전에서는 최대 %d개의 메모를 저장할 수 있습니다.", comment: "Memo limit desc"), freeMemoLimit)
            case .combo:
                return String(format: NSLocalizedString("무료 버전에서는 최대 %d개의 콤보를 만들 수 있습니다.", comment: "Combo limit desc"), freeComboLimit)
            case .template:
                return String(format: NSLocalizedString("무료 버전에서는 최대 %d개의 템플릿을 사용할 수 있습니다.", comment: "Template limit desc"), freeTemplateLimit)
            case .clipboardHistory:
                return String(format: NSLocalizedString("무료 버전에서는 최근 %d개의 클립보드 기록만 저장됩니다.", comment: "Clipboard limit desc"), freeClipboardHistoryLimit)
            case .cloudBackup:
                return NSLocalizedString("Pro 버전에서 iCloud 백업을 사용할 수 있습니다.", comment: "Cloud backup desc")
            case .biometricLock:
                return NSLocalizedString("Pro 버전에서 Face ID/Touch ID 잠금을 사용할 수 있습니다.", comment: "Biometric desc")
            case .themeCustomization:
                return NSLocalizedString("Pro 버전에서 테마를 변경할 수 있습니다.", comment: "Theme desc")
            case .imageMemo:
                return NSLocalizedString("Pro 버전에서 이미지 메모를 저장할 수 있습니다.", comment: "Image memo desc")
            }
        }
    }
}
