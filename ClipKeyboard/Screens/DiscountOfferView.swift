//
//  DiscountOfferView.swift
//  ClipKeyboard
//
//  **반값 제안 창** - 평생 잠금해제를 반값에 건네는 화면. 두 자리에서 뜬다(`Occasion`).
//   · firstRun  : 설치하고 얼마 안 된 사람에게
//   · limitEdge : 한도 한 칸 앞(9개)에서 일주일을 지낸 사람에게
//  뜰 조건은 전부 `DiscountOfferManager` 가 판정한다(이 화면은 그리기만 한다).
//
//  ⚠️ 두 자리는 **문구가 다르다.** 앞의 사람은 아직 아무것도 안 써 봤고, 뒤의 사람은 한도에
//     닿아 봤다. 같은 말을 하면 한쪽에는 뜬금없고 다른 쪽에는 하나 마나 한 말이 된다.
//
//  ⚠️ 페이월(`PaywallView`)과 역할이 다르다.
//   · PaywallView = 막혔을 때 여는 문. 기능 비교표까지 다 있는 큰 화면.
//   · 이 화면    = 막히기 **전**에 한 번 건네는 제안. 읽을 것이 적고, 할 일이 하나다.
//     여기에 비교표를 또 붙이면 제안이 아니라 두 번째 페이월이 된다.
//
//  ⚠️ "반값"은 **반값 상품이 실제로 있을 때만** 말한다. 값을 지어내지 않고 스토어가 준
//     `displayPrice` 두 개를 그대로 나란히 보여준다(통화·자릿수도 스토어 것이 맞다).
//

import SwiftUI
import StoreKit

