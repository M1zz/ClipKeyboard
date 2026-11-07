//
//  PaywallPlans.swift
//  ClipKeyboard
//
//  페이월의 **세 칸**: 무료 · Plus · Pro (`AccessTier`). 유료 칸마다 월 구독 · 연 구독 · 평생을 나란히 판다.
//
//    무료   지금 그대로  단축어 · 템플릿 몇 개, 클립보드 기록 50개
//    Plus   쌓기        단축어 · 템플릿 · 스택 · 이미지 무제한       (`plus.monthly` · `plus.yearly` · 평생 `slots5`)
//    Pro    지키기      Plus 전부 + iCloud 백업 · 생체 잠금 · 동기화(베타)
//                       (`pro.monthly` · `pro.yearly` · 평생 `pro`, Plus 평생을 산 사람의 평생은 `pro.upgrade`)
//
//  화면 틀은 `PaywallTemplate`(PaywallLadder.swift)이 그린다. 여기는 칸의 규칙과 비교표다.
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

// MARK: - 길

/// 칸 하나를 사는 세 가지 길.
///
/// ⚠️ LeeoKit 의 `LeeoPlanTerm`(연 · 평생 둘)을 넓히지 않고 여기 따로 둔다. 그 enum 을 switch 하는
///    다른 앱 네 개가 LeeoKit 을 올리는 순간 깨지기 때문이다. 월 구독은 이 앱만 판다(2026-11).
enum PaywallTerm: String, CaseIterable {
    case monthly, yearly, lifetime
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

    /// 이 칸에서 이 길(월 · 연 구독 · 평생)을 고르면 결제할 상품. 살 수 없는 칸이면 nil.
    ///
    /// ⚠️ **카드에 적은 값과 결제하는 상품은 반드시 같다.** 이 표 하나가 그 약속이다.
    static func productID(for plan: PaywallPlan, _ state: PaywallPlanState, term: PaywallTerm) -> String? {
        switch (plan, state, term) {
        case (.plus, .buy, .monthly):    return AccessTier.plusMonthlyProductID
        case (.plus, .buy, .yearly):     return AccessTier.plusYearlyProductID
        case (.plus, .buy, .lifetime):   return AccessTier.plusProductID
        case (.pro, .buy, .monthly),
             (.pro, .upgrade, .monthly): return AccessTier.proMonthlyProductID
        case (.pro, .buy, .yearly),
             (.pro, .upgrade, .yearly):  return AccessTier.proYearlyProductID
        case (.pro, .buy, .lifetime):    return AccessTier.proProductID
        case (.pro, .upgrade, .lifetime): return AccessTier.plusToProProductID
        default:                         return nil
        }
    }

    /// 처음 골라 둘 길. 올리기는 평생(올리기 값이 그 사람만의 값이다), 나머지는 연 구독
    /// (처음 보는 사람에게 첫 해 할인이 그 자리에 보인다). 월은 고르는 사람만 고른다.
    static func initialTerm(_ state: PaywallPlanState) -> PaywallTerm {
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
                header(PaywallPlan.pro.name).foregroundStyle(theme.accent)
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
                    cell(row.pro, tint: theme.accent)
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

// MARK: - 그림 장 (LeeoKit `LeeoShowcase`)

/// 페이월에서 옆으로 넘겨 보는 장 - 그 기능이 적용된 화면을 SwiftUI 로 줄여 그린다.
/// 스크린샷이 아니라 그림이라 언어 · 다크 모드 · 키 색을 따라가고 앱 용량이 늘지 않는다.
/// ⚠️ 그림 속 글자는 꼭 필요한 것만(숫자 · 기호). 문장은 그림 아래 한 줄 설명이 맡는다.
extension PaywallPlan {
    var showcases: [LeeoShowcase] {
        switch self {
        case .plus:
            return [
                LeeoShowcase(id: "snippets", title: highlights[0],
                             detail: NSLocalizedString("자주 쓰는 글을 칸 걱정 없이 얼마든지 담아요", comment: "Paywall showcase detail: unlimited snippets")) { SnippetsArt() },
                LeeoShowcase(id: "stacks", title: highlights[1],
                             detail: NSLocalizedString("여러 값을 묶은 스택과 이미지도 마음껏 만들어요", comment: "Paywall showcase detail: unlimited stacks and images")) { StacksArt() },
                LeeoShowcase(id: "history", title: highlights[2],
                             detail: NSLocalizedString("복사한 것을 100개까지 기억해 두었다가 다시 붙여요", comment: "Paywall showcase detail: clipboard history 100")) { HistoryArt() },
            ]
        case .pro:
            return [
                LeeoShowcase(id: "backup", title: highlights[1],
                             detail: NSLocalizedString("쌓은 단축어를 iCloud 에 백업하고 Face ID 로 잠가요", comment: "Paywall showcase detail: iCloud backup and biometric lock")) { BackupLockArt() },
                LeeoShowcase(id: "sync", title: highlights[2],
                             detail: NSLocalizedString("아이폰 · 아이패드 · Mac 에서 같은 단축어를 써요", comment: "Paywall showcase detail: cross-device sync")) { SyncArt() },
                LeeoShowcase(id: "plus", title: highlights[0],
                             detail: NSLocalizedString("Plus 에서 열리는 것을 모두 그대로 써요", comment: "Paywall showcase detail: everything in Plus")) { EverythingInPlusArt() },
            ]
        }
    }
}

/// 그림 속 단축어 한 줄 - 기호와 글자 자리(막대)
private struct ArtSnippetRow: View {
    let symbol: String
    let width: CGFloat
    @Environment(\.appTheme) private var theme
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 30, height: 30)
                .background(theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Capsule().fill(Color.primary.opacity(0.75)).frame(width: width * 0.45, height: 7)
                Capsule().fill(Color.secondary.opacity(0.35)).frame(width: width, height: 6)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
    }
}

/// 단축어 무제한: 단축어가 줄줄이, 모서리에 ∞
private struct SnippetsArt: View {
    @Environment(\.appTheme) private var theme
    var body: some View {
        VStack(spacing: 8) {
            ArtSnippetRow(symbol: "envelope.fill", width: 150)
            ArtSnippetRow(symbol: "phone.fill", width: 110)
            ArtSnippetRow(symbol: "house.fill", width: 170)
            ArtSnippetRow(symbol: "creditcard.fill", width: 130)
        }
        .padding(16)
        .overlay(alignment: .topTrailing) {
            Image(systemName: "infinity")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(theme.accent, in: Circle())
                .shadow(color: theme.accent.opacity(0.4), radius: 6, y: 2)
                .padding(8)
        }
    }
}

/// 스택 · 이미지: 값 여러 개가 겹친 카드와 사진 단축어
private struct StacksArt: View {
    @Environment(\.appTheme) private var theme
    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                        .frame(width: 120, height: 84)
                        .overlay(alignment: .topLeading) {
                            VStack(alignment: .leading, spacing: 6) {
                                Capsule().fill(Color.primary.opacity(0.7)).frame(width: 60, height: 7)
                                Capsule().fill(Color.secondary.opacity(0.35)).frame(width: 84, height: 6)
                            }
                            .padding(12)
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if i == 2 {
                                Text(verbatim: "1/3")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(theme.accent, in: Capsule())
                                    .padding(8)
                            }
                        }
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                        .offset(x: CGFloat(i - 1) * 8, y: CGFloat(i - 1) * -10)
                }
            }
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [theme.accent.opacity(0.85), .purple.opacity(0.6)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 84, height: 100)
                .overlay {
                    Image(systemName: "photo.fill").font(.title).foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
        .padding(16)
    }
}

