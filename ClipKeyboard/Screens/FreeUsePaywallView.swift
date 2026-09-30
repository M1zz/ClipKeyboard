//
//  FreeUsePaywallView.swift
//  ClipKeyboard
//
//  문턱(`FreeUse.threshold`)에 닿았을 때의 결제 화면. **가격보다 영수증이 먼저다.**
//
//  왜 영수증이 먼저인가: 결제할까 망설이는 까닭은 이 앱이 그만한 값을 하는지 확신이 없어서다.
//  100번 넣은 사람에게는 그 증거가 이미 있다. 보여 주기만 하면 된다.
//
//  요금제는 둘뿐이다(평생 · 연 구독). 같은 Pro 를 기간으로만 나눈다. 기능을 쪼갠 요금제는
//  무엇이 빠지는지 사용자가 따져야 하고, 따지는 순간 "나중에"로 끝난다.
//
//  ⚠️ 연 구독 상품이 App Store Connect 에 아직 없으면 그 칸만 숨기고 평생만 판다.
//  ⚠️ 구독을 고르면 갱신 조건과 약관 · 개인정보 링크를 보인다(심사 기준 3.1.2).
//

import SwiftUI
import StoreKit

struct FreeUsePaywallView: View {
    /// 문턱에 닿아 저절로 뜬 것인가(안내 화면에서 눌러 연 것이 아니라).
    var isThresholdMoment = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.openURL) private var openURL
    @ObservedObject private var store = StoreManager.shared

    enum Plan { case lifetime, yearly }
    @State private var plan: Plan = .lifetime
    @State private var receipt = FreeUseReceipt.current()
    @State private var restoreOutcome: StoreManager.RestoreOutcome?
    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if receipt.uses > 0 { receiptCard }
                    FreeUseStaysRow(ownCount: receipt.ownCount)
                    plans
                    purchaseButton
                    if plan == .yearly, let yearly = store.yearlyProduct { subscriptionTerms(yearly) }
                    footer
                }
                .padding(20)
            }
            .background(theme.surface.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: AppSymbol.xmark)
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel(NSLocalizedString("닫기", comment: "Close / dismiss"))
                }
            }
        }
        .restoreOutcomeAlert($restoreOutcome)
        .task { if store.products.isEmpty { await store.loadProducts() } }
        .onAppear {
            receipt = FreeUseReceipt.current()
            if isThresholdMoment { FreeUseMoments.shared.receiptShown() }
        }
    }

    // MARK: - 머리

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if receipt.uses > 0 {
                Text(String(format: NSLocalizedString("지난 %d일 동안", comment: "Free use paywall: over the last N days"), receipt.days))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
                Text(String(format: NSLocalizedString("단축어를 %d번 넣었어요", comment: "Free use paywall: inserted N times"), receipt.uses))
                    .font(.title.weight(.bold))
                    .foregroundColor(theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("ClipKeyboard Pro")
                    .font(.title.weight(.bold))
                    .foregroundColor(theme.text)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - 영수증

    private var receiptCard: some View {
        VStack(spacing: 12) {
            if receipt.minutesSaved > 0 {
                receiptRow(NSLocalizedString("아낀 시간", comment: "Free use receipt: time saved"),
                           String(format: NSLocalizedString("약 %d분", comment: "Free use receipt: about N minutes"), receipt.minutesSaved))
            }
            if let top = receipt.topSnippet {
                receiptRow(NSLocalizedString("가장 많이 쓴 것", comment: "Free use receipt: most used"),
                           String(format: NSLocalizedString("%1$@ · %2$d번", comment: "Free use receipt: title and count"), top.title, top.count))
            }
            receiptRow(NSLocalizedString("직접 만든 단축어", comment: "Free use receipt: own snippets"),
                       String(format: NSLocalizedString("%d개", comment: "Free use receipt: N items"), receipt.ownCount))
        }
        .padding(16)
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                .strokeBorder(theme.textFaint, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
        .accessibilityElement(children: .contain)
    }

    private func receiptRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundColor(theme.textMuted)
            Spacer(minLength: 12)
            Text(value).fontWeight(.semibold).foregroundColor(theme.text)
                .multilineTextAlignment(.trailing)
        }
        .font(.body)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 요금제

    private var plans: some View {
        VStack(spacing: 10) {
            planButton(.lifetime,
                       title: NSLocalizedString("평생 Pro", comment: "Plan: lifetime"),
                       caption: NSLocalizedString("한 번 결제하고 계속", comment: "Plan: lifetime caption"),
                       price: store.proProduct?.displayPrice,
                       badge: NSLocalizedString("추천", comment: "Plan: recommended badge"))
            if store.yearlyProduct != nil {
                planButton(.yearly,
                           title: NSLocalizedString("연 구독", comment: "Plan: yearly"),
                           caption: NSLocalizedString("매년 갱신, 언제든 해지", comment: "Plan: yearly caption"),
                           price: store.yearlyProduct?.displayPrice,
                           badge: nil)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(NSLocalizedString("요금제", comment: "Plans group"))
    }

    private func planButton(_ value: Plan, title: String, caption: String, price: String?, badge: String?) -> some View {
        let selected = plan == value
        return Button { plan = value } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title).font(.headline).foregroundColor(theme.text)
                        if let badge {
                            Text(badge)
                                .font(.body.weight(.bold))
                                .foregroundColor(theme.accentFg)
                                .padding(.horizontal, 8)
                                .background(theme.accent)
                                .clipShape(Capsule())
                        }
                    }
                    Text(caption).font(.body).foregroundColor(theme.textMuted)
                }
                Spacer(minLength: 8)
                if let price {
                    Text(price).font(.headline).foregroundColor(theme.text)
                } else {
                    ProgressView()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(selected ? theme.accentSoft : theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                    .strokeBorder(selected ? theme.accent : theme.textFaint.opacity(0.5), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
        }
        .buttonStyle(.squish)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: - 결제

    private var purchaseButton: some View {
        Button {
            Task { await buy() }
        } label: {
            ZStack {
                if isPurchasing {
                    ProgressView().tint(theme.accentFg)
                } else {
                    Text(plan == .lifetime
                         ? NSLocalizedString("평생 Pro로 계속하기", comment: "Buy lifetime CTA")
                         : NSLocalizedString("연 구독 시작하기", comment: "Buy yearly CTA"))
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(theme.accent)
            .foregroundColor(theme.accentFg)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
        }
        .buttonStyle(.squish)
        .disabled(isPurchasing)
    }

    private func buy() async {
        isPurchasing = true
        defer { isPurchasing = false }
        let source = isThresholdMoment ? "free_use_threshold" : "free_use_guide"
        let bought = plan == .lifetime
            ? await store.purchasePro(triggeredBy: source)
            : await store.purchaseYearly(triggeredBy: source)
        if bought { dismiss() }
    }

    /// 구독 조건. 무엇을 · 얼마에 · 언제 갱신되고 · 어떻게 끊는지를 결제 버튼 바로 아래에.
    private func subscriptionTerms(_ product: Product) -> some View {
        Text(String(format: NSLocalizedString("1년마다 %@씩 자동으로 갱신돼요. 갱신 24시간 전까지 설정 > Apple 계정 > 구독에서 해지할 수 있어요.", comment: "Yearly subscription terms"), product.displayPrice))
            .font(.body)
            .foregroundColor(theme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                Task { restoreOutcome = await store.restorePurchases() }
            } label: {
                Text(NSLocalizedString("이전 구매 복원", comment: "Restore"))
                    .font(.body)
                    .frame(minHeight: 44)
            }
            HStack(spacing: 20) {
                link(NSLocalizedString("이용약관", comment: "Terms of use link"), Constants.termsOfUseURL)
                link(NSLocalizedString("개인정보 처리방침", comment: "Privacy policy link"), Constants.privacyPolicyURL)
            }
            if let error = store.errorMessage {
                Text(error).font(.body).foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func link(_ title: String, _ address: String) -> some View {
        Button {
            if let url = URL(string: address) { openURL(url) }
        } label: {
            Text(title).font(.body).foregroundColor(theme.textMuted).underline()
                .frame(minHeight: 44)
        }
    }
}

/// "결제하지 않아도 만든 N개는 계속" - 요금제보다 먼저 말한다.
private struct FreeUseStaysRow: View {
    let ownCount: Int
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: AppSymbol.checkmark)
                .font(.body.weight(.bold))
                .foregroundColor(theme.success)
                .accessibilityHidden(true)
            Text(String(format: NSLocalizedString("결제하지 않아도 만든 %d개는 계속 넣을 수 있어요. Pro는 새로 만들고, 백업과 동기화를 여는 것이에요.", comment: "Free use paywall: what stays free"), ownCount))
                .font(.body)
                .foregroundColor(theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 영수증 값

/// 결제 화면이 보여 주는 숫자들. 전부 기기 안에 이미 있는 값이고 새로 모으는 것은 없다.
struct FreeUseReceipt: Equatable {
    struct Top: Equatable { let title: String; let count: Int }

    let uses: Int
    let days: Int
    let minutesSaved: Int
    let ownCount: Int
    let topSnippet: Top?

    static func current() -> FreeUseReceipt {
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        return make(uses: FreeUse.uses,
                    days: FreeUse.daysSinceFirstUse(),
                    secondsSaved: KeyboardUsageTracker.totalTimeSavedSeconds(),
                    memos: memos,
                    samples: ProFeatureManager.sampleMemoIds)
    }

    /// 순수 함수 - 시험이 여기를 본다.
    static func make(uses: Int, days: Int, secondsSaved: Double, memos: [Memo], samples: Set<UUID>) -> FreeUseReceipt {
        let own = memos.filter { !samples.contains($0.id) }
        let top = memos.filter { $0.clipCount > 0 }.max { $0.clipCount < $1.clipCount }
        return FreeUseReceipt(uses: uses,
                              days: days,
                              minutesSaved: Int(secondsSaved / 60),
                              ownCount: own.count,
                              topSnippet: top.map { Top(title: $0.title, count: $0.clipCount) })
    }
}
