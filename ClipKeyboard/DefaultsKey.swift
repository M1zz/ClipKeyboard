//
//  DefaultsKey.swift
//  ClipKeyboard
//
//  자동 생성 가능 — 정적 UserDefaults 키 단일 출처(Single Source of Truth).
//  메인앱·키보드(ClipKeyboardExtension)·macOS(.tap) 3개 타겟이 공유한다.
//  하드코딩 리터럴 대신 항상 이 상수를 사용할 것.
//

import Foundation

enum DefaultsKey {
    static let autoBackupEnabled = "autoBackupEnabled"
    static let categoryBadgeNudgeDismissed = "categoryBadgeNudgeDismissed"
    static let categoryBadgeVisible = "categoryBadgeVisible"
    static let categoryFeatureEnabledV1 = "category.feature.enabled.v1"
    static let comboModelUnifyMigratedV1 = "comboModelUnifyMigrated_v1"
    static let didRemoveAds = "didRemoveAds"
    static let enabledBuiltInCategoriesV1 = "enabledBuiltInCategories_v1"
    static let entries = "entries"
    static let fontSize = "fontSize"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let hiddenCategoryTabsV1 = "hiddenCategoryTabs_v1"
    static let kbBeaconLastUse = "kb.beacon.lastUse"
    static let kbBeaconPendingCount = "kb.beacon.pendingCount"
    static let keyboardExtensionDidLoad = "keyboard_extension_did_load"
    static let keyboardKoreanEnabled = "keyboardKoreanEnabled"
    static let keyboardPasteCount = "keyboard_paste_count"
    static let keyboardSecurePinHash = "keyboard_secure_pin_hash"
    static let keyboardTypingLang = "keyboardTypingLang"
    static let koreanEnabledMigratedV1 = "koreanEnabledMigrated_v1"
    static let lastBackupDate = "lastBackupDate"
    static let memoCopyCount = "memoCopyCount"
    static let onboarding = "onboarding"
    static let pasteTipDismissed = "pasteTipDismissed"
    static let proValueNudgeDismissedV1 = "proValueNudgeDismissed_v1"
    static let recentEmojis = "recentEmojis"
    static let recentlyUsedCategories = "recentlyUsedCategories"
    static let reviewBannerDismissed = "review_banner_dismissed"
    static let reviewBannerLaterDate = "review_banner_later_date"
    static let sampleTemplateFlagsMigratedV1 = "sampleTemplateFlagsMigrated_v1"
    static let secureMemoEncryptionMigratedV1 = "secureMemoEncryptionMigrated_v1"
    static let showVisualCues = "showVisualCues"
    static let useCaseSelection = "useCaseSelection"
    static let userCategoryColorsV1 = "userCategoryColors_v1"
    static let userCategoryIconsV1 = "userCategoryIcons_v1"
    static let userDefinedCategoriesV1 = "userDefinedCategories_v1"
    static let visualCuesMigratedV1 = "visualCuesMigrated_v1"

    // MARK: - Pro / 그랜드파더링 / 템플릿 (iOS·macOS 공유 — 이전엔 타겟별 중복 정의)
    static let proStatus = "clipkeyboard_is_pro"
    static let wasProAtV3 = "clipkeyboard_was_pro_at_v3"
    static let existingFreeUser = "clipkeyboard_existing_free_user"
    static let v4GraceMemos = "clipkeyboard_v4_grace_memos"
    static let v4GraceBannerDismissed = "clipkeyboard_v4_grace_banner_dismissed"
    static let v4GrandfatherBootstrapDone = "clipkeyboard_v4_grandfather_bootstrap_done"
    static let trialStartedAt = "clipkeyboard_trial_started_at"
    static let trialLastSeen = "clipkeyboard_trial_last_seen"
    static let userTimezone = "clipkeyboard_user_timezone"
    static let userCurrency = "clipkeyboard_user_currency"

    // MARK: - 메모 실시간 동기화 (CKSyncEngine)
    static let memoSyncEnabled = "memoSyncEnabled"
    static let syncEngineState = "sync.engine.state"
    static let syncShadow = "sync.shadow"
    static let syncTombstones = "sync.tombstones"
}
