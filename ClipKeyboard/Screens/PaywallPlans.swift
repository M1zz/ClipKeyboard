//
//  PaywallPlans.swift
//  ClipKeyboard
//
//  페이월의 **세 칸**: 무료 · Plus · Pro (`AccessTier`). 유료 칸마다 연 구독과 평생을 나란히 판다.
//
//    무료   지금 그대로  단축어 · 템플릿 몇 개, 클립보드 기록 50개
//    Plus   쌓기        단축어 · 템플릿 · 스택 · 이미지 무제한       (`plus.yearly` · 평생 `slots5`)
//    Pro    지키기      Plus 전부 + iCloud 백업 · 생체 잠금 · 동기화(베타)
//                       (`pro.yearly` · 평생 `pro`, Plus 평생을 산 사람의 평생은 `pro.upgrade`)
//
//  칸을 늘어놓고 사는 일은 `PaywallLadder` 가 한다. 여기는 칸 하나의 규칙과 모양이다.
//
//  ⚠️ 마스터는 여기 세우지 않는다. 마스터에만 있는 기능이 아직 없고, 상품도 App Store Connect 에 없다.
//     생기면 `PaywallPlan` 에 한 칸을 더한다.
//  ⚠️ 두 대째(`TwoDevicePack`) · 칸 팩(`SlotPack`)은 팔지 않는다. 산 사람의 권한만 남는다.
//     동기화는 아직 베타라 따로 돈을 받을 물건이 아니고, 칸 팩은 Plus 가 대신한다.
//

import SwiftUI
import StoreKit
import LeeoKit

// MARK: - 칸

enum PaywallPlan: String, CaseIterable, Identifiable {
    case plus
    case pro

    var id: String { rawValue }

    /// 이름. 고유명사라 번역하지 않는다(App Store 상품 이름과 같다).
    var name: String {
        switch self {
        case .plus: return "Plus"
        case .pro:  return "Pro"
        }
    }

    /// 한 줄 요약 - 이 칸이 **무엇을 위한 것인지**.
    var tagline: String {
        switch self {
        case .plus: return NSLocalizedString("마음껏 쌓기", comment: "Paywall plan tagline: Plus")
        case .pro:  return NSLocalizedString("쌓은 것을 지키기", comment: "Paywall plan tagline: Pro")
        }
    }

    /// 카드에 적는 것. Pro 는 Plus 를 다시 늘어놓지 않고 "Plus 전부" 한 줄로 시작한다.
    var highlights: [String] {
        switch self {
        case .plus:
            return [
                NSLocalizedString("단축어 · 템플릿 무제한", comment: "Paywall Plus highlight: unlimited snippets and templates"),
                NSLocalizedString("스택 · 이미지 단축어 무제한", comment: "Paywall Plus highlight: unlimited stacks and images"),
                String(format: NSLocalizedString("클립보드 기록 %d개", comment: "Paywall highlight: clipboard history count"), 100)
            ]
        case .pro:
            return [
                NSLocalizedString("Plus 의 모든 것", comment: "Paywall Pro highlight: everything in Plus"),
                NSLocalizedString("iCloud 백업 · 생체인증 잠금", comment: "Paywall Pro highlight: backup and biometric lock"),
                NSLocalizedString("기기 간 동기화 (베타)", comment: "Cross-device sync section header")
            ]
        }
    }
}

// MARK: - 이 사람에게 각 칸이 어떤 상태인가

/// 각 칸 카드가 무엇을 말하고 무엇을 파는가. **순수 값**이라 시험으로 고정한다(`PaywallPlansTests`).
enum PaywallPlanState: Equatable {
    /// 산다(정가).
    case buy
    /// Plus 평생을 가진 사람이 Pro 로 오른다(평생은 `pro.upgrade`).
    case upgrade
    /// 이미 가졌다.
    case owned
    /// 위 칸을 가져서 이 칸은 저절로 들어 있다.
    case included

    var isPurchasable: Bool { self == .buy || self == .upgrade }
}

