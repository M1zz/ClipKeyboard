//
//  ThemePickerView.swift
//  ClipKeyboard
//
//  Dusk / Paper 테마 선택 — 각 테마의 hero gradient로 프리뷰 카드 노출.
//

import SwiftUI

struct ThemePickerView: View {
    @EnvironmentObject private var prefs: AppThemePreference

    var body: some View {
        List {
            Section {
                ForEach(AppThemeKind.allCases) { kind in
                    ThemeOptionRow(kind: kind, isSelected: prefs.kind == kind) {
                        prefs.kind = kind
                    }
                }
            } header: {
                Text(NSLocalizedString("Theme", comment: "Settings: theme picker"))
            } footer: {
                Text(NSLocalizedString(
                    "Pick a visual direction for the app. Dusk uses a playful gradient-forward palette. Paper is warm and serif-led.",
                    comment: "Theme picker footer"
                ))
            }
        }
        .navigationTitle(NSLocalizedString("Theme", comment: "Settings: theme picker"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private struct ThemeOptionRow: View {
    let kind: AppThemeKind
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var systemColorScheme

    private var previewTheme: AppTheme {
        AppTheme.resolve(kind: kind, isDark: systemColorScheme == .dark)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Hero gradient preview swatch (48×48 rounded).
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(previewTheme.heroGradient)
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(subtitle(for: kind))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(previewTheme.accent)
                        .font(.system(size: 20))
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary.opacity(0.5))
                        .font(.system(size: 20))
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func subtitle(for kind: AppThemeKind) -> String {
        switch kind {
        case .dusk:
            return NSLocalizedString("Playful gradients · Indigo-violet accent", comment: "Dusk description")
        case .paper:
            return NSLocalizedString("Warm paper · Serif display · Terracotta accent", comment: "Paper description")
        }
    }
}

// MARK: - Appearance Mode Picker

struct AppearanceModePickerView: View {
    @EnvironmentObject private var prefs: AppThemePreference

    var body: some View {
        List {
            Section {
                ForEach(AppThemeMode.allCases) { mode in
                    Button {
                        prefs.mode = mode
                    } label: {
                        HStack {
                            Label {
                                Text(mode.displayName)
                                    .foregroundColor(.primary)
                            } icon: {
                                Image(systemName: iconName(for: mode))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if prefs.mode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(NSLocalizedString("Appearance mode", comment: "Settings: appearance mode"))
            }
        }
        .navigationTitle(NSLocalizedString("Appearance mode", comment: "Settings: appearance mode"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func iconName(for mode: AppThemeMode) -> String {
        switch mode {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}
