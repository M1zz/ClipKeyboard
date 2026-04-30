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

    var body: some View {
        Form {
            // Header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "tag.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        Text(NSLocalizedString("Manage categories", comment: "Category settings header"))
                            .font(.headline)
                    }
                    Text(NSLocalizedString("Add your own categories or remove ones you don't use. Defaults vary by region.",
                                           comment: "Category settings description"))
                        .font(.caption)
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
                    EditButton().font(.caption)
                }
            } footer: {
                Text(NSLocalizedString("Long-press to drag and reorder. Swipe left to delete (protected ones can't be removed).",
                                       comment: "Categories footer hint"))
                    .font(.caption)
            }

            // Reset
            Section {
                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text(NSLocalizedString("Reset to regional defaults", comment: "Reset categories button"))
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("Categories", comment: "Categories nav title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert(NSLocalizedString("Reset categories?", comment: "Reset alert title"),
               isPresented: $showResetAlert) {
            Button(NSLocalizedString("Cancel", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("Reset", comment: "Reset"), role: .destructive) {
                store.resetToDefaults()
            }
        } message: {
            Text(NSLocalizedString("Your custom categories will be removed and the list will be re-seeded based on your region.",
                                   comment: "Reset alert message"))
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
                .textFieldStyle(.roundedBorder)
                Button(NSLocalizedString("Done", comment: "Done")) {
                    if store.rename(from: category, to: renameText) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    renaming = nil
                }
                .font(.caption)
            } else {
                Text(category)
                    .foregroundColor(CategoryStore.protectedCategories.contains(category) ? .secondary : .primary)
                Spacer()
                if CategoryStore.protectedCategories.contains(category) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Button {
                        renaming = category
                        renameText = category
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
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
