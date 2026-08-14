//
//  DiscountOfferManager.swift
//  ClipKeyboard
//
//  **반값 제안** - 무료 한도 한 칸 앞(9개)에서 일주일을 버틴 사람에게 한 번 건네는 제안.
//
//  왜 9개이고 왜 일주일인가:
//   · 9개는 한 칸 남았다는 뜻이다. 열 번째를 만들려다 막히기 **전**이라, 벽에 부딪힌
//     사람을 붙잡는 것이 아니라 벽이 보이기 시작한 사람에게 미리 길을 내주는 자리다.
//   · 닿자마자 들이밀지 않는다. 하루 만에 9개를 채운 사람은 아직 이 앱이 자기에게
//     필요한지 모른다. 일주일을 그 개수로 지냈다면 **쓰고 있다**는 뜻이고, 그때의 제안은
//     광고가 아니라 거래가 된다.
//
//  ⚠️ 할인 상품이 실제로 로드되지 않으면 **제안 자체를 띄우지 않는다.** 반값이라 말해 놓고
//     정가를 결제시키는 것은 거짓말이다. 판정은 `shouldOffer(...)` 한 곳에서만 한다.
//
//  ⚠️ 한 번만 뜬다(`discountOfferShownAt`). 되풀이되는 결제 창은 그 자체로 앱을 미워하게
//     만든다. 놓친 사람은 설정 > Pro 에서 언제든 정가로 살 수 있다.
//

import Foundation

enum DiscountOfferManager {

    // MARK: - 상수

    /// 반값 상품 ID.
    /// ⚠️ App Store Connect 에 **별도 비소모성 상품**으로 등록해야 한다. StoreKit 은 비소모성
    ///    상품에 할인을 걸 수단이 없어서, 반값은 "다른 상품"으로만 팔 수 있다.
    ///    두 상품 모두 `ClipKeyboardSpec.paywall.entitlementIDs` 에 들어 있어 어느 쪽을 사도 Pro 다.
    static let discountedProProductID = "com.Ysoup.TokenMemo.pro.halfoff"

    /// 제안이 겨냥하는 개수 - 무료 한도 한 칸 앞.
    static var limitEdgeCount: Int { max(1, ProFeatureManager.freeMemoLimit - 1) }

    /// 그 개수에 닿은 뒤 기다리는 날 수.
    static let waitDays = 7

    private static var waitInterval: TimeInterval { TimeInterval(waitDays) * 86_400 }

    private static var defaults: UserDefaults? {
        AppGroup.defaults
    }

    // MARK: - 기록

    /// 단축어 개수가 바뀔 때마다 불린다 - 한 칸 앞에 **처음** 닿은 시각만 남긴다.
    ///
    /// ⚠️ 개수가 도로 줄었다고 지우지 않는다. 지우면 하나 지웠다 다시 만드는 것만으로
    ///    시계가 초기화돼, 오래 쓴 사람일수록 제안을 못 받는 거꾸로 된 규칙이 된다.
    static func noteShortcutCount(_ count: Int) {
        guard count >= limitEdgeCount else { return }
        guard reachedLimitEdgeAt == nil else { return }
        defaults?.set(Date().timeIntervalSince1970, forKey: DefaultsKey.discountOfferReachedLimitEdgeAt)
        print("📌 [DiscountOfferManager] 한도 한 칸 앞(\(count)개) 도달 기록")
    }

    /// 한 칸 앞에 처음 닿은 시각.
    static var reachedLimitEdgeAt: Date? {
        let raw = defaults?.double(forKey: DefaultsKey.discountOfferReachedLimitEdgeAt) ?? 0
        return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
    }

    /// 제안을 이미 띄웠는가.
    static var wasShown: Bool {
        (defaults?.double(forKey: DefaultsKey.discountOfferShownAt) ?? 0) > 0
    }

    /// 띄웠다고 못박는다 - 시트를 여는 그 자리에서 부른다(닫는 방법과 무관하게 1회를 보장).
    static func markShown() {
        defaults?.set(Date().timeIntervalSince1970, forKey: DefaultsKey.discountOfferShownAt)
    }

    // MARK: - 판정

    /// 지금 제안을 띄워도 되는가 - **순수 함수**라 그대로 테스트할 수 있다.
    ///
    /// - Parameters:
    ///   - reachedAt: 한 칸 앞에 처음 닿은 시각(`nil`이면 아직 닿은 적 없음).
    ///   - alreadyShown: 이미 한 번 띄웠는가.
    ///   - hasPro: 이미 Pro 인가(구매·그랜드파더·체험 포함).
    ///   - discountAvailable: 반값 상품이 실제로 로드됐는가.
    static func shouldOffer(now: Date = Date(),
                            reachedAt: Date?,
                            alreadyShown: Bool,
                            hasPro: Bool,
                            discountAvailable: Bool) -> Bool {
        guard !hasPro else { return false }
        guard !alreadyShown else { return false }
        // 팔 수 없는 반값을 광고하지 않는다.
        guard discountAvailable else { return false }
        guard let reachedAt else { return false }
        return now.timeIntervalSince(reachedAt) >= waitInterval
    }

    /// 지금 이 기기의 실제 상태로 위 판정을 돌린다.
    @MainActor
    static func shouldOfferNow(discountAvailable: Bool) -> Bool {
        shouldOffer(reachedAt: reachedLimitEdgeAt,
                    alreadyShown: wasShown,
                    hasPro: ProFeatureManager.hasFullAccess,
                    discountAvailable: discountAvailable)
    }

    /// 상품 얘기를 빼고 **때가 됐는가**만 본다.
    ///
    /// ⚠️ 상품 로드는 네트워크다. 대상이 아닌 사람(대부분)에게까지 런치마다 스토어를
    ///    두드리지 않으려고, 싼 조건을 먼저 통과한 뒤에만 상품을 부른다.
    @MainActor
    static var isDueIgnoringProduct: Bool {
        shouldOfferNow(discountAvailable: true)
    }

    // MARK: - 진단

    /// 개발 중에 조건을 되돌린다(설정 > 개발자 화면에서 부를 수 있게 열어 둔다).
    static func resetForTesting() {
        defaults?.removeObject(forKey: DefaultsKey.discountOfferReachedLimitEdgeAt)
        defaults?.removeObject(forKey: DefaultsKey.discountOfferShownAt)
    }
}
