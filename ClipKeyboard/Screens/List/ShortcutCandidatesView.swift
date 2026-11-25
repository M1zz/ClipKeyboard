//
//  ShortcutCandidatesView.swift
//  ClipKeyboard
//
//  앱 아래 탭 '임시'. **아직 단축어가 아닌데 단축어가 될 만한 것**을 한곳에 모은다.
//
//  왜 필요한가: 후보는 이미 앱 여기저기에 있었다. 만들다 만 단축어는 목록 카드 사이에,
//  빠른 메모는 설정 안 보관함에, 복사한 글은 목록의 '최근' 카테고리에. 셋 다 "나중에 정리하자"
//  하고 둔 것인데, 정리하러 갈 한 자리가 없어서 정리되지 않았다(2026-11 사용자 요청).
//
//  칸은 넷이다. 위에서부터 손이 가장 덜 가는 순서다.
//  1. 자주 넣은 글: 키보드 '최근' 에서 두 번 넘게 넣은 것(`FrequentClips`). 사라지면 아쉬울 글이다.
//  2. 만들다 만 단축어(`SavedDraft`): 누르면 이어 쓴다.
//  3. 빠른 메모(`QuickNote`): 누르면 고치고 단축어로 옮긴다.
//  4. 복사한 글: 나머지 '최근'. 30일 뒤 사라진다.
//
//  ⚠️ 이미 단축어인 글은 어느 칸에도 세우지 않는다. 후보가 아니다.
//  ⚠️ 탭은 후보가 하나라도 있을 때만 선다(`ShortcutCandidates.showsTab`). 첫날 사람은 지금처럼 두 칸만 본다.
//

import SwiftUI
import LeeoKit

// MARK: - 후보를 읽는 곳

/// 복사 기록과 넣은 횟수를 읽어 둔다. 임시 저장 · 빠른 메모는 제 저장소(`DraftStore` · `QuickNoteStore`)가 이미 들고 있다.
final class ShortcutCandidates: ObservableObject {
    static let shared = ShortcutCandidates()

    /// 키보드 '최근' 과 같은 것(보관 기간 안, 최근 순).
    @Published private(set) var clips: [SmartClipboardHistory] = []
    @Published private(set) var ledger = FrequentClips.Ledger()

    private var observers: [NSObjectProtocol] = []

