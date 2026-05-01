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
    // v3.x: 메모 10, 콤보 2 → v4.0: 메모 5, 콤보 1 → v4.1: 메모 10, 콤보 3
    // 노마드 use case 기준 가치 검증 시간 확보를 위해 v4.1에서 한도 상향.
    // 기존 유저는 `isGrandfathered`로 신규 제한 우회 유지.

    /// 무료 메모 최대 개수
    static let freeMemoLimit = 10

    /// 무료 콤보 최대 개수
    static let freeComboLimit = 3

    /// 무료 클립보드 히스토리 최대 개수
    static let freeClipboardHistoryLimit = 50

    /// 무료 템플릿 최대 개수
    static let freeTemplateLimit = 3

    /// 무료 이미지 메모 최대 개수 (이미지가 첨부된 메모 개수 기준)
    static let freeImageMemoLimit = 5

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
    /// 7일 무료 체험 시작 timestamp (epoch). 한 번 설정되면 다시 설정하지 않음 (1회 한정).
    static let trialStartedAtKey = "clipkeyboard_trial_started_at"
    /// 시계 조작 방어용 마지막 본 시점 (epoch). 매 launch마다 max(now, lastSeen)로 갱신.
    static let trialLastSeenKey = "clipkeyboard_trial_last_seen"

    /// 무료 체험 기간 (일)
    static let trialDurationDays = 7

    // MARK: - Pro 전용 기능 플래그

    /// 모든 Pro 기능에 무제한 접근 가능 — 구매(Pro) / v3.x 그랜드파더 / 활성 7일 체험
    static var hasFullAccess: Bool {
        isPro || isGrandfathered || isInTrial
    }

    /// iCloud 백업 사용 가능 여부
    static var isCloudBackupAvailable: Bool { hasFullAccess }

    /// 생체인증 잠금 사용 가능 여부
    static var isBiometricLockAvailable: Bool { hasFullAccess }

    /// 테마 커스터마이징 사용 가능 여부 (v4.1부터 무료 개방)
    static var isThemeCustomizationAvailable: Bool { true }

    /// 이미지 메모 사용 가능 여부 (v4.1부터 무료 유저도 freeImageMemoLimit개까지 가능)
    static var isImageMemoAvailable: Bool { true }

    /// 키보드 익스텐션은 모든 유저에게 무료 개방.
    /// 무료 유저는 freeMemoLimit 개수만큼만 표시됨.
    static var isKeyboardExtensionAvailable: Bool { true }

    /// 키보드에서 표시할 메모 최대 개수.
    static var keyboardMemoDisplayLimit: Int {
        hasFullAccess ? Int.max : freeMemoLimit
    }

    // MARK: - 상태 체크

    private static var groupDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupSuite)
    }

    /// TestFlight 빌드 여부 (샌드박스 영수증 감지)
    static var isTestFlight: Bool {
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    /// Pro 여부 (TestFlight 베타 사용자는 자동 Pro 활성화)
    static var isPro: Bool {
        if isTestFlight { return true }
        return groupDefaults?.bool(forKey: proStatusKey) ?? false
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

    // MARK: - 7일 무료 체험 (Trial)

    /// 시계 조작 방어용 "현재 시점" — 항상 단조 증가하도록 max(now, lastSeen) 적용.
    /// 사용자가 시계를 뒤로 돌려도 trial 잔여 시간이 늘어나지 않는다.
    /// 시계를 앞으로 돌리면 trial 만료가 빨라지지만, 그건 사용자가 손해 보는 방향이라 OK.
    private static var monotonicNow: TimeInterval {
        let now = Date().timeIntervalSince1970
        let lastSeen = groupDefaults?.double(forKey: trialLastSeenKey) ?? 0
        let effective = max(now, lastSeen)
        // 새 최댓값으로 lastSeen 갱신 (단조성 유지)
        if effective > lastSeen {
            groupDefaults?.set(effective, forKey: trialLastSeenKey)
        }
        return effective
    }

    /// 체험 시작 timestamp (없으면 nil)
    static var trialStartedAt: TimeInterval? {
        let value = groupDefaults?.double(forKey: trialStartedAtKey) ?? 0
        return value > 0 ? value : nil
    }

    /// 체험을 한 번이라도 시작한 적 있는지 (재시작 방지용)
    static var hasStartedTrial: Bool {
        trialStartedAt != nil
    }

    /// 체험 활성 여부 (시작 + 미만료)
    static var isInTrial: Bool {
        guard let startedAt = trialStartedAt else { return false }
        let durationSeconds = TimeInterval(trialDurationDays) * 86400
        return monotonicNow < startedAt + durationSeconds
    }

    /// 체험 남은 일수 (활성 중일 때만 의미 있음). 0이면 오늘 만료.
    static var trialDaysRemaining: Int {
        guard let startedAt = trialStartedAt else { return 0 }
        let durationSeconds = TimeInterval(trialDurationDays) * 86400
        let remainingSeconds = (startedAt + durationSeconds) - monotonicNow
        guard remainingSeconds > 0 else { return 0 }
        return Int(ceil(remainingSeconds / 86400))
    }

    /// 체험 시작 가능 여부 — 아직 안 했고, 이미 Pro도 아니고, 그랜드파더도 아닌 경우
    static var canStartTrial: Bool {
        !hasStartedTrial && !isPro && !isGrandfathered
    }

    /// 체험 시작 (1회 한정, idempotent)
    /// - Returns: 실제로 시작된 경우 true, 이미 시작된 적 있거나 자격 없음이면 false
    @discardableResult
    static func startTrial() -> Bool {
        guard canStartTrial else {
            print("ℹ️ [ProFeatureManager] 체험 시작 불가 (이미 시작됨/Pro/그랜드파더)")
            return false
        }
        groupDefaults?.set(monotonicNow, forKey: trialStartedAtKey)
        print("🎁 [ProFeatureManager] 7일 무료 체험 시작")
        return true
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
        if hasFullAccess { return true }
        return currentCount < freeMemoLimit
    }

    /// 콤보 추가 가능 여부
    static func canAddCombo(currentCount: Int) -> Bool {
        if hasFullAccess { return true }
        return currentCount < freeComboLimit
    }

    /// 템플릿 추가 가능 여부
    static func canAddTemplate(currentCount: Int) -> Bool {
        if hasFullAccess { return true }
        return currentCount < freeTemplateLimit
    }

    /// 이미지 메모 추가 가능 여부 (currentImageMemoCount = 이미지가 첨부된 메모 수)
    static func canAddImageMemo(currentImageMemoCount: Int) -> Bool {
        if hasFullAccess { return true }
        return currentImageMemoCount < freeImageMemoLimit
    }

    /// 클립보드 히스토리 제한
    static func clipboardHistoryLimit() -> Int {
        return hasFullAccess ? 100 : freeClipboardHistoryLimit
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

        /// Analytics 슬라이싱용 안정된 영문 키 (locale 무관)
        var analyticsKey: String {
            switch self {
            case .memo: return "memo"
            case .combo: return "combo"
            case .template: return "template"
            case .clipboardHistory: return "clipboard_history"
            case .cloudBackup: return "cloud_backup"
            case .biometricLock: return "biometric_lock"
            case .themeCustomization: return "theme"
            case .imageMemo: return "image_memo"
            }
        }

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
                return String(format: NSLocalizedString("무료 버전에서는 최대 %d개의 이미지 메모를 저장할 수 있습니다.", comment: "Image memo limit desc"), freeImageMemoLimit)
            }
        }
    }
}
