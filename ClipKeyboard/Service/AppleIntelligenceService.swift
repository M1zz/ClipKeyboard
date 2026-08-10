//
//  AppleIntelligenceService.swift
//  ClipKeyboard
//
//  Apple Foundation Models(온디바이스 AI) 래퍼 - iOS 26+ Apple Intelligence 기기 전용.
//  1) 클립보드 자동 분류 보강: 정규식 신뢰도가 낮은 항목을 온디바이스 LLM으로 재분류
//  2) 붙여넣을 앱 예측: "이 텍스트는 어디에 붙여넣을 가능성이 높은가" → 단축 액션 제안
//  3) 온디바이스 번역: Apple Intelligence 지원 언어 간 무료 번역
//
//  ⚠️ 모든 처리는 온디바이스 - 텍스트가 기기를 떠나지 않는다.
//  ⚠️ 메인 앱 타겟 전용. 키보드 익스텐션은 메모리 제한 때문에 사용하지 않는다.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Availability

/// Foundation Models 사용 가능 상태 (설정 화면 안내용)
enum AIAvailability {
    case available              // 사용 가능
    case osNotSupported         // iOS 26 미만
    case deviceNotEligible      // Apple Intelligence 미지원 기기
    case appleIntelligenceOff   // 설정에서 Apple Intelligence 꺼짐
    case modelNotReady          // 모델 다운로드/준비 중

    var localizedDescription: String {
        switch self {
        case .available:
            return NSLocalizedString("사용 가능", comment: "AI availability: available")
        case .osNotSupported:
            return NSLocalizedString("iOS 26 이상에서 사용할 수 있어요", comment: "AI availability: OS not supported")
        case .deviceNotEligible:
            return NSLocalizedString("이 기기는 Apple Intelligence를 지원하지 않아요", comment: "AI availability: device not eligible")
        case .appleIntelligenceOff:
            return NSLocalizedString("iOS 설정에서 Apple Intelligence를 켜주세요", comment: "AI availability: Apple Intelligence off")
        case .modelNotReady:
            return NSLocalizedString("AI 모델을 준비하고 있어요. 잠시 후 다시 시도해 주세요", comment: "AI availability: model not ready")
        }
    }
}

// MARK: - Paste Target (붙여넣을 앱 예측)

/// AI가 예측한 "이 텍스트를 붙여넣을 가능성이 높은 곳" - 단축 액션으로 변환된다.
enum PasteTargetPrediction: String {
    case mail        // 메일 초안 느낌의 텍스트
    case messages    // 짧은 대화체 텍스트
    case calendar    // 날짜/약속이 담긴 텍스트
    case webSearch   // 검색해볼 만한 키워드/질문
    case notes       // 보관할 만한 정보 → 메모로 저장 제안
    case none        // 제안 없음

    var actionLabel: String {
        switch self {
        case .mail:      return NSLocalizedString("메일 쓰기", comment: "Paste target action: compose mail")
        case .messages:  return NSLocalizedString("메시지 보내기", comment: "Paste target action: send message")
        case .calendar:  return NSLocalizedString("캘린더 열기", comment: "Paste target action: open calendar")
        case .webSearch: return NSLocalizedString("웹 검색", comment: "Paste target action: web search")
        case .notes:     return NSLocalizedString("단축어로 저장", comment: "Paste target action: save as memo")
        case .none:      return ""
        }
    }

    var icon: String {
        switch self {
        case .mail:      return "envelope"
        case .messages:  return "message"
        case .calendar:  return "calendar.badge.plus"
        case .webSearch: return "magnifyingglass"
        case .notes:     return "square.and.arrow.down"
        case .none:      return ""
        }
    }
}

// MARK: - Translation Languages (Apple Intelligence 지원 언어)

