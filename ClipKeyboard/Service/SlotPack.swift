//
//  SlotPack.swift
//  ClipKeyboard
//
//  **칸 추가** - 무료 한도에 다섯 칸을 더하는 작은 상품. 페이월에 늘 서 있다.
//
//  가격표에서의 자리:
//    +5칸  (상시, 최대 세 번)      ← 여기
//    평생  (상시)
//    평생  (칸을 산 사람만 보는 업그레이드 값, `ProUpgrade`)
//    평생  (한 번뿐인 반값 제안, `DiscountOfferManager`)
//
//  왜 작은 값이 필요한가: 늘 보이는 작은 값이 있어야 가끔 오는 반값이 싸 보인다.
//  거꾸로, 평생이 부담스러운 사람에게는 다섯 칸만 사고 계속 쓰는 길이 생긴다.
//
//  ⚠️ **칸을 샀다고 Pro 가 되는 것은 아니다.** `ClipKeyboardSpec` 의 `entitlementIDs` 에
//     이 상품을 넣지 않는 이유다(기본값이 "파는 상품 전체"라 가만두면 Pro 가 되어 버린다).
//     이 상품이 여는 것은 개수 하나뿐이고, 그 밖의 Pro 기능은 그대로 잠겨 있다.
//
//  ⚠️ 키보드 익스텐션은 StoreKit 을 보지 않는다. Pro 여부와 마찬가지로 **산 칸수도**
//     App Group 에 미러링해서 익스텐션이 같은 한도를 보게 한다.
//
//  MARK: 왜 상품이 둘인가 (5.2)
//
//  처음 판 `slots5` 는 **비소모성**이라 한 번밖에 못 산다. 그래서 "조금씩 늘려 쓴다" 는
//  길이 실제로는 15칸에서 끊겼다. 20칸이 필요해진 사람에게 남은 선택지는 평생 Pro 하나뿐인데,
//  그 사람은 방금 돈을 낸 사람이라 다음 결제가 더 비싸게 느껴진다. 소액 결제가 다음 결제를
//  막는 구조였다.
//
//  고치는 방법은 상품 종류를 바꾸는 것인데, **App Store Connect 에 이미 올린 상품의 종류는
//  바꿀 수 없다.** 그래서 소모성 상품을 하나 더 만든다(`slots5.pack`).
//   · 예전 상품을 산 사람: 그대로 다섯 칸. 권한(비소모성)이라 복원도 된다.
//   · 새로 사는 사람: 소모성 팩을 최대 세 번까지. 총 추가 칸은 15개에서 멈춘다.
//     (그 위가 필요한 사람에게 팔아야 하는 것은 칸이 아니라 평생이다.)
//
//  ⚠️ **소모성은 복원되지 않는다.** 애플이 돌려주지 않으므로 앱이 직접 기억해야 한다.
//     App Group 에 쌓되 iCloud 키·값 저장소에도 같이 새겨서, 지우고 다시 깔거나 기기를
//     바꿔도 같은 Apple ID 면 칸이 따라온다. 둘 중 **큰 값**을 쓴다(적은 쪽을 믿으면
//     산 칸이 조용히 사라진다).
//

import Foundation

enum SlotPack {

    // MARK: - 상품

    /// 처음 판 칸 추가 상품 (**비소모성**, 한 번만).
    /// ⚠️ App Store Connect 등록값. 변경 금지(영수증과의 계약).
    static let productID = "com.Ysoup.TokenMemo.slots5"

    /// 다시 살 수 있는 칸 추가 상품 (**소모성**).
    /// ⚠️ App Store Connect 에 **소모성**으로 새로 등록한다. 기존 `slots5` 의 종류를
    ///    바꾸는 것이 아니라 별도 상품이다.
    static let consumableProductID = "com.Ysoup.TokenMemo.slots5.pack"

    /// 이 상품이 한 번에 더해 주는 칸수.
    static let slotsPerPack = 5

    /// 살 수 있는 팩의 최대 개수. 예전 비소모성 상품도 한 팩으로 센다.
    /// 여기서 멈추는 이유: 15칸을 넘겨 필요한 사람에게 팔 물건은 칸이 아니라 평생이다.
    static let maxPacks = 3

    /// 칸 추가로 열 수 있는 최대 칸수.
    static var maxExtraSlots: Int { maxPacks * slotsPerPack }

    // MARK: - 가진 것

    /// ⚠️ 공유 저장소로 가는 문은 `AppGroup.defaults` 하나다.
    private static var defaults: UserDefaults? { AppGroup.defaults }

    /// 예전 비소모성 상품으로 얻은 칸수 (0 또는 5).
    /// ⚠️ 키 이름을 그대로 둔다. 이미 깔려 있는 기기에 이 값이 들어 있다.
    static var legacySlots: Int {
        defaults?.integer(forKey: DefaultsKey.purchasedExtraSlots) ?? 0
    }

