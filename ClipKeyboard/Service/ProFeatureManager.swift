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

    // MARK: - 무료 제한 설정 (v4.0)
    // v3.x: 메모 10, 콤보 2 → v4.0: 메모 5, 콤보 1
    // 기존 유저는 `isGrandfathered`로 새 제한 우회 (P0 참조)

    /// 무료 메모 최대 개수
    static let freeMemoLimit = 5

    /// 무료 콤보 최대 개수
    static let freeComboLimit = 1

    /// 무료 클립보드 히스토리 최대 개수
    static let freeClipboardHistoryLimit = 20

    /// 무료 템플릿 최대 개수
    static let freeTemplateLimit = 3

    // MARK: - App Group UserDefaults 키 (키보드 익스텐션과 공유)

    static let appGroupSuite = "group.com.Ysoup.TokenMemo"
    static let proStatusKey = "clipkeyboard_is_pro"
    /// v4.0 업그레이드 시점에 v3.x Pro 구매 이력이 확인되면 영구 true.
    static let grandfatheredPurchaseKey = "clipkeyboard_was_pro_at_v3"
    /// v4.0 업그레이드 시점에 메모를 1개 이상 가진 기존 유저를 표시. 키보드 익스텐션 등의
    /// 기존 가용 기능은 유지하고, 신규 추가만 새 제한을 적용한다.
    static let existingFreeUserKey = "clipkeyboard_existing_free_user"
    /// v4.0 업그레이드 시 메모 보유량이 새 한도를 초과해 grace 상태가 된 유저.
    static let graceMemoQuotaKey = "clipkeyboard_v4_grace_memos"
    /// v4.0 grace 배너를 이미 닫은 유저.
    static let graceBannerDismissedKey = "clipkeyboard_v4_grace_banner_dismissed"

    // MARK: - Pro 전용 기능 플래그

    /// iCloud 백업 사용 가능 여부
    static var isCloudBackupAvailable: Bool { isPro }

    /// 생체인증 잠금 사용 가능 여부
    static var isBiometricLockAvailable: Bool { isPro }

    /// 테마 커스터마이징 사용 가능 여부
    static var isThemeCustomizationAvailable: Bool { isPro }

    /// 이미지 메모 사용 가능 여부
    static var isImageMemoAvailable: Bool { isPro }

    /// 키보드 익스텐션 사용 가능 여부 (v4.0 신규 잠금)
    /// - Pro 구매자: 항상 true
    /// - v3.x Pro 그랜드파더: 항상 true
    /// - v3.x 무료 기존 유저: 항상 true (기존 경험 유지)
    /// - 신규 v4.0 무료 유저: false → Paywall
    static var isKeyboardExtensionAvailable: Bool {
        isPro || hasGrandfatheredPurchase || wasExistingFreeUser
    }

    // MARK: - 상태 체크

    private static var groupDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupSuite)
    }

    /// Pro 여부 (StoreManager에서 가져옴)
    static var isPro: Bool {
        groupDefaults?.bool(forKey: proStatusKey) ?? false
    }

    /// v3.x에서 Pro 구매 이력이 있는 유저 여부. v4.0 첫 실행 시 영수증 검증으로 설정되며, 이후 영구 유지.
    static var hasGrandfatheredPurchase: Bool {
        groupDefaults?.bool(forKey: grandfatheredPurchaseKey) ?? false
    }

    /// v3.x 기존 무료 유저 여부 (메모 하나라도 저장했던 유저). 키보드 익스텐션 기본 접근 보장용.
    static var wasExistingFreeUser: Bool {
        groupDefaults?.bool(forKey: existingFreeUserKey) ?? false
    }

    /// 업그레이드 그랜드파더 상태 (Pro 구매자 or 기존 유저)를 통합적으로 판단.
    /// 신규 제한을 적용하지 않아야 하는 경우 true.
    static var isGrandfathered: Bool {
        hasGrandfatheredPurchase || wasExistingFreeUser
    }

    /// v4.0 업그레이드 당시 메모가 새 한도를 초과했던 유저.
    static var hasGraceMemoQuota: Bool {
        groupDefaults?.bool(forKey: graceMemoQuotaKey) ?? false
    }

    /// grace 배너 노출이 이미 닫혔는지.
    static var didDismissGraceBanner: Bool {
        groupDefaults?.bool(forKey: graceBannerDismissedKey) ?? false
    }

    static func markGraceBannerDismissed() {
        groupDefaults?.set(true, forKey: graceBannerDismissedKey)
    }

    // MARK: - 제한 체크

    /// 메모 추가 가능 여부
    static func canAddMemo(currentCount: Int) -> Bool {
        if isPro || isGrandfathered { return true }
        return currentCount < freeMemoLimit
    }

    /// 콤보 추가 가능 여부
    static func canAddCombo(currentCount: Int) -> Bool {
        if isPro || isGrandfathered { return true }
        return currentCount < freeComboLimit
    }

    /// 템플릿 추가 가능 여부
    static func canAddTemplate(currentCount: Int) -> Bool {
        if isPro || isGrandfathered { return true }
        return currentCount < freeTemplateLimit
    }

    /// 클립보드 히스토리 제한
    static func clipboardHistoryLimit() -> Int {
        return (isPro || isGrandfathered) ? 100 : freeClipboardHistoryLimit
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
