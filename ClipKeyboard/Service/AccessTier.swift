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
//  옵션(현대차의 선택 품목처럼 낮은 트림에 붙는 것)은 따로 산다: 칸 추가(`SlotPack`) ·
//  두 대째(`TwoDevicePack`). 트림이 아니라서 여기서 세지 않는다.
//
//  가격은 **한 번에 위를 사는 쪽이 늘 싸다.** 계단 하나를 오를 때마다 업그레이드 값(별도 상품)에
//  웃돈이 붙는다. StoreKit 은 이미 산 것을 근거로 할인해 주지 못해서 업그레이드는 상품으로만
//  만들 수 있다(`ProUpgrade` 와 같은 이유).
//
//  MARK: 왜 예전 상품을 다시 쓰나
//
//  새 상품을 다섯 개 만드는 대신 **이미 승인된 상품의 뜻을 넓혔다.**
//   · 플러스 = 예전 칸 추가 `slots5`(비소모성, 더 이상 칸으로는 안 팔던 것).
//     예전에 그걸 산 사람은 다섯 칸 대신 플러스를 받는다. 더 주는 쪽이라 빼앗는 사람이 없다.
//   · 플러스 → 프로 = `pro.upgrade`. 원래 "칸을 산 사람이 프로로 오르는 값" 이었고, 플러스가
//     바로 그 칸 상품이라 뜻이 그대로 이어진다. 칸 팩(소모성)을 산 사람도 계속 이 값을 본다.
//   · 마스터 두 상품만 새로 만든다. 마스터 기능이 생길 때 App Store Connect 에 올린다.
//     플러스에서 마스터로 바로 가는 값은 두지 않는다 - 플러스 → 프로 → 마스터로 오른다.
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

    /// 플러스 = 예전 칸 추가 `slots5` (비소모성). 이름과 값만 App Store Connect 에서 바꿨다.
    static let plusProductID = "com.Ysoup.TokenMemo.slots5"
    /// 플러스(또는 칸 팩)를 산 사람이 프로로 오르는 값 = 예전 `pro.upgrade`.
    static let plusToProProductID = "com.Ysoup.TokenMemo.pro.upgrade"
    /// 마스터 (비소모성). **아직 App Store Connect 에 없다** - 마스터 기능이 생길 때 만든다.
    /// 없는 동안에는 이 상품만 안 뜬다.
    static let masterProductID = "com.Ysoup.TokenMemo.tier.master"
    /// 프로를 가진 사람이 마스터로 오르는 값. **아직 없다**(위와 같다).
    static let proToMasterProductID = "com.Ysoup.TokenMemo.up.pro.master"

    /// 프로를 여는 예전 상품들. 정가 · 연 구독 · 반값.
    static let legacyProProductIDs: Set<String> = [
        "com.Ysoup.TokenMemo.pro",
        "com.Ysoup.TokenMemo.pro.yearly",
        "com.Ysoup.TokenMemo.pro.halfoff"
    ]

    /// 이 트림을 여는 상품들. **위 트림의 상품은 아래 트림도 연다**(`purchased` 가 가장 높은 것을 고른다).
    static func productIDs(opening tier: AccessTier) -> Set<String> {
        switch tier {
        case .free:   return []
        case .plus:   return [plusProductID]
        case .pro:    return legacyProProductIDs.union([plusToProProductID])
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
    static func purchased(from owned: Set<String>) -> AccessTier {
        for tier in allCases.reversed() where !owned.isDisjoint(with: productIDs(opening: tier)) {
            return tier
        }
        return .free
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
