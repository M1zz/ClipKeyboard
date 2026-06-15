//
//  MemoPreviewFormatter.swift
//  ClipKeyboard
//
//  Renders a one-line content preview for a Memo, with type-aware
//  formatting (URL domain, address truncation, token masking, etc.).
//

import Foundation

extension String {
    /// {중괄호}만 떼어낸 자연스러운 문장 — 템플릿 미리보기·하이라이트 입력칸에서 공용.
    /// (키보드 익스텐션 타겟에도 포함되는 파일이라 여기에 둔다.)
    var strippingTemplateBraces: String {
        replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
    }
}

enum MemoPreviewFormatter {

    static let maxPreviewLength = 40
    static let ellipsis = "…"

    /// Returns a one-line preview string for the memo's value.
    /// - Parameters:
    ///   - memo: The memo to format.
    ///   - resolvedType: The effective type (may come from category, autoDetectedType, or live classification).
    static func preview(for memo: Memo, resolvedType: ClipboardItemType?) -> String {
        if memo.isCombo {
            return comboPreview(memo)
        }
        if memo.isTemplate {
            return templatePreview(memo)
        }
        if memo.contentType == .image {
            return imagePreview(count: memo.imageFileNames.count)
        }

        let trimmed = singleLine(memo.value)
        if trimmed.isEmpty {
            if memo.contentType == .mixed {
                return imagePreview(count: memo.imageFileNames.count)
            }
            return ""
        }

        if memo.isSecure, let type = resolvedType, isMaskableType(type) {
            return maskedPreview(value: trimmed, type: type)
        }

        switch resolvedType {
        case .url:
            return urlPreview(trimmed)
        case .email, .phone:
            return truncate(trimmed)
        case .address:
            return truncate(trimmed)
        default:
            return truncate(trimmed)
        }
    }

    // MARK: - Helpers

    /// Accessibility label that describes masked content in full, so VoiceOver
    /// users can hear the last visible digits with context.
    static func accessibilityPreview(for memo: Memo, resolvedType: ClipboardItemType?) -> String {
        let preview = self.preview(for: memo, resolvedType: resolvedType)
        guard memo.isSecure, let type = resolvedType, isMaskableType(type) else {
            return preview
        }
        let typeName = type.localizedName
        let format = NSLocalizedString(
            "Masked %@, ending %@",
            comment: "Accessibility: masked sensitive content with type and tail digits"
        )
        let tail = preview.filter { $0.isNumber || $0.isLetter }
        return String(format: format, typeName, tail)
    }

    /// Extracts placeholder names from a template value, e.g. {이름} → "이름".
    static func extractPlaceholders(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "\\{([^}]+)\\}") else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        var seen = Set<String>()
        var result: [String] = []
        for match in matches where match.numberOfRanges >= 2 {
            if let r = Range(match.range(at: 1), in: text) {
                let name = String(text[r])
                if seen.insert(name).inserted {
                    result.append(name)
                }
            }
        }
        return result
    }

    // MARK: - Type-specific renderers

    private static func templatePreview(_ memo: Memo) -> String {
        // 리스트 행에서는 {중괄호}를 떼고 자연스럽게 — 변수 개수는 "· N variables"로 안내된다.
        let first = truncate(singleLine(memo.value).strippingTemplateBraces, max: 28)
        let placeholders = extractPlaceholders(in: memo.value)
        guard !placeholders.isEmpty else { return first }
        let format = NSLocalizedString("%d variables", comment: "Template placeholder count suffix")
        let count = String(format: format, placeholders.count)
        return "\(first) · \(count)"
    }

    private static func comboPreview(_ memo: Memo) -> String {
        // 첫 번째 값을 앞세우고 개수는 꼬리로 — 템플릿 미리보기("첫 줄 · N variables")와 동일 스타일.
        guard let first = memo.comboValues.first else { return truncate(singleLine(memo.value)) }
        let format = NSLocalizedString("%d items", comment: "Combo item count preview")
        let count = String(format: format, memo.comboValues.count)
        return "\(truncate(singleLine(first), max: 28)) · \(count)"
    }

    private static func imagePreview(count: Int) -> String {
        let n = max(count, 1)
        let format = NSLocalizedString("%d image(s)", comment: "Image count preview")
        return String(format: format, n)
    }

    private static func urlPreview(_ value: String) -> String {
        // Try parse with URL; fall back to a naive host extraction.
        if let url = URL(string: value), let host = url.host {
            let path = url.path
            let combined = path.isEmpty || path == "/" ? host : "\(host)\(path)"
            return truncate(combined)
        }
        // Strip scheme manually if URL init failed.
        var stripped = value
        for scheme in ["https://", "http://"] {
            if stripped.hasPrefix(scheme) {
                stripped = String(stripped.dropFirst(scheme.count))
                break
            }
        }
        return truncate(stripped)
    }

    private static func maskedPreview(value: String, type: ClipboardItemType) -> String {
        let digits = value.filter { $0.isNumber || $0.isLetter }
        guard !digits.isEmpty else { return String(repeating: "•", count: 4) }

        let tailLength: Int
        switch type {
        case .creditCard, .bankAccount:
            tailLength = 4
        case .passportNumber, .taxID, .insuranceNumber, .medicalRecord, .employeeID:
            tailLength = 3
        default:
            tailLength = 4
        }

        let tail = String(digits.suffix(tailLength))
        return "•••• \(tail)"
    }

    // MARK: - Utilities

    private static func isMaskableType(_ type: ClipboardItemType) -> Bool {
        switch type {
        case .creditCard, .bankAccount, .passportNumber, .taxID,
             .insuranceNumber, .medicalRecord, .employeeID:
            return true
        default:
            return false
        }
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func truncate(_ text: String, max: Int = maxPreviewLength) -> String {
        guard text.count > max else { return text }
        let end = text.index(text.startIndex, offsetBy: max)
        return String(text[..<end]) + ellipsis
    }
}
