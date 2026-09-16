//
//  TwoDevicePack.swift
//  ClipKeyboard
//
//  **두 대째** - 기기 사이 동기화만 여는 상품. 평생 Pro 와 나란히 서는 다른 문이다.
//
//  왜 따로 파는가: 이건 칸 개수 문제가 아니라 **기기 개수** 문제다.
//  아이폰 하나로 쓰는 사람에게는 있어도 그만인 기능이고, 아이폰과 맥을 같이 쓰는 사람에게는
//  단축어 개수보다 먼저 아쉬운 것이다. 개수 사다리(`SlotPack`)에 끼워 넣으면 둘 다 흐려진다.
//
//  ⚠️ **이 상품은 Pro 가 아니다.** `ClipKeyboardSpec` 의 `entitlementIDs` 에 넣지 않는다.
//     여는 것은 동기화 하나뿐이고, 무제한 칸·백업·생체잠금은 그대로 잠겨 있다.
//
//  ⚠️ 거꾸로, **Pro 인 사람에게서 동기화를 빼앗지 않는다.** 동기화는 이미 Pro 가 여는 것에
//     들어 있다(`ProFeatureManager.isSyncAvailable`). 이 상품은 Pro 를 안 산 사람에게만
//     파는 별도의 문이지, Pro 에서 떼어 낸 조각이 아니다. 판 것을 도로 가져가는 앱은
//     두 번째 결제를 못 받는다.
//
//  ⚠️ 비소모성이라 복원된다. 그래서 `SlotPack` 과 달리 iCloud 에 따로 새기지 않아도 되지만,
//     동기화 엔진이 **결제를 못 보는 자리**(공유 타입)에서 권한을 판단하므로
//     `ProFeatureManager.mirrorSyncEntitlement()` 가 App Group·iCloud KV 에 결과를 미러링한다.
//

import Foundation

enum TwoDevicePack {

    /// 두 대째 상품 ID.
    /// ⚠️ App Store Connect 에 **비소모성**으로 등록한다. 변경 금지(영수증과의 계약).
    static let productID = "com.Ysoup.TokenMemo.twodevice"

    private static var defaults: UserDefaults? { AppGroup.defaults }

    /// 샀는가 - 결제 권한을 앱이 App Group 에 미러링한 값을 읽는다.
    /// (동기화 엔진과 설정 화면이 같은 답을 봐야 하므로 통로는 여기 하나다.)
    static var isPurchased: Bool {
        defaults?.bool(forKey: DefaultsKey.twoDevicePurchased) ?? false
    }

    /// 결제 권한에서 읽은 값을 App Group 에 새긴다(앱 프로세스에서만 부른다).
    static func mirror(purchased: Bool) {
        guard purchased != isPurchased else { return }
        defaults?.set(purchased, forKey: DefaultsKey.twoDevicePurchased)
        print("🔧 [TwoDevicePack.mirror] 두 대째 = \(purchased)")
    }

    /// 개발 중에 되돌린다.
    static func resetForTesting() {
        defaults?.removeObject(forKey: DefaultsKey.twoDevicePurchased)
    }
}
