//
//  DiscountOfferManager.swift
//  ClipKeyboard
//
//  **반값 제안** - 평생 잠금해제를 반값에 살 수 있는 기회. 딱 두 번 온다.
//
//   ① 설치 직후(`firstRun`)   : 시작하는 김에 열어 둘 사람에게. 첫 주 안에 한 번.
//   ② 한도 한 칸 앞(`limitEdge`): 9개를 만들고 **일주일을 그 개수로 지낸** 사람에게 한 번.
//
//  왜 둘인가: 둘은 다른 사람이다. ①은 "이 앱이 마음에 들면 그냥 사 두는" 쪽이고,
//  ②는 써 보고 한도에 닿아 **비용이 실제로 느껴진** 쪽이다. 한쪽만 두면 나머지 한쪽은
//  평생 정가만 본다. 그렇다고 아무 때나 띄우면 결제 창이 따라다니는 앱이 되므로,
//  기회는 각각 **한 번씩**이고 한 번 지나가면 다시 오지 않는다.
//
//  왜 ②가 9개이고 일주일인가:
//   · 9개는 한 칸 남았다는 뜻이다. 열 번째에서 막히기 **전**이라, 벽에 부딪힌 사람을
//     붙잡는 것이 아니라 벽이 보이기 시작한 사람에게 미리 길을 내주는 자리다.
//   · 닿자마자 들이밀지 않는다. 하루 만에 9개를 채운 사람은 아직 이 앱이 자기에게
//     필요한지 모른다. 일주일을 그 개수로 지냈다면 쓰고 있다는 뜻이고, 그때의 제안은
//     광고가 아니라 거래가 된다.
//
//  ⚠️ 할인 상품이 실제로 로드되지 않으면 **제안 자체를 띄우지 않는다.** 반값이라 말해 놓고
//     정가를 결제시키는 것은 거짓말이다. 판정은 `dueOccasion(...)` 한 곳에서만 한다.
//

import Foundation

enum DiscountOfferManager {

    // MARK: - 기회

    /// 반값을 살 수 있는 자리. 각각 한 번씩만 온다.
    enum Occasion: String, CaseIterable, Sendable {
        /// 설치하고 얼마 안 된 사람에게 - 첫 주 안에 한 번.
        case firstRun
        /// 무료 한도 한 칸 앞에서 일주일을 지낸 사람에게 - 한 번.
        case limitEdge
    }

    // MARK: - 상수

    /// 반값 상품 ID.
    /// ⚠️ App Store Connect 에 **별도 비소모성 상품**으로 등록해야 한다. StoreKit 은 비소모성
    ///    상품에 할인을 걸 수단이 없어서, 반값은 "다른 상품"으로만 팔 수 있다.
    ///    두 상품 모두 `ClipKeyboardSpec.monetization` 의 productIDs 에 있어 어느 쪽을 사도 Pro 다.
    static let discountedProProductID = "com.Ysoup.TokenMemo.pro.halfoff"

    /// ② 기회가 겨냥하는 개수 - **지금 이 사람의** 한도 한 칸 앞.
    /// ⚠️ 기본 한도가 아니라 `memoLimit` 을 본다. 칸을 산 사람(15개)에게 9개에서
    ///    "한 칸 남았다"고 말하면 거짓말이고, 정작 14개일 때는 아무 말도 안 하게 된다.
    static var limitEdgeCount: Int { max(1, ProFeatureManager.memoLimit - 1) }

    /// ② 그 개수에 닿은 뒤 기다리는 날 수.
    static let waitDays = 7

    /// ① 기회가 열려 있는 기간(설치 후 며칠까지).
    ///
    /// ⚠️ 첫 실행 그 자리에서만 노리지 않는다. 설치 직후에는 안내와 튜토리얼이 줄을 서 있어
    ///    양보하다 보면 못 뜨는 날이 흔하다. 첫 주를 창으로 두면 다음 실행에서 조용히 만난다.
    static let firstRunWindowDays = 7

    private static var waitInterval: TimeInterval { TimeInterval(waitDays) * 86_400 }
    private static var firstRunWindow: TimeInterval { TimeInterval(firstRunWindowDays) * 86_400 }

    /// ⚠️ 공유 저장소로 가는 문은 `AppGroup.defaults` 하나다(매번 새로 만들지 않는다).
    private static var defaults: UserDefaults? { AppGroup.defaults }

    // MARK: - 판정에 필요한 것들

