//
//  ProFeatureManager.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2026/02/21.
//

import Foundation
import StoreKit

/// Pro 기능 제한 관리
/// - 무료 사용자 제한 정의
/// - 제한 도달 여부 체크
/// - Pro 기능 게이팅
struct ProFeatureManager {

    // MARK: - 무료 제한 설정
    // v3.x: 메모 10, 콤보 2 → v4.0: 메모 5, 콤보 1 → v4.1: 메모 10, 콤보 3
    // 노마드 use case 기준 가치 검증 시간 확보를 위해 v4.1에서 한도 상향.
    // 기존 유저는 `isGrandfathered`로 신규 제한 우회 유지.

    /// 무료 메모 최대 개수 - **기본값.** 실제로 쓸 수 있는 개수는 `memoLimit` 이다.
    /// (칸 추가 상품을 산 사람은 이 값보다 많다)
    static let freeMemoLimit = 10

    /// 지금 이 사람이 쓸 수 있는 단축어 개수.
    ///
    /// Pro 면 무제한, 아니면 기본 한도에 **산 칸수**를 더한 값이다.
    /// ⚠️ 한도를 묻는 곳은 전부 이 값을 봐야 한다. `freeMemoLimit` 을 직접 보면
    ///    칸을 산 사람에게 "10개까지" 라고 말하게 된다.
    static var memoLimit: Int {
        hasFullAccess ? Int.max : freeMemoLimit + SlotPack.purchasedSlots
    }

    /// 무료 콤보 최대 개수
    static let freeStackLimit = 3

    /// 무료 클립보드 히스토리 최대 개수
    static let freeClipboardHistoryLimit = 50

    /// 무료 템플릿 최대 개수
    static let freeTemplateLimit = 3

    /// 무료 이미지 메모 최대 개수 (이미지가 첨부된 메모 개수 기준)
    static let freeImageMemoLimit = 5

    // MARK: - App Group UserDefaults 키 (키보드 익스텐션과 공유)

    // 키 리터럴은 DefaultsKey 단일 출처에서 관리.
    static let proStatusKey = DefaultsKey.proStatus
    /// v4.0 업그레이드 시점에 v3.x Pro 구매 이력이 확인되면 영구 true.
    static let grandfatheredPurchaseKey = DefaultsKey.wasProAtV3
    /// v4.0 업그레이드 시점에 메모를 1개 이상 가진 기존 유저를 표시. 키보드 익스텐션 등의
    /// 기존 가용 기능은 유지하고, 신규 추가만 새 제한을 적용한다.
    static let existingFreeUserKey = DefaultsKey.existingFreeUser
    /// v4.0 업그레이드 시 메모 보유량이 새 한도를 초과해 grace 상태가 된 유저.
    static let graceMemoQuotaKey = DefaultsKey.v4GraceMemos
    /// v4.0 grace 배너를 이미 닫은 유저.
    static let graceBannerDismissedKey = DefaultsKey.v4GraceBannerDismissed
    /// 7일 무료 체험 시작 timestamp (epoch). 한 번 설정되면 다시 설정하지 않음 (1회 한정).
    static let trialStartedAtKey = DefaultsKey.trialStartedAt
    /// 시계 조작 방어용 마지막 본 시점 (epoch). 매 launch마다 max(now, lastSeen)로 갱신.
    static let trialLastSeenKey = DefaultsKey.trialLastSeen

    /// 무료 체험 기간 (일)
    static let trialDurationDays = 7

    // MARK: - Pro 전용 기능 플래그

    /// 모든 Pro 기능에 무제한 접근 가능 - 구매(Pro) / v3.x 그랜드파더 / 활성 7일 체험
    static var hasFullAccess: Bool {
        isPro || isGrandfathered || isInTrial
    }

