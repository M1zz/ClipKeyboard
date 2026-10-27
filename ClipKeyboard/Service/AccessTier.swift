//
//  AccessTier.swift
//  ClipKeyboard / ClipKeyboardExtension
//
//  **트림** - 무료 · 플러스 · 프로 · 마스터. 쓴 기간이 길어질수록 필요한 것이 위에 있다.
//
//    무료     처음          (무료로 쓰는 기간이 끝나면 새로 만드는 것에 한도)
//    플러스   첫 달: 쌓기   단축어 · 템플릿 · 스택 · 이미지 무제한
//    프로     몇 달: 지키기 + iCloud 백업 · 생체 잠금 · 기기 간 동기화 (예전의 평생 Pro 그대로)
//    마스터   1년: 다스리기 + 오래 쓴 사람에게만 뜻이 있는 기능(아직 없다, 생기면 연다)
//
//  2026-10 요금제 개편: 유료 칸(플러스 · 프로)마다 **연 구독과 평생**을 나란히 판다. 연 구독은 같은
//  칸의 평생과 같은 권한이다. 구독 중인 사람은 졸업가(`proGraduateProductID`)로 프로 평생에 옮겨 갈 수 있고,
//  언제나 평생 패스(LeeoKit `LeeoForeverPass`)가 열려 있으면 프로다. 마스터는 체험용으로만 남는다.
//
//  옵션(현대차의 선택 품목처럼 낮은 트림에 붙는 것)은 따로 산다: 칸 추가(`SlotPack`) ·
//  두 대째(`TwoDevicePack`). 트림이 아니라서 여기서 세지 않는다.
//
//  가격은 **계단을 나눠 올라도 한 번에 사는 값보다 싸지지 않는다**(플러스 평생 + 올리기 = 프로 평생).
//  StoreKit 은 이미 산 것을 근거로 할인해 주지 못해서 업그레이드는 상품으로만
//  만들 수 있다(`ProUpgrade` 와 같은 이유).
//
//  MARK: 왜 예전 상품을 다시 쓰나
//
//  새 상품을 다섯 개 만드는 대신 **이미 승인된 상품의 뜻을 넓혔다.**
//   · 플러스 = 예전 칸 추가 `slots5`(비소모성, 더 이상 칸으로는 안 팔던 것).
//     예전에 그걸 산 사람은 다섯 칸 대신 플러스를 받는다. 더 주는 쪽이라 빼앗는 사람이 없다.
//   · 플러스 → 프로 = `pro.upgrade`. 원래 "칸을 산 사람이 프로로 오르는 값" 이었고, 플러스가
//     바로 그 칸 상품이라 뜻이 그대로 이어진다. 2026-10 부터는 **플러스 평생을 산 사람만** 이 값을 본다
//     (칸 팩 · 연 구독에 낸 값으로 프로 평생을 싸게 사는 뒷문이 되지 않게).
//   · 마스터 두 상품은 App Store Connect 에 없다. 체험용 트림으로만 남기고 팔지 않는다.
//
//  ⚠️ 상품 ID 는 App Store Connect · 영수증과의 계약이다. 등록한 뒤에는 바꾸지 않는다.
//  ⚠️ **예전에 판 Pro 는 그대로 프로다.** 판 것을 하나도 빼앗지 않는다. 그 사람이 새로 내는 것은
//     마스터로 오르는 값뿐이다.
//  ⚠️ 키보드 익스텐션은 StoreKit 을 못 본다. 앱이 산 트림을 App Group 에 새기고
//     (`StoreManager` → `mirror`), 익스텐션은 그 값을 읽는다.
//

import Foundation

enum AccessTier: Int, Comparable, CaseIterable {
    case free = 0
    case plus = 1
    case pro = 2
    case master = 3

    static func < (lhs: AccessTier, rhs: AccessTier) -> Bool { lhs.rawValue < rhs.rawValue }

    // MARK: - 상품

    // ⚠️ 문자열로 적는다. 익스텐션 타겟에는 `StoreManager` · `ProUpgrade` 가 없는 자리가 있다.
    //    같은 값이 `SlotPack.productID` · `ProUpgrade.productID` 등에도 있다(바꿀 일은 없다).

    /// 플러스 평생 = 예전 칸 추가 `slots5` (비소모성). 이름과 값만 App Store Connect 에서 바꿨다.
    static let plusProductID = "com.Ysoup.TokenMemo.slots5"
    /// 플러스 연 구독 (자동 갱신). 플러스 평생과 **같은 권한**을 기간으로 판다.
    static let plusYearlyProductID = "com.Ysoup.TokenMemo.plus.yearly"
    /// 프로 평생 (비소모성). 예전부터 판 바로 그 Pro 다.
    static let proProductID = "com.Ysoup.TokenMemo.pro"
    /// 프로 연 구독 (자동 갱신). 프로 평생과 같은 권한.
    static let proYearlyProductID = "com.Ysoup.TokenMemo.pro.yearly"
    /// 플러스 평생을 산 사람이 프로 평생으로 오르는 값 = 예전 `pro.upgrade`.
    static let plusToProProductID = "com.Ysoup.TokenMemo.pro.upgrade"
    /// 구독 졸업 = 구독 중인 사람이 사는 프로 평생(`LeeoGraduation`). 권한은 프로 평생과 같다.
    static let proGraduateProductID = "com.Ysoup.TokenMemo.pro.graduate"
    /// 마스터 (비소모성). **App Store Connect 에 없다**. 체험용 트림으로만 남기고 팔지 않는다.
    static let masterProductID = "com.Ysoup.TokenMemo.tier.master"
    /// 프로를 가진 사람이 마스터로 오르는 값. **없다**(위와 같다).
    static let proToMasterProductID = "com.Ysoup.TokenMemo.up.pro.master"

