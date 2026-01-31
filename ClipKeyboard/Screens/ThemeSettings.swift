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
            Section(header: Text("키보드 테마")) {
                Picker("테마 선택", selection: $selectedTheme) {
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
                Section(header: Text("커스텀 색상")) {
                    ColorPicker("배경 색상", selection: $backgroundColor)
                        .onChange(of: backgroundColor) { newValue in
                            keyboardBackgroundColorHex = newValue.toHex() ?? "F5F5F5"
                        }

                    ColorPicker("키 색상", selection: $keyColor)
                        .onChange(of: keyColor) { newValue in
                            keyboardKeyColorHex = newValue.toHex() ?? "FFFFFF"
                        }
                }

                Section(header: Text("미리보기")) {
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

            Section(header: Text("프리셋")) {
                Button("기본 라이트") {
                    backgroundColor = Color(hex: "F5F5F5") ?? .gray
                    keyColor = Color(hex: "FFFFFF") ?? .white
                }

                Button("기본 다크") {
                    backgroundColor = Color(hex: "1C1C1E") ?? .black
                    keyColor = Color(hex: "2C2C2E") ?? .gray
                }

                Button("파스텔 블루") {
                    backgroundColor = Color(hex: "E3F2FD") ?? .blue
                    keyColor = Color(hex: "BBDEFB") ?? .blue
                }

                Button("민트") {
                    backgroundColor = Color(hex: "E0F2F1") ?? .green
                    keyColor = Color(hex: "B2DFDB") ?? .green
                }
            }
        }
        .navigationTitle("테마 설정")
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
