//
//  VaultDeposit.swift
//  ClipKeyboard
//
//  **입금** — 단축어를 누르면 동전이 톡 튀어 금고로 슉 들어간다.
//
//  이 모션이 하는 일은 장식이 아니라 **인과를 보여주는 것**이다. 잔고 숫자만 있으면
//  "저 숫자가 왜 늘었지"를 설명해야 하지만, 동전이 손끝에서 금고로 날아가면 설명이 필요 없다.
//
//  ⚠️ 0.6초짜리 한 번짜리 연출이다. 상시 도는 것이 하나도 없다 —
//     하루에 수십 번 여는 도구에서 뭔가 늘 움직이면 셋째 날부터 소음이 된다.
//
//  ⚠️ '동작 줄이기'·저전력·Delight 끔에서는 **날리지 않는다.** 대신 금고만 한 번 튕긴다.
//     날아가는 것을 못 볼 뿐 입금이 안 된 것처럼 보이면 안 되기 때문이다.
//

import SwiftUI

// MARK: - 조율

/// 어디서 날아와 어디로 들어가는지를 쥐고 있는 것.
///
/// 목록 화면이 소유하고, 카드가 좌표를 주고, 금고 버튼이 목적지를 알려준다.
@MainActor
final class VaultDeposit: ObservableObject {

    /// ⚠️ 좌표는 전부 **global** 로 주고받는다.
    ///
    /// 처음에는 이름 붙인 좌표계(`.named`)를 썼는데, 카드가 ScrollView 안쪽 깊이 있어서
    /// 그 이름이 카드까지 닿지 않았다. 그래서 탭 좌표가 원점 근처로 잡혔고,
    /// **동전이 어느 카드를 눌러도 화면 왼쪽 위에서 날아갔다.**
    /// global 은 계층 구조와 무관하게 언제나 같은 원점을 쓴다.
    /// 화면에 얹을 때만 비행 레이어가 자기 위치를 빼서 지역 좌표로 바꾼다.

    /// 무엇이 날아가는가. 금고는 시간을(동전), 지오드는 보석을 센다.
    enum Payload: Equatable { case coin, gem }

    struct Flight: Identifiable, Equatable {
        let id = UUID()
        /// 손가락이 닿은 자리 — **global 좌표**.
        let from: CGPoint
        /// 이번에 돌려받은 시간(초). 액면가를 정한다 — 큰 문구는 은화가 날아간다.
        let seconds: Double
        var payload: Payload = .coin
    }

    /// 날고 있는 동전들. 연타해도 각각 난다.
    @Published private(set) var flights: [Flight] = []
    /// 금고 버튼의 중심 — **global 좌표**. 목적지.
    @Published var vaultPoint: CGPoint = .zero
    /// 동전이 도착할 때마다 오르는 값 — 금고가 이걸 보고 흔들린다.
    @Published private(set) var arrivals = 0

    /// 한 번에 날 수 있는 동전 수. 연타로 화면이 동전밭이 되지 않게.
    static let maxConcurrent = 6

    /// 동전 하나를 날린다.
    /// - Parameter from: 카드에서 손가락이 닿은 자리. 여기서 톡 튄다.
    func launch(from: CGPoint, seconds: Double, payload: Payload = .coin) {
        // 목적지를 아직 모르면 날릴 수 없다(금고 버튼이 화면에 없는 경우).
        guard vaultPoint != .zero else { return }
        // 동전은 값어치가 있어야 날아간다. 보석은 세 번을 채운 것 자체가 값어치다.
        guard payload == .gem || seconds > 0 else { return }
        guard flights.count < Self.maxConcurrent else { return }
        flights.append(Flight(from: from, seconds: seconds, payload: payload))
    }

    /// 동전이 금고에 닿았다.
    func arrive(_ id: UUID) {
        flights.removeAll { $0.id == id }
        arrivals += 1
    }

    /// 날리지 않고 입금만 알린다(동작 줄이기 등).
    func arriveSilently() { arrivals += 1 }
}

// MARK: - 날아가는 동전