    /// 소모성으로 산 팩 수.
    static var purchasedPacks: Int {
        defaults?.integer(forKey: DefaultsKey.purchasedSlotPacks) ?? 0
    }

    /// 예전 상품까지 합쳐 **가진 팩 수**. 한도 계산과 "더 살 수 있나" 판단의 단일 출처다.
    static var ownedPacks: Int {
        min(maxPacks, (legacySlots / slotsPerPack) + purchasedPacks)
    }

    /// 산 칸수 - 익스텐션도 읽는 App Group 값이 이 계산의 재료다.
    /// 안 샀으면 0, 최대 `maxExtraSlots`.
    static var purchasedSlots: Int { ownedPacks * slotsPerPack }

    /// 칸을 한 번이라도 샀는가.
    ///
    /// ⚠️ 이 값이 참이면 페이월은 **업그레이드 값**을 보여 준다(`ProUpgrade`).
    ///    칸에 낸 돈이 평생 값에서 빠진다는 약속이 여기에 걸려 있다.
    static var isPurchased: Bool { ownedPacks > 0 }

    /// 아직 더 살 수 있는가.
    static var canBuyMore: Bool { ownedPacks < maxPacks }

    /// 앞으로 더 살 수 있는 칸수 (버튼에 적는다).
    static var remainingPurchasableSlots: Int { (maxPacks - ownedPacks) * slotsPerPack }

    // MARK: - 새기기

    /// 결제 권한(비소모성 `slots5`)에서 읽은 값을 App Group 에 새긴다.
    /// 앱 프로세스에서만 부른다.
    static func mirror(purchased: Bool) {
        let slots = purchased ? slotsPerPack : 0
        guard slots != legacySlots else { return }
        defaults?.set(slots, forKey: DefaultsKey.purchasedExtraSlots)
        print("🔧 [SlotPack.mirror] 예전 칸 추가 = \(slots)")
    }

    /// 소모성 팩을 하나 샀다 - 결제가 끝난 자리에서 부른다.
    ///
    /// ⚠️ 소모성 트랜잭션은 `finish` 하면 사라진다. **여기서 못 세면 돈만 받은 것이 된다.**
    ///    그래서 구매 성공 직후, 다른 일보다 먼저 부른다.
    /// - Returns: 실제로 늘어났으면 true. 이미 최대면 false(그런 경우 애초에 버튼이 없다).
    @discardableResult
    static func recordPackPurchase() -> Bool {
        guard canBuyMore else {
            print("ℹ️ [SlotPack] 이미 최대 칸수, 기록하지 않는다")
            return false
        }
        let next = purchasedPacks + 1
        defaults?.set(next, forKey: DefaultsKey.purchasedSlotPacks)
        writeToCloud(next)
        print("🔧 [SlotPack] 칸 추가 팩 \(next)개 (총 \(purchasedSlots)칸)")
        return true
    }

    // MARK: - iCloud 로 따라오게

    /// 기기의 값과 iCloud 의 값 중 **큰 쪽**으로 맞춘다.
    ///
    /// 왜 큰 쪽인가: 소모성은 애플이 복원해 주지 않아서, 적은 쪽을 믿는 순간 산 칸이
    /// 조용히 사라진다. 반대로 큰 쪽을 믿으면 최악이라도 칸 몇 개를 더 주는 정도다.
    /// 어느 쪽이 사용자에게 덜 나쁜지는 분명하다.
    ///
    /// ⚠️ **앱에서만 부른다.** 키보드 익스텐션은 iCloud 키·값 저장소 권한이 없다.
    ///    익스텐션이 읽는 것은 App Group 에 새겨진 결과뿐이다.
    static func syncFromCloud() {
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        let cloud = Int(store.longLong(forKey: DefaultsKey.purchasedSlotPacks))
        let local = purchasedPacks
        let merged = min(maxPacks, max(cloud, local))
        if merged != local {
            defaults?.set(merged, forKey: DefaultsKey.purchasedSlotPacks)
            print("☁️ [SlotPack] iCloud 에서 칸 추가 팩 \(merged)개 회수")
        }
        if merged != cloud {
            writeToCloud(merged)
        }
    }

    private static func writeToCloud(_ packs: Int) {
        NSUbiquitousKeyValueStore.default.set(Int64(packs), forKey: DefaultsKey.purchasedSlotPacks)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    // MARK: - 진단

    /// 개발 중에 되돌린다(설정 > 개발자 화면).
    static func resetForTesting() {
        defaults?.removeObject(forKey: DefaultsKey.purchasedSlotPacks)
        defaults?.removeObject(forKey: DefaultsKey.purchasedExtraSlots)
    }
}
