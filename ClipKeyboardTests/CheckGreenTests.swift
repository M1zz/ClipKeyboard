//
//  CheckGreenTests.swift
//  ClipKeyboardTests
//
//  **체크 표시는 언제나 연두다.**
//
//  ⚠️ 이 규칙이 생긴 이유: 키컬러를 고를 수 있게 되면서(`AppAccent`) 체크를 키컬러로
//     그리면 자두를 고른 사람에게는 자주색 체크가, 먹을 고른 사람에게는 검은 체크가 뜬다.
//     "골랐다 · 됐다 · 맞다"는 색을 갖고 있는 말이고, 그 색은 사람이 고르는 것이 아니다.
//
//  ⚠️ 색을 눈으로만 고르면 안 되는 자리다. 진짜 연두(#9ACD32)는 흰 바탕에서 1.9:1 이라
//     글리프가 그냥 안 보인다. 라이트는 읽히는 선까지 눌러 내린 연두를 쓴다.
//     여기서 그 선을 지킨다 - 나중에 누가 "더 연두답게" 밝히면 이 시험이 잡는다.
//

import Testing
import Foundation
import SwiftUI
import UIKit
@testable import ClipKeyboard

@Suite("checkGreen: 체크는 언제나 연두")
struct CheckGreenTests {

    private func rgb(_ color: Color, dark: Bool) -> (CGFloat, CGFloat, CGFloat) {
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
        let la = luminance(rgb(a, dark: dark)), lb = luminance(rgb(b, dark: dark))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// 체크가 앉는 바닥 셋 - 카드(surface) · 화면(bg) · 옅은 판(surfaceAlt).
    private func grounds(dark: Bool) -> [(String, Color)] {
        let t = AppTheme.resolve(kind: .paper, isDark: dark, accent: .system)
        return [("surface", t.surface), ("bg", t.bg), ("surfaceAlt", t.surfaceAlt)]
    }

    /// 글리프라 3:1 이 기준이다(WCAG non-text contrast).
    @Test("어느 바닥에서도 체크가 보인다")
    func legibleOnEveryGround() {
        for dark in [false, true] {
            for (name, ground) in grounds(dark: dark) {
                let ratio = contrast(.checkGreen, ground, dark: dark)
                #expect(ratio >= 3.0,
                        "\(dark ? "dark" : "light") \(name) 위에서 체크가 \(ratio) 밖에 안 된다")
            }
        }
    }

    /// ⚠️ 채워진 체크(`checkmark.circle.fill`)는 **글리프가 연두 원 위에** 얹힌다.
    ///    원만 보이고 체크가 안 보이면 그건 그냥 초록 점이다.
    ///
    /// ⚠️ 그래서 안쪽이 흰색이면 안 된다. 다크의 연두는 아주 밝아서 흰 체크가 1.4:1 로
    ///    사라진다 - 처음에 흰색으로 두었다가 이 시험이 잡았다.
    @Test("채워진 체크 안의 표시가 보인다")
    func glyphInsideTheFilledCircleIsLegible() {
        for dark in [false, true] {
            let ratio = contrast(.checkOnGreen, .checkGreen, dark: dark)
            #expect(ratio >= 3.0,
                    "\(dark ? "dark" : "light") 연두 원 위의 체크가 \(ratio) 밖에 안 된다")
        }
        // 흰색을 도로 넣으면 다크에서 사라진다는 것을 못박아 둔다.
        #expect(contrast(.white, .checkGreen, dark: true) < 3.0,
                "다크 연두 위의 흰 체크가 읽힌다면 연두가 너무 어두워진 것이다")
    }

    /// ⚠️ **키컬러와 달라야 한다.** 같아 보이면 체크를 떼어 낸 뜻이 없어진다.
    ///    쪽·솔처럼 초록·파랑 계열을 고른 사람에게도 구분돼야 한다.
    @Test("어떤 키컬러와도 눈에 띄게 다르다")
    func staysDistinctFromEveryAccent() {
        for candidate in AppAccent.allCases {
            for dark in [false, true] {
                let check = rgb(.checkGreen, dark: dark)
                let accent = rgb(candidate.accent(isDark: dark), dark: dark)
                let distance = abs(check.0 - accent.0) + abs(check.1 - accent.1) + abs(check.2 - accent.2)
                #expect(distance > 0.25,
                        "\(candidate.rawValue)/\(dark ? "dark" : "light") 키컬러가 체크 연두와 너무 닮았다")
            }
        }
    }

    /// ⚠️ 연두는 **노랑 쪽으로 기운 초록**이다. 순수 초록(hue 120°)으로 흘러가면
    ///    그건 이미 있는 `success` 초록과 같은 색이 되어 두 신호가 겹친다.
    @Test("초록이 아니라 연두다 - 색상환에서 노랑 쪽")
    func actuallyYellowGreen() {
        for dark in [false, true] {
            let (r, g, b) = rgb(.checkGreen, dark: dark)
            #expect(g > r && g > b, "\(dark ? "dark" : "light") 초록 성분이 가장 크지 않다")
            #expect(r > b, "\(dark ? "dark" : "light") 빨강이 파랑보다 커야 노랑 쪽으로 기운 연두다")
        }
    }
}
