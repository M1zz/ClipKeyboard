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
    func purchasePro() async -> Bool {
        guard let product = proProduct else {
            print("❌ [StoreManager] Pro 상품을 찾을 수 없음")
            errorMessage = NSLocalizedString("상품을 찾을 수 없습니다", comment: "Product not found")
            return false
        }
        
        return await purchase(product)
    }
    
    /// 상품 구매
    func purchase(_ product: Product) async -> Bool {
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
                isLoading = false
                return true
                
            case .userCancelled:
                print("ℹ️ [StoreManager] 사용자가 구매 취소")
                isLoading = false
                return false
                
            case .pending:
                print("⏳ [StoreManager] 구매 대기 중 (부모 승인 필요 등)")
                errorMessage = NSLocalizedString("구매 승인 대기 중입니다", comment: "Purchase pending")
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
            print("✅ [StoreManager] 구매 복원 완료")
        } catch {
            print("❌ [StoreManager] 구매 복원 실패: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
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
