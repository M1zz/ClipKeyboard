//
//  PaywallLadder.swift
//  ClipKeyboard
//
//  **페이월 템플릿.** 두 결제 화면(`PaywallView` · 100번째 사용의 `FreeUsePaywallView`)이 같은 틀을 쓴다.
//  화면마다 다른 것은 맨 위 머리말(`hero`) 하나뿐이다.
//
//    머리말            화면이 넣는다(제목 한 줄 + 이 사람의 한 줄)
//    Plus | Pro        칸 고르기. Pro 가 처음 골라져 있다(추천)
//    혜택 세 줄        고른 칸의 것만
//    월 · 연 · 평생     세로 목록. 줄마다 **전체 가격과 청구 기간**, 연에는 "N% 절약"
//    갱신 조건 한 줄    고른 길의 것만(본문 맨 아래)
//    체험 · 복원 · 약관  한 줄(본문 맨 아래)
//    ─── 아래 고정 ───
//    구매 단추         고른 칸 · 고른 길 그대로. 아래에는 단추 하나만 둔다(2026-11, 글이 많다는 말을 들었다)
//
//  2026-11 개편: 칸 카드 세 장(무료 · Plus · Pro)에 카드마다 길 고르기와 구매 단추가 따로 있어
//  "조잡하고 복잡하다" 는 말을 들었다. 혜택은 3~5개, 고를 것은 한 번에 하나, 가격은 숨기지 않고,
//  구매 단추는 하나(adapty 의 iOS 페이월 정리를 따랐다). 비교표는 접어 둔다.
//
//  ⚠️ 무엇을 결제하는지는 `PaywallPlanRules.productID` 한 곳이 정한다. 화면에 적은 값과 결제하는 상품은 같다.
//  ⚠️ 결제는 화면의 `@Environment(\.purchase)` 로 한다. 아이패드에서 결제 시트가 엉뚱한 창에 뜨지 않게.
//  ⚠️ 글자 · 바탕은 시스템 색이다. 테마 색을 쓰면 다크 모드에서 흰 바탕에 흰 글자가 됐다.
//     강조(선택 테두리 · 배지 · 구매 단추)만 앱의 키 색(`theme.accent`)이다.
//

import SwiftUI
import StoreKit
import LeeoKit

struct PaywallTemplate<Hero: View>: View {
    /// 이 사람의 권한을 한 번 읽어 둔 것(`PaywallAccess.current`).
    let access: PaywallAccess
    /// 애널리틱스에 남길 진입점. nil 이면 칸 이름으로 남긴다.
    let source: String?
    /// 무료 체험을 시작한다. 체험을 줄 수 없으면 nil(단추가 서지 않는다).
    var startTrial: (() -> Void)?
    /// 결제가 확인됐다. 어느 칸을 샀는지 알려 준다.
    let onPurchased: (PaywallPlan) -> Void
    @ViewBuilder let hero: () -> Hero

    @ObservedObject private var store = StoreManager.shared
    @Environment(\.purchase) private var purchaseAction
    @Environment(\.openURL) private var openURL

    /// 고른 칸. 이미 가진 칸은 고를 수 없다.
    @State private var plan: PaywallPlan = .pro
    /// 칸마다 고른 길. 고르기 전에는 `PaywallPlanRules.initialTerm`.
    @State private var terms: [PaywallPlan: PaywallTerm] = [:]
    @State private var buying = false
    @State private var introEligible = false
    @State private var restoreOutcome: StoreManager.RestoreOutcome?
    @State private var showsComparison = false

    @Environment(\.appTheme) private var theme
    /// 앱의 키 색. 예전 페이월은 주황을 박아 두어 이 화면만 색이 달랐다(2026-11).
    private var accent: Color { theme.accent }

    var body: some View {
        // 그림으로 파는 틀(LeeoKit `LeeoShowcasePaywall`): 칸 고르기 · 기능 그림 · 요금이 첫 화면에, 구매 단추는 늘 떠 있다.
        LeeoShowcasePaywall(showcases: plan.showcases) {
            VStack(spacing: 16) {
                hero()
                if purchasablePlans.count > 1 { planSwitch }
            }
        } plans: {
            options
        } button: {
            purchaseBar
        } details: {
            VStack(spacing: 20) {
                fineprint
                comparison
            }
        }
        .leeoStyle(theme.leeoStyle)
        .restoreOutcomeAlert($restoreOutcome)
        .onAppear { if !purchasablePlans.contains(plan), let first = purchasablePlans.first { plan = first } }
        .task(id: product(.yearly)?.id) {
            introEligible = await product(.yearly)?.subscription?.isEligibleForIntroOffer ?? false
        }
    }

    // MARK: - 칸

    /// 살 수 있는 칸. Plus 를 가진 사람에게는 Pro 하나뿐이라 고르는 줄이 서지 않는다.
    private var purchasablePlans: [PaywallPlan] {
        PaywallPlan.allCases.filter { access[$0].isPurchasable }
    }

    private var state: PaywallPlanState { access[plan] }

