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
                    Text("⚙️ 키보드 레이아웃 설정")
                        .font(.headline)
                    Text("키보드의 열 개수와 버튼 크기를 조정할 수 있습니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("열 개수") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("열 개수")
                        Spacer()
                        Text("\(columnCount)열")
                            .foregroundColor(.secondary)
                    }

                    Picker("열 개수", selection: $columnCount) {
                        ForEach(1...5, id: \.self) { count in
                            Text("\(count)열").tag(count)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("화면에 표시될 버튼의 열 개수를 선택하세요. 열이 많을수록 더 많은 버튼을 한 눈에 볼 수 있습니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("버튼 크기") {
                VStack(alignment: .leading, spacing: 16) {
                    // 높이 슬라이더
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("버튼 높이")
                            Spacer()
                            Text("\(Int(buttonHeight))pt")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $buttonHeight, in: 20...60, step: 1)
                            .tint(.blue)

                        HStack {
                            Text("작게")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("크게")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // 폰트 크기 슬라이더
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("글자 크기")
                            Spacer()
                            Text("\(Int(buttonFontSize))pt")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $buttonFontSize, in: 10...20, step: 1)
                            .tint(.blue)

                        HStack {
                            Text("작게")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("크게")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section("미리보기") {
                VStack(spacing: 8) {
                    Text("버튼 미리보기")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // 미리보기 버튼
                    Button(action: {}) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
                            Text("예시 버튼")
                                .foregroundColor(.primary)
                                .font(.system(size: buttonFontSize, weight: .semibold))
                                .padding(.vertical, (buttonHeight - buttonFontSize) / 2)
                        }
                    }
                    .frame(height: buttonHeight)
                    .disabled(true)

                    Text("실제 키보드에 적용된 크기로 표시됩니다.")
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
                        Text("기본값으로 되돌리기")
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("레이아웃 설정")
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
