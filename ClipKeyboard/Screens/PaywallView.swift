//
//  PaywallView.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2026/02/21.
//

import SwiftUI
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

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - 헤더
                    headerSection

                    // MARK: - 제한 안내 (트리거된 경우)
                    if let trigger = triggeredBy {
                        limitBanner(trigger)
                    }

                    // MARK: - 가치 제안 (개인화 증거 + 결과 중심)
                    valueProps

                    // MARK: - 구매 버튼 (가치 직후, 스펙표 위)
                    purchaseSection

                    // MARK: - 기능 비교 (보조 디테일)
                    featureComparison

                    // MARK: - 하단 정보
                    footerSection
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: AppSymbol.xmarkCircleFill)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(NSLocalizedString("닫기", comment: "Close paywall"))
                }
            }
        }
        .overlay {
            if showSuccessAnimation {
                successOverlay
            }
        }
        .onAppear {
            AnalyticsService.logPaywallView(triggeredBy: triggeredBy?.analyticsKey)
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
            if !didConvert {
                AnalyticsService.logPaywallDismissed(triggeredBy: triggeredBy?.analyticsKey)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: AppSymbol.crownFill)
                .font(.system(size: 48))
                .foregroundStyle(.yellow.gradient)

            Text("ClipKeyboard Pro")
                .font(.title)
                .fontWeight(.bold)

            Text(headerSubtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // 지금 이 사람의 자리. 값을 말하기 전에 **지금 어디에 서 있는지**부터 말한다.
            // 이 줄이 없으면 "무제한" 이 무엇에서 풀려나는 말인지 알 수 없다.
            if !ProFeatureManager.hasPermanentPro {
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
        let own = ProFeatureManager.ownMemoCount(MemoStore.shared.memos)
        let limit = ProFeatureManager.memoLimit
        let text = limit == Int.max
            ? NSLocalizedString("단축어 무제한", comment: "Paywall: unlimited slots")
            : String(format: NSLocalizedString("지금 내 단축어 %1$d / %2$d칸", comment: "Paywall: current slot usage"), own, limit)
        return Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.orange.opacity(0.12))
            .clipShape(Capsule())
            .accessibilityLabel(text)
    }

    private var headerSubtitle: String {
        if ProFeatureManager.canStartTrial {
            return String(format: NSLocalizedString("%d일 무료 체험 · 한번 구매, 평생 사용", comment: "Trial subtitle"), ProFeatureManager.trialDurationDays)
        }
        return NSLocalizedString("한번 구매, 평생 사용", comment: "One-time purchase")
    }

    // MARK: - Value Props (개인화 증거 + 결과 중심)

    private var valueProps: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 개인화된 증거 - 이미 절약한 시간(있을 때만). 가장 강력한 전환 훅.
            if let proof = timeSavedProof {
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
                .background(.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                .accessibilityElement(children: .combine)
            }

            valueRow("checkmark.seal.fill",
                     NSLocalizedString("IBAN·타임존·계좌 응대를 무제한 저장, 어떤 앱에서든 탭 한 번", comment: "Paywall value: unlimited save"))
            valueRow("text.bubble.fill",
                     NSLocalizedString("프로페셔널 영어 템플릿을 마음껏: 비원어민도 유창하게", comment: "Paywall value: english templates"))
            valueRow("icloud.fill",
                     NSLocalizedString("iCloud 백업·스택·보안 단축어·macOS 앱까지 전부", comment: "Paywall value: pro extras"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func valueRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.orange)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    /// 이미 절약한 시간을 증거로 - 5분 이상일 때만 노출.
    private var timeSavedProof: String? {
        let seconds = KeyboardUsageTracker.totalTimeSavedSeconds()
        guard seconds >= 300 else { return nil }
        let minutes = Int(seconds / 60)
        return String(format: NSLocalizedString("이미 ClipKeyboard로 %d분을 아꼈어요. Pro로 무제한으로 계속 아끼세요.", comment: "Paywall personalized time-saved proof"), minutes)
    }

    // MARK: - Limit Banner

    private func limitBanner(_ limit: ProFeatureManager.LimitType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: AppSymbol.infoCircleFill)
                .foregroundStyle(.orange)

            Text(limit.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
    }

    // MARK: - Feature Comparison

    private var featureComparison: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text(NSLocalizedString("기능", comment: "Feature"))
                    .font(.body)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(NSLocalizedString("무료", comment: "Free"))
                    .font(.body)
                    .fontWeight(.medium)
                    .frame(width: 60)

                Text("Pro")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                    .frame(width: 60)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(theme.surfaceAlt)

            // 행들
            featureRow(NSLocalizedString("키보드에서 보이는 단축어", comment: "Keyboard visible memos feature row"),
                       free: String(format: NSLocalizedString("%d개", comment: "count unit"), 10),
                       pro: NSLocalizedString("무제한", comment: "Unlimited"))

            featureRow(NSLocalizedString("단축어 저장", comment: "Memo"),
                       free: String(format: NSLocalizedString("%d개", comment: "count unit"), ProFeatureManager.freeMemoLimit),
                       pro: NSLocalizedString("무제한", comment: "Unlimited"))

            featureRow(NSLocalizedString("스택", comment: "Combo"),
                       free: String(format: NSLocalizedString("%d개", comment: "count unit"), ProFeatureManager.freeStackLimit),
                       pro: NSLocalizedString("무제한", comment: "Unlimited"))

            featureRow(NSLocalizedString("템플릿", comment: "Template"),
                       free: String(format: NSLocalizedString("%d개", comment: "count unit"), ProFeatureManager.freeTemplateLimit),
                       pro: NSLocalizedString("무제한", comment: "Unlimited"))

            featureRow(NSLocalizedString("클립보드 기록", comment: "Clipboard"),
                       free: String(format: NSLocalizedString("%d개", comment: "count unit"), ProFeatureManager.freeClipboardHistoryLimit),
                       pro: String(format: NSLocalizedString("%d개", comment: "count unit"), 100))

            featureRow(NSLocalizedString("iCloud 백업", comment: "iCloud"),
                       free: "-", pro: "✓", isProOnly: true)

            featureRow(NSLocalizedString("생체인증 잠금", comment: "Biometric"),
                       free: "-", pro: "✓", isProOnly: true)

            featureRow(NSLocalizedString("이미지 단축어", comment: "Image"),
                       free: String(format: NSLocalizedString("%d개", comment: "count unit"), ProFeatureManager.freeImageMemoLimit),
                       pro: NSLocalizedString("무제한", comment: "Unlimited"))
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMd)
                .stroke(theme.surfaceAlt, lineWidth: 1)
        )
    }

    private func featureRow(_ name: String, free: String, pro: String, isProOnly: Bool = false) -> some View {
        let freeLabel = free == "-"
            ? NSLocalizedString("미포함", comment: "Feature not included")
            : free == "✓" ? NSLocalizedString("포함", comment: "Feature included") : free
        let proLabel = pro == "-"
            ? NSLocalizedString("미포함", comment: "Feature not included")
            : pro == "✓" ? NSLocalizedString("포함", comment: "Feature included") : pro

        return HStack {
            Text(name)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(free)
                .font(.body)
                .foregroundStyle(isProOnly ? .secondary : .primary)
                .frame(width: 60)

            Text(pro)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.orange)
                .frame(width: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(format: NSLocalizedString("%@, 무료: %@, Pro: %@", comment: "Feature row: name, free plan value, pro plan value"),
                   name, freeLabel, proLabel)
        )
    }

    // MARK: - Purchase

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            if ProFeatureManager.hasPermanentPro {
                // 이미 Pro (구매 / 그랜드파더 / TestFlight) - store.isPro만 보면 그랜드파더 누락
                Label(NSLocalizedString("Pro 활성화됨", comment: "Pro active"),
                      systemImage: AppSymbol.checkmarkSealFill)
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding()
            } else {
                // 활성 trial 표시
                if ProFeatureManager.isInTrial {
                    trialActiveBadge
                }

                // 7일 무료 체험 시작 버튼 (1회 한정, 자격 있을 때만)
                if ProFeatureManager.canStartTrial {
                    trialStartButton
                }

                // 구매 버튼
                Button {
                    AnalyticsService.logPaywallCtaTapped(triggeredBy: triggeredBy?.analyticsKey, isTrial: false)
                    Task {
                        // ⚠️ 업그레이드 값을 보여 준 화면에서 정가가 빠져나가면 사고다.
                        //    보여 준 상품과 결제하는 상품은 반드시 같아야 한다.
                        let success = isUpgradeOffer
                            ? await store.purchaseUpgradePro(triggeredBy: triggeredBy?.analyticsKey)
                            : await store.purchasePro(triggeredBy: triggeredBy?.analyticsKey)
                        if success {
                            didConvert = true
                            withAnimation(reduceMotion ? nil : .spring(response: 0.4)) {
                                showSuccessAnimation = true
                            }
                            #if os(iOS)
                            UIAccessibility.post(notification: .announcement,
                                argument: NSLocalizedString("Pro 활성화 완료!", comment: "Pro activated announcement"))
                            #endif
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        if store.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(priceText)
                                .fontWeight(.bold)
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(height: 54)
                    .frame(maxWidth: .infinity)
                    .background(.orange.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                }
                .disabled(store.isLoading)
                .accessibilityLabel(store.isLoading
                    ? NSLocalizedString("처리 중", comment: "Purchase loading state")
                    : priceText
                )
                .accessibilityHint(store.isLoading ? "" : NSLocalizedString("탭하면 Pro를 구매합니다", comment: "Purchase button hint"))

                // 칸에 낸 돈이 빠졌다는 말 - 업그레이드 값으로 샀을 때만.
                if isUpgradeOffer {
                    upgradeCaption
                }

                // 작은 계단 - 평생이 부담스러운 사람에게 다섯 칸만 파는 길.
                // ⚠️ Pro 버튼 **아래**에 둔다. 위에 두면 싼 것부터 눈에 들어와 평생 구매가
                //    비교당하기만 한다. 이건 대안이지 추천이 아니다.
                // ⚠️ 조건은 "아직 안 샀나" 가 아니라 "**더 살 수 있나**" 다. 예전에는
                //    한 번 산 사람에게 버튼이 사라져서, 다섯 칸을 더 원하는 사람 앞에서
                //    사다리가 끊겼다.
                if SlotPack.canBuyMore, let slots = store.slotPackProduct {
                    slotPackButton(slots)
                }

                // 두 대째 - 기기가 둘이 된 사람에게만 보이는 다른 문.
                // ⚠️ 이건 Pro 의 대안이 아니라 **다른 물건**이다. 그래서 평생을 살 수 없는
                //    사람에게 내미는 것이 아니라, 기기 문제로 온 사람에게만 내민다.
                if shouldOfferTwoDevice, let twoDevice = store.twoDeviceProduct {
                    twoDeviceButton(twoDevice)
                }

                // 복원 버튼
                Button {
                    Task { await store.restorePurchases() }
                } label: {
                    Text(NSLocalizedString("이전 구매 복원", comment: "Restore"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                // 에러 메시지
                if let error = store.errorMessage {
                    Text(error)
                        .font(.body)
                        .foregroundStyle(.red)
                }
            }
        }
        .id(trialTick) // trial 시작 시 강제 redraw
    }

    /// 칸 추가 버튼 - 개수만 늘린다(다른 Pro 기능은 그대로 잠겨 있다).
    private func slotPackButton(_ product: Product) -> some View {
        Button {
            AnalyticsService.logPaywallCtaTapped(triggeredBy: "slot_pack", isTrial: false)
            Task {
                if await store.purchaseSlotPack(triggeredBy: "slot_pack") {
                    didConvert = true
                    dismiss()
                }
            }
        } label: {
            VStack(spacing: 2) {
                Text(String(format: NSLocalizedString("%1$@ 로 %2$d칸만 더 늘리기", comment: "Slot pack button"),
                            product.displayPrice, SlotPack.slotsPerPack))
                    .font(.headline)
                // 무엇이 아닌지도 말한다 - 사고 나서 "이게 다야?" 가 되면 안 된다.
                // 어디까지 살 수 있는지도 같이 말한다. 끝이 없는 것처럼 보이면 안 된다.
                Text(String(format: NSLocalizedString("개수만 늘어요. 다른 Pro 기능은 열리지 않아요 (최대 %d칸)",
                                                      comment: "Slot pack button caption"),
                            ProFeatureManager.freeMemoLimit + SlotPack.maxExtraSlots))
                    .font(.caption2)
            }
            .foregroundStyle(.orange)
            .frame(height: 54)
            .frame(maxWidth: .infinity)
            .background(.orange.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
        }
        .disabled(store.isLoading)
    }

    /// "7일 무료 체험 시작" 버튼
    private var trialStartButton: some View {
        Button {
            AnalyticsService.logPaywallCtaTapped(triggeredBy: triggeredBy?.analyticsKey, isTrial: true)
            let started = ProFeatureManager.startTrial()
            if started {
                didConvert = true
                AnalyticsService.logTrialStarted(triggeredBy: triggeredBy?.analyticsKey)
                trialTick &+= 1
                withAnimation(reduceMotion ? nil : .spring(response: 0.4)) {
                    showSuccessAnimation = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: AppSymbol.giftFill)
                Text(String(format: NSLocalizedString("%d일 무료 체험 시작", comment: "Start free trial button"), ProFeatureManager.trialDurationDays))
                    .fontWeight(.semibold)
            }
            .font(.headline)
            .foregroundStyle(.orange)
            .frame(height: 54)
            .frame(maxWidth: .infinity)
            .background(.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
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
        .background(.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm))
        .accessibilityElement(children: .combine)
    }

    /// 지금 이 사람에게 **업그레이드 값**을 팔고 있는가.
    ///
    /// 칸을 산 사람에게만, 그리고 그 상품이 실제로 로드됐을 때만 참이다.
    /// ⚠️ 상품이 없으면 거짓이어야 한다. 깎아 준다고 말해 놓고 정가를 결제시키는 것은
    ///    거짓말이다(반값과 같은 규칙).
    private var isUpgradeOffer: Bool {
        ProUpgrade.isEligible && store.upgradeProProduct != nil
    }

    /// 두 대째를 내밀 자리인가 - 기기 문제로 온 사람에게만.
    private var shouldOfferTwoDevice: Bool {
        triggeredBy == .deviceSync && !ProFeatureManager.isSyncAvailable
    }

    /// 업그레이드 값 아래 한 줄 - 왜 싼지를 말한다.
    /// 이유 없이 싼 값은 정가가 거짓이었다는 뜻으로 읽힌다.
    private var upgradeCaption: some View {
        Text(NSLocalizedString("칸 추가에 내신 값이 빠진 값이에요", comment: "Upgrade price caption"))
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// 두 대째 버튼 - 동기화만 연다.
    private func twoDeviceButton(_ product: Product) -> some View {
        Button {
            AnalyticsService.logPaywallCtaTapped(triggeredBy: "two_device", isTrial: false)
            Task {
                if await store.purchaseTwoDevice(triggeredBy: "two_device") {
                    didConvert = true
                    dismiss()
                }
            }
        } label: {
            VStack(spacing: 2) {
                Text(String(format: NSLocalizedString("%@ 로 두 기기에서 같이 쓰기", comment: "Two device button"),
                            product.displayPrice))
                    .font(.headline)
                // 무엇이 아닌지도 말한다.
                Text(NSLocalizedString("동기화만 열려요. 단축어 개수는 그대로예요",
                                       comment: "Two device button caption"))
                    .font(.caption2)
            }
            .foregroundStyle(.orange)
            .frame(height: 54)
            .frame(maxWidth: .infinity)
            .background(.orange.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
        }
        .disabled(store.isLoading)
    }

    private var priceText: String {
        // 업그레이드 값을 보여 줄 때는 **그 상품의 값**을 적는다.
        if isUpgradeOffer, let upgrade = store.upgradeProProduct {
            return String(format: NSLocalizedString("Pro 업그레이드: %@", comment: "Price"), upgrade.displayPrice)
        }
        if let product = store.proProduct {
            return String(format: NSLocalizedString("Pro 업그레이드: %@", comment: "Price"), product.displayPrice)
        }
        return NSLocalizedString("Pro 업그레이드", comment: "Upgrade")
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 4) {
            Text(NSLocalizedString("일회성 결제 · 구독 없음 · 환불 가능", comment: "Purchase info"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 20)
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
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg))
        }
        .transition(.opacity)
    }

    /// 구매 vs trial 시작에 따라 다른 메시지
    private var successText: String {
        if ProFeatureManager.isInTrial && !ProFeatureManager.hasPermanentPro {
            return NSLocalizedString("체험 시작! 모든 기능 잠금 해제됨", comment: "Trial started")
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