    /// 영구적인 Pro 권한 보유 여부 - 구매(Pro) / v3.x 그랜드파더 / TestFlight.
    /// 체험(trial)은 일부러 제외한다(체험 유저에겐 "평생 Pro" 업셀을 계속 보여줘야 하므로).
    ///
    /// ⚠️ UI에서 "Pro 활성화됨 vs 업그레이드 유도"를 결정할 땐 반드시 이 값을 쓴다.
    /// `StoreManager.isPro`(실제 결제 entitlement만 봄)를 쓰면 그랜드파더/TestFlight 유저가
    /// 기능은 다 열려 있는데도 "업그레이드" 안내를 보게 되는 불일치가 생긴다.
    static var hasPermanentPro: Bool {
        isPro || isGrandfathered
    }

    /// iCloud 백업 사용 가능 여부
    static var isCloudBackupAvailable: Bool { hasFullAccess }

    /// 생체인증 잠금 사용 가능 여부
    static var isBiometricLockAvailable: Bool { hasFullAccess }

    /// 기기 사이 동기화 사용 가능 여부.
    ///
    /// Pro 면 당연히 되고, **두 대째 상품(`TwoDevicePack`)만 산 사람도 된다.**
    /// ⚠️ 동기화를 묻는 곳은 전부 이 값을 봐야 한다. `hasFullAccess` 를 직접 보면
    ///    두 대째를 산 사람이 돈을 내고도 토글을 못 켠다.
    static var isSyncAvailable: Bool { hasFullAccess || TwoDevicePack.isPurchased }

    /// 테마 커스터마이징 사용 가능 여부 (v4.1부터 무료 개방)
    static var isThemeCustomizationAvailable: Bool { true }

    /// 이미지 메모 사용 가능 여부 (v4.1부터 무료 유저도 freeImageMemoLimit개까지 가능)
    static var isImageMemoAvailable: Bool { true }

    /// 키보드 익스텐션은 모든 유저에게 무료 개방.
    /// 무료 유저는 freeMemoLimit 개수만큼만 표시됨.
    static var isKeyboardExtensionAvailable: Bool { true }

    /// 키보드에서 표시할 메모 최대 개수.
    /// (칸을 산 사람은 그만큼 더 보인다 - `memoLimit` 이 이미 그 계산을 한다)
    ///
    /// ⚠️ 이 숫자로 목록을 앞에서 자르지 않는다. 자르는 일은 `memosWithinLimit` 이 한다.
    ///    샘플은 칸을 차지하지 않아서, 몇 개를 남길지는 자기 것만 세어야 정해진다.
    static var keyboardMemoDisplayLimit: Int { memoLimit }

    // MARK: - 상태 체크

    private static var groupDefaults: UserDefaults? {
        AppGroup.defaults
    }

    /// TestFlight 빌드 여부 - 앱 시작 시 bootstrapIsTestFlight()로 설정.
    nonisolated(unsafe) static var isTestFlight: Bool = false

    /// AppTransaction으로 TestFlight/Sandbox 환경 감지 후 캐시 저장.
    /// ClipKeyboardApp.init()에서 Task로 호출.
    static func bootstrapIsTestFlight() async {
        do {
            let result = try await AppTransaction.shared
            if case .verified(let transaction) = result {
                isTestFlight = transaction.environment == .xcode || transaction.environment == .sandbox
            }
        } catch {
            isTestFlight = false
        }
    }

    // MARK: - v4.0 이전 유료 앱 구매자 그랜드파더

    /// v4.0(무료 + Pro IAP) App Store 출시 시각.
    /// 앱은 이 시점까지 "유료 앱(다운로드 유료)"이었고 이후 무료로 전환됐다.
    /// 따라서 이 시점 **이전**에 앱을 최초 구매(다운로드)한 사용자는 유료 구매자이므로
    /// 영구 Pro로 인정한다.
    ///
    /// 실제 출시: 2026-02-21 00:14 KST. 타임존/심사 전파 오차로 인해 유료 구매자가
    /// 누락되는 일이 없도록 컷오프를 다음 날 자정(KST)으로 넉넉히 잡는다 - 유료 구매자
    /// 누락(=0)을 최우선하고, 그 대가로 초기 무료 다운로더 극소수가 Pro가 될 수 있는 건 허용.
    /// 값: 2026-02-22 00:00:00 KST = 2026-02-21 15:00:00 UTC = epoch 1_771_686_000.
    static let freemiumReleaseDate = Date(timeIntervalSince1970: 1_771_686_000)

