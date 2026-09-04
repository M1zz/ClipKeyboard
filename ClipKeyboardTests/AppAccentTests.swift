//
//  AppAccentTests.swift
//  ClipKeyboardTests
//
//  **키컬러는 사용자가 고른다.** 그 계약을 붙잡아 둔다.
//
//  여기서 지키는 것은 색값이 아니라 약속 셋이다.
//   ① 저장된 값이 없으면 **기본**(아이폰이 쓰는 그 파랑)이다. 모르는 값도 거기로
//      떨어진다 - 키컬러가 비면 앱에 누를 곳이 사라진다.
//   ② 고른 값은 **App Group** 에 산다. 표준 UserDefaults 에 두면 키보드 익스텐션이
//      못 읽어서 앱과 키보드가 두 색으로 갈린다.
//   ③ 어느 색을 골라도 **그 위의 글자가 읽힌다.** 고를 수 있게 열어 준 순간부터
//      읽히지 않는 조합을 고를 수 있게 되므로, 일곱 개 전부를 재 둔다.
//      (`AccessibilityContrastTests` 는 기본값 하나만 본다)
//

import Testing
import Foundation
import SwiftUI
import UIKit
@testable import ClipKeyboard

@Suite("AppAccent: 누를 곳을 가리키는 색", .serialized)
struct AppAccentTests {

    /// 시험이 저장소를 건드리므로, 끝나면 원래 값으로 돌려놓는다.
    private func withStoredAccent(_ raw: String?, _ body: () -> Void) {
        let d = AppGroup.defaults
        let saved = d?.string(forKey: DefaultsKey.appAccent)
        defer {
            if let saved { d?.set(saved, forKey: DefaultsKey.appAccent) }
            else { d?.removeObject(forKey: DefaultsKey.appAccent) }
        }
        if let raw { d?.set(raw, forKey: DefaultsKey.appAccent) }
        else { d?.removeObject(forKey: DefaultsKey.appAccent) }
        body()
    }

    @Test("저장된 값이 없으면 아이폰 기본 파랑 - 시스템과 동화하는 것이 이 앱의 정체다")
    func defaultsToSystem() {
        withStoredAccent(nil) {
            #expect(AppAccent.current == .system)
        }
    }

    @Test("모르는 값이어도 기본으로 떨어진다. 키컬러가 비면 누를 곳이 사라진다")
    func unknownFallsBackToSystem() {
        withStoredAccent("gundam") {
            #expect(AppAccent.current == .system)
        }
    }

