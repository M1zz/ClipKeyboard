//
//  WhatsNewView.swift
//  ClipKeyboard
//
//  업데이트 후 1회 노출되는 "새로운 기능" 시트. 새 기능을 자연스럽게 알리는 announce 층.
//  (지속 리마인드는 TipKit, 상시 노출은 Inbox 배너가 담당.)
//

import SwiftUI

/// What's-New 콘텐츠 + 버전. 새 안내가 필요할 때 `version`을 올리면 그 버전 사용자에게 1회 노출된다.
enum WhatsNewContent {
    /// 이 안내가 소개하는 기능 버전. 무관한 버전 범프에서는 다시 뜨지 않도록 콘텐츠 기준 버전으로 고정.
    static let version = "4.3.4"
}

struct WhatsNewView: View {
    let onClose: () -> Void
    /// "보관함 열기"를 누르면 닫은 뒤 Inbox를 연다.
    let onOpenInbox: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Image(systemName: AppSymbol.trayAndArrowDownFill)
                            .font(.system(size: 48))
                            .foregroundStyle(.tint)
                            .padding(.top, 28)
                        Text(NSLocalizedString("New: Quick Note", comment: "What's new title"))
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        Text(NSLocalizedString("Capture anything in a tap — decide later whether to keep it as a keyboard memo.", comment: "What's new subtitle"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    VStack(spacing: 18) {
                        featureRow(
                            symbol: AppSymbol.squareAndArrowUp,
                            title: NSLocalizedString("Capture from anywhere", comment: "What's new feature 1 title"),
                            detail: NSLocalizedString("Send text or images from the Share Sheet, Shortcuts, Siri, or a Control Center button — without opening the app.", comment: "What's new feature 1 detail")
                        )
                        featureRow(
                            symbol: AppSymbol.trayFull,
                            title: NSLocalizedString("It waits in your inbox", comment: "What's new feature 2 title"),
                            detail: NSLocalizedString("Captured items are kept in the inbox with no rush — nothing is auto-deleted.", comment: "What's new feature 2 detail")
                        )
                        featureRow(
                            symbol: AppSymbol.squareAndPencil,
                            title: NSLocalizedString("Promote when you're ready", comment: "What's new feature 3 title"),
                            detail: NSLocalizedString("Swipe to save an item as a keyboard memo, or delete it. You decide later.", comment: "What's new feature 3 detail")
                        )
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
            }

            VStack(spacing: 10) {
                Button {
                    onOpenInbox()
                } label: {
                    Text(NSLocalizedString("Open Inbox", comment: "Open inbox button"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    onClose()
                } label: {
                    Text(NSLocalizedString("Not now", comment: "Dismiss what's new"))
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    private func featureRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
