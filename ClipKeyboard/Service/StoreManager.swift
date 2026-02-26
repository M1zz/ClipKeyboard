//
//  StoreManager.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2026/02/21.
//

import Foundation
import StoreKit

/// StoreKit 2 기반 인앱 구매 매니저
/// - 일회성 구매 (Non-consumable)
/// - 구매 상태 UserDefaults + Transaction 이중 검증
@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    // MARK: - Product IDs
    static let proProductID = "com.Ysoup.TokenMemo.pro"
    
    // MARK: - Published
    @Published private(set) var proProduct: Product?
    @Published private(set) var isPro: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var purchaseError: String?
    
    // MARK: - Private
    private var transactionListener: Task<Void, Error>?
    private let proKey = "clipkeyboard_is_pro"
    private let proDateKey = "clipkeyboard_pro_date"
    
    private let legacyMigratedKey = "clipkeyboard_legacy_pro_migrated"
    
    private init() {
        // 기존 유료 구매자 마이그레이션 (앱이 유료→무료 전환 시)
        migrateLegacyPaidUsers()
        
        // 캐시된 상태 먼저 로드 (빠른 UI 반응)
        isPro = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.bool(forKey: proKey) ?? false
        
        // Transaction 리스너 시작
        transactionListener = listenForTransactions()
        
        // 실제 구매 상태 검증
        Task {
            await loadProducts()
            await verifyPurchaseStatus()
        }
    }
    
    /// 기존 유료 앱 구매자를 Pro로 자동 전환
    /// - 앱이 유료 → 무료+IAP 모델로 바뀔 때 한 번만 실행
    /// - didShowOnboarding = true (기존 유저) + 마이그레이션 미완료 시 Pro 부여
    private func migrateLegacyPaidUsers() {
        let defaults = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")
        let standardDefaults = UserDefaults.standard
        
        // 이미 마이그레이션 완료됨
        guard !(defaults?.bool(forKey: legacyMigratedKey) ?? false) else { return }
        
        // 기존 유저 판별: 온보딩을 이미 완료한 사람 = 이전 버전 사용자
        let isExistingUser = standardDefaults.bool(forKey: "onboarding")
        
        if isExistingUser {
            // 기존 유료 앱 구매자 → Pro 부여
            defaults?.set(true, forKey: proKey)
            defaults?.set(Date().timeIntervalSince1970, forKey: proDateKey)
            print("✅ [StoreManager] 기존 유료 구매자 → Pro 마이그레이션 완료")
        }
        
        // 마이그레이션 완료 플래그 (다시 실행 안 함)
        defaults?.set(true, forKey: legacyMigratedKey)
        defaults?.synchronize()
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// 상품 정보 로드
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.proProductID])
            proProduct = products.first
        } catch {
            print("❌ [StoreManager] 상품 로드 실패: \(error)")
        }
    }
    
    /// Pro 구매
    func purchasePro() async -> Bool {
        guard let product = proProduct else {
            purchaseError = NSLocalizedString("상품 정보를 불러올 수 없습니다.", comment: "Product load error")
            return false
        }
        
        isLoading = true
        purchaseError = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                setProStatus(true)
                isLoading = false
                return true
                
            case .userCancelled:
                isLoading = false
                return false
                
            case .pending:
                purchaseError = NSLocalizedString("구매 승인 대기 중입니다.", comment: "Purchase pending")
                isLoading = false
                return false
                
            @unknown default:
                isLoading = false
                return false
            }
        } catch {
            purchaseError = NSLocalizedString("구매 중 오류가 발생했습니다.", comment: "Purchase error")
            isLoading = false
            print("❌ [StoreManager] 구매 실패: \(error)")
            return false
        }
    }
    
    /// 구매 복원
    func restorePurchases() async {
        isLoading = true
        purchaseError = nil
        
        do {
            try await AppStore.sync()
            await verifyPurchaseStatus()
        } catch {
            purchaseError = NSLocalizedString("복원 중 오류가 발생했습니다.", comment: "Restore error")
            print("❌ [StoreManager] 복원 실패: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    /// Transaction 리스너 — 외부 구매/복원 감지
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handleTransactionResult(result)
            }
        }
    }
    
    /// Transaction 결과 처리 (MainActor에서 실행)
    private func handleTransactionResult(_ result: VerificationResult<Transaction>) {
        do {
            let transaction = try checkVerified(result)
            handleTransaction(transaction)
            Task { await transaction.finish() }
        } catch {
            print("⚠️ [StoreManager] Transaction 검증 실패: \(error)")
        }
    }
    
    /// 구매 상태 검증 (앱 시작 시)
    private func verifyPurchaseStatus() async {
        // currentEntitlements로 현재 유효한 구매 확인
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID {
                setProStatus(true)
                return
            }
        }
        
        // 유효한 구매가 없으면 캐시 초기화
        // (단, 오프라인일 수 있으므로 캐시된 값 유지)
        // setProStatus(false) — 의도적으로 주석 처리
        // 오프라인 사용자 경험을 위해 캐시 값 유지
    }
    
    /// Transaction 처리
    private func handleTransaction(_ transaction: Transaction) {
        if transaction.productID == Self.proProductID {
            if transaction.revocationDate == nil {
                setProStatus(true)
            } else {
                setProStatus(false)
            }
        }
    }
    
    /// Transaction 검증
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    /// Pro 상태 저장 (UserDefaults — App Group 공유)
    private func setProStatus(_ value: Bool) {
        isPro = value
        let defaults = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")
        defaults?.set(value, forKey: proKey)
        if value {
            defaults?.set(Date().timeIntervalSince1970, forKey: proDateKey)
        }
        defaults?.synchronize()
        
        print(value ? "✅ [StoreManager] Pro 활성화" : "⚠️ [StoreManager] Pro 비활성화")
    }
}

// MARK: - Error

enum StoreError: LocalizedError {
    case verificationFailed
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return NSLocalizedString("구매 검증에 실패했습니다.", comment: "Verification failed")
        }
    }
}
