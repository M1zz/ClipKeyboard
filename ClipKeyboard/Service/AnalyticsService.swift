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
    /// Paywall 화면 노출
    case paywallView = "paywall_view"
    /// Pro 잠금 해제 결제 성공
    case paywallPurchase = "paywall_purchase"
    /// 메모 추가
    case memoCreated = "memo_created"
    /// Apple Offer Code (예: APRIL) 리딤으로 인한 구매
    case offerCodeRedeemed = "offer_code_redeemed"
    /// 키보드 익스텐션 사용 (App Group 비콘 → 메인 앱 launch 시점에 전송)
    case keyboardUsed = "keyboard_used"
    /// 일괄 가져오기 (BulkImport)로 메모 저장
    case bulkImported = "bulk_imported"
    /// 7일 무료 체험 시작
    case trialStarted = "trial_started"
    /// Paywall을 구매 없이 닫음 (닫기율 = view 대비)
    case paywallDismissed = "paywall_dismissed"
    /// Paywall에서 구매 버튼을 탭함 (StoreKit 시트 진입 전) — "안 누름 vs 누르고 이탈" 분리
    case paywallCtaTapped = "paywall_cta_tapped"
    /// StoreKit 결제 사용자 취소
    case purchaseCancelled = "purchase_cancelled"
    /// StoreKit 결제 실패 (네트워크/검증/상품 등)
    case purchaseFailed = "purchase_failed"
    /// 가치 순간 Pro 넛지 노출
    case proNudgeShown = "pro_nudge_shown"
    /// 가치 순간 Pro 넛지 탭 → 페이월
    case proNudgeTapped = "pro_nudge_tapped"
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
    case useCount = "use_count"            // 누적 키보드 사용 횟수 (마지막 보고 이후)
    case hoursSinceLastUse = "hours_since_last_use"  // 마지막 키보드 사용 후 경과 시간
    case importedCount = "imported_count"  // BulkImport로 저장한 메모 수
    case triggeredBy = "triggered_by"      // paywall 노출/구매를 유도한 한도 (memo, combo, image_memo 등)
    case reason = "reason"                 // 실패/취소 사유
    case source = "source"                 // 넛지 종류 등 (time_saved | slots_left)
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
    static func logPaywallPurchase(productId: String, isOfferCode: Bool, offerCode: String? = nil, currency: String = "USD", revenue: Double? = nil, triggeredBy: String? = nil) {
        var params: [AnalyticsParam: Any] = [
            .productId: productId,
            .priceTier: isOfferCode ? "offer" : "regular",
            .currency: currency
        ]
        if let revenue { params[.revenue] = revenue }
        if let offerCode { params[.offerCode] = offerCode }
        if let triggeredBy { params[.triggeredBy] = triggeredBy }

        log(.paywallPurchase, parameters: params)

        // Offer Code인 경우 별도 이벤트도 함께 (분석 편의)
        if isOfferCode, let offerCode {
            log(.offerCodeRedeemed, parameters: [
                .offerCode: offerCode,
                .productId: productId
            ])
        }
    }

    /// Paywall 화면 노출 — 어떤 한도/진입점이 트리거했는지 기록
    static func logPaywallView(triggeredBy: String?) {
        var params: [AnalyticsParam: Any] = [:]
        if let triggeredBy { params[.triggeredBy] = triggeredBy }
        log(.paywallView, parameters: params)
    }

    /// 7일 무료 체험 시작 — 어떤 한도가 trial을 유도했는지 슬라이싱
    static func logTrialStarted(triggeredBy: String?) {
        var params: [AnalyticsParam: Any] = [:]
        if let triggeredBy { params[.triggeredBy] = triggeredBy }
        log(.trialStarted, parameters: params)
    }

    /// 메모 생성
    static func logMemoCreated(memoType: String, memoCount: Int) {
        log(.memoCreated, parameters: [
            .memoType: memoType,
            .memoCount: memoCount
        ])
    }

    /// 키보드 사용 비콘 — 메인 앱 launch 시 호출. App Group에 익스텐션이 기록한 timestamp/카운트를 읽어 전송.
    /// 카운트 = 0이면 (= 비콘 미발생) 이벤트 생략. 보고 후 카운트 0으로 리셋.
    static func flushKeyboardBeacon() {
        guard let defaults = UserDefaults(suiteName: AppGroup.identifier) else { return }
        let count = defaults.integer(forKey: "kb.beacon.pendingCount")
        guard count > 0 else { return }
        let lastUseEpoch = defaults.double(forKey: "kb.beacon.lastUse")
        let hoursSince = lastUseEpoch > 0
            ? Int((Date().timeIntervalSince1970 - lastUseEpoch) / 3600)
            : -1
        log(.keyboardUsed, parameters: [
            .useCount: count,
            .hoursSinceLastUse: hoursSince
        ])
        // 보고 완료 — 카운트만 리셋 (lastUse는 그대로 두어 cohort 분석 가능)
        defaults.set(0, forKey: "kb.beacon.pendingCount")
    }

    /// 일괄 가져오기로 메모 N개 저장
    static func logBulkImported(count: Int) {
        log(.bulkImported, parameters: [.importedCount: count])
    }

    // MARK: - Paywall micro-funnel

    static func logPaywallDismissed(triggeredBy: String?) {
        log(.paywallDismissed, parameters: triggeredBy.map { [.triggeredBy: $0] } ?? [:])
    }

    static func logPaywallCtaTapped(triggeredBy: String?, isTrial: Bool) {
        var params: [AnalyticsParam: Any] = [.source: isTrial ? "trial" : "buy"]
        if let triggeredBy { params[.triggeredBy] = triggeredBy }
        log(.paywallCtaTapped, parameters: params)
    }

    static func logPurchaseCancelled(triggeredBy: String?) {
        log(.purchaseCancelled, parameters: triggeredBy.map { [.triggeredBy: $0] } ?? [:])
    }

    static func logPurchaseFailed(reason: String, triggeredBy: String?) {
        var params: [AnalyticsParam: Any] = [.reason: String(reason.prefix(90))]
        if let triggeredBy { params[.triggeredBy] = triggeredBy }
        log(.purchaseFailed, parameters: params)
    }

    static func logProNudge(_ event: AnalyticsEvent, source: String) {
        log(event, parameters: [.source: source])
    }

    // MARK: - User Properties (세그먼트 — 모든 퍼널을 이 축으로 쪼갤 수 있게)

    /// 런치 시 1회 — Pro 여부·페르소나·키보드 활성 여부를 유저 속성으로 설정.
    /// 이걸 박아두면 GA4에서 "페르소나별 전환", "키보드 켠 유저의 전환" 같은 슬라이싱이 가능.
    static func applyLaunchUserProperties(isPro: Bool, persona: String?, keyboardActive: Bool) {
        setUserProperty(isPro ? "yes" : "no", forName: "is_pro")
        setUserProperty(persona ?? "none", forName: "persona")
        setUserProperty(keyboardActive ? "yes" : "no", forName: "keyboard_active")
    }

    /// 메모 보유량 버킷 — 활성도/한도근접 세그먼트.
    static func setMemoBucket(_ count: Int) {
        let bucket: String
        switch count {
        case 0:         bucket = "0"
        case 1..<10:    bucket = "1-9"
        case 10:        bucket = "10_at_limit"
        case 11..<50:   bucket = "11-49"
        default:        bucket = "50+"
        }
        setUserProperty(bucket, forName: "memo_bucket")
    }

    private static func setUserProperty(_ value: String, forName name: String) {
        #if !KEYBOARD_EXTENSION && canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: name)
        #endif
        print("📊 [Analytics] userProperty \(name)=\(value)")
    }
}
