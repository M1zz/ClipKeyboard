//
//  FreeUsePaywallView.swift
//  ClipKeyboard
//
//  문턱(`FreeUse.threshold`)에 닿았을 때의 결제 화면. **가격보다 영수증이 먼저다.**
//
//  왜 영수증이 먼저인가: 결제할까 망설이는 까닭은 이 앱이 그만한 값을 하는지 확신이 없어서다.
//  100번 넣은 사람에게는 그 증거가 이미 있다. 보여 주기만 하면 된다.
//
//  영수증 아래는 다른 결제 화면과 같은 템플릿이다(`PaywallTemplate`). 다른 것은 머리말뿐이다.
//

import SwiftUI
import StoreKit

struct FreeUsePaywallView: View {
    /// 문턱에 닿아 저절로 뜬 것인가(안내 화면에서 눌러 연 것이 아니라).
    var isThresholdMoment = false

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = StoreManager.shared

    @State private var receipt = FreeUseReceipt.current()
    /// 샀으면 닫기로 세지 않는다(`PaywallView` 와 같은 규칙).
    @State private var didConvert = false

    /// 허브에 남기는 진입점. 결제 단추를 누른 것(`paywall_cta_tapped`)도 같은 이름으로 남는다.
    static func analyticsSource(isThresholdMoment: Bool) -> String {
        isThresholdMoment ? "free_use_threshold" : "free_use_guide"
    }

    var body: some View {
        NavigationStack {
            PaywallTemplate(access: .current,
                            source: Self.analyticsSource(isThresholdMoment: isThresholdMoment),
                            onPurchased: { _ in
                                didConvert = true
                                dismiss()
                            }) { header }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        GlassCircleButton(AppSymbol.xmark, role: .secondary,
                                          label: NSLocalizedString("닫기", comment: "Close / dismiss")) {
                            dismiss()
                        }
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
        }
        .task { if store.products.isEmpty { await store.loadProducts() } }
        .onAppear {
            receipt = FreeUseReceipt.current()
            if isThresholdMoment { FreeUseMoments.shared.receiptShown() }
            // ⚠️ 이 화면도 결제 화면이다. 예전에는 노출을 남기지 않아, 문턱에서 뜬 영수증과
            //    안내 화면의 "Pro 보기" 가 허브의 "페이월을 봄" 에서 통째로 빠졌다.
            //    결제 단추 누름(`paywall_cta_tapped`)은 남고 본 것은 안 남아 깔때기가 거꾸로 섰다(2026-11-25).
            if !ProFeatureManager.hasPermanentPro {
                AnalyticsService.logPaywallView(triggeredBy: Self.analyticsSource(isThresholdMoment: isThresholdMoment))
            }
        }
        .onDisappear {
            if !didConvert && !ProFeatureManager.hasPermanentPro {
                AnalyticsService.logPaywallDismissed(triggeredBy: Self.analyticsSource(isThresholdMoment: isThresholdMoment))
            }
        }
    }

    // MARK: - 머리말 (영수증)

    /// "지난 23일 동안 단축어를 100번 넣었어요" 와 한 줄. 결제하지 않아도 만든 것은 계속 쓴다는 말을 먼저 한다.
    private var header: some View {
        VStack(spacing: 8) {
            if receipt.uses > 0 {
                Text(String(format: NSLocalizedString("지난 %d일 동안", comment: "Free use paywall: over the last N days"), receipt.days))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(String(format: NSLocalizedString("단축어를 %d번 넣었어요", comment: "Free use paywall: inserted N times"), receipt.uses))
                    .font(.title.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(NSLocalizedString("자주 쓰는 글, 마음껏 담고 지키세요", comment: "Paywall headline: save as many snippets as you like and keep them safe"))
                    .font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(receiptLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// 아낀 시간(있으면)과 "만든 것은 계속 무료" 를 한 줄로.
    private var receiptLine: String {
        let stays = NSLocalizedString("만든 단축어는 결제하지 않아도 계속 써요", comment: "Free use paywall: snippets you made keep working without paying")
        guard receipt.minutesSaved > 0 else { return stays }
        let saved = String(format: NSLocalizedString("약 %d분", comment: "Free use receipt: about N minutes"), receipt.minutesSaved)
        return String(format: NSLocalizedString("%1$@ 아꼈어요 · %2$@", comment: "Free use paywall: time saved, then that made snippets stay free. %1$@ = about N minutes"), saved, stays)
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
