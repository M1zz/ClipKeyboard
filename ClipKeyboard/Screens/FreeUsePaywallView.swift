//
//  FreeUsePaywallView.swift
//  ClipKeyboard
//
//  문턱(`FreeUse.threshold`)에 닿았을 때의 결제 화면. **가격보다 영수증이 먼저다.**
//
//  왜 영수증이 먼저인가: 결제할까 망설이는 까닭은 이 앱이 그만한 값을 하는지 확신이 없어서다.
//  100번 넣은 사람에게는 그 증거가 이미 있다. 보여 주기만 하면 된다.
//
//  영수증 아래 요금제는 다른 결제 화면과 같은 사다리다(`PaywallLadder`): 무료 · Plus · Pro 세 칸,
//  칸마다 연 구독과 평생, 그 아래 언제나 평생 패스 한 줄. 갱신 조건과 약관 링크도 사다리가 보인다.
//

import SwiftUI
import StoreKit

struct FreeUsePaywallView: View {
    /// 문턱에 닿아 저절로 뜬 것인가(안내 화면에서 눌러 연 것이 아니라).
    var isThresholdMoment = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @ObservedObject private var store = StoreManager.shared

    @State private var receipt = FreeUseReceipt.current()
    @State private var restoreOutcome: StoreManager.RestoreOutcome?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if receipt.uses > 0 { receiptCard }
                    FreeUseStaysRow(ownCount: receipt.ownCount)
                    PaywallLadder(access: .current,
                                  source: isThresholdMoment ? "free_use_threshold" : "free_use_guide") { _ in
                        dismiss()
                    }
                    footer
                }
                .padding(20)
            }
            .background(theme.surface.ignoresSafeArea())
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
                Text("ClipKeyboard Plus · Pro")
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

    // MARK: - 복원

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                Task { restoreOutcome = await store.restorePurchases() }
            } label: {
                Text(NSLocalizedString("이전 구매 복원", comment: "Restore"))
                    .font(.body)
                    .frame(minHeight: 44)
            }
            if let error = store.errorMessage {
                Text(error).font(.body).foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity)
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
            Text(String(format: NSLocalizedString("결제하지 않아도 만든 %d개는 계속 넣을 수 있어요. Plus는 마음껏 새로 만들고, Pro는 백업과 동기화까지 열어요.", comment: "Free use paywall: what stays free, what Plus and Pro add"), ownCount))
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