/// 온디바이스 번역 대상 언어. Apple Intelligence가 지원하는 언어 목록.
enum AITranslationLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case english = "en"
    case japanese = "ja"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case spanish = "es"
    case portuguese = "pt"
    case dutch = "nl"
    case swedish = "sv"
    case danish = "da"
    case norwegian = "no"
    case turkish = "tr"
    case vietnamese = "vi"

    var id: String { rawValue }

    /// 원어 표기 - 언어 선택 UI에서 번역 없이 그대로 노출한다.
    var displayName: String {
        switch self {
        case .korean:             return "한국어"
        case .english:            return "English"
        case .japanese:           return "日本語"
        case .chineseSimplified:  return "中文(简体)"
        case .chineseTraditional: return "中文(繁體)"
        case .french:             return "Français"
        case .german:             return "Deutsch"
        case .italian:            return "Italiano"
        case .spanish:            return "Español"
        case .portuguese:         return "Português"
        case .dutch:              return "Nederlands"
        case .swedish:            return "Svenska"
        case .danish:             return "Dansk"
        case .norwegian:          return "Norsk"
        case .turkish:            return "Türkçe"
        case .vietnamese:         return "Tiếng Việt"
        }
    }

    /// 프롬프트에 넣을 영어 언어명 (모델이 가장 안정적으로 인식)
    var englishName: String {
        switch self {
        case .korean:             return "Korean"
        case .english:            return "English"
        case .japanese:           return "Japanese"
        case .chineseSimplified:  return "Simplified Chinese"
        case .chineseTraditional: return "Traditional Chinese"
        case .french:             return "French"
        case .german:             return "German"
        case .italian:            return "Italian"
        case .spanish:            return "Spanish"
        case .portuguese:         return "Portuguese"
        case .dutch:              return "Dutch"
        case .swedish:            return "Swedish"
        case .danish:             return "Danish"
        case .norwegian:          return "Norwegian"
        case .turkish:            return "Turkish"
        case .vietnamese:         return "Vietnamese"
        }
    }

    /// 시스템 언어와 일치하는 기본 번역 대상 (기본값: 영어)
    static var systemDefault: AITranslationLanguage {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return AITranslationLanguage.allCases.first { $0.rawValue.hasPrefix(code) } ?? .english
    }
}

// MARK: - Generable Schemas (iOS 26+)

#if canImport(FoundationModels)
/// 온디바이스 LLM이 반환하는 클립보드 카테고리 (guided generation)
@available(iOS 26.0, macCatalyst 26.0, *)
@Generable
enum AIClipboardCategory {
    case email
    case phoneNumber
    case personName
    case streetAddress
    case url
    case sourceCode
    case trackingNumber
    case confirmationCode
    case membershipNumber
    case bankAccount
    case dateOrBirthDate
    case plainText
}

@available(iOS 26.0, macCatalyst 26.0, *)
@Generable
struct AIClassificationResult {
    @Guide(description: "The single most fitting category for the given text")
    var category: AIClipboardCategory
}

/// "붙여넣을 앱" 예측 결과 (guided generation)
@available(iOS 26.0, macCatalyst 26.0, *)
@Generable
enum AIPasteTargetCategory {
    case mailDraft          // formal/long text likely pasted into an email
    case chatMessage        // short conversational text for a messenger
    case calendarEvent      // contains a date/time/appointment
    case webSearchQuery     // a keyword or question worth searching
    case noteWorthKeeping   // reference info worth saving as a note
    case noSuggestion
}

@available(iOS 26.0, macCatalyst 26.0, *)
@Generable
struct AIPasteTargetResult {
    @Guide(description: "Where the user is most likely to paste this text next")
    var target: AIPasteTargetCategory
}
#endif

// MARK: - Service

/// Apple Foundation Models 래퍼 싱글톤.
/// iOS 26 미만/미지원 기기에서는 모든 메서드가 조용히 nil을 반환한다 (앱 최소 버전 iOS 17 유지).
final class AppleIntelligenceService {
    static let shared = AppleIntelligenceService()
    private init() {}

    // MARK: - Caches (재분류/재예측 비용 방지)

    private var classifyCache: [Int: (type: ClipboardItemType, confidence: Double)] = [:]
    private var targetCache: [Int: PasteTargetPrediction] = [:]
    private let cacheQueue = DispatchQueue(label: "com.Ysoup.TokenMemo.ai.cache")

    /// AI 분류에 부여하는 고정 신뢰도 - 정규식 강매치(0.9+)보다는 낮고 UI 강조선(0.8)보다는 높게.
    static let aiConfidence: Double = 0.85

    // MARK: - Settings (App Group - 설정 화면과 공유)

    static var classificationEnabled: Bool {
        UserDefaults(suiteName: AppGroup.identifier)?
            .object(forKey: DefaultsKey.aiClassificationEnabled) as? Bool ?? true
    }

    static var actionSuggestionsEnabled: Bool {
        UserDefaults(suiteName: AppGroup.identifier)?
            .object(forKey: DefaultsKey.aiActionSuggestionsEnabled) as? Bool ?? true
    }

    static var translationTargetLanguage: AITranslationLanguage {
        let raw = UserDefaults(suiteName: AppGroup.identifier)?
            .string(forKey: DefaultsKey.aiTranslationTargetLang)
        return raw.flatMap(AITranslationLanguage.init(rawValue:)) ?? .systemDefault
    }

    // MARK: - Availability