    /// 판정 입력을 한 덩어리로 - 순수 함수로 두어 그대로 테스트한다.
    struct Context {
        /// 앱을 설치한 시각(`app_install_date`).
        var installedAt: Date?
        /// 한도 한 칸 앞에 **처음** 닿은 시각.
        var reachedLimitEdgeAt: Date?
        /// 이미 띄운 기회들.
        var shownOccasions: Set<Occasion>
        /// 이미 Pro 인가(구매·그랜드파더·체험 포함).
        var hasPro: Bool
        /// 반값 상품이 실제로 로드됐는가.
        var discountAvailable: Bool
        /// 첫 단축어를 아직 만들지도 건너뛰지도 않았는가.
        /// ⚠️ 이때는 튜토리얼 시트가 화면을 잡고 있다. 그 위에 결제 창을 얹지 않는다.
        var isMidFirstShortcut: Bool
    }

    /// 지금 띄울 기회가 있으면 그것을 돌려준다 - **순수 함수.**
    ///
    /// 둘 다 자격이 되면 `limitEdge` 가 이긴다. 그쪽이 더 뚜렷한 신호이기 때문이다
    /// (한도에 닿아 본 사람은 이 앱이 자기에게 무엇인지 이미 안다).
    static func dueOccasion(now: Date = Date(), context: Context) -> Occasion? {
        guard !context.hasPro else { return nil }
        // 팔 수 없는 반값을 광고하지 않는다.
        guard context.discountAvailable else { return nil }

        if !context.shownOccasions.contains(.limitEdge),
           let reachedAt = context.reachedLimitEdgeAt,
           now.timeIntervalSince(reachedAt) >= waitInterval {
            return .limitEdge
        }

        if !context.shownOccasions.contains(.firstRun),
           !context.isMidFirstShortcut,
           let installedAt = context.installedAt,
           now.timeIntervalSince(installedAt) <= firstRunWindow {
            return .firstRun
        }

        return nil
    }

    /// 지금 이 기기의 실제 상태로 위 판정을 돌린다.
    @MainActor
    static func dueOccasionNow(discountAvailable: Bool, isMidFirstShortcut: Bool) -> Occasion? {
        dueOccasion(context: Context(
            installedAt: installedAt,
            reachedLimitEdgeAt: reachedLimitEdgeAt,
            shownOccasions: shownOccasions,
            hasPro: ProFeatureManager.hasFullAccess,
            discountAvailable: discountAvailable,
            isMidFirstShortcut: isMidFirstShortcut
        ))
    }

    /// 상품 얘기를 빼고 **때가 됐는가**만 본다.
    ///
    /// ⚠️ 상품 로드는 네트워크다. 대상이 아닌 사람(대부분)에게까지 런치마다 스토어를
    ///    두드리지 않으려고, 싼 조건을 먼저 통과한 뒤에만 상품을 부른다.
    @MainActor
    static func isDueIgnoringProduct(isMidFirstShortcut: Bool) -> Bool {
        dueOccasionNow(discountAvailable: true, isMidFirstShortcut: isMidFirstShortcut) != nil
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

    /// 설치 시각 - 앱이 첫 실행에 찍어 두는 값(표준 UserDefaults).
    static var installedAt: Date? {
        UserDefaults.standard.object(forKey: DefaultsKey.appInstallDate) as? Date
    }

    /// 이미 띄운 기회들.
    static var shownOccasions: Set<Occasion> {
        let raw = defaults?.stringArray(forKey: DefaultsKey.discountOfferShownOccasions) ?? []
        return Set(raw.compactMap(Occasion.init(rawValue:)))
    }

    /// 띄웠다고 못박는다 - 시트를 여는 그 자리에서 부른다(닫는 방법과 무관하게 1회를 보장).
    static func markShown(_ occasion: Occasion) {
        var shown = shownOccasions
        shown.insert(occasion)
        defaults?.set(shown.map(\.rawValue), forKey: DefaultsKey.discountOfferShownOccasions)
        print("📌 [DiscountOfferManager] 반값 제안 노출 기록: \(occasion.rawValue)")
    }

    // MARK: - 진단

    /// 개발 중에 조건을 되돌린다(설정 > 개발자 화면에서 부를 수 있게 열어 둔다).
    static func resetForTesting() {
        defaults?.removeObject(forKey: DefaultsKey.discountOfferReachedLimitEdgeAt)
        defaults?.removeObject(forKey: DefaultsKey.discountOfferShownOccasions)
    }
}