enum PaywallPlanRules {
    /// - Parameters:
    ///   - purchased: 산 트림(`ProFeatureManager.purchasedTier`). 체험 · 무료 기간은 넣지 않는다.
    ///   - hasPermanentPro: 산 Pro · v3.x 그랜드파더 · TestFlight.
    ///   - upgradeEligible: Plus 평생(`slots5`)을 샀다(`ProUpgrade.isEligible`).
    static func state(of plan: PaywallPlan,
                      purchased: AccessTier,
                      hasPermanentPro: Bool,
                      upgradeEligible: Bool) -> PaywallPlanState {
        let hasPro = hasPermanentPro || purchased >= .pro
        switch plan {
        case .plus:
            if hasPro { return .included }
            return purchased >= .plus ? .owned : .buy
        case .pro:
            if hasPro { return .owned }
            // ⚠️ 업그레이드 값은 Plus **평생**에 이미 낸 사람에게만. Plus 연 구독 · 칸 팩에 낸 사람이나
            //    아무것도 안 산 사람에게 보이면 정가보다 싼 값으로 Pro 평생을 사는 뒷문이 된다.
            return upgradeEligible ? .upgrade : .buy
        }
    }

    /// 이 칸에서 이 길(연 구독 · 평생)을 고르면 결제할 상품. 살 수 없는 칸이면 nil.
    ///
    /// ⚠️ **카드에 적은 값과 결제하는 상품은 반드시 같다.** 이 표 하나가 그 약속이다.
    static func productID(for plan: PaywallPlan, _ state: PaywallPlanState, term: LeeoPlanTerm) -> String? {
        switch (plan, state, term) {
        case (.plus, .buy, .yearly):     return AccessTier.plusYearlyProductID
        case (.plus, .buy, .lifetime):   return AccessTier.plusProductID
        case (.pro, .buy, .yearly),
             (.pro, .upgrade, .yearly):  return AccessTier.proYearlyProductID
        case (.pro, .buy, .lifetime):    return AccessTier.proProductID
        case (.pro, .upgrade, .lifetime): return AccessTier.plusToProProductID
        default:                         return nil
        }
    }

    /// 처음 골라 둘 길. 올리기는 평생(올리기 값이 그 사람만의 값이다), 나머지는 연 구독
    /// (처음 보는 사람에게 첫 해 할인이 그 자리에 보인다).
    static func initialTerm(_ state: PaywallPlanState) -> LeeoPlanTerm {
        state == .upgrade ? .lifetime : .yearly
    }
}

/// 이 사람의 권한을 **한 번** 읽어 둔 것.
///
/// `ProFeatureManager.purchasedTier` 는 읽을 때마다 App Group 저장소를 열고 거울을 푼다.
/// 페이월이 한 번 그려질 때 칸 상태 · 가격 · 버튼 문구 · 막힘 여부가 저마다 그걸 다시 읽어
/// 열 번 넘게 열었다. 이제 body 머리에서 한 번 읽고 이 값을 돌려쓴다.
struct PaywallAccess: Equatable {
    let hasPermanentPro: Bool
    let plus: PaywallPlanState
    let pro: PaywallPlanState

    init(purchased: AccessTier, hasPermanentPro: Bool, upgradeEligible: Bool) {
        self.hasPermanentPro = hasPermanentPro
        plus = PaywallPlanRules.state(of: .plus, purchased: purchased,
                                      hasPermanentPro: hasPermanentPro, upgradeEligible: upgradeEligible)
        pro = PaywallPlanRules.state(of: .pro, purchased: purchased,
                                     hasPermanentPro: hasPermanentPro, upgradeEligible: upgradeEligible)
    }

    static var current: PaywallAccess {
        PaywallAccess(purchased: ProFeatureManager.purchasedTier,
                      hasPermanentPro: ProFeatureManager.hasPermanentPro,
                      upgradeEligible: ProUpgrade.isEligible)
    }