struct DiscountOfferView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var store = StoreManager.shared

    /// 어떤 자리에서 온 제안인가 - 문구와 애널리틱스가 이 값을 따라간다.
    var occasion: DiscountOfferManager.Occasion = .limitEdge

    /// 애널리틱스에서 이 창을 다른 페이월과, 그리고 서로 구분하는 이름.
    /// (두 기회의 전환율이 섞이면 어느 쪽이 먹히는지 영영 알 수 없다)
    private var analyticsSource: String { "discount_offer_" + occasion.rawValue }

    @State private var showSuccess = false
    @State private var didConvert = false

    var body: some View {
        VStack(spacing: 0) {
            closeBar
            ScrollView {
                VStack(spacing: 22) {
                    header
                    priceBlock
                    reasons
                    buyButton
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .background(theme.bg.ignoresSafeArea())
        .overlay { if showSuccess { successOverlay } }
        .onAppear {
            AnalyticsService.logPaywallView(triggeredBy: analyticsSource)
        }
        .onDisappear {
            if !didConvert {
                AnalyticsService.logPaywallDismissed(triggeredBy: analyticsSource)
            }
        }
    }

    // MARK: - 머리

    private var closeBar: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: AppSymbol.xmarkCircleFill)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(NSLocalizedString("닫기", comment: "Close paywall"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.15))
                    .frame(width: 84, height: 84)
                Image(systemName: AppSymbol.crownFill)
                    .font(.system(size: 38))
                    .foregroundStyle(.orange.gradient)
            }
            .accessibilityHidden(true)

            Text(title)
                .font(.title2.weight(.bold))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)

            // 왜 하필 지금 왔는지를 밝힌다 - 이유 없는 결제 창은 광고로만 읽힌다.
            Text(subtitle)
                .font(.callout)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var title: String {
        switch occasion {
        case .firstRun:
            return NSLocalizedString("시작하는 김에, 반값으로 열어 둘래요?", comment: "Discount offer title: first run")
        case .limitEdge:
            return NSLocalizedString("반값으로 평생 쓰실래요?", comment: "Discount offer title")
        }
    }

    private var subtitle: String {
        switch occasion {
        case .firstRun:
            // 아직 아무것도 안 써 본 사람이다. 한도 이야기를 꺼내면 협박이 되므로 값만 말한다.
            return NSLocalizedString("한번 결제하면 평생이에요. 지금 안 하셔도 앱은 그대로 다 쓰실 수 있어요.",
                                     comment: "Discount offer subtitle: first run")
        case .limitEdge:
            return String(format: NSLocalizedString("단축어 %d개를 일주일 넘게 쓰고 계세요. 이 창에서만 반값이에요.",
                                                    comment: "Discount offer subtitle: why now"),
                          DiscountOfferManager.limitEdgeCount)
        }
    }

    // MARK: - 값

    /// 정가에 줄을 긋고 반값을 옆에 둔다. 두 값 모두 스토어가 준 문자열 그대로.
    @ViewBuilder
    private var priceBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let regular = store.proProduct?.displayPrice {
                Text(regular)
                    .font(.title3)
                    .foregroundColor(theme.textMuted)
                    .strikethrough()
            }
            Text(store.discountedProProduct?.displayPrice ?? "")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(theme.text)
            Text(NSLocalizedString("50% 할인", comment: "Discount badge"))
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.orange))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(priceAccessibilityLabel)
    }

    private var priceAccessibilityLabel: String {
        let discounted = store.discountedProProduct?.displayPrice ?? ""
        guard let regular = store.proProduct?.displayPrice else { return discounted }
        return String(format: NSLocalizedString("정가 %1$@, 지금은 50%% 할인된 %2$@",
                                                comment: "Price accessibility: original and discounted"),
                      regular, discounted)
    }

    // MARK: - 무엇이 열리는가

    /// 비교표 대신 세 줄. **한도 이야기를 맨 위에** 둔다 - 지금 이 사람에게 걸린 것이 그것이다.
    private var reasons: some View {
        VStack(alignment: .leading, spacing: 12) {
            reasonRow(AppSymbol.sparkles,
                      NSLocalizedString("단축어 개수 제한이 사라져요", comment: "Discount offer reason: unlimited shortcuts"))
            reasonRow(AppSymbol.checkmarkSealFill,
                      NSLocalizedString("한번 결제하면 평생, 구독 아니에요", comment: "Discount offer reason: one-time"))
            reasonRow(AppSymbol.clockArrowCirclepath,
                      NSLocalizedString("이미 만든 단축어는 그대로 있어요", comment: "Discount offer reason: keeps existing data"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
    }

    private func reasonRow(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(.orange)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .foregroundColor(theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 사기

    private var buyButton: some View {
        VStack(spacing: 10) {
            Button {
                AnalyticsService.logPaywallCtaTapped(triggeredBy: analyticsSource, isTrial: false)
                Task { await buy() }
            } label: {
                Group {
                    if store.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(buttonText).fontWeight(.bold)
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(height: 54)
                .frame(maxWidth: .infinity)
                .background(.orange.gradient)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
            }
            .disabled(store.isLoading)
            .accessibilityLabel(store.isLoading
                ? NSLocalizedString("처리 중", comment: "Purchase loading state")
                : buttonText)

            // 지금 안 사도 잃는 것이 없다고 말해 준다. 겁을 줘서 파는 창이 아니다.
            Button {
                dismiss()
            } label: {
                Text(NSLocalizedString("지금은 괜찮아요", comment: "Discount offer decline"))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
            }

            if let error = store.errorMessage {
                Text(error)
                    .font(.body)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var buttonText: String {
        guard let price = store.discountedProProduct?.displayPrice else {
            return NSLocalizedString("반값으로 평생 사용", comment: "Discount offer buy button")
        }
        return String(format: NSLocalizedString("%@ 로 평생 사용", comment: "Discount offer buy button with price"), price)
    }

    private func buy() async {
        let success = await store.purchaseDiscountedPro(triggeredBy: analyticsSource)
        guard success else { return }
        didConvert = true
        withAnimation(reduceMotion ? nil : .spring(response: 0.4)) { showSuccess = true }
        #if os(iOS)
        UIAccessibility.post(notification: .announcement,
                             argument: NSLocalizedString("Pro 활성화 완료!", comment: "Pro activated announcement"))
        #endif
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        dismiss()
    }

    // MARK: - 꼬리

    private var footer: some View {
        VStack(spacing: 6) {
            Text(NSLocalizedString("일회성 결제 · 구독 없음 · 환불 가능", comment: "Purchase info"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
            // 놓쳐도 길이 있다는 것을 밝힌다.
            // ⚠️ 첫 화면에서는 "한 번만"이라고 말하지 않는다. 뒤에 기회가 한 번 더 있는데
            //    마지막인 것처럼 말하면 거짓말이고, 그렇다고 다음 기회를 예고하면 아무도 지금
            //    사지 않는다. 그래서 겁도 예고도 없이 "안 사도 된다"만 말한다.
            Text(NSLocalizedString("지금 안 하셔도 괜찮아요. 나중에 설정에서 구매할 수 있어요.",
                                   comment: "Discount offer: no pressure notice"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: AppSymbol.checkmarkCircleFill)
                    .font(.system(size: 64))
                    .foregroundStyle(Color.checkGreen)
                Text(NSLocalizedString("Pro 활성화 완료!", comment: "Pro activated"))
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg))
        }
        .transition(.opacity)
    }
}

#Preview {
    DiscountOfferView()
}
