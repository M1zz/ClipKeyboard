//
//  PaywallLadder.swift
//  ClipKeyboard
//
//  **요금제 사다리**: 무료 · Plus · Pro 세 칸과 그 아래 언제나 평생 패스 한 줄.
//  두 결제 화면(`PaywallView` · 100번째 사용의 `FreeUsePaywallView`)이 같은 사다리를 쓴다.
//
//   · 유료 칸마다 연 구독과 평생을 나란히 둔다(`LeeoTermPicker`). 처음 보는 사람에게는 연 구독 첫 해
//     할인이, 평생을 고르면 "연 구독 N년치" 가 그 자리에 보인다(LeeoKit 이 알아서 한다).
//   · 무엇을 결제하는지는 `PaywallPlanRules.productID` 한 곳이 정한다. Plus 평생을 산 사람의 Pro 평생은
//     올리기 상품이다.
//   · 연 구독을 고르면 갱신 조건을 버튼 바로 아래에, 약관 · 개인정보 링크를 사다리 끝에 둔다(심사 기준 3.1.2).
//
//  ⚠️ 결제는 화면의 `@Environment(\.purchase)` 로 한다. 아이패드에서 결제 시트가 엉뚱한 창에 뜨지 않게.
//

import SwiftUI
import StoreKit
import LeeoKit

struct PaywallLadder: View {
    /// 이 사람의 권한을 한 번 읽어 둔 것(`PaywallAccess.current`).
    let access: PaywallAccess
    /// 애널리틱스에 남길 진입점. nil 이면 칸 이름으로 남긴다.
    let source: String?
    /// 결제가 확인됐다. 어느 칸을 샀는지 알려 준다.
    let onPurchased: (PaywallPlan) -> Void

    @ObservedObject private var store = StoreManager.shared
    @Environment(\.purchase) private var purchaseAction
    @Environment(\.openURL) private var openURL
    @Environment(\.appTheme) private var theme
    /// 칸마다 고른 길. 고르기 전에는 `PaywallPlanRules.initialTerm`.
    @State private var terms: [PaywallPlan: LeeoPlanTerm] = [:]
    @State private var buying: PaywallPlan?

    var body: some View {
        VStack(spacing: 10) {
            PaywallFreeCard()
            ForEach(PaywallPlan.allCases) { plan in
                let state = access[plan]
                PaywallPlanCard(plan: plan, state: state, isRecommended: plan == .pro) {
                    purchaseArea(plan, state)
                }
            }
            LeeoForeverPassLine(pass: store.foreverPass, ownsLifetimePro: ownsLifetimePro)
            LeeoLifetimePriceNotice()
                .frame(maxWidth: .infinity, alignment: .leading)
            legalLinks
        }
        .leeoThemed()
    }

    /// 이 앱의 Pro 를 평생으로 가졌는가. 그러면 패스 화면이 올리기 값을 보인다.
    private var ownsLifetimePro: Bool {
        AccessTier.ownsLifetimePro(store.purchasedProductIDs) || ProFeatureManager.isGrandfathered
    }

    // MARK: - 칸 안

    private func term(_ plan: PaywallPlan, _ state: PaywallPlanState) -> LeeoPlanTerm {
        terms[plan] ?? PaywallPlanRules.initialTerm(state)
    }

    private func product(_ plan: PaywallPlan, _ state: PaywallPlanState, _ term: LeeoPlanTerm) -> Product? {
        PaywallPlanRules.productID(for: plan, state, term: term).flatMap(store.product)
    }

    @ViewBuilder
    private func purchaseArea(_ plan: PaywallPlan, _ state: PaywallPlanState) -> some View {
        let chosen = term(plan, state)
        let yearly = product(plan, state, .yearly)
        let lifetime = product(plan, state, .lifetime)
        let selected = chosen == .yearly ? yearly : lifetime
        VStack(alignment: .leading, spacing: 10) {
            LeeoTermPicker(term: Binding(get: { term(plan, state) }, set: { terms[plan] = $0 }),
                           yearly: yearly, lifetime: lifetime)
            if state == .upgrade && chosen == .lifetime {
                Text(NSLocalizedString("Plus 에서 Pro 로 오르는 값 · 한 번 결제", comment: "Paywall price caption: upgrade from Plus"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            buyButton(plan, state, selected)
            if chosen == .yearly, let yearly {
                Text(String(format: NSLocalizedString("1년마다 %@씩 자동으로 갱신돼요. 갱신 24시간 전까지 설정 > Apple 계정 > 구독에서 해지할 수 있어요.", comment: "Yearly subscription terms"), yearly.displayPrice))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func buyButton(_ plan: PaywallPlan, _ state: PaywallPlanState, _ product: Product?) -> some View {
        let title = state == .upgrade
            ? NSLocalizedString("Pro 로 올리기", comment: "Paywall CTA: upgrade to Pro without price")
            : String(format: NSLocalizedString("%@ 시작하기", comment: "Paywall CTA: start plan without price"), plan.name)
        return Button {
            guard let product else { return }
            Task { await buy(plan, product) }
        } label: {
            Group {
                if buying == plan {
                    ProgressView().tint(.white)
                } else {
                    Text(title).fontWeight(.bold)
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(.orange.gradient, in: RoundedRectangle(cornerRadius: theme.radiusMd))
        }
        .buttonStyle(.squish)
        // 상품을 못 읽었으면 누를 수 없다. 누른 뒤에 "상품 없음" 을 듣는 것보다 낫다.
        .disabled(buying != nil || product == nil)
        .accessibilityLabel(buying == plan ? NSLocalizedString("처리 중", comment: "Purchase loading state") : title)
    }

    private func buy(_ plan: PaywallPlan, _ product: Product) async {
        AnalyticsService.logPaywallCtaTapped(triggeredBy: source ?? "plan_\(plan.rawValue)", isTrial: false)
        buying = plan
        let bought = await store.purchase(product, using: purchaseAction, triggeredBy: source)
        buying = nil
        if bought { onPurchased(plan) }
    }

    // MARK: - 약관

    private var legalLinks: some View {
        HStack(spacing: 20) {
            link(NSLocalizedString("이용약관", comment: "Terms of use link"), Constants.termsOfUseURL)
            link(NSLocalizedString("개인정보 처리방침", comment: "Privacy policy link"), Constants.privacyPolicyURL)
        }
        .frame(maxWidth: .infinity)
    }

    private func link(_ title: String, _ address: String) -> some View {
        Button {
            if let url = URL(string: address) { openURL(url) }
        } label: {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .underline()
                .frame(minHeight: 44)
        }
    }
}
