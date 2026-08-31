//
//  StampMark.swift
//  ClipKeyboard
//
//  날인 자국 - 사용 흔적을 숫자가 아니라 잉크 농도로 보여준다.
//
//  왜 숫자가 아닌가: "132회 사용"은 성과 지표처럼 읽히고, 적은 쪽에 죄책감을 만든다.
//  자국은 그냥 흔적이라 많이 쓴 문구가 자연스럽게 손에 익은 것처럼 보인다.
//
//  ⚠️ 색은 테마 accent를 쓴다 - 인앱은 Native Neutral 유지.
//

import SwiftUI

// MARK: - 정적 자국 (리스트 행에 남는 흔적)

/// 사용 흔적 자국. `useCount`가 0이면 아무것도 그리지 않는다.
struct StampMark: View {
    let useCount: Int
    /// 지름(pt).
    var size: CGFloat = 18
    /// 자국의 기울기(도). 행마다 같은 값을 주면 기계적으로 보이므로 호출부에서 흔들어 준다.
    var angle: Double = -8

    @Environment(\.appTheme) private var theme

    var body: some View {
        if useCount > 0 {
            Circle()
                .strokeBorder(theme.accent.opacity(Delight.inkOpacity(forUseCount: useCount)),
                              lineWidth: max(1, size * 0.09))
                .overlay(
                    Text("\(min(useCount, 999))")
                        .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.accent.opacity(Delight.inkOpacity(forUseCount: useCount) + 0.18))
                        .minimumScaleFactor(0.6)
                        .padding(1)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(angle))
                // 행 전체의 accessibilityLabel이 사용 횟수를 이미 읽으므로 중복 낭독을 막는다.
                .accessibilityHidden(true)
        }
    }
}

// MARK: - 찍히는 순간 (입력 직후 한 번)
