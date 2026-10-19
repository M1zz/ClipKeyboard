//
//  TipAskBanner.swift
//  ClipKeyboard
//
//  "계속 만들 수 있게 힘을 보태 주세요" 카드. 목록 위(`topBanners`)에 선다.
//
//  누구에게: **이미 Pro 를 다 가진 사람**에게만. 무료 · Plus 사용자에게는 업그레이드가 맞는 길이라
//  팁을 묻지 않는다(파는 말 둘이 겹치면 둘 다 약해진다).
//  언제: 이 앱이 그 사람에게 도움이 됐다는 것이 숫자로 보이는 순간(`TipAskMoments`).
//  얼마나 드물게: LeeoKit 의 규칙(`LeeoTipAskPolicy`). 물으면 60일 쉬고, 낸 사람은 180일, '다음에' 세 번이면 끝.
//
//  ⚠️ 목록은 탭마다 머리(`pageHeader`)가 따로 있어서 이 컨테이너가 여러 개 산다.
//     보여 줄 카드는 `TipAskCenter` 한 곳에 두고 모두 그것을 본다(한 번 묻고, 한 번 닫는다).
//

import SwiftUI
import LeeoKit

// MARK: - 순간 (순수)

enum TipAskMoments {
    /// 아낀 시간(시간). 큰 것부터.
    static let savedHours = [20, 5, 1]
    /// 키보드에서 꺼내 쓴 횟수. 큰 것부터.
    static let pastes = [2000, 500, 100]

    /// 넘어선 순간, **인상적인 것부터**. 아낀 시간이 앞이다(사람이 얻은 것이 가장 분명하다).
    static func reached(timeSavedSeconds: Double, pasteCount: Int) -> [LeeoTipMoment] {
        let hours = Int(timeSavedSeconds / 3600)
        let saved = savedHours.filter { hours >= $0 }.map { threshold in
            LeeoTipMoment(id: "saved.\(threshold)h",
                          message: String(format: NSLocalizedString("클립키보드로 벌써 %d시간을 아꼈어요",
                                                                    comment: "Tip ask card: hours saved so far. %d is hours"), hours))
        }
        let used = pastes.filter { pasteCount >= $0 }.map { threshold in
            LeeoTipMoment(id: "paste.\(threshold)",
                          message: String(format: NSLocalizedString("키보드에서 단축어를 %d번 꺼내 쓰셨어요",
                                                                    comment: "Tip ask card: how many times snippets were used from the keyboard"), pasteCount))
        }
        return saved + used
    }

    static var reachedNow: [LeeoTipMoment] {
        reached(timeSavedSeconds: KeyboardUsageTracker.totalTimeSavedSeconds(),
                pasteCount: AppGroup.defaults?.integer(forKey: DefaultsKey.keyboardPasteCount) ?? 0)
    }
}

// MARK: - 한 곳

@MainActor
final class TipAskCenter: ObservableObject {
    static let shared = TipAskCenter()
    @Published private(set) var moment: LeeoTipMoment?
    /// 물을 거리를 정할 때 닿아 있던 순간들. 카드가 실제로 섰을 때 물은 것으로 적는다.
    private var reachedAtEvaluate: [LeeoTipMoment] = []

    private init() {}

    /// 물을 때인지 본다. 이미 카드가 서 있으면 그대로 둔다.
    ///
    /// ⚠️ 여기서 물은 것으로 적지 않는다. 카드가 설지는 `PromptBoard` 가 고르므로,
    ///    다른 말에 자리를 내줬는데 물은 것으로 적히면 그 순간이 조용히 사라진다.
    func evaluate() {
        guard moment == nil, ProFeatureManager.hasPermanentPro,
              let tipJar = StoreManager.shared.tipJar else { return }
        let reached = TipAskMoments.reachedNow
        guard let next = tipJar.momentToAsk(from: reached) else { return }
        reachedAtEvaluate = reached
        moment = next
        print("💛 [TipAskCenter.evaluate] 팁 부탁 거리: \(next.id)")
    }

    /// 카드가 실제로 섰다. 이때 물은 것으로 적는다.
    func markShown() {
        guard moment != nil, !reachedAtEvaluate.isEmpty,
              let tipJar = StoreManager.shared.tipJar else { return }
        tipJar.markAsked(covering: reachedAtEvaluate)
        reachedAtEvaluate = []
    }

    func close() { moment = nil }
}

// MARK: - 카드

struct TipAskBannerContainer: View {
    @ObservedObject private var center = TipAskCenter.shared
    @ObservedObject private var store = StoreManager.shared
    @Environment(\.appTheme) private var theme
    @State private var showTipJar = false

    var body: some View {
        PromptRow(.tipAsk, wants: center.moment != nil && store.tipJar != nil) {
            if let moment = center.moment, let tipJar = store.tipJar {
                LeeoTipAskCard(tipJar: tipJar, moment: moment,
                               onSupport: {
                                   HapticManager.shared.light()
                                   showTipJar = true
                                   center.close()
                               },
                               onLater: { center.close() })
                    .leeoStyle(theme.leeoStyle)
                    .onAppear { center.markShown() }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }
        }
        .onAppear { center.evaluate() }
        // 팁 상품은 앱이 뜬 뒤에 온다. 오면 다시 본다.
        .onChange(of: store.tipJar?.isAvailable ?? false) { _, _ in center.evaluate() }
        .sheet(isPresented: $showTipJar) {
            if let tipJar = store.tipJar {
                NavigationStack {
                    LeeoTipJarView<ClipKeyboardSpec>(tipJar: tipJar)
                        .leeoStyle(theme.leeoStyle)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                GlassCircleButton(AppSymbol.xmark, role: .secondary,
                                                  label: NSLocalizedString("닫기", comment: "Close / dismiss")) {
                                    showTipJar = false
                                }
                            }
                            .sharedBackgroundVisibility(.hidden)
                        }
                }
            }
        }
    }
}