    /// 판매를 멈춘 프로 상품. **산 사람의 권한은 그대로다**(2026-10 요금제 개편).
    /// 반값 Pro 는 더 팔지 않지만 권한 목록에서는 절대 빼지 않는다.
    static let retiredProProductIDs: Set<String> = ["com.Ysoup.TokenMemo.pro.halfoff"]

    /// 자동 갱신 구독 상품. 구독 졸업을 묻는 곳(`LeeoGraduation`)이 이 목록을 본다.
    static let subscriptionProductIDs: Set<String> = [plusYearlyProductID, proYearlyProductID]

    /// 이 트림을 여는 상품들. **위 트림의 상품은 아래 트림도 연다**(`purchased` 가 가장 높은 것을 고른다).
    /// 연 구독은 같은 칸의 평생과 같은 권한이다. 구독이 끝나면 StoreKit 권한 목록에서 빠져 저절로 닫힌다.
    static func productIDs(opening tier: AccessTier) -> Set<String> {
        switch tier {
        case .free:   return []
        case .plus:   return [plusProductID, plusYearlyProductID]
        case .pro:    return retiredProProductIDs.union([proProductID, proYearlyProductID,
                                                         plusToProProductID, proGraduateProductID])
        case .master: return [masterProductID, proToMasterProductID]
        }
    }

    /// 트림을 여는 상품 전부. 칸 팩(소모성) · 두 대째는 들어가지 않는다(옵션이지 트림이 아니다).
    static var allTierProductIDs: Set<String> {
        Set(allCases.flatMap { productIDs(opening: $0) })
    }

    /// 프로 이상을 여는 상품. 예전부터 "Pro 권한" 으로 보던 목록(`ClipKeyboardSpec.entitlementIDs`)이 이것이다.
    ///
    /// ⚠️ 플러스는 넣지 않는다. 넣으면 플러스를 산 사람에게 백업 · 잠금 · 동기화가 열린다.
    static var proOrHigherProductIDs: Set<String> {
        productIDs(opening: .pro).union(productIDs(opening: .master))
    }

    /// 가진 상품들이 여는 가장 높은 트림. **순수 함수.**
    ///
    /// 업그레이드 값만 있고 아래 트림이 없어도(환불 · 가족 공유가 엇갈린 경우) 그 위 트림을 연다.
    /// 돈을 낸 상품이 아무것도 안 여는 것보다는 낫다.
    ///
    /// - Parameter foreverPass: 언제나 평생 패스가 열려 있는가(`LeeoForeverPass`). 패스는 이 앱의
    ///   가장 높은 유료 칸인 **프로**를 연다. 패스 상품 ID 는 `owned` 에 있어도 여기서 세지 않는다.
    static func purchased(from owned: Set<String>, foreverPass: Bool = false) -> AccessTier {
        let bought = allCases.reversed().first { !owned.isDisjoint(with: productIDs(opening: $0)) } ?? .free
        return foreverPass ? max(bought, .pro) : bought
    }

    /// 프로를 **평생**으로 가졌는가(구독은 빼고 본다). 패스 화면이 올리기 값을 보일지 정한다.
    static func ownsLifetimePro(_ owned: Set<String>) -> Bool {
        purchased(from: owned.subtracting(subscriptionProductIDs)) >= .pro
    }

    /// 플러스를 **평생**으로 가졌는가. 그 사람에게만 프로 평생을 올리기 값(`plusToProProductID`)으로 판다.
    static func ownsLifetimePlus(_ owned: Set<String>) -> Bool {
        owned.contains(plusProductID)
    }

    // MARK: - 산 트림 (App Group 미러)

    /// 앱이 마지막으로 새긴 산 트림. 새긴 적이 없으면 nil.
    static var mirrored: AccessTier? {
        guard let raw = AppGroup.defaults?.object(forKey: DefaultsKey.purchasedTier) as? Int else { return nil }
        return AccessTier(rawValue: raw)
    }

    /// 결제 권한에서 읽은 트림을 App Group 에 새긴다(앱 프로세스에서만 부른다).
    static func mirror(_ tier: AccessTier) {
        guard tier != mirrored else { return }
        AppGroup.defaults?.set(tier.rawValue, forKey: DefaultsKey.purchasedTier)
        print("🔧 [AccessTier.mirror] 산 트림 = \(tier)")
    }

    /// 개발 중에 되돌린다.
    static func resetForTesting() {
        AppGroup.defaults?.removeObject(forKey: DefaultsKey.purchasedTier)
    }
}
