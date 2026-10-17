//
//  PaywallView.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2026/02/21.
//

import SwiftUI
import LeeoKit
import StoreKit

/// Paywall - Pro 업그레이드 화면
/// 제한 도달 시 자연스럽게 표시
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var store = StoreManager.shared

    /// 어떤 제한 때문에 보여주는지 (nil이면 일반 업그레이드)
    var triggeredBy: ProFeatureManager.LimitType?

    @State private var showSuccessAnimation = false
    /// trial 상태가 바뀌었음을 알려 view를 다시 그리게 하는 tick (ProFeatureManager가 struct라 직접 observe 불가)
    @State private var trialTick: Int = 0
    /// 전환 완료 여부 - 닫기율(paywall_dismissed) 분리용 (구매/체험 시작이면 닫기로 안 침)
    @State private var didConvert = false
    /// 복원을 누른 결과. 값이 들어오면 알림이 뜬다.
    @State private var restoreOutcome: StoreManager.RestoreOutcome?
    /// 고른 칸(Plus · Pro). 처음에는 살 수 있는 칸 중 위의 것(`PaywallAccess.initialSelection`).
    @State private var selectedPlan: PaywallPlan?
    /// 방금 산 칸 - 성공 문구가 산 것을 말하게.
    @State private var boughtPlan: PaywallPlan?

    var body: some View {
        // 권한은 그릴 때 한 번만 읽는다(`PaywallAccess`).
        let access = PaywallAccess.current
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection(access)

                    // 제한에 걸려 열렸을 때만
                    if let trigger = triggeredBy {
                        limitBanner(trigger)
                    }

                    // 개인화 증거(이미 아낀 시간). 칸마다 무엇이 들어 있는지는 칸 카드가 말한다.
                    if !access.hasPermanentPro, let proof = timeSavedProof {
                        timeSavedBanner(proof)
                    }

                    // 구매 버튼은 가치 직후, 비교표 위
                    purchaseSection(access)

                    PaywallComparisonTable()

                    if !access.hasPermanentPro {
                        Text(NSLocalizedString("일회성 결제 · 구독 없음 · 환불 가능", comment: "Purchase info"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, 20)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    GlassCircleButton(AppSymbol.xmark, role: .secondary,
                                      label: NSLocalizedString("닫기", comment: "Close paywall")) {
                        dismiss()
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .overlay {
            if showSuccessAnimation {
                successOverlay
            }
        }
        .restoreOutcomeAlert($restoreOutcome)
        .onAppear {
            if selectedPlan == nil { selectedPlan = access.initialSelection }
            // ⚠️ 산 사람이 기능을 보러 연 것은 결제 화면 노출로 세지 않는다. 세면 전환율이 깎인다.
            if !access.hasPermanentPro {
                AnalyticsService.logPaywallView(triggeredBy: triggeredBy?.analyticsKey)
            }
        }
        .task {
            // 상품은 이 화면이 열릴 때 읽는다 - 런치에서 미리 읽지 않기 때문이다.
            // 안 읽으면 칸 추가 버튼이 아예 안 보이고(상품이 nil), Pro 버튼도 가격 없이
            // 뜬다. 구매 버튼을 누른 뒤에야 상품이 와서 그제야 나타나는 것이 그 증상이다.
            if store.products.isEmpty {
                await store.loadProducts()
            }
        }
        .onDisappear {
            // 구매/체험 시작이 아니면 "닫기"로 기록 → 닫기율(view 대비) 산출.
            if !didConvert && !ProFeatureManager.hasPermanentPro {
                AnalyticsService.logPaywallDismissed(triggeredBy: triggeredBy?.analyticsKey)
            }
        }
    }

    // MARK: - Header

    private func headerSection(_ access: PaywallAccess) -> some View {
        VStack(spacing: 12) {
            Image(systemName: AppSymbol.crownFill)
                .font(.system(size: 48))
                .foregroundStyle(.yellow.gradient)
                .accessibilityHidden(true)

            // 이미 Pro 인 사람에게는 그 이름 그대로. 아니면 고를 칸 둘을 다 말한다.
            Text(access.hasPermanentPro ? "ClipKeyboard Pro" : "ClipKeyboard Plus · Pro")
                .font(.title)
                .fontWeight(.bold)

            Text(headerSubtitle(access))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // 지금 이 사람의 자리. 값을 말하기 전에 **지금 어디에 서 있는지**부터 말한다.
            // 이 줄이 없으면 "무제한" 이 무엇에서 풀려나는 말인지 알 수 없다.
            if !access.hasPermanentPro {
                limitStatusRow
            }
        }
        .padding(.top, 20)
    }

    /// "내 단축어 7 / 10칸" - 산 칸까지 더한 **지금 이 사람의** 한도를 말한다.
    ///
    /// ⚠️ 세는 것은 자기 것뿐이다(`ownMemoCount`). 온보딩이 심어 준 샘플까지 세면
    ///    아무것도 안 만든 사람이 4/10 에서 시작한다.
    private var limitStatusRow: some View {
        let limit = ProFeatureManager.memoLimit
        let text = limit == Int.max
            ? NSLocalizedString("단축어 무제한", comment: "Paywall: unlimited slots")
            : String(format: NSLocalizedString("지금 내 단축어 %1$d / %2$d칸", comment: "Paywall: current slot usage"),
                     ProFeatureManager.ownMemoCount(MemoStore.shared.memos), limit)
        return Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.orange.opacity(0.12), in: Capsule())
    }

    private func headerSubtitle(_ access: PaywallAccess) -> String {
        // 이미 산 사람도 "무엇이 열려 있는지" 보러 온다(`ProBenefitsView` 의 전체 보기). 파는 말은 하지 않는다.
        if access.hasPermanentPro {
            return NSLocalizedString("모든 Pro 기능이 열려 있어요", comment: "Paywall subtitle for users who already have Pro")
        }
        if ProFeatureManager.canStartTrial {
            return String(format: NSLocalizedString("%d일 무료 체험 · 한번 구매, 평생 사용", comment: "Trial subtitle"), ProFeatureManager.trialDurationDays)
        }
        return NSLocalizedString("한번 구매, 평생 사용", comment: "One-time purchase")
    }

    // MARK: - 이미 아낀 시간

    private func timeSavedBanner(_ proof: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: AppSymbol.clockArrowCirclepath)
                .font(.title3)
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text(proof)
                .font(.callout.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: theme.radiusMd))
        .accessibilityElement(children: .combine)
    }

    /// 이미 절약한 시간을 증거로 - 5분 이상일 때만. "Pro로 계속 아끼세요" 는 산 사람에게 하지 않는다(부르는 쪽이 거른다).
    private var timeSavedProof: String? {
        let seconds = KeyboardUsageTracker.totalTimeSavedSeconds()
        guard seconds >= 300 else { return nil }
        return String(format: NSLocalizedString("이미 ClipKeyboard로 %d분을 아꼈어요. Pro로 무제한으로 계속 아끼세요.", comment: "Paywall personalized time-saved proof"), Int(seconds / 60))
    }

    // MARK: - Limit Banner

    private func limitBanner(_ limit: ProFeatureManager.LimitType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: AppSymbol.infoCircleFill)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text(limit.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: theme.radiusMd))
    }

    // MARK: - Purchase

    private func purchaseSection(_ access: PaywallAccess) -> some View {
        VStack(spacing: 12) {
            if access.hasPermanentPro {
                // 이미 Pro (구매 / 그랜드파더 / TestFlight) - store.isPro만 보면 그랜드파더 누락
                Label(NSLocalizedString("Pro 활성화됨", comment: "Pro active"),
                      systemImage: AppSymbol.checkmarkSealFill)
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding()
                // 다 가진 사람이 더 내고 싶을 때 갈 곳(팁). 팁 상품이 와 있을 때만.
                if let tipJar = store.tipJar, tipJar.isAvailable {
                    NavigationLink {
                        LeeoTipJarView<ClipKeyboardSpec>(tipJar: tipJar).leeoStyle(theme.leeoStyle)
                    } label: {
                        Label(LeeoTipText.entry, systemImage: AppSymbol.heartFill)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
            } else {
                if ProFeatureManager.isInTrial {
                    trialActiveBadge
                }
                // 무료 체험 시작 버튼 (1회 한정, 자격 있을 때만)
                if ProFeatureManager.canStartTrial {
                    trialStartButton
                }

                planCards(access)
                buyButton(access)

                Button {
                    Task {
                        let outcome = await store.restorePurchases()
                        if outcome == .restored { didConvert = true }
                        restoreOutcome = outcome
                    }
                } label: {
                    Text(NSLocalizedString("이전 구매 복원", comment: "Restore"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                if let error = store.errorMessage {
                    Text(error)
                        .font(.body)
                        .foregroundStyle(.red)
                }
            }
        }
        .id(trialTick) // trial 시작 시 강제 redraw
    }

    /// "7일 무료 체험 시작" 버튼
    private var trialStartButton: some View {
        Button {
            AnalyticsService.logPaywallCtaTapped(triggeredBy: triggeredBy?.analyticsKey, isTrial: true)
            guard ProFeatureManager.startTrial() else { return }
            didConvert = true
            AnalyticsService.logTrialStarted(triggeredBy: triggeredBy?.analyticsKey)
            trialTick &+= 1
            celebrateAndDismiss()
        } label: {
            Label(String(format: NSLocalizedString("%d일 무료 체험 시작", comment: "Start free trial button"), ProFeatureManager.trialDurationDays),
                  systemImage: AppSymbol.giftFill)
                .font(.headline)
                .foregroundStyle(.orange)
                .frame(height: 54)
                .frame(maxWidth: .infinity)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: theme.radiusMd))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusMd)
                        .stroke(.orange.opacity(0.4), lineWidth: 1.5)
                )
        }
    }

    /// 활성 trial 상태 배지
    private var trialActiveBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: AppSymbol.clockBadgeCheckmarkFill)
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text(String(format: NSLocalizedString("체험 활성: %d일 남음", comment: "Trial active days remaining"), ProFeatureManager.trialDaysRemaining))
                .font(.body)
                .fontWeight(.medium)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: theme.radiusSm))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Plans

    /// 이 칸을 고르면 결제할 상품. **카드에 적은 값과 결제하는 상품은 반드시 같다.**
    private func product(for plan: PaywallPlan, _ state: PaywallPlanState) -> Product? {
        switch state {
        case .buy:      return plan == .plus ? store.plusProduct : store.proProduct
        case .upgrade:  return store.upgradeProProduct
        case .owned, .included: return nil
        }
    }

    /// Plus · Pro 두 장. Pro 를 위에 둔다(위 칸이 기준이고, Plus 는 그보다 가벼운 길이다).
    private func planCards(_ access: PaywallAccess) -> some View {
        VStack(spacing: 10) {
            ForEach(PaywallPlan.allCases.reversed()) { plan in
                let state = access[plan]
                PaywallPlanCard(plan: plan,
                                state: state,
                                price: product(for: plan, state)?.displayPrice,
                                isSelected: selectedPlan == plan,
                                isRecommended: plan == .pro,
                                onSelect: {
                                    HapticManager.shared.light()
                                    selectedPlan = plan
                                })
            }
        }
    }

    /// 고른 칸을 사는 버튼. 고른 칸을 살 수 없으면(이미 가짐) 서지 않는다.
    @ViewBuilder
    private func buyButton(_ access: PaywallAccess) -> some View {
        if let plan = selectedPlan, case let state = access[plan], state.isPurchasable {
            let product = product(for: plan, state)
            let title = buyButtonTitle(plan, state, price: product?.displayPrice)
            Button {
                buy(plan, state)
            } label: {
                Group {
                    if store.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(title).fontWeight(.bold)
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(height: 54)
                .frame(maxWidth: .infinity)
                .background(.orange.gradient, in: RoundedRectangle(cornerRadius: theme.radiusMd))
            }
            // 상품을 못 읽었으면 누를 수 없다. 누른 뒤에 "상품 없음" 을 듣는 것보다 낫다.
            .disabled(store.isLoading || product == nil)
            .accessibilityLabel(store.isLoading
                ? NSLocalizedString("처리 중", comment: "Purchase loading state")
                : title)
        }
    }

    private func buyButtonTitle(_ plan: PaywallPlan, _ state: PaywallPlanState, price: String?) -> String {
        switch (state, price) {
        case (.upgrade, let price?):
            return String(format: NSLocalizedString("%@ 로 Pro 로 올리기", comment: "Paywall CTA: upgrade Plus to Pro, %@ is price"), price)
        case (.upgrade, nil):
            return NSLocalizedString("Pro 로 올리기", comment: "Paywall CTA: upgrade to Pro without price")
        case (_, let price?):
            return String(format: NSLocalizedString("%1$@ 시작하기 · %2$@", comment: "Paywall CTA: start plan, %1$@ plan name, %2$@ price"), plan.name, price)
        case (_, nil):
            return String(format: NSLocalizedString("%@ 시작하기", comment: "Paywall CTA: start plan without price"), plan.name)
        }
    }

    private func buy(_ plan: PaywallPlan, _ state: PaywallPlanState) {
        let source = triggeredBy?.analyticsKey
        AnalyticsService.logPaywallCtaTapped(triggeredBy: source ?? "plan_\(plan.rawValue)", isTrial: false)
        Task {
            // ⚠️ 카드에 적은 상품만 결제한다. 업그레이드 칸에서 정가가 빠져나가면 사고다.
            let success: Bool
            switch (plan, state) {
            case (.plus, .buy):     success = await store.purchasePlus(triggeredBy: source)
            case (.pro, .buy):      success = await store.purchasePro(triggeredBy: source)
            case (.pro, .upgrade):  success = await store.purchaseUpgradePro(triggeredBy: source)
            default:                return
            }
            guard success else { return }
            didConvert = true
            boughtPlan = plan
            #if os(iOS)
            UIAccessibility.post(notification: .announcement, argument: successText)
            #endif
            celebrateAndDismiss()
        }
    }

    /// 성공 표시를 띄우고 1.5초 뒤 닫는다. 체험 시작과 구매가 같이 쓴다.
    private func celebrateAndDismiss() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.4)) {
            showSuccessAnimation = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: AppSymbol.checkmarkCircleFill)
                    .font(.system(size: 64))
                    .foregroundStyle(Color.checkGreen)

                Text(successText)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .translucentBackground(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg))
        }
        .transition(.opacity)
    }

    /// 구매 vs trial 시작에 따라 다른 메시지
    private var successText: String {
        if ProFeatureManager.isInTrial && !ProFeatureManager.hasPermanentPro {
            return NSLocalizedString("체험 시작! 모든 기능 잠금 해제됨", comment: "Trial started")
        }
        if boughtPlan == .plus {
            return NSLocalizedString("Plus 활성화 완료!", comment: "Plus activated")
        }
        return NSLocalizedString("Pro 활성화 완료!", comment: "Pro activated")
    }
}

