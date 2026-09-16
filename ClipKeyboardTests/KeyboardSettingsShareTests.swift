//
//  KeyboardSettingsShareTests.swift
//  ClipKeyboardTests
//
//  **진짜 키보드 · 앱의 무대 · 설정 미리보기가 같은 설정을 본다**는 것을 못박는다.
//
//  왜 필요한가: 셋이 각자 defaults 를 읽고 각자 높이를 셈하고 있었다. 설정 미리보기만
//  `KeyboardHeightBook` 으로 제대로 쟀고, 무대는 `화면 높이 × 0.5` 라는 제 나름의 셈을
//  썼다. 그 숫자에는 근거가 없었고 무엇보다 **사용자가 고른 것을 하나도 안 봤다.**
//  키를 크게 잡아도, 칸 수를 줄여도, 높이를 넉넉히로 바꿔도 무대는 426pt 그대로였다.
//  기본 설정에서 진짜 키보드보다 141pt 높았다.
//
//  그래서 읽는 곳을 `KeyboardHeightBook.currentContentMetrics()` 한 군데로 모았다.
//  여기서 지키는 것은 그 함수가 **App Group 에 적힌 것을 실제로 읽는다**는 것이다.
//  이게 깨지면 셋이 다시 조용히 갈라진다.
//

import Testing
import Foundation
import CoreGraphics
@testable import ClipKeyboard

@Suite("키보드 설정을 셋이 함께 본다", .serialized)
struct KeyboardSettingsShareTests {

    /// App Group 값을 만졌다가 **반드시** 되돌린다.
    ///
    /// ⚠️ 되돌리기를 빠뜨리면 다른 시험이 남은 값을 보고 흔들린다. 같은 저장소에
    ///    그렇게 흔들리는 시험이 이미 하나 있다(`SnippetsTabStyleTests`).
    private func withDefaults(_ values: [String: Any?], _ body: () -> Void) {
        guard let d = AppGroup.defaults else { return }
        let saved = values.keys.reduce(into: [String: Any?]()) { $0[$1] = d.object(forKey: $1) }
        defer {
            for (key, value) in saved {
                if let value { d.set(value, forKey: key) } else { d.removeObject(forKey: key) }
            }
        }
        for (key, value) in values {
            if let value { d.set(value, forKey: key) } else { d.removeObject(forKey: key) }
        }
        body()
    }

    // MARK: - 적힌 것을 읽는가

    @Test("고른 키 높이를 읽는다")
    func readsButtonHeight() {
        withDefaults([DefaultsKey.keyboardButtonHeight: 60.0]) {
            #expect(KeyboardHeightBook.currentContentMetrics().buttonHeight == 60)
        }
    }

    @Test("고른 칸 수를 읽는다")
    func readsColumnCount() {
        withDefaults([DefaultsKey.keyboardColumnCount: 4]) {
            #expect(KeyboardHeightBook.currentContentMetrics().columns == 4)
        }
    }

    @Test("고른 조작 키 크기를 읽는다")
    func readsControlKeySize() {
        withDefaults([DefaultsKey.keyboardControlKeySize: 40.0]) {
            #expect(KeyboardHeightBook.currentContentMetrics().controlKeySize == 40)
        }
    }

    // MARK: - 없을 때

    /// ⚠️ `UserDefaults` 는 키가 없으면 0 을 돌려준다. 그대로 쓰면 격자가 필요로 하는
    ///    높이가 0 이 되어 바닥 계산이 통째로 무너진다.
    @Test("값이 없으면 기본값으로 선다. 0 을 그대로 쓰지 않는다")
    func missingValuesFallBackToDefaults() {
        withDefaults([DefaultsKey.keyboardButtonHeight: nil,
                      DefaultsKey.keyboardColumnCount: nil,
                      DefaultsKey.keyboardControlKeySize: nil]) {
            let metrics = KeyboardHeightBook.currentContentMetrics()
            #expect(metrics.buttonHeight > 0)
            #expect(metrics.columns > 0)
            #expect(metrics.controlKeySize == KeyboardHeightBook.defaultControlKeySize)
        }
    }

    @Test("0 이 적혀 있어도 기본값으로 선다")
    func zeroIsTreatedAsUnset() {
        withDefaults([DefaultsKey.keyboardButtonHeight: 0.0,
                      DefaultsKey.keyboardColumnCount: 0,
                      DefaultsKey.keyboardControlKeySize: 0.0]) {
            let metrics = KeyboardHeightBook.currentContentMetrics()
            #expect(metrics.buttonHeight > 0)
            #expect(metrics.columns > 0)
            #expect(metrics.controlKeySize == KeyboardHeightBook.defaultControlKeySize)
        }
    }

    // MARK: - 높이가 설정을 따라 움직이는가

    /// 무대가 예전처럼 굳어 있으면 이 시험이 깨진다.
    @Test("키를 크게 잡으면 판도 높아진다")
    func heightFollowsTheSettings() {
        let screen = CGSize(width: 393, height: 852)

        var small: CGFloat = 0
        withDefaults([DefaultsKey.keyboardButtonHeight: 40.0,
                      DefaultsKey.keyboardColumnCount: 2,
                      DefaultsKey.keyboardControlKeySize: 28.0]) {
            small = KeyboardHeightBook.currentHeight(for: screen)
        }

        var large: CGFloat = 0
        withDefaults([DefaultsKey.keyboardButtonHeight: 70.0,
                      DefaultsKey.keyboardColumnCount: 1,
                      DefaultsKey.keyboardControlKeySize: 44.0]) {
            large = KeyboardHeightBook.currentHeight(for: screen)
        }

        #expect(large > small, "설정을 키웠는데 판 높이가 그대로다(\(small) → \(large))")
    }

    /// 무대·미리보기·익스텐션이 같은 함수를 부르므로 같은 값이 나와야 한다.
    @Test("같은 설정이면 어디서 재도 같은 높이다")
    func everyCallerGetsTheSameHeight() {
        let screen = CGSize(width: 393, height: 852)
        withDefaults([DefaultsKey.keyboardButtonHeight: 52.0,
                      DefaultsKey.keyboardColumnCount: 3,
                      DefaultsKey.keyboardControlKeySize: 32.0]) {
            // 익스텐션·무대가 부르는 길
            let shared = KeyboardHeightBook.currentHeight(for: screen)
            // 설정 미리보기가 부르는 길(치수를 직접 넘긴다)
            let explicit = KeyboardHeightBook.height(for: screen,
                                                     content: KeyboardHeightBook.currentContentMetrics(),
                                                     preset: KeyboardHeightPreset.current)
            #expect(shared == explicit)
        }
    }
}