    /// v3.x 가 Pro 상태를 적던 옛 자리. v4.0 첫 실행에 통합 키로 옮겨졌고, 지우지 않고 남아 있다.
    /// v4.0 이전 사용자라는 **기기 쪽 증거**로도 쓴다(`isGrandfatheredPurchase`).
    static let legacyV3ProKey = "com.ysoup.tokenmemo.isPro"

    /// `wasProAtV3` 를 영수증으로 한 번 다시 확인했는가. 결제 이력으로 잘못 새겨진 값을 걷어 낸 뒤 켠다.
    static let grandfatheredPurchaseRevalidatedKey = "clipkeyboard_was_pro_at_v3_revalidated"

    /// `existingFreeUser` 를 영수증으로 한 번 다시 확인했는가.
    static let existingFreeUserRevalidatedKey = "clipkeyboard_existing_free_user_revalidated"

    /// 잘못 켜졌던 `existingFreeUser` 를 걷어 낸 시각. 한 번 걷힌 설치를 통계와 진단에서 가르는 표시다.
    static let existingFreeUserRevokedAtKey = "clipkeyboard_existing_free_user_revoked_at"

    /// 켜져 있는 `existingFreeUser` 가 **잘못 켜진 것**인가.
    ///
    /// 이 표시는 v3.x 에서 넘어온 사람의 것인데, 온보딩 샘플을 "기존 메모" 로 세던 시절에
    /// v4.0 이후 새로 받은 사람까지 전부 켜졌다. 영수증의 최초 다운로드일이 v4.0 이후면
    /// 넘어온 사람일 수가 없다.
    static func shouldRevokeExistingFreeUser(wasExistingFreeUser: Bool,
                                             originalPurchaseDate: Date,
                                             hadV3ProKey: Bool) -> Bool {
        wasExistingFreeUser && !isGrandfatheredPurchase(originalPurchaseDate: originalPurchaseDate,
                                                         hadV3ProKey: hadV3ProKey)
    }

    /// 잘못 켜졌던 `existingFreeUser` 를 걷는다. **한 번에 막지 않는다** - 7일 체험을 붙인다.
    ///
    /// 이 사람들은 몇 달을 한도 없이 써 왔다. 표시만 지우면 다음 실행에 키보드에서
    /// 단축어가 사라진 것처럼 보인다(한도 밖은 `memosWithinLimit` 이 가린다 - 지우지는 않는다).
    /// 체험 7일은 그 사이에 결제하든 정리하든 고를 시간이다. 이미 체험을 쓴 사람이나
    /// 지금 결제한 사람에게는 붙지 않는다(`canStartTrial`).
    ///
    /// - Returns: 체험이 새로 시작됐는가.
    @discardableResult
    static func revokeExistingFreeUser() -> Bool {
        groupDefaults?.removeObject(forKey: existingFreeUserKey)
        groupDefaults?.set(Date().timeIntervalSince1970, forKey: existingFreeUserRevokedAtKey)
        let trial = startTrial()
        print("🧹 [ProFeatureManager] 샘플로 잘못 켜졌던 기존 무료 유저 회수 (체험 시작=\(trial))")
        return trial
    }

    /// v4.0 이전에 앱을 산 사람인가 - `wasProAtV3` 의 **유일한** 판정.
    ///
    /// ⚠️ 여기에 "지금 결제 권한이 있다" 를 섞지 않는다. 예전에는 Pro 가 한 번이라도
    ///    켜지면 이 키를 영구히 켰고, 그래서 **환불·취소한 사람이 평생 Pro** 로 남았다
    ///    (허브 통계에도 계속 결제로 올라갔다). 지금 결제는 `clipkeyboard_is_pro` 가
    ///    StoreKit 을 따라 켜지고 꺼지며 맡는다.
    static func isGrandfatheredPurchase(originalPurchaseDate: Date, hadV3ProKey: Bool) -> Bool {
        hadV3ProKey || originalPurchaseDate < freemiumReleaseDate
    }

