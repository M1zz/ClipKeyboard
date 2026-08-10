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
    ///
    /// ⚠️ **내용을 바꿀 때 이 값도 같이 올릴 것.** 안 올리면 업데이트한 사람은 이미 본 것으로
    ///    기록돼 있어 새 안내를 **한 번도 못 본다** - 새 기능이 있어도 있는 줄 모른다.
    static let version = "4.4.5"
}

struct WhatsNewView: View {
    let onClose: () -> Void
    /// 큰 버튼을 누르면 닫은 뒤 그 기능으로 데려간다(이번 버전은 키보드 화면).
    /// ⚠️ 안내는 **보여주는 데서 끝나면 안 된다** - 읽고 닫으면 아무것도 안 달라진다.
    let onPrimaryAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 48))
                            .foregroundStyle(.tint)
                            .padding(.top, 28)
                        Text(NSLocalizedString("새로워진 첫 화면", comment: "What's new title 4.4.4"))
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        Text(NSLocalizedString("앱을 열면 키보드가 올라온 모습 그대로 보여요. 눌러서 바로 써 볼 수 있어요.", comment: "What's new subtitle 4.4.4"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    VStack(spacing: 18) {
                        featureRow(
                            symbol: "keyboard",
                            title: NSLocalizedString("눌러 보고 익히세요", comment: "What's new 4.4.4 feature 1 title"),
                            detail: NSLocalizedString("다른 앱에서 키보드가 올라온 그 화면이 앱 안에 그대로 있어요. 눌러서 어떻게 입력되는지 바로 볼 수 있어요.", comment: "What's new 4.4.4 feature 1 detail")
                        )
                        featureRow(
                            symbol: AppSymbol.docOnDoc,
                            title: NSLocalizedString("키마다 복사 버튼", comment: "What's new 4.4.4 feature 2 title"),
                            detail: NSLocalizedString("키를 누르면 입력창에, 복사 버튼을 누르면 클립보드로 갑니다. 예전처럼 복사해 쓰는 방법도 그대로예요.", comment: "What's new 4.4.4 feature 2 detail")
                        )
                        featureRow(
                            symbol: "square.grid.2x2",
                            title: NSLocalizedString("목록도 그대로 있어요", comment: "What's new 4.4.4 feature 3 title"),
                            detail: NSLocalizedString("툴바 버튼으로 목록과 키보드 화면을 오갈 수 있고, 설정 > 첫 화면에서 시작 화면을 고를 수 있어요.", comment: "What's new 4.4.4 feature 3 detail")
                        )
                        featureRow(
                            symbol: "rectangle.stack.badge.plus",
                            title: NSLocalizedString("한꺼번에 가져오기도 미리 보고", comment: "What's new 4.4.5 feature title"),
                            detail: NSLocalizedString("여러 개를 한 번에 가져올 때 저장하기 전에 키보드 모습으로 보여줘요. 키를 눌러 뺄 것만 빼면 됩니다.", comment: "What's new 4.4.5 feature detail")
                        )
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
            }

            VStack(spacing: 10) {
                Button {
                    onPrimaryAction()
                } label: {
                    Text(NSLocalizedString("키보드 화면 보기", comment: "What's new 4.4.4 primary button"))
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
