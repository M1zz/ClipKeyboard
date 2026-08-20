//
//  ShellCrack.swift
//  ClipKeyboard
//
//  **껍데기를 깨서 값을 꺼낸다.**
//
//  단축어를 누르면 값이 나온다는 것을, 말이 아니라 한 번의 장면으로 알리는 장치다.
//  키 위에 껍데기가 씌워지고, 악어가 들어와 깨물고, 갈라진 틈에서 알맹이가 나온다.
//
//  ⚠️ **이빨 스킨과 같이 쓰지 않는다.** 같은 키가 이빨이면서 먹이일 수는 없다.
//     키가 이빨이면 악어가 자기 이빨을 무는 그림이 된다. 그래서 이 연출을 택하면서
//     이빨 스킨은 새 설치에서 켜지지 않게 했다(`ToothStyle.seedDefaultIfNeeded`).
//
//  ⚠️ **익스텐션에서는 절대 돌지 않는다.** 이 파일은 `KeyboardView` 와 함께 익스텐션에도
//     컴파일되지만, 연출은 `hostKind == .inApp` 일 때만 불린다. 익스텐션은 메모리가
//     빠듯하고, 무엇보다 하루에 수십 번 누르는 자리다. 매번 깨지면 사흘째부터는 방해다.
//
//  ⚠️ **처음 몇 번만.** 미리보기에서도 `ShellCrack.budget` 이 다 닳으면 조용히 멈춘다.
//     배우는 자리의 연출은 다 배우고 나면 소음이다.
//
//  ⚠️ 껍데기는 **벡터로 그린다.** 에셋이 필요 없고, 종류를 바꾸는 데 그림을 다시
//     그리지 않아도 된다(`ShellKind.current` 한 줄).
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 무엇을 깨무나

/// 키에 씌우는 껍데기. 셋 다 같은 뼈대(반쪽 둘 + 알맹이)라 **그림만 갈아 끼운다.**
enum ShellKind: String, CaseIterable, Sendable {

    /// 깨면 **글이 적힌 쪽지**가 나온다. 이 앱이 꺼내는 것도 글이라 뜻이 정확히 맞는다.
    case fortuneCookie

    /// 두 색으로 나뉘어 있어 열리기 전부터 안이 있다고 말한다. 어느 문화에서나 같게 읽힌다.
    case capsule

    /// 껍데기와 알맹이의 원형. 뚜껑이 날아가고 알맹이가 드러난다.
    case acorn

    /// 지금 쓰는 껍데기. **바꾸려면 이 한 줄만 고친다.**
    static let current: ShellKind = .fortuneCookie
}

// MARK: - 껍데기 색

/// 껍데기에만 쓰는 색. 앱 테마 토큰이 아니라 여기 두는 이유는, 이 색들이 테마를 따르는
/// 표면색이 아니라 **물건의 색**이기 때문이다(쿠키는 다크 모드에서도 쿠키색이다).
private enum ShellPalette {
    static let cookie     = Color(red: 0xE3/255, green: 0xB4/255, blue: 0x73/255)
    static let cookieEdge = Color(red: 0xC9/255, green: 0x92/255, blue: 0x4E/255)
    static let paper      = Color(red: 0xFF/255, green: 0xFD/255, blue: 0xF6/255)
    static let capsuleTop = Color.clipBrand
    static let capsuleBot = Color(red: 0xF4/255, green: 0xEF/255, blue: 0xE4/255)
    static let acornCap   = Color(red: 0x7A/255, green: 0x52/255, blue: 0x30/255)
    static let acornNut   = Color(red: 0xD6/255, green: 0xA8/255, blue: 0x68/255)
    static let acornMeat  = Color(red: 0xF6/255, green: 0xEE/255, blue: 0xDF/255)
}

// MARK: - 껍데기 반쪽