// MARK: - Paywall Modifier

/// 제한 도달 시 자동으로 Paywall을 띄우는 ViewModifier
struct PaywallModifier: ViewModifier {
    @Binding var isPresented: Bool
    var limitType: ProFeatureManager.LimitType?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                PaywallView(triggeredBy: limitType)
                    .presentationDetents([.large])
            }
    }
}

extension View {
    /// Paywall 시트를 쉽게 붙이는 modifier
    func paywall(isPresented: Binding<Bool>, triggeredBy: ProFeatureManager.LimitType? = nil) -> some View {
        modifier(PaywallModifier(isPresented: isPresented, limitType: triggeredBy))
    }
}

#Preview {
    PaywallView(triggeredBy: .memo)
}

// MARK: - 복원 결과 알림

/// "이전 구매 복원" 을 누른 뒤 결과를 알린다. 페이월과 설정이 같은 문구를 쓴다.
///
/// ⚠️ 찾은 것이 없을 때가 가장 중요하다. 말이 없으면 버튼이 고장 난 것처럼 보인다.
struct RestoreOutcomeAlert: ViewModifier {
    @Binding var outcome: StoreManager.RestoreOutcome?

    func body(content: Content) -> some View {
        content.alert(item: $outcome) { outcome in
            switch outcome {
            case .restored:
                // Plus 만 산 사람에게 "Pro 기능" 이라 하면 없는 것을 준다고 말하는 셈이다.
                let restoredMessage = ProFeatureManager.hasPermanentPro
                    ? NSLocalizedString("Pro 기능을 다시 쓸 수 있어요.", comment: "Restore result message: Pro restored")
                    : NSLocalizedString("Plus 기능을 다시 쓸 수 있어요.", comment: "Restore result message: Plus restored")
                return Alert(
                    title: Text(NSLocalizedString("구매를 복원했어요", comment: "Restore result title: Pro restored")),
                    message: Text(restoredMessage),
                    dismissButton: .default(Text(NSLocalizedString("확인", comment: "OK")))
                )
            case .nothingFound:
                return Alert(
                    title: Text(NSLocalizedString("복원할 구매가 없어요", comment: "Restore result title: nothing to restore")),
                    message: Text(NSLocalizedString("지금 로그인한 Apple ID 로 Pro 를 구매한 기록을 찾지 못했어요. 구매할 때 쓴 Apple ID 로 로그인했는지 확인해 주세요.", comment: "Restore result message: no Pro purchase found for this Apple ID")),
                    dismissButton: .default(Text(NSLocalizedString("확인", comment: "OK")))
                )
            case .failed(let message):
                return Alert(
                    title: Text(NSLocalizedString("복원하지 못했어요", comment: "Restore result title: failed")),
                    message: Text(String(format: NSLocalizedString("App Store 에 연결하지 못했어요. 잠시 뒤 다시 시도해 주세요.\n(%@)", comment: "Restore result message: App Store error, %@ is the system error"), message)),
                    dismissButton: .default(Text(NSLocalizedString("확인", comment: "OK")))
                )
            }
        }
    }
}

extension View {
    func restoreOutcomeAlert(_ outcome: Binding<StoreManager.RestoreOutcome?>) -> some View {
        modifier(RestoreOutcomeAlert(outcome: outcome))
    }
}
