//
//  CategorySettings.swift
//  ClipKeyboard
//
//  사용자 카테고리 관리 — 추가/이름변경/삭제/순서변경.
//  CategoryStore (App Group 영구 저장)와 연동.
//

import SwiftUI

struct CategorySettings: View {
    @StateObject private var store = CategoryStore.shared
    @State private var newCategoryName: String = ""
    @State private var renaming: String? = nil
    @State private var renameText: String = ""
    @State private var showResetAlert = false
    @Environment(\.appTheme) private var theme

    var body: some View {
        Form {
            // Header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "tag.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("Manage categories", comment: "Category settings header"))
                            .font(.headline)
                    }
                    Text(NSLocalizedString("Add your own categories or remove ones you don't use. Defaults vary by region.",
                                           comment: "Category settings description"))
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            // Add new
            Section {
                HStack {
                    TextField(NSLocalizedString("New category name", comment: "Add category placeholder"),
                              text: $newCategoryName)
                        .textInputAutocapitalization(.words)
                    Button(NSLocalizedString("Add", comment: "Add")) {
                        if store.add(newCategoryName) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            newCategoryName = ""
                        } else {
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        }
                    }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            } header: {
                Text(NSLocalizedString("Add new", comment: "Add new section header"))
            }

            // Existing list
            Section {
                ForEach(store.allCategories, id: \.self) { category in
                    categoryRow(category)
                }
                .onMove { source, destination in
                    store.move(from: source, to: destination)
                }
                .onDelete { indices in
                    for idx in indices {
                        let name = store.allCategories[idx]
                        if !store.remove(name) {
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        }
                    }
                }
            } header: {
                HStack {
                    Text(String(format: NSLocalizedString("%d categories", comment: "Categories count header"),
                                store.allCategories.count))
                    Spacer()
                    EditButton().font(.body)
                }
            } footer: {
                Text(NSLocalizedString("Long-press to drag and reorder. Swipe left to delete (protected ones can't be removed).",
                                       comment: "Categories footer hint"))
                    .font(.body)
            }

            // Remove all
            if !store.allCategories.isEmpty {
                Section {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .accessibilityHidden(true)
                            Text(NSLocalizedString("Remove all categories", comment: "Remove all categories button"))
                        }
                    }
                    .accessibilityHint(NSLocalizedString("모든 카테고리를 삭제합니다. 메모는 유지됩니다.", comment: "Remove all categories hint"))
                }
            }
        }
        .navigationTitle(NSLocalizedString("Categories", comment: "Categories nav title"))
        .onAppear { store.reload() } // 키보드 컨텍스트 메뉴 등 다른 경로의 변경 반영 (통일된 단일 목록)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbarBackground(theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert(NSLocalizedString("Remove all categories?", comment: "Remove all categories alert title"),
               isPresented: $showResetAlert) {
            Button(NSLocalizedString("Cancel", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("Remove all", comment: "Remove all"), role: .destructive) {
                store.removeAll()
            }
        } message: {
            Text(NSLocalizedString("All categories will be deleted. Your memos are kept (they just won't have a category tab).",
                                   comment: "Remove all categories alert message"))
        }
    }

    @ViewBuilder
    private func categoryRow(_ category: String) -> some View {
        HStack {
            if renaming == category {
                TextField(category, text: $renameText, onCommit: {
                    if store.rename(from: category, to: renameText) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    renaming = nil
                })
                .clipRoundedField()
                .accessibilityLabel(NSLocalizedString("새 카테고리 이름", comment: "Rename category field"))
                Button(NSLocalizedString("Done", comment: "Done")) {
                    if store.rename(from: category, to: renameText) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    renaming = nil
                }
                .font(.body)
            } else {
                Text(NSLocalizedString(category, comment: "Category name"))
                    .foregroundColor(CategoryStore.protectedCategories.contains(category) ? .secondary : .primary)
                Spacer()
                if CategoryStore.protectedCategories.contains(category) {
                    Image(systemName: "lock.fill")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .accessibilityLabel(NSLocalizedString("기본 카테고리 (삭제 불가)", comment: "Protected category lock icon"))
                } else {
                    Button {
                        renaming = category
                        renameText = category
                    } label: {
                        Image(systemName: "pencil")
                            .font(.body)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(NSLocalizedString("이름 변경", comment: "Rename category button"))
                    .accessibilityHint(String(format: NSLocalizedString("%@ 카테고리 이름을 변경합니다", comment: "Rename category hint"), category))
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategorySettings()
    }
}
