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
    // MARK: - App-specific Design System Colors (ClipKeyboard 고유 — 공유하지 않음)

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
