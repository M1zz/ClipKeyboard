//
//  KeyboardSetupRequiredBanner.swift
//  ClipKeyboard
//
//  키보드를 켜지 않았으면 목록 맨 위에 **늘** 서 있는 띠.
//
//  ⚠️ 닫는 단추가 없다. 키보드를 켜지 않으면 이 앱은 아무것도 아니다. 단축어를 아무리 만들어도
//     다른 앱에서 넣을 길이 없다. 닫을 수 있게 하면 닫고 잊은 사람이 "이 앱 뭐 하는 거지"로 떠난다.
//     켜는 것 말고는 사라지는 길이 없다(키보드 무대의 띠와 같은 약속, `KeyboardSetupBannerGate`).
//
//  ⚠️ 켰는지는 `KeyboardInstallState.isUsable` 하나로 본다. 설정에서 켜고 돌아오면
//     앱이 앞으로 올 때 다시 보고 곧바로 걷힌다.
//

import SwiftUI
import LeeoKit

struct KeyboardSetupRequiredBanner: View {
    @Environment(\.appTheme) private var theme
    @State private var isUsable = KeyboardInstallState.isUsable
    @State private var showsSetup = false

    var body: some View {
        DismissibleRow(isShowing: !isUsable) {
            Button {
                HapticManager.shared.light()
                showsSetup = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: AppSymbol.keyboardBadgeEllipsis)
                        .font(.title2)
                        .foregroundColor(theme.accent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("아직 다른 앱에서는 못 써요", comment: "Keyboard not set up banner title"))
                            .font(.headline)
                            .foregroundColor(theme.text)
                        Text(NSLocalizedString("키보드를 켜야 어느 앱에서든 단축어를 넣을 수 있어요", comment: "Keyboard not set up banner body (list)"))
                            .font(.body)
                            .foregroundColor(theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Text(NSLocalizedString("켜기", comment: "Turn on the keyboard"))
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.accentFg)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(theme.accent))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.squish)
            .accessibilityElement(children: .combine)
            .accessibilityHint(NSLocalizedString("키보드를 켜는 방법을 봅니다", comment: "Keyboard setup banner hint"))
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // 시스템이 켠 키보드 목록을 비추는 데 한 박자 걸린다. 곧바로 물으면 방금 켠 것도 못 본다.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { refresh() }
        }
        .fullScreenCover(isPresented: $showsSetup, onDismiss: refresh) {
            KeyboardSetupOnboardingView(exitAction: { showsSetup = false })
        }
    }

    private func refresh() {
        let now = KeyboardInstallState.isUsable
        if now != isUsable { withAnimation { isUsable = now } }
    }
}
