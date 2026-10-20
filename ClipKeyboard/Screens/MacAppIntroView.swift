//
//  MacAppIntroView.swift
//  ClipKeyboard
//
//  iOS에서 Mac 버전의 존재를 소개. Universal Purchase이므로 같은 App Store
//  구매로 Mac에서도 설치 가능.
//

import SwiftUI
import LeeoKit

struct MacAppIntroView: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroSection
                featuresSection
                purchaseNote
                openAppStoreButton
                #if !targetEnvironment(macCatalyst)
                shortcutsHint
                #endif
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .navigationTitle(NSLocalizedString("ClipKeyboard for Mac", comment: "Mac app intro title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .solidNavBar(theme.bg)
        #endif
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: AppSymbol.macbook)
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text(NSLocalizedString("Also on your Mac", comment: "Mac hero title"))
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(NSLocalizedString("Same snippets, same memos: available on macOS.", comment: "Mac hero subtitle"))
                .font(.body)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            MacFeatureRow(
                icon: "menubar.rectangle",
                tint: .blue,
                title: NSLocalizedString("Menu bar access", comment: "Mac feature: menu bar"),
                description: NSLocalizedString("Pin ClipKeyboard to the macOS menu bar and paste from anywhere.", comment: "Mac feature: menu bar description")
            )
            MacFeatureRow(
                icon: "keyboard",
                tint: .indigo,
                title: NSLocalizedString("Global hotkey", comment: "Mac feature: global hotkey"),
                description: NSLocalizedString("Press ⌃⌥K from any app to open your snippet list instantly.", comment: "Mac feature: hotkey description")
            )
            MacFeatureRow(
                icon: "icloud.fill",
                tint: .cyan,
                title: NSLocalizedString("Syncs via iCloud", comment: "Mac feature: iCloud sync"),
                description: NSLocalizedString("Your memos, templates and clipboard history follow you between iPhone and Mac.", comment: "Mac feature: sync description")
            )
            MacFeatureRow(
                icon: "command.circle",
                tint: .purple,
                title: NSLocalizedString("Native keyboard shortcuts", comment: "Mac feature: shortcuts"),
                description: NSLocalizedString("⌘⇧N for a new memo, ⌘⇧H for clipboard history, and more.", comment: "Mac feature: shortcuts description")
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
    }

    private var purchaseNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: AppSymbol.checkmarkSealFill)
                .foregroundColor(.green)
                .font(.system(.body))
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("Universal Purchase", comment: "Mac universal purchase title"))
                    .font(.body)
                    .fontWeight(.semibold)
                Text(NSLocalizedString("If you've purchased Pro on iOS, it works on Mac automatically: no extra payment.", comment: "Universal purchase description"))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMd)
                .stroke(Color.green.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
    }

    private var openAppStoreButton: some View {
        Button {
            openMacAppStore()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: AppSymbol.arrowUpForwardAppFill)
                Text(NSLocalizedString("Open on Mac App Store", comment: "Open Mac App Store button"))
                    .fontWeight(.semibold)
            }
            .foregroundColor(Color.accentForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
        }
        .buttonStyle(.squish)
    }

    @ViewBuilder
    private var shortcutsHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("Tip", comment: "Tip section title"))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(theme.textMuted)
            Text(NSLocalizedString("Once installed, look for the ClipKeyboard icon in your Mac menu bar. Sign in with the same Apple ID to sync via iCloud.", comment: "Mac install tip"))
                .font(.body)
                .foregroundColor(theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func openMacAppStore() {
        HapticManager.shared.light()
        // ⚠️ 예전에는 `appStoreURL`(아이폰 앱)로 보냈다. Mac 앱은 따로 있는 앱이다.
        guard let url = URL(string: Constants.macAppStoreURL) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #endif
    }
}

// MARK: - Row helper

private struct MacFeatureRow: View {
    let icon: String
    let tint: Color
    let title: String
    let description: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(.body, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
                Text(description)
                    .font(.body)
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Mac 에서 이 앱을 열었을 때

/// 아이폰 앱을 Mac(Apple 실리콘)에서 열면 **이 화면 하나만** 띄운다.
///
/// 왜: 이 앱의 쓸모는 아이폰 키보드에 있다. Mac 에서는 키보드 익스텐션이 붙지 않아
/// 단축어를 만들어도 다른 앱에 넣을 길이 없다. Mac 에는 메뉴 막대와 단축키로 붙여넣는
/// Mac 앱(탭클립키보드)이 따로 있으니 그리로 보낸다.
///
/// ⚠️ 동기화 · 백업 · 런치 작업을 돌리지 않는다(`ClipKeyboardApp.body` 에서 이 화면만 그린다).
struct MacOnlyGuideView: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            Image(systemName: AppSymbol.macbook)
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(NSLocalizedString("Mac에서는 탭클립키보드를 받아 주세요",
                                   comment: "Shown when the iPhone app is opened on a Mac: title asking to download the Mac app (Tap ClipKeyboard)"))
                .font(.title2.weight(.bold))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(NSLocalizedString("이 앱은 아이폰 키보드에서 쓰는 앱이라 Mac에서는 단축어를 넣을 수 없어요. Mac용 탭클립키보드는 메뉴 막대와 단축키로 어느 앱에서나 바로 붙여넣어요.",
                                   comment: "Shown when the iPhone app is opened on a Mac: why, and what the Mac app does"))
                .font(.body)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                guard let url = URL(string: Constants.macAppStoreURL) else { return }
                UIApplication.shared.open(url)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: AppSymbol.arrowUpForwardAppFill)
                    Text(NSLocalizedString("Open on Mac App Store", comment: "Open Mac App Store button"))
                        .fontWeight(.semibold)
                }
                .foregroundColor(Color.accentForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
            }
            .buttonStyle(.squish)
            Spacer(minLength: 0)
        }
        .padding(32)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
        .onAppear {
            // 런치 작업을 돌리지 않으므로 여기서 런치를 닫는다. 안 닫으면 다음 실행이 멈춘 런치로 읽힌다.
            LaunchGuard.finish()
        }
    }

    /// 이 아이폰 앱이 지금 Mac 에서 돌고 있는가.
    static var isRunningOnMac: Bool {
        ProcessInfo.processInfo.isiOSAppOnMac
    }
}
