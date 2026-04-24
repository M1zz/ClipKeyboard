//
//  ColorExtension.swift
//  ClipKeyboard
//
//  Created by Claude Code
//

import SwiftUI
import UIKit

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        #if canImport(UIKit)
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        #elseif canImport(AppKit)
        guard let components = NSColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        #else
        return nil
        #endif

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])

        return String(format: "%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }

    // MARK: - Named Color Mapping

    /// 색상 이름 문자열에서 Color 반환 (테마·카테고리 색상 공통 사용)
    static func fromName(_ name: String) -> Color {
        let colorMap: [String: Color] = [
            "blue": .blue, "green": .green, "purple": .purple,
            "orange": .orange, "red": .red, "indigo": .indigo,
            "brown": .brown, "cyan": .cyan, "teal": .teal,
            "pink": .pink, "mint": .mint, "yellow": .yellow
        ]
        return colorMap[name] ?? .gray
    }

    // MARK: - Design System Colors

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

// MARK: - UIImage Extensions for Clipboard
extension UIImage {
    /// 이미지를 Base64 문자열로 변환
    func toBase64(compressionQuality: CGFloat = 0.8) -> String? {
        guard let imageData = self.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        return imageData.base64EncodedString()
    }

    /// Base64 문자열에서 UIImage 생성
    static func from(base64: String) -> UIImage? {
        guard let imageData = Data(base64Encoded: base64) else {
            return nil
        }
        return UIImage(data: imageData)
    }

    /// 이미지를 특정 크기로 리사이즈 (썸네일 생성용)
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    /// 이미지를 최대 너비/높이로 제한 (메모리 절약)
    func constrainedSize(maxDimension: CGFloat = 1024) -> UIImage? {
        let maxSize = max(size.width, size.height)
        if maxSize <= maxDimension {
            return self
        }

        let ratio = maxDimension / maxSize
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        return resized(to: newSize)
    }

    /// 이미지 포맷 감지
    var imageFormat: String {
        guard let data = self.pngData() ?? self.jpegData(compressionQuality: 1.0) else {
            return "unknown"
        }

        // 첫 바이트로 이미지 포맷 판별
        let byte: UInt8 = data[0]
        switch byte {
        case 0xFF: return "jpeg"
        case 0x89: return "png"
        case 0x47: return "gif"
        case 0x49, 0x4D: return "tiff"
        default: return "unknown"
        }
    }
}

// MARK: - Haptic Feedback Manager
#if canImport(UIKit)
struct HapticManager {
    static let shared = HapticManager()
    private init() {}

    /// Light impact - for button taps, toggles
    func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Medium impact - for significant actions
    func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Heavy impact - for important completions
    func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Success notification - for successful operations
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Warning notification - for warnings
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Error notification - for errors
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    /// Selection changed - for picker changes
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    /// Rigid impact - for delete actions
    func rigid() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }

    /// Soft impact - for subtle interactions
    func soft() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }
}
#else
// macOS fallback - no haptics
struct HapticManager {
    static let shared = HapticManager()
    private init() {}

    func light() {}
    func medium() {}
    func heavy() {}
    func success() {}
    func warning() {}
    func error() {}
    func selection() {}
    func rigid() {}
    func soft() {}
}
#endif