    /// v4.0 이전 유료 구매자를 AppTransaction(Apple ID에 묶인 최초 구매 영수증)으로 식별해
    /// 영구 그랜드파더 Pro를 부여한다.
    /// - iOS의 `originalAppVersion`은 마케팅 버전이 아니라 빌드 번호라 신뢰 불가 →
    ///   `originalPurchaseDate`를 v4.0 출시일과 비교해 판별한다.
    /// - Apple ID 영수증 기반이라 재설치 / 기기 변경 / 데이터 초기화 후에도 유지된다.
    /// - 이미 그랜드파더로 **확인된** 상태면 즉시 종료 (idempotent - 매 실행 호출해도 안전).
    ///
    /// 한 번은 **켜져 있는 값도 다시 확인한다.** 결제 이력으로 새겨졌던 값(환불해도 안 꺼지던
    /// 것)을 걷어 내기 위해서다. 지금 결제한 사람은 `clipkeyboard_is_pro` 로 그대로 Pro 라
    /// 잃는 것이 없고, 잃는 사람은 v4.0 이후에 받아 결제했다가 환불·취소한 사람뿐이다.
    /// 영수증을 못 읽으면 아무것도 바꾸지 않고 다음 실행에 다시 본다.
    /// 호출 시점: ClipKeyboardApp.init() / 구매 복원 직후.
    ///
    /// 같은 영수증으로 `existingFreeUser` 도 한 번 다시 확인한다(`shouldRevokeExistingFreeUser`).
    static func grandfatherPaidUserIfNeeded() async {
        let purchaseSettled = hasGrandfatheredPurchase
            && (groupDefaults?.bool(forKey: grandfatheredPurchaseRevalidatedKey) ?? false)
        let freeUserSettled = !wasExistingFreeUser
            || (groupDefaults?.bool(forKey: existingFreeUserRevalidatedKey) ?? false)
        if purchaseSettled && freeUserSettled { return }

        do {
            let result = try await AppTransaction.shared
            guard case .verified(let appTransaction) = result else {
                print("⚠️ [ProFeatureManager] AppTransaction 미검증, 유료 구매자 판별 보류")
                return
            }

            let hadV3ProKey = groupDefaults?.bool(forKey: legacyV3ProKey) ?? false
            let entitled = isGrandfatheredPurchase(originalPurchaseDate: appTransaction.originalPurchaseDate,
                                                   hadV3ProKey: hadV3ProKey)
            let before = hasGrandfatheredPurchase
            if entitled {
                groupDefaults?.set(true, forKey: grandfatheredPurchaseKey)
                if !before {
                    print("🛡 [ProFeatureManager] v4.0 이전 유료 앱 구매자 → 그랜드파더 Pro 부여 (originalPurchase=\(appTransaction.originalPurchaseDate))")
                }
            } else {
                groupDefaults?.removeObject(forKey: grandfatheredPurchaseKey)
                print(before
                      ? "🧹 [ProFeatureManager] 결제 이력으로 새겨졌던 그랜드파더 회수 (originalPurchase=\(appTransaction.originalPurchaseDate))"
                      : "ℹ️ [ProFeatureManager] v4.0 이후 최초 다운로드, 그랜드파더 비대상 (originalPurchase=\(appTransaction.originalPurchaseDate))")
            }
            groupDefaults?.set(true, forKey: grandfatheredPurchaseRevalidatedKey)

            var revoked = false
            if shouldRevokeExistingFreeUser(wasExistingFreeUser: wasExistingFreeUser,
                                            originalPurchaseDate: appTransaction.originalPurchaseDate,
                                            hadV3ProKey: hadV3ProKey) {
                revokeExistingFreeUser()
                revoked = true
            }
            groupDefaults?.set(true, forKey: existingFreeUserRevalidatedKey)

            if before != entitled || revoked {
                // hasFullAccess를 보는 화면들이 재렌더되도록 ProStatusManager에 변경 알림
                await MainActor.run {
                    ProStatusManager.shared.objectWillChange.send()
                    mirrorSyncEntitlement()
                }
            }
            if revoked {
                // 목록 화면은 이 판정보다 먼저 뜬다 - 안내 배너가 다음 실행까지 기다리지 않게.
                NotificationCenter.postOnMain(name: .accessRevoked, object: nil)
            }
        } catch {
            print("⚠️ [ProFeatureManager] AppTransaction 조회 실패, 다음 실행에 재시도: \(error)")
        }
    }

