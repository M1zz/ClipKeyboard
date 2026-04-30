//
//  ComboKeyboardView.swift
//  TokenKeyboard
//
//  Created by Claude Code on 2026-01-16.
//  Phase 3: Combo support in keyboard extension
//

import SwiftUI
import UIKit

struct ComboKeyboardView: View {
    @State private var executingMemoId: UUID? = nil
    @State private var refreshTrigger: Bool = false

    @AppStorage("keyboardTheme") private var keyboardTheme: String = "system"
    @AppStorage("keyboardBackgroundColor") private var keyboardBackgroundColorHex: String = "F5F5F5"
    @AppStorage("keyboardKeyColor") private var keyboardKeyColorHex: String = "FFFFFF"

    @Environment(\.colorScheme) var colorScheme

    private var gridItemLayout = [GridItem(.adaptive(minimum: 130), spacing: 10)]

    // clipMemos에서 실시간으로 Combo 메모 필터링
    private var comboMemos: [Memo] {
        clipMemos.filter { $0.isCombo && !$0.comboValues.isEmpty }
    }

    var body: some View {
        ZStack {
            backgroundColor

            if comboMemos.isEmpty {
                // 빈 상태
                VStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.forward.dottedline.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))

                    Text(NSLocalizedString("Combo가 없습니다", comment: "Empty combo list title"))
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(NSLocalizedString("앱에서 Combo를 생성해보세요", comment: "Empty combo list description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: gridItemLayout, spacing: 10) {
                        ForEach(comboMemos) { memo in
                            ComboKeyboardCard(
                                memo: memo,
                                isExecuting: executingMemoId == memo.id,
                                keyColor: keyColor,
                                onExecute: {
                                    executeCombo(memo)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }
        }
        .frame(width: UIScreen.main.bounds.size.width)
        .id(refreshTrigger) // refreshTrigger 변경 시 뷰 재생성
    }

    private func executeCombo(_ memo: Memo) {
        print("🎬 [ComboKeyboardView] Combo 실행: \(memo.title)")
        print("   현재 인덱스: \(memo.currentComboIndex), 전체: \(memo.comboValues.count)개")
        UIImpactFeedbackGenerator().impactOccurred()
        executingMemoId = memo.id

        // 현재 인덱스의 값 입력
        if !memo.comboValues.isEmpty {
            let currentValue = memo.comboValues[memo.currentComboIndex]
            print("   ✅ 입력할 값: [\(memo.currentComboIndex + 1)/\(memo.comboValues.count)] \(currentValue)")

            // 알림 전송하여 입력 (KeyboardViewController에서 처리)
            // KeyboardViewController가 currentComboIndex를 증가시키고 저장함
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: "addTextEntry"),
                object: memo.value,
                userInfo: ["memoId": memo.id]
            )
        }

        // 짧은 딜레이 후 뷰 갱신 및 실행 상태 초기화
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            executingMemoId = nil
            // clipMemos가 업데이트되었으므로 뷰 강제 갱신
            refreshTrigger.toggle()
            print("   🔄 뷰 갱신 완료")
        }
    }

    // MARK: - Theme Colors

    private var backgroundColor: Color {
        if keyboardTheme == "시스템" {
            return .clear
        } else if keyboardTheme == "라이트" {
            return .clear
        } else if keyboardTheme == "다크" {
            return .clear
        } else if keyboardTheme == "커스텀" {
            return Color(hex: keyboardBackgroundColorHex) ?? .clear
        }
        return .clear
    }

    private var keyColor: Color {
        if keyboardTheme == "시스템" {
            return defaultKeyColor
        } else if keyboardTheme == "라이트" {
            return .white
        } else if keyboardTheme == "다크" {
            return Color(red: 0.17, green: 0.17, blue: 0.18)
        } else if keyboardTheme == "커스텀" {
            return Color(hex: keyboardKeyColorHex) ?? defaultKeyColor
        }
        return defaultKeyColor
    }

    private var defaultKeyColor: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.0)
                : .white
        })
    }
}

// MARK: - Combo Card

struct ComboKeyboardCard: View {
    let memo: Memo
    let isExecuting: Bool
    let keyColor: Color
    let onExecute: () -> Void

    var body: some View {
        Button(action: {
            guard !isExecuting else { return }
            onExecute()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .foregroundColor(isExecuting ? Color.blue.opacity(0.2) : keyColor)
                    .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)

                VStack(spacing: 6) {
                    // 제목
                    Text(memo.title)
                        .foregroundColor(Color(uiColor: UIColor.label))
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)

                    // 설명 (선택적)
                    if !memo.value.isEmpty {
                        Text(memo.value)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }

                    // 항목 개수 및 현재 위치
                    HStack(spacing: 4) {
                        Image(systemName: "square.stack.3d.forward.dottedline")
                            .font(.caption2)
                            .foregroundColor(.orange)

                        Text("\(memo.comboValues.count)개 값")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(String(format: NSLocalizedString("다음: %lld", comment: "Combo next index"), memo.currentComboIndex + 1))
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }

                    // 실행 상태 표시
                    if isExecuting {
                        HStack(spacing: 4) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.7)
                            Text(NSLocalizedString("입력 중...", comment: "Combo executing"))
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 12)
            }
        }
        .disabled(isExecuting)
    }
}

#Preview {
    ComboKeyboardView()
}
