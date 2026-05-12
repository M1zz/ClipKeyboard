//
//  SecurePINSettings.swift
//  ClipKeyboard
//
//  보안 메모 PIN 설정 — 키보드 익스텐션이 보안 메모 입력 시 인증에 사용.
//  4자리 PIN을 SHA-256으로 해시해서 App Group UserDefaults에 저장.
//

import SwiftUI
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

struct SecurePINSettings: View {
    @State private var showPINSetup = false
    @State private var pinIsSet = false

    private let pinKey = "keyboard_secure_pin_hash"
    private let appGroup = "group.com.Ysoup.TokenMemo"

    @Environment(\.appTheme) private var theme

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("보안 메모 PIN", comment: "Secure memo PIN section header"))
                            .font(.headline)
                    }
                    Text(NSLocalizedString("보안 메모를 키보드에서 입력할 때 사용하는 4자리 PIN입니다. 메인 앱에서 설정하면 키보드 익스텐션에서 인증에 사용됩니다.", comment: "Secure PIN section footer"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                if pinIsSet {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("보안 PIN이 설정되어 있습니다", comment: "Secure PIN is set"))
                        Spacer()
                        Button(NSLocalizedString("변경", comment: "Change PIN button")) {
                            showPINSetup = true
                        }
                        .font(.system(size: 14))
                        .accessibilityLabel(NSLocalizedString("PIN 변경", comment: "Change PIN accessibility label"))
                        .accessibilityHint(NSLocalizedString("새 PIN을 설정합니다", comment: "Change PIN hint"))
                    }
                    Button(role: .destructive) {
                        UserDefaults(suiteName: appGroup)?.removeObject(forKey: pinKey)
                        pinIsSet = false
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .accessibilityHidden(true)
                            Text(NSLocalizedString("PIN 삭제", comment: "Delete PIN button"))
                        }
                        .foregroundColor(.red)
                    }
                    .accessibilityHint(NSLocalizedString("저장된 보안 PIN을 삭제합니다", comment: "Delete PIN hint"))
                } else {
                    Button {
                        showPINSetup = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .accessibilityHidden(true)
                            Text(NSLocalizedString("보안 PIN 설정", comment: "Set secure PIN button"))
                        }
                        .foregroundColor(.blue)
                    }
                    .accessibilityHint(NSLocalizedString("4자리 보안 PIN을 새로 설정합니다", comment: "Set PIN hint"))
                }
            }
        }
        .sheet(isPresented: $showPINSetup) {
            SecurePINSetupView { hash in
                UserDefaults(suiteName: appGroup)?.set(hash, forKey: pinKey)
                pinIsSet = true
                showPINSetup = false
            }
        }
        .navigationTitle(NSLocalizedString("보안 PIN", comment: "Secure PIN nav title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbarBackground(theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            let storedHash = UserDefaults(suiteName: appGroup)?.string(forKey: pinKey) ?? ""
            pinIsSet = !storedHash.isEmpty
        }
    }
}

#Preview {
    NavigationStack {
        SecurePINSettings()
    }
}
