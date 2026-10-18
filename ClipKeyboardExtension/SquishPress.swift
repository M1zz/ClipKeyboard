//
//  SquishPress.swift
//  ClipKeyboard
//
//  누르면 말랑하게 줄었다가, 떼면 원래보다 살짝 커졌다 제자리로 돌아오는 눌림.
//
//  앱과 키보드 익스텐션이 **같은 파일**을 쓴다. 한쪽만 말랑하면 같은 키가 설정 미리보기에서와
//  실제 키보드에서 다르게 눌린다.
//
//  ⚠️ 줄어드는 것은 **그리기만**이다(`scaleEffect`). 자리(frame)는 그대로라 옆 키가
//     밀리지 않고, 누르는 영역도 줄지 않는다.
//  ⚠️ 동작 줄이기를 켰거나 연출을 끈 사람에게는 줄지 않는다. 대신 `.plain` 처럼 살짝 옅어져
//     눌렸다는 것만 알린다.
//

import SwiftUI

// MARK: - 곡선

enum SquishPress {
    /// 누르고 있는 동안. 손끝은 따라가되 **딱 멈추지는 않는다** - 끝에서 살짝 무르게 눌린다.
    /// (0.16 · 0.82 는 단단한 스위치처럼 딱 떨어졌고, 0.22 · 0.7 은 누르는 데서부터 출렁였다)
    static let pressIn: Animation = .spring(response: 0.2, dampingFraction: 0.78)

    /// 기본 눌림 비율.
    ///
    /// ⚠️ 0.90 은 너무 깊었다. 놓을 때의 튕김과 겹쳐 버튼마다 덜렁거린다는 말을 들었다
    ///    (사용자 의견 2026-10-18). 그렇다고 줄이지 않으면 단단한 스위치처럼 죽는다.
    ///    "적당히 말랑하게": 눌린 것이 보일 만큼만 들어간다.
    static let defaultScale: CGFloat = 0.94

    /// 화면 폭을 다 쓰는 줄(최근 목록)의 눌림 비율. 같은 곡선이되 얕게.
    /// 폭이 380pt 면 0.94 로도 좌우 23pt 가 움직인다. 0.975 는 10pt 남짓이다.
    static let rowScale: CGFloat = 0.975

    /// 떼는 순간 원래 크기를 넘어 커지는 비율. 줄어든 만큼의 3분의 1쯤 넘친다.
    /// 4분의 3(0.75)은 버튼이 놓일 때마다 부풀어 덜렁거렸고, 0 이면 고무가 아니라 플라스틱이다.
    static func overshoot(for scale: CGFloat) -> CGFloat {
        1 + (1 - scale) * 0.35
    }

    /// 연출 마스터 스위치(`DefaultsKey.delightEffectsEnabled`). 값이 없으면 켜짐.
    /// 앱의 `Delight.isEnabled` 와 키보드의 `KeyboardHaptics.delightEnabled` 가 같은 키를 읽는다.
    static var delightEnabled: Bool {
        guard let value = AppGroup.defaults?
            .object(forKey: DefaultsKey.delightEffectsEnabled) as? Bool else { return true }
        return value
    }
}

// MARK: - 수식어

/// 누르는 동안 줄어 있고, 떼는 순간 **작게 → 원래보다 크게 → 제자리** 를 한 번 재생한다.
///
/// ⚠️ 떼는 움직임을 눌림 상태의 애니메이션에 맡기지 않는다. 짧게 톡 치면 눌림이 켜졌다
///    꺼지는 사이에 한 프레임도 안 그려져서, 줄어드는 모습 없이 아무 일도 안 일어난 것처럼
///    보였다(목록 카드). 그래서 떼는 순간을 신호로 받아 **정해진 순서를 끝까지** 재생한다.
///    눌림이 화면에 그려졌든 안 그려졌든 같은 말랑함이 나온다.
struct SquishPressEffect: ViewModifier {
    let pressed: Bool
    var scale: CGFloat = SquishPress.defaultScale
    /// 눌림 상태를 못 받는 곳이 직접 튕기게 하는 신호. 0보다 큰 값으로 바뀔 때마다 한 번 튕긴다.
    /// (0으로 돌아가는 것은 무시한다 - 다른 카드로 신호가 옮겨 갈 때 옛 카드가 튕기지 않게)
    var bounce: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 뗄 때마다 하나씩 올라간다. 키프레임을 다시 트는 신호.
    @State private var releases = 0

