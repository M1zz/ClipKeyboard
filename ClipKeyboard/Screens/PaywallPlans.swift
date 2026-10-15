//
//  PaywallPlans.swift
//  ClipKeyboard
//
//  페이월의 **세 칸**: 무료 · Plus · Pro (`AccessTier`).
//
//    무료   처음        단축어 10개까지
//    Plus   쌓기        단축어 · 템플릿 · 스택 · 이미지 무제한       (`slots5`)
//    Pro    지키기      Plus 전부 + iCloud 백업 · 생체 잠금 · 동기화(베타)  (`pro`, Plus 에서는 `pro.upgrade`)
//
//  ⚠️ 마스터는 여기 세우지 않는다. 마스터에만 있는 기능이 아직 없고, 상품도 App Store Connect 에 없다.
//     생기면 `PaywallPlan` 에 한 칸을 더한다.
//  ⚠️ 두 대째(`TwoDevicePack`) · 칸 팩(`SlotPack`)은 팔지 않는다. 산 사람의 권한만 남는다.
//     동기화는 아직 베타라 따로 돈을 받을 물건이 아니고, 칸 팩은 Plus 가 대신한다.
//

import SwiftUI
import StoreKit

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
    /// Plus(또는 칸)를 가진 사람이 Pro 로 오른다(`pro.upgrade`).
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
    ///   - upgradeEligible: 칸(예전 `slots5` 포함)을 산 적이 있다(`ProUpgrade.isEligible`).
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
            // ⚠️ 업그레이드 값은 Plus(또는 칸)에 **이미 낸 사람**에게만. 아무것도 안 산 사람에게 보이면
            //    정가보다 싼 값으로 Pro 를 사는 뒷문이 된다.
            return (purchased >= .plus || upgradeEligible) ? .upgrade : .buy
        }
    }

    /// 처음 골라 둘 칸. 살 수 있는 칸 중 **위의 것**.
    /// 둘 다 못 사면(이미 Pro) nil.
    static func initialSelection(purchased: AccessTier,
                                 hasPermanentPro: Bool,
                                 upgradeEligible: Bool) -> PaywallPlan? {
        PaywallPlan.allCases.reversed().first {
            state(of: $0, purchased: purchased, hasPermanentPro: hasPermanentPro,
                  upgradeEligible: upgradeEligible).isPurchasable
        }
    }
}

// MARK: - 카드

/// 칸 하나. 누르면 고른다. 고른 칸은 강조색 테두리.
struct PaywallPlanCard: View {
    let plan: PaywallPlan
    let state: PaywallPlanState
    /// 이 사람이 낼 값(업그레이드면 업그레이드 값). 상품을 아직 못 읽었으면 nil.
    let price: String?
    let isSelected: Bool
    let isRecommended: Bool
    let onSelect: () -> Void

    @Environment(\.appTheme) private var theme