    private var planSwitch: some View {
        HStack(spacing: 4) {
            ForEach(purchasablePlans) { p in
                let selected = p == plan
                Button {
                    HapticManager.shared.light()
                    withAnimation(.snappy(duration: 0.25)) { plan = p }
                } label: {
                    HStack(spacing: 6) {
                        Text(p.name).fontWeight(.bold)
                        if p == .pro {
                            Text(NSLocalizedString("추천", comment: "Paywall plan badge: recommended"))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(accent.opacity(selected ? 0.18 : 0.12), in: Capsule())
                                .foregroundStyle(accent)
                        }
                    }
                    .font(.body)
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background {
                        if selected {
                            Capsule().fill(Color(uiColor: .systemBackground))
                                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
    }

    // MARK: - 길

    private var term: PaywallTerm { terms[plan] ?? PaywallPlanRules.initialTerm(state) }

    private func product(_ term: PaywallTerm) -> Product? {
        PaywallPlanRules.productID(for: plan, state, term: term).flatMap(store.product)
    }

    private var options: some View {
        VStack(spacing: 10) {
            ForEach(PaywallTerm.allCases, id: \.self) { t in
                optionRow(t)
            }
            if term == .lifetime { LeeoLifetimePriceNotice().leeoThemed() }
        }
    }

    private func optionRow(_ t: PaywallTerm) -> some View {
        let item = product(t)
        let selected = t == term
        return Button {
            HapticManager.shared.light()
            terms[plan] = t
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? AppSymbol.checkmarkCircleFill : AppSymbol.circle)
                    .font(.title3)
                    .foregroundStyle(selected ? accent : Color(uiColor: .tertiaryLabel))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title(t)).font(.body.weight(.semibold))
                        if let badge = badge(t) {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(accent, in: Capsule())
                                .foregroundStyle(theme.accentFg)
                        }
                    }
                    if let caption = caption(t) {
                        Text(caption)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                Text(price(t, item) ?? " ")
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? accent : .clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(item == nil)
        .opacity(item == nil ? 0.5 : 1)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func title(_ t: PaywallTerm) -> String {
        switch t {
        case .monthly:  return NSLocalizedString("월 구독", comment: "Paywall term option: monthly subscription")
        case .yearly:   return LeeoLadderText.yearly
        case .lifetime: return LeeoLadderText.lifetime
        }
    }

    /// 줄 오른쪽: 실제로 내는 값과 그 기간. 월 환산값을 크게 쓰지 않는다(청구 주기가 흐려진다).
    private func price(_ t: PaywallTerm, _ item: Product?) -> String? {
        guard let item else { return nil }
        switch t {
        case .monthly:  return String(format: NSLocalizedString("%@ / 월", comment: "Paywall term option: monthly price. %@ = price"), item.displayPrice)
        case .yearly:   return String(format: LeeoLadderText.perYearFormat, item.displayPrice)
        case .lifetime: return item.displayPrice
        }
    }

    /// 줄 아래 작은 글. 연은 첫 해 할인(받을 수 있는 사람만), 평생은 올리기 값이거나 연 구독 몇 년치.
    private func caption(_ t: PaywallTerm) -> String? {
        switch t {
        case .monthly:
            return nil
        case .yearly:
            if introEligible, let offer = product(.yearly)?.subscription?.introductoryOffer,
               offer.paymentMode == .payUpFront || offer.paymentMode == .payAsYouGo {
                return String(format: LeeoLadderText.introFormat, offer.displayPrice)
            }
            guard let yearly = product(.yearly) else { return nil }
            return String(format: NSLocalizedString("연 구독이면 한 달에 %@", comment: "Paywall note under monthly: the yearly plan works out to this price per month. %@ = price"),
                          (yearly.price / 12).formatted(yearly.priceFormatStyle))
        case .lifetime:
            if state == .upgrade {
                return NSLocalizedString("Plus 에서 Pro 로 오르는 값 · 한 번 결제", comment: "Paywall price caption: upgrade from Plus")
            }
            guard let yearly = product(.yearly), let lifetime = product(.lifetime), yearly.price > 0 else { return nil }
            // ⚠️ `NSDecimalNumber.intValue` 는 자릿수가 긴 몫에서 엉뚱한 값을 낸다. double 로 내린다.
            let years = Int(NSDecimalNumber(decimal: lifetime.price / yearly.price).doubleValue.rounded(.down))
            return years >= 2 ? String(format: LeeoLadderText.lifetimeWorthFormat, years) : nil
        }
    }

    /// 연 구독이 월 구독 열두 달보다 얼마나 싼가. 10% 넘게 쌀 때만 붙인다.
    private func badge(_ t: PaywallTerm) -> String? {
        guard t == .yearly, let saving = PaywallPricing.yearlySaving(monthly: product(.monthly)?.price,
                                                                     yearly: product(.yearly)?.price) else { return nil }
        return String(format: NSLocalizedString("%@ 절약", comment: "Paywall badge on the yearly option: how much cheaper than 12 months of monthly. %@ = percent, e.g. 50%"),
                      saving.formatted(.percent.precision(.fractionLength(0))))
    }

    // MARK: - 아래 고정

    private var purchaseBar: some View {
        let item = product(term)
        return VStack(spacing: 10) {
            Button {
                guard let item else { return }
                Task { await buy(item) }
            } label: {
                Group {
                    if buying { ProgressView().tint(theme.accentFg) } else { Text(ctaTitle).fontWeight(.bold) }
                }
                .font(.headline)
                .foregroundStyle(theme.accentFg)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.squish)
            // 상품을 못 읽었으면 누를 수 없다. 누른 뒤에 "상품 없음" 을 듣는 것보다 낫다.
            .disabled(buying || item == nil)
            .accessibilityLabel(buying ? NSLocalizedString("처리 중", comment: "Purchase loading state") : ctaTitle)

            if let error = store.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var ctaTitle: String {
        state == .upgrade
            ? NSLocalizedString("Pro 로 올리기", comment: "Paywall CTA: upgrade to Pro without price")
            : String(format: NSLocalizedString("%@ 시작하기", comment: "Paywall CTA: start plan without price"), plan.name)
    }

    /// 본문 맨 아래: 고른 길의 갱신 조건과 체험 · 복원 · 약관. 고정 띠에는 구매 단추만 둔다.
    private var fineprint: some View {
        VStack(spacing: 12) {
            if let terms = renewalTerms(product(term)) {
                Text(terms)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            footerLinks
        }
        .frame(maxWidth: .infinity)
    }

    /// 고른 길의 갱신 조건(심사 기준 3.1.2). 평생은 갱신이 없다고 말한다.
    private func renewalTerms(_ item: Product?) -> String? {
        guard let item else { return nil }
        switch term {
        case .monthly:
            return String(format: NSLocalizedString("매달 %@씩 자동으로 갱신돼요. 갱신 24시간 전까지 설정 > Apple 계정 > 구독에서 해지할 수 있어요.", comment: "Monthly subscription terms"), item.displayPrice)
        case .yearly:
            return String(format: NSLocalizedString("1년마다 %@씩 자동으로 갱신돼요. 갱신 24시간 전까지 설정 > Apple 계정 > 구독에서 해지할 수 있어요.", comment: "Yearly subscription terms"), item.displayPrice)
        case .lifetime:
            return NSLocalizedString("한 번만 결제해요. 자동 갱신은 없어요.", comment: "Paywall terms under the button when lifetime is selected")
        }
    }

    /// 체험 · 복원 · 약관 · 개인정보. 늘 같은 자리에 있다.
    ///
    /// ⚠️ 한 줄에 다 안 들어가면 **세로로** 쌓는다. 예전에는 대신 그린 것이 같은 가로줄에 `fixedSize` 를
    ///    건 것이라 화면보다 넓어졌고, 페이월 전체가 그 폭으로 벌어져 양옆이 잘렸다(2026-11).
    private var footerLinks: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { footerButtons }
            VStack(spacing: 6) { footerButtons }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    @ViewBuilder
    private var footerButtons: some View {
        if let startTrial {
            Button(String(format: NSLocalizedString("%d일 무료 체험 시작", comment: "Start free trial button"), ProFeatureManager.trialDurationDays)) {
                AnalyticsService.logPaywallCtaTapped(triggeredBy: source, isTrial: true)
                startTrial()
            }
            .fontWeight(.semibold)
            .foregroundStyle(accent)
        }
        Button(NSLocalizedString("복원", comment: "Paywall footer: restore purchases, short")) {
            Task { restoreOutcome = await store.restorePurchases() }
        }
        Button(NSLocalizedString("이용약관", comment: "Terms of use link")) {
            if let url = URL(string: Constants.inAppWebURL(Constants.termsOfUseURL)) { openURL(url) }
        }
        Button(NSLocalizedString("개인정보 처리방침", comment: "Privacy policy link")) {
            if let url = URL(string: Constants.inAppWebURL(Constants.privacyPolicyURL)) { openURL(url) }
        }
    }

    // MARK: - 비교표

    private var comparison: some View {
        DisclosureGroup(isExpanded: $showsComparison) {
            PaywallComparisonTable().padding(.top, 12)
        } label: {
            Text(NSLocalizedString("모든 기능 비교", comment: "Paywall: expand the full feature comparison table"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .tint(.secondary)
    }

    // MARK: - 결제

    private func buy(_ item: Product) async {
        AnalyticsService.logPaywallCtaTapped(triggeredBy: source ?? "plan_\(plan.rawValue)", isTrial: false)
        buying = true
        let bought = await store.purchase(item, using: purchaseAction, triggeredBy: source)
        buying = false
        if bought { onPurchased(plan) }
    }
}

// MARK: - 값 계산

enum PaywallPricing {
    /// 연 구독이 월 구독 열두 달보다 싼 몫(0.5 = 50%). 10% 넘게 쌀 때만, 모르면 nil. **순수 함수.**
    static func yearlySaving(monthly: Decimal?, yearly: Decimal?) -> Double? {
        guard let monthly, let yearly, monthly > 0 else { return nil }
        let saving = 1 - NSDecimalNumber(decimal: yearly / (monthly * 12)).doubleValue
        return saving > 0.1 ? saving : nil
    }
}
