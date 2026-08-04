//
//  WaxSealView.swift
//  ClipKeyboard
//
//  봉인 — 보안 메모의 잠금 상태를 만질 수 있는 형태로 만든다.
//
//  "보안 메모 잠금"은 지금까지 설정 화면의 체크박스였다. 봉랍 도장으로 바꾸면
//  프라이버시가 설명이 아니라 감각이 된다. 눌러서 봉하고, 갈라서 연다.
//
//  ⚠️ 연출일 뿐 잠금 자체는 아니다. 실제 인증은 BiometricAuthManager가 한다.
//     이 뷰는 상태를 보여주고 탭을 전달하기만 한다.
//

import SwiftUI

struct WaxSealView: View {
    /// 봉인되어 있는가.
    let isSealed: Bool
    var size: CGFloat = 44
    /// 탭 동작. nil이면 장식으로만 쓰인다(탭 불가).
    var onTap: (() -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pressScale: CGFloat = 1.0

    var body: some View {
        Group {
            if onTap != nil {
                Button(action: tapped) { seal }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityLabel)
                    .accessibilityHint(accessibilityHint)
                    .accessibilityAddTraits(.isButton)
            } else {
                seal
                    .accessibilityLabel(accessibilityLabel)
            }
        }
    }

    // MARK: - 봉랍

    private var seal: some View {
        ZStack {
            Circle()
                .fill(theme.accent.opacity(isSealed ? 0.92 : 0.28))

            // 봉인이 갈라진 자국 — 열렸을 때만 보인다.
            if !isSealed {
                Capsule()
                    .fill(theme.surface)
                    .frame(width: size * 0.075, height: size * 0.98)
                    .rotationEffect(.degrees(14))
            }

            Image(systemName: isSealed ? AppSymbol.lockFill : AppSymbol.lockOpenFill)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundColor(isSealed ? theme.accentFg : theme.accent)
        }
        .frame(width: size, height: size)
        .scaleEffect(pressScale)
        .animation(Delight.motion(.occasional, reduceMotion: reduceMotion), value: isSealed)
        .animation(Delight.motion(.daily, reduceMotion: reduceMotion), value: pressScale)
    }

    // MARK: - 동작

    private func tapped() {
        if isSealed { Delight.unsealed() } else { Delight.sealed() }

        if Delight.isEnabled, !reduceMotion {
            pressScale = 0.9
            DispatchQueue.main.asyncAfter(deadline: .now() + Delight.Tier.daily.duration) {
                pressScale = 1.0
            }
        }
        onTap?()
    }

    // MARK: - 접근성

    private var accessibilityLabel: String {
        isSealed
            ? NSLocalizedString("봉인됨", comment: "Wax seal state: sealed")
            : NSLocalizedString("열림", comment: "Wax seal state: opened")
    }

    private var accessibilityHint: String {
        isSealed
            ? NSLocalizedString("두 번 탭하면 생체인증으로 엽니다.", comment: "Wax seal hint: unlock")
            : NSLocalizedString("두 번 탭하면 다시 봉인합니다.", comment: "Wax seal hint: lock again")
    }
}
