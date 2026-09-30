//
//  FreeUseScreens.swift
//  ClipKeyboard
//
//  무료로 쓰는 기간(`FreeUse`)을 사용자에게 알리는 화면들.
//
//   - 이정표 카드: 50% 에서 받은 것을, 80% 에서 문턱 뒤에도 **그대로인 것**을 먼저 말한다
//   - 안내 화면: 어떻게 운영되는지 한 장으로. 설정과 카드에서 연다. 첫날에도 열 수 있다
//   - 문턱에서 뜨는 결제 화면은 `FreeUsePaywallView`
//
//  ⚠️ 모든 안내는 닫을 수 있고, 이정표마다 한 번만 뜬다. 키보드에서 넣는 일을 가로막지 않는다.
//  ⚠️ "체험" 이라는 말을 쓰지 않는다. 애플 심사 기준(3.1.1)에서 체험은 **기간**으로 끝나는 것이고,
//     이건 쓴 횟수로 끝나는 무료 사용이다.
//

import SwiftUI

// MARK: - 지금 보여 줄 것

/// 이정표 카드와 문턱 화면을 **한 곳에서** 정한다. 목록의 여러 페이지가 같은 카드를 띄우므로
/// 한쪽에서 닫으면 다른 쪽도 같이 닫혀야 한다.
@MainActor
final class FreeUseMoments: ObservableObject {
    static let shared = FreeUseMoments()

    /// 목록 위에 띄울 카드(50 · 80). 문턱(100)은 카드가 아니라 화면이다.
    @Published private(set) var card: FreeUse.Milestone?
    /// 문턱 화면을 띄울 차례인가.
    @Published var showsReceipt = false

    private init() {}

    /// - Parameter presentReceipt: 문턱 화면까지 띄워도 되는 때인가. 앱을 열었을 때만 띄운다.
    ///   앱 안에서 복사하다가 문턱을 넘은 순간에 화면이 덮치면 하던 일이 끊긴다.
    func refresh(presentReceipt: Bool) {
        switch FreeUse.pendingMilestone {
        case .half?, .nearEnd?:
            card = FreeUse.pendingMilestone
        case .reached?:
            card = nil
            if presentReceipt { showsReceipt = true }
        case nil:
            card = nil
        }
    }

    func dismissCard() {
        if let card { FreeUse.markSeen(card) }
        withAnimation { card = nil }
    }

    /// 문턱 화면이 떴다. 다시 띄우지 않는다(안내 화면의 "Pro 보기" 로는 언제든 다시 연다).
    func receiptShown() {
        FreeUse.markSeen(.reached)
        card = nil
    }
}

// MARK: - 목록 위 카드

/// 목록 맨 위에 서는 이정표 카드. 페이지마다 하나씩 있어도 `FreeUseMoments` 를 같이 본다.
struct FreeUseMilestoneBanner: View {
    @ObservedObject private var moments = FreeUseMoments.shared
    @State private var showsGuide = false

