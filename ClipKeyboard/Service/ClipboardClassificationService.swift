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

    // MARK: - Memoized Resolver

    /// 리스트 렌더 시점에 재분류 비용을 피하기 위한 in-memory 캐시.
    /// 키: memo id + value 해시. memo.value가 바뀌면 새로 분류된다.
    private var resolverCache: [UUID: (contentHash: Int, type: ClipboardItemType)] = [:]

    /// ⚠️ 직렬 큐가 아니라 **락**이다.
    ///
    /// 예전에는 `DispatchQueue(label:).sync` 였다. 이 캐시는 `applyFilters()` 안에서
    /// **항목마다** 읽고 쓰이고, `applyFilters()` 는 검색어 `onChange` 에 물려 있다.
    /// 즉 글자 하나를 칠 때마다 `메모 수 × 2` 번의 큐 홉이 메인 스레드에서 일어났다.
    /// 큐 홉은 스레드를 실제로 재우고 깨우지만, 여기서 지키는 것은 딕셔너리 한 개다.
    /// 경합이 거의 없는 짧은 구간이라 `NSLock` 이 비교가 안 되게 싸다.
    /// (WWDC23 "Analyze hangs with Instruments" 의 Blocked Main Thread 사례)
    private let resolverLock = NSLock()

    /// 메모에 적용할 타입을 결정한다.
    /// 우선순위: 명시 카테고리 매칭 → autoDetectedType → contentType(이미지) → 콘텐츠 기반 자동분류
    /// - Note: `memo.category`는 영속 수정하지 않는다. 이 결과는 UI 표시용 캐시일 뿐이다.
    func resolvedType(for memo: Memo) -> ClipboardItemType? {
        if let explicit = ClipboardItemType.allCases.first(where: { $0.rawValue == memo.category }) {
            return explicit
        }
        if let auto = memo.autoDetectedType {
            return auto
        }
        if memo.contentType == .image {
            return .image
        }
        let trimmed = memo.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let hash = trimmed.hashValue
        resolverLock.lock()
        let cached = resolverCache[memo.id]
        resolverLock.unlock()
        if let cached, cached.contentHash == hash { return cached.type }

        let classified = classify(content: trimmed)
        // 신뢰도가 너무 낮으면 기본 '텍스트'로 남겨 잘못된 아이콘을 피한다.
        let type: ClipboardItemType = classified.confidence >= 0.5 ? classified.type : .text
        resolverLock.lock()
        resolverCache[memo.id] = (hash, type)
        resolverLock.unlock()
        return type
    }

    /// 특정 메모의 캐시만 제거 (편집/삭제 시 호출 가능).
    func invalidateResolvedType(for memoId: UUID) {
        resolverLock.lock()
        _ = resolverCache.removeValue(forKey: memoId)
        resolverLock.unlock()
    }

    // MARK: - Public Methods

    /// 클립보드 내용을 자동으로 분류
    /// - Parameter content: 분류할 텍스트
    /// - Returns: (타입, 신뢰도) 튜플
    func classify(content: String) -> (type: ClipboardItemType, confidence: Double) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (.text, 0.0) }

        // 높은 신뢰도·구체적인 패턴부터 순서대로 검사 (테이블 기반)
        // v4.0: Korea-only detectors (detectVehiclePlate, detectAddress)는 우선순위에서 제거
        // 글로벌 IBAN/SWIFT/VAT/Crypto/PayPal 우선 배치
        let detectors: [(String) -> (type: ClipboardItemType, confidence: Double)?] = [
            detectIBAN,            // 가장 엄격 (mod-97 체크섬)
            detectSWIFT,
            detectVAT,
            detectCryptoWallet,
            detectPayPalLink,
            detectCreditCard,
            detectEmail,
            detectURL,
            detectPassportNumber,
            detectDeclarationNumber,
            detectIPAddress,
            detectBirthDate,       // 계좌번호보다 먼저
            detectPostalCode,
            detectPhoneStrong,     // E.164 + 한국 010 등 신뢰도 높은 패턴만
            detectBankAccount,     // 한국 전화번호 형식과 겹치는 약한 phone 패턴 전에 시도
            detectPhoneWeak,       // 일반 10~15자리 숫자 (계좌번호 안 매치된 경우만)
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

    // 클립보드 그림을 base64 로 바꿔 히스토리에 담던 길(`createHistoryFromImage`)은 걷어냈다.
    // 부르는 곳이 없어진 지 오래인데, 예전에 담긴 그림이 히스토리 파일에 남아 키보드가 뜰 때마다
    // 통째로 메모리에 올라와 키보드가 죽었다(docs/postmortem/KEYBOARD_CLIPBOARD_IMAGES_5_1_8.md).
    // 다시 그림을 담으려면 파일을 따로 두고 이름만 적는다. 히스토리 JSON 안에 넣지 않는다.

    // MARK: - 정규식 (미리 만들어 둔다)

    /// 패턴마다 한 번만 만든 정규식. 키보드와 앱이 함께 쓴다.
    ///
    /// ⚠️ 예전에는 `String.range(of:options: .regularExpression)` 로 검사할 때마다 패턴을 새로
    ///    컴파일했다. 분류 한 번에 20개 남짓, 단축어 추가 화면에서는 **한 글자마다** 돌았다.
    private static let regexLock = NSLock()
    private static var regexCache: [String: NSRegularExpression] = [:]

    static func matches(_ pattern: String, in text: String) -> Bool {
        regexLock.lock()
        let regex: NSRegularExpression?
        if let cached = regexCache[pattern] {
            regex = cached
        } else {
            regex = try? NSRegularExpression(pattern: pattern)
            if let regex { regexCache[pattern] = regex }
        }
        regexLock.unlock()
        guard let regex else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// ASCII 숫자만 남긴다(`[^0-9]` 를 지우는 것과 같다). `keeping` 에 든 글자는 남긴다.
    static func asciiDigits(_ text: String, keeping extra: Set<Character> = []) -> String {
        String(text.filter { ("0"..."9").contains($0) || extra.contains($0) })
    }

    // MARK: - Detection Methods

    private func detectEmail(_ text: String) -> (ClipboardItemType, Double)? {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        if Self.matches(emailRegex, in: text) {
            return (.email, 0.95)
        }
        return nil
    }

    /// 신뢰도 높은 phone 패턴: E.164 + 한국 010/0X. 이 단계에서 안 잡히면
    /// detectBankAccount에 양보 (계좌번호 형식과 한국 전화번호가 겹치는 경계 케이스 처리).
    private func detectPhoneStrong(_ text: String) -> (ClipboardItemType, Double)? {
        let hasPlus = text.trimmingCharacters(in: .whitespaces).hasPrefix("+")
        let cleaned = Self.asciiDigits(text)

        // E.164: + 와 함께 7~15 자리 숫자
        if hasPlus && cleaned.count >= 7 && cleaned.count <= 15 {
            return (.phone, 0.92)
        }

        // 한국 010/0X 번호만 강한 신뢰도로 phone 처리
        if !hasPlus && cleaned.count >= 10 && cleaned.count <= 15 {
            let koreanPatterns = [
                "^010[0-9]{8}$",
                "^01[016789][0-9]{7,8}$",
                "^0[2-6][0-9]{7,8}$"
            ]
            for pattern in koreanPatterns {
                if Self.matches(pattern, in: cleaned) {
                    return (.phone, 0.9)
                }
            }
        }

        return nil
    }

    /// 약한 phone 패턴: 일반 10~15자리 숫자 (`+` 없음). detectBankAccount 다음에
    /// 호출되어 계좌번호로 매치 안 된 경우에만 phone으로 잡는다.
    private func detectPhoneWeak(_ text: String) -> (ClipboardItemType, Double)? {
        let hasPlus = text.trimmingCharacters(in: .whitespaces).hasPrefix("+")
        let cleaned = Self.asciiDigits(text)
        if !hasPlus && cleaned.count >= 10 && cleaned.count <= 15 {
            return (.phone, 0.55)
        }
        return nil
    }

    private func detectURL(_ text: String) -> (ClipboardItemType, Double)? {
        let urlRegex = "^(https?://|www\\.)[^\\s]+"
        if Self.matches(urlRegex, in: text) {
            return (.url, 0.95)
        }

        if text.contains(".com") || text.contains(".net") || text.contains(".kr") || text.contains(".io") {
            return (.url, 0.7)
        }

        return nil
    }

    private func detectCreditCard(_ text: String) -> (ClipboardItemType, Double)? {
        let cleaned = Self.asciiDigits(text)

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

        let cleaned = Self.asciiDigits(text, keeping: ["-"])

        let patterns = [
            "^[0-9]{2,4}-[0-9]{2,6}-[0-9]{2,8}$",
            "^[0-9]{10,14}$"
        ]

        for pattern in patterns {
            if Self.matches(pattern, in: cleaned) {
                return (.bankAccount, 0.6)
            }
        }

        return nil
    }

    private func detectPassportNumber(_ text: String) -> (ClipboardItemType, Double)? {
        let passportRegex = "^[MmSs][0-9]{8}$"
        if Self.matches(passportRegex, in: text) {
            return (.passportNumber, 0.9)
        }
        return nil
    }

    private func detectDeclarationNumber(_ text: String) -> (ClipboardItemType, Double)? {
        let declarationRegex = "^[Pp][0-9]{12}$"
        if Self.matches(declarationRegex, in: text) {
            return (.declarationNumber, 0.95)
        }
        return nil
    }

    private func detectPostalCode(_ text: String) -> (ClipboardItemType, Double)? {
        // v4.0: 국가별 우편번호 포맷 다양 (3~10자, 일부는 문자 포함 UK/CA/NL)
        // 순수 숫자는 자동분류 신뢰도 낮춤 (오탐 위험 높음).
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        // US/KR/DE/FR/JP 등 5자리 숫자 우편번호
        let digitCleaned = Self.asciiDigits(trimmed)
        if digitCleaned == trimmed, digitCleaned.count == 5 {
            return (.postalCode, 0.55)
        }
        // UK 포맷 예: SW1A 1AA, EC1A 1BB (문자+숫자 조합)
        if Self.matches("^[A-Z]{1,2}[0-9][0-9A-Z]? ?[0-9][A-Z]{2}$", in: trimmed) {
            return (.postalCode, 0.85)
        }
        // Canada 포맷 예: K1A 0B1
        if Self.matches("^[A-Z][0-9][A-Z] ?[0-9][A-Z][0-9]$", in: trimmed) {
            return (.postalCode, 0.85)
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
            if Self.matches(pattern, in: text) {
                return (.birthDate, 0.75)
            }
        }

        return nil
    }

    // NOTE: detectVehiclePlate는 v4.0에서 자동분류 우선순위에서 제거됨 (한국 전용 패턴).
    //       사용자가 수동으로 '차량번호' 카테고리를 지정하는 기능은 enum에 남아 있어 기존 데이터 호환.

    private func detectIPAddress(_ text: String) -> (ClipboardItemType, Double)? {
        let ipv4Pattern = "^([0-9]{1,3}\\.){3}[0-9]{1,3}$"
        if Self.matches(ipv4Pattern, in: text) {
            let octets = text.split(separator: ".").compactMap { Int($0) }
            if octets.count == 4 && octets.allSatisfy({ $0 >= 0 && $0 <= 255 }) {
                return (.ipAddress, 0.95)
            }
        }

        let ipv6Pattern = "^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$"
        if Self.matches(ipv6Pattern, in: text) {
            return (.ipAddress, 0.85)
        }

        return nil
    }

    private func detectName(_ text: String) -> (ClipboardItemType, Double)? {
        let namePattern = "^[가-힣]{2,4}$"
        if Self.matches(namePattern, in: text) {
            return (.name, 0.5)
        }

        let englishNamePattern = "^[A-Z][a-z]+( [A-Z][a-z]+)*$"
        if Self.matches(englishNamePattern, in: text) {
            return (.name, 0.6)
        }

        return nil
    }

    // NOTE: detectAddress는 v4.0에서 자동분류 우선순위에서 제거됨 (한국 주소 키워드 기반).
    //       'address' enum case는 사용자 수동 카테고리로 여전히 사용 가능.

    // MARK: - v4.0 Global Detectors

    /// IBAN (International Bank Account Number) 검증 - ISO 13616 mod-97 체크섬
    private func detectIBAN(_ text: String) -> (ClipboardItemType, Double)? {
        let normalized = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()

        // 기본 형식: 2자리 국가코드 + 2자리 체크 + 최대 30자리
        guard Self.matches("^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$", in: normalized) else {
            return nil
        }

        // mod-97 체크섬 검증
        // 앞 4자를 뒤로 이동 후 문자를 숫자로 치환 (A=10, B=11, ..., Z=35)
        let rearranged = String(normalized.dropFirst(4)) + String(normalized.prefix(4))
        var numeric = ""
        for char in rearranged {
            if char.isLetter {
                guard let ascii = char.asciiValue else { return nil }
                numeric += String(Int(ascii) - 55)
            } else {
                numeric.append(char)
            }
        }

        // 긴 숫자 mod-97: 청크 단위로 처리
        var remainder = 0
        for digitChar in numeric {
            guard let digit = Int(String(digitChar)) else { return nil }
            remainder = (remainder * 10 + digit) % 97
        }

        if remainder == 1 {
            return (.iban, 0.97)
        }
        return nil
    }

    /// SWIFT/BIC 코드 - 8자 또는 11자 (AAAA BB CC [DDD])
    private func detectSWIFT(_ text: String) -> (ClipboardItemType, Double)? {
        let normalized = text.trimmingCharacters(in: .whitespaces).uppercased()
        let pattern = "^[A-Z]{4}[A-Z]{2}[A-Z0-9]{2}([A-Z0-9]{3})?$"
        if Self.matches(pattern, in: normalized) {
            return (.swift, 0.9)
        }
        return nil
    }

    /// VAT 번호 (EU + UK). 국가 prefix + 숫자/영숫자 8~12자.
    private func detectVAT(_ text: String) -> (ClipboardItemType, Double)? {
        let normalized = text.replacingOccurrences(of: " ", with: "").uppercased()
        let euCountries = "AT|BE|BG|CY|CZ|DE|DK|EE|EL|ES|FI|FR|GB|HR|HU|IE|IT|LT|LU|LV|MT|NL|PL|PT|RO|SE|SI|SK|XI"
        let pattern = "^(\(euCountries))[0-9A-Z+*.]{8,12}$"
        if Self.matches(pattern, in: normalized) {
            return (.vat, 0.85)
        }
        return nil
    }

    /// Crypto 지갑 주소 - BTC (legacy, bech32), ETH (0x 시작 40 hex).
    private func detectCryptoWallet(_ text: String) -> (ClipboardItemType, Double)? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        // BTC legacy (P2PKH, P2SH): 1 또는 3으로 시작, Base58 26~35자
        if Self.matches("^[13][a-km-zA-HJ-NP-Z1-9]{25,34}$", in: trimmed) {
            return (.cryptoWallet, 0.9)
        }
        // BTC bech32 (SegWit): bc1 시작
        if Self.matches("^bc1[a-z0-9]{39,59}$", in: trimmed.lowercased()) {
            return (.cryptoWallet, 0.95)
        }
        // ETH / ERC-20 / Polygon / BSC: 0x + 40 hex
        if Self.matches("^0x[a-fA-F0-9]{40}$", in: trimmed) {
            return (.cryptoWallet, 0.95)
        }
        // TRON: T로 시작, Base58 34자
        if Self.matches("^T[a-km-zA-HJ-NP-Z1-9]{33}$", in: trimmed) {
            return (.cryptoWallet, 0.9)
        }
        return nil
    }

    /// PayPal.me 링크 - paypal.me/username.
    private func detectPayPalLink(_ text: String) -> (ClipboardItemType, Double)? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let pattern = "^(https?://)?(www\\.)?paypal\\.me/[A-Za-z0-9_.-]+/?$"
        if Self.matches(pattern, in: trimmed) {
            return (.paypalLink, 0.95)
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
