//
//  ProStatusManager.swift
//  ClipKeyboard
//
//  Created by Claude on 2026/02/18.
//

import Foundation

/// Pro 상태 및 무료 제한 관리
/// ProFeatureManager와 App Group UserDefaults 키를 공유한다 (키보드 익스텐션에서도 같은 값을 읽도록).
class ProStatusManager: ObservableObject {
    static let shared = ProStatusManager()

    // MARK: - 무료 제한 상수
    // Note: Source of truth는 ProFeatureManager.freeMemoLimit 등. 이 struct는 레거시 참조용.

    struct FreeLimits {
        static var maxMemos: Int { ProFeatureManager.memoLimit }
        static var maxClipboardHistory: Int { ProFeatureManager.freeClipboardHistoryLimit }
        static var maxTemplates: Int { ProFeatureManager.freeTemplateLimit }
    }

    // MARK: - Published Properties

    @Published var isPro: Bool = false

    // MARK: - Private

    // ProFeatureManager와 키를 통일 (이전 "com.ysoup.tokenmemo.isPro" 키는 누락돼 Pro 구매 상태가 ProFeatureManager에 전달되지 않던 버그가 있었음)
    private let proStatusKey = ProFeatureManager.proStatusKey
    private let userDefaults = AppGroup.defaults

    // MARK: - Init

    private init() {
        migrateLegacyProKeyIfNeeded()
        loadProStatus()
    }

    /// v3.x에서 "com.ysoup.tokenmemo.isPro" 키에 저장하던 Pro 상태를 신규 통합 키로 이관.
    /// StoreKit 재동기화가 늦는 경우에도 업그레이드 직후 Pro 권한이 유지되도록 한다.
    private func migrateLegacyProKeyIfNeeded() {
        guard let defaults = userDefaults else { return }
        let legacyKey = ProFeatureManager.legacyV3ProKey
        let unifiedKey = ProFeatureManager.proStatusKey
        // 이미 통합 키에 값이 있다면 건드리지 않음.
        if defaults.object(forKey: unifiedKey) != nil { return }
        if let legacyPro = defaults.object(forKey: legacyKey) as? Bool {
            defaults.set(legacyPro, forKey: unifiedKey)
            print("🔄 [ProStatusManager] 레거시 Pro 키 이관: \(legacyPro)")
        }
    }

    /// v4.0 첫 실행 시 그랜드파더 플래그 설정. 호출 시점:
    /// - 앱 시작 직후 (ClipKeyboardApp.init / onAppear 근처)
    ///
    /// `memos` 는 저장된 단축어 **전부**를 넘긴다. 세는 일은 여기서 한다 - 샘플은 뺀다.
    ///
    /// ⚠️ 예전에는 개수를 그대로 받아서, 온보딩이 방금 심어 준 샘플까지 "기존에 쓰던
    ///    메모"로 셌다. 샘플을 심는 게 이 판정보다 먼저라, **새로 받은 사람이 전부**
    ///    `existingFreeUser` 가 됐다. 한도·체험·동기화 게이트가 신규 설치에서 모두 풀렸고,
    ///    허브 통계에서도 무료 사용자가 늘지 않았다.
    ///
    /// ⚠️ 결제 이력(`wasProAtV3`)은 여기서 **새기지 않는다.** 예전에는 "지금 Pro 면 영구
    ///    true" 였고, 그래서 환불한 사람도 평생 Pro 로 남았다. 그 키는 v4.0 이전에 앱을
    ///    산 사람 전용이고, 판정은 `ProFeatureManager.grandfatherPaidUserIfNeeded` 한 곳이 한다.
    func bootstrapV4GrandfatherFlags(memos: [Memo]) {
        guard let defaults = userDefaults else { return }
        let existingMemoCount = ProFeatureManager.ownMemoCount(memos)

        // ⚠️ 기존 무료 유저 표시(`existingFreeUser`)는 **더 이상 켜지 않는다.** 단축어 개수로
        //    v3 사용자를 짐작하던 자리였는데, v3 사용자는 모두 v4.0 이전 다운로드라 영수증
        //    날짜(`grandfatherPaidUserIfNeeded`)가 이미 가려낸다. 짐작은 틀리면 없는 Pro 를
        //    만들었고, 재설치 뒤 iCloud 에서 단축어를 되살린 새 사용자에게 "열려 있던 기능이
        //    닫힌다" 안내를 띄울 수도 있었다(켜자마자 영수증이 걷으므로).

        // 3) 메모 보유량이 새 한도 초과면 grace 플래그
        let overNewLimit = existingMemoCount > ProFeatureManager.freeMemoLimit
        if overNewLimit, !defaults.bool(forKey: ProFeatureManager.graceMemoQuotaKey) {
            defaults.set(true, forKey: ProFeatureManager.graceMemoQuotaKey)
            print("🛡 [ProStatusManager] Grace memo quota 표시됨 (memos=\(existingMemoCount))")
        }
    }

