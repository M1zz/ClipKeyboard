//
//  StoreManager.swift
//  ClipKeyboard
//
//  Created by Claude on 2026/02/18.
//
//  StoreKit 2 엔진(상품 로드·구매·복원·권한 추적·트랜잭션 리스너·검증·오프라인 캐시)은
//  이제 LeeoKit 의 LeeoStore 가 공용으로 담당한다. 이 파일은 그 위에 앱 고유 로직
//  (구매 애널리틱스·그랜드파더 재검증·익스텐션 공유 Pro 키 미러링)만 얹은 얇은 파사드로,
//  기존 호출부(PaywallView / SettingView / ClipKeyboardApp)는 그대로 동작한다.
//
//  ⚠️ 키보드 익스텐션은 이 매니저를 쓰지 않는다. 익스텐션은 App Group 의 Pro 키
//  (`clipkeyboard_is_pro`)를 ProFeatureManager 로 읽기만 한다. 결제 권한이 바뀔 때마다
//  store.hasPro 를 그 키에 계속 미러링해 익스텐션이 정확한 Pro 상태를 보게 한다.
//

import Foundation
import Combine
import StoreKit
import SwiftUI
import LeeoKit

/// StoreKit 2 기반 인앱 구매 관리 (LeeoStore 파사드)
@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()

    // MARK: - Product IDs

    /// ⚠️ App Store Connect·기존 사용자 영수증과의 계약 - 변경 금지.
    /// `nonisolated`: 불변 String 상수라 격리가 필요 없고, `ClipKeyboardSpec.paywall`(nonisolated static let)이
    /// 이 값을 참조한다. 격리된 채로 두면 Swift 6 언어 모드에서 에러가 된다.
    /// 칸마다의 상품(평생 · 연 구독 · 올리기 · 졸업)은 `AccessTier` 한 곳에 적는다.
    nonisolated static let proProductID = AccessTier.proProductID

    /// Pro 선물 (소모성). 산 사람이 아니라 **코드를 받은 사람**에게 정가 Pro 를 연다(`LeeoGiftStore`).
    /// ⚠️ App Store Connect 에 소모성 상품으로 만들어야 뜬다. 없으면 설정의 선물 행이 숨는다.
    nonisolated static let giftProductID = "com.Ysoup.TokenMemo.gift.pro"

    /// 팁(응원), 작은 것부터. 소모성이고 아무것도 열지 않는다(`LeeoTipJar`).
    /// ⚠️ App Store Connect 에 소모성 상품으로 만들어야 뜬다. 없으면 설정의 응원 행이 숨는다.
    nonisolated static let tipProductIDs = [
        "com.Ysoup.TokenMemo.tip.small",
        "com.Ysoup.TokenMemo.tip.medium",
        "com.Ysoup.TokenMemo.tip.large"
    ]

    // MARK: - 내부 공용 스토어

    private let store: LeeoStore
    private var cancellables = Set<AnyCancellable>()

    /// 언제나 평생 패스. 열려 있으면 프로다(`AccessTier.purchased(from:foreverPass:)`).
    ///
    /// ⚠️ 캐시를 App Group 에 둔다. 키보드는 이 객체를 만들지 않고, 앱이 새긴 트림(`AccessTier.mirror`)을 본다.
    /// ⚠️ 패스 상품은 위 판매 · 권한 목록에 없다. 결제와 iCloud 기록은 이 객체가 따로 본다.
    let foreverPass = LeeoForeverPass(containerIdentifier: "iCloud.com.Ysoup.FeedbackHub",
                                      defaults: AppGroup.defaults ?? .standard)

    /// 지금 살아 있는 연 구독(Plus · Pro). 없으면 nil. 구독 졸업 제안과 설정의 '평생으로 바꾸기' 가 본다.
    @Published private(set) var subscription: LeeoGraduation.Subscription?

    // MARK: - 공개 상태 (기존 API 유지 - 내부 LeeoStore 로 위임)

    /// 로드된 판매 상품.
    var products: [Product] { store.products }

    /// 현재 유효한 권한을 가진 상품 ID 집합.
    var purchasedProductIDs: Set<String> { store.purchasedProductIDs }

    /// 로딩 스피너용 - 상품 로드/구매/복원 중 하나라도 진행 중이면 true.
    var isLoading: Bool {
        store.isLoadingProducts || store.purchasingProductID != nil || store.isRestoring
    }

    /// 사용자 노출 오류 메시지 (LeeoStore.lastError 로 위임).
    var errorMessage: String? {
        get { store.lastError }
        set { store.lastError = newValue }
    }

    /// 불러온 상품 하나. 아직 못 불러왔거나 App Store Connect 에 없으면 nil.
    func product(_ id: String) -> Product? {
        store.products.first { $0.id == id }
    }

    /// 구독 졸업 상품(구독 중인 사람의 Pro 평생).
    var graduateProduct: Product? { product(AccessTier.proGraduateProductID) }

    /// 지금 구독 졸업을 제안할 때인가(6개월째 · 갱신 7일 전, 창마다 한 번).
    var graduationIsDue: Bool {
        guard let subscription else { return false }
        return LeeoGraduation.isDue(subscription, lastOffered: LeeoGraduation.lastOffered())
    }

    /// 두 대째 상품 - 동기화만 여는 별도의 문. **Pro 가 아니다.**
    var twoDeviceProduct: Product? {
        store.products.first { $0.id == TwoDevicePack.productID }
    }

    /// 결제 entitlement 기반 Pro 여부.
    /// (그랜드파더 / TestFlight / 체험은 ProFeatureManager 가 별도로 판단한다.)
    var isPro: Bool { store.hasPro }

    /// Pro 선물하기. 받은 선물은 `purchasedProductIDs` 에 정가 Pro 로 합쳐져 들어오므로
    /// 트림 · 익스텐션 미러는 산 것과 똑같이 따라간다.
    var gift: LeeoGiftStore? { store.gift }

    /// 팁(응원). 권한과 상관없다.
    var tipJar: LeeoTipJar? { store.tipJar }

    // MARK: - Init

    private init() {
        store = LeeoStore(config: ClipKeyboardSpec.paywall!)

        // 공용 스토어의 상태 변화를 그대로 뷰에 전파한다.
        store.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // 선물 상품이 불러와지면(설정의 선물 행이 보이게) 화면도 다시 그린다.
        store.gift?.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        // 언제나 평생 패스가 열리거나 닫히면 페이월 · 설정도 다시 그린다.
        foreverPass.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        // 팁 상품도 같다(설정의 응원 행).
        store.tipJar?.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        // 이미 Pro 인 사람(앱이 따로 판정하는 v3 그랜드파더 포함)은 선물을 받지 않는다.
        // 코드를 쓰지 않고 남겨 두면 다른 사람에게 넘길 수 있다.
        store.gift?.alreadyEntitled = { ProFeatureManager.hasPermanentPro }
        // 개발자 모드에서만 시험 선물을 만들고 받는다. 시험 선물은 Pro 를 열지 않는다(`GiftDeveloperTestView`).
        store.gift?.allowsTestGifts = { UserDefaults.standard.bool(forKey: DefaultsKey.masterModeEnabled) }

        // 결제 권한을 익스텐션이 읽는 App Group Pro 키에 미러링한다.
        //
        // ⚠️ 정가 ID 하나가 아니라 **권한 상품 전체**(`grantsPro`)로 본다. 예전에는
        //    `contains(proProductID)` 였고, 그래서 반값·업그레이드로 산 사람은 돈을 내고도
        //    `clipkeyboard_is_pro` 가 false 였다 - 기능도 안 열리고, 통계에는 무료로 올라갔다.
        //
        // ⚠️ 언제나 평생 패스도 같이 본다. 패스는 권한 목록에 없는 상품이라, 여기서 합치지 않으면
        //    패스를 산 사람의 키보드는 무료로 남는다.
        let entitlement = Publishers.CombineLatest(store.$purchasedProductIDs, foreverPass.$isActive)
        entitlement
            .map { owned, pass in Self.grantsPro(owned) || pass }
            .removeDuplicates()
            .sink { [weak self] isProNow in
                Task { @MainActor in self?.mirrorProStatus(isPro: isProNow) }
            }
            .store(in: &cancellables)

        // 산 트림(플러스 · 프로 · 마스터)도 미러링한다. Pro 키 하나로는 플러스와 마스터를 못 가른다.
        entitlement
            .map { owned, pass in AccessTier.purchased(from: owned, foreverPass: pass) }
            .removeDuplicates()
            .sink { tier in
                Task { @MainActor in
                    AccessTier.mirror(tier)
                    // 동기화 권한은 트림을 보고 정해진다(프로 이상). 트림이 바뀌면 다시 새긴다.
                    ProFeatureManager.mirrorSyncEntitlement()
                }
            }
            .store(in: &cancellables)

        // 칸 추가 상품도 같은 방식으로 미러링한다 - 익스텐션은 StoreKit 을 못 보므로
        // 이 값이 없으면 앱에서는 15칸, 키보드에서는 10칸으로 갈린다.
        //
        // ⚠️ 여기서 보는 것은 **예전 비소모성 상품**뿐이다. 새로 파는 팩은 소모성이라
        //    권한 목록에 아예 나타나지 않는다. 그쪽은 결제 직후 `recordPackPurchase()` 가
        //    직접 센다(`purchaseSlotPack`).
        store.$purchasedProductIDs
            .map { $0.contains(SlotPack.productID) }
            .removeDuplicates()
            .sink { boughtSlots in
                Task { @MainActor in SlotPack.mirror(purchased: boughtSlots) }
            }
            .store(in: &cancellables)

        // 두 대째도 같은 이유로 미러링한다. 동기화 엔진은 공유 타입이라 StoreKit 을 못 본다.
        store.$purchasedProductIDs
            .map { $0.contains(TwoDevicePack.productID) }
            .removeDuplicates()
            .sink { boughtTwoDevice in
                Task { @MainActor in
                    TwoDevicePack.mirror(purchased: boughtTwoDevice)
                    ProFeatureManager.mirrorSyncEntitlement()
                }
            }
            .store(in: &cancellables)

        // 구독이 바뀌면(새로 · 갱신 · 끝남) 졸업 제안의 기준도 다시 읽는다.
        store.$purchasedProductIDs
            .map { !$0.isDisjoint(with: AccessTier.subscriptionProductIDs) }
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in await self?.refreshSubscription() }
            }
            .store(in: &cancellables)

        // 초기(캐시) 상태 즉시 미러링.
        mirrorProStatus(isPro: Self.grantsPro(store.purchasedProductIDs) || foreverPass.isActive)
        AccessTier.mirror(AccessTier.purchased(from: store.purchasedProductIDs, foreverPass: foreverPass.isActive))
        SlotPack.mirror(purchased: store.purchasedProductIDs.contains(SlotPack.productID))
        TwoDevicePack.mirror(purchased: store.purchasedProductIDs.contains(TwoDevicePack.productID))
        // 소모성이라 애플이 돌려주지 않는 칸수를 iCloud 에서 회수한다(둘 중 큰 값).
        SlotPack.syncFromCloud()
    }

    /// 이 상품들 중 Pro 를 여는 것이 있는가 - 정가·반값·업그레이드 중 하나라도.
    ///
    /// 권한 목록은 `ClipKeyboardSpec` 한 곳에만 적는다. 여기서 ID 를 다시 나열하면
    /// 상품이 늘 때 한쪽만 고쳐져, 돈을 받고 아무것도 안 열어 주는 상품이 또 생긴다.
    nonisolated static func grantsPro(_ owned: Set<String>) -> Bool {
        !owned.isDisjoint(with: ClipKeyboardSpec.paywall?.entitlementIDs ?? [])
    }

    // MARK: - Public Methods

    /// 상품 목록 로드
    func loadProducts() async {
        await store.loadProducts()
    }

    /// 칸 추가 상품 - **지금 파는 쪽**(소모성).
    ///
    /// ⚠️ 예전 비소모성 `slots5` 는 여기서 안 판다. 이미 산 사람의 권한으로만 남는다.
    ///    한 번밖에 못 사는 물건을 계속 진열하면 두 번째로 필요한 사람 앞에서 사다리가 끊긴다.
    ///    (App Store Connect 에 올린 상품의 종류는 바꿀 수 없어서 상품이 둘이다.
    ///     자세한 이유: Service/SlotPack.swift)
    var slotPackProduct: Product? {
        store.products.first { $0.id == SlotPack.consumableProductID }
    }

    /// 칸 추가 구매 - 페이월의 작은 계단. 최대 세 번까지.
    ///
    /// ⚠️ 소모성이라 애플이 기억해 주지 않는다. 성공한 자리에서 **먼저** 세고,
    ///    그 다음에 다른 일을 한다. 여기서 못 세면 돈만 받은 것이 된다.
    func purchaseSlotPack(triggeredBy: String? = nil) async -> Bool {
        guard SlotPack.canBuyMore else {
            print("ℹ️ [StoreManager] 칸이 이미 최대라 사지 않는다")
            return false
        }
        if store.products.isEmpty { await store.loadProducts() }
        guard let product = slotPackProduct else {
            print("❌ [StoreManager] 칸 추가 상품을 찾을 수 없음: \(SlotPack.consumableProductID)")
            errorMessage = NSLocalizedString("상품을 찾을 수 없습니다", comment: "Product not found")
            return false
        }
        let bought = await purchase(product, triggeredBy: triggeredBy)
        if bought { SlotPack.recordPackPurchase() }
        return bought
    }

    /// 두 대째 구매 - 동기화만 여는 문.
    func purchaseTwoDevice(triggeredBy: String? = nil) async -> Bool {
        if store.products.isEmpty { await store.loadProducts() }
        guard let product = twoDeviceProduct else {
            print("❌ [StoreManager] 두 대째 상품을 찾을 수 없음: \(TwoDevicePack.productID)")
            errorMessage = NSLocalizedString("상품을 찾을 수 없습니다", comment: "Product not found")
            return false
        }
        return await purchase(product, triggeredBy: triggeredBy)
    }

    /// 상품 구매 (StoreKit 실행은 LeeoStore 에 위임하고, 애널리틱스만 여기서 유지)
    ///
    /// - Parameter action: 화면의 `@Environment(\.purchase)`. 넘기면 결제 시트가 그 창에 뜬다
    ///   (아이패드에서 창을 잘못 짚어 결제가 오류로 끝나는 일을 막는다). 없으면 StoreKit 이 짐작한다.
    ///
    /// ⚠️ 성공은 **결제가 확인됐는가**로 본다. LeeoStore 는 "Pro 권한이 생겼는가" 로 답해서,
    ///    Plus 를 산 사람에게는 늘 실패라고 했다(돈은 나갔는데 화면이 그대로였다).
    func purchase(_ product: Product, using action: PurchaseAction? = nil, triggeredBy: String? = nil) async -> Bool {
        errorMessage = nil

        // ⚠️ **결제 전에** 찍는다. 이 결제가 끝나면 상태가 바뀌어서, 나중에 물으면
        //    전부 "이미 뭔가 산 사람" 이 된다. 업그레이드 가설을 검증할 유일한 값이다.
        let prior = PriorPurchase.current

        var verified = false
        let entitled = await store.purchase(product) { product in
            let result = if let action { try await action(product) } else { try await product.purchase() }
            if case .success(.verified) = result { verified = true }
            return result
        }
        let success = entitled || verified

        if success {
            print("✅ [StoreManager] 구매 성공: \(product.id)")

            // Analytics - Offer Code 여부 판별 (iOS 17.2+에서만 direct 검출 가능).
            // LeeoStore 가 트랜잭션을 finish 하므로, 방금 완료된 트랜잭션은 latest 로 조회한다.
            var isOfferCode = false
            var offerCodeName: String?
            if #available(iOS 17.2, *),
               let latest = await Transaction.latest(for: product.id),
               case .verified(let transaction) = latest,
               transaction.offer?.type == .code {
                isOfferCode = true
                offerCodeName = transaction.offer?.id ?? "code"
            }
            let priceDouble = NSDecimalNumber(decimal: product.price).doubleValue
            AnalyticsService.logPaywallPurchase(
                productId: product.id,
                isOfferCode: isOfferCode,
                offerCode: offerCodeName,
                currency: product.priceFormatStyle.currencyCode,
                revenue: priceDouble,
                triggeredBy: triggeredBy,
                priorPurchase: prior
            )
            return true
        } else {
            // 실패/취소 구분: LeeoStore 는 사용자 취소 시 lastError 를 건드리지 않고,
            // pending·검증실패·오류 시 lastError 를 채운다. 이를 근사로 사용한다.
            if let reason = store.lastError {
                print("❌ [StoreManager] 구매 실패/대기: \(reason)")
                AnalyticsService.logPurchaseFailed(reason: reason, triggeredBy: triggeredBy)
            } else {
                print("ℹ️ [StoreManager] 사용자가 구매 취소")
                AnalyticsService.logPurchaseCancelled(triggeredBy: triggeredBy)
            }
            return false
        }
    }

    /// 복원을 누른 사람에게 돌려줄 결과.
    ///
    /// ⚠️ 복원은 **반드시 결과를 말한다.** 예전에는 찾은 것이 없어도 아무 말이 없어서
    ///    "복원을 눌러도 아무 일도 안 일어난다" 는 문의가 왔다(2026-09-26, 재설치 뒤 Pro 소실).
    enum RestoreOutcome: Identifiable, Equatable {
        /// Pro(결제·그랜드파더)가 열려 있다.
        case restored
        /// 이 Apple ID 에 복원할 Pro 구매가 없다.
        case nothingFound
        /// App Store 에 닿지 못했다.
        case failed(String)

        var id: String {
            switch self {
            case .restored: return "restored"
            case .nothingFound: return "nothingFound"
            case .failed(let message): return "failed:\(message)"
            }
        }
    }

    /// 구매 복원
    @discardableResult
    func restorePurchases() async -> RestoreOutcome {
        await store.restore()
        // 다른 앱에서 산 언제나 평생 패스도 복원할 때 다시 찾는다.
        await foreverPass.refresh()
        // v4.0 이전 유료 앱 구매자도 "이전 구매 복원"으로 즉시 Pro 해제되도록
        // AppTransaction(최초 구매일) 재검증. (신규 Pro IAP 영수증이 없어도 부여됨)
        // 복원은 사용자가 누른 것이라 영수증을 App Store 에서 새로 받아 온다(재설치 직후 대비).
        let receiptError = await ProFeatureManager.grandfatherPaidUserIfNeeded(refreshReceipt: true)
        ProStatusManager.shared.objectWillChange.send()

        let outcome: RestoreOutcome
        // ⚠️ Plus 도 산 것이다. Pro 만 보면 Plus 를 산 사람이 복원을 눌렀을 때 "구매 없음" 을 듣는다.
        if Self.grantsPro(store.purchasedProductIDs) || ProFeatureManager.hasPermanentPro || foreverPass.isActive
            || AccessTier.purchased(from: store.purchasedProductIDs) >= .plus {
            outcome = .restored
        } else if let error = store.lastError ?? receiptError {
            // 영수증을 못 읽었는데 "구매 없음" 이라 하면 v4.0 이전 구매자가 Pro 를 잃었다고 믿는다
            // (2026-10-12 문의: 재설치 뒤 Pro 가 사라졌고 복원해도 찾지 못했다).
            outcome = .failed(error)
        } else {
            outcome = .nothingFound
        }
        print("✅ [StoreManager] 구매 복원 완료: \(outcome.id) (owned=\(store.purchasedProductIDs.sorted()))")
        return outcome
    }

    /// 화면 밖에서 결제가 끝났을 때(구독 졸업 시트 · 패스 화면) 권한을 다시 읽는다.
    func refreshEntitlements() async {
        await store.refreshEntitlements()
        await refreshSubscription()
    }

    /// 지금 살아 있는 연 구독을 다시 읽는다.
    func refreshSubscription() async {
        let current = await LeeoGraduation.currentSubscription(among: AccessTier.subscriptionProductIDs)
        if current != subscription { subscription = current }
    }

    // MARK: - Private

    /// 결제 권한을 익스텐션이 읽는 App Group Pro 키에 미러링한다.
    ///
    /// ⚠️ 여기서 `wasProAtV3` 를 켜지 않는다. 예전에는 "Pro 가 한 번이라도 켜지면 영구
    ///    기록" 이었고, 그래서 환불·취소가 `clipkeyboard_is_pro` 는 껐지만 권한은 그 키로
    ///    평생 남았다. 지금 결제는 이 키 하나가 StoreKit 을 따라 켜지고 꺼진다.
    private func mirrorProStatus(isPro: Bool) {
        // ProStatusManager 가 App Group(clipkeyboard_is_pro) + iCloud KVS 에 저장한다.
        ProStatusManager.shared.setProStatus(isPro)
        Task { await mirrorProOwnership() }
    }

    /// Pro 권한이 **가족 공유로만** 들어왔는지 App Group 에 새긴다.
    ///
    /// 기능은 똑같이 열린다. 다르게 보는 곳은 사용 통계뿐이다 - 가족 공유는 이 설치에서
    /// 돈이 나가지 않았으므로 `flag.isPaid` 가 아니라 `flag.isComped` 다
    /// (`UsageReportingService.currentMetrics`). 권한 목록(`purchasedProductIDs`)은 누가
    /// 샀는지를 들고 있지 않아서 트랜잭션을 한 번 더 훑는다.
    private func mirrorProOwnership() async {
        var owned: [(productID: String, isFamilyShared: Bool)] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            owned.append((transaction.productID, transaction.ownershipType == .familyShared))
        }
        AppGroup.defaults?.set(Self.proIsFamilySharedOnly(owned), forKey: DefaultsKey.proViaFamilySharing)
    }

    /// Pro 를 여는 권한이 있고, 그게 **전부** 가족 공유인가.
    /// 한 번이라도 직접 샀으면(정가든 반값이든) 가족 공유가 같이 있어도 결제다.
    nonisolated static func proIsFamilySharedOnly(_ owned: [(productID: String, isFamilyShared: Bool)]) -> Bool {
        let pro = owned.filter { grantsPro([$0.productID]) }
        return !pro.isEmpty && pro.allSatisfy(\.isFamilyShared)
    }

    // MARK: - Diagnostics

    /// 현재 계정의 Pro/구매 상태를 한눈에 보기 위한 진단 덤프.
    /// "왜 Pro가 아닌가 / 왜 프로모션·복원이 안 되나" 디버깅용.
    /// 호출: ClipKeyboardApp.init()에서 Task로. (로그는 Xcode 콘솔에서 "🩺 [Diag]"로 검색)
    func logAccountDiagnostics() async {
        let line = String(repeating: "─", count: 48)
        print("🩺 [Diag] \(line)")
        print("🩺 [Diag] === 계정/구매 상태 진단 시작 ===")

        // 1) 실행 환경 (AppTransaction = Apple ID에 묶인 최초 구매 영수증)
        print("🩺 [Diag] isTestFlight(cached) = \(ProFeatureManager.isTestFlight)")
        do {
            let result = try await AppTransaction.shared
            switch result {
            case .verified(let tx):
                print("🩺 [Diag] AppTransaction: VERIFIED")
                print("🩺 [Diag]   environment        = \(tx.environment.rawValue)  (production / sandbox / xcode)")
                print("🩺 [Diag]   originalPurchase   = \(tx.originalPurchaseDate)")
                print("🩺 [Diag]   originalAppVersion = \(tx.originalAppVersion)")
                print("🩺 [Diag]   bundleID           = \(tx.bundleID)")
                print("🩺 [Diag]   freemium 컷오프      = \(ProFeatureManager.freemiumReleaseDate)")
                print("🩺 [Diag]   → 그랜드파더 대상?    = \(tx.originalPurchaseDate < ProFeatureManager.freemiumReleaseDate)")
            case .unverified(_, let error):
                print("🩺 [Diag] AppTransaction: UNVERIFIED: \(error)")
            }
        } catch {
            print("🩺 [Diag] AppTransaction 조회 실패: \(error)")
        }

        // 2) 앱이 인식하는 Pro 권한 종합 (ProFeatureManager)
        print("🩺 [Diag] -- ProFeatureManager 종합 판정 --")
        print("🩺 [Diag] tier                  = \(ProFeatureManager.tier)  (산 트림 \(ProFeatureManager.purchasedTier))")
        print("🩺 [Diag] hasFullAccess         = \(ProFeatureManager.hasFullAccess)  ← 개수 제한 없음(플러스 이상)")
        print("🩺 [Diag]   isPro               = \(ProFeatureManager.isPro)")
        print("🩺 [Diag]   isGrandfathered     = \(ProFeatureManager.isGrandfathered)")
        print("🩺 [Diag]     hasGrandfathered  = \(ProFeatureManager.hasGrandfatheredPurchase)")
        print("🩺 [Diag]     wasExistingFree   = \(ProFeatureManager.wasExistingFreeUser)")
        print("🩺 [Diag]   isInTrial           = \(ProFeatureManager.isInTrial)")
        print("🩺 [Diag]     hasStartedTrial   = \(ProFeatureManager.hasStartedTrial)")
        print("🩺 [Diag]     trialStartedAt    = \(ProFeatureManager.trialStartedAt.map { "\(Date(timeIntervalSince1970: $0))" } ?? "nil")")
        print("🩺 [Diag]     trialDaysRemaining= \(ProFeatureManager.trialDaysRemaining)")

        // 3) App Group UserDefaults 원본 값
        let d = AppGroup.defaults
        print("🩺 [Diag] -- App Group UserDefaults (\(AppGroup.identifier)) --")
        func dump(_ key: String) {
            let raw = d?.object(forKey: key)
            print("🩺 [Diag]   \(key) = \(raw.map { "\($0)" } ?? "nil(미설정)")")
        }
        dump(ProFeatureManager.proStatusKey)
        dump(ProFeatureManager.grandfatheredPurchaseKey)
        dump(ProFeatureManager.existingFreeUserKey)
        dump(ProFeatureManager.trialStartedAtKey)

        // 4) StoreManager 상태
        print("🩺 [Diag] -- StoreManager --")
        print("🩺 [Diag]   로드된 상품 수        = \(products.count)  (0이면 상품 fetch 실패)")
        for p in products {
            print("🩺 [Diag]     • \(p.id) | \(p.displayPrice) | type=\(p.type.rawValue)")
        }
        print("🩺 [Diag]   purchasedProductIDs = \(purchasedProductIDs.isEmpty ? "(없음)" : purchasedProductIDs.joined(separator: ", "))")
        print("🩺 [Diag]   StoreManager.isPro  = \(isPro)")

        // 5) 실제 보유 권한 (Transaction.currentEntitlements) - 프로모/복원이 실제로 들어왔는지 확인
        print("🩺 [Diag] -- Transaction.currentEntitlements (실제 보유 권한) --")
        var count = 0
        for await result in Transaction.currentEntitlements {
            count += 1
            switch result {
            case .verified(let tx):
                var offerInfo = "none"
                if #available(iOS 17.2, *), let offer = tx.offer {
                    offerInfo = "type=\(offer.type)  id=\(offer.id ?? "-")"
                }
                print("🩺 [Diag]   #\(count) VERIFIED")
                print("🩺 [Diag]      productID     = \(tx.productID)")
                print("🩺 [Diag]      productType   = \(tx.productType.rawValue)")
                print("🩺 [Diag]      ownershipType = \(tx.ownershipType)  (purchased / familyShared)")
                print("🩺 [Diag]      purchaseDate  = \(tx.purchaseDate)")
                print("🩺 [Diag]      revocationDate= \(tx.revocationDate.map { "\($0)" } ?? "nil")")
                print("🩺 [Diag]      environment   = \(tx.environment.rawValue)")
                print("🩺 [Diag]      offer         = \(offerInfo)")
            case .unverified(let tx, let error):
                print("🩺 [Diag]   #\(count) UNVERIFIED: productID=\(tx.productID) error=\(error)")
            }
        }
        if count == 0 {
            print("🩺 [Diag]   (보유 권한 없음. 프로모션/복원이 한 번도 성공하지 않았다는 뜻)")
        }

        print("🩺 [Diag] === 진단 끝 ===")
        print("🩺 [Diag] \(line)")
    }
}
