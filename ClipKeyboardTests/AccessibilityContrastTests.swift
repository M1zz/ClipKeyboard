//
//  AccessibilityContrastTests.swift
//  ClipKeyboardTests
//
//  대비 증가(설정 > 손쉬운 사용 > 디스플레이 > 대비 증가)를 켠 사람의 화면을 지킨다.
//
//  ⚠️ 이 시험들이 지키는 것은 색값이 아니라 **약속**이다.
//     흐린 것은 또렷해지고, 이미 또렷한 것은 그대로 있는다.
//     대비 증가는 "화면을 바꿔 달라"가 아니라 "안 보이는 것을 보이게 해 달라"는 요청이다.
//

import XCTest
import SwiftUI
@testable import ClipKeyboard

final class AccessibilityContrastTests: XCTestCase {

    /// 라이트/다크 각각에서 실제로 그려질 색을 뽑는다.
    private func rgba(_ color: Color, dark: Bool) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let trait = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        let ui = UIColor(color).resolvedColor(with: trait)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    /// WCAG 상대 휘도.
    private func luminance(_ c: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)) -> CGFloat {
        func lin(_ v: CGFloat) -> CGFloat {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }

    private func contrastRatio(_ a: Color, _ b: Color, dark: Bool) -> CGFloat {
        let la = luminance(rgba(a, dark: dark)), lb = luminance(rgba(b, dark: dark))
        let hi = max(la, lb), lo = min(la, lb)
        return (hi + 0.05) / (lo + 0.05)
    }

    private var themes: [(AppThemeKind, Bool)] {
        [(.paper, false), (.paper, true), (.dusk, false), (.dusk, true)]
    }

    // MARK: - 흐린 것이 또렷해진다

    func test_대비를_켜면_흐린_글자가_바탕에서_더_떨어진다() {
        for (kind, dark) in themes {
            let base = AppTheme.resolve(kind: kind, isDark: dark, increasedContrast: false)
            let high = AppTheme.resolve(kind: kind, isDark: dark, increasedContrast: true)
            for (name, b, h) in [("textMuted", base.textMuted, high.textMuted),
                                 ("textFaint", base.textFaint, high.textFaint)] {
                let before = contrastRatio(b, base.bg, dark: dark)
                let after = contrastRatio(h, high.bg, dark: dark)
                XCTAssertGreaterThan(after, before,
                    "\(kind)/\(dark ? "dark" : "light") \(name) 이 더 또렷해지지 않았다 (\(before) -> \(after))")
            }
        }
    }

    func test_대비를_켜면_선이_실제로_보인다() {
        // 라이트의 divider 는 검정 7%다. 대비 증가를 켠 사람에게는 없는 선이나 마찬가지다.
        for (kind, dark) in themes {
            let base = AppTheme.resolve(kind: kind, isDark: dark, increasedContrast: false)
            let high = AppTheme.resolve(kind: kind, isDark: dark, increasedContrast: true)
            XCTAssertGreaterThan(rgba(high.divider, dark: dark).a,
                                 rgba(base.divider, dark: dark).a,
                                 "\(kind)/\(dark ? "dark" : "light") 선이 더 진해지지 않았다")
        }
    }

    // MARK: - 이미 또렷한 것은 그대로

    func test_바탕과_본문과_키컬러는_건드리지_않는다() {
        // 이 셋까지 바꾸면 대비 증가를 켠 사람에게만 다른 앱이 된다.
        for (kind, dark) in themes {
            let base = AppTheme.resolve(kind: kind, isDark: dark, increasedContrast: false)
            let high = AppTheme.resolve(kind: kind, isDark: dark, increasedContrast: true)
            XCTAssertEqual(base.bg, high.bg)
            XCTAssertEqual(base.surface, high.surface)
            XCTAssertEqual(base.text, high.text)
            XCTAssertEqual(base.accent, high.accent)
            XCTAssertEqual(base.accentFg, high.accentFg)
        }
    }

    func test_모양과_글꼴은_그대로다() {
        // 대비는 색의 일이다. 모서리나 글꼴이 같이 바뀌면 그건 다른 테마다.
        for (kind, dark) in themes {
            let base = AppTheme.resolve(kind: kind, isDark: dark, increasedContrast: false)
            let high = AppTheme.resolve(kind: kind, isDark: dark, increasedContrast: true)
            XCTAssertEqual(base.radiusMd, high.radiusMd)
            XCTAssertEqual(base.displayFontName, high.displayFontName)
            XCTAssertEqual(base.bodyFontName, high.bodyFontName)
            XCTAssertEqual(base.kind, high.kind)
            XCTAssertEqual(base.isDark, high.isDark)
        }
    }

    // MARK: - 평소 화면도 읽을 수 있어야 한다

    func test_대비를_켜지_않아도_본문은_읽힌다() {
        // WCAG AA 본문 기준 4.5:1. 이건 대비 증가와 무관하게 늘 지켜야 하는 선이다.
        for (kind, dark) in themes {
            let t = AppTheme.resolve(kind: kind, isDark: dark)
            XCTAssertGreaterThanOrEqual(contrastRatio(t.text, t.bg, dark: dark), 4.5,
                "\(kind)/\(dark ? "dark" : "light") 본문이 바탕에서 4.5:1 을 못 넘는다")
        }
    }

    func test_키컬러_위의_글자가_읽힌다() {
        // 버튼 글자는 큰 편이라 3:1 이 기준이다.
        for (kind, dark) in themes {
            let t = AppTheme.resolve(kind: kind, isDark: dark)
            XCTAssertGreaterThanOrEqual(contrastRatio(t.accentFg, t.accent, dark: dark), 3.0,
                "\(kind)/\(dark ? "dark" : "light") 키컬러 위 글자가 3:1 을 못 넘는다")
        }
    }

    // MARK: - 섞기

    func test_섞기는_양_끝을_지킨다() {
        let a = Color.black, b = Color.white
        XCTAssertEqual(rgba(a.mixed(with: b, amount: 1), dark: false).r, 0, accuracy: 0.01)
        XCTAssertEqual(rgba(a.mixed(with: b, amount: 0), dark: false).r, 1, accuracy: 0.01)
        XCTAssertEqual(rgba(a.mixed(with: b, amount: 0.5), dark: false).r, 0.5, accuracy: 0.01)
    }
}