    subscript(plan: PaywallPlan) -> PaywallPlanState {
        switch plan {
        case .plus: return plus
        case .pro:  return pro
        }
    }
}

// MARK: - 카드

/// 유료 칸 하나. 살 수 있으면 안에 길 고르기와 구매 버튼(`purchase`)을 품는다.
struct PaywallPlanCard<Purchase: View>: View {
    let plan: PaywallPlan
    let state: PaywallPlanState
    let isRecommended: Bool
    @ViewBuilder let purchase: () -> Purchase

    @Environment(\.appTheme) private var theme

    // ⚠️ 글자 · 바탕은 **시스템 색**이다. 페이월의 나머지(머리말 · 체험 버튼)가 시스템 색이라,
    //    테마 색(`theme.surface` · `theme.text`)을 쓰면 다크 모드에서 흰 카드 위에 흰 글자가 된다.
    var body: some View {
        PaywallCardSurface(highlighted: isRecommended && state.isPurchasable) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(plan.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(plan.tagline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    badge
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                PaywallHighlights(lines: plan.highlights)
                if state.isPurchasable { purchase() }
            }
        }
    }

    @ViewBuilder
    private var badge: some View {
        switch state {
        case .owned:
            PaywallTag(text: NSLocalizedString("사용 중", comment: "Paywall plan badge: already owned"), color: .green)
        case .included:
            PaywallTag(text: NSLocalizedString("Pro 에 포함", comment: "Paywall plan badge: included in Pro"), color: .green)
        case .buy, .upgrade:
            if isRecommended {
                PaywallTag(text: NSLocalizedString("추천", comment: "Paywall plan badge: recommended"), color: .orange)
            }
        }
    }
}

/// 무료 칸. 지금 무료로 되는 것을 적는다. 버튼은 없다.
struct PaywallFreeCard: View {
    var body: some View {
        PaywallCardSurface(highlighted: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(NSLocalizedString("무료", comment: "Free"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(NSLocalizedString("지금 그대로", comment: "Paywall plan tagline: Free, keep using it as it is now"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                PaywallHighlights(lines: Self.highlights)
            }
        }
    }

    /// 숫자는 `ProFeatureManager` 의 한도에서 읽는다(여기 따로 적지 않는다).
    static var highlights: [String] {
        [
            NSLocalizedString("키보드에서 단축어 넣기", comment: "Paywall Free highlight: insert snippets from the keyboard"),
            String(format: NSLocalizedString("단축어 %1$d개 · 템플릿 %2$d개", comment: "Paywall Free highlight: free snippet and template counts"),
                   ProFeatureManager.freeMemoLimit, ProFeatureManager.freeTemplateLimit),
            String(format: NSLocalizedString("클립보드 기록 %d개", comment: "Paywall highlight: clipboard history count"),
                   ProFeatureManager.freeClipboardHistoryLimit)
        ]
    }
}

// MARK: - 카드 부품

private struct PaywallCardSurface<Content: View>: View {
    let highlighted: Bool
    @ViewBuilder let content: () -> Content
    @Environment(\.appTheme) private var theme

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                    .stroke(highlighted ? Color.orange : Color(uiColor: .separator), lineWidth: highlighted ? 2 : 1)
            )
    }
}

private struct PaywallHighlights: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(lines, id: \.self) { line in
                Label {
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: AppSymbol.checkmark)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.orange)
                }
            }
        }
    }
}

private struct PaywallTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
    }
}

// MARK: - 비교표

/// 무료 · Plus · Pro 세 열. 값은 `ProFeatureManager` 의 한도에서 읽는다(여기 숫자를 따로 적지 않는다).
///
/// ⚠️ 칸에는 **글자를 쓰지 않는다**(숫자와 기호만). 열이 좁아 "Unlimited" · "Без ограничений" 같은 말은
///    "Unli…" 로 잘렸고, "%d개" 는 번역이 없는 언어에서 한국어로 나왔다.
struct PaywallComparisonTable: View {
    @Environment(\.appTheme) private var theme