    var body: some View {
        DismissibleRow(isShowing: moments.card != nil) {
            if let milestone = moments.card {
                FreeUseMilestoneCard(
                    milestone: milestone,
                    uses: FreeUse.uses,
                    threshold: FreeUse.threshold,
                    minutesSaved: Int(KeyboardUsageTracker.totalTimeSavedSeconds() / 60),
                    onMore: { showsGuide = true },
                    onDismiss: { moments.dismissCard() }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
        }
        .sheet(isPresented: $showsGuide) {
            FreeUseGuideView()
        }
    }
}

struct FreeUseMilestoneCard: View {
    let milestone: FreeUse.Milestone
    let uses: Int
    let threshold: Int
    let minutesSaved: Int
    let onMore: () -> Void
    let onDismiss: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundColor(theme.text)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .font(.body)
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            FreeUseProgressBar(uses: uses, threshold: threshold)
            if milestone == .nearEnd {
                FreeUseKeepsList()
            } else {
                Text(String(format: NSLocalizedString("%d번까지는 지금처럼 모두 무료예요.", comment: "Free use card: everything stays free until threshold"), threshold))
                    .font(.body)
                    .foregroundColor(theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Button(action: onMore) {
                    Text(milestone == .nearEnd
                         ? NSLocalizedString("무엇이 달라지는지 보기", comment: "Free use card: see what changes")
                         : NSLocalizedString("자세히", comment: "Free use card: more"))
                        .font(.body.weight(.semibold))
                        .frame(minHeight: 44)
                        .padding(.horizontal, 16)
                        .background(milestone == .nearEnd ? theme.accent : theme.accentSoft)
                        .foregroundColor(milestone == .nearEnd ? theme.accentFg : theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
                }
                .buttonStyle(.squish)
                Button(action: onDismiss) {
                    Text(milestone == .nearEnd
                         ? NSLocalizedString("나중에", comment: "Free use card: later")
                         : NSLocalizedString("알겠어요", comment: "Free use card: got it"))
                        .font(.body.weight(.semibold))
                        .frame(minHeight: 44)
                        .padding(.horizontal, 16)
                        .foregroundColor(theme.textMuted)
                }
                .buttonStyle(.squish)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        switch milestone {
        case .nearEnd:
            return String(format: NSLocalizedString("%d번 남았어요", comment: "Free use card: uses remaining"), max(0, threshold - uses))
        default:
            return String(format: NSLocalizedString("단축어를 %d번 썼어요", comment: "Free use card: uses so far"), uses)
        }
    }

    private var detail: String? {
        switch milestone {
        case .nearEnd:
            return String(format: NSLocalizedString("%d번부터는 새로 만들 때 Pro가 필요해요.", comment: "Free use card: after threshold creating needs Pro"), threshold)
        default:
            guard minutesSaved > 0 else { return nil }
            return String(format: NSLocalizedString("직접 쳤다면 약 %d분이 걸렸을 거예요.", comment: "Free use card: minutes saved"), minutesSaved)
        }
    }
}

/// 문턱까지의 막대. VoiceOver 는 "100번 중 50번" 으로 읽는다.
struct FreeUseProgressBar: View {
    let uses: Int
    let threshold: Int
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            ProgressView(value: Double(min(uses, threshold)), total: Double(max(threshold, 1)))
                .tint(theme.accent)
                .scaleEffect(x: 1, y: 2, anchor: .center)
            HStack {
                Text("\(min(uses, threshold))")
                Spacer()
                Text("\(threshold)")
            }
            .font(.body)
            .foregroundColor(theme.textMuted)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: NSLocalizedString("%1$d번 중 %2$d번 썼어요", comment: "Free use progress, VoiceOver"), threshold, min(uses, threshold)))
    }
}

/// 문턱 뒤에도 **그대로인 것.** 무엇이 닫히는지보다 먼저 말한다.
struct FreeUseKeepsList: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            row(NSLocalizedString("만든 단축어는 계속 무료로 넣을 수 있어요", comment: "Free use: made snippets stay usable"))
            row(NSLocalizedString("클립보드 기록도 그대로예요", comment: "Free use: clipboard history stays"))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.success.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
    }

    private func row(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: AppSymbol.checkmark)
                .font(.body.weight(.bold))
                .foregroundColor(theme.success)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .foregroundColor(theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 안내 화면

/// 무료로 쓰는 방식 한 장. 설정의 "무료로 쓰는 중" 과 이정표 카드에서 연다.
///
/// 첫날에도 열 수 있고, 여기서 바로 Pro 를 볼 수 있다. 처음부터 사려는 사람의 마음을
/// 100번 뒤로 미루지 않는다(설치 첫날 결제 의도가 가장 크다).
struct FreeUseGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var showsPlans = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    status
                    VStack(alignment: .leading, spacing: 14) {
                        Text(NSLocalizedString("이렇게 운영해요", comment: "Free use guide: how it works"))
                            .font(.title3.weight(.bold))
                            .foregroundColor(theme.text)
                        point(String(format: NSLocalizedString("단축어를 %d번 넣을 때까지는 모든 기능이 무료예요.", comment: "Free use guide: all free until threshold"), FreeUse.threshold))
                        point(NSLocalizedString("그 뒤에도 만든 단축어는 전부 계속 쓸 수 있어요.", comment: "Free use guide: made snippets keep working"))
                        point(String(format: NSLocalizedString("새로 만들기는 무료로 단축어 %1$d개, 템플릿 %2$d개, 스택 %3$d개, 이미지 단축어 %4$d개까지예요.", comment: "Free use guide: free creation quotas after threshold"),
                                     ProFeatureManager.freeMemoLimit, ProFeatureManager.freeTemplateLimit,
                                     ProFeatureManager.freeStackLimit, ProFeatureManager.freeImageMemoLimit))
                        point(NSLocalizedString("Pro는 개수 제한 없이 만들고, iCloud 백업과 기기 사이 동기화, 생체인증 잠금을 열어요.", comment: "Free use guide: what Pro opens"))
                        point(NSLocalizedString("평생 한 번 결제와 연 구독 중에 고를 수 있어요.", comment: "Free use guide: lifetime or yearly"))
                    }
                    if !ProFeatureManager.hasPermanentPro {
                        Button { showsPlans = true } label: {
                            Text(NSLocalizedString("Pro 보기", comment: "Pro nudge CTA"))
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(theme.accent)
                                .foregroundColor(theme.accentFg)
                                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
                        }
                        .buttonStyle(.squish)
                    }
                }
                .padding(20)
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("무료로 쓰는 방법", comment: "Free use guide title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("닫기", comment: "Close / dismiss")) { dismiss() }
                }
            }
            .sheet(isPresented: $showsPlans) {
                FreeUsePaywallView()
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        VStack(alignment: .leading, spacing: 12) {
            if ProFeatureManager.hasPermanentPro {
                Text(NSLocalizedString("Pro를 쓰고 있어요", comment: "Free use guide: already Pro"))
                    .font(.title2.weight(.bold))
                    .foregroundColor(theme.text)
            } else if FreeUse.isActive {
                Text(String(format: NSLocalizedString("지금은 모든 기능이 무료예요. %d번 남았어요", comment: "Free use guide: active status"), FreeUse.remaining))
                    .font(.title2.weight(.bold))
                    .foregroundColor(theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                FreeUseProgressBar(uses: FreeUse.uses, threshold: FreeUse.threshold)
            } else {
                Text(NSLocalizedString("무료로 모두 쓰는 기간이 끝났어요", comment: "Free use guide: period ended"))
                    .font(.title2.weight(.bold))
                    .foregroundColor(theme.text)
                FreeUseKeepsList()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
    }

    private func point(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(theme.accent)
                .frame(width: 7, height: 7)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .foregroundColor(theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 문턱 화면을 거는 자리

extension View {
    /// 앱을 열 때 문턱에 닿아 있으면 영수증 화면을 한 번 띄운다. 카드도 같은 때 새로 본다.
    func freeUseMoments() -> some View {
        modifier(FreeUseMomentsModifier())
    }
}

private struct FreeUseMomentsModifier: ViewModifier {
    @ObservedObject private var moments = FreeUseMoments.shared

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $moments.showsReceipt) {
                FreeUsePaywallView(isThresholdMoment: true)
            }
            .onAppear { moments.refresh(presentReceipt: true) }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // 키보드에서 쓴 횟수는 다른 프로세스에서 쌓인다. 앱이 앞으로 올 때 다시 본다.
                moments.refresh(presentReceipt: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .memoUsed)) { _ in
                moments.refresh(presentReceipt: false)
            }
    }
}
