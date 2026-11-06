//
//  TipAskBanner.swift
//  ClipKeyboard
//
//  "혼자 만드는 앱이에요, 작은 응원도 큰 힘이 돼요" 창. 목록 화면에서 한 번 띄운다(LeeoKit `.leeoTipAsk`).
//  창 안에서 바로 팁을 내고, '다음에' · '앞으로 이 메시지 보지 않기' 를 고른다.
//
//  누구에게: **이미 Pro 를 다 가진 사람**에게만. 무료 · Plus 사용자에게는 업그레이드가 맞는 길이라
//  팁을 묻지 않는다(파는 말 둘이 겹치면 둘 다 약해진다).
//  언제: 이 앱이 그 사람에게 도움이 됐다는 것이 숫자로 보이는 순간(`TipAskMoments`).
//  얼마나 드물게: LeeoKit 의 규칙(`LeeoTipAskPolicy`). 물으면 60일 쉬고, 낸 사람은 180일, '다음에' 세 번이면 끝,
//  '앞으로 이 메시지 보지 않기' 면 바로 끝. 목록에 2초 머문 뒤에 본다(열자마자 막아서지 않게).
//
//  ⚠️ 목록은 탭마다 머리가 따로 있어 그 안에 두면 여럿이 산다. 창은 목록 화면 맨 바깥 한 곳에만 건다
//     (`ClipKeyboardList.body` 의 `.background(TipAskSheetAnchor())`).
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

// MARK: - 창

/// 창을 띄우는 자리. 팁 상품이 올 때까지는 아무것도 아니다.
struct TipAskSheetAnchor: View {
    @ObservedObject private var store = StoreManager.shared
    @Environment(\.appTheme) private var theme

    var body: some View {
        if let tipJar = store.tipJar {
            Color.clear
                // 한 번 열 때 저절로 뜨는 창은 하나(`LaunchSheetGate`). 띄우기 직전에 자리를 쥔다.
                .leeoTipAsk(tipJar: tipJar, when: ProFeatureManager.hasPermanentPro,
                            canPresent: { LaunchSheetGate.claim("tipAsk") }) { TipAskMoments.reachedNow }
                .leeoStyle(theme.leeoStyle)
        }
    }
}