    // MARK: - 열려 있던 기능이 닫힌다는 안내

    /// 잘못 열려 있던 기능을 걷은 사람에게 **무엇을 말할 차례인가.**
    ///
    /// 몇 달을 한도 없이 쓴 사람이다. 말없이 닫으면 "업데이트했더니 단축어가 사라졌다" 가
    /// 된다(한도 밖은 키보드에서 가려진다). 그래서 두 번 말한다 - 걷은 직후 한 번,
    /// 체험이 하루 남았을 때 한 번. 결제한 사람에게는 둘 다 안 한다.
    enum AccessEndingNotice: Equatable {
        /// 걷은 직후. `daysLeft` 가 0 이면 체험 없이 바로 닫힌 것이다(이미 체험을 쓴 사람).
        case revoked(daysLeft: Int)
        /// 체험이 하루 안으로 남았다.
        case endingSoon
    }

    static let accessRevokedNoticeSeenKey = "clipkeyboard_access_revoked_notice_seen"
    static let accessEndingSoonNoticeSeenKey = "clipkeyboard_access_ending_soon_notice_seen"

    /// 걷은 직후 안내를 띄우는 기간. 체험(7일)이 끝나고 하루를 더 둔다 - 체험 없이 바로
    /// 닫힌 사람도 그 사이에 한 번은 앱을 열 것이고, 그 뒤로는 새 소식이 아니다.
    static let accessRevokedNoticeWindowDays = trialDurationDays + 1

    /// 상태만 받아 판정한다(테스트용으로 순수하게 둔다). `accessEndingNoticeNow` 가 실제 값을 넣는다.
    static func accessEndingNotice(revokedAt: TimeInterval?,
                                   now: TimeInterval,
                                   hasPermanentPro: Bool,
                                   isInTrial: Bool,
                                   trialDaysRemaining: Int,
                                   revokedSeen: Bool,
                                   endingSoonSeen: Bool) -> AccessEndingNotice? {
        guard let revokedAt, !hasPermanentPro else { return nil }
        if !revokedSeen,
           now < revokedAt + TimeInterval(accessRevokedNoticeWindowDays) * 86_400 {
            return .revoked(daysLeft: isInTrial ? trialDaysRemaining : 0)
        }
        if isInTrial, trialDaysRemaining <= 1, !endingSoonSeen {
            return .endingSoon
        }
        return nil
    }

    /// 지금 이 기기에서 띄울 안내.
    static var accessEndingNoticeNow: AccessEndingNotice? {
        let revokedAt = groupDefaults?.double(forKey: existingFreeUserRevokedAtKey) ?? 0
        return accessEndingNotice(revokedAt: revokedAt > 0 ? revokedAt : nil,
                                  now: Date().timeIntervalSince1970,
                                  hasPermanentPro: hasPermanentPro,
                                  isInTrial: isInTrial,
                                  trialDaysRemaining: trialDaysRemaining,
                                  revokedSeen: groupDefaults?.bool(forKey: accessRevokedNoticeSeenKey) ?? false,
                                  endingSoonSeen: groupDefaults?.bool(forKey: accessEndingSoonNoticeSeenKey) ?? false)
    }

