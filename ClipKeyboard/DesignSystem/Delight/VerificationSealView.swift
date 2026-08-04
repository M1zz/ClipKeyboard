//
//  VerificationSealView.swift
//  ClipKeyboard
//
//  검증 각인 — "틀리지 않았다"를 눈에 보이게 만든다.
//
//  mod-97·Luhn 검증은 예전부터 돌고 있었지만 사용자에게는 한 번도 보이지 않았다.
//  조용히 맞히는 것과 "맞았습니다"라고 찍어 주는 것은 다른 경험이다.
//
//  실패했을 때가 더 중요하다 — 나무라지 않고 **어디를 고칠지**만 말한다.
//  그래서 실패 색도 danger가 아니라 warn 을 쓴다(오류가 아니라 확인 요청이다).
//

import SwiftUI

struct VerificationSealView: View {
    let result: ChecksumVerifier.Result

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0

    private var tint: Color { result.isValid ? theme.success : theme.warn }

    private var symbol: String {
        result.isValid ? AppSymbol.checkmarkSealFill : AppSymbol.exclamationmarkTriangleFill
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(result.stampLabel)
                        .font(.caption.weight(.bold))
                        .kerning(0.6)
                        .foregroundColor(tint)
                    Text(result.subject.displayName)
                        .font(.caption2)
                        .foregroundColor(theme.textMuted)
                }
                Text(result.detail)
                    .font(.caption2)
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusSm, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusSm, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        )
        .scaleEffect(scale)
        .opacity(opacity)
        // 색만으로 구분하지 않는다 — 아이콘·문구가 함께 상태를 말한다(접근성).
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.subject.displayName) \(result.stampLabel). \(result.detail)")
        .onAppear { press() }
        .onChange(of: result) { _, _ in press() }
    }

    /// 도장이 눌리듯 한 번 들어왔다 자리를 잡는다. 주 1~2회 보는 연출이라 daily보다 조금 길다.
    ///
    /// ⚠️ 햅틱은 **통과했을 때만** 울린다.
    ///    입력 중에는 값이 아직 미완성이라 실패 판정이 계속 뜨는데, 거기에 진동까지 붙이면
    ///    타이핑하는 내내 손을 때리는 꼴이 된다. 실패는 조용히 문구로만 알린다.
    ///    (`Result`가 Equatable이라 같은 판정이 반복되면 onChange 자체가 안 불린다 —
    ///     통과 햅틱도 유효/무효가 실제로 뒤집힐 때 한 번만 울린다)
    private func press() {
        if result.isValid { Delight.verified() }

        guard Delight.isEnabled, !reduceMotion else {
            scale = 1.0
            opacity = 1.0
            return
        }
        scale = 1.12
        opacity = 0
        withAnimation(.spring(response: Delight.Tier.occasional.duration, dampingFraction: 0.68)) {
            scale = 1.0
            opacity = 1.0
        }
    }
}
