//
//  GiftDeveloperTestView.swift
//  ClipKeyboard
//
//  설정 > 개발자 > 선물 시험. 출시 빌드(CloudKit Production)에서 선물 주고받기를 돈 없이 끝까지 지나 본다.
//
//  ⚠️ 시험 코드는 **Pro 를 열지 않는다**(`LeeoGiftStore.issueTestGift`). 개발자 모드는 버전 줄을
//     일곱 번 누르면 누구나 켤 수 있어서, 시험 코드가 Pro 를 열면 그게 곧 공짜 Pro 가 된다.
//     여기서 보는 것은 공개 DB 에 선물 기록 만들기 · 코드로 찾기 · 한 번만 받기 · 이미 받은 코드 거절까지다.
//     Apple 서명 확인은 진짜 결제로만 볼 수 있다.
//

import SwiftUI
import LeeoKit

struct GiftDeveloperTestView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var gift: LeeoGiftStore
    @State private var code: String?
    @State private var copied = false

    var body: some View {
        List {
            Section {
                Button {
                    HapticManager.shared.light()
                    copied = false
                    Task { code = await gift.issueTestGift() }
                } label: {
                    HStack {
                        Label(NSLocalizedString("시험 코드 만들기", comment: "Developer gift test: create a test gift code"),
                              systemImage: AppSymbol.giftFill)
                        Spacer()
                        if gift.isWorking { ProgressView() }
                    }
                }
                .disabled(gift.isWorking)

                if let code {
                    HStack {
                        Text(verbatim: LeeoGiftCode.display(code))
                            .font(.system(.title2, design: .monospaced).weight(.semibold))
                            .foregroundColor(theme.text)
                            .textSelection(.enabled)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = LeeoGiftCode.display(code)
                            HapticManager.shared.success()
                            copied = true
                        } label: {
                            Image(systemName: copied ? AppSymbol.checkmark : AppSymbol.docOnDoc)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(NSLocalizedString("복사", comment: "Action: copy"))
                    }
                }

                if let error = gift.lastError {
                    Text(error.localizedDescription)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            } footer: {
                Text(NSLocalizedString("결제 없이 시험 코드를 만들어 지금 빌드의 iCloud 환경에 올려요. 받아도 Pro는 열리지 않아요.",
                                       comment: "Developer gift test: footer explaining test codes skip payment and never unlock Pro"))
            }

            Section {
                // 링크로 코드를 채우지 않는다. 여덟 칸에 직접 쳐 보는 것까지가 시험이다.
                FoldLink(destination: LeeoGiftRedeemView<ClipKeyboardSpec>(gift: gift)) {
                    Label(LeeoGiftText.redeemEntry, systemImage: AppSymbol.giftcard)
                }
            } footer: {
                Text(NSLocalizedString("코드를 넣으면 끝까지 처리됐다고 나와야 해요. 같은 코드를 한 번 더 넣으면 이미 받은 선물로 나와야 맞아요.",
                                       comment: "Developer gift test: what a successful test looks like"))
            }
        }
        .navigationTitle(NSLocalizedString("선물 시험 (개발자)", comment: "Developer gift test settings entry"))
    }
}