    // ⚠️ 글자 · 바탕은 **시스템 색**이다. 페이월의 나머지(머리말 · 체험 버튼)가 시스템 색이라,
    //    테마 색(`theme.surface` · `theme.text`)을 쓰면 다크 모드에서 흰 카드 위에 흰 글자가 된다.
    var body: some View {
        Button(action: onSelect) {
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
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(plan.highlights, id: \.self) { line in
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
                priceLine
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                    .stroke(isSelected ? Color.orange : Color(uiColor: .separator), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.squish)
        .disabled(!state.isPurchasable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var badge: some View {
        switch state {
        case .owned:
            tag(NSLocalizedString("사용 중", comment: "Paywall plan badge: already owned"), color: .green)
        case .included:
            tag(NSLocalizedString("Pro 에 포함", comment: "Paywall plan badge: included in Pro"), color: .green)
        case .buy, .upgrade:
            if isRecommended {
                tag(NSLocalizedString("추천", comment: "Paywall plan badge: recommended"), color: .orange)
            }
        }
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
    }

    @ViewBuilder
    private var priceLine: some View {
        if state.isPurchasable {
            VStack(alignment: .leading, spacing: 2) {
                if let price {
                    Text(price)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                Text(state == .upgrade
                     ? NSLocalizedString("Plus 에서 Pro 로 오르는 값 · 한 번 결제", comment: "Paywall price caption: upgrade from Plus")
                     : NSLocalizedString("한 번 결제 · 평생 사용", comment: "Paywall price caption: one-time"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 비교표

/// 무료 · Plus · Pro 세 열. 값은 `ProFeatureManager` 의 한도에서 읽는다(여기 숫자를 따로 적지 않는다).
struct PaywallComparisonTable: View {
    @Environment(\.appTheme) private var theme

    private struct Row: Identifiable {
        let name: String
        let free: String
        let plus: String
        let pro: String
        var id: String { name }
    }

    private static let check = "✓"
    private static let none = "-"

    private var rows: [Row] {
        let unlimited = NSLocalizedString("무제한", comment: "Unlimited")
        func count(_ n: Int) -> String { String(format: NSLocalizedString("%d개", comment: "count unit"), n) }
        return [
            Row(name: NSLocalizedString("단축어 저장", comment: "Memo"),
                free: count(ProFeatureManager.freeMemoLimit), plus: unlimited, pro: unlimited),
            Row(name: NSLocalizedString("템플릿", comment: "Template"),
                free: count(ProFeatureManager.freeTemplateLimit), plus: unlimited, pro: unlimited),
            Row(name: NSLocalizedString("스택", comment: "Combo"),
                free: count(ProFeatureManager.freeStackLimit), plus: unlimited, pro: unlimited),
            Row(name: NSLocalizedString("이미지 단축어", comment: "Image"),
                free: count(ProFeatureManager.freeImageMemoLimit), plus: unlimited, pro: unlimited),
            Row(name: NSLocalizedString("클립보드 기록", comment: "Clipboard"),
                free: count(ProFeatureManager.freeClipboardHistoryLimit), plus: count(100), pro: count(100)),
            Row(name: NSLocalizedString("iCloud 백업", comment: "iCloud"),
                free: Self.none, plus: Self.none, pro: Self.check),
            Row(name: NSLocalizedString("생체인증 잠금", comment: "Biometric"),
                free: Self.none, plus: Self.none, pro: Self.check),
            Row(name: NSLocalizedString("기기 간 동기화 (베타)", comment: "Cross-device sync section header"),
                free: Self.none, plus: Self.none, pro: Self.check)
        ]
    }

    private let columnWidth: CGFloat = 58

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(NSLocalizedString("기능", comment: "Feature"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(NSLocalizedString("무료", comment: "Free"))
                    .frame(width: columnWidth)
                Text(PaywallPlan.plus.name)
                    .frame(width: columnWidth)
                Text(PaywallPlan.pro.name)
                    .foregroundStyle(.orange)
                    .frame(width: columnWidth)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(uiColor: .tertiarySystemBackground))

            ForEach(rows) { row in
                HStack {
                    Text(row.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    cell(row.free, muted: true)
                    cell(row.plus, muted: false)
                    cell(row.pro, muted: false, accent: true)
                }
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(
                    format: NSLocalizedString("%1$@, 무료: %2$@, Plus: %3$@, Pro: %4$@",
                                              comment: "Paywall comparison row for VoiceOver: feature, free, Plus, Pro"),
                    row.name, spoken(row.free), spoken(row.plus), spoken(row.pro)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
        .overlay(RoundedRectangle(cornerRadius: theme.radiusMd).stroke(Color(uiColor: .separator), lineWidth: 1))
    }

    private func cell(_ value: String, muted: Bool, accent: Bool = false) -> some View {
        Text(value)
            .fontWeight(accent ? .semibold : .regular)
            .foregroundStyle(accent ? Color.orange : (muted || value == Self.none ? Color.secondary : Color.primary))
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .frame(width: columnWidth)
    }

    private func spoken(_ value: String) -> String {
        switch value {
        case Self.none:  return NSLocalizedString("미포함", comment: "Feature not included")
        case Self.check: return NSLocalizedString("포함", comment: "Feature included")
        default:         return value
        }
    }
}
