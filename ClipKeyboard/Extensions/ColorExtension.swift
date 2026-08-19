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

    /// 키컬러(AccentColor 에셋) 위에 얹는 글자·아이콘 색.
    ///
    /// 라이트의 키컬러는 짙은 녹색이라 흰 글자가 잘 보이지만, 다크의 키컬러는
    /// 밝은 민트라 흰 글자를 얹으면 대비가 3:1 아래로 떨어진다. 두 모드에서
    /// 같은 `.white` 를 쓰는 대신 이 색을 쓴다. (테마 토큰이 닿는 곳은 `theme.accentFg`.)
    static var accentForeground: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0x06/255, green: 0x23/255, blue: 0x1D/255, alpha: 1)
                : .white
        })
    }

    /// 브랜드 녹색 - 캐릭터 몸통에서 뽑은 키컬러(#1F7A67).
    /// 라이트/다크로 뒤집히는 `Color.accentColor` 와 달리 **항상 같은 값**이라,
    /// 흰 글자를 얹는 그라데이션 버튼처럼 대비가 고정돼야 하는 곳에 쓴다.
    static let clipBrand = Color(red: 0x1F/255, green: 0x7A/255, blue: 0x67/255)

    /// 브랜드 짙은 녹색 - 캐릭터 외곽선에서 뽑은 색(#0E5A4C).
    /// 키컬러와 짝을 이뤄 그라데이션의 어두운 쪽을 맡는다.
    static let clipBrandDeep = Color(red: 0x0E/255, green: 0x5A/255, blue: 0x4C/255)

    /// 브랜드 노랑 - 캐릭터 배 쪽 색(#FCBE35). 강조 배지·하이라이트용.
    static let clipBrandYellow = Color(red: 0xFC/255, green: 0xBE/255, blue: 0x35/255)

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