/// 껍데기의 한 조각. 0~1 정규 좌표로 그려 어느 크기에나 같은 모양이 나온다.
struct ShellHalfShape: Shape {
    let kind: ShellKind
    /// true 면 위쪽·왼쪽 조각, false 면 아래쪽·오른쪽 조각.
    let leading: Bool

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }

        var path = Path()
        switch kind {
        case .fortuneCookie:
            // 접힌 과자를 반으로 쪼갠 모양. 위 꼭짓점에서 아래로 벌어진다.
            if leading {
                path.move(to: p(0.50, 0.22))
                path.addQuadCurve(to: p(0.19, 0.74), control: p(0.30, 0.44))
                path.addQuadCurve(to: p(0.50, 0.58), control: p(0.34, 0.63))
            } else {
                path.move(to: p(0.50, 0.22))
                path.addQuadCurve(to: p(0.81, 0.74), control: p(0.70, 0.44))
                path.addQuadCurve(to: p(0.50, 0.58), control: p(0.66, 0.63))
            }
            path.closeSubpath()

        case .capsule:
            // 가로로 누운 캡슐을 가운데서 좌우로 가른다.
            if leading {
                path.move(to: p(0.50, 0.30))
                path.addLine(to: p(0.30, 0.30))
                path.addQuadCurve(to: p(0.30, 0.70), control: p(0.08, 0.50))
                path.addLine(to: p(0.50, 0.70))
            } else {
                path.move(to: p(0.50, 0.30))
                path.addLine(to: p(0.70, 0.30))
                path.addQuadCurve(to: p(0.70, 0.70), control: p(0.92, 0.50))
                path.addLine(to: p(0.50, 0.70))
            }
            path.closeSubpath()

        case .acorn:
            // 뚜껑과 몸통. 뚜껑이 날아가고 몸통이 벌어진다.
            if leading {
                path.move(to: p(0.20, 0.44))
                path.addQuadCurve(to: p(0.80, 0.44), control: p(0.50, 0.06))
            } else {
                path.move(to: p(0.20, 0.44))
                path.addQuadCurve(to: p(0.80, 0.44), control: p(0.50, 0.94))
            }
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - 껍데기 한 벌

/// 껍데기 + 안의 알맹이. `split` 이 0 이면 닫혀 있고, 1 이면 완전히 갈라져 알맹이가 드러난다.
struct ShellView: View {
    var kind: ShellKind = ShellKind.current
    /// 0 = 닫힘, 1 = 갈라짐.
    var split: Double = 0

    var body: some View {
        ZStack {
            core
                .scaleEffect(0.2 + 0.8 * split)
                .opacity(split)

            ShellHalfShape(kind: kind, leading: true)
                .fill(leadingColor)
                .offset(x: -13 * split, y: -9 * split)
                .rotationEffect(.degrees(-26 * split))
                .opacity(1 - 0.65 * split)

            ShellHalfShape(kind: kind, leading: false)
                .fill(trailingColor)
                .offset(x: 13 * split, y: 10 * split)
                .rotationEffect(.degrees(24 * split))
                .opacity(1 - 0.65 * split)
        }
        .compositingGroup()
    }

    /// 안에 들어 있던 것.
    @ViewBuilder
    private var core: some View {
        switch kind {
        case .fortuneCookie:
            // 쪽지. 줄 두 개가 "글이 적혀 있다"를 말한다.
            ZStack {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(ShellPalette.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.18), lineWidth: 0.6)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Capsule().fill(Color.clipBrand).frame(width: 14, height: 1.6)
                    Capsule().fill(Color.clipBrand.opacity(0.55)).frame(width: 19, height: 1.6)
                }
            }
            .frame(width: 26, height: 13)

        case .capsule:
            ZStack {
                Circle().fill(Color.clipBrand).frame(width: 18, height: 18)
                Circle().fill(Color.clipBrandYellow).frame(width: 8, height: 8)
            }

        case .acorn:
            ZStack {
                Circle().fill(ShellPalette.acornMeat).frame(width: 20, height: 20)
                Circle().fill(Color.clipBrand).frame(width: 9, height: 9)
            }
        }
    }

    private var leadingColor: Color {
        switch kind {
        case .fortuneCookie: return ShellPalette.cookie
        case .capsule:       return ShellPalette.capsuleTop
        case .acorn:         return ShellPalette.acornCap
        }
    }

    private var trailingColor: Color {
        switch kind {
        case .fortuneCookie: return ShellPalette.cookieEdge
        case .capsule:       return ShellPalette.capsuleBot
        case .acorn:         return ShellPalette.acornNut
        }
    }
}

// MARK: - 몇 번 더 보여줄까

enum ShellCrack {

    /// 미리보기에서 이 연출을 보여 줄 횟수. 다 닳으면 조용히 멈춘다.
    static let initialBudget = 3

    /// 한 번 쓴다. 남아 있었으면 true 를 주고 하나 깎는다.
    ///
    /// ⚠️ 값을 읽어만 보고 깎지 않는 경로를 만들지 않는다. 그러면 키를 눌러도 연출이
    ///    안 나오는데 횟수만 그대로 남는 상태가 생긴다.
    @discardableResult
    static func consumeBudget() -> Bool {
        guard let d = AppGroup.defaults else { return false }
        let left = d.object(forKey: DefaultsKey.shellCracksLeft) as? Int ?? initialBudget
        guard left > 0 else { return false }
        d.set(left - 1, forKey: DefaultsKey.shellCracksLeft)
        return true
    }

