//
//  PaywallLadder.swift
//  ClipKeyboard
//
//  **요금제 사다리**: 무료 · Plus · Pro 세 칸과 그 아래 언제나 평생 패스 한 줄.
//  두 결제 화면(`PaywallView` · 100번째 사용의 `FreeUsePaywallView`)이 같은 사다리를 쓴다.
//
//   · 유료 칸마다 월 구독 · 연 구독 · 평생을 나란히 둔다(`PaywallTermPicker`). 처음엔 연 구독이 골라져 있고,
//     처음 보는 사람에게는 첫 해 할인이, 월을 고르면 "연 구독이면 한 달에 얼마", 평생을 고르면 "연 구독 N년치" 가 보인다.
//   · 무엇을 결제하는지는 `PaywallPlanRules.productID` 한 곳이 정한다. Plus 평생을 산 사람의 Pro 평생은
//     올리기 상품이다.
//   · 구독을 고르면 갱신 조건을 버튼 바로 아래에, 약관 · 개인정보 링크를 사다리 끝에 둔다(심사 기준 3.1.2).
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
    @State private var terms: [PaywallPlan: PaywallTerm] = [:]
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
            if StoreManager.sellsForeverPass {
                LeeoForeverPassLine(pass: store.foreverPass, ownsLifetimePro: ownsLifetimePro)
            }
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

    private func term(_ plan: PaywallPlan, _ state: PaywallPlanState) -> PaywallTerm {
        terms[plan] ?? PaywallPlanRules.initialTerm(state)
    }

    private func product(_ plan: PaywallPlan, _ state: PaywallPlanState, _ term: PaywallTerm) -> Product? {
        PaywallPlanRules.productID(for: plan, state, term: term).flatMap(store.product)
    }

    @ViewBuilder
    private func purchaseArea(_ plan: PaywallPlan, _ state: PaywallPlanState) -> some View {
        let chosen = term(plan, state)
        let monthly = product(plan, state, .monthly)
        let yearly = product(plan, state, .yearly)
        let lifetime = product(plan, state, .lifetime)
        let selected = [PaywallTerm.monthly: monthly, .yearly: yearly, .lifetime: lifetime][chosen] ?? nil
        VStack(alignment: .leading, spacing: 10) {
            PaywallTermPicker(term: Binding(get: { term(plan, state) }, set: { terms[plan] = $0 }),
                              monthly: monthly, yearly: yearly, lifetime: lifetime)
            if state == .upgrade && chosen == .lifetime {
                Text(NSLocalizedString("Plus 에서 Pro 로 오르는 값 · 한 번 결제", comment: "Paywall price caption: upgrade from Plus"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            buyButton(plan, state, selected)
            if chosen == .monthly, let monthly {
                Text(String(format: NSLocalizedString("매달 %@씩 자동으로 갱신돼요. 갱신 24시간 전까지 설정 > Apple 계정 > 구독에서 해지할 수 있어요.", comment: "Monthly subscription terms"), monthly.displayPrice))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
            link(NSLocalizedString("이용약관", comment: "Terms of use link"), Constants.inAppWebURL(Constants.termsOfUseURL))
            link(NSLocalizedString("개인정보 처리방침", comment: "Privacy policy link"), Constants.inAppWebURL(Constants.privacyPolicyURL))
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

// MARK: - 월 · 연 · 평생 고르기

/// 유료 칸 하나의 세 길. 모양과 말은 LeeoKit `LeeoTermPicker` 와 같고 월 구독 하나가 더 있다.
///
/// 아래 한 줄: 월이면 "연 구독이면 한 달에 얼마", 연이면 처음 보는 사람에게 첫 해 할인, 평생이면 "연 구독 N년치".
private struct PaywallTermPicker: View {
    @Binding var term: PaywallTerm
    let monthly: Product?
    let yearly: Product?
    let lifetime: Product?

    @Environment(\.leeoStyle) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var introEligible = false

    var body: some View {
        // 아주 큰 글자에서는 세 길을 위아래로 세운다. 나란히 두면 가격이 몇 줄로 꺾인다.
        let options = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        VStack(alignment: .leading, spacing: 8) {
            options {
                option(.monthly, title: NSLocalizedString("월 구독", comment: "Paywall term option: monthly subscription"),
                       price: monthly.map { String(format: NSLocalizedString("%@ / 월", comment: "Paywall term option: monthly price. %@ = price"), $0.displayPrice) })
                option(.yearly, title: LeeoLadderText.yearly,
                       price: yearly.map { String(format: LeeoLadderText.perYearFormat, $0.displayPrice) })
                option(.lifetime, title: LeeoLadderText.lifetime, price: lifetime?.displayPrice)
            }
            if let note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task(id: yearly?.id) {
            introEligible = await yearly?.subscription?.isEligibleForIntroOffer ?? false
        }
    }

    private var note: String? {
        switch term {
        case .monthly:
            // 연 구독을 열두 달로 나눈 값. 월 구독보다 쌀 때만 말한다.
            guard let yearly, let monthly, yearly.price / 12 < monthly.price else { return nil }
            let perMonth = (yearly.price / 12).formatted(yearly.priceFormatStyle)
            return String(format: NSLocalizedString("연 구독이면 한 달에 %@", comment: "Paywall note under monthly: the yearly plan works out to this price per month. %@ = price"), perMonth)
        case .yearly:
            guard introEligible, let offer = yearly?.subscription?.introductoryOffer,
                  offer.paymentMode == .payUpFront || offer.paymentMode == .payAsYouGo else { return nil }
            return String(format: LeeoLadderText.introFormat, offer.displayPrice)
        case .lifetime:
            // 평생 값이 연 구독 몇 년치인가(내림). 2년치가 안 되면 말하지 않는다.
            // ⚠️ `NSDecimalNumber.intValue` 는 자릿수가 긴 몫에서 엉뚱한 값을 낸다. double 로 내린다.
            guard let yearly, let lifetime, yearly.price > 0 else { return nil }
            let years = Int(NSDecimalNumber(decimal: lifetime.price / yearly.price).doubleValue.rounded(.down))
            return years >= 2 ? String(format: LeeoLadderText.lifetimeWorthFormat, years) : nil
        }
    }

    private func option(_ value: PaywallTerm, title: String, price: String?) -> some View {
        let selected = term == value
        return Button {
            term = value
        } label: {
            VStack(spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(price ?? " ")
                    .font(.footnote)
                    .monospacedDigit()
            }
            .foregroundStyle(selected ? theme.accent : theme.text)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusSm, style: .continuous)
                    .fill(selected ? theme.accent.opacity(0.12) : theme.surfaceAlt)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusSm, style: .continuous)
                    .strokeBorder(selected ? theme.accent : .clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(price == nil)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityInputLabels([Text(title)])
    }
}
