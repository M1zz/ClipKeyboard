//
//  ProFeatureManagerTests.swift
//  ClipKeyboardTests
//
//  Pro/무료/체험 게이팅 로직 테스트.
//  주의: ProFeatureManager는 App Group UserDefaults를 직접 읽고/쓰는 static struct.
//  TestFlight 환경에서는 isPro가 무조건 true가 되므로 시뮬레이터/디버그 빌드에서 실행 권장.
//

import XCTest
@testable import ClipKeyboard

final class ProFeatureManagerTests: XCTestCase {

    private var groupDefaults: UserDefaults? {
        AppGroup.defaults
    }

    /// 테스트 격리를 위해 모든 ProFeatureManager 관련 키 초기화
    private func clearAllProState() {
        let keys = [
            ProFeatureManager.proStatusKey,
            ProFeatureManager.grandfatheredPurchaseKey,
            ProFeatureManager.existingFreeUserKey,
            ProFeatureManager.graceMemoQuotaKey,
            ProFeatureManager.graceBannerDismissedKey,
            ProFeatureManager.trialStartedAtKey,
            ProFeatureManager.trialLastSeenKey,
            ProFeatureManager.grandfatheredPurchaseRevalidatedKey,
            ProFeatureManager.existingFreeUserRevalidatedKey,
            ProFeatureManager.existingFreeUserRevokedAtKey,
            ProFeatureManager.accessRevokedNoticeSeenKey,
            ProFeatureManager.accessEndingSoonNoticeSeenKey,
            DefaultsKey.sampleMemoIdsV1
        ]
        for key in keys {
            groupDefaults?.removeObject(forKey: key)
        }
    }

    override func setUp() {
        super.setUp()
        clearAllProState()
    }

    override func tearDown() {
        clearAllProState()
        super.tearDown()
    }

    // MARK: - 상수 검증

    func testFreeLimits_AreExpectedValues() {
        XCTAssertEqual(ProFeatureManager.freeMemoLimit, 10)
        XCTAssertEqual(ProFeatureManager.freeStackLimit, 3)
        XCTAssertEqual(ProFeatureManager.freeClipboardHistoryLimit, 50)
        XCTAssertEqual(ProFeatureManager.freeTemplateLimit, 3)
        XCTAssertEqual(ProFeatureManager.freeImageMemoLimit, 5)
        XCTAssertEqual(ProFeatureManager.trialDurationDays, 7)
    }

    // MARK: - 무료 사용자 한도

    func testCanAddMemo_FreeUserUnderLimit_True() throws {
        guard !ProFeatureManager.hasFullAccess else {
            // TestFlight 빌드에서는 항상 Pro라 의미 있는 검증 불가
            throw XCTSkip("TestFlight/Pro 환경에서는 한도 검증을 스킵")
        }
        XCTAssertTrue(ProFeatureManager.canAddMemo(currentCount: 0))
        XCTAssertTrue(ProFeatureManager.canAddMemo(currentCount: 9))
    }