/// 톡 튀어 올랐다가 금고로 슉 빨려 들어가는 동전 한 개.
///
/// `TimelineView(.animation)` 으로 직접 시간을 굴린다 — `withAnimation` 으로는 중간 프레임을
/// 못 보기 때문에 **동전이 구르는 3프레임**을 바꿔 끼울 수 없다. 구르지 않는 동전은
/// 그냥 미끄러지는 원이라 금속으로 안 보인다.
struct FlyingCoin: View {
    let flight: VaultDeposit.Flight
    let to: CGPoint
    let onArrive: () -> Void

    /// 톡 튀어 오르는 시간.
    private let hop: Double = 0.16
    /// 금고까지 날아가는 시간.
    private let fly: Double = 0.44

    @State private var startedAt = Date()

    private var total: Double { hop + fly }

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(startedAt)

            Group {
                if flight.payload == .gem {
                    // 보석은 구르지 않는다 — 결정은 굴러가는 물건이 아니라 반짝이는 물건이다.
                    GemView(size: 24)
                        .rotationEffect(.degrees(Double(elapsed) * 90))
                } else {
                    VaultSpriteStrip(sprites: [spinFrame(at: elapsed)], pixel: 3, gap: 0)
                }
            }
            .scaleEffect(scale(at: elapsed))
            .opacity(opacity(at: elapsed))
            .position(position(at: elapsed))
        }
        .allowsHitTesting(false)
        .task {
            try? await Task.sleep(nanoseconds: UInt64(total * 1_000_000_000))
            onArrive()
        }
    }

    // MARK: 시간 → 모습

    /// 액면가는 이번에 돌려받은 시간이 정한다 — 긴 문구를 쓰면 은화가 난다.
    private var denomination: VaultSprite {
        if flight.seconds >= VaultLedger.goldSeconds { return .gold }
        if flight.seconds >= VaultLedger.silverSeconds { return .silver }
        return .bronze
    }

    /// 나는 동안 구른다. 금화만 3프레임 회전을 쓰고, 동·은은 앞면 그대로 굴린다
    /// (회전 프레임은 금색 한 벌뿐이라 색이 튀면 다른 동전으로 보인다).
    private func spinFrame(at t: Double) -> VaultSprite {
        guard t > hop, denomination == .gold else { return denomination }
        let turns = (t - hop) / fly * 6
        return VaultSprite.spin[Int(turns) % VaultSprite.spin.count]
    }

    private func position(at t: Double) -> CGPoint {
        if t <= hop {
            // 톡 — 제자리에서 살짝 솟는다.
            let p = easeOut(t / hop)
            return CGPoint(x: flight.from.x, y: flight.from.y - 22 * p)
        }
        // 슉 — 솟은 자리에서 금고까지 포물선으로.
        //
        // ⚠️ 베지어 제어점으로 호를 만들면 안 된다. 카드가 금고보다 위냐 아래냐에 따라
        //    실제로 솟는 높이가 18pt~110pt로 들쭉날쭉해져서, 어떤 카드는 호가 아예 안 보이고
        //    (대각선으로 미끄러지는 것처럼 보인다) 어떤 카드는 과장되게 튄다.
        //    **직선에서 벗어나는 양**을 고정하면 어디서 눌러도 같은 호가 나온다.
        let p = easeIn(min(1, (t - hop) / fly))
        let start = CGPoint(x: flight.from.x, y: flight.from.y - 22)
        let arc = 4 * Self.arcRise * p * (1 - p)      // p=0.5 에서 정확히 arcRise 만큼 벗어난다
        return CGPoint(x: start.x + (to.x - start.x) * p,
                       y: start.y + (to.y - start.y) * p - arc)
    }

    /// 직선에서 벗어나는 최대 높이(pt).
    private static let arcRise: CGFloat = 70

    private func scale(at t: Double) -> CGFloat {
        guard t > hop else { return 1 }
        // 금고에 가까워질수록 작아진다 — 빨려 들어가는 느낌은 크기가 만든다.
        return 1 - 0.45 * CGFloat(min(1, (t - hop) / fly))
    }

    private func opacity(at t: Double) -> Double {
        let p = min(1, max(0, (t - hop) / fly))
        return p > 0.85 ? (1 - p) / 0.15 : 1
    }

    // MARK: 곡선

    private func easeOut(_ t: Double) -> CGFloat { CGFloat(1 - pow(1 - min(1, max(0, t)), 3)) }
    private func easeIn(_ t: Double) -> CGFloat { CGFloat(pow(min(1, max(0, t)), 1.7)) }
}

