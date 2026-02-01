#!/usr/bin/swift
//
// ClipboardClassificationService 테스트
// 터미널에서 실행: swift test_classification.swift
//

import Foundation

// ClipboardItemType enum (복사)
enum ClipboardItemType: String, Codable, CaseIterable {
    case email = "이메일"
    case phone = "전화번호"
    case address = "주소"
    case url = "URL"
    case creditCard = "카드번호"
    case bankAccount = "계좌번호"
    case passportNumber = "여권번호"
    case declarationNumber = "신고번호"
    case postalCode = "우편번호"
    case name = "이름"
    case birthDate = "생년월일"
    case text = "텍스트"
}

// ClipboardClassificationService (복사)
class ClipboardClassificationService {
    static let shared = ClipboardClassificationService()

    func classify(content: String) -> (type: ClipboardItemType, confidence: Double) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return (.text, 0.0) }

        if let result = detectCreditCard(trimmed) { return result }
        if let result = detectEmail(trimmed) { return result }
        if let result = detectPhone(trimmed) { return result }
        if let result = detectURL(trimmed) { return result }
        if let result = detectPassportNumber(trimmed) { return result }
        if let result = detectCustomsCode(trimmed) { return result }
        if let result = detectBirthDate(trimmed) { return result }
        if let result = detectPostalCode(trimmed) { return result }
        if let result = detectBankAccount(trimmed) { return result }

        return (.text, 0.3)
    }

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
        guard cleaned.count >= 13 && cleaned.count <= 19 else { return nil }
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

    private func detectCustomsCode(_ text: String) -> (ClipboardItemType, Double)? {
        let customsRegex = "^[Pp][0-9]{12}$"
        if text.range(of: customsRegex, options: .regularExpression) != nil {
            return (.customsCode, 0.95)
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

// 테스트 케이스
let testCases: [(String, ClipboardItemType)] = [
    ("test@example.com", .email),
    ("user.name+tag@domain.co.kr", .email),

    ("01012345678", .phone),
    ("010-1234-5678", .phone),
    ("02-1234-5678", .phone),

    ("https://www.google.com", .url),
    ("www.naver.com", .url),
    ("github.com", .url),

    ("4532015112830366", .creditCard),  // Visa 테스트 번호
    ("5425233430109903", .creditCard),  // Mastercard 테스트 번호

    ("110-123-456789", .bankAccount),
    ("12345678901234", .bankAccount),

    ("M12345678", .passportNumber),
    ("S87654321", .passportNumber),

    ("P123456789012", .customsCode),

    ("12345", .postalCode),

    ("1990-01-15", .birthDate),
    ("1990.01.15", .birthDate),
    ("19900115", .birthDate),

    ("just some text", .text),
    ("안녕하세요", .text)
]

print("🧪 ClipboardClassificationService 테스트 시작\n")
print(String(repeating: "=", count: 70))

var passed = 0
var failed = 0

for (input, expected) in testCases {
    let result = ClipboardClassificationService.shared.classify(content: input)
    let status = result.type == expected ? "✅ PASS" : "❌ FAIL"

    if result.type == expected {
        passed += 1
    } else {
        failed += 1
    }

    print("\(status) | \(input)")
    print("     예상: \(expected.rawValue)")
    print("     결과: \(result.type.rawValue) (신뢰도: \(Int(result.confidence * 100))%)")
    print(String(repeating: "-", count: 70))
}

print("\n📊 테스트 결과")
print(String(repeating: "=", count: 70))
print("총 \(testCases.count)개 테스트")
print("통과: \(passed)개 ✅")
print("실패: \(failed)개 ❌")
print("성공률: \(Int(Double(passed) / Double(testCases.count) * 100))%")
print(String(repeating: "=", count: 70))

if failed == 0 {
    print("\n🎉 모든 테스트 통과!")
} else {
    print("\n⚠️  일부 테스트 실패. 패턴 개선 필요.")
}
