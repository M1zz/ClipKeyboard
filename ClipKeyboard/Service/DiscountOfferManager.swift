//
//  DiscountOfferManager.swift
//  ClipKeyboard
//
//  **반값 제안** - 평생 잠금해제를 반값에 살 수 있는 기회. 평생 **딱 한 번** 온다.
//
//   · 한도 한 칸 앞(`limitEdge`): 9개를 만들고 **일주일을 그 개수로 지낸** 사람에게 한 번.
//
//  MARK: 왜 설치 직후(`firstRun`) 를 없앴나 (5.2)
//
//  예전에는 설치 첫 주에도 반값을 보여 줬다. 그런데 그 사람은 이 앱이 자기에게 쓸모
//  있는지 **아직 모르는 사람**이다. 가치를 보기 전에 값부터 깎아 주면, 사는 사람은 반값에
//  사고 안 사는 사람은 "정가가 제값이 아니다" 는 사실만 배우고 간다. 그 뒤로 정가는
//  영영 진짜 값으로 안 보인다. 일시불 앱에서 기다리기 시작한 사람은 대개 영영 안 산다.
//
//  `limitEdge` 는 반대다. 한도에 닿아 본 사람은 이 앱이 자기에게 무엇인지 이미 알고,
//  그때의 반값은 광고가 아니라 거래다. 그래서 그 하나만 남긴다.
//
//  ⚠️ `.firstRun` 케이스 자체는 지우지 않는다. 이미 그 기록이 남아 있는 기기가 있고,
//     `DiscountOfferView` 도 그 문안을 들고 있다. 다만 `dueOccasion` 이 **다시는
//     돌려주지 않는다.** 판정은 한 곳에서만 한다.
//
//  왜 9개이고 일주일인가:
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

    /// 반값을 살 수 있는 자리.
    enum Occasion: String, CaseIterable, Sendable {
        /// 설치하고 얼마 안 된 사람에게 - **5.2에서 그만뒀다.** 판정이 다시는 돌려주지 않는다.
        /// (남겨 둔 이유는 파일 머리말에 적었다)
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

    /// 기회가 겨냥하는 개수 - **지금 이 사람의** 한도 한 칸 앞.
    /// ⚠️ 기본 한도가 아니라 `memoLimit` 을 본다. 칸을 산 사람(15개)에게 9개에서
    ///    "한 칸 남았다"고 말하면 거짓말이고, 정작 14개일 때는 아무 말도 안 하게 된다.
    static var limitEdgeCount: Int { limitEdge(forMemoLimit: ProFeatureManager.memoLimit) }

    /// 위 값의 순수한 규칙만 떼어 둔 것. 한도가 주어지면 겨냥할 개수는 이것 하나로 정해진다.
    ///
    /// 왜 나눠 두나: `limitEdgeCount` 는 App Group 에 남아 있는 Pro 권한·산 칸수를 읽는다.
    /// 그래서 시험이 그 값을 그대로 보면 **주변에 남은 상태에 따라 통과했다 실패했다** 한다
    /// (실제로 그랬다. 다른 시험이 키를 치워 줄 때만 초록이었다). 규칙 자체는 여기서
    /// 상태 없이 확인하고, 상태가 필요한 곳은 인자로 받는다.
    static func limitEdge(forMemoLimit limit: Int) -> Int { max(1, limit - 1) }

    /// 그 개수에 닿은 뒤 기다리는 날 수.
    static let waitDays = 7

    private static var waitInterval: TimeInterval { TimeInterval(waitDays) * 86_400 }

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
        /// 오래 손을 안 댔다가 지금 막 돌아왔는가(`UserActivity.dormant` · `.returning`).
        /// ⚠️ **돌아온 것 자체가 좋은 신호다.** 그 첫 화면이 결제 창이면 다시 나간다.
        var isAwayOrJustBack: Bool = false
        /// 만들어만 두고 대부분 안 쓰는 사람인가(`UserGrain.hoarder`).
        /// ⚠️ 이 사람에게 "칸이 한 칸 남았다"는 **틀린 말**이다. 칸이 모자란 것이 아니라
        ///    만들어 둔 것을 못 찾는 것이라, 한도를 사면 못 찾는 것이 하나 더 늘 뿐이다.
        var hoardsUnusedShortcuts: Bool = false
        /// 쓰임새로 보아 값을 깎아 권해도 되는가(`FeatureFit.allowsDiscountOffer`).
        /// ⚠️ 학생으로 확신하는 사람에게는 꺼내지 않는다. 그 사람에게는 친구에게 알리기가 따로 있다.
        var fitsDiscountOffer: Bool = true
    }

    /// 지금 띄울 기회가 있으면 그것을 돌려준다 - **순수 함수.**
    ///
    /// 남은 기회는 `limitEdge` 하나다. 한도에 닿아 본 사람은 이 앱이 자기에게 무엇인지
    /// 이미 안다. 그 앞에서만 값을 깎는다.
    ///
    /// ⚠️ `.firstRun` 은 **절대 돌려주지 않는다.** 가치를 보기 전의 할인은 정가에 대한
    ///    정보만 남긴다(자세한 이유는 파일 머리말).
    static func dueOccasion(now: Date = Date(), context: Context) -> Occasion? {
        guard !context.hasPro else { return nil }
        // 팔 수 없는 반값을 광고하지 않는다.
        guard context.discountAvailable else { return nil }
        // 오랜만에 돌아온 사람에게 먼저 꺼낼 말이 돈일 수는 없다.
        guard !context.isAwayOrJustBack else { return nil }
        // 튜토리얼이 화면을 잡고 있는 동안에는 그 위에 결제 창을 얹지 않는다.
        guard !context.isMidFirstShortcut else { return nil }
        // 쓰임새로 보아 값을 깎아 권할 사람이 아니다.
        guard context.fitsDiscountOffer else { return nil }

        if !context.shownOccasions.contains(.limitEdge),
           // 쌓아만 두는 사람에게 한도 이야기는 틀린 말이다(위 `hoardsUnusedShortcuts`).
           !context.hoardsUnusedShortcuts,
           let reachedAt = context.reachedLimitEdgeAt,
           now.timeIntervalSince(reachedAt) >= waitInterval {
            return .limitEdge
        }

        return nil
    }

    /// 지금 이 기기의 실제 상태로 위 판정을 돌린다.
    /// ⚠️ **숙련도 표(`UserSurface.slotLimit`)를 그대로 씌우지 않는다.** 그 표에서 한도
    ///    이야기는 익음 아래로 감춰지는데, 여기 ① 기회는 애초에 **설치 첫 주**를 겨냥한다.
    ///    표를 그대로 씌우면 그 기회가 통째로 사라진다. 이 화면이 상태 모델에서 가져오는
    ///    것은 두 겹뿐이다 - 휴면·복귀(먼저 말 걸지 않기)와 결(한도 이야기가 틀린 사람).
    @MainActor
    static func dueOccasionNow(discountAvailable: Bool, isMidFirstShortcut: Bool) -> Occasion? {
        let state = UserStateStore.shared.state
        return dueOccasion(context: Context(
            installedAt: installedAt,
            reachedLimitEdgeAt: reachedLimitEdgeAt,
            shownOccasions: shownOccasions,
            hasPro: ProFeatureManager.hasFullAccess,
            discountAvailable: discountAvailable,
            isMidFirstShortcut: isMidFirstShortcut,
            isAwayOrJustBack: state.activity != .active,
            hoardsUnusedShortcuts: state.grain == .hoarder,
            fitsDiscountOffer: FeatureFit.allowsDiscountOffer(PersonaResolver.profile)
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
    /// - Parameter edge: 겨냥하는 개수. 기본값은 지금 이 사람의 한도 한 칸 앞이다.
    ///   시험에서만 직접 넘긴다(주변 상태에 흔들리지 않게).
    static func noteShortcutCount(_ count: Int, edge: Int = limitEdgeCount) {
        guard count >= edge else { return }
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
