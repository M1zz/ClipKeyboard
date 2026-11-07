//
//  SettingsGiftView.swift
//  ClipKeyboard
//
//  설정 ▸ 선물하기. Plus · Pro 선물 보내기와 받은 코드 넣기를 한 화면에 모은다.
//
//  선물을 사면 App Store 오퍼 코드 링크가 나오고, 그 링크로 받은 사람은 App Store 에서
//  "사용" 한 번으로 열린다(LeeoKit `LeeoOfferCodePool`). 지침 3.1.1 에 맞다:
//  여는 것은 우리 코드가 아니라 App Store 다.
//  ⚠️ 줄 문구는 LeeoKit 카탈로그에 있다(`LeeoGiftText`). 앱 카탈로그에 다시 적지 않는다.
//

import SwiftUI
import LeeoKit

struct SettingsGiftView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject private var proManager = StoreManager.shared
    /// 선물이 안 될 때의 문의 창(결제 번호 · 코드가 붙는다).
    @State private var showSupport = false

    /// 보낼 수 있는 선물. 상품이 App Store 에서 왔거나, 이미 보낸 선물 · 준비 중인 결제가 있으면 늘 선다.
    private static func senders(_ store: StoreManager) -> [LeeoGiftStore] {
        store.gifts.filter { $0.isAvailable || $0.pendingCount > 0 || !$0.sentGifts.isEmpty }
    }

    /// 받기 줄은 아직 Pro 가 아닌 사람에게만. 링크 없이 코드만 받은 사람을 위한 자리다.
    private static func showsRedeem(_ store: StoreManager) -> Bool {
        (store.gift?.canRedeem ?? false) && !ProFeatureManager.hasPermanentPro
    }

    /// 설정에 선물하기 줄을 세울지.
    static func hasContent(_ store: StoreManager) -> Bool {
        store.gift != nil && (!senders(store).isEmpty || showsRedeem(store))
    }

    var body: some View {
        List {
            Section {
                // 싼 것(Plus)부터. 설정 목록은 사다리 순서를 따른다.
                ForEach(Self.senders(proManager).reversed(), id: \.config.productID) { gift in
                    FoldLink(destination: LeeoGiftView<ClipKeyboardSpec>(gift: gift, showsRedeemLink: false,
                                                                          onContactSupport: { showSupport = true })
                        .leeoStyle(theme.leeoStyle)) {
                        Label(LeeoGiftText.sendEntry(tier: gift.config.tierName), systemImage: AppSymbol.giftFill)
                    }
                }
            }
            if Self.showsRedeem(proManager), let first = proManager.gift {
                Section {
                    FoldLink(destination: LeeoGiftRedeemView<ClipKeyboardSpec>(gift: first,
                                                                             onContactSupport: { showSupport = true })
                        .leeoStyle(theme.leeoStyle)) {
                        Label(LeeoGiftText.redeemEntry, systemImage: AppSymbol.giftcard)
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("선물하기", comment: "Settings: gift entry opening the gift page"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSupport) {
            FeedbackView(origin: .settings, initialType: .bug, initialCategory: .purchase,
                         extraLines: proManager.gifts.flatMap(\.supportLines))
        }
    }
}