    func body(content: Content) -> some View {
        let moves = !reduceMotion && SquishPress.delightEnabled
        let overshoot = SquishPress.overshoot(for: scale)
        content
            // 누르고 있는 동안의 크기. 뗄 때는 애니메이션 없이 1로 돌리고 아래 키프레임이 이어받는다.
            .scaleEffect(moves && pressed ? scale : 1)
            .animation(pressed ? SquishPress.pressIn : nil, value: pressed)
            .keyframeAnimator(initialValue: CGFloat(1), trigger: releases) { view, value in
                view.scaleEffect(value)
            } keyframes: { _ in
                KeyframeTrack {
                    // 눌린 크기에서 시작한다. 이미 줄어 있었다면 그 자리 그대로다.
                    LinearKeyframe(scale, duration: 0.01)
                    CubicKeyframe(scale, duration: 0.05)
                    // 원래보다 살짝 커졌다가 - 천천히 부풀어야 고무처럼 읽힌다.
                    CubicKeyframe(overshoot, duration: 0.16)
                    // 제자리로 내려앉는다. 한 번 부드럽게 닿고 멈춘다.
                    // ⚠️ 감쇠 0.42 는 한 번 더 흔들려 덜렁거렸다(2026-10-18). 0.62 는 출렁임 없이 탄력만 남는다.
                    SpringKeyframe(1, duration: 0.36, spring: .init(response: 0.32, dampingRatio: 0.62))
                }
            }
            .opacity(!moves && pressed ? 0.7 : 1)
            .onChange(of: pressed) { wasPressed, isPressed in
                if moves, wasPressed, !isPressed { releases += 1 }
            }
            .onChange(of: bounce) { _, now in
                if moves, now > 0 { releases += 1 }
            }
    }
}

extension View {
    /// 눌림 상태를 이미 들고 있는 곳(카드·콤보 키)에서 쓴다.
    func squishPress(_ pressed: Bool, scale: CGFloat = SquishPress.defaultScale, bounce: Int = 0) -> some View {
        modifier(SquishPressEffect(pressed: pressed, scale: scale, bounce: bounce))
    }
}

// MARK: - 버튼 스타일

/// `.plain` 과 같은 모양에 말랑한 눌림만 더한 스타일.
///
/// ⚠️ 글자색을 칠하지 않는다. `.plain` 을 쓰던 자리를 그대로 바꿔 끼우는 용도라,
///    여기서 강조색을 입히면 손으로 칠해 둔 단추 색이 전부 바뀐다.
struct SquishButtonStyle: ButtonStyle {
    var scale: CGFloat = SquishPress.defaultScale

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .squishPress(configuration.isPressed, scale: scale)
    }
}

extension ButtonStyle where Self == SquishButtonStyle {
    static var squish: SquishButtonStyle { SquishButtonStyle() }
}

// MARK: - 넓은 줄의 눌림

/// 화면 폭을 다 쓰는 줄(최근 목록)의 눌림. `.squish` 와 **같은 곡선을 얕게** 쓴다.
///
/// ⚠️ 넓은 줄에 기본 깊이를 쓰면 좌우가 수십 pt 씩 움직여 목록 전체가 덜렁거린다.
///    그렇다고 튕김을 아예 빼면 단단히 굳은 것으로 읽혔다(둘 다 사용자 의견 2026-10-18).
struct RowPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .squishPress(configuration.isPressed, scale: SquishPress.rowScale)
    }
}

extension ButtonStyle where Self == RowPressButtonStyle {
    static var rowPress: RowPressButtonStyle { RowPressButtonStyle() }
}
