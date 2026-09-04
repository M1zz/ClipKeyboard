//
//  AppleIntelligenceService.swift
//  ClipKeyboard
//
//  Apple Foundation Models(온디바이스 AI) 래퍼 - iOS 26+ Apple Intelligence 기기 전용.
//  1) 클립보드 자동 분류 보강: 정규식 신뢰도가 낮은 항목을 온디바이스 LLM으로 재분류
//  2) 붙여넣을 앱 예측: "이 텍스트는 어디에 붙여넣을 가능성이 높은가" → 단축 액션 제안
//
//  번역은 여기 없다. `AppTranslation`(이 파일 아래)이 `Translation` 프레임워크로 한다.
//  Apple Intelligence 는 러시아어를 못 하고, 애초에 켤 수 없는 기기가 많다. 그 머리말 참고.
//
//  ⚠️ 모든 처리는 온디바이스 - 텍스트가 기기를 떠나지 않는다.
//  ⚠️ 메인 앱 타겟 전용. 키보드 익스텐션은 메모리 제한 때문에 사용하지 않는다.
//

import Foundation
#if canImport(Translation)
import Translation
#endif
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

// MARK: - 번역 (Translation.framework)

/// 번역이 되는 언어와, 지금 고른 대상 언어.
///
/// ⚠️ **Foundation Models 로 번역하지 않는다.** 이유가 둘이다.
///
///   하나. Apple Intelligence 가 아는 언어는 열몇 개뿐이고 거기에 러시아어는 없다.
///   앱은 러시아어로 도는데 번역만 못 하면, 그 사용자에게는 앱이 반쯤만 자기 말을 하는 셈이다.
///
///   둘. `Translation` 은 **Apple Intelligence 를 못 켜는 기기에서도 돈다.**
///   예전에는 최신 기기를 가진 사람만 번역을 볼 수 있었다. 이제 다 볼 수 있다.
///
/// ⚠️ 지원 언어 목록을 손으로 들고 있지 않다. 기기에 묻는다(`LanguageAvailability`).
///    적어 두면 iOS 가 언어를 더한 날 우리만 모르고, 기기가 못 하는 언어를 목록에 세우게 된다.
///    (`TokenFormat.automaticPattern` 이 나라 목록을 시스템에 묻는 것과 같은 이유다)
enum AppTranslation {

    /// 이 기기가 번역할 수 있는 언어. 그 언어의 이름 순으로 준다.
    static func supportedLanguages() async -> [Locale.Language] {
        #if canImport(Translation)
        let languages = await LanguageAvailability().supportedLanguages
        // 같은 언어가 지역만 달리 여러 번 오는 경우가 있다(en, en-GB...). 언어로 한 번만 센다.
        var seen = Set<String>()
        let unique = languages.filter { seen.insert(key(for: $0)).inserted }
        return unique.sorted {
            displayName(of: $0).localizedStandardCompare(displayName(of: $1)) == .orderedAscending
        }
        #else
        return []
        #endif
    }

    /// 사람이 고른 대상 언어. 고른 적이 없으면 **앱에서 고른 언어**.
    ///
    /// 왜 앱 언어인가: 번역은 남의 말을 내 말로 옮기려고 쓴다. 기기 지역이 아니라
    /// 사람이 읽겠다고 고른 말이 목적지다.
    static var targetLanguage: Locale.Language {
        get {
            if let raw = AppGroup.defaults?.string(forKey: DefaultsKey.aiTranslationTargetLang),
               !raw.isEmpty {
                return Locale.Language(identifier: raw)
            }
            return defaultTarget
        }
        set {
            AppGroup.defaults?.set(key(for: newValue), forKey: DefaultsKey.aiTranslationTargetLang)
        }
    }

    /// 앱에서 고른 언어. 고른 적이 없으면 기기 언어.
    static var defaultTarget: Locale.Language {
        if let code = AppLanguage.current.bundleCode {
            return Locale.Language(identifier: code)
        }
        return Locale.current.language
    }

    /// 저장·비교에 쓰는 이름 (`ko` · `zh-Hans`).
    static func key(for language: Locale.Language) -> String {
        language.minimalIdentifier
    }

    /// 목록에 적을 이름. **그 언어로** 적는다.
    /// 영어만 읽는 사람에게 "한국어"를 "Korean"으로 보여주면 정작 그 말을 찾는 사람이 못 알아본다.
    static func displayName(of language: Locale.Language) -> String {
        let id = key(for: language)
        let locale = Locale(identifier: id)
        if let name = locale.localizedString(forIdentifier: id), !name.isEmpty { return name }
        if let code = language.languageCode?.identifier,
           let name = locale.localizedString(forLanguageCode: code), !name.isEmpty { return name }
        return id
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
        AppGroup.defaults?
            .object(forKey: DefaultsKey.aiClassificationEnabled) as? Bool ?? true
    }

    static var actionSuggestionsEnabled: Bool {
        AppGroup.defaults?
            .object(forKey: DefaultsKey.aiActionSuggestionsEnabled) as? Bool ?? true
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

}
