//
//  KeyboardStageIntro.swift
//  ClipKeyboard
//
//  키보드 미리보기(무대)로 **처음** 건너왔을 때 한 번 뜨는 그림.
//
//  "다른 앱에서 지구본을 누르면 이 키보드가 떠요" 를 말하고, 아래 키보드를 가리키는 화살표가
//  두어 번 내려앉는다. 알겠어요를 누르거나 5초가 지나면 걷힌다. 장부에 `.stage` 로 적는다.
//
//  ⚠️ 백지로 시작한 사람만 본다. 기존 사용자는 이 단추를 이미 안다.
//

import SwiftUI
import LeeoKit

struct KeyboardStageIntro: View {
    @State private var shown = false
    @State private var bob = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 지금 띄울 때인가.
    static var isDue: Bool {
        FeatureSet.isBlankStartUser() && !LessonLedger.hasLearned(.stage)
    }

    var body: some View {
        Group {
            if shown {
                VStack(spacing: 10) {
                    Text(NSLocalizedString("다른 앱에서 지구본을 누르면 이 키보드가 떠요",
                                           comment: "Keyboard stage intro: what this preview is"))
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text(NSLocalizedString("여기서 미리 눌러 볼 수 있어요", comment: "Keyboard stage intro: you can try it here"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Image(systemName: AppSymbol.arrowDown)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .offset(y: bob ? 8 : 0)
                    Button {
                        dismiss()
                    } label: {
                        Text(NSLocalizedString("알겠어요", comment: "Keyboard stage intro: dismiss"))
                            .font(.body.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22).padding(.vertical, 10)
                            .background(Color.accentColor, in: Capsule())
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 70)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            guard Self.isDue else { return }
            withAnimation(.spring(duration: 0.5, bounce: 0.3).delay(0.35)) { shown = true }
            HapticManager.shared.light()
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.6).repeatCount(4, autoreverses: true).delay(0.8)) { bob = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { dismiss() }
        }
    }

    private func dismiss() {
        guard shown else { return }
        LessonLedger.learn(.stage)
        withAnimation(.easeInOut(duration: 0.3)) { shown = false }
    }
}