    var availability: AIAvailability {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macCatalyst 26.0, *) else { return .osNotSupported }
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceOff
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable:
            return .deviceNotEligible
        }
        #else
        return .osNotSupported
        #endif
    }

    var isAvailable: Bool { availability == .available }

    // MARK: - 1) 클립보드 자동 분류 보강

    /// 정규식 분류 신뢰도가 낮은 텍스트를 온디바이스 LLM으로 재분류한다.
    /// - Returns: (타입, 신뢰도) - 사용 불가/실패/plainText 판정이면 nil
    func classify(_ content: String) async -> (type: ClipboardItemType, confidence: Double)? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macCatalyst 26.0, *), isAvailable else { return nil }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 400 else { return nil }

        let hash = trimmed.hashValue
        if let cached = cacheQueue.sync(execute: { classifyCache[hash] }) {
            return cached
        }

        let session = LanguageModelSession(instructions: """
            You classify short clipboard text into exactly one category. \
            Choose plainText unless the text clearly matches a specific category. \
            The text may be in any language, including Korean.
            """)
        do {
            let response = try await session.respond(
                to: "Classify this clipboard text:\n\(trimmed)",
                generating: AIClassificationResult.self
            )
            guard let mapped = Self.map(response.content.category) else { return nil }
            let result = (mapped, Self.aiConfidence)
            cacheQueue.sync { classifyCache[hash] = result }
            print("🤖 [AppleIntelligenceService.classify] '\(trimmed.prefix(30))' → \(mapped.rawValue)")
            return result
        } catch {
            print("❌ [AppleIntelligenceService.classify] 분류 실패: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macCatalyst 26.0, *)
    private static func map(_ category: AIClipboardCategory) -> ClipboardItemType? {
        switch category {
        case .email:            return .email
        case .phoneNumber:      return .phone
        case .personName:       return .name
        case .streetAddress:    return .address
        case .url:              return .url
        case .sourceCode:       return nil   // 전용 타입 없음 - 텍스트 유지
        case .trackingNumber:   return .trackingNumber
        case .confirmationCode: return .confirmationCode
        case .membershipNumber: return .membershipNumber
        case .bankAccount:      return .bankAccount
        case .dateOrBirthDate:  return .birthDate
        case .plainText:        return nil   // 재분류 무의미 - 기존 결과 유지
        }
    }
    #endif

    // MARK: - 2) 붙여넣을 앱 예측 → 단축 액션

    /// 일반 텍스트가 "어디에 붙여넣을 가능성이 높은지" 예측한다.
    /// URL/전화번호처럼 타입만으로 액션이 자명한 항목에는 호출하지 말 것 (호출부에서 거른다).
    func predictPasteTarget(_ content: String) async -> PasteTargetPrediction? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macCatalyst 26.0, *), isAvailable else { return nil }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8, trimmed.count <= 400 else { return nil }

        let hash = trimmed.hashValue
        if let cached = cacheQueue.sync(execute: { targetCache[hash] }) {
            return cached
        }

        let session = LanguageModelSession(instructions: """
            You predict where a user will most likely paste a piece of clipboard text next. \
            Pick calendarEvent only if the text contains a concrete date, time, or appointment. \
            Pick noSuggestion when nothing fits confidently. \
            The text may be in any language, including Korean.
            """)
        do {
            let response = try await session.respond(
                to: "Where will this clipboard text most likely be pasted?\n\(trimmed)",
                generating: AIPasteTargetResult.self
            )
            let prediction: PasteTargetPrediction
            switch response.content.target {
            case .mailDraft:        prediction = .mail
            case .chatMessage:      prediction = .messages
            case .calendarEvent:    prediction = .calendar
            case .webSearchQuery:   prediction = .webSearch
            case .noteWorthKeeping: prediction = .notes
            case .noSuggestion:     prediction = .none
            }
            cacheQueue.sync { targetCache[hash] = prediction }
            print("🤖 [AppleIntelligenceService.predictPasteTarget] '\(trimmed.prefix(30))' → \(prediction.rawValue)")
            return prediction
        } catch {
            print("❌ [AppleIntelligenceService.predictPasteTarget] 예측 실패: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - 3) 온디바이스 번역

    enum TranslationError: LocalizedError {
        case unavailable
        case failed

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return AppleIntelligenceService.shared.availability.localizedDescription
            case .failed:
                return NSLocalizedString("번역하지 못했어요. 잠시 후 다시 시도해 주세요.", comment: "Translation failed error")
            }
        }
    }

    /// 텍스트를 대상 언어로 번역한다 (온디바이스, 무료).
    func translate(_ text: String, to language: AITranslationLanguage) async throws -> String {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macCatalyst 26.0, *), isAvailable else {
            throw TranslationError.unavailable
        }

        let input = String(text.prefix(2000))
        let session = LanguageModelSession(instructions: """
            You are a professional translator. Translate the user's text into \(language.englishName). \
            Preserve the tone, formatting, and line breaks. \
            Output ONLY the translation with no explanations or quotes.
            """)
        do {
            let response = try await session.respond(to: input)
            let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !result.isEmpty else { throw TranslationError.failed }
            return result
        } catch let error as TranslationError {
            throw error
        } catch {
            print("❌ [AppleIntelligenceService.translate] 번역 실패: \(error)")
            throw TranslationError.failed
        }
        #else
        throw TranslationError.unavailable
        #endif
    }
}
