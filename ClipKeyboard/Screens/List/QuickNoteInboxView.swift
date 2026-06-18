//
//  QuickNoteInboxView.swift
//  ClipKeyboard
//
//  빠른 메모(Inbox) 보관함 화면 — 어디서든 빠르게 담아둔 결정-보류 항목들을 모아 보여주고,
//  사용자가 항목별로 "메모로 저장"(승격)하거나 "삭제"하도록 한다.
//  애플 메모앱의 "빠른 메모"를 본떠, 키보드 메모로 쓸지 여부를 나중에 결정하게 하는 받은편지함.
//

import SwiftUI

struct QuickNoteInboxView: View {
    @ObservedObject private var store = QuickNoteStore.shared

    @State private var noteToEdit: QuickNote?
    @State private var noteToDelete: QuickNote?
    @State private var showAddSheet = false
    @State private var promotedToast: String?

    var body: some View {
        Group {
            if store.quickNotes.isEmpty {
                emptyState
            } else {
                inboxList
            }
        }
        .navigationTitle(NSLocalizedString("Inbox", comment: "Quick note inbox screen title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: AppSymbol.plusCircleFill)
                }
                .accessibilityLabel(NSLocalizedString("Add Quick Note", comment: "Add quick note button"))
            }
        }
        .sheet(item: $noteToEdit) { note in
            QuickNoteEditSheet(note: note) { updated in
                store.update(updated)
            } onPromote: { promoted in
                store.update(promoted)            // 편집 내용 먼저 반영
                store.promoteToMemo(promoted)
                promotedToast = promoted.displayTitle
            }
        }
        .sheet(isPresented: $showAddSheet) {
            QuickNoteEditSheet(note: QuickNote()) { newNote in
                guard !newNote.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                store.add(newNote)
            } onPromote: { newNote in
                guard !newNote.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                store.add(newNote)
                store.promoteToMemo(newNote)
                promotedToast = newNote.displayTitle
            }
        }
        .alert(
            NSLocalizedString("Delete this quick note?", comment: "Delete quick note confirmation"),
            isPresented: Binding(get: { noteToDelete != nil }, set: { if !$0 { noteToDelete = nil } })
        ) {
            Button(NSLocalizedString("Delete", comment: "Delete"), role: .destructive) {
                if let note = noteToDelete {
                    store.remove(note.id, deleteImages: true)
                }
                noteToDelete = nil
            }
            Button(NSLocalizedString("Cancel", comment: "Cancel"), role: .cancel) { noteToDelete = nil }
        } message: {
            Text(NSLocalizedString("This quick note will be permanently removed from your inbox.", comment: "Delete quick note message"))
        }
    }

    // MARK: - List

    private var inboxList: some View {
        List {
            Section {
                ForEach(store.quickNotes) { note in
                    QuickNoteRow(note: note)
                        .contentShape(Rectangle())
                        .onTapGesture { noteToEdit = note }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                noteToDelete = note
                            } label: {
                                Label(NSLocalizedString("Delete", comment: "Delete"), systemImage: AppSymbol.trash)
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                store.promoteToMemo(note)
                                promotedToast = note.displayTitle
                            } label: {
                                Label(NSLocalizedString("Save as Memo", comment: "Promote quick note to memo"),
                                      systemImage: AppSymbol.squareAndPencil)
                            }
                            .tint(.blue)
                        }
                }
            } header: {
                Text(NSLocalizedString("Tap to edit · Swipe right to save as a keyboard memo", comment: "Inbox list hint"))
                    .textCase(nil)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: AppSymbol.trayFull)
                .font(.system(size: 52))
                .foregroundColor(.secondary)
            Text(NSLocalizedString("Your inbox is empty", comment: "Empty inbox title"))
                .font(.title3.bold())
            Text(NSLocalizedString("Quickly capture anything from the Share Sheet, Shortcuts, or Control Center. Decide later whether to keep it as a keyboard memo.", comment: "Empty inbox description"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showAddSheet = true
            } label: {
                Label(NSLocalizedString("Add Quick Note", comment: "Add quick note button"), systemImage: AppSymbol.plusCircleFill)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

private struct QuickNoteRow: View {
    let note: QuickNote

    var body: some View {
        HStack(spacing: 12) {
            if note.hasImages, let first = note.imageFileNames.first,
               let image = MemoStore.shared.loadImage(fileName: first) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: note.hasImages ? AppSymbol.photo : AppSymbol.docText)
                            .foregroundColor(.secondary)
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(note.displayTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if !note.text.isEmpty {
                    Text(note.text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Text(relativeTime(note.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Inbox Banner (메인 리스트 상단 노출)

/// 보관함에 분류 대기 항목이 있을 때 메인 리스트 상단에 뜨는 배너.
/// 메뉴 속에 숨지 않고 "N개 대기 · 정리하기"를 노출해 발견성을 높인다.
struct QuickNoteInboxBanner: View {
    let count: Int
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: AppSymbol.trayFull)
                .font(.title3)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("Inbox", comment: "Quick note inbox title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Text(String(format: NSLocalizedString("%d waiting to be sorted", comment: "Inbox banner subtitle with count"), count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: AppSymbol.chevronRight)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            // 닫기 — 행 탭과 분리된 단일 버튼(중첩 버튼 회피)
            Image(systemName: AppSymbol.xmarkCircleFill)
                .foregroundColor(Color.secondary.opacity(0.6))
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }
                .accessibilityLabel(NSLocalizedString("Dismiss", comment: "Dismiss banner"))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Edit / Add Sheet

private struct QuickNoteEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: QuickNote
    let onSave: (QuickNote) -> Void
    let onPromote: (QuickNote) -> Void

    init(note: QuickNote, onSave: @escaping (QuickNote) -> Void, onPromote: @escaping (QuickNote) -> Void) {
        self._draft = State(initialValue: note)
        self.onSave = onSave
        self.onPromote = onPromote
    }

    private var canSave: Bool {
        !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.hasImages
    }

    var body: some View {
        NavigationStack {
            Form {
                if draft.hasImages {
                    Section(NSLocalizedString("Image", comment: "Image section")) {
                        imagePreview
                    }
                }
                Section(NSLocalizedString("Content", comment: "Content section")) {
                    TextField(
                        NSLocalizedString("Quick note", comment: "Quick note text field placeholder"),
                        text: $draft.text,
                        axis: .vertical
                    )
                    .lineLimit(3...10)
                }
            }
            .navigationTitle(NSLocalizedString("Quick Note", comment: "Quick note edit title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button {
                            onSave(draft)
                            dismiss()
                        } label: {
                            Label(NSLocalizedString("Keep in Inbox", comment: "Save quick note to inbox"),
                                  systemImage: AppSymbol.tray)
                        }
                        Button {
                            onPromote(draft)
                            dismiss()
                        } label: {
                            Label(NSLocalizedString("Save as Memo", comment: "Promote quick note to memo"),
                                  systemImage: AppSymbol.squareAndPencil)
                        }
                    } label: {
                        Text(NSLocalizedString("Save", comment: "Save"))
                            .fontWeight(.semibold)
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let first = draft.imageFileNames.first, let image = MemoStore.shared.loadImage(fileName: first) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .cornerRadius(8)
        }
    }
}
