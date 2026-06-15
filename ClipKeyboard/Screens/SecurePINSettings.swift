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
    @State private var showDeletePINConfirm = false

    private let pinKey = "keyboard_secure_pin_hash"

    @Environment(\.appTheme) private var theme

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: AppSymbol.lockShieldFill)
                            .font(.title2)
                            .foregroundColor(.orange)
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("보안 메모 PIN", comment: "Secure memo PIN section header"))
                            .font(.headline)
                    }
                    Text(NSLocalizedString("보안 메모를 키보드에서 입력할 때 사용하는 4자리 PIN입니다. 메인 앱에서 설정하면 키보드 익스텐션에서 인증에 사용됩니다.", comment: "Secure PIN section footer"))
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                if pinIsSet {
                    HStack {
                        Image(systemName: AppSymbol.checkmarkCircleFill)
                            .foregroundColor(.green)
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("보안 PIN이 설정되어 있습니다", comment: "Secure PIN is set"))
                        Spacer()
                        Button(NSLocalizedString("변경", comment: "Change PIN button")) {
                            showPINSetup = true
                        }
                        .font(.body)
                        .accessibilityLabel(NSLocalizedString("PIN 변경", comment: "Change PIN accessibility label"))
                        .accessibilityHint(NSLocalizedString("새 PIN을 설정합니다", comment: "Change PIN hint"))
                    }
                    Button(role: .destructive) {
                        showDeletePINConfirm = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: AppSymbol.trash)
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
                            Image(systemName: AppSymbol.plusCircle)
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
                UserDefaults(suiteName: AppGroup.identifier)?.set(hash, forKey: pinKey)
                pinIsSet = true
                showPINSetup = false
            }
        }
        .alert(NSLocalizedString("보안 PIN 삭제", comment: "Delete PIN confirm title"),
               isPresented: $showDeletePINConfirm) {
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("삭제", comment: "Delete"), role: .destructive) {
                UserDefaults(suiteName: AppGroup.identifier)?.removeObject(forKey: pinKey)
                pinIsSet = false
            }
        } message: {
            Text(NSLocalizedString("PIN을 삭제하면 보안 메모 잠금이 해제됩니다. 계속하시겠습니까?", comment: "Delete PIN confirm message"))
        }
        .navigationTitle(NSLocalizedString("보안 메모 PIN", comment: "Secure memo PIN"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .solidNavBar(theme.bg)
        .onAppear {
            let storedHash = UserDefaults(suiteName: AppGroup.identifier)?.string(forKey: pinKey) ?? ""
            pinIsSet = !storedHash.isEmpty
        }
    }
}

#Preview {
    NavigationStack {
        SecurePINSettings()
    }
}
