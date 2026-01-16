//
//  ComboKeyboardView.swift
//  TokenKeyboard
//
//  Created by Claude Code on 2026-01-16.
//  Phase 3: Combo support in keyboard extension
//

import SwiftUI

struct ComboKeyboardView: View {
    @State private var combos: [Combo] = []
    @State private var executingComboId: UUID? = nil
    @StateObject private var executionService = ComboExecutionService.shared

    @AppStorage("keyboardTheme") private var keyboardTheme: String = "system"
    @AppStorage("keyboardBackgroundColor") private var keyboardBackgroundColorHex: String = "F5F5F5"
    @AppStorage("keyboardKeyColor") private var keyboardKeyColorHex: String = "FFFFFF"

    @Environment(\.colorScheme) var colorScheme

    private var gridItemLayout = [GridItem(.adaptive(minimum: 130), spacing: 10)]

    var body: some View {
        ZStack {
            backgroundColor

            if combos.isEmpty {
                // 빈 상태
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.badge.play")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))

                    Text("Combo가 없습니다")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("앱에서 Combo를 생성해보세요")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: gridItemLayout, spacing: 10) {
                        ForEach(combos) { combo in
                            ComboKeyboardCard(
                                combo: combo,
                                isExecuting: executingComboId == combo.id,
                                executionState: executionService.state,
                                keyColor: keyColor,
                                onExecute: {
                                    executeCombo(combo)
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
        .onAppear {
            loadCombos()
        }
    }

    private func loadCombos() {
        do {
            combos = try MemoStore.shared.loadCombos()
            print("📦 [ComboKeyboardView] Combo 로드 완료: \(combos.count)개")
        } catch {
            print("❌ [ComboKeyboardView] Combo 로드 실패: \(error)")
            combos = []
        }
    }

    private func executeCombo(_ combo: Combo) {
        print("🎬 [ComboKeyboardView] Combo 실행: \(combo.title)")
        UIImpactFeedbackGenerator().impactOccurred()
        executingComboId = combo.id

        Task {
            ComboExecutionService.shared.startCombo(combo)

            // 실행 완료 후 3초 뒤 초기화
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if case .completed = ComboExecutionService.shared.state {
                executingComboId = nil
            }
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
    let combo: Combo
    let isExecuting: Bool
    let executionState: ComboExecutionState
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

                VStack(spacing: 4) {
                    // 제목
                    Text(combo.title)
                        .foregroundStyle(Color(uiColor: .label))
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)

                    // 항목 개수
                    Text(String(format: NSLocalizedString("%lld개 항목", comment: ""), combo.items.count))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    // 실행 상태 표시
                    if isExecuting {
                        executionStatusView
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 12)
            }
        }
        .disabled(isExecuting)
    }

    @ViewBuilder
    private var executionStatusView: some View {
        switch executionState {
        case .running(let currentIndex, let totalCount):
            VStack(spacing: 4) {
                ProgressView(value: Double(currentIndex + 1), total: Double(totalCount))
                    .progressViewStyle(.linear)
                    .tint(.blue)

                Text("\(currentIndex + 1) / \(totalCount)")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            .padding(.top, 4)

        case .completed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("완료!")
                    .foregroundColor(.green)
            }
            .font(.caption)
            .padding(.top, 4)

        case .error(let message):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("오류")
                    .foregroundColor(.red)
            }
            .font(.caption2)
            .padding(.top, 4)

        default:
            EmptyView()
        }
    }
}

#Preview {
    ComboKeyboardView()
}
