//
//  ColorExtension.swift
//  Token memo
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
