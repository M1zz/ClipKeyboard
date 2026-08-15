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
