//
//  KeyboardLayoutSettings.swift
//  Token memo
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
    }

    private func resetToDefaults() {
        columnCount = 2
        buttonHeight = 40.0
        buttonFontSize = 15.0
    }
}

#Preview {
    NavigationStack {
        KeyboardLayoutSettings()
    }
}
