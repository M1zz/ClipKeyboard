//
//  FootprintTrail.swift
//  ClipKeyboard
//
//  눈 덮인 카드와 그 위에 남는 발자국.
//
//  ⚠️ **눈은 내리지 않는다.** 원래 아이디어는 "눈이 내리는 질감"이었지만, 상시 낙하 애니메이션은
//     배터리를 계속 먹으면서 정작 스크린샷에는 아무것도 안 남긴다. 이 스킨의 값어치는
//     눈이 아니라 **발자국** - 흐르는 것이 아니라 **남는 것**이다.
//     그래서 눈은 정지 질감으로 깔고, 발자국만 사용 기록에 따라 쌓는다.
//     (앞서 만든 날인 자국·픽셀 마을과 같은 성격)
//
//  ⚠️ 발자국 좌표는 **사용 횟수에서 결정적으로 계산**한다. 난수를 쓰면 스크롤할 때마다
//     발자국이 옮겨 다녀서 "지나간 자취"로 안 읽힌다.
//

import SwiftUI

// MARK: - 발자국 배치 (순수 함수 - 테스트 가능)

enum FootprintTrail {

    /// 발자국 하나.
    struct Mark: Equatable, Identifiable {
        /// 카드 안 상대 위치 (0…1).
        let x: Double
        let y: Double
        /// 기울기(도).
        let angle: Double
        let id: Int
    }

    /// 한 카드에 남길 수 있는 최대 발자국. 넘으면 눈밭이 아니라 진창이 된다.
    static let maxMarks = 8

    /// 사용 횟수만큼 **대각선으로 하나씩** 찍는다.
    /// 왼쪽 아래에서 오른쪽 위로 걸어간 자취처럼 보이게 배치한다.
    static func marks(useCount: Int) -> [Mark] {
        guard useCount > 0 else { return [] }
        let count = min(useCount, maxMarks)

        return (0..<count).map { index in
            let t = Double(index) / Double(max(1, maxMarks - 1))
            // 걸음마다 좌우로 살짝 엇갈리게 - 한 줄로 곧게 찍히면 도장 자국처럼 보인다.
            let sway = (index % 2 == 0) ? -0.035 : 0.035
            return Mark(
                x: 0.13 + t * 0.70 + sway,
                y: 0.80 - t * 0.62,
                // 걸어가는 방향으로 기울되 걸음마다 조금씩 다르게(결정적).
                angle: -32 + Double((index * 37) % 24),
                id: index
            )
        }
    }
}

// MARK: - 눈 질감

/// 카드에 깔리는 정지 눈 - 위가 밝고 아래로 갈수록 원래 표면이 비친다.
/// 알갱이는 시드 기반이라 스크롤해도 같은 자리에 있다.
struct SnowTexture: View {
    /// 카드마다 다른 알갱이 배치를 위한 시드(메모 id 해시).
    let seed: Int

    private static let grainCount = 10

    var body: some View {
        Canvas { context, size in
            // 위에서 아래로 옅어지는 눈층
            let veil = Path(CGRect(origin: .zero, size: size))
            context.fill(veil, with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.86, green: 0.90, blue: 0.95).opacity(0.55),
                    Color(red: 0.86, green: 0.90, blue: 0.95).opacity(0.0)
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            ))

            // 알갱이 - 결정적 난수(시드)로 흩뿌린다.
            var state = UInt64(bitPattern: Int64(seed)) | 1
            for _ in 0..<Self.grainCount {
                let px = Double(next(&state) % 1000) / 1000.0
                let py = Double(next(&state) % 1000) / 1000.0
                let r = 1.0 + Double(next(&state) % 12) / 10.0
                let dot = Path(ellipseIn: CGRect(x: px * size.width,
                                                 y: py * size.height * 0.9,
                                                 width: r, height: r))
                context.fill(dot, with: .color(.white.opacity(0.75)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// xorshift - Foundation 난수와 달리 시드를 넣으면 항상 같은 수열이 나온다.
    private func next(_ state: inout UInt64) -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - 발자국 레이어

struct FootprintLayer: View {
    let useCount: Int
    /// 발자국 하나의 크기(pt).
    var size: CGFloat = 9

    var body: some View {
        GeometryReader { geo in
            ForEach(FootprintTrail.marks(useCount: useCount)) { mark in
                PawShape()
                    .fill(Color(red: 0.42, green: 0.47, blue: 0.55).opacity(0.42))
                    .frame(width: size * 0.78, height: size)
                    .rotationEffect(.degrees(mark.angle))
                    .position(x: geo.size.width * mark.x,
                              y: geo.size.height * mark.y)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 발바닥 - 패드 하나와 발가락 셋.
private struct PawShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height

        // 발바닥
        path.addEllipse(in: CGRect(x: w * 0.14, y: h * 0.42, width: w * 0.72, height: h * 0.52))
        // 발가락 셋
        let toe = CGSize(width: w * 0.30, height: h * 0.28)
        path.addEllipse(in: CGRect(x: 0, y: h * 0.16, width: toe.width, height: toe.height))
        path.addEllipse(in: CGRect(x: w * 0.35, y: 0, width: toe.width, height: toe.height))
        path.addEllipse(in: CGRect(x: w * 0.70, y: h * 0.16, width: toe.width, height: toe.height))
        return path
    }
}
