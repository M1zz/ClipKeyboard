//
//  ComboEditSheet.swift
//  ClipKeyboard
//
//  콤보는 comboValues(이어지는 단계)를 가진 일반 Memo다. 콤보 메모를 탭하면
//  단계 값들이 즉시 클립보드에 복사되고, 어떤 값들이 (키보드에서 순서대로) 입력될지
//  보여주는 미리보기 하프모달(ComboPreviewSheet)이 뜬다. 편집은 롱프레스 → 수정.
//

import SwiftUI

// MARK: - Combo Preview Sheet (탭 시 즉시 복사 + 순차 입력될 값 미리보기)

struct ComboPreviewSheet: View {
    let comboId: UUID
    let allMemos: [Memo]
    let onDismiss: () -> Void
    @Environment(\.appTheme) private var theme

    @State private var loadedMemo: Memo?

    var body: some View {
        Group {
            if let memo = loadedMemo {
                content(for: memo)
            } else {
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.5)
                    Text(NSLocalizedString("불러오는 중...", comment: "Loading"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.bg)
                .onAppear { loadMemo() }
            }
        }
        .onDisappear { onDismiss() }
    }

    /// 단계 값(자동 변수 치환). 커스텀 토큰({이름} 등)은 키보드 동작과 동일하게 그대로 둔다.
    private func resolvedSteps(for memo: Memo) -> [String] {
        memo.comboValues.map { TemplateVariableProcessor.process($0) }
    }

    @ViewBuilder
    private func content(for memo: Memo) -> some View {
        let steps = resolvedSteps(for: memo)
        VStack(alignment: .leading, spacing: 0) {
            // 헤더 — 콤보 제목
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundColor(theme.accent)
                    .accessibilityHidden(true)
                Text(memo.title)
                    .font(.headline)
                    .foregroundColor(theme.text)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 4)

            // 복사됨 안내
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundColor(.green)
                    .accessibilityHidden(true)
                Text(NSLocalizedString("클립보드에 복사됐어요", comment: "Combo preview: copied to clipboard"))
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .accessibilityElement(children: .combine)

            // 순차 입력될 단계 값 목록
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(idx + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(theme.accent))
                            Text(step.isEmpty ? "—" : step)
                                .font(.body)
                                .foregroundColor(theme.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(String(
                            format: NSLocalizedString("%d단계: %@", comment: "Combo preview step: order and value"),
                            idx + 1, step.isEmpty ? "—" : step))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            // 키보드 안내
            HStack(spacing: 6) {
                Image(systemName: "keyboard")
                    .font(.caption)
                    .foregroundColor(theme.textFaint)
                    .accessibilityHidden(true)
                Text(NSLocalizedString("키보드에서 이 순서로 입력돼요", comment: "Combo preview: typed in this order on the keyboard"))
                    .font(.caption)
                    .foregroundColor(theme.textFaint)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bg)
    }

    private func loadMemo() {
        if let memo = allMemos.first(where: { $0.id == comboId }) {
            loadedMemo = memo
            return
        }
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        loadedMemo = memos.first(where: { $0.id == comboId })
    }
}