/// 클립보드 기록: 복사한 것이 차례로, 위에 100
private struct HistoryArt: View {
    @Environment(\.appTheme) private var theme
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "doc.on.clipboard.fill").foregroundStyle(theme.accent)
                Spacer()
                Text(verbatim: "100").font(.headline.weight(.heavy)).foregroundStyle(theme.accent)
            }
            .padding(.horizontal, 4)
            ForEach([140, 100, 160, 120], id: \.self) { width in
                HStack(spacing: 10) {
                    Image(systemName: "clock").font(.caption).foregroundStyle(.secondary)
                    Capsule().fill(Color.primary.opacity(0.6)).frame(width: CGFloat(width), height: 7)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.uturn.left").font(.caption.weight(.bold)).foregroundStyle(theme.accent)
                }
                .padding(10)
                .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
            }
        }
        .padding(16)
    }
}

/// iCloud 백업 · 생체 잠금: 구름으로 올라가고, 얼굴로 연다
private struct BackupLockArt: View {
    @Environment(\.appTheme) private var theme
    var body: some View {
        HStack(spacing: 22) {
            ZStack {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                Image(systemName: "arrow.up").font(.title2.weight(.heavy)).foregroundStyle(.white).offset(y: 6)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
                    .frame(width: 100, height: 100)
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                Image(systemName: "faceid").font(.system(size: 50)).foregroundStyle(theme.accent)
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "lock.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.green, in: Circle())
                    .offset(x: 8, y: 8)
            }
        }
        .padding(16)
    }
}

/// 기기 간 동기화: 아이폰 · 아이패드 · Mac 이 같은 단축어를
private struct SyncArt: View {
    @Environment(\.appTheme) private var theme
    var body: some View {
        ZStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 120, weight: .ultraLight))
                .foregroundStyle(theme.accent.opacity(0.25))
            HStack(alignment: .bottom, spacing: 18) {
                Image(systemName: "iphone").font(.system(size: 50))
                Image(systemName: "ipad.landscape").font(.system(size: 64))
                Image(systemName: "laptopcomputer").font(.system(size: 70))
            }
            .foregroundStyle(theme.accent)
        }
        .padding(16)
    }
}

/// Plus 의 모든 것: Plus 에서 열리는 셋을 한데
private struct EverythingInPlusArt: View {
    @Environment(\.appTheme) private var theme
    var body: some View {
        VStack(spacing: 14) {
            Text(verbatim: "Plus")
                .font(.headline.weight(.heavy))
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 14).padding(.vertical, 5)
                .background(theme.accent.opacity(0.14), in: Capsule())
            HStack(spacing: 16) {
                ForEach(["text.badge.plus", "square.stack.3d.up.fill", "doc.on.clipboard.fill"], id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.accent)
                        .frame(width: 64, height: 64)
                        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
                }
            }
            Image(systemName: "checkmark.seal.fill").font(.title).foregroundStyle(.green)
        }
        .padding(16)
    }
}