/// 화면 맨 위에 깔리는 비행 레이어. 카드도 금고도 아닌 **그 사이**를 그린다.
///
/// 받은 좌표는 global 이고 그리는 자리는 이 레이어 안이라, 자기 원점을 빼서 옮긴다.
/// 이 변환을 빼먹으면 동전이 화면 왼쪽 위로 쏠린다.
struct CoinFlightLayer: View {
    @ObservedObject var deposit: VaultDeposit

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            ZStack {
                ForEach(deposit.flights) { flight in
                    FlyingCoin(
                        flight: VaultDeposit.Flight(from: flight.from - origin,
                                                    seconds: flight.seconds,
                                                    payload: flight.payload),
                        to: deposit.vaultPoint - origin
                    ) {
                        deposit.arrive(flight.id)
                    }
                    .id(flight.id)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private extension CGPoint {
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
}

// MARK: - 금고 입구

/// 목록 화면에 서 있는 작은 금고. 동전이 여기로 들어오고, 누르면 금고 화면이 열린다.
struct VaultButton: View {
    /// 지금까지 쌓인 시간(초).
    let savedSeconds: Double
    /// 무엇을 모으는 자리인가 — 금고(시간)냐 주머니(보석)냐.
    var collects: VaultDeposit.Payload = .coin
    @ObservedObject var deposit: VaultDeposit
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 동전이 닿을 때마다 튕긴다.
    @State private var kick = false

    var body: some View {
        Button(action: action) {
            // 바에서는 금고만 세운다. 잔고 숫자까지 붙이면 제목과 자리를 다투고,
            // 다른 툴바 버튼들이 유리 알약을 걷어낸 상태라 여기만 채워진 알약이면 튄다.
            // 숫자는 금고 화면에서 크게 보여 주고, 여기서는 **들어왔다는 것**만 알린다.
            Group {
                if collects == .gem {
                    // 지오드 스킨에서는 보석이 모이는 주머니다. 금고를 세워 두면
                    // 시간을 모으는 것처럼 보여서 무엇을 세는지 헷갈린다.
                    GemView(size: 20)
                } else {
                    VaultSpriteStrip(sprites: [.closed], pixel: 1.5, gap: 0)
                }
            }
            .scaleEffect(kick ? 1.18 : 1)
            .offset(y: kick ? -2 : 0)
            .frame(width: 44, height: 44)     // 손가락이 닿을 만큼
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 금고가 자기 중심을 알려준다 — 동전은 이 좌표로 날아온다.
        //
        // ⚠️ PreferenceKey 로 올려보내지 않는다. 이 버튼은 네비게이션 바(툴바) 안에 사는데,
        //    툴바는 화면 본문과 다른 계층이라 preference 가 본문의 onPreferenceChange 까지
        //    닿는다는 보장이 없다. 가진 객체에 **직접** 적는 편이 확실하다.
        .background(
            GeometryReader { geo in
                let frame = geo.frame(in: .global)
                Color.clear
                    .onAppear { deposit.vaultPoint = CGPoint(x: frame.midX, y: frame.midY) }
                    .onChange(of: frame) { _, new in
                        deposit.vaultPoint = CGPoint(x: new.midX, y: new.midY)
                    }
            }
        )
        .onChange(of: deposit.arrivals) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) { kick = true }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.6).delay(0.12)) { kick = false }
        }
        .accessibilityLabel(NSLocalizedString("금고", comment: "Vault button accessibility label"))
        .accessibilityValue(UsagePassport.timeSavedText(seconds: savedSeconds)
                            ?? NSLocalizedString("아직 비어 있어요", comment: "Vault button empty value"))
    }
}
