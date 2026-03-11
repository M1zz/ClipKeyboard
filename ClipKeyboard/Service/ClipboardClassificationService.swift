//
//  ClipboardClassificationService.swift
//  ClipKeyboard
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Clipboard Classification Service

/// 클립보드 내용 자동 분류 서비스
class ClipboardClassificationService {
    static let shared = ClipboardClassificationService()

    private init() {}

    // MARK: - Public Methods

    /// 클립보드 내용을 자동으로 분류
    /// - Parameter content: 분류할 텍스트
    /// - Returns: (타입, 신뢰도) 튜플
    func classify(content: String) -> (type: ClipboardItemType, confidence: Double) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (.text, 0.0) }

        // 높은 신뢰도·구체적인 패턴부터 순서대로 검사 (테이블 기반)
        // Korea-specific patterns removed for global categories
        // detectRRN, detectBusinessNumber 제거됨
        let detectors: [(String) -> (type: ClipboardItemType, confidence: Double)?] = [
            detectCreditCard,
            detectEmail,
            detectPhone,
            detectURL,
            detectPassportNumber,
            detectDeclarationNumber,
            detectVehiclePlate,
            detectIPAddress,
            detectBirthDate,    // 계좌번호보다 먼저
            detectPostalCode,
            detectBankAccount,  // 가장 유연한 패턴은 마지막
            detectAddress,
            detectName
        ]

        for detect in detectors {
            if let result = detect(trimmed) { return result }
        }

        return (.text, 0.3)
    }

    /// 사용자 피드백을 반영하여 학습 (향후 ML 모델 개선용)
    /// - Parameters:
    ///   - content: 원본 텍스트
    ///   - correctedType: 사용자가 수정한 타입
    func updateClassificationModel(content: String, correctedType: ClipboardItemType) {
        // TODO: 나중에 Core ML 모델 학습 또는 휴리스틱 개선
        print("📚 [Classification] 학습 데이터 수집: \(content) -> \(correctedType.rawValue)")
    }

    // MARK: - Clipboard Image Detection

    #if canImport(UIKit)
    /// 클립보드에서 내용 가져오기 (텍스트 또는 이미지)
    /// - Returns: SmartClipboardHistory 객체 또는 nil
    func checkClipboard() -> SmartClipboardHistory? {
        let pasteboard = UIPasteboard.general

        // 1. 이미지 우선 확인
        if let image = pasteboard.image {
            return createHistoryFromImage(image)
        }

        // 2. 텍스트 확인
        if let text = pasteboard.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return createHistoryFromText(text)
        }

        return nil
    }

    /// 이미지로부터 클립보드 히스토리 생성
    private func createHistoryFromImage(_ image: UIImage) -> SmartClipboardHistory? {
        let maxDimension: CGFloat = 1024
        let maxSize = max(image.size.width, image.size.height)

        var finalImage = image
        if maxSize > maxDimension {
            let ratio = maxDimension / maxSize
            let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)

            UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
            defer { UIGraphicsEndImageContext() }
            image.draw(in: CGRect(origin: .zero, size: newSize))

            guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
                return nil
            }
            finalImage = resizedImage
        }

        guard let imageData = finalImage.jpegData(compressionQuality: 0.7) else {
            return nil
        }
        let base64 = imageData.base64EncodedString()

        return SmartClipboardHistory(
            content: "이미지 (\(Int(finalImage.size.width))x\(Int(finalImage.size.height)))",
            contentType: .image,
            imageData: base64,
            detectedType: .text,
            confidence: 1.0
        )
    }

    /// 텍스트로부터 클립보드 히스토리 생성
    private func createHistoryFromText(_ text: String) -> SmartClipboardHistory {
        let classification = classify(content: text)

        return SmartClipboardHistory(
            content: text,
            contentType: .text,
            imageData: nil,
            detectedType: classification.type,
            confidence: classification.confidence
        )
    }

    /// 클립보드에 이미지가 있는지 확인
    func hasImage() -> Bool {
        return UIPasteboard.general.image != nil
    }

    /// 클립보드에 텍스트가 있는지 확인
    func hasText() -> Bool {
        if let text = UIPasteboard.general.string {
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }
    #endif

    // MARK: - Detection Methods

    private func detectEmail(_ text: String) -> (ClipboardItemType, Double)? {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        if text.range(of: emailRegex, options: .regularExpression) != nil {
            return (.email, 0.95)
        }
        return nil
    }

    private func detectPhone(_ text: String) -> (ClipboardItemType, Double)? {
        let cleaned = text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

        let patterns = [
            "^010[0-9]{8}$",
            "^01[016789][0-9]{7,8}$",
            "^0[2-6][0-9]{7,8}$",
            "^1[5-9][0-9]{2}$"
        ]

        for pattern in patterns {
            if cleaned.range(of: pattern, options: .regularExpression) != nil {
                return (.phone, 0.9)
            }
        }

        return nil
    }

    private func detectURL(_ text: String) -> (ClipboardItemType, Double)? {
        let urlRegex = "^(https?://|www\\.)[^\\s]+"
        if text.range(of: urlRegex, options: .regularExpression) != nil {
            return (.url, 0.95)
        }

        if text.contains(".com") || text.contains(".net") || text.contains(".kr") || text.contains(".io") {
            return (.url, 0.7)
        }

        return nil
    }

    private func detectCreditCard(_ text: String) -> (ClipboardItemType, Double)? {
        let cleaned = text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

        guard cleaned.count >= 13 && cleaned.count <= 19 else {
            return nil
        }

        if isValidLuhn(cleaned) {
            return (.creditCard, 0.85)
        }

        return nil
    }

    private func detectBankAccount(_ text: String) -> (ClipboardItemType, Double)? {
        if text.uppercased().hasPrefix("P") {
            return nil
        }

        let cleaned = text.replacingOccurrences(of: "[^0-9-]", with: "", options: .regularExpression)

        let patterns = [
            "^[0-9]{2,4}-[0-9]{2,6}-[0-9]{2,8}$",
            "^[0-9]{10,14}$"
        ]

        for pattern in patterns {
            if cleaned.range(of: pattern, options: .regularExpression) != nil {
                return (.bankAccount, 0.6)
            }
        }

        return nil
    }

    private func detectPassportNumber(_ text: String) -> (ClipboardItemType, Double)? {
        let passportRegex = "^[MmSs][0-9]{8}$"
        if text.range(of: passportRegex, options: .regularExpression) != nil {
            return (.passportNumber, 0.9)
        }
        return nil
    }

    private func detectDeclarationNumber(_ text: String) -> (ClipboardItemType, Double)? {
        let declarationRegex = "^[Pp][0-9]{12}$"
        if text.range(of: declarationRegex, options: .regularExpression) != nil {
            return (.declarationNumber, 0.95)
        }
        return nil
    }

    private func detectPostalCode(_ text: String) -> (ClipboardItemType, Double)? {
        let cleaned = text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if cleaned.count == 5 {
            return (.postalCode, 0.7)
        }
        return nil
    }

    private func detectBirthDate(_ text: String) -> (ClipboardItemType, Double)? {
        let patterns = [
            "^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
            "^[0-9]{4}\\.[0-9]{2}\\.[0-9]{2}$",
            "^[0-9]{4}/[0-9]{2}/[0-9]{2}$",
            "^[0-9]{6}$",
            "^[0-9]{8}$"
        ]

        for pattern in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return (.birthDate, 0.75)
            }
        }

        return nil
    }

    private func detectVehiclePlate(_ text: String) -> (ClipboardItemType, Double)? {
        let newPlatePattern = "^[0-9]{2,3}[가-힣][0-9]{4}$"
        if text.range(of: newPlatePattern, options: .regularExpression) != nil {
            return (.vehiclePlate, 0.9)
        }

        let oldPlatePattern1 = "^[가-힣][0-9]{4}$"
        let oldPlatePattern2 = "^[가-힣]{2}[0-9]{2}[가-힣][0-9]{4}$"

        if text.range(of: oldPlatePattern1, options: .regularExpression) != nil {
            return (.vehiclePlate, 0.85)
        }

        if text.range(of: oldPlatePattern2, options: .regularExpression) != nil {
            return (.vehiclePlate, 0.9)
        }

        return nil
    }

    private func detectIPAddress(_ text: String) -> (ClipboardItemType, Double)? {
        let ipv4Pattern = "^([0-9]{1,3}\\.){3}[0-9]{1,3}$"
        if text.range(of: ipv4Pattern, options: .regularExpression) != nil {
            let octets = text.split(separator: ".").compactMap { Int($0) }
            if octets.count == 4 && octets.allSatisfy({ $0 >= 0 && $0 <= 255 }) {
                return (.ipAddress, 0.95)
            }
        }

        let ipv6Pattern = "^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$"
        if text.range(of: ipv6Pattern, options: .regularExpression) != nil {
            return (.ipAddress, 0.85)
        }

        return nil
    }

    private func detectName(_ text: String) -> (ClipboardItemType, Double)? {
        let namePattern = "^[가-힣]{2,4}$"
        if text.range(of: namePattern, options: .regularExpression) != nil {
            return (.name, 0.5)
        }

        let englishNamePattern = "^[A-Z][a-z]+( [A-Z][a-z]+)*$"
        if text.range(of: englishNamePattern, options: .regularExpression) != nil {
            return (.name, 0.6)
        }

        return nil
    }

    private func detectAddress(_ text: String) -> (ClipboardItemType, Double)? {
        let addressKeywords = [
            "시", "도", "구", "동", "로", "길", "번지", "아파트",
            "빌딩", "타워", "층", "호", "번길", "대로"
        ]

        let keywordCount = addressKeywords.filter { text.contains($0) }.count

        if keywordCount >= 2 {
            return (.address, 0.7)
        }

        if text.range(of: "[0-9]{5}", options: .regularExpression) != nil &&
           text.range(of: "[가-힣]+", options: .regularExpression) != nil {
            return (.address, 0.65)
        }

        return nil
    }

    // MARK: - Helper Methods

    private func isValidLuhn(_ number: String) -> Bool {
        var sum = 0
        let reversedChars = number.reversed().map { String($0) }

        for (index, char) in reversedChars.enumerated() {
            guard let digit = Int(char) else { return false }

            if index % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }

        return sum % 10 == 0
    }
}
