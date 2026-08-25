//
//  ColorExtension.swift
//  ClipKeyboard
//
//  Created by Claude Code
//
//  공용 잎사귀(Color hex 변환·fromName, UIImage 유틸, HapticManager)는 LeeoKit으로 이전됨.
//  이 파일에는 ClipKeyboard 고유 디자인 색상만 남긴다.
//

import SwiftUI
import UIKit

extension Color {
    // MARK: - App-specific Design System Colors (ClipKeyboard 고유 - 공유하지 않음)

    /// 즐겨찾기 지정색 - 시스템 핑크보다 더 선명한 분홍(#FF4A9E).
    ///
    /// 앱과 키보드가 **같은 분홍**이어야 한다. 예전에는 앱 쪽 목록 파일에 있고
    /// 키보드는 타깃이 갈린다는 이유로 같은 숫자를 인라인으로 적어 두었는데,
    /// 두 곳에 있는 색은 언젠가 한쪽만 바뀐다. 두 타깃이 함께 보는 이 파일로 옮긴다.
    static let clipFavorite = Color(red: 1.0, green: 0.29, blue: 0.62)

    /// 키컬러 위에 얹는 글자·아이콘 색.
    ///
    /// 라이트의 키컬러는 짙어서 흰 글자가 잘 보이지만, 다크의 키컬러는 밝게 띄운
    /// 색이라 흰 글자를 얹으면 대비가 3:1 아래로 떨어진다. 두 모드에서 같은 `.white` 를
    /// 쓰는 대신 이 색을 쓴다. (테마 토큰이 닿는 곳은 `theme.accentFg`.)
    ///
    /// ⚠️ **사용자가 고른 키컬러를 따라간다.** 예전에는 다크 값이 짙은 갈색(#2A0E03)으로
    ///    못박혀 있었다 - 키컬러가 주황 하나뿐이던 시절의 짝이다. 그대로 두면 먹을 고른
    ///    사람의 화면에서 흰 바탕 위에 **갈색 글자**가 얹힌다.
    static var accentForeground: Color {
        let choice = AppAccent.current
        return Color(UIColor { trait in
            UIColor(choice.accentFg(isDark: trait.userInterfaceStyle == .dark))
        })
    }

    /// **체크 표시는 언제나 연두다.**
    ///
    /// ⚠️ 키컬러를 고를 수 있게 되면서(`AppAccent`) 생긴 규칙이다. 체크를 키컬러로 그리면
    ///    자두를 고른 사람에게는 **자주색 체크**가, 먹을 고른 사람에게는 **검은 체크**가
    ///    뜬다. "골랐다 · 됐다 · 맞다"는 색을 갖고 있는 말이고, 그 색은 사람이 고르는 것이
    ///    아니다. 그래서 체크만은 키컬러에서 떼어 낸다.
    ///
    /// ⚠️ 값은 눈으로만 고르지 않았다. 진짜 연두(#9ACD32)는 흰 바탕에서 1.9:1 이라
    ///    글리프가 안 보인다. 라이트는 읽히는 선까지 눌러 내린 연두(3.9:1 on white),
    ///    다크는 마음껏 밝은 연두다. 시험이 이 선을 지킨다(`CheckGreenTests`).
    static var checkGreen: Color {
        Color(UIColor { trait in
            UIColor(checkGreen(isDark: trait.userInterfaceStyle == .dark))
        })
    }

    /// 밝기를 **못박아** 고른 체크 연두.
    ///
    /// ⚠️ 그리는 자리의 트레이트를 못 믿는 곳에서 쓴다. 실제로 공유 영상이 그랬다
    ///    (`ShareVideoRenderer`) - `ImageRenderer` 는 화면과 무관하게 라이트 트레이트로
    ///    굽기 때문에, 위의 동적 색을 쓰면 **어두운 영상에도 라이트용 초록**이 들어간다.
    ///    구워 놓고 보기 전에는 안 보이는 종류의 어긋남이다.
    static func checkGreen(isDark: Bool) -> Color {
        isDark ? Color(red: 0xA8/255, green: 0xE0/255, blue: 0x63/255)
               : Color(red: 0x52/255, green: 0x90/255, blue: 0x1A/255)
    }

    /// 채워진 체크(`checkmark.circle.fill`) **안쪽** 표시색.
    ///
    /// ⚠️ 흰색이면 안 된다. 다크의 연두(#A8E063)는 아주 밝아서 흰 체크를 얹으면 1.4:1 이라
    ///    원만 보이고 체크가 안 보인다 - 그건 그냥 초록 점이다. 짙은 먹을 얹으면
    ///    라이트 연두(4.9:1) 와 다크 연두(12.9:1) 양쪽에서 다 읽힌다.
    static let checkOnGreen = Color(red: 0x10/255, green: 0x14/255, blue: 0x0A/255)

    /// 브랜드 주황 - 키컬러(#E8501C).
    /// 라이트/다크로 뒤집히는 `Color.accentColor` 와 달리 **항상 같은 값**이라,
    /// 흰 글자를 얹는 그라데이션 버튼처럼 대비가 고정돼야 하는 곳에 쓴다.
    static let clipBrand = Color(red: 0xE8/255, green: 0x50/255, blue: 0x1C/255)

    /// 브랜드 짙은 주황(#B83A0F).
    /// 키컬러와 짝을 이뤄 그라데이션의 어두운 쪽을 맡는다.
    static let clipBrandDeep = Color(red: 0xB8/255, green: 0x3A/255, blue: 0x0F/255)

    /// 브랜드 노랑(#F0A93A). 강조 배지·하이라이트용 - 키컬러와 같은 따뜻한 줄에 선다.
    static let clipBrandYellow = Color(red: 0xF0/255, green: 0xA9/255, blue: 0x3A/255)

    /// 두 색을 섞는다. `amount` 는 **받는 쪽(self)** 의 비율.
    ///
    /// 대비 증가에서 흐린 글자를 본문 색 쪽으로 당길 때 쓴다. 회색을 더 진하게 만드는 것이
    /// 아니라 본문에 가깝게 섞어야, 테마가 바뀌어도(종이/저녁) 그 테마의 글자색을 따라간다.
    ///
    /// ⚠️ 라이트/다크로 뒤집히는 색이라 `UIColor` 로 내려가 **각 모드에서 따로 섞는다.**
    ///    한쪽에서 섞은 값을 양쪽에 쓰면 반대 모드에서 글자가 배경에 묻는다.
    func mixed(with other: Color, amount: Double) -> Color {
        let a = UIColor(self), b = UIColor(other)
        let t = CGFloat(max(0, min(1, amount)))
        return Color(UIColor { trait in
            var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
            var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
            a.resolvedColor(with: trait).getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
            b.resolvedColor(with: trait).getRed(&br, green: &bg, blue: &bb, alpha: &ba)
            return UIColor(red:   ar * t + br * (1 - t),
                           green: ag * t + bg * (1 - t),
                           blue:  ab * t + bb * (1 - t),
                           alpha: aa * t + ba * (1 - t))
        })
    }

    /// Toast background color
    static var toastBackground: Color {
        Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 0.9))
    }

    /// Toast text color
    static let toastText = Color.white

    /// Secure/Lock icon color
    static let appSecureIcon = Color.orange

    /// Template icon color
    static let appTemplateIcon = Color.purple

    /// Button background (light overlay)
    static var appButtonBackground: Color {
        Color(UIColor.systemGray5)
    }

    /// Onboarding overlay background
    static var appOnboardingOverlay: Color {
        Color.white.opacity(0.15)
    }
}