    /// 한 칸의 값.
    enum Cell: Equatable {
        case count(Int)
        case unlimited
        case included
        case excluded
    }

    private struct Row: Identifiable {
        let name: String
        let free: Cell
        let plus: Cell
        let pro: Cell
        var id: String { name }
    }

    private static var rows: [Row] {
        func limit(_ name: String, free: Int, paid: Cell = .unlimited) -> Row {
            Row(name: name, free: .count(free), plus: paid, pro: paid)
        }
        func proOnly(_ name: String) -> Row {
            Row(name: name, free: .excluded, plus: .excluded, pro: .included)
        }
        return [
            limit(NSLocalizedString("단축어 저장", comment: "Memo"), free: ProFeatureManager.freeMemoLimit),
            limit(NSLocalizedString("템플릿", comment: "Template"), free: ProFeatureManager.freeTemplateLimit),
            limit(NSLocalizedString("스택", comment: "Combo"), free: ProFeatureManager.freeStackLimit),
            limit(NSLocalizedString("이미지 단축어", comment: "Image"), free: ProFeatureManager.freeImageMemoLimit),
            limit(NSLocalizedString("클립보드 기록", comment: "Clipboard"),
                  free: ProFeatureManager.freeClipboardHistoryLimit, paid: .count(100)),
            proOnly(NSLocalizedString("iCloud 백업", comment: "iCloud")),
            proOnly(NSLocalizedString("생체인증 잠금", comment: "Biometric")),
            proOnly(NSLocalizedString("기기 간 동기화 (베타)", comment: "Cross-device sync section header"))
        ]
    }

    private let columnWidth: CGFloat = 58

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(NSLocalizedString("기능", comment: "Feature"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                header(NSLocalizedString("무료", comment: "Free"))
                header(PaywallPlan.plus.name)
                header(PaywallPlan.pro.name).foregroundStyle(.orange)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(uiColor: .tertiarySystemBackground))

            ForEach(Self.rows) { row in
                HStack {
                    Text(row.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    cell(row.free, tint: .secondary)
                    cell(row.plus, tint: .primary)
                    cell(row.pro, tint: .orange)
                }
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(
                    format: NSLocalizedString("%1$@, 무료: %2$@, Plus: %3$@, Pro: %4$@",
                                              comment: "Paywall comparison row for VoiceOver: feature, free, Plus, Pro"),
                    row.name, Self.spoken(row.free), Self.spoken(row.plus), Self.spoken(row.pro)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
        .overlay(RoundedRectangle(cornerRadius: theme.radiusMd).stroke(Color(uiColor: .separator), lineWidth: 1))
    }

    /// 열 이름. 세 열을 한 단계 작은 글자로 맞춰 "Bezpłatnie" · "Бесплатно" 도 잘리지 않게 한다.
    /// (더 긴 말만 줄어들면 열마다 글자 크기가 달라 보인다.)
    private func header(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(width: columnWidth)
    }

    @ViewBuilder
    private func cell(_ value: Cell, tint: Color) -> some View {
        Group {
            switch value {
            case .count(let n):
                Text(n, format: .number)
                    .monospacedDigit()
                    .foregroundStyle(tint)
            case .unlimited:
                Image(systemName: AppSymbol.infinity)
                    .fontWeight(.semibold)
                    .foregroundStyle(tint)
            case .included:
                Image(systemName: AppSymbol.checkmark)
                    .fontWeight(.bold)
                    .foregroundStyle(tint)
            case .excluded:
                Image(systemName: AppSymbol.minus)
                    .foregroundStyle(.tertiary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(width: columnWidth)
    }

    static func spoken(_ value: Cell) -> String {
        switch value {
        case .count(let n): return n.formatted()
        case .unlimited:    return NSLocalizedString("무제한", comment: "Unlimited")
        case .included:     return NSLocalizedString("포함", comment: "Feature included")
        case .excluded:     return NSLocalizedString("미포함", comment: "Feature not included")
        }
    }
}
