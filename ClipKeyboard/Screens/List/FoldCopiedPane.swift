//
//  FoldCopiedPane.swift
//  ClipKeyboard
//
//  아이폰 듀오를 폈을 때 단축어 탭의 **결과 쪽**.
//
//  고르는 쪽(지금 목록 그대로)에서 카드를 누르면 복사된다. 무엇이 복사됐는지는 폰에서는
//  카드 위 도장으로만 알았다. 펴면 결과 쪽이 그 값을 크게 보이고, 그 아래에 최근 복사한 글이
//  서 있다. 잠깐 쓰는 것(최근)과 오래 두는 것(단축어)이 접힌 선을 사이에 두고 마주 본다.
//
//  ⚠️ 보안 단축어는 여기서도 값을 보이지 않는다. 펼친 화면은 옆에서도 잘 보인다.
//  ⚠️ 접으면 이 판은 사라진다. 바깥 화면은 고르는 쪽만 남는 지금 아이폰 화면이다.
//

import SwiftUI

struct FoldCopiedPane: View {
    @Environment(\.appTheme) private var theme

    /// 방금 복사한 것. 카드를 누르기 전에는 nil.
    @State private var copied: CopiedSnapshot?
    /// 최근 목록을 다시 읽게 하는 표. 복사할 때마다 바뀐다.
    @State private var recentsToken = 0
    @State private var toast: String?

    private struct CopiedSnapshot: Equatable {
        let title: String
        /// 보여 줄 값. 보안이면 nil.
        let value: String?
        let isImage: Bool
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                copiedCard
                recentHeader
                RecentClipsPage(searchQuery: "",
                                onToast: { show($0) },
                                onSnippetSaved: { })
                    .id(recentsToken)
                    .padding(.horizontal, -16) // 최근 줄은 제 안쪽 여백을 갖고 있다
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 110)
        }
        .scrollEdgeEffectHidden(true, for: .all)
        .background(theme.surfaceAlt.opacity(0.45).ignoresSafeArea())
        .overlay(alignment: .bottom) { toastView }
        .onReceive(NotificationCenter.default.publisher(for: .memoUsed)) { note in
            remember(note)
        }
    }

    // MARK: - 방금 복사함

    @ViewBuilder
    private var copiedCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("방금 복사함", comment: "Fold result pane: the snippet just copied"))
                .font(.body.weight(.semibold))
                .foregroundColor(theme.textMuted)
            if let copied {
                Text(copied.title)
                    .font(.title3.weight(.bold))
                    .foregroundColor(theme.text)
                Text(valueLine(copied))
                    .font(.body)
                    .foregroundColor(copied.value == nil ? theme.textMuted : theme.text)
                    .lineLimit(6)
                    .textSelection(.enabled)
            } else {
                Text(NSLocalizedString("카드를 누르면 복사한 값이 여기 보여요",
                                       comment: "Fold result pane: hint before anything is copied"))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radiusLg))
        .accessibilityElement(children: .combine)
        .animation(.easeOut(duration: 0.2), value: copied)
    }

    private func valueLine(_ copied: CopiedSnapshot) -> String {
        if copied.isImage {
            return NSLocalizedString("그림 단축어", comment: "Fold result pane: an image snippet was copied")
        }
        return copied.value
            ?? NSLocalizedString("보안 단축어라 값은 보이지 않아요",
                                 comment: "Fold result pane: secure snippet value is hidden")
    }

    private var recentHeader: some View {
        Text(String(format: NSLocalizedString("최근 · %d일", comment: "Fold result pane: recent clips header. %d is the retention days"),
                    SmartClipboardHistory.retentionDays))
            .font(.body.weight(.semibold))
            .foregroundColor(theme.textMuted)
    }

    // MARK: - 토스트

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.body.weight(.semibold))
                .foregroundColor(theme.text)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(theme.surface, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .padding(.bottom, 96)
                .transition(.opacity)
        }
    }

    private func show(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { if toast == message { toast = nil } }
        }
    }

    // MARK: - 복사 신호

    /// `.memoUsed` 는 앱 · 키보드 어느 길로 써도 `MemoStore.incrementClipCount` 한 곳에서 나간다.
    private func remember(_ note: Notification) {
        recentsToken += 1
        let info = note.userInfo ?? [:]
        guard let title = info[MemoUsedKey.title] as? String else { return }
        let isSecure = info[MemoUsedKey.isSecure] as? Bool ?? true
        copied = CopiedSnapshot(title: title,
                                value: isSecure ? nil : info[MemoUsedKey.copiedText] as? String,
                                isImage: info[MemoUsedKey.isImage] as? Bool ?? false)
        print("📝 [FoldCopiedPane.remember] 결과 쪽에 방금 복사한 것 표시: \(title)")
    }
}
