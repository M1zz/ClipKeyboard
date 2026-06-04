//
//  StoreManager.swift
//  ClipKeyboard
//
//  Created by Claude on 2026/02/18.
//

import Foundation
import StoreKit

/// StoreKit 2 기반 인앱 구매 관리
@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    // MARK: - Product IDs
    
    static let proProductID = "com.Ysoup.TokenMemo.pro"
    
    // MARK: - Published Properties
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    var proProduct: Product? {
        products.first { $0.id == Self.proProductID }
    }
    
    var isPro: Bool {
        purchasedProductIDs.contains(Self.proProductID)
    }
    
    // MARK: - Private
    
    private var updateListenerTask: Task<Void, Error>? = nil
    
    // MARK: - Init
    
    private init() {
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// 상품 목록 로드
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let storeProducts = try await Product.products(for: [Self.proProductID])
            products = storeProducts
            print("✅ [StoreManager] 상품 로드 완료: \(storeProducts.count)개")
            
            for product in storeProducts {
                print("   - \(product.id): \(product.displayPrice)")
            }
        } catch {
            print("❌ [StoreManager] 상품 로드 실패: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Pro 구매
    /// - Parameter triggeredBy: 어떤 한도/진입점이 paywall을 띄웠는지 (analytics 슬라이싱용)
    func purchasePro(triggeredBy: String? = nil) async -> Bool {
        guard let product = proProduct else {
            print("❌ [StoreManager] Pro 상품을 찾을 수 없음")
            errorMessage = NSLocalizedString("상품을 찾을 수 없습니다", comment: "Product not found")
            return false
        }

        return await purchase(product, triggeredBy: triggeredBy)
    }

    /// 상품 구매
    func purchase(_ product: Product, triggeredBy: String? = nil) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                // 구매 완료 처리
                await updatePurchasedProducts()
                await transaction.finish()

                print("✅ [StoreManager] 구매 성공: \(product.id)")

                // Analytics — Offer Code 여부 판별 (iOS 17.2+에서만 direct 검출 가능)
                var isOfferCode = false
                var offerCodeName: String? = nil
                if #available(iOS 17.2, *) {
                    if transaction.offer?.type == .code {
                        isOfferCode = true
                        offerCodeName = transaction.offer?.id ?? "code"
                    }
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

                isLoading = false
                return true
                
            case .userCancelled:
                print("ℹ️ [StoreManager] 사용자가 구매 취소")
                AnalyticsService.logPurchaseCancelled(triggeredBy: triggeredBy)
                isLoading = false
                return false

            case .pending:
                print("⏳ [StoreManager] 구매 대기 중 (부모 승인 필요 등)")
                errorMessage = NSLocalizedString("구매 승인 대기 중입니다", comment: "Purchase pending")
                AnalyticsService.logPurchaseFailed(reason: "pending", triggeredBy: triggeredBy)
                isLoading = false
                return false

            @unknown default:
                print("❓ [StoreManager] 알 수 없는 구매 결과")
                isLoading = false
                return false
            }
        } catch {
            print("❌ [StoreManager] 구매 실패: \(error)")
            errorMessage = error.localizedDescription
            AnalyticsService.logPurchaseFailed(reason: "\(error)", triggeredBy: triggeredBy)
            isLoading = false
            return false
        }
    }
    
    /// 구매 복원
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            // v4.0 이전 유료 앱 구매자도 "이전 구매 복원"으로 즉시 Pro 해제되도록
            // AppTransaction(최초 구매일) 재검증. (신규 Pro IAP 영수증이 없어도 부여됨)
            await ProFeatureManager.grandfatherPaidUserIfNeeded()
            print("✅ [StoreManager] 구매 복원 완료")
        } catch {
            print("❌ [StoreManager] 구매 복원 실패: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
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
        let d = UserDefaults(suiteName: ProFeatureManager.appGroupSuite)
        print("🩺 [Diag] -- App Group UserDefaults (\(ProFeatureManager.appGroupSuite)) --")
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

    // MARK: - Private Methods

    /// 구매 상태 업데이트
    private func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // 비소모성 상품 (Pro)
                if transaction.productType == .nonConsumable {
                    purchasedIDs.insert(transaction.productID)
                }
            } catch {
                print("⚠️ [StoreManager] 트랜잭션 검증 실패: \(error)")
            }
        }
        
        purchasedProductIDs = purchasedIDs

        // ProStatusManager에 알림
        let isPro = purchasedIDs.contains(Self.proProductID)
        ProStatusManager.shared.setProStatus(isPro)

        // v4.0 그랜드파더 Pro 플래그: Pro 이력 생기면 영구 기록
        if isPro {
            UserDefaults(suiteName: ProFeatureManager.appGroupSuite)?
                .set(true, forKey: ProFeatureManager.grandfatheredPurchaseKey)
        }

        print("📋 [StoreManager] 구매 상태 업데이트: isPro = \(isPro)")
    }
    
    /// 트랜잭션 리스너
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("⚠️ [StoreManager] 트랜잭션 업데이트 실패: \(error)")
                }
            }
        }
    }
    
    /// 트랜잭션 검증
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Errors

enum StoreError: Error, LocalizedError {
    case failedVerification
    case productNotFound
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return NSLocalizedString("구매 검증에 실패했습니다", comment: "Verification failed")
        case .productNotFound:
            return NSLocalizedString("상품을 찾을 수 없습니다", comment: "Product not found")
        }
    }
}
