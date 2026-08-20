//
//  AnalyticsService.swift
//  ClipKeyboard
//
//  Analytics 이벤트 호출 wrapper.
//  - Firebase 제거됨: 콘솔 print + (메인 앱에서 켜 주면) 익명 사용 통계 허브 전송.
//  - 이벤트/파라미터 taxonomy는 향후 다른 백엔드로 교체할 때 그대로 재사용하려고 유지한다.
//  - 실제 백엔드를 붙일 땐 log()/setUserProperty() 본문만 바꾸면 모든 호출부가 그대로 동작한다.
//
//  ⚠️ 이 파일은 키보드 익스텐션 타겟에도 포함된다 - LeeoKit/CloudKit을 여기서 직접 참조하지 말 것.
//     전송은 메인 앱이 런치 시 `eventSink`를 꽂아 주는 방식으로만 연결한다(UsageReportingService).
//

import Foundation

/// 키보드를 쓴 **날짜별** 원장 - 익스텐션이 쌓고, 메인 앱이 비우며 허브로 소급 전송한다.
///
/// 왜 카운터 하나로 부족한가: `kbBeaconPendingCount`에는 "언제"가 없다. 앱을 2주 만에
/// 열면 그 2주치 활동이 전부 '앱을 연 날 하루'로 뭉쳐, 키보드만 쓰는 사람의 활동일이
/// 활성 사용자 추이에서 통째로 사라진다. 지금 메우려는 사각지대가 정확히 그것이다.
///
/// ⚠️ **앱과 키보드 익스텐션 양쪽에서 컴파일된다.** 익스텐션은 메모리 상한(약 60MB)
///    안에서 도니 무거운 의존을 들이지 말 것. 여기 있는 건 UserDefaults 읽기·쓰기뿐이다.
enum KeyboardDayLedger {

    /// 원장 보관 한도. 앱을 이보다 오래 안 열면 가장 오래된 날부터 버린다.
    /// (넉넉히 잡되 무한정 쌓이지는 않게 - 익스텐션이 매번 통째로 읽고 쓰는 사전이다)
    static let maxDays = 120

    /// 로컬 달력 기준 날짜 키. 사전순 = 시간순이라 오래된 날 정리에 그대로 쓴다.
    /// DateFormatter를 쓰지 않는 이유: 캐시하면 사용자가 시간대를 옮겼을 때 낡은 값이
    /// 남고, 매번 만들면 키보드가 뜰 때마다 값을 치른다.
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// 날짜 키 → 그날 **정오**. 자정이 아니라 정오인 건, 시간대가 바뀌어도
    /// 앞뒤 날짜로 넘어가지 않게 하려는 것이다(집계 묶음이 하루씩 밀리는 걸 막는다).
    static func date(fromDayKey key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    /// 키보드를 한 번 썼다고 기록. 익스텐션이 키보드가 뜰 때마다 호출한다.
    static func recordUse(at date: Date = Date()) {
        guard let defaults = AppGroup.defaults else { return }
        var days = (defaults.dictionary(forKey: DefaultsKey.kbBeaconDayCounts) as? [String: Int]) ?? [:]
        days[dayKey(for: date), default: 0] += 1
        if days.count > maxDays {
            for key in days.keys.sorted().prefix(days.count - maxDays) { days[key] = nil }
        }
        defaults.set(days, forKey: DefaultsKey.kbBeaconDayCounts)
    }

    /// 아직 허브로 보내지 않은 날짜들 (오래된 순).
    static func pendingDays() -> [String] {
        guard let defaults = AppGroup.defaults,
              let days = defaults.dictionary(forKey: DefaultsKey.kbBeaconDayCounts) as? [String: Int]
        else { return [] }
        return days.keys.sorted()
    }

    /// 전송을 확정한 날짜만 원장에서 지운다.
    /// ⚠️ 보내기 **전에** 지우지 말 것 - iCloud 미로그인이나 네트워크 실패로 못 보낸
    ///    날을 지우면 그 사람의 활동은 영영 복구되지 않는다.
    static func removeDays(_ keys: [String]) {
        guard !keys.isEmpty,
              let defaults = AppGroup.defaults,
              var days = defaults.dictionary(forKey: DefaultsKey.kbBeaconDayCounts) as? [String: Int]
        else { return }
        for key in keys { days[key] = nil }
        defaults.set(days, forKey: DefaultsKey.kbBeaconDayCounts)
    }
}

/// 추적할 이벤트 이름 - 표준 이름 (snake_case, 40자 이내)
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
    /// Paywall에서 구매 버튼을 탭함 (StoreKit 시트 진입 전) - "안 누름 vs 누르고 이탈" 분리
    case paywallCtaTapped = "paywall_cta_tapped"
    /// StoreKit 결제 사용자 취소
    case purchaseCancelled = "purchase_cancelled"
    /// StoreKit 결제 실패 (네트워크/검증/상품 등)
    case purchaseFailed = "purchase_failed"
    /// 가치 순간 Pro 넛지 노출
    case proNudgeShown = "pro_nudge_shown"
    /// 가치 순간 Pro 넛지 탭 → 페이월
    case proNudgeTapped = "pro_nudge_tapped"
    /// 온보딩을 끝까지 마침 - 획득 퍼널의 첫 단계.
    /// 설치는 했는데 여기서 끊기면 첫인상 문제이고, 여기는 통과했는데 단축어를
    /// 안 만들면 가치 전달 문제다. 둘을 구분하려고 남긴다.
    case onboardingCompleted = "onboarding_completed"
    /// 직전 런치가 끝까지 못 갔다 - `source` 에 멈춘 단계 이름이 실린다(LaunchGuard).
    /// 재현이 안 되는 런치 크래시를 **남의 기기에서** 잡아내는 유일한 통로다.
    case launchIncomplete = "launch_incomplete"
    /// 아낀 시간이 이정표에 닿았다 - `source` 에 이정표 이름이 실린다(oneMinute…oneWorkday).
    ///
    /// ⚠️ **초 단위 숫자는 보내지 않는다.** 보내는 것은 "이 설치가 어느 칸까지 갔는가"뿐이다.
    ///    이것만으로도 알고 싶던 것은 답이 나온다 - 몇 %가 1분을 넘고, 몇 %가 한 시간을
    ///    넘는가. 반대로 초를 보내면 그건 개인의 사용량 그 자체라 수집 항목이 늘어난다.
    case timeSavedMilestone = "time_saved_milestone"
}

