//
//  AnalyticsService.swift
//  ClipKeyboard
//
//  Firebase Analytics 이벤트 호출 wrapper.
//  - 메인 앱(ClipKeyboard) 타겟에서만 동작 (키보드 ext / widget은 메모리 한계로 제외)
//  - 사용자가 IDFA 설정에 동의 안 해도 익명 식별자 기반 집계 (no AdSupport)
//  - Firebase가 SDK 미설치 환경에선 no-op (canImport guards)
//

import Foundation
// 키보드 익스텐션에서는 Firebase를 절대 link하지 않는다 (메모리 한계 + 미링크 심볼).
// SWIFT_ACTIVE_COMPILATION_CONDITIONS = KEYBOARD_EXTENSION 플래그로 ext 빌드 제외.
#if !KEYBOARD_EXTENSION && canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

/// 추적할 이벤트 이름 — Firebase 표준 이름 (snake_case, 40자 이내)
enum AnalyticsEvent: String {
    /// Pro 잠금 해제 결제 성공
    case paywallPurchase = "paywall_purchase"
    /// 메모 추가
    case memoCreated = "memo_created"
    /// Apple Offer Code (예: APRIL) 리딤으로 인한 구매
    case offerCodeRedeemed = "offer_code_redeemed"
}

/// 이벤트 파라미터 키 — 분석 시 슬라이싱용
enum AnalyticsParam: String {
    case productId = "product_id"
    case priceTier = "price_tier"          // "regular" | "offer"
    case offerCode = "offer_code"          // 예: "APRIL"
    case currency = "currency"
    case revenue = "revenue"               // 사용자 결제 금액 (USD)
    case memoType = "memo_type"            // "text" | "image" | "template" | "combo"
    case memoCount = "memo_count"          // 사용자 보유 메모 총 개수
}

/// Analytics 호출 wrapper. 모든 호출은 main thread/안전.
enum AnalyticsService {

    /// 일반 이벤트 로깅
    static func log(_ event: AnalyticsEvent, parameters: [AnalyticsParam: Any] = [:]) {
        let stringKeyParams = parameters.reduce(into: [String: Any]()) { result, pair in
            result[pair.key.rawValue] = pair.value
        }
        #if !KEYBOARD_EXTENSION && canImport(FirebaseAnalytics)
        Analytics.logEvent(event.rawValue, parameters: stringKeyParams)
        #endif
        // dev 빌드 콘솔 확인용
        print("📊 [Analytics] \(event.rawValue) \(stringKeyParams)")
    }

    /// 사용자가 의도적으로 분석 거부 — UserDefaults 토글로 제어 가능 (향후 옵션)
    static func setCollectionEnabled(_ enabled: Bool) {
        #if !KEYBOARD_EXTENSION && canImport(FirebaseAnalytics)
        Analytics.setAnalyticsCollectionEnabled(enabled)
        #endif
    }

    // MARK: - Convenience

    /// Pro 구매 성공 — 일반가 또는 Offer Code 모두
    static func logPaywallPurchase(productId: String, isOfferCode: Bool, offerCode: String? = nil, currency: String = "USD", revenue: Double? = nil) {
        var params: [AnalyticsParam: Any] = [
            .productId: productId,
            .priceTier: isOfferCode ? "offer" : "regular",
            .currency: currency
        ]
        if let revenue { params[.revenue] = revenue }
        if let offerCode { params[.offerCode] = offerCode }

        log(.paywallPurchase, parameters: params)

        // Offer Code인 경우 별도 이벤트도 함께 (분석 편의)
        if isOfferCode, let offerCode {
            log(.offerCodeRedeemed, parameters: [
                .offerCode: offerCode,
                .productId: productId
            ])
        }
    }

    /// 메모 생성
    static func logMemoCreated(memoType: String, memoCount: Int) {
        log(.memoCreated, parameters: [
            .memoType: memoType,
            .memoCount: memoCount
        ])
    }
}
