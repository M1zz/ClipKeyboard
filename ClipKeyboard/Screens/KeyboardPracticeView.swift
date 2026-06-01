//
//  KeyboardPracticeView.swift
//  ClipKeyboard
//

import SwiftUI

// MARK: - Practice View (Settings 진입 or Sheet 내부에서 사용)

struct KeyboardPracticeView: View {
    @Environment(\.appTheme) private var theme
    @State private var practiceText = ""
    @FocusState private var isEditorFocused: Bool

    private var isNomad: Bool {
        CategoryStore.shared.selectedPersona == .nomad
    }

    private var sampleMemos: [Memo] {
        let all = (try? MemoStore.shared.load(type: .memo)) ?? []
        if isNomad {
            let priorityIds = Set(all.filter {
                $0.category == "IBAN" || $0.category == "여권번호" || $0.category == "Passport"
            }.map { $0.id })
            let priority = all.filter { priorityIds.contains($0.id) }
            let rest = all.filter { !priorityIds.contains($0.id) }
            return Array((priority + rest).prefix(3))
        }
        return Array(all.prefix(3))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                instructionsCard
                if !sampleMemos.isEmpty { memoHintsCard }
                practiceEditor
                if !practiceText.isEmpty {
                    Button(NSLocalizedString("지우기", comment: "Clear practice text")) {
                        practiceText = ""
                    }
                    .foregroundColor(theme.textMuted)
                    .font(.body)
                }
                Spacer(minLength: 220)
            }
            .padding()
        }
        .background(theme.bg.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("키보드 연습하기", comment: "Keyboard Practice"))
        .navigationBarTitleDisplayMode(.inline)
        .solidNavBar(theme.bg)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isEditorFocused = true
            }
        }
    }

    // MARK: - Instructions Card

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                NSLocalizedString("이렇게 연습하세요", comment: "Practice instructions header"),
                systemImage: "keyboard"
            )
            .font(.headline)
            .foregroundColor(theme.text)

            PracticeStepRow(number: "1",
                            text: NSLocalizedString("아래 입력창을 탭해서 키보드를 열어요",
                                                    comment: "Practice step 1"))
            PracticeStepRow(number: "2",
                            text: NSLocalizedString("지구본(🌐) 버튼으로 ClipKeyboard로 전환해요",
                                                    comment: "Practice step 2"))
            PracticeStepRow(number: "3",
                            text: isNomad
                                ? NSLocalizedString("저장한 IBAN이나 여권번호를 탭하면 양식에 바로 입력돼요",
                                                    comment: "Practice step 3 for nomad persona")
                                : NSLocalizedString("메모를 탭하면 입력창에 바로 붙여넣어져요",
                                                    comment: "Practice step 3"))
        }
        .padding(16)
        .background(theme.surface)
        .cornerRadius(theme.radiusMd)
    }

    // MARK: - Memo Hints Card

    private var memoHintsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("저장된 메모 (키보드에서 보임)",
                                   comment: "Saved memos hint label"))
                .font(.body)
                .foregroundColor(theme.textMuted)

            ForEach(sampleMemos) { memo in
                HStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.body)
                        .foregroundColor(theme.accent)
                        .frame(width: 20)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(memo.title)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(theme.text)
                        if !memo.value.isEmpty {
                            Text(memo.value)
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surfaceAlt)
                .cornerRadius(theme.radiusSm)
            }
        }
    }

    // MARK: - Practice Editor

    private var practiceEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("입력 연습 공간", comment: "Practice text area label"))
                .font(.body)
                .foregroundColor(theme.textMuted)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $practiceText)
                    .focused($isEditorFocused)
                    .frame(minHeight: 160)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(theme.surface)
                    .cornerRadius(theme.radiusMd)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMd)
                            .stroke(isEditorFocused ? theme.accent : theme.divider, lineWidth: 1.5)
                    )

                if practiceText.isEmpty {
                    Text(NSLocalizedString("여기를 탭하고 ClipKeyboard에서 메모를 붙여넣어 보세요…",
                                          comment: "Practice editor placeholder"))
                        .font(.body)
                        .foregroundColor(theme.textFaint)
                        .padding(18)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

// MARK: - Practice Step Row

private struct PracticeStepRow: View {
    let number: String
    let text: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(theme.accent)
                .clipShape(Circle())
                .accessibilityHidden(true)

            Text(text)
                .font(.body)
                .foregroundColor(theme.text)
        }
    }
}

// MARK: - Practice Sheet (온보딩 직후 Sheet 형태 제공)

/// 온보딩 직후 sheet로 표시.
/// 프롬프트 → "지금 연습하기" 탭 → KeyboardPracticeView 전환.
struct KeyboardPracticeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var startPractice = false

    var body: some View {
        if startPractice {
            NavigationStack {
                KeyboardPracticeView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(NSLocalizedString("완료", comment: "Done button")) {
                                dismiss()
                            }
                        }
                    }
            }
        } else {
            promptView
        }
    }

    private var promptView: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "keyboard.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .accessibilityHidden(true)
                .padding(.bottom, 28)

            Text(NSLocalizedString("키보드로 바로 써볼까요?",
                                   comment: "Practice prompt title"))
                .font(.title2.weight(.bold))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

            Text(NSLocalizedString(
                "ClipKeyboard 설치가 완료됐어요!\n저장한 메모를 키보드에서 탭 한 번으로\n입력하는 연습을 지금 바로 해볼 수 있어요.",
                comment: "Practice prompt description"
            ))
            .font(.body)
            .foregroundColor(theme.textMuted)
            .multilineTextAlignment(.center)
            .lineSpacing(4)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        startPractice = true
                    }
                } label: {
                    Text(NSLocalizedString("지금 연습하기", comment: "Start practice button"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(theme.accent)
                        .cornerRadius(theme.radiusMd)
                }

                Button {
                    dismiss()
                } label: {
                    Text(NSLocalizedString("나중에 할게요", comment: "Skip practice button"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                        .padding(.vertical, 8)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
    }
}

#Preview("Practice View") {
    NavigationStack {
        KeyboardPracticeView()
    }
}

#Preview("Practice Sheet") {
    KeyboardPracticeSheet()
}
