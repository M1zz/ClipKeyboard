//
//  RecentClipsPage.swift
//  ClipKeyboard
//
//  목록 탭 맨 앞 '최근' 페이지 - 키보드 '최근' 탭과 같은 것을 앱 크기로 보여 준다.
//

import SwiftUI
import LeeoKit

/// 목록 탭 맨 앞 페이지. 복사해 담아 둔 것을 **잠깐 쓰는 그릇**으로 보여 준다.
///
/// 키보드 '최근' 탭(`KeyboardRecentClipsPanel`)과 같은 것을 같은 규칙으로 고른다
/// (`SmartClipboardHistory.keyboardRecents`, 보관 기간 `SmartClipboardHistory.retentionDays`).
/// 사용자: "키보드에는 최근이 생겼는데 목록 탭에는 안 생겼네".
///
/// 손짓은 목록의 단축어 카드와 같다. **누르면 복사**, 길게 누르면 단축어로 저장 · 삭제.
/// 키보드 판은 키보드에 맞춰 작게 그려서 그대로 쓰지 않는다(글자는 `.body` 이상).
struct RecentClipsPage: View {

    /// 목록의 검색어. 비어 있지 않으면 그 글이 든 것만.
    let searchQuery: String
    /// 목록 화면의 토스트로 알린다.
    let onToast: (String) -> Void
    /// 단축어로 저장한 뒤 - 목록이 새 단축어를 다시 읽게 한다.
    let onSnippetSaved: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var history: [SmartClipboardHistory] = []
    @State private var itemToSave: SmartClipboardHistory?

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var clips: [SmartClipboardHistory] {
        let recents = SmartClipboardHistory.keyboardRecents(history)
        guard !trimmedQuery.isEmpty else { return recents }
        return recents.filter { $0.content.localizedStandardContains(trimmedQuery) }
    }

    var body: some View {
        let clips = clips
        Group {
            if clips.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(clips) { clip in
                        row(clip)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
        }
        .onAppear(perform: load)
        // 키보드에서 담은 것은 다른 프로세스가 같은 파일에 쓴다. 앱으로 돌아올 때 다시 읽는다.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            load()
        }
        .sheet(item: $itemToSave) { item in
            SaveToMemoSheet(item: item) { saved in
                itemToSave = nil
                guard saved else { return }
                onSnippetSaved()
                onToast(NSLocalizedString("단축어로 저장되었습니다", comment: "Clipboard item saved as memo"))
            }
        }
    }

    // MARK: - 한 줄

    private func row(_ clip: SmartClipboardHistory) -> some View {
        let type = clip.userCorrectedType ?? clip.detectedType
        return Button {
            copy(clip)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: type.icon)
                    .font(.body)
                    .foregroundColor(theme.textMuted)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(preview(clip, type: type))
                        .font(.body)
                        .foregroundColor(theme.text)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(Self.relativeFormatter.localizedString(for: clip.copiedAt, relativeTo: Date()))
                        .font(.body)
                        .foregroundColor(theme.textFaint)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
            .contentShape(RoundedRectangle(cornerRadius: theme.radiusMd))
        }
        // 줄이 넓어 `.squish` 깊이로는 목록 전체가 흔들린다. 같은 곡선을 얕게.
        .buttonStyle(.rowPress)
        .contextMenu {
            Button {
                copy(clip)
            } label: {
                Label(NSLocalizedString("Copy to clipboard", comment: "Context menu: copy"), systemImage: AppSymbol.docOnDoc)
            }
            Button {
                itemToSave = clip
            } label: {
                Label(NSLocalizedString("단축어로 저장", comment: "Save to memo sheet title"), systemImage: AppSymbol.squareAndArrowDown)
            }
            Button(role: .destructive) {
                delete(clip)
            } label: {
                Label(NSLocalizedString("삭제", comment: "Action: delete"), systemImage: AppSymbol.trash)
            }
        }
        .accessibilityHint(NSLocalizedString("탭하면 클립보드에 복사됩니다", comment: "Clipboard item copy hint"))
    }

    /// 목록에 보일 글. 카드번호 · 계좌처럼 남이 보면 곤란한 것은 **끝 네 자리만** 보인다(키보드 판과 같은 규칙).
    /// 복사할 때는 원문 그대로다.
    private func preview(_ clip: SmartClipboardHistory, type: ClipboardItemType) -> String {
        let text = clip.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard type.isSensitive else { return text }
        let tail = String(text.filter { !$0.isWhitespace }.suffix(4))
        return "\u{2022}\u{2022}\u{2022}\u{2022} " + tail
    }

    // MARK: - 빈 화면

    private var emptyState: some View {
        let isFiltering = !trimmedQuery.isEmpty
        return VStack(spacing: 8) {
            Image(systemName: isFiltering ? AppSymbol.magnifyingglass : AppSymbol.tray)
                .font(.title2)
                .foregroundColor(theme.textFaint)
                .accessibilityHidden(true)
            Text(isFiltering
                 ? NSLocalizedString("Try a shorter keyword or clear the filter.", comment: "Empty hint: search")
                 : NSLocalizedString("아직 담아 둔 것이 없어요", comment: "Keyboard recent tab: empty title"))
                .font(.body.weight(.semibold))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)
            if !isFiltering {
                Text(String(format: NSLocalizedString("복사한 글이 %d일 동안 남아요",
                                                      comment: "What's new 5.1.8 retention title. %d is the number of days"),
                            SmartClipboardHistory.retentionDays))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Actions

    private func load() {
        do {
            history = try MemoStore.shared.loadSmartClipboardHistory()
        } catch {
            print("❌ [RecentClipsPage.load] \(error)")
        }
    }

    private func copy(_ clip: SmartClipboardHistory) {
        UIPasteboard.general.string = clip.content
        HapticManager.shared.success()
        onToast(NSLocalizedString("복사됨", comment: "VoiceOver: copied"))
    }

    private func delete(_ clip: SmartClipboardHistory) {
        let before = history
        history.removeAll { $0.id == clip.id }
        do {
            try MemoStore.shared.saveSmartClipboardHistory(history: history)
        } catch {
            // 화면과 디스크가 어긋나지 않게 되돌리고 알린다.
            print("❌ [RecentClipsPage.delete] 삭제 저장 실패: \(error)")
            history = before
            onToast(NSLocalizedString("삭제하지 못했습니다", comment: "Delete failed toast"))
        }
    }
}
