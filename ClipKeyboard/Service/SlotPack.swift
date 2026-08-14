//
//  SlotPack.swift
//  ClipKeyboard
//
//  **칸 추가** - 무료 한도에 다섯 칸을 더하는 작은 상품. 페이월에 늘 서 있다.
//
//  가격표에서의 자리:
//    +5칸 $3   (상시)      ← 여기
//    평생 $9.99 (상시)
//    평생 $4.99 (2회 한정 반값 제안, `DiscountOfferManager`)
//
//  왜 두 상품을 나란히 두는가: 늘 보이는 작은 값이 있어야 가끔 오는 반값이 싸 보인다.
//  거꾸로, 평생이 부담스러운 사람에게는 다섯 칸만 사고 계속 쓰는 길이 생긴다.
//
//  ⚠️ **칸을 샀다고 Pro 가 되는 것은 아니다.** `ClipKeyboardSpec` 의 `entitlementIDs` 에
//     이 상품을 넣지 않는 이유다(기본값이 "파는 상품 전체"라 가만두면 Pro 가 되어 버린다).
//     이 상품이 여는 것은 개수 하나뿐이고, 그 밖의 Pro 기능은 그대로 잠겨 있다.
//
//  ⚠️ 비소모성이라 **한 번만** 살 수 있다. 다섯 칸을 여러 번 쌓을 수는 없다
//     (반복 구매가 필요하면 소모성으로 바꿔야 하는데, 그러면 복원이 안 돼 심사에서 걸린다).
//
//  ⚠️ 키보드 익스텐션은 StoreKit 을 보지 않는다. Pro 여부와 마찬가지로 **산 칸수도**
//     App Group 에 미러링해서 익스텐션이 같은 한도를 보게 한다(`StoreManager.mirrorSlotPack`).
//

import Foundation

enum SlotPack {

    /// 칸 추가 상품 ID.
    /// ⚠️ App Store Connect 에 **비소모성**으로 등록한다. 변경 금지(영수증과의 계약).
    static let productID = "com.Ysoup.TokenMemo.slots5"

    /// 이 상품이 더해 주는 칸수.
    static let slotsPerPack = 5

    /// 산 칸수 - 익스텐션도 읽는 App Group 값.
    /// 안 샀으면 0, 샀으면 `slotsPerPack`.
    static var purchasedSlots: Int {
        AppGroup.defaults?.integer(forKey: DefaultsKey.purchasedExtraSlots) ?? 0
    }

    /// 칸을 샀는가 - 페이월에서 "이미 가진 것"으로 표시할 때 쓴다.
    static var isPurchased: Bool { purchasedSlots > 0 }

    /// 결제 권한에서 읽은 값을 App Group 에 새긴다(앱 프로세스에서만 부른다).
    static func mirror(purchased: Bool) {
        let slots = purchased ? slotsPerPack : 0
        guard slots != purchasedSlots else { return }
        AppGroup.defaults?.set(slots, forKey: DefaultsKey.purchasedExtraSlots)
        print("🔧 [SlotPack.mirror] 추가 칸수 = \(slots)")
    }
}
