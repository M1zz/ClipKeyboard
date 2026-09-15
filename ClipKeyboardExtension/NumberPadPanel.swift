//
//  NumberPadPanel.swift
//  ClipKeyboardExtension
//
//  숫자 판 - 단축어 판 자리에 잠깐 들어서는 화면.
//
//  왜 있는가: 카드번호·금액·전화번호처럼 **숫자 몇 자만** 넣으면 되는 순간이 있는데,
//  그때마다 다른 키보드로 건너갔다 돌아와야 했다. 한 글자 지우기가 없어서 건너가야 했던
//  것과 같은 종류의 일이다(`backspaceDocumentKey` 주석 참고).
//
//  ⚠️ **위줄(조작 키)은 그대로 둔다.** 지우기·보내기·전체삭제가 거기 있고, 숫자를 넣다가
//     고치는 일은 여기서도 똑같이 일어난다. 이 화면은 단축어 격자 자리만 차지한다.
//
//  ⚠️ 키 모양·색은 단축어 키와 **같은 것**을 쓴다. 판이 바뀌었는데 키까지 달라 보이면
//     다른 키보드로 건너온 것처럼 읽힌다.
//

import SwiftUI

struct NumberPadPanel: View {

    /// 글자를 넣는 곳. 위줄의 키들이 쓰는 것과 같은 통로다.
    let insert: (String) -> Void
    /// 키 하나의 높이 - 단축어 키와 같은 값을 받아 쓴다.
    /// 키 하나의 높이 - 단축어 키와 같은 값을 받아 쓴다(`keyboardButtonHeight`).
    let keyHeight: Double
    let theme: AppTheme
    let keycapShape: KeycapShape

    /// 줄마다 세 칸. 마지막 줄만 기호 둘이 숫자를 사이에 둔다.
    ///
    /// ⚠️ 마지막 줄을 `0` 하나로 넓게 두지 않는다. 이 앱에서 숫자를 넣는 자리는 대개
    ///    카드번호·계좌번호·금액이라, 하이픈과 점이 숫자만큼 자주 쓰인다.
    private let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["-", "0", "."]
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func keyButton(_ key: String) -> some View {
        Button {
            KeyboardHaptics.tap()
            insert(key)
        } label: {
            Text(key)
                .font(.system(size: 22, weight: .regular, design: .rounded))
                .foregroundColor(theme.text)
                .frame(maxWidth: .infinity)
                .frame(height: CGFloat(keyHeight))
                .background(theme.surface)
                .clipShape(keycapShape)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(accessibilityName(for: key))
    }

    /// 화면 읽기가 기호를 "하이픈" · "점" 으로 읽게 한다. 그냥 두면 문장부호로 흘려 읽는다.
    private func accessibilityName(for key: String) -> String {
        switch key {
        case "-": return NSLocalizedString("하이픈", comment: "Number pad key: hyphen")
        case ".": return NSLocalizedString("점", comment: "Number pad key: period")
        default:  return key
        }
    }
}
