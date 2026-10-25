//
//  FoldCopiedPane.swift
//  ClipKeyboard
//
//  아이폰 듀오를 폈을 때 단축어 탭의 **결과 쪽**.
//
//  위에는 **다른 곳에서 방금 복사한 글**을 크게 보이고, 그 아래에 최근 복사한 글이 서 있다.
//  잠깐 쓰는 것(최근)과 오래 두는 것(단축어)이 접힌 선을 사이에 두고 마주 본다.
//
//  ⚠️ 내 단축어 카드를 누른 것은 여기 띄우지 않는다. 이미 목록에 있는 값이라 다시 보여 줄 까닭이 없다
//     (2026-10 사용자 요청). 그래서 '방금 복사함' 은 복사 기록에서 단축어와 같은 값을 뺀 맨 앞이다.
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
        // 접힌 선 띠의 결과 쪽 절반도 이 색으로(`FoldSplitView.hinge`)
        .preference(key: FoldBandTrailFillKey.self, value: theme.surfaceAlt.opacity(0.45))
        .overlay(alignment: .bottom) { toastView }
        .onAppear { refreshLatest() }
        // 단축어를 눌러도 기록이 바뀐다(목록이 복사 기록에 남긴다). 그때 다시 읽되 단축어 값은 빼고 본다
        .onReceive(NotificationCenter.default.publisher(for: .memoUsed)) { _ in
            recentsToken += 1
            refreshLatest()
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
                Text(NSLocalizedString("다른 앱에서 복사하면 여기 보여요",
                                       comment: "Fold result pane: hint when nothing has been copied from outside"))
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

    /// 복사 기록의 맨 앞 중 **단축어에 없는 값**을 '방금 복사함' 에 세운다.
    private func refreshLatest() {
        let snippetValues = Set(((try? MemoStore.shared.load(type: .memo)) ?? []).map(\.value))
        let latest = ((try? MemoStore.shared.loadSmartClipboardHistory()) ?? [])
            .first { $0.contentType == .text && !snippetValues.contains($0.content) }
        copied = latest.map {
            CopiedSnapshot(title: NSLocalizedString("다른 곳에서 복사함", comment: "Fold result pane: title of text copied outside the app"),
                           value: $0.content, isImage: false)
        }
    }
}
