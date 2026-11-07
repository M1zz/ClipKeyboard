//
//  SettingsGiftView.swift
//  ClipKeyboard
//
//  설정 ▸ Send a Gift. 누르면 바로 등급(Plus · Pro)을 고르고 선물하는 한 화면이다
//  (LeeoKit `LeeoGiftPickerView`). 받은 코드 넣기는 그 화면 맨 아래 링크로 둔다.
//
//  선물을 사면 App Store 오퍼 코드 링크가 나오고, 그 링크로 받은 사람은 App Store 에서
//  "사용" 한 번으로 열린다(LeeoKit `LeeoOfferCodePool`). 지침 3.1.1 에 맞다:
//  여는 것은 우리 코드가 아니라 App Store 다.
//  ⚠️ 화면 문구는 LeeoKit 카탈로그에 있다(`LeeoGiftText`). 앱 카탈로그에 다시 적지 않는다.
//

import SwiftUI
import LeeoKit

struct SettingsGiftView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject private var proManager = StoreManager.shared
    /// 선물이 안 될 때의 문의 창(결제 번호 · 코드가 붙는다).
    @State private var showSupport = false

    /// 보낼 수 있는 선물, 싼 것(Plus)부터. 상품이 App Store 에서 왔거나,
    /// 이미 보낸 선물 · 준비 중인 결제가 있으면 늘 선다.
    private static func senders(_ store: StoreManager) -> [LeeoGiftStore] {
        store.gifts.filter { $0.isAvailable || $0.pendingCount > 0 || !$0.sentGifts.isEmpty }.reversed()
    }

    /// 받기 링크는 아직 Pro 가 아닌 사람에게만. 링크 없이 코드만 받은 사람을 위한 자리다.
    private static func showsRedeem(_ store: StoreManager) -> Bool {
        (store.gift?.canRedeem ?? false) && !ProFeatureManager.hasPermanentPro
    }

    /// 설정에 선물 줄을 세울지.
    static func hasContent(_ store: StoreManager) -> Bool {
        store.gift != nil && (!senders(store).isEmpty || showsRedeem(store))
    }

    var body: some View {
        content
            .leeoStyle(theme.leeoStyle)
            .sheet(isPresented: $showSupport) {
                FeedbackView(origin: .settings, initialType: .bug, initialCategory: .purchase,
                             extraLines: proManager.gifts.flatMap(\.supportLines))
            }
    }

    @ViewBuilder
    private var content: some View {
        let gifts = Self.senders(proManager)
        if gifts.isEmpty, let first = proManager.gift {
            // 보낼 선물은 없고 받을 코드만 넣을 수 있을 때
            LeeoGiftRedeemView<ClipKeyboardSpec>(gift: first, onContactSupport: { showSupport = true })
        } else {
            LeeoGiftPickerView<ClipKeyboardSpec>(gifts: gifts,
                                                 showsRedeemLink: Self.showsRedeem(proManager),
                                                 onContactSupport: { showSupport = true })
        }
    }
}
