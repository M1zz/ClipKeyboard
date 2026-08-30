//
//  CardSurfaceEffects.swift
//  ClipKeyboard
//
//  카드 한 장의 표면과 두께, 그리고 눌렸을 때의 반응.
//  목록 화면 파일에 같이 살던 것을 꺼냈다. 이것들은 목록의 일부가 아니라
//  "카드는 어떻게 생겼고 어떻게 눌리는가" 라는 이 앱의 표면 언어라서,
//  다른 카드면에서도 그대로 쓸 수 있어야 한다.
//

import SwiftUI

/// 카드 글자 뒤에 까는 할로 - **필요할 때만 깐다.**
///
/// ⚠️ `color` 가 nil 이면 `compositingGroup` 째로 건너뛴다. 이게 이 뷰의 전부다.
///    할로는 유리 너머로 사진이나 카테고리 색이 비칠 때 글자를 붙잡아 주려고 있는데,
///    민 바탕(배경 사진 없음 + 무색 카드) 위에서는 테마 배경색과 **같은 색**이라
///    보이지도 않는다. 그런데 `compositingGroup` 은 카드마다 화면 밖 합성을 한 번씩
///    더 만든다 - 목록에 들어갈 때마다 카드 수만큼 공짜로 내는 값이었다.
struct CardTextHalo: ViewModifier {
    let color: Color?

    func body(content: Content) -> some View {
        if let color {
            content
                .compositingGroup()
                .shadow(color: color, radius: 4, x: 0, y: 0)
        } else {
            content
        }
    }
}

// MARK: - 카드 누름 효과

/// 카드가 탭에 반응하는 방식. 스킨에 따라 **두 갈래**로 갈린다.
///
/// - 두께가 있는 스킨: 키캡처럼 바닥까지 내려앉았다 돌아온다(스커트가 제자리에 남는다).
/// - 두께가 없는 스킨(납작·예전 방식): 키캡 이전에 쓰던 **푹신한 스케일 바운스**.
///   0.92로 쑥 들어갔다가 1.05까지 부풀고 제자리로 - 키프레임으로 1.05 peak를 보장해
///   빠르게 연타해도 항상 보인다.
///
/// ⚠️ 두 방식을 한 뷰에서 분기하는 이유: 예전 동작을 **버리지 않고 남겨 두기 위해서**다.
///    키캡은 취향이 갈리는 변화라, 설정 하나로 원래대로 돌아갈 수 있어야 한다.
/// 카드 아래 깔리는 옆면. 유리를 **버리지 않고** 그 밑에 두께만 더한다
/// 유리는 표면이고 스커트는 두께라 서로 싸우지 않는다.
///
/// ⚠️ 키보드의 `KeycapSurface`와 규칙은 같지만 구동 방식이 다르다.
///    키는 누르고 있는 동안(`isPressed`) 내려가 있고, 카드는 탭 한 번에
///    키프레임으로 내려갔다 올라온다(리스트는 롱프레스가 따로 있어 press 상태를 못 쓴다).
///
/// 색·반지름을 **값으로 받는** 이유: 이 뷰가 만들어지는 자리가 키프레임 애니메이터의
/// `@Sendable` 클로저 안이라, 거기서 테마나 스킨을 다시 읽을 수 없다.
struct CardSkirt: View {
    let depth: CGFloat
    let offsetY: CGFloat
    let radius: CGFloat
    let opacity: Double

    var body: some View {
        if depth > 0 {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.black.opacity(opacity))
                // 캡이 dy만큼 내려가면 스커트는 그만큼 덜 내려가 **절대 위치가 고정**된다.
                // (합이 항상 depth → 바닥은 가만히 있고 캡만 눌린다)
                .offset(y: depth - offsetY)
        }
    }
}

struct CardPressEffect<Skirt: View>: ViewModifier {
    let trigger: Int
    let legacyBounce: Bool
    let depth: CGFloat
    let pressDuration: Double
    // `keyframeAnimator` 의 content 클로저가 `@Sendable` 이라 여기도 같이 붙여야
    // 메인 액터 격리 경고가 나지 않는다.
    @ViewBuilder let skirt: @Sendable (CGFloat) -> Skirt

    func body(content: Content) -> some View {
        if legacyBounce {
            content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    CubicKeyframe(0.92, duration: 0.12)   // 부드럽게 쑥 들어감
                    CubicKeyframe(1.05, duration: 0.17)   // 원래보다 크게 튀어나옴
                    CubicKeyframe(1.0, duration: 0.22)    // 원래 크기로 안착
                }
            }
        } else {
            content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, dy in
                view
                    .background(skirt(dy))
                    .offset(y: dy)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    CubicKeyframe(depth, duration: pressDuration)  // 바닥까지
                    CubicKeyframe(0, duration: 0.22)               // 제자리로
                }
            }
        }
    }
}
