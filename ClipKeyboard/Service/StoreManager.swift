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
import LeeoKit

/// StoreKit 2 기반 인앱 구매 관리 (LeeoStore 파사드)
@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()

    // MARK: - Product IDs

    static let proProductID = "com.Ysoup.TokenMemo.pro"

    // MARK: - 내부 공용 스토어

    private let store: LeeoStore
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 공개 상태 (기존 API 유지 — 내부 LeeoStore 로 위임)

    /// 로드된 판매 상품.
    var products: [Product] { store.products }

    /// 현재 유효한 권한을 가진 상품 ID 집합.
    var purchasedProductIDs: Set<String> { store.purchasedProductIDs }

    /// 로딩 스피너용 — 상품 로드/구매/복원 중 하나라도 진행 중이면 true.
    var isLoading: Bool {
        store.isLoadingProducts || store.purchasingProductID != nil || store.isRestoring
    }

    /// 사용자 노출 오류 메시지 (LeeoStore.lastError 로 위임).
    var errorMessage: String? {
        get { store.lastError }
        set { store.lastError = newValue }
    }

    var proProduct: Product? {
        store.products.first { $0.id == Self.proProductID }
    }

    /// 결제 entitlement 기반 Pro 여부.
    /// (그랜드파더 / TestFlight / 체험은 ProFeatureManager 가 별도로 판단한다.)
    var isPro: Bool { store.hasPro }

    // MARK: - Init

    private init() {
        store = LeeoStore(config: ClipKeyboardSpec.paywall!)

        // 공용 스토어의 상태 변화를 그대로 뷰에 전파한다.
        store.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // 결제 권한(hasPro)을 익스텐션이 읽는 App Group Pro 키에 미러링한다.
        // (그랜드파더 클로저를 쓰지 않으므로 store.hasPro == 결제 entitlement 보유 여부.)
        store.$purchasedProductIDs
            .map { $0.contains(Self.proProductID) }
            .removeDuplicates()
            .sink { [weak self] isProNow in
                Task { @MainActor in self?.mirrorProStatus(isPro: isProNow) }
            }
            .store(in: &cancellables)

        // 초기(캐시) 상태 즉시 미러링.
        mirrorProStatus(isPro: store.purchasedProductIDs.contains(Self.proProductID))
    }

    // MARK: - Public Methods

    /// 상품 목록 로드
    func loadProducts() async {
        await store.loadProducts()
    }

    /// Pro 구매
    /// - Parameter triggeredBy: 어떤 한도/진입점이 paywall을 띄웠는지 (analytics 슬라이싱용)
    func purchasePro(triggeredBy: String? = nil) async -> Bool {
        if store.products.isEmpty { await store.loadProducts() }
        guard let product = proProduct else {
            print("❌ [StoreManager] Pro 상품을 찾을 수 없음")
            errorMessage = NSLocalizedString("상품을 찾을 수 없습니다", comment: "Product not found")
            return false
        }
        return await purchase(product, triggeredBy: triggeredBy)
    }

    /// 상품 구매 (StoreKit 실행은 LeeoStore 에 위임하고, 애널리틱스만 여기서 유지)
    func purchase(_ product: Product, triggeredBy: String? = nil) async -> Bool {
        errorMessage = nil

        let success = await store.purchase(product)

        if success {
            print("✅ [StoreManager] 구매 성공: \(product.id)")

            // Analytics — Offer Code 여부 판별 (iOS 17.2+에서만 direct 검출 가능).
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
                triggeredBy: triggeredBy
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

    /// 구매 복원
    func restorePurchases() async {
        await store.restore()
        // v4.0 이전 유료 앱 구매자도 "이전 구매 복원"으로 즉시 Pro 해제되도록
        // AppTransaction(최초 구매일) 재검증. (신규 Pro IAP 영수증이 없어도 부여됨)
        await ProFeatureManager.grandfatherPaidUserIfNeeded()
        print("✅ [StoreManager] 구매 복원 완료")
    }

    // MARK: - Private

    /// store.hasPro(결제 권한)를 익스텐션이 읽는 App Group Pro 키에 미러링한다.
    /// 기존 updatePurchasedProducts() 의 부작용(ProStatusManager.setProStatus +
    /// v4.0 그랜드파더 구매 이력 기록)을 그대로 유지한다.
    private func mirrorProStatus(isPro: Bool) {
        // ProStatusManager 가 App Group(clipkeyboard_is_pro) + iCloud KVS 에 저장한다.
        ProStatusManager.shared.setProStatus(isPro)

        // Pro 이력이 생기면 v4.0 그랜드파더 플래그를 영구 기록.
        if isPro {
            UserDefaults(suiteName: AppGroup.identifier)?
                .set(true, forKey: ProFeatureManager.grandfatheredPurchaseKey)
        }
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
                print("🩺 [Diag] AppTransaction: UNVERIFIED — \(error)")
            }
        } catch {
            print("🩺 [Diag] AppTransaction 조회 실패: \(error)")
        }

        // 2) 앱이 인식하는 Pro 권한 종합 (ProFeatureManager)
        print("🩺 [Diag] -- ProFeatureManager 종합 판정 --")
        print("🩺 [Diag] hasFullAccess         = \(ProFeatureManager.hasFullAccess)  ← 최종 Pro 기능 개방 여부")
        print("🩺 [Diag]   isPro               = \(ProFeatureManager.isPro)")
        print("🩺 [Diag]   isGrandfathered     = \(ProFeatureManager.isGrandfathered)")
        print("🩺 [Diag]     hasGrandfathered  = \(ProFeatureManager.hasGrandfatheredPurchase)")
        print("🩺 [Diag]     wasExistingFree   = \(ProFeatureManager.wasExistingFreeUser)")
        print("🩺 [Diag]   isInTrial           = \(ProFeatureManager.isInTrial)")
        print("🩺 [Diag]     hasStartedTrial   = \(ProFeatureManager.hasStartedTrial)")
        print("🩺 [Diag]     trialStartedAt    = \(ProFeatureManager.trialStartedAt.map { "\(Date(timeIntervalSince1970: $0))" } ?? "nil")")
        print("🩺 [Diag]     trialDaysRemaining= \(ProFeatureManager.trialDaysRemaining)")

        // 3) App Group UserDefaults 원본 값
        let d = UserDefaults(suiteName: AppGroup.identifier)
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

        // 5) 실제 보유 권한 (Transaction.currentEntitlements) — 프로모/복원이 실제로 들어왔는지 확인
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
                print("🩺 [Diag]   #\(count) UNVERIFIED — productID=\(tx.productID) error=\(error)")
            }
        }
        if count == 0 {
            print("🩺 [Diag]   (보유 권한 없음 — 프로모션/복원이 한 번도 성공하지 않았다는 뜻)")
        }

        print("🩺 [Diag] === 진단 끝 ===")
        print("🩺 [Diag] \(line)")
    }
}
