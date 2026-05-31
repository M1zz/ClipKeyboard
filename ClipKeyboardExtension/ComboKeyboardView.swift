//
//  ComboKeyboardView.swift
//  TokenKeyboard
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

    private var gridItemLayout = [GridItem(.adaptive(minimum: 150), spacing: 8)]

    private var comboMemos: [Memo] {
        clipMemos.filter { $0.isCombo && !$0.comboValues.isEmpty }
    }

    var body: some View {
        ZStack {
            backgroundColor

            if comboMemos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.forward.dottedline.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.gray.opacity(0.4))
                    Text(NSLocalizedString("Combo가 없습니다", comment: "Empty combo list title"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("앱에서 Combo를 생성해보세요", comment: "Empty combo list description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: gridItemLayout, spacing: 8) {
                        ForEach(comboMemos) { memo in
                            ComboKeyboardCard(
                                memo: memo,
                                isExecuting: executingMemoId == memo.id,
                                keyColor: keyColor,
                                onInsert: { executeCombo(memo) },
                                onSkip: { skipCombo(memo) }
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .id(refreshTrigger)
    }

    private func executeCombo(_ memo: Memo) {
        guard !memo.comboValues.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        executingMemoId = memo.id
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: "addTextEntry"),
            object: memo.value,
            userInfo: ["memoId": memo.id]
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            executingMemoId = nil
            refreshTrigger.toggle()
        }
    }

    private func skipCombo(_ memo: Memo) {
        guard !memo.comboValues.isEmpty else { return }
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: "skipComboEntry"),
            object: nil,
            userInfo: ["memoId": memo.id]
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            refreshTrigger.toggle()
        }
    }

    // MARK: - Theme Colors

    private var backgroundColor: Color {
        keyboardTheme == "커스텀" ? (Color(hex: keyboardBackgroundColorHex) ?? .clear) : .clear
    }

    private var keyColor: Color {
        switch keyboardTheme {
        case "라이트": return .white
        case "다크": return Color(red: 0.17, green: 0.17, blue: 0.18)
        case "커스텀": return Color(hex: keyboardKeyColorHex) ?? defaultKeyColor
        default: return defaultKeyColor
        }
    }

    private var defaultKeyColor: Color {
        Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark
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
    let onInsert: () -> Void
    let onSkip: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var theme: AppTheme {
        AppTheme.resolve(kind: .paper, isDark: colorScheme == .dark)
    }

    private var safeIndex: Int {
        memo.currentComboIndex < memo.comboValues.count ? memo.currentComboIndex : 0
    }
    private var currentValue: String { memo.comboValues[safeIndex] }
    private var total: Int { memo.comboValues.count }

    var body: some View {
        HStack(spacing: 0) {
            // ── 좌: 입력 버튼 ──────────────────────────────
            Button(action: {
                guard !isExecuting else { return }
                onInsert()
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    // 제목
                    Text(memo.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(uiColor: .label))
                        .lineLimit(1)

                    // 인덱스 배지
                    HStack(spacing: 4) {
                        Text("\(safeIndex + 1) / \(total)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                        if isExecuting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.65)
                        }
                    }

                    // 현재 값 미리보기
                    Text(currentValue)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(isExecuting)

            // 구분선
            Divider()
                .frame(width: 0.5)
                .background(Color(uiColor: .separator))

            // ── 우: 스킵 버튼 ──────────────────────────────
            Button(action: onSkip) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.orange.opacity(0.7))
                    .frame(width: 40)
                    .frame(maxHeight: .infinity)
            }
            .disabled(isExecuting)
        }
        .background(
            RoundedRectangle(cornerRadius: theme.radiusSm)
                .fill(isExecuting ? Color.orange.opacity(0.08) : keyColor)
                .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusSm)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm))
        .frame(height: 68)
    }
}

#Preview {
    ComboKeyboardView()
}
