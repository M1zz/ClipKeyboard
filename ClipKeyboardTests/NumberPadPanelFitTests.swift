//
//  NumberPadPanelFitTests.swift
//  ClipKeyboardTests
//
//  숫자 판 네 줄이 **자리에 맞춰 선다**는 것을 못박는다.
//
//  왜 필요한가: 예전에는 받은 키 높이를 그대로 그렸다. 세로에서는 멀쩡했고 가로로 돌리면
//  마지막 줄(`- 0 .`)이 통째로 사라졌다. 판을 위에 붙여 그리는데 호스트 뷰가 잘라내니,
//  잘린 줄에 닿을 방법이 아예 없었다. 돌려야만 보이는 종류의 버그라 눈으로는 잘 안 잡힌다.
//
//  숫자가 말해 주는 크기: 아이폰 가로의 격자 자리는 120~160pt 인데, 네 줄이 기본 크기로
//  서려면 220pt 가 필요했다. **가로는 전부** 모자랐다.
//
//  여기서 지키는 것은 셋이다.
//   · 자리가 좁으면 **여백부터** 줄인다. 누를 자리를 지키는 쪽이 먼저다.
//   · 그렇게 해서 네 줄이 다 선다.
//   · 자리가 남아도 사용자가 고른 크기보다 **키우지는 않는다.**
//

import Testing
import CoreGraphics
@testable import ClipKeyboard

@Suite("숫자 판 높이 맞추기")
struct NumberPadPanelFitTests {

    /// 격자 자리. 판 높이에서 머리 줄(조작 키 + 여백)을 뺀 값이다.
    /// `KeyboardHeightBook.height(for:)` 를 기기 크기로 돌려서 얻은 실제 값들이다.
    private static let landscapePhones: [(name: String, room: CGFloat)] = [
        ("iPhone SE3 가로", 122),
        ("iPhone 13 mini 가로", 122),
        ("iPhone 17 가로", 134),
        ("iPhone 17 Pro Max 가로", 163),
    ]

    /// 세로 아이폰의 격자 자리. 넉넉하다.
    private let roomyPortrait: CGFloat = 294

    // MARK: - 고른 크기를 지키는 쪽

    @Test("자리가 넉넉하면 고른 크기를 그대로 쓴다")
    func keepsRequestedWhenThereIsRoom() {
        let layout = NumberPadPanel.layout(in: roomyPortrait, requested: 44)
        #expect(layout.keyHeight == 44)
        #expect(layout.rowSpacing == NumberPadPanel.rowSpacing)
        #expect(layout.verticalPadding == NumberPadPanel.verticalPadding)
        #expect(layout.scrolls == false)
    }

    @Test("자리가 남아도 고른 크기보다 키우지 않는다")
    func neverGrowsBeyondRequested() {
        #expect(NumberPadPanel.layout(in: 900, requested: 44).keyHeight == 44)
    }

    @Test("자리를 아직 모르면 고른 크기를 쓴다")
    func zeroHeightFallsBackToRequested() {
        #expect(NumberPadPanel.layout(in: 0, requested: 44).keyHeight == 44)
    }

    // MARK: - 자리가 모자랄 때

    @Test("키를 줄이기 전에 여백부터 줄인다")
    func tightensPaddingBeforeKeys() {
        let layout = NumberPadPanel.layout(in: 134, requested: 44)
        #expect(layout.verticalPadding == NumberPadPanel.tightVerticalPadding)
        #expect(layout.rowSpacing == NumberPadPanel.tightRowSpacing)
        // 여백을 줄인 덕에 키가 하한까지 내려가지 않는다.
        #expect(layout.keyHeight > NumberPadPanel.minimumKeyHeight)
    }

    @Test("아이폰 가로 어디서도 네 줄이 다 선다", arguments: landscapePhones)
    func everyLandscapePhoneFits(_ device: (name: String, room: CGFloat)) {
        let layout = NumberPadPanel.layout(in: device.room, requested: 44)
        let needed = NumberPadPanel.neededHeight(keyHeight: layout.keyHeight,
                                                 rowSpacing: layout.rowSpacing,
                                                 verticalPadding: layout.verticalPadding)
        #expect(needed <= device.room + 0.5, "\(device.name): \(needed)pt 가 \(device.room)pt 자리에 안 들어간다")
        #expect(layout.scrolls == false, "\(device.name): 숫자 판은 굴리지 않고 서야 한다")
        #expect(layout.keyHeight >= NumberPadPanel.minimumKeyHeight)
    }

    @Test("키를 크게 쓰는 사람도 가로에서 네 줄이 다 선다", arguments: landscapePhones)
    func largeKeyUsersAlsoFit(_ device: (name: String, room: CGFloat)) {
        let layout = NumberPadPanel.layout(in: device.room, requested: 70)
        let needed = NumberPadPanel.neededHeight(keyHeight: layout.keyHeight,
                                                 rowSpacing: layout.rowSpacing,
                                                 verticalPadding: layout.verticalPadding)
        #expect(needed <= device.room + 0.5, "\(device.name): \(needed)pt")
        #expect(layout.scrolls == false)
    }

    // MARK: - 바닥

    @Test("못 누를 크기까지 줄이지는 않는다. 대신 굴린다")
    func stopsAtTheMinimumAndScrolls() {
        let layout = NumberPadPanel.layout(in: 60, requested: 44)
        #expect(layout.keyHeight == NumberPadPanel.minimumKeyHeight)
        #expect(layout.scrolls == true, "줄여도 안 들어가면 잘라내지 말고 굴려서 닿게 한다")
    }
}
