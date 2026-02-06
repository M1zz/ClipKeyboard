//
//  ThemeSettings.swift
//  Token memo
//
//  Created by Claude Code
//

import SwiftUI

struct ThemeSettings: View {
    @AppStorage("keyboardTheme") private var keyboardTheme: String = "system"
    @AppStorage("keyboardBackgroundColor") private var keyboardBackgroundColorHex: String = "F5F5F5"
    @AppStorage("keyboardKeyColor") private var keyboardKeyColorHex: String = "FFFFFF"

    @State private var selectedTheme: KeyboardTheme = .system
    @State private var backgroundColor: Color = Color(hex: "F5F5F5") ?? .gray
    @State private var keyColor: Color = Color(hex: "FFFFFF") ?? .white

    var body: some View {
        Form {
            Section(header: Text(NSLocalizedString("키보드 테마", comment: "Keyboard theme section"))) {
                Picker(NSLocalizedString("테마 선택", comment: "Theme picker"), selection: $selectedTheme) {
                    ForEach(KeyboardTheme.allCases, id: \.self) { theme in
                        Text(theme.localizedName).tag(theme)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedTheme) { newValue in
                    keyboardTheme = newValue.rawValue
                    applyTheme(newValue)
                }
            }

            if selectedTheme == .custom {
                Section(header: Text(NSLocalizedString("커스텀 색상", comment: "Custom colors section"))) {
                    ColorPicker(NSLocalizedString("배경 색상", comment: "Background color"), selection: $backgroundColor)
                        .onChange(of: backgroundColor) { newValue in
                            keyboardBackgroundColorHex = newValue.toHex() ?? "F5F5F5"
                        }

                    ColorPicker(NSLocalizedString("키 색상", comment: "Key color"), selection: $keyColor)
                        .onChange(of: keyColor) { newValue in
                            keyboardKeyColorHex = newValue.toHex() ?? "FFFFFF"
                        }
                }

                Section(header: Text(NSLocalizedString("미리보기", comment: "Preview section"))) {
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            ForEach(["안녕", "하세요", "테스트"], id: \.self) { text in
                                Text(text)
                                    .padding()
                                    .background(keyColor)
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(backgroundColor)
                    .cornerRadius(12)
                }
            }

            Section(header: Text(NSLocalizedString("프리셋", comment: "Presets section"))) {
                Button(NSLocalizedString("기본 라이트", comment: "Default light preset")) {
                    backgroundColor = Color(hex: "F5F5F5") ?? .gray
                    keyColor = Color(hex: "FFFFFF") ?? .white
                }

                Button(NSLocalizedString("기본 다크", comment: "Default dark preset")) {
                    backgroundColor = Color(hex: "1C1C1E") ?? .black
                    keyColor = Color(hex: "2C2C2E") ?? .gray
                }

                Button(NSLocalizedString("파스텔 블루", comment: "Pastel blue preset")) {
                    backgroundColor = Color(hex: "E3F2FD") ?? .blue
                    keyColor = Color(hex: "BBDEFB") ?? .blue
                }

                Button(NSLocalizedString("민트", comment: "Mint preset")) {
                    backgroundColor = Color(hex: "E0F2F1") ?? .green
                    keyColor = Color(hex: "B2DFDB") ?? .green
                }
            }
        }
        .navigationTitle(NSLocalizedString("테마 설정", comment: "Theme settings title"))
        .onAppear {
            selectedTheme = KeyboardTheme(rawValue: keyboardTheme) ?? .system
            backgroundColor = Color(hex: keyboardBackgroundColorHex) ?? Color(hex: "F5F5F5") ?? .gray
            keyColor = Color(hex: keyboardKeyColorHex) ?? Color(hex: "FFFFFF") ?? .white
        }
    }

    private func applyTheme(_ theme: KeyboardTheme) {
        switch theme {
        case .system:
            // System will handle colors automatically
            break
        case .light:
            backgroundColor = Color(hex: "F5F5F5") ?? .gray
            keyColor = Color(hex: "FFFFFF") ?? .white
        case .dark:
            backgroundColor = Color(hex: "1C1C1E") ?? .black
            keyColor = Color(hex: "2C2C2E") ?? .gray
        case .custom:
            // User will set colors manually
            break
        }
    }
}

enum KeyboardTheme: String, CaseIterable {
    case system = "시스템"
    case light = "라이트"
    case dark = "다크"
    case custom = "커스텀"

    var localizedName: String {
        return NSLocalizedString(self.rawValue, comment: "Keyboard theme")
    }
}

struct ThemeSettings_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ThemeSettings()
        }
    }
}
