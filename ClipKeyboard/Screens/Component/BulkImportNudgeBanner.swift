//
//  BulkImportNudgeBanner.swift
//  ClipKeyboard
//
//  "한 번에 정리하기"를 목록에서 내놓는 줄.
//
//  왜 컨테이너로 감싸는가: `ClipKeyboardList` 의 `mainColumn` 은 SwiftUI 런타임
//  타입 메타데이터 한계에 붙어 있어, 조건부 자식을 한 겹 더 얹으면 기기에서 죽는다.
//  그래서 "보여줄지 말지"를 **이 안에서** 정하고, 목록 쪽에는 자식 하나만 는다.
//  (같은 이유로 만들어진 `QuickNoteInboxBannerContainer` 와 같은 꼴이다.)
//
//  ⚠️ 여기 걸리는 두 순간은 **추측**이다(아직 몇 개 없다 · 줄줄이 만드는 중).
//     붙여넣는 순간의 제안(`MemoAdd`)과 달리 확실하지 않아서, 한 번 물리면
//     다시 내놓지 않는다.
//

import SwiftUI

/// 보여줄 때인지 스스로 판단하는 껍데기. 아닐 때는 아무것도 그리지 않는다.
struct BulkImportNudgeBannerContainer: View {
    let memoCount: Int
    /// 디스크에서 한 번이라도 읽어 왔는가.
    ///
    /// ⚠️ **이 문지기가 없으면 모두에게 번쩍인다.** 화면이 뜬 직후에는 `memoCount` 가
    ///    0이라 누구나 "아직 몇 개 없는 사람"으로 보인다. 그래서 배너가 떴다가,
    ///    목록을 읽어 오면 사라진다. 그 사이 아래 카드들이 밀렸다 되돌아온다.
    let hasLoaded: Bool
    let onTap: () -> Void

    @State private var dismissed = false

    var body: some View {
        if hasLoaded, !dismissed, BulkImportNudge.shouldOfferInList(memoCount: memoCount) {
            BulkImportNudgeBanner(
                isNewcomer: BulkImportNudge.isNewcomer(memoCount: memoCount),
                onTap: {
                    BulkImportNudge.resetStreak()
                    onTap()
                },
                onDismiss: {
                    BulkImportNudge.isDismissed = true
                    BulkImportNudge.resetStreak()
                    withAnimation { dismissed = true }
                }
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct BulkImportNudgeBanner: View {
    /// 아직 몇 개 없는 사람인가. 같은 기능이라도 할 말이 다르다.
    let isNewcomer: Bool
    let onTap: () -> Void
    let onDismiss: () -> Void
    @Environment(\.appTheme) private var theme

    private var message: String {
        isNewcomer
        ? NSLocalizedString("이미 어디 적어 두신 것 있으면 통째로 가져올 수 있어요",
                            comment: "Bulk import nudge for someone with almost no snippets yet")
        : NSLocalizedString("하나씩 만들고 계시네요. 통째로 붙여넣으면 한 번에 담겨요",
                            comment: "Bulk import nudge for someone creating snippets one by one")
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: AppSymbol.docOnClipboard)
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(message)
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(NSLocalizedString("한 번에 정리하기", comment: "Bulk import CTA"))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.blue)
                }
                Spacer(minLength: 8)
                Button(action: onDismiss) {
                    Image(systemName: AppSymbol.xmark)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(theme.textFaint)
                        .padding(6)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(NSLocalizedString("닫기", comment: "Close / dismiss"))
            }
            .padding(14)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                    .stroke(.blue.opacity(0.30), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityHint(NSLocalizedString("탭하면 한 번에 정리하기 열기", comment: "VoiceOver: open bulk import"))
    }
}
