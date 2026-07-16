//
//  DraftListView.swift
//  ClipKeyboard
//
//  "임시 저장 보기" — 단축어(메모)를 만들다가 저장하지 않고 나간 미완성 입력 목록.
//  탭하면 이어서 작성(정식 저장 시 목록에서 사라짐), 스와이프로 삭제.
//

import SwiftUI
import LeeoKit

struct DraftListView: View {
    @ObservedObject private var store = DraftStore.shared
    @Environment(\.appTheme) private var theme
    @State private var resumeTarget: SavedDraft?

    var body: some View {
        Group {
            if store.drafts.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(store.drafts) { draft in
                        Button {
                            HapticManager.shared.light()
                            resumeTarget = draft
                        } label: {
                            row(draft)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        for i in offsets { store.remove(store.drafts[i].id) }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(NSLocalizedString("임시 저장", comment: "Drafts screen title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $resumeTarget) { draft in
            NavigationStack {
                MemoAdd(
                    insertedKeyword: draft.keyword,
                    insertedValue: draft.value,
                    insertedCategory: draft.category,
                    insertedIsSecure: draft.isSecure,
                    insertedHint: draft.hint,
                    insertedIsFavorite: draft.isFavorite,
                    resumeDraftId: draft.id
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(NSLocalizedString("취소", comment: "Cancel")) { resumeTarget = nil }
                    }
                }
            }
        }
    }

    private func row(_ draft: SavedDraft) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(draft.displayTitle)
                    .font(.body.weight(.semibold))
                    .foregroundColor(theme.text)
                    .lineLimit(1)
                Spacer()
                Text(draft.savedAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(theme.textMuted)
            }
            if !draft.previewLine.isEmpty {
                Text(draft.previewLine.templateAwareAttributed(theme: theme, font: .subheadline))
                    .font(.subheadline)
                    .foregroundColor(theme.textMuted)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: AppSymbol.trayFull)
                .font(.system(size: 44))
                .foregroundColor(theme.textMuted)
            Text(NSLocalizedString("임시 저장된 항목이 없어요", comment: "Drafts empty state title"))
                .font(.headline)
                .foregroundColor(theme.text)
            Text(NSLocalizedString("단축어를 만들다 저장하지 않고 나가면 여기에 자동으로 보관돼요.", comment: "Drafts empty state subtitle"))
                .font(.subheadline)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