    /// 닫았거나 눌렀으면 그 안내는 다시 안 띄운다.
    static func markAccessEndingNoticeSeen(_ notice: AccessEndingNotice) {
        switch notice {
        case .revoked:    groupDefaults?.set(true, forKey: accessRevokedNoticeSeenKey)
        case .endingSoon: groupDefaults?.set(true, forKey: accessEndingSoonNoticeSeenKey)
        }
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

    /// 실제 접근 권한(`hasFullAccess`)을 App Group + iCloud KV 에 미러링한다.
    /// 공유 동기화 엔진(`MemoSyncEngine`)은 iOS 전용 타입을 못 보므로 이 키로 게이트를 판단한다.
    /// 앱 시작·구매 상태 변화 시 호출 - 안 부르면 그랜드파더/TestFlight/체험 사용자는
    /// 토글을 켜도 엔진이 시작되지 않는다.
    static func mirrorSyncEntitlement() {
        // ⚠️ `hasFullAccess` 가 아니라 `isSyncAvailable` 이다. 두 대째만 산 사람도 엔진이 돌아야 한다.
        let entitled = isSyncAvailable
        groupDefaults?.set(entitled, forKey: DefaultsKey.syncEntitled)
        NSUbiquitousKeyValueStore.default.set(entitled, forKey: DefaultsKey.syncEntitled)
        print("🔑 [ProFeatureManager] 동기화 권한 미러링: \(entitled)")
    }

    // MARK: - Diagnostics

    /// "실제 접근 권한"을 결제 외 경로까지 한 줄로 찍는다.
    /// StoreManager.isPro / ProStatusManager는 **IAP 구매 권한만** 보므로 false여도,
    /// 앱이 Pro로 보이는 진짜 이유(TestFlight·그랜드파더·체험)를 로그에서 바로 알 수 있게 한다.
    /// → "구매=false인데 왜 Pro로 보이지?" 혼동 제거용.
    static func logAccessResolution(_ context: String) {
        let purchased = groupDefaults?.bool(forKey: proStatusKey) ?? false
        let reason: String
        if purchased { reason = "구매(IAP)" }
        else if isTestFlight { reason = "TestFlight/Xcode" }
        else if hasGrandfatheredPurchase { reason = "그랜드파더(v3.x 유료구매)" }
        else if wasExistingFreeUser { reason = "기존 무료유저(v3.x)" }
        else if isInTrial { reason = "7일 체험" }
        else { reason = "없음(무료)" }
        print("🔑 [ProFeature] \(context), 접근권한: \(hasFullAccess ? "Pro ✅" : "무료") · 경로=\(reason) " +
              "[구매IAP=\(purchased) TestFlight=\(isTestFlight) 그랜드파더구매=\(hasGrandfatheredPurchase) 기존무료=\(wasExistingFreeUser) 체험=\(isInTrial)]")
    }

    // MARK: - 7일 무료 체험 (Trial)

    /// 시계 조작 방어용 "현재 시점" - 항상 단조 증가하도록 max(now, lastSeen) 적용.
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

    /// 체험 시작 가능 여부 - 아직 안 했고, 이미 Pro도 아니고, 그랜드파더도 아닌 경우
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

    /// 메모 추가 가능 여부 - **저장을 막는 실제 관문.**
    ///
    /// ⚠️ `currentCount` 에는 **자기 것만** 넘긴다(`ownMemoCount`). 온보딩이 심어 준
    ///    샘플까지 세면 아무것도 안 만든 사람이 4/10 에서 시작해, 실제로 쓸 수 있는
    ///    무료 칸이 6개가 된다. 한도를 10으로 올려 둔 뜻이 그만큼 사라진다.
    /// ⚠️ 여기가 `freeMemoLimit` 을 보면 칸을 산 사람이 11번째에서 그대로 막힌다.
    static func canAddMemo(currentCount: Int) -> Bool {
        currentCount < memoLimit
    }

    // MARK: - 한도가 세는 개수

    /// 온보딩이 심어 준 샘플 단축어의 id.
    ///
    /// 앱과 키보드가 같은 답을 내야 해서 App Group 에 있다. 심는 쪽은
    /// `SampleMemoStorage`, 세는 쪽은 여기 하나다.
    static var sampleMemoIds: Set<UUID> {
        let raw = groupDefaults?.stringArray(forKey: DefaultsKey.sampleMemoIdsV1) ?? []
        return Set(raw.compactMap { UUID(uuidString: $0) })
    }

    /// **이 사람이 직접 저장한** 단축어 개수. 한도를 묻는 곳은 전부 이 값을 센다.
    ///
    /// 왜 샘플을 빼는가: 심어 준 4개는 앱이 자기를 소개하려고 넣은 것이지 사용자가
    /// 만든 것이 아니다. 그걸 한도에 세면 앱이 자기 광고비를 사용자 지갑에서 꺼내
    /// 내는 셈이 된다. 샘플을 지웠는지 그냥 뒀는지로 쓸 수 있는 칸이 달라지는 것도
    /// 이상하다. 지우든 두든 자기 칸은 10개다.
    ///
    /// ⚠️ 샘플을 **고쳐 쓴** 것도 여전히 샘플로 센다(id 로 가른다). 자기 문구로 바꿔
    ///    쓰는 순간 칸이 하나 줄어든다면, 고쳐 쓰라고 심어 둔 것과 앞뒤가 안 맞는다.
    static func ownMemoCount(_ memos: [Memo]) -> Int {
        let samples = sampleMemoIds
        return memos.reduce(0) { $0 + (samples.contains($1.id) ? 0 : 1) }
    }

    /// 무료 한도 안에서 실제로 보여 줄 것들.
    ///
    /// 샘플은 칸을 차지하지 않으므로 **가려지지 않는다.** 자기 것만 앞에서부터
    /// `memoLimit` 개까지 남긴다. 순서는 들어온 그대로 둔다.
    ///
    /// ⚠️ 단순히 앞에서 `memoLimit` 개를 자르면 안 된다. 그러면 샘플이 앞자리를
    ///    차지한 만큼 자기 단축어가 뒤로 밀려 안 보이게 된다. 한도에서 뺀 것을
    ///    화면에서 도로 세는 셈이다.
    static func memosWithinLimit(_ memos: [Memo]) -> [Memo] {
        let limit = memoLimit
        if limit == Int.max { return memos }
        let samples = sampleMemoIds
        var ownKept = 0
        return memos.filter { memo in
            if samples.contains(memo.id) { return true }
            guard ownKept < limit else { return false }
            ownKept += 1
            return true
        }
    }

    /// 콤보 추가 가능 여부
    static func canAddStack(currentCount: Int) -> Bool {
        if hasFullAccess { return true }
        return currentCount < freeStackLimit
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
        case stack
        case template
        case clipboardHistory
        case cloudBackup
        case biometricLock
        case themeCustomization
        case imageMemo
        /// 두 번째 기기가 나타났다 - 파는 것은 Pro 가 아니라 **두 대째**다.
        case deviceSync

        /// Analytics 슬라이싱용 안정된 영문 키 (locale 무관)
        var analyticsKey: String {
            switch self {
            case .memo: return "memo"
            case .stack: return "combo"
            case .template: return "template"
            case .clipboardHistory: return "clipboard_history"
            case .cloudBackup: return "cloud_backup"
            case .biometricLock: return "biometric_lock"
            case .themeCustomization: return "theme"
            case .imageMemo: return "image_memo"
            case .deviceSync: return "device_sync"
            }
        }

        var localizedTitle: String {
            switch self {
            case .memo:
                return NSLocalizedString("단축어 개수 제한", comment: "Memo limit")
            case .stack:
                return NSLocalizedString("스택 개수 제한", comment: "Combo limit")
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
                return NSLocalizedString("이미지 단축어", comment: "Image memo")
            case .deviceSync:
                return NSLocalizedString("기기 사이 동기화", comment: "Device sync")
            }
        }

        var localizedDescription: String {
            switch self {
            case .memo:
                // 산 칸까지 더한 **지금 이 사람의** 한도를 말한다.
                return String(format: NSLocalizedString("무료 버전에서는 최대 %d개의 단축어를 저장할 수 있습니다.", comment: "Memo limit desc"), memoLimit)
            case .stack:
                return String(format: NSLocalizedString("무료 버전에서는 최대 %d개의 스택을 만들 수 있습니다.", comment: "Combo limit desc"), freeStackLimit)
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
                return String(format: NSLocalizedString("무료 버전에서는 최대 %d개의 이미지 단축어를 저장할 수 있습니다.", comment: "Image memo limit desc"), freeImageMemoLimit)
            case .deviceSync:
                return NSLocalizedString("같은 iCloud 계정의 다른 기기에서도 같은 단축어를 쓸 수 있습니다.", comment: "Device sync desc")
            }
        }
    }
}
