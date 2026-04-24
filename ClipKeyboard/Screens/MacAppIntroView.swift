//
//  MacAppIntroView.swift
//  ClipKeyboard
//
//  iOS에서 Mac 버전의 존재를 소개. Universal Purchase이므로 같은 App Store
//  구매로 Mac에서도 설치 가능.
//

import SwiftUI

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
        #endif
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "macbook")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text(NSLocalizedString("Also on your Mac", comment: "Mac hero title"))
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(NSLocalizedString("Same snippets, same memos — available on macOS.", comment: "Mac hero subtitle"))
                .font(.subheadline)
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
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var purchaseNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.green)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("Universal Purchase", comment: "Mac universal purchase title"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(NSLocalizedString("If you've purchased Pro on iOS, it works on Mac automatically — no extra payment.", comment: "Universal purchase description"))
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var openAppStoreButton: some View {
        Button {
            openMacAppStore()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.forward.app.fill")
                Text(NSLocalizedString("Open on Mac App Store", comment: "Open Mac App Store button"))
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var shortcutsHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("Tip", comment: "Tip section title"))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(theme.textMuted)
            Text(NSLocalizedString("Once installed, look for the ClipKeyboard icon in your Mac menu bar. Sign in with the same Apple ID to sync via iCloud.", comment: "Mac install tip"))
                .font(.footnote)
                .foregroundColor(theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func openMacAppStore() {
        HapticManager.shared.light()
        guard let url = URL(string: Constants.appStoreURL) else { return }
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
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
                Text(description)
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