    private init() {
        reload()
        // 키보드가 담거나 넣은 것은 앱으로 돌아올 때, 앱 안에서 바뀐 것은 데이터 변경 알림으로 다시 읽는다.
        observers = [Notification.Name.memoDataChanged, UIApplication.didBecomeActiveNotification].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.reload()
            }
        }
    }

    func reload() {
        let next = SmartClipboardHistory.keyboardRecents((try? ClipboardHistoryStore.shared.load()) ?? [])
        if next.map(\.id) != clips.map(\.id) || next.map(\.content) != clips.map(\.content) { clips = next }
        let nextLedger = FrequentClips.load(from: AppGroup.defaults)
        if nextLedger != ledger { ledger = nextLedger }
    }

    /// 이미 단축어인 글. 후보에서 뺀다.
    static func savedValues(_ memos: [Memo]) -> Set<String> {
        Set(memos.map { $0.value.trimmingCharacters(in: .whitespacesAndNewlines) })
    }

    /// 자주 넣은 글(많이 넣은 순).
    func frequent(saved: Set<String>) -> [(clip: SmartClipboardHistory, count: Int)] {
        FrequentClips.ranked(among: clips, ledger: ledger, savedValues: saved)
    }

    /// 나머지 복사한 글. 자주 넣은 글 칸에 선 것과 이미 단축어인 것은 뺀다.
    func otherClips(saved: Set<String>, excluding: Set<UUID>) -> [SmartClipboardHistory] {
        clips.filter {
            $0.contentType == .text && !excluding.contains($0.id)
                && !saved.contains($0.content.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// 복사 기록에서 지운다.
    func delete(_ clip: SmartClipboardHistory) {
        do {
            try ClipboardHistoryStore.shared.delete(id: clip.id)
        } catch {
            AppLog.error(.store, "❌ [ShortcutCandidates.delete] 복사 기록을 지우지 못했다: \(error.localizedDescription)")
        }
        reload()
    }

    /// 단축어로 저장했다. 키보드도 그 글로는 다시 묻지 않는다.
    func noteSaved(_ clip: SmartClipboardHistory) {
        FrequentClips.save(FrequentClips.settling(clip.content, in: ledger), to: AppGroup.defaults)
        reload()
    }

    // MARK: - 탭

    /// 탭을 세울까. 후보가 하나라도 있으면 선다(이미 단축어인 복사 글은 후보가 아니다).
    static func showsTab(drafts: [SavedDraft], quickNotes: [QuickNote],
                         clips: [SmartClipboardHistory], saved: Set<String>) -> Bool {
        !drafts.isEmpty || !quickNotes.isEmpty
            || clips.contains { $0.contentType == .text && !saved.contains($0.content.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    /// 탭 배지. 손을 대야 할 것만 센다(자주 넣은 글 · 만들다 만 것 · 빠른 메모).
    /// 복사한 글은 저절로 쌓이는 것이라 세지 않는다. 세면 배지가 늘 떠서 아무 뜻이 없어진다.
    static func badge(drafts: Int, quickNotes: Int, frequent: Int) -> Int {
        drafts + quickNotes + frequent
    }
}

// MARK: - 화면

struct ShortcutCandidatesView: View {
    @ObservedObject private var candidates = ShortcutCandidates.shared
    @ObservedObject private var drafts = DraftStore.shared
    @ObservedObject private var quickNotes = QuickNoteStore.shared
    @ObservedObject private var memos = MemoStore.shared
    @Environment(\.appTheme) private var theme

    @State private var clipToSave: SmartClipboardHistory?
    @State private var draftToResume: SavedDraft?
    @State private var noteToEdit: QuickNote?

    private var saved: Set<String> { ShortcutCandidates.savedValues(memos.memos) }

    var body: some View {
        let frequent = candidates.frequent(saved: saved)
        let others = candidates.otherClips(saved: saved, excluding: Set(frequent.map(\.clip.id)))
        Group {
            if frequent.isEmpty && drafts.drafts.isEmpty && quickNotes.quickNotes.isEmpty && others.isEmpty {
                emptyState
            } else {
                List {
                    if !frequent.isEmpty {
                        Section {
                            ForEach(frequent, id: \.clip.id) { item in
                                clipRow(item.clip, count: item.count)
                            }
                        } header: {
                            header(NSLocalizedString("자주 넣은 글", comment: "Candidates tab: section of copied texts the user inserted from the keyboard several times"))
                        }
                    }
                    if !drafts.drafts.isEmpty {
                        Section {
                            ForEach(drafts.drafts) { draft in draftRow(draft) }
                        } header: {
                            header(NSLocalizedString("만들다 만 단축어", comment: "Candidates tab: section of unfinished snippets (drafts)"))
                        }
                    }
                    if !quickNotes.quickNotes.isEmpty {
                        Section {
                            ForEach(quickNotes.quickNotes) { note in noteRow(note) }
                        } header: {
                            header(NSLocalizedString("빠른 메모", comment: "Candidates tab: section of quick notes captured from Control Center, Siri or the share sheet"))
                        }
                    }
                    if !others.isEmpty {
                        Section {
                            ForEach(others) { clip in clipRow(clip, count: nil) }
                        } header: {
                            header(NSLocalizedString("복사한 글", comment: "Candidates tab: section of recently copied texts"))
                        } footer: {
                            Text(String(format: NSLocalizedString("복사한 글이 %d일 동안 남아요",
                                                                  comment: "What's new 5.1.8 retention title. %d is the number of days"),
                                        SmartClipboardHistory.retentionDays))
                        }
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("임시함", comment: "Tab bar: candidates tab collecting things that could become snippets (drafts, quick notes, copied texts)"))
        .onAppear { candidates.reload() }
        .sheet(item: $clipToSave) { clip in
            SaveToMemoSheet(item: clip) { didSave in
                clipToSave = nil
                if didSave { candidates.noteSaved(clip) }
            }
        }
        .sheet(item: $draftToResume) { draft in
            NavigationStack {
                MemoAdd(insertedKeyword: draft.keyword,
                        insertedValue: draft.value,
                        insertedCategory: draft.category,
                        insertedIsSecure: draft.isSecure,
                        insertedHint: draft.hint,
                        insertedIsFavorite: draft.isFavorite,
                        resumeDraftId: draft.id)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(NSLocalizedString("취소", comment: "Cancel")) { draftToResume = nil }
                        }
                    }
            }
        }
        .sheet(item: $noteToEdit) { note in
            QuickNoteEditSheet(note: note) { updated in
                quickNotes.update(updated)
            } onPromote: { promoted in
                quickNotes.update(promoted)
                quickNotes.promoteToMemo(promoted)
            }
        }
    }

    // MARK: - 줄

    private func header(_ title: String) -> some View {
        Text(title).textCase(nil)
    }

    /// 복사한 글 한 줄. 누르면 단축어로 저장 시트. 카드번호 같은 것은 끝 네 자리만 보인다.
    private func clipRow(_ clip: SmartClipboardHistory, count: Int?) -> some View {
        let row = KeyboardShelfRow(clip: clip)
        return Button {
            HapticManager.shared.light()
            clipToSave = clip
        } label: {
            HStack(spacing: 12) {
                Image(systemName: row.icon)
                    .foregroundColor(theme.textMuted)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.preview)
                        .foregroundColor(theme.text)
                        .lineLimit(2)
                    if let count {
                        Text(String(format: NSLocalizedString("키보드에서 %d번 넣었어요", comment: "Candidates tab: how many times this copied text was inserted from the keyboard. %d is the count"), count))
                            .font(.caption)
                            .foregroundColor(theme.textMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: AppSymbol.plus)
                    .font(.body.weight(.semibold))
                    .foregroundColor(theme.accent)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(NSLocalizedString("단축어로 저장", comment: "Save to memo sheet title"))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { candidates.delete(clip) } label: {
                Label(NSLocalizedString("Delete", comment: "Delete"), systemImage: AppSymbol.trash)
            }
        }
    }

    /// 만들다 만 단축어 한 줄. 누르면 이어 쓴다. 잠근 단축어로 만들던 것은 본문을 보이지 않는다.
    private func draftRow(_ draft: SavedDraft) -> some View {
        Button {
            HapticManager.shared.light()
            draftToResume = draft
        } label: {
            HStack(spacing: 12) {
                Image(systemName: draft.isSecure ? AppSymbol.lockFill : AppSymbol.squareAndPencil)
                    .foregroundColor(theme.textMuted)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.displayTitle)
                        .foregroundColor(theme.text)
                        .lineLimit(1)
                    if !draft.isSecure, !draft.keyword.isEmpty, !draft.previewLine.isEmpty {
                        Text(draft.previewLine)
                            .font(.caption)
                            .foregroundColor(theme.textMuted)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: AppSymbol.pencil)
                    .font(.body.weight(.semibold))
                    .foregroundColor(theme.accent)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(NSLocalizedString("이어서 쓰기", comment: "Keyboard drafts tab: row button that opens the app to finish this unfinished shortcut"))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { drafts.remove(draft.id) } label: {
                Label(NSLocalizedString("Delete", comment: "Delete"), systemImage: AppSymbol.trash)
            }
        }
    }

    /// 빠른 메모 한 줄. 누르면 고치고, 거기서 단축어로 옮긴다(보관함과 같은 시트).
    private func noteRow(_ note: QuickNote) -> some View {
        Button {
            HapticManager.shared.light()
            noteToEdit = note
        } label: {
            HStack(spacing: 12) {
                Image(systemName: note.hasImages ? AppSymbol.photo : AppSymbol.trayFull)
                    .foregroundColor(theme.textMuted)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                Text(note.displayTitle)
                    .foregroundColor(theme.text)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: AppSymbol.plus)
                    .font(.body.weight(.semibold))
                    .foregroundColor(theme.accent)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { quickNotes.remove(note.id, deleteImages: true) } label: {
                Label(NSLocalizedString("Delete", comment: "Delete"), systemImage: AppSymbol.trash)
            }
        }
    }

    // MARK: - 빈 화면

    /// 탭은 후보가 있을 때만 서지만, 보는 중에 마지막 것을 지우면 여기에 닿는다.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: AppSymbol.trayFull)
                .font(.system(size: 46, weight: .light))
                .foregroundColor(theme.textFaint)
                .accessibilityHidden(true)
            Text(NSLocalizedString("정리할 것이 없어요", comment: "Candidates tab: empty state title"))
                .font(.headline)
                .foregroundColor(theme.text)
            Text(NSLocalizedString("복사한 글, 만들다 만 단축어, 빠른 메모가 여기 모여요. 단축어로 만들 것을 골라 보세요.", comment: "Candidates tab: empty state description"))
                .font(.subheadline)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
