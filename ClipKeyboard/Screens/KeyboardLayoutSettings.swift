//
//  KeyboardLayoutSettings.swift
//  ClipKeyboard
//
//  Created by Claude Code on 2026-01-28.
//  키보드 레이아웃 및 버튼 크기 설정
//

import SwiftUI

struct KeyboardLayoutSettings: View {
    @AppStorage("keyboardColumnCount", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo"))
    private var columnCount: Int = 2

    @AppStorage("keyboardButtonHeight", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo"))
    private var buttonHeight: Double = 40.0

    @AppStorage("keyboardButtonFontSize", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo"))
    private var buttonFontSize: Double = 15.0

    // 색상 커스터마이즈 — 기본 false (Paper 테마 사용)
    @AppStorage("keyboardUseCustomColors", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo"))
    private var useCustomColors: Bool = false

    @AppStorage("keyboardCustomBgHex", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo"))
    private var customBgHex: String = ""

    @AppStorage("keyboardCustomKeyHex", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo"))
    private var customKeyHex: String = ""

    // ColorPicker 바인딩용 임시 Color (hex로 변환 후 저장)
    @State private var customBgColor: Color = .clear
    @State private var customKeyColor: Color = .clear

    // 옵션 토글
    @AppStorage("keyboardShowSearch", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo"))
    private var showSearchBar: Bool = false

    @AppStorage("keyboardShowRecent", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo"))
    private var showRecentSection: Bool = false

    // 한글 레이아웃 — 두벌식 / 천지인
    @AppStorage("keyboardKoreanLayout", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo"))
    private var koreanLayoutRaw: String = "dubeolsik"

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("⚙️ 키보드 레이아웃 설정", comment: "Keyboard layout settings header"))
                        .font(.headline)
                    Text(NSLocalizedString("키보드의 열 개수와 버튼 크기를 조정할 수 있습니다.", comment: "Keyboard layout settings description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section(NSLocalizedString("열 개수", comment: "Column count section")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(NSLocalizedString("열 개수", comment: "Column count label"))
                        Spacer()
                        Text(String(format: NSLocalizedString("%d열", comment: "Column count value"), columnCount))
                            .foregroundColor(.secondary)
                    }

                    Picker(NSLocalizedString("열 개수", comment: "Column count picker"), selection: $columnCount) {
                        ForEach(1...5, id: \.self) { count in
                            Text(String(format: NSLocalizedString("%d열", comment: "Column count option"), count)).tag(count)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(NSLocalizedString("화면에 표시될 버튼의 열 개수를 선택하세요. 열이 많을수록 더 많은 버튼을 한 눈에 볼 수 있습니다.", comment: "Column count description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(NSLocalizedString("버튼 크기", comment: "Button size section")) {
                VStack(alignment: .leading, spacing: 16) {
                    // 높이 슬라이더
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(NSLocalizedString("버튼 높이", comment: "Button height label"))
                            Spacer()
                            Text("\(Int(buttonHeight))pt")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $buttonHeight, in: 20...60, step: 1)
                            .tint(.blue)

                        HStack {
                            Text(NSLocalizedString("작게", comment: "Small size label"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(NSLocalizedString("크게", comment: "Large size label"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // 폰트 크기 슬라이더
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(NSLocalizedString("글자 크기", comment: "Font size label"))
                            Spacer()
                            Text("\(Int(buttonFontSize))pt")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $buttonFontSize, in: 10...20, step: 1)
                            .tint(.blue)

                        HStack {
                            Text(NSLocalizedString("작게", comment: "Small size label"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(NSLocalizedString("크게", comment: "Large size label"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section {
                Picker(selection: $koreanLayoutRaw) {
                    Text(NSLocalizedString("두벌식 (표준)", comment: "Korean layout: 2-set standard"))
                        .tag("dubeolsik")
                    Text(NSLocalizedString("천지인 (3x3)", comment: "Korean layout: cheonjiin"))
                        .tag("cheonjiin")
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Korean layout", comment: "Picker: Korean keyboard layout"))
                        Text(NSLocalizedString("Used when typing in Korean (한 toggle).", comment: "Picker desc: Korean layout"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(NSLocalizedString("Korean keyboard", comment: "Section: Korean keyboard"))
            } footer: {
                Text(NSLocalizedString("두벌식 = full QWERTY-style. 천지인 = 9-key layout common on older Korean phones.", comment: "Footer: Korean layouts"))
                    .font(.caption)
            }

            Section {
                Toggle(isOn: $showSearchBar) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Search bar", comment: "Toggle: show search bar in keyboard"))
                        Text(NSLocalizedString("Type to filter snippets. Adds a search input above the grid.", comment: "Toggle desc: search bar"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Toggle(isOn: $showRecentSection) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Recent snippets", comment: "Toggle: show recent section"))
                        Text(NSLocalizedString("Pin the last 5 used snippets at the top of the keyboard.", comment: "Toggle desc: recent"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(NSLocalizedString("Keyboard sections", comment: "Section: keyboard sections"))
            } footer: {
                Text(NSLocalizedString("Both options off by default — your snippet grid gets more room. Toggle on as needed.", comment: "Section footer: keyboard sections"))
                    .font(.caption)
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $useCustomColors) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("Custom keyboard colors", comment: "Toggle: use custom colors"))
                            Text(NSLocalizedString("Override the default Paper theme with your own colors.", comment: "Toggle description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if useCustomColors {
                        Divider()

                        ColorPicker(NSLocalizedString("Background", comment: "Color picker: keyboard background"),
                                    selection: $customBgColor, supportsOpacity: false)
                            .onChange(of: customBgColor) { newColor in
                                customBgHex = newColor.toHex() ?? ""
                            }

                        ColorPicker(NSLocalizedString("Key", comment: "Color picker: keyboard key"),
                                    selection: $customKeyColor, supportsOpacity: false)
                            .onChange(of: customKeyColor) { newColor in
                                customKeyHex = newColor.toHex() ?? ""
                            }

                        Button {
                            customBgHex = ""
                            customKeyHex = ""
                            customBgColor = .clear
                            customKeyColor = .clear
                        } label: {
                            HStack {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.caption)
                                Text(NSLocalizedString("Reset to theme defaults", comment: "Button: reset custom colors"))
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
            } header: {
                Text(NSLocalizedString("Keyboard colors", comment: "Section: keyboard colors"))
            } footer: {
                Text(NSLocalizedString("Default uses your iOS app theme. Toggle on to override with your own colors.", comment: "Section footer: keyboard colors"))
                    .font(.caption)
            }

            Section(NSLocalizedString("미리보기", comment: "Preview section")) {
                VStack(spacing: 8) {
                    Text(NSLocalizedString("버튼 미리보기", comment: "Button preview label"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // 미리보기 버튼
                    Button(action: {}) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
                            Text(NSLocalizedString("예시 버튼", comment: "Example button text"))
                                .foregroundColor(.primary)
                                .font(.system(size: buttonFontSize, weight: .semibold))
                                .padding(.vertical, (buttonHeight - buttonFontSize) / 2)
                        }
                    }
                    .frame(height: buttonHeight)
                    .disabled(true)

                    Text(NSLocalizedString("실제 키보드에 적용된 크기로 표시됩니다.", comment: "Preview description"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                Button {
                    resetToDefaults()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text(NSLocalizedString("기본값으로 되돌리기", comment: "Reset to defaults button"))
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(NSLocalizedString("레이아웃 설정", comment: "Layout settings title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            // 저장된 hex 값을 ColorPicker 초기값으로 동기화
            if !customBgHex.isEmpty, let c = Color(hex: customBgHex) {
                customBgColor = c
            }
            if !customKeyHex.isEmpty, let c = Color(hex: customKeyHex) {
                customKeyColor = c
            }
        }
    }

    private func resetToDefaults() {
        columnCount = 2
        buttonHeight = 40.0
        buttonFontSize = 15.0
        useCustomColors = false
        customBgHex = ""
        customKeyHex = ""
        customBgColor = .clear
        customKeyColor = .clear
        showSearchBar = false
        showRecentSection = false
        koreanLayoutRaw = "dubeolsik"
    }
}

#Preview {
    NavigationStack {
        KeyboardLayoutSettings()
    }
}
