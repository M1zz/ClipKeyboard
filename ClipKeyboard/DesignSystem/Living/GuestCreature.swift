//
//  GuestCreature.swift
//  ClipKeyboard
//
//  가끔 찾아오는 손님 - 새와 고양이.
//
//  ⚠️ **상시로 돌아다니지 않는다.** 원래 아이디어는 고양이가 계속 폴짝거리는 것이었지만,
//     하루에 수십 번 여는 도구에서 무언가 늘 움직이면 셋째 날부터는 귀여움이 아니라
//     소음이 된다. 그래서 둘 다 **어쩌다 마주치는 손님**으로 만든다
//     한참 있다 한 번 와서 잠깐 머물고 간다. 반가움은 희소성에서 나온다.
//
//  ⚠️ 격자 전체를 가로지르지 않고 **카드 한 장 위에서** 벌어진다.
//     카드 격자는 스크롤되고 개수가 바뀌고 재정렬돼서, 전역 경로를 계산하면 발판이
//     사라진 자리로 뛰어내리는 사고가 난다. 호스트 카드를 하나 정하고 그 위에서만 논다.
//
//  ⚠️ 저전력 모드·동작 줄이기에서는 아예 나타나지 않는다(스케줄러가 멈춘다).
//

import SwiftUI

// MARK: - 방문 스케줄러

/// 어느 카드에 손님이 와 있는지 관리한다.
/// 리스트가 하나만 들고 있고, 카드들은 "내가 호스트인가"만 본다.
@MainActor
final class GuestScheduler: ObservableObject {

    /// 지금 손님이 앉아 있는 카드. nil이면 아무도 없다.
    @Published private(set) var hostId: UUID?

    private var timer: Timer?
    private var skin: LivingSkin = .none

    /// 스킨이 바뀌거나 화면이 나타날 때 호출. 조건이 안 맞으면 조용히 멈춘다.
    func start(skin: LivingSkin, candidates: @escaping () -> [UUID], reduceMotion: Bool) {
        stop()
        self.skin = skin

        guard skin.isVisitor,
              Delight.isEnabled,
              !reduceMotion,
              !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }

        // 화면을 열자마자 오면 우연이 아니라 연출로 읽힌다 - 첫 방문도 한 박자 뒤에.
        schedule(after: skin.visitInterval * 0.35, candidates: candidates)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        hostId = nil
    }

    private func schedule(after delay: TimeInterval, candidates: @escaping () -> [UUID]) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.visit(candidates: candidates) }
        }
    }

    private func visit(candidates: @escaping () -> [UUID]) {
        let ids = candidates()
        guard !ids.isEmpty else {
            schedule(after: skin.visitInterval, candidates: candidates)
            return
        }

        hostId = ids.randomElement()

        // 머물다 떠난 뒤 다음 방문을 예약.
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: skin.visitDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.hostId = nil
                self.schedule(after: self.skin.visitInterval, candidates: candidates)
            }
        }
    }

    deinit { timer?.invalidate() }
}

// MARK: - 손님 뷰

/// 카드 위에 나타나는 손님. `kind` 에 따라 새/고양이로 그려진다.
struct GuestCreature: View {
    let kind: LivingSkin
    /// 카드 너비 - 착지 지점을 정하는 데 쓴다.
    let cardWidth: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .arriving

    private enum Phase { case arriving, staying, leaving }

    private var size: CGFloat { kind == .cat ? 26 : 16 }

    var body: some View {
        Group {
            if kind == .cat { CatShape() } else { BirdShape() }
        }
        .frame(width: size * (kind == .cat ? 1.3 : 1.0), height: size)
        .offset(x: offsetX, y: offsetY)
        .opacity(phase == .leaving ? 0 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { animateIn() }
    }

    // 도착 전에는 카드 밖(왼쪽 위), 머무는 동안 카드 윗변, 떠날 때 오른쪽 위로.
    private var offsetX: CGFloat {
        switch phase {
        case .arriving: return -cardWidth * 0.55
        case .staying:  return cardWidth * 0.16
        case .leaving:  return cardWidth * 0.75
        }
    }

    private var offsetY: CGFloat {
        switch phase {
        case .arriving: return -34
        case .staying:  return 0
        case .leaving:  return -40
        }
    }

    private func animateIn() {
        guard !reduceMotion else { phase = .staying; return }

        withAnimation(.easeOut(duration: 0.9)) { phase = .staying }

        let stay = kind.visitDuration - 1.6
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.6, stay)) {
            withAnimation(.easeIn(duration: 0.7)) { phase = .leaving }
        }
    }
}

// MARK: - 실루엣

/// 새 - 몸통 하나와 날개 한 장으로 읽히는 최소 형태.
private struct BirdShape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            var body = Path()
            body.move(to: CGPoint(x: w * 0.12, y: h * 0.62))
            body.addQuadCurve(to: CGPoint(x: w * 0.88, y: h * 0.40),
                              control: CGPoint(x: w * 0.48, y: h * 0.08))
            body.addQuadCurve(to: CGPoint(x: w * 0.48, y: h * 0.70),
                              control: CGPoint(x: w * 0.62, y: h * 0.52))
            body.addQuadCurve(to: CGPoint(x: w * 0.12, y: h * 0.62),
                              control: CGPoint(x: w * 0.30, y: h * 0.86))
            context.fill(body, with: .color(Color(red: 0.26, green: 0.24, blue: 0.28)))

            // 부리
            var beak = Path()
            beak.move(to: CGPoint(x: w * 0.86, y: h * 0.40))
            beak.addLine(to: CGPoint(x: w, y: h * 0.47))
            beak.addLine(to: CGPoint(x: w * 0.84, y: h * 0.50))
            beak.closeSubpath()
            context.fill(beak, with: .color(Color(red: 0.90, green: 0.66, blue: 0.24)))
        }
        .allowsHitTesting(false)
    }
}

/// 고양이 - 귀 둘, 몸통, 꼬리. 옆모습 실루엣.
private struct CatShape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let ink = Color(red: 0.24, green: 0.22, blue: 0.26)

            // 귀
            var ears = Path()
            ears.move(to: CGPoint(x: w * 0.10, y: h * 0.42))
            ears.addLine(to: CGPoint(x: w * 0.17, y: h * 0.08))
            ears.addLine(to: CGPoint(x: w * 0.27, y: h * 0.42))
            ears.closeSubpath()
            ears.move(to: CGPoint(x: w * 0.30, y: h * 0.42))
            ears.addLine(to: CGPoint(x: w * 0.38, y: h * 0.08))
            ears.addLine(to: CGPoint(x: w * 0.46, y: h * 0.42))
            ears.closeSubpath()
            context.fill(ears, with: .color(ink))

            // 머리 + 몸통
            context.fill(Path(ellipseIn: CGRect(x: w * 0.06, y: h * 0.30,
                                                width: w * 0.44, height: h * 0.58)),
                         with: .color(ink))
            context.fill(Path(ellipseIn: CGRect(x: w * 0.36, y: h * 0.44,
                                                width: w * 0.50, height: h * 0.48)),
                         with: .color(ink))

            // 꼬리
            var tail = Path()
            tail.move(to: CGPoint(x: w * 0.83, y: h * 0.72))
            tail.addQuadCurve(to: CGPoint(x: w * 0.97, y: h * 0.22),
                              control: CGPoint(x: w * 1.05, y: h * 0.58))
            context.stroke(tail, with: .color(ink),
                           style: StrokeStyle(lineWidth: max(1.4, w * 0.07), lineCap: .round))
        }
        .allowsHitTesting(false)
    }
}
