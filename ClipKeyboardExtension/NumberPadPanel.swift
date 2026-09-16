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
    /// 키 하나의 높이 - 단축어 키와 같은 값을 받아 쓴다(`keyboardButtonHeight`).
    ///
    /// ⚠️ 이 값은 **바라는 크기**지 그릴 크기가 아니다. 자리가 좁으면 줄여 그린다
    ///    (`fittedKeyHeight`). 받은 값을 그대로 쓰면 낮은 판에서 아래가 잘린다.
    let keyHeight: Double
    let theme: AppTheme
    let keycapShape: KeycapShape

    /// 줄마다 세 칸. 마지막 줄만 기호 둘이 숫자를 사이에 둔다.
    ///
    /// ⚠️ 마지막 줄을 `0` 하나로 넓게 두지 않는다. 이 앱에서 숫자를 넣는 자리는 대개
    ///    카드번호·계좌번호·금액이라, 하이픈과 점이 숫자만큼 자주 쓰인다.
    private static let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["-", "0", "."]
    ]

    // MARK: - 자리에 맞추는 치수

    /// 넉넉할 때의 줄 사이.
    static let rowSpacing: CGFloat = 8
    /// 넉넉할 때의 위아래 여백.
    static let verticalPadding: CGFloat = 10
    /// 자리가 모자랄 때 줄이는 줄 사이.
    static let tightRowSpacing: CGFloat = 4
    /// 자리가 모자랄 때 줄이는 위아래 여백.
    static let tightVerticalPadding: CGFloat = 4
    /// 키가 이보다 작아질 것 같으면 **여백부터** 줄인다.
    static let comfortableKeyHeight: CGFloat = 30
    /// 여백을 다 줄이고도 모자라면 여기서 멈춘다.
    /// 조작 키 하한(`KeyboardHeightBook.minimumControlKeySize`)과 같은 값이다.
    static let minimumKeyHeight: CGFloat = 24

    /// 판이 실제로 그릴 치수.
    struct Layout: Equatable {
        var keyHeight: CGFloat
        var rowSpacing: CGFloat
        var verticalPadding: CGFloat
        /// 여백까지 줄이고도 안 들어가는 자리. 잘라내는 대신 굴린다.
        var scrolls: Bool
    }

    /// 키 높이·여백이 이만큼일 때 네 줄이 서려면 판이 얼마나 높아야 하는가.
    static func neededHeight(keyHeight: CGFloat,
                             rowSpacing spacing: CGFloat = rowSpacing,
                             verticalPadding padding: CGFloat = verticalPadding) -> CGFloat {
        let rowCount = CGFloat(rows.count)
        return rowCount * keyHeight + (rowCount - 1) * spacing + padding * 2
    }

    /// 주어진 자리에 맞춰 치수를 정한다.
    ///
    /// 순서가 중요하다. **여백을 먼저 줄이고 키는 나중에 줄인다.** 반대로 하면 여백은
    /// 넉넉한데 누를 수 없는 키가 남는다. 여백은 보기 좋으라고 있는 것이고 키는 눌러야
    /// 하는 것이라, 자리가 없을 때 물러설 쪽은 여백이다.
    ///
    /// 바라는 값보다 **키우지는 않는다.** 자리가 남아도 사용자가 고른 크기가 상한이다.
    static func layout(in available: CGFloat, requested: CGFloat) -> Layout {
        // 자리를 아직 모르는 첫 레이아웃. 고른 값 그대로 두고 다음 번에 맞춘다.
        guard available > 0 else {
            return Layout(keyHeight: requested,
                          rowSpacing: rowSpacing,
                          verticalPadding: verticalPadding,
                          scrolls: false)
        }

        // ① 넉넉한 여백으로 재 본다. 이걸로 편한 크기가 나오면 더 볼 것 없다.
        let roomy = min(requested, fittedKeyHeight(in: available,
                                                   rowSpacing: rowSpacing,
                                                   verticalPadding: verticalPadding))
        if roomy >= comfortableKeyHeight {
            return Layout(keyHeight: roomy,
                          rowSpacing: rowSpacing,
                          verticalPadding: verticalPadding,
                          scrolls: false)
        }

        // ② 여백을 줄여 자리를 만든다. 가로에서 네 줄이 서는 것은 대개 여기서 결정된다.
        let tight = fittedKeyHeight(in: available,
                                    rowSpacing: tightRowSpacing,
                                    verticalPadding: tightVerticalPadding)
        let keyHeight = max(minimumKeyHeight, min(requested, tight))
        let needed = neededHeight(keyHeight: keyHeight,
                                  rowSpacing: tightRowSpacing,
                                  verticalPadding: tightVerticalPadding)
        return Layout(keyHeight: keyHeight,
                      rowSpacing: tightRowSpacing,
                      verticalPadding: tightVerticalPadding,
                      scrolls: needed > available + 0.5)
    }

    /// 여백을 뺀 자리를 네 줄이 나눠 가질 때 키 하나의 높이. 하한을 대지 않은 날 값이다.
    static func fittedKeyHeight(in available: CGFloat,
                                rowSpacing spacing: CGFloat,
                                verticalPadding padding: CGFloat) -> CGFloat {
        let rowCount = CGFloat(rows.count)
        return (available - padding * 2 - spacing * (rowCount - 1)) / rowCount
    }

    // MARK: - 그리기

    /// ⚠️ 키 높이를 받은 값 그대로 쓰면 안 된다. 숫자 판은 네 줄이 **한 자리에 다 서야**
    ///    하는 판이고, 위에 붙여 그린다. 가로처럼 낮은 자리에서 네 줄 높이가 자리보다 크면
    ///    넘치는 만큼 아래가 잘리는데, 호스트 뷰가 `clipsToBounds` 라 잘린 줄(`- 0 .`)에
    ///    닿을 방법이 아예 없어진다. 세로에서는 멀쩡하고 돌리면 사라지니 더 헷갈린다.
    ///
    ///    실제로 아이폰 **가로는 전부** 모자랐다. 격자 자리가 120~160pt 인데 네 줄이
    ///    기본 크기로 서려면 220pt 가 필요했다.
    var body: some View {
        GeometryReader { geo in
            let layout = Self.layout(in: geo.size.height, requested: CGFloat(keyHeight))

            Group {
                if layout.scrolls {
                    ScrollView { pad(layout) }
                } else {
                    pad(layout)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func pad(_ layout: Layout) -> some View {
        VStack(spacing: layout.rowSpacing) {
            ForEach(Self.rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key, height: layout.keyHeight)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, layout.verticalPadding)
    }

    private func keyButton(_ key: String, height: CGFloat) -> some View {
        Button {
            KeyboardHaptics.tap()
            insert(key)
        } label: {
            Text(key)
                // 키가 줄어든 만큼 글자도 줄인다. 그대로 두면 낮은 자리에서 글자가 키를 넘는다.
                .font(.system(size: min(22, height * 0.5),
                              weight: .regular, design: .rounded))
                .foregroundColor(theme.text)
                .frame(maxWidth: .infinity)
                .frame(height: height)
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
