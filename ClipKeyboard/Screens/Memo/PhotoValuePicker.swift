//
//  PhotoValuePicker.swift
//  ClipKeyboard
//
//  사진에서 읽은 글자 중 **값으로 넣을 것을 고르는** 자리.
//
//  왜 고르게 하는가: 카드 한 장을 찍으면 카드사 이름·영문 이름·유효기간·카드번호가 한꺼번에
//  읽힌다. 그걸 전부 값에 쏟아부으면 사용자는 결국 지우는 일을 하게 된다 - 손으로 치는 것보다
//  나을 게 없다. 읽은 것을 **줄 단위로 늘어놓고 하나만 집게** 해야 사진이 입력을 대신한다.
//
//  ⚠️ 인식 순서를 흐트러뜨리지 않는다. 사진에 보이는 위→아래 순서가 그대로여야
//     "세 번째 줄이 계좌번호"라는 눈의 기억과 화면이 맞는다.
//     (`OCRService.recognizeText` 가 이미 그 순서로 준다)
//

import SwiftUI
import LeeoKit   // HapticManager

#if os(iOS)

struct PhotoValuePicker: View {

    /// 사진에서 읽은 줄들 (사진에 보이는 순서 그대로).
    let lines: [String]

    /// 그 줄로 값을 채우고 닫는다.
    let onPick: (String) -> Void
    /// 값 끝에 이어 붙인다. 두 줄짜리 주소처럼 **여러 줄이 한 값**일 때 쓴다(닫지 않는다).
    let onAppend: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    /// 이어 붙이기로 담은 줄 - 사용자가 무엇을 이미 넣었는지 흐리게 표시한다.
    @State private var appended: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                if !smartPicks.isEmpty {
                    Section {
                        ForEach(smartPicks, id: \.label) { pick in
                            row(text: pick.value, label: pick.label)
                        }
                    } header: {
                        Text(NSLocalizedString("찾은 값", comment: "Photo value picker: parsed values section"))
                    } footer: {
                        Text(NSLocalizedString("사진에서 알아본 값이에요. 아래 읽은 글자에서 직접 고를 수도 있어요.",
                                               comment: "Photo value picker: parsed values footer"))
                    }
                }

                Section {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        row(text: line, label: nil)
                    }
                } header: {
                    Text(NSLocalizedString("읽은 글자", comment: "Photo value picker: recognized lines section"))
                }

                if lines.count > 1 {
                    Section {
                        Button {
                            onPick(lines.joined(separator: "\n"))
                            dismiss()
                        } label: {
                            Label(NSLocalizedString("읽은 글자 전부 넣기", comment: "Photo value picker: use all recognized text"),
                                  systemImage: AppSymbol.textAlignleft)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("어느 걸 넣을까요?", comment: "Photo value picker title"))
            .navigationBarTitleDisplayMode(.inline)
            .solidNavBar(theme.bg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "Cancel")) { dismiss() }
                }
            }
        }
    }

    /// 한 줄 - 누르면 값이 되고, 오른쪽 +를 누르면 이어 붙는다.
    private func row(text: String, label: String?) -> some View {
        HStack(spacing: 12) {
            Button {
                onPick(text)
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    if let label {
                        Text(label)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.accentColor)
                    }
                    Text(text)
                        .font(.body)
                        .foregroundColor(theme.text)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                onAppend(text)
                appended.insert(text)
                HapticManager.shared.light()
            } label: {
                Image(systemName: appended.contains(text) ? AppSymbol.checkmarkCircleFill : AppSymbol.plusCircle)
                    .font(.title3)
                    .foregroundColor(appended.contains(text) ? Color.checkGreen : .accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("값 끝에 이어 붙이기", comment: "Photo value picker: append line to value"))
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    /// 사진 종류를 알아본 값 - 카드번호·유효기간·주소. 없으면 빈 배열.
    /// ⚠️ 읽은 줄에서 **덜어내지 않는다.** 알아본 게 틀렸을 때 원본 줄이 사라져 있으면
    ///    사용자는 손으로 칠 수밖에 없다. 위에 얹어 두고 아래는 그대로 남긴다.
    private var smartPicks: [(label: String, value: String)] {
        var picks: [(String, String)] = []

        let card = OCRService.shared.parseCardInfo(from: lines)
        if let number = card["카드번호"] {
            picks.append((NSLocalizedString("카드번호", comment: "Bulk import: card number label"), number))
        }
        if let expiry = card["유효기간"] {
            picks.append((NSLocalizedString("유효기간", comment: "Bulk import: card expiry label"), expiry))
        }

        let address = OCRService.shared.parseAddress(from: lines)
        // 한 줄만 걸린 건 주소라기보다 우연히 '동'·'로'가 든 낱말이기 쉽다.
        if !address.isEmpty, address.contains(" ") {
            picks.append((NSLocalizedString("주소", comment: "Photo value picker: parsed address label"), address))
        }

        // 알아본 값이 원본 줄과 똑같으면 같은 것이 두 번 보인다 - 그건 얹을 이유가 없다.
        return picks.filter { !lines.contains($0.1) }
    }
}

#endif