    // MARK: - Public Methods

    /// 메모를 더 추가할 수 있는지 확인
    func canAddMemo(currentCount: Int) -> Bool {
        return ProFeatureManager.canAddMemo(currentCount: currentCount)
    }

    /// 클립보드 히스토리를 더 저장할 수 있는지 확인
    func canAddClipboardHistory(currentCount: Int) -> Bool {
        return ProFeatureManager.hasFullAccess || currentCount < FreeLimits.maxClipboardHistory
    }

    /// 템플릿을 더 추가할 수 있는지 확인
    func canAddTemplate(currentCount: Int) -> Bool {
        return ProFeatureManager.canAddTemplate(currentCount: currentCount)
    }

    /// iCloud 백업 사용 가능 여부 (구매 / 그랜드파더 / 활성 trial)
    var canUseCloudBackup: Bool {
        return ProFeatureManager.hasFullAccess
    }

    /// Combo 기능 사용 가능 여부
    var canUseStack: Bool {
        return ProFeatureManager.hasFullAccess
    }

    /// 보안 메모 사용 가능 여부
    var canUseSecureMemo: Bool {
        return ProFeatureManager.hasFullAccess
    }

    /// 남은 무료 메모 개수
    func remainingFreeMemos(currentCount: Int) -> Int {
        if ProFeatureManager.hasFullAccess { return Int.max }
        return max(0, FreeLimits.maxMemos - currentCount)
    }

    /// Pro 상태 설정 (StoreManager에서 호출)
    func setProStatus(_ isPro: Bool) {
        self.isPro = isPro
        saveProStatus()
        print("✅ [ProStatusManager] IAP 구매 권한 변경: \(isPro)")
        // 결제 외 경로(TestFlight/그랜드파더/체험)까지 합친 실제 접근권한을 함께 찍어 혼동 제거.
        ProFeatureManager.logAccessResolution("구매 권한 변경 후")
    }

    /// Pro 상태 복원 (앱 시작 시 또는 구매 복원 시)
    func restoreProStatus() {
        // StoreManager에서 구매 복원 후 호출됨
        loadProStatus()
    }

    // MARK: - Private Methods

    private func loadProStatus() {
        isPro = userDefaults?.bool(forKey: proStatusKey) ?? false
        print("📥 [ProStatusManager] IAP 구매 권한 로드: \(isPro)")
    }

    private func saveProStatus() {
        userDefaults?.set(isPro, forKey: proStatusKey)
        userDefaults?.synchronize()
        // macOS 앱과 Pro 상태 동기화 (iCloud KV Store)
        NSUbiquitousKeyValueStore.default.set(isPro, forKey: proStatusKey)
        NSUbiquitousKeyValueStore.default.synchronize()
        print("💾 [ProStatusManager] IAP 구매 권한 저장: \(isPro)")
    }
}
