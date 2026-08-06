//
//  GeodeSkin.swift
//  ClipKeyboard
//
//  **지오드(정동석)** — 세 번 쓸 때마다 돌이 깨지고 보석이 하나 나온다.
//
//  금고와 같은 뼈대를 쓰지만 세는 것이 다르다 — 금고는 **아낀 시간**을, 지오드는 **보석 개수**를 센다.
//
//  ⚠️ 리듬이 값어치다. 누를 때마다 매번 깨졌다 되돌아가면 셋째 날부터는 지루한 반복이 된다.
//     세 번에 한 번이라야 "이번엔 깨진다"는 기대가 생긴다.
//     그래서 단계는 **사용 횟수에서 계산**한다 — 저장하지 않으므로 어긋날 것도 없다.
//
//  ⚠️ 돌은 카드 **구석**에 둔다. 가운데에 크게 놓으면 제목과 내용을 덮는다
//     (금고 동전을 늘어놨다가 글이 안 읽혔던 일과 같은 실수다).
//
//  ⚠️ **그림(GeodeStage1~3)이 지금 없다.** 2026-08-06 에 앱에서 그림·영상을 걷어내면서
//     함께 지웠다. 이 스킨은 `LivingSkin.isEmpty`… 가 아니라 `LivingSkin.isEnabled == false`
//     라서 아무에게도 안 보이므로 지금은 문제가 없지만, 생활 레이어를 다시 켤 생각이라면
//     **그림부터 다시 넣어야 한다.** 안 그러면 돌 자리가 빈칸으로 남는다.
//     (지운 그림은 git 이력에 있다 — `git show HEAD~1:...` 로 꺼낼 수 있다)
//

import SwiftUI

// MARK: - 단계

/// 돌이 깨져 가는 세 단계. 세 번째 다음에는 보석이 나오고 새 돌이 놓인다.
enum GeodeStage: Int, CaseIterable {
    /// 온전한 돌 — 실금 하나에 옅은 빛만.
    case intact = 0
    /// 금이 갈라지며 결정이 드러남.
    case cracked = 1
    /// 부서져 보석이 터져 나오기 직전.
    case broken = 2

    var imageName: String {
        switch self {
        case .intact:  return "GeodeStage1"
        case .cracked: return "GeodeStage2"
        case .broken:  return "GeodeStage3"
        }
    }

    /// 사용 횟수로 지금 단계를 정한다. 3의 배수마다 새 돌로 돌아온다.
    static func current(useCount: Int) -> GeodeStage {
        GeodeStage(rawValue: max(0, useCount) % 3) ?? .intact
    }

    /// 이번 사용으로 보석이 나오는가 — 세 번째 사용마다.
    static func yieldsGem(afterUseCount useCount: Int) -> Bool {
        useCount > 0 && useCount % 3 == 0
    }
}

/// 지금까지 캔 보석 수. 문구별 사용 횟수에서 그대로 나온다 — 따로 저장하지 않는다.
enum GeodeLedger {
    static func gems(from memos: [Memo]) -> Int {
        memos.reduce(0) { $0 + $1.clipCount / 3 }
    }
}

// MARK: - 보석

/// 캐낸 보석 하나. 일러스트와 같은 납작한 결정 모양.
struct GemShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let shoulder = h * 0.32
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addLine(to: CGPoint(x: w, y: shoulder))
        p.addLine(to: CGPoint(x: w * 0.5, y: h))
        p.addLine(to: CGPoint(x: 0, y: shoulder))
        p.closeSubpath()
        return p
    }
}

struct GemView: View {
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            GemShape()
                .fill(LinearGradient(colors: [Color(red: 0.85, green: 0.55, blue: 1.0),
                                              Color(red: 0.55, green: 0.24, blue: 0.85)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            // 결정면 하이라이트 — 한 면만 밝아야 유리처럼 보인다.
            GemShape()
                .fill(Color.white.opacity(0.55))
                .scaleEffect(x: 0.34, y: 0.62, anchor: .top)
                .offset(x: -size * 0.13, y: size * 0.06)
            GemShape()
                .strokeBorder(Color(red: 0.32, green: 0.12, blue: 0.5).opacity(0.9), lineWidth: 1.2)
        }
        .frame(width: size, height: size * 1.25)
        .shadow(color: Color(red: 0.7, green: 0.3, blue: 1.0).opacity(0.6), radius: 5)
    }
}

private extension GemShape {
    func strokeBorder(_ color: Color, lineWidth: CGFloat) -> some View {
        self.stroke(color, lineWidth: lineWidth)
    }
}

// MARK: - 카드 위의 돌

/// 단축어 카드 구석에 놓이는 지오드. 쓸수록 금이 가고, 세 번째에 터진다.
struct GeodeBadge: View {
    let useCount: Int
    /// 방금 터졌는가 — 터지는 순간 한 번 크게 부풀었다 가라앉는다.
    var bursting: Bool = false
    var size: CGFloat = 40

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var stage: GeodeStage {
        // 터지는 중에는 **부서진 모습**을 보여준다. 다음 단계(온전한 돌)로 곧장 넘어가면
        // 무엇이 나왔는지 못 보고 지나간다.
        bursting ? .broken : GeodeStage.current(useCount: useCount)
    }

    var body: some View {
        Image(stage.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(bursting && !reduceMotion ? 1.35 : 1)
            .shadow(color: Color(red: 0.6, green: 0.25, blue: 0.95)
                        .opacity(stage == .intact ? 0.15 : 0.45),
                    radius: stage == .broken ? 10 : 5)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.5),
                       value: bursting)
            .accessibilityHidden(true)
    }
}