    /// ⚠️ 값을 적어 두면 애플이 그 파랑을 손볼 때 우리만 옛 파랑으로 남는다.
    ///    이 시험은 우리가 쓰는 값이 **시스템이 주는 값 그대로**인지를 본다.
    @Test("기본색은 시스템에서 받아 온다 - 적어 둔 값이 아니다")
    func systemAccentComesFromTheSystem() {
        for dark in [false, true] {
            let trait = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
            let expected = UIColor.systemBlue.resolvedColor(with: trait)
            let got = UIColor(AppAccent.system.accent(isDark: dark)).resolvedColor(with: trait)
            #expect(got == expected,
                    "\(dark ? "dark" : "light") 기본색이 시스템 파랑과 다르다")
        }
    }

    @Test("고른 값은 그대로 살아난다")
    func selectionSurvives() {
        withStoredAccent(nil) {
            AppAccent.select(.plum)
            #expect(AppAccent.current == .plum)
        }
    }

    /// ⚠️ 표준 UserDefaults 에 저장하면 이 시험이 잡는다. 키보드 익스텐션은
    ///    앱의 표준 저장소를 못 읽어서, 앱만 새 색이 되고 키보드는 예전 색으로 남는다.
    @Test("App Group 에 저장한다 - 키보드도 같은 색을 봐야 한다")
    func livesInTheAppGroup() {
        withStoredAccent(nil) {
            AppAccent.select(.pine)
            #expect(AppGroup.defaults?.string(forKey: DefaultsKey.appAccent) == "pine")
        }
    }

    @Test("지나온 색들이 목록에 남아 있다 - 쓰던 사람이 되돌릴 길")
    func pastAccentsStaySelectable() {
        #expect(AppAccent.allCases.contains(.terracotta))
        #expect(AppAccent.allCases.contains(.ink))
        #expect(AppAccent.allCases.first == .system, "기본이 맨 앞이라야 고르는 자리에서 먼저 보인다")
    }

    // MARK: - 어느 색을 골라도 읽힌다

    private func rgba(_ color: Color, dark: Bool) -> (CGFloat, CGFloat, CGFloat) {
        let ui = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    private func luminance(_ c: (CGFloat, CGFloat, CGFloat)) -> CGFloat {
        func lin(_ v: CGFloat) -> CGFloat { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.0) + 0.7152 * lin(c.1) + 0.0722 * lin(c.2)
    }

    private func contrast(_ a: Color, _ b: Color, dark: Bool) -> CGFloat {
        let la = luminance(rgba(a, dark: dark)), lb = luminance(rgba(b, dark: dark))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// 버튼 글자는 큰 편이라 3:1 이 기준이다(WCAG large text).
    @Test("일곱 색 모두, 키컬러 위의 글자가 3:1 을 넘는다")
    func everyAccentIsLegible() {
        for candidate in AppAccent.allCases {
            for dark in [false, true] {
                let ratio = contrast(candidate.accentFg(isDark: dark),
                                     candidate.accent(isDark: dark), dark: dark)
                #expect(ratio >= 3.0,
                        "\(candidate.rawValue)/\(dark ? "dark" : "light") 키컬러 위 글자가 \(ratio) 밖에 안 된다")
            }
        }
    }

    /// ⚠️ 옅은 바탕(`accentSoft`)에 키컬러 글자를 얹는 칩이 곳곳에 있다.
    ///    두 색이 붙어 있으면 칩이 통째로 뭉개진다.
    @Test("일곱 색 모두, 옅은 바탕 위의 키컬러 글자가 3:1 을 넘는다")
    func everySoftPairIsLegible() {
        for candidate in AppAccent.allCases {
            for dark in [false, true] {
                let ratio = contrast(candidate.accent(isDark: dark),
                                     candidate.accentSoft(isDark: dark), dark: dark)
                #expect(ratio >= 3.0,
                        "\(candidate.rawValue)/\(dark ? "dark" : "light") 옅은 바탕 위 글자가 \(ratio) 밖에 안 된다")
            }
        }
    }

    /// ⚠️ 테마의 나머지 토큰은 건드리지 않는다. 키컬러는 **누를 곳**만 정한다 -
    ///    바탕·글자까지 따라 바뀌면 색을 고르는 것이 아니라 테마를 갈아 끼우는 것이 된다.
    @Test("키컬러를 바꿔도 바탕과 본문은 그대로다")
    func accentOnlyTouchesTheAccent() {
        for dark in [false, true] {
            let base = AppTheme.resolve(kind: .paper, isDark: dark, accent: .system)
            let plum = AppTheme.resolve(kind: .paper, isDark: dark, accent: .plum)
            #expect(base.bg == plum.bg)
            #expect(base.surface == plum.surface)
            #expect(base.text == plum.text)
            #expect(base.divider == plum.divider)
            #expect(base.accent != plum.accent, "키컬러는 실제로 달라져야 한다")
        }
    }

    /// ⚠️ 익스텐션은 앱의 `AppThemedContainer` 를 안 거치고 `resolve` 를 직접 부른다.
    ///    거기에 고른 색이 안 실리면 같은 앱이 두 색으로 갈린다.
    @Test("resolve 가 저장된 키컬러를 그대로 실어 온다 - 익스텐션이 이 길로 읽는다")
    func resolvePicksUpTheStoredChoice() {
        withStoredAccent(nil) {
            AppAccent.select(.indigo)
            let theme = AppTheme.resolve(kind: .paper, isDark: false)
            #expect(theme.accent == AppAccent.indigo.accent(isDark: false))
        }
    }
}