    /// 마스코트 그림 이름. 무는 포즈가 준비되면 그것으로, 없으면 기본 얼굴로.
    ///
    /// ⚠️ `MascotPose` 를 쓰지 않는다. 그 타입은 앱 타겟에만 있는데 이 파일은 익스텐션에도
    ///    컴파일된다. 같은 규칙(없으면 기본 얼굴)을 여기서 한 번 더 적는 편이,
    ///    익스텐션에 TipKit 을 끌고 들어가는 것보다 싸다.
    static var mascotImageName: String {
        #if canImport(UIKit)
        if UIImage(named: "MascotBiting") != nil { return "MascotBiting" }
        #endif
        return "MascotAvatar"
    }
}

// MARK: - 키 위에 얹는 연출

/// 눌린 키 위에서 벌어지는 한 장면. 키 자체는 건드리지 않고 **위에 얹기만** 한다.
///
/// ⚠️ 키의 좌표를 바깥에서 계산하지 않는다. 이 장치는 키 셀 안에 얹혀서 셀 좌표만 쓴다.
///    격자는 스크롤되고 열 수가 바뀌고 재정렬되므로, 전역 좌표로 계산하면 이미 사라진
///    자리에 악어가 내려앉는 사고가 난다.
struct ShellCrackOverlay: ViewModifier {

    /// 지금 이 키에서 연출이 돌아야 하는가.
    let active: Bool
    /// 장면이 끝났다 - 호출한 쪽이 표식을 지운다.
    let onEnd: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shellOpacity: Double = 0
    @State private var split: Double = 0
    @State private var crocOffset: CGSize = .zero
    @State private var crocOpacity: Double = 0
    @State private var crocAngle: Double = 0
    @State private var flash: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay { scene }
            .onChange(of: active) { _, isOn in
                guard isOn else { return }
                run()
            }
    }

    @ViewBuilder
    private var scene: some View {
        if shellOpacity > 0 || crocOpacity > 0 {
            ZStack {
                // 깨지는 순간의 빛. 어디서 벌어진 일인지 눈이 먼저 찾아간다.
                Circle()
                    .fill(
                        RadialGradient(colors: [Color.clipBrandYellow.opacity(0.85), .clear],
                                       center: .center, startRadius: 0, endRadius: 26)
                    )
                    .frame(width: 54, height: 54)
                    .scaleEffect(0.4 + flash)
                    .opacity(flash)

                ShellView(split: split)
                    .frame(width: 38, height: 38)
                    .opacity(shellOpacity)

                Image(ShellCrack.mascotImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 74, height: 74)
                    .rotationEffect(.degrees(crocAngle))
                    .offset(crocOffset)
                    .opacity(crocOpacity)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// 장면. 시간은 밀리초로 적어 두었다 - 눈으로 읽히는 순서가 코드의 순서와 같아야 한다.
    private func run() {
        // 움직임 줄이기: 껍데기를 갈라 놓은 그림만 잠깐 보여 주고 끝낸다.
        guard !reduceMotion else {
            shellOpacity = 1
            split = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                shellOpacity = 0
                split = 0
                onEnd()
            }
            return
        }

        // 0ms - 껍데기가 키를 덮고, 악어가 오른쪽 밖에서 들어온다.
        shellOpacity = 1
        split = 0
        crocAngle = 0
        crocOffset = CGSize(width: 120, height: -30)
        crocOpacity = 1
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            crocOffset = CGSize(width: 6, height: -30)
        }

        // 330ms - 깨문다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.33) {
            withAnimation(.easeInOut(duration: 0.13)) { crocAngle = -15 }
            withAnimation(.spring(response: 0.30, dampingFraction: 0.6)) { split = 1 }
            withAnimation(.easeOut(duration: 0.34)) { flash = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
            withAnimation(.easeInOut(duration: 0.12)) { crocAngle = 4 }
            withAnimation(.easeOut(duration: 0.2)) { flash = 0 }
        }

        // 620ms - 알맹이만 남기고 악어는 나간다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            withAnimation(.easeInOut(duration: 0.1)) { crocAngle = 0 }
            withAnimation(.easeIn(duration: 0.28)) {
                crocOffset = CGSize(width: 120, height: -30)
                crocOpacity = 0
            }
        }

        // 940ms - 껍데기도 사라진다. 값은 이미 무대에 올라가 있다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.94) {
            withAnimation(.easeOut(duration: 0.22)) { shellOpacity = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.18) {
            split = 0
            onEnd()
        }
    }
}