    func testCanAddMemo_FreeUserAtLimit_False() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        XCTAssertFalse(ProFeatureManager.canAddMemo(currentCount: 10))
        XCTAssertFalse(ProFeatureManager.canAddMemo(currentCount: 100))
    }

    func testCanAddStack_FreeUserUnderLimit() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        XCTAssertTrue(ProFeatureManager.canAddStack(currentCount: 2))
        XCTAssertFalse(ProFeatureManager.canAddStack(currentCount: 3))
    }

    func testCanAddTemplate_FreeUserUnderLimit() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        XCTAssertTrue(ProFeatureManager.canAddTemplate(currentCount: 2))
        XCTAssertFalse(ProFeatureManager.canAddTemplate(currentCount: 3))
    }

    func testCanAddImageMemo_FreeUserUnderLimit() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        XCTAssertTrue(ProFeatureManager.canAddImageMemo(currentImageMemoCount: 4))
        XCTAssertFalse(ProFeatureManager.canAddImageMemo(currentImageMemoCount: 5))
    }

    func testClipboardHistoryLimit_FreeUser() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        XCTAssertEqual(ProFeatureManager.clipboardHistoryLimit(), 50)
    }

    // MARK: - Pro/그랜드파더 무제한

    func testCanAddMemo_Grandfathered_AlwaysTrue() {
        groupDefaults?.set(true, forKey: ProFeatureManager.grandfatheredPurchaseKey)
        XCTAssertTrue(ProFeatureManager.canAddMemo(currentCount: 99999))
        XCTAssertTrue(ProFeatureManager.canAddStack(currentCount: 99999))
    }

    func testClipboardHistoryLimit_FullAccess_Higher() {
        groupDefaults?.set(true, forKey: ProFeatureManager.grandfatheredPurchaseKey)
        XCTAssertEqual(ProFeatureManager.clipboardHistoryLimit(), 100)
    }

    func testKeyboardMemoDisplayLimit_FullAccess_Unlimited() {
        groupDefaults?.set(true, forKey: ProFeatureManager.grandfatheredPurchaseKey)
        XCTAssertEqual(ProFeatureManager.keyboardMemoDisplayLimit, Int.max)
    }

    func testKeyboardMemoDisplayLimit_FreeUser_Limited() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        XCTAssertEqual(ProFeatureManager.keyboardMemoDisplayLimit, 10)
    }

    // MARK: - 그랜드파더

    func testIsGrandfathered_TrueIfPurchaseFlag() {
        groupDefaults?.set(true, forKey: ProFeatureManager.grandfatheredPurchaseKey)
        XCTAssertTrue(ProFeatureManager.isGrandfathered)
    }

    func testIsGrandfathered_TrueIfExistingFreeUser() {
        groupDefaults?.set(true, forKey: ProFeatureManager.existingFreeUserKey)
        XCTAssertTrue(ProFeatureManager.isGrandfathered)
    }

    func testIsGrandfathered_FalseIfNoFlag() throws {
        // TestFlight 환경에서는 isGrandfathered와 무관하게 isPro=true가 됨, 그래도 isGrandfathered 자체는 false
        XCTAssertFalse(ProFeatureManager.isGrandfathered)
    }

    // MARK: - 그랜드파더 판정

    /// v4.0 이전에 받은 사람만 구매 그랜드파더다. 그 뒤에 받은 사람은 결제 이력이
    /// 있어도 아니다 - 결제는 `clipkeyboard_is_pro` 가 맡고, 환불되면 꺼져야 한다.
    func testGrandfatheredPurchase_OnlyBeforeFreemiumRelease() {
        let before = ProFeatureManager.freemiumReleaseDate.addingTimeInterval(-1)
        let after = ProFeatureManager.freemiumReleaseDate.addingTimeInterval(86_400)
        XCTAssertTrue(ProFeatureManager.isGrandfatheredPurchase(originalPurchaseDate: before, hadV3ProKey: false))
        XCTAssertFalse(ProFeatureManager.isGrandfatheredPurchase(originalPurchaseDate: after, hadV3ProKey: false),
                       "v4.0 이후 설치는 결제했다 환불해도 그랜드파더로 남으면 안 된다")
        XCTAssertFalse(ProFeatureManager.isGrandfatheredPurchase(originalPurchaseDate: ProFeatureManager.freemiumReleaseDate,
                                                                hadV3ProKey: false))
        XCTAssertTrue(ProFeatureManager.isGrandfatheredPurchase(originalPurchaseDate: after, hadV3ProKey: true),
                      "v3 가 Pro 를 적어 둔 기기는 영수증 날짜와 무관하게 인정")
    }

    /// 첫 실행에 심어 준 샘플만 있는 설치는 기존 사용자가 아니다.
    ///
    /// 샘플을 심는 게 이 판정보다 먼저라, 샘플을 세면 새로 받은 사람이 전부
    /// `existingFreeUser` 가 되어 무료 한도·체험이 통째로 사라진다(실제로 그랬다).
    func testBootstrap_SamplesOnly_IsNotExistingFreeUser() {
        let samples = [Memo(title: "샘플1", value: "a"), Memo(title: "샘플2", value: "b")]
        SampleMemoStorage.save(ids: samples.map(\.id))
        ProStatusManager.shared.bootstrapV4GrandfatherFlags(memos: samples)
        XCTAssertFalse(ProFeatureManager.wasExistingFreeUser)
        XCTAssertFalse(ProFeatureManager.isGrandfathered)
    }

    func testBootstrap_OwnMemo_IsExistingFreeUser() {
        let sample = Memo(title: "샘플", value: "a")
        SampleMemoStorage.save(ids: [sample.id])
        ProStatusManager.shared.bootstrapV4GrandfatherFlags(memos: [sample, Memo(title: "내 것", value: "b")])
        XCTAssertTrue(ProFeatureManager.wasExistingFreeUser)
    }

    /// 부트스트랩은 결제 이력을 새기지 않는다 - 지금 Pro 여도 `wasProAtV3` 는 그대로.
    func testBootstrap_DoesNotRecordPurchaseHistory() {
        groupDefaults?.set(true, forKey: ProFeatureManager.proStatusKey)
        ProStatusManager.shared.bootstrapV4GrandfatherFlags(memos: [])
        XCTAssertFalse(ProFeatureManager.hasGrandfatheredPurchase)
    }

    /// 영수증상 v4.0 이후 설치의 `existingFreeUser` 만 걷는다. v4.0 이전 설치는 그대로.
    func testShouldRevokeExistingFreeUser_OnlyForPostFreemiumInstalls() {
        let before = ProFeatureManager.freemiumReleaseDate.addingTimeInterval(-86_400)
        let after = ProFeatureManager.freemiumReleaseDate.addingTimeInterval(86_400)
        XCTAssertTrue(ProFeatureManager.shouldRevokeExistingFreeUser(wasExistingFreeUser: true,
                                                                      originalPurchaseDate: after, hadV3ProKey: false))
        XCTAssertFalse(ProFeatureManager.shouldRevokeExistingFreeUser(wasExistingFreeUser: true,
                                                                       originalPurchaseDate: before, hadV3ProKey: false))
        XCTAssertFalse(ProFeatureManager.shouldRevokeExistingFreeUser(wasExistingFreeUser: true,
                                                                       originalPurchaseDate: after, hadV3ProKey: true))
        XCTAssertFalse(ProFeatureManager.shouldRevokeExistingFreeUser(wasExistingFreeUser: false,
                                                                       originalPurchaseDate: after, hadV3ProKey: false))
    }

    /// 걷을 때 한 번에 막지 않는다 - 체험 7일이 붙는다.
    func testRevokeExistingFreeUser_StartsTrialAsLanding() throws {
        guard !ProFeatureManager.isTestFlight else { throw XCTSkip("TestFlight 에서는 isPro 라 체험이 시작되지 않는다") }
        groupDefaults?.set(true, forKey: ProFeatureManager.existingFreeUserKey)
        XCTAssertTrue(ProFeatureManager.revokeExistingFreeUser())
        XCTAssertFalse(ProFeatureManager.wasExistingFreeUser)
        XCTAssertTrue(ProFeatureManager.isInTrial)
        XCTAssertTrue(ProFeatureManager.hasFullAccess, "걷은 직후에도 기능은 7일 동안 열려 있다")
        XCTAssertNotNil(groupDefaults?.object(forKey: ProFeatureManager.existingFreeUserRevokedAtKey))
    }

    /// 이미 체험을 쓴 사람에게는 체험이 다시 붙지 않는다.
    func testRevokeExistingFreeUser_TrialAlreadyUsed_NoSecondTrial() throws {
        guard !ProFeatureManager.isTestFlight else { throw XCTSkip("TestFlight 환경") }
        groupDefaults?.set(1.0, forKey: ProFeatureManager.trialStartedAtKey)
        groupDefaults?.set(true, forKey: ProFeatureManager.existingFreeUserKey)
        XCTAssertFalse(ProFeatureManager.revokeExistingFreeUser())
        XCTAssertFalse(ProFeatureManager.wasExistingFreeUser)
        XCTAssertFalse(ProFeatureManager.isInTrial)
    }

    // MARK: - 닫힌다는 안내

    private func notice(revokedAt: TimeInterval? = 0, now: TimeInterval = 86_400,
                        pro: Bool = false, trial: Bool = true, daysLeft: Int = 7,
                        revokedSeen: Bool = false, endingSeen: Bool = false) -> ProFeatureManager.AccessEndingNotice? {
        ProFeatureManager.accessEndingNotice(revokedAt: revokedAt, now: now, hasPermanentPro: pro,
                                             isInTrial: trial, trialDaysRemaining: daysLeft,
                                             revokedSeen: revokedSeen, endingSoonSeen: endingSeen)
    }

    /// 걷지 않은 사람에게는 아무 말도 안 한다 - 보통의 체험 사용자도 마찬가지.
    func testAccessNotice_NotRevoked_Nothing() {
        XCTAssertNil(notice(revokedAt: nil, daysLeft: 1))
    }

    /// 걷은 직후 한 번 - 체험이 남은 날수와 함께. 체험 없이 닫혔으면 0.
    func testAccessNotice_RightAfterRevoke() {
        XCTAssertEqual(notice(daysLeft: 7), .revoked(daysLeft: 7))
        XCTAssertEqual(notice(trial: false, daysLeft: 0), .revoked(daysLeft: 0))
    }

    /// 첫 안내를 닫았으면 마지막 날까지 조용하고, 마지막 날 한 번 더.
    func testAccessNotice_LastDay() {
        XCTAssertNil(notice(daysLeft: 3, revokedSeen: true))
        XCTAssertEqual(notice(daysLeft: 1, revokedSeen: true), .endingSoon)
        XCTAssertNil(notice(daysLeft: 1, revokedSeen: true, endingSeen: true))
    }

    /// 결제했으면 둘 다 안 한다.
    func testAccessNotice_PaidUser_Nothing() {
        XCTAssertNil(notice(pro: true))
        XCTAssertNil(notice(pro: true, daysLeft: 1, revokedSeen: true))
    }

    /// 첫 안내는 체험이 끝나고 하루까지만. 그 뒤로는 새 소식이 아니다.
    func testAccessNotice_RevokedNoticeExpires() {
        let window = TimeInterval(ProFeatureManager.accessRevokedNoticeWindowDays) * 86_400
        XCTAssertNil(notice(revokedAt: 0, now: window + 1, trial: false, daysLeft: 0))
    }

    func testAccessNotice_MarkSeen() {
        ProFeatureManager.markAccessEndingNoticeSeen(.revoked(daysLeft: 7))
        XCTAssertTrue(groupDefaults?.bool(forKey: ProFeatureManager.accessRevokedNoticeSeenKey) ?? false)
        XCTAssertFalse(groupDefaults?.bool(forKey: ProFeatureManager.accessEndingSoonNoticeSeenKey) ?? true)
    }

    // MARK: - 7일 체험

    func testStartTrial_FreshUser_Succeeds() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        XCTAssertTrue(ProFeatureManager.canStartTrial)
        let started = ProFeatureManager.startTrial()
        XCTAssertTrue(started)
        XCTAssertNotNil(ProFeatureManager.trialStartedAt)
        XCTAssertTrue(ProFeatureManager.hasStartedTrial)
        XCTAssertTrue(ProFeatureManager.isInTrial)
    }

    func testStartTrial_AlreadyStarted_ReturnsFalse() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        _ = ProFeatureManager.startTrial()
        let secondTry = ProFeatureManager.startTrial()
        XCTAssertFalse(secondTry, "체험은 1회 한정")
    }

    func testStartTrial_ProUser_ReturnsFalse() {
        groupDefaults?.set(true, forKey: ProFeatureManager.proStatusKey)
        let started = ProFeatureManager.startTrial()
        XCTAssertFalse(started, "Pro는 체험 시작 불가")
    }

    func testStartTrial_Grandfathered_ReturnsFalse() {
        groupDefaults?.set(true, forKey: ProFeatureManager.grandfatheredPurchaseKey)
        let started = ProFeatureManager.startTrial()
        XCTAssertFalse(started)
    }

    func testTrialDaysRemaining_AfterStart_LessThanOrEqualToDuration() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        _ = ProFeatureManager.startTrial()
        let remaining = ProFeatureManager.trialDaysRemaining
        XCTAssertGreaterThan(remaining, 0)
        XCTAssertLessThanOrEqual(remaining, ProFeatureManager.trialDurationDays)
    }

    func testIsInTrial_AfterExpiry_False() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        // 8일 전에 시작했다고 강제 설정
        let eightDaysAgo = Date().timeIntervalSince1970 - (8 * 86400)
        groupDefaults?.set(eightDaysAgo, forKey: ProFeatureManager.trialStartedAtKey)
        groupDefaults?.set(eightDaysAgo, forKey: ProFeatureManager.trialLastSeenKey)
        XCTAssertTrue(ProFeatureManager.hasStartedTrial)
        XCTAssertFalse(ProFeatureManager.isInTrial)
        XCTAssertEqual(ProFeatureManager.trialDaysRemaining, 0)
    }

    func testTrialMonotonicTime_ClockRollback_DoesNotExtendTrial() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        let now = Date().timeIntervalSince1970
        // 체험 5일 전 시작 + 미래 시점까지 lastSeen 기록 (예: 6일 후 본 척)
        groupDefaults?.set(now - 5 * 86400, forKey: ProFeatureManager.trialStartedAtKey)
        groupDefaults?.set(now + 6 * 86400, forKey: ProFeatureManager.trialLastSeenKey)
        // 체험 시작 + 7일 < lastSeen + Δ → 체험 만료로 처리되어야 함
        XCTAssertFalse(ProFeatureManager.isInTrial, "시계 조작(과거로 되돌리기) 방어")
    }

    // MARK: - Grace 배너

    func testMarkGraceBannerDismissed_Persists() {
        XCTAssertFalse(ProFeatureManager.didDismissGraceBanner)
        ProFeatureManager.markGraceBannerDismissed()
        XCTAssertTrue(ProFeatureManager.didDismissGraceBanner)
    }

    // MARK: - LimitType (분석/푸시 메시지용)

    func testLimitType_AnalyticsKeys_Unique() {
        let keys = [
            ProFeatureManager.LimitType.memo.analyticsKey,
            ProFeatureManager.LimitType.stack.analyticsKey,
            ProFeatureManager.LimitType.template.analyticsKey,
            ProFeatureManager.LimitType.clipboardHistory.analyticsKey,
            ProFeatureManager.LimitType.cloudBackup.analyticsKey,
            ProFeatureManager.LimitType.biometricLock.analyticsKey,
            ProFeatureManager.LimitType.themeCustomization.analyticsKey,
            ProFeatureManager.LimitType.imageMemo.analyticsKey
        ]
        XCTAssertEqual(Set(keys).count, keys.count, "analyticsKey는 모두 고유해야 함")
    }

    // MARK: - Feature 게이팅

    func testIsKeyboardExtensionAvailable_AlwaysTrue() {
        XCTAssertTrue(ProFeatureManager.isKeyboardExtensionAvailable)
    }

    func testIsThemeCustomizationAvailable_AlwaysTrue() {
        XCTAssertTrue(ProFeatureManager.isThemeCustomizationAvailable)
    }

    func testIsImageMemoAvailable_AlwaysTrue() {
        XCTAssertTrue(ProFeatureManager.isImageMemoAvailable)
    }

    func testIsCloudBackupAvailable_RequiresFullAccess() {
        groupDefaults?.set(true, forKey: ProFeatureManager.proStatusKey)
        XCTAssertTrue(ProFeatureManager.isCloudBackupAvailable)
    }

    func testIsBiometricLockAvailable_RequiresFullAccess() {
        groupDefaults?.set(true, forKey: ProFeatureManager.proStatusKey)
        XCTAssertTrue(ProFeatureManager.isBiometricLockAvailable)
    }
}
