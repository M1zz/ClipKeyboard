//
//  ComboEditSheet.swift
//  ClipKeyboard
//
//  콤보는 이제 comboValues(이어지는 단계)를 가진 일반 Memo다. 콤보 메모를 탭하면
//  통합 메모 편집기(MemoAdd)를 열어 본문 + 이어지는 메모를 함께 편집한다.
//

import SwiftUI

// MARK: - Combo Sheet Resolver

struct ComboSheetResolver: View {
    let comboId: UUID
    let allMemos: [Memo]
    let onDismiss: () -> Void
    @Environment(\.appTheme) private var theme

    @State private var loadedMemo: Memo? = nil

    var body: some View {
        Group {
            if let memo = loadedMemo {
                NavigationStack {
                    // 통합 편집기 — 본문(1단계) + 이어지는 단계(comboValues)를 편집.
                    MemoAdd(
                        memoId: memo.id,
                        insertedKeyword: memo.title,
                        insertedValue: memo.comboValues.first ?? memo.value,
                        insertedCategory: memo.category,
                        insertedIsSecure: memo.isSecure
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(NSLocalizedString("취소", comment: "Cancel")) { onDismiss() }
                        }
                    }
                }
                .onDisappear { onDismiss() }
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