/// 이벤트 파라미터 키 - 분석 시 슬라이싱용
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

    /// 이벤트 전송 훅 - 메인 앱이 런치 시 UsageReportingService를 연결한다.
    /// 키보드 익스텐션에서는 nil로 남아 콘솔 로깅만 수행한다.
    static var eventSink: ((String) -> Void)?

    /// 일반 이벤트 로깅
    static func log(_ event: AnalyticsEvent, parameters: [AnalyticsParam: Any] = [:]) {
        let stringKeyParams = parameters.reduce(into: [String: Any]()) { result, pair in
            result[pair.key.rawValue] = pair.value
        }
        print("📊 [Analytics] \(event.rawValue) \(stringKeyParams)")

        // 허브 전송 - 이름 + 슬라이스 한 조각(triggeredBy > source)만. 값 자체는 보내지 않는다.
        guard let eventSink else { return }
        let slice = (parameters[.triggeredBy] as? String) ?? (parameters[.source] as? String)
        eventSink(slice.map { "\(event.rawValue):\($0)" } ?? event.rawValue)
    }

    /// 사용자가 의도적으로 분석 거부 - UserDefaults 토글로 제어 가능 (향후 옵션)
    static func setCollectionEnabled(_ enabled: Bool) {
        print("📊 [Analytics] setCollectionEnabled=\(enabled)")
    }

    // MARK: - Convenience

    /// Pro 구매 성공 - 일반가 또는 Offer Code 모두
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

    /// Paywall 화면 노출 - 어떤 한도/진입점이 트리거했는지 기록
    static func logPaywallView(triggeredBy: String?) {
        var params: [AnalyticsParam: Any] = [:]
        if let triggeredBy { params[.triggeredBy] = triggeredBy }
        log(.paywallView, parameters: params)
    }

    /// 7일 무료 체험 시작 - 어떤 한도가 trial을 유도했는지 슬라이싱
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

    /// 키보드 사용 비콘 - 메인 앱 launch 시 호출. App Group에 익스텐션이 기록한 timestamp/카운트를 읽어 전송.
    /// 카운트 = 0이면 (= 비콘 미발생) 이벤트 생략. 보고 후 카운트 0으로 리셋.
    static func flushKeyboardBeacon() {
        guard let defaults = AppGroup.defaults else { return }
        let count = defaults.integer(forKey: DefaultsKey.kbBeaconPendingCount)
        guard count > 0 else { return }
        let lastUseEpoch = defaults.double(forKey: DefaultsKey.kbBeaconLastUse)
        let hoursSince = lastUseEpoch > 0
            ? Int((Date().timeIntervalSince1970 - lastUseEpoch) / 3600)
            : -1
        log(.keyboardUsed, parameters: [
            .useCount: count,
            .hoursSinceLastUse: hoursSince
        ])
        // 보고 완료 - 카운트만 리셋 (lastUse는 그대로 두어 cohort 분석 가능)
        // 누적 사용 횟수는 따로 쌓아 사용 통계 스냅샷 지표(keyboardUses)로 보낸다.
        let total = defaults.integer(forKey: DefaultsKey.kbBeaconTotalCount) + count
        defaults.set(total, forKey: DefaultsKey.kbBeaconTotalCount)
        defaults.set(0, forKey: DefaultsKey.kbBeaconPendingCount)
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

    // MARK: - User Properties (세그먼트 - 모든 퍼널을 이 축으로 쪼갤 수 있게)

    /// 런치 시 1회 - Pro 여부·페르소나·키보드 활성 여부를 유저 속성으로 설정.
    /// 이걸 박아두면 GA4에서 "페르소나별 전환", "키보드 켠 유저의 전환" 같은 슬라이싱이 가능.
    static func applyLaunchUserProperties(isPro: Bool, persona: String?, keyboardActive: Bool) {
        setUserProperty(isPro ? "yes" : "no", forName: "is_pro")
        setUserProperty(persona ?? "none", forName: "persona")
        setUserProperty(keyboardActive ? "yes" : "no", forName: "keyboard_active")
    }

    /// 메모 보유량 버킷 - 활성도/한도근접 세그먼트.
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
        // Firebase 제거됨 - 현재는 콘솔 로깅만 (백엔드 교체 지점)
        print("📊 [Analytics] userProperty \(name)=\(value)")
    }
}
