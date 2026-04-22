//
//  MacPreferencesView.swift
//  ClipKeyboard.tap
//
//  Mac-native preferences window for the menu bar companion app.
//

import SwiftUI

struct MacPreferencesView: View {
    @AppStorage("macLaunchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("macClipboardMonitoring") private var clipboardMonitoring: Bool = true
    @AppStorage("macMenuBarIconStyle") private var iconStyle: String = "symbol"
    @AppStorage("macDefaultTransform") private var defaultTransform: String = "none"

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label(NSLocalizedString("General", comment: "Prefs: general"), systemImage: "gear") }

            shortcutsTab
                .tabItem { Label(NSLocalizedString("Shortcuts", comment: "Prefs: shortcuts"), systemImage: "command") }

            aboutTab
                .tabItem { Label(NSLocalizedString("About", comment: "Prefs: about"), systemImage: "info.circle") }
        }
        .frame(width: 520, height: 400)
        .padding()
    }

    // MARK: - Tabs

    private var generalTab: some View {
        Form {
            Section {
                Toggle(NSLocalizedString("Launch at login", comment: "Prefs: launch at login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
                Toggle(NSLocalizedString("Monitor clipboard in background", comment: "Prefs: clipboard monitoring"), isOn: $clipboardMonitoring)
            } header: {
                Text(NSLocalizedString("Startup", comment: "Prefs section: startup"))
                    .font(.headline)
            }

            Section {
                Picker(NSLocalizedString("Menu bar icon", comment: "Prefs: icon style"), selection: $iconStyle) {
                    Text(NSLocalizedString("Clipboard icon (recommended)", comment: "Icon: symbol")).tag("symbol")
                    Text(NSLocalizedString("Emoji", comment: "Icon: emoji")).tag("emoji")
                }
                .pickerStyle(.inline)
            } header: {
                Text(NSLocalizedString("Appearance", comment: "Prefs section: appearance"))
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
    }

    private var shortcutsTab: some View {
        Form {
            Section {
                shortcutRow(NSLocalizedString("Open memo list", comment: "Shortcut: memo list"), keys: "⌃⌥K")
                shortcutRow(NSLocalizedString("New memo", comment: "Shortcut: new memo"), keys: "⌃⌥N")
                shortcutRow(NSLocalizedString("Clipboard history", comment: "Shortcut: clipboard history"), keys: "⌃⌥H")
                shortcutRow(NSLocalizedString("iCloud backup", comment: "Shortcut: iCloud backup"), keys: "⌃⌥B")
                shortcutRow(NSLocalizedString("Preferences", comment: "Shortcut: preferences"), keys: "⌘,")
            } header: {
                Text(NSLocalizedString("Global Shortcuts", comment: "Prefs section: global shortcuts"))
                    .font(.headline)
            } footer: {
                Text(NSLocalizedString("ClipKeyboard needs Accessibility permission to register global shortcuts. Grant access in System Settings → Privacy & Security → Accessibility.", comment: "Accessibility note"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .padding(.top, 12)

            Text("ClipKeyboard")
                .font(.title2)
                .fontWeight(.semibold)

            Text(NSLocalizedString("Version %@", comment: "Version label format"))
                .font(.caption)
                .foregroundColor(.secondary)
                .overlay(alignment: .center) {
                    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
                    Text(String(format: NSLocalizedString("Version %@", comment: "Version label format"), version))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

            Divider().padding(.vertical, 8)

            VStack(spacing: 8) {
                Link(NSLocalizedString("View User Guide", comment: "About: user guide"),
                     destination: URL(string: "https://leeo75.notion.site/ClipKeyboard-tutorial-70624fccc524465f99289c89bd0261a4?pvs=4")!)

                Link(NSLocalizedString("Send Feedback", comment: "About: feedback"),
                     destination: URL(string: "mailto:leeo@kakao.com")!)
            }
            .font(.subheadline)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Helpers

    private func shortcutRow(_ label: String, keys: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        // SMAppService는 macOS 13+에서 사용. LaunchAtLogin 기능은 entitlement + SMAppService.mainApp.register/unregister 조합.
        // 간단 구현 — 실제 sandbox 앱에서는 SMAppService.mainApp 사용 필요. 여기서는 사용자 선호만 저장.
        print("🔧 [Prefs] Launch at login: \(enabled) (persisted; SMAppService 등록은 별도 구현 필요)")
    }
}
