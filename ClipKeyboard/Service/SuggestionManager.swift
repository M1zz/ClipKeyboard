//
//  SuggestionManager.swift
//  ClipKeyboard
//

import SwiftUI

// MARK: - SuggestionTemplate

struct SuggestionTemplate: Identifiable {
    let stableID: Int
    let emoji: String
    let title: String
    let content: String
    let feature: ScenarioFeature
    let categoryTitle: String

    var id: Int { stableID }
}

// MARK: - SuggestionManager

final class SuggestionManager: ObservableObject {
    static let shared = SuggestionManager()
    private init() {}

    @Published private(set) var occasionalSuggestion: SuggestionTemplate? = nil

    private var defaults: UserDefaults? { AppConfig.sharedDefaults }

    private enum Keys {
        static let dismissedIDs  = "suggestion_dismissed_ids"
        static let lastShownDate = "suggestion_last_shown_date"
        static let appOpenCount  = "suggestion_app_open_count"
    }

    // MARK: - Locale-aware suggestion list

    /// 기존 UsageGuideView의 시나리오 풀 + v4.0.8 페르소나별 친화 seed.
    /// empty state에서 random 3개로 노출되어 사용자가 진입할 때마다 다양한 영감을 얻음.
    var allSuggestions: [SuggestionTemplate] {
        let fromUsageGuide = usageCategories.flatMap { category in
            category.scenarios.map { scenario in
                SuggestionTemplate(
                    stableID: abs(scenario.exampleKey.hashValue),
                    emoji: category.emoji,
                    title: scenario.title,
                    content: scenario.example,
                    feature: scenario.feature,
                    categoryTitle: category.title
                )
            }
        }
        let fromPersonaSeeds = Self.personaSeedSuggestions.map { seed in
            SuggestionTemplate(
                stableID: seed.stableID,
                emoji: seed.emoji,
                title: NSLocalizedString(seed.titleKey, comment: "Empty state seed title"),
                content: seed.content,
                feature: seed.feature,
                categoryTitle: NSLocalizedString(seed.categoryKey, comment: "Empty state seed category")
            )
        }
        return fromUsageGuide + fromPersonaSeeds
    }

    /// empty state에 노출할 random 3개. 매 호출마다 새 shuffle.
    /// 페르소나가 선택되어 있으면 그 페르소나 + general seed에 가중치를 둠.
    var emptyStateSuggestions: [SuggestionTemplate] {
        let pool = personaWeightedPool()
        return Array(pool.shuffled().prefix(3))
    }

    /// 페르소나 가중치 풀: 선택된 페르소나(+general) seed를 두 번 넣어 노출 빈도 ↑.
    /// usageCategories 시나리오는 가중치 없이 1회만 포함.
    private func personaWeightedPool() -> [SuggestionTemplate] {
        let everything = allSuggestions
        guard let selected = CategoryStore.shared.selectedPersona else {
            return everything
        }
        let preferred = Self.personaSeedSuggestions.filter { seed in
            seed.persona == selected || seed.persona == .general
        }
        let preferredAsTemplates = preferred.map { seed in
            SuggestionTemplate(
                stableID: seed.stableID,
                emoji: seed.emoji,
                title: NSLocalizedString(seed.titleKey, comment: "Empty state seed title"),
                content: seed.content,
                feature: seed.feature,
                categoryTitle: NSLocalizedString(seed.categoryKey, comment: "Empty state seed category")
            )
        }
        // preferred를 2번 넣어 random pick에서 더 자주 뽑힘
        return everything + preferredAsTemplates
    }

    // MARK: - Persona seed pool (v4.0.8)

    /// 페르소나별 친화 seed. 본문은 영어/한국어 mix — 페르소나 맥락에 맞춰 자연스럽게.
    private struct PersonaSeed {
        let stableID: Int
        let emoji: String
        let titleKey: String
        let content: String
        let feature: ScenarioFeature
        let persona: Persona
        let categoryKey: String
    }

    private static let personaSeedSuggestions: [PersonaSeed] = [
        // Digital Nomad / Freelancer (6)
        PersonaSeed(stableID: 90001, emoji: "💸",
                    titleKey: "Currency preference reply",
                    content: "I invoice in USD or EUR (your choice). Wise gets it to me fastest — happy to share my details if you go with Wise.",
                    feature: .template, persona: .nomad, categoryKey: "Nomad essentials"),
        PersonaSeed(stableID: 90002, emoji: "🛂",
                    titleKey: "Visa run notice",
                    content: "Quick heads-up: doing a visa run on {date}, replies might be slow for ~24h. Everything still on track on my end.",
                    feature: .template, persona: .nomad, categoryKey: "Nomad essentials"),
        PersonaSeed(stableID: 90003, emoji: "🏠",
                    titleKey: "Apartment info bundle",
                    content: "Apartment: [Your Address]\nWiFi: [SSID] / [Password]\nCheckout: 11AM local",
                    feature: .memo, persona: .nomad, categoryKey: "Nomad essentials"),
        PersonaSeed(stableID: 90004, emoji: "🌐",
                    titleKey: "Async-first availability",
                    content: "I work async-first — feel free to leave loom/voice notes. I'll batch-reply during my morning ({timezone}).",
                    feature: .template, persona: .nomad, categoryKey: "Timezone & availability"),
        PersonaSeed(stableID: 90005, emoji: "💼",
                    titleKey: "Cross-border invoicing notice",
                    content: "FYI my invoice will be issued from my {country} entity. Let me know if you need a specific format for accounting.",
                    feature: .template, persona: .nomad, categoryKey: "Banking & Payments"),
        PersonaSeed(stableID: 90006, emoji: "✈️",
                    titleKey: "Travel days notice",
                    content: "I'm in transit {date_from}–{date_to} ({route}). I'll be online from {hotel} starting {arrival_time}.",
                    feature: .template, persona: .nomad, categoryKey: "Nomad essentials"),

        // Business / Office Worker (5)
        PersonaSeed(stableID: 90011, emoji: "📅",
                    titleKey: "Meeting delay reply",
                    content: "회의가 10분 늦어질 것 같습니다. 양해 부탁드립니다.",
                    feature: .memo, persona: .business, categoryKey: "Business / Office"),
        PersonaSeed(stableID: 90012, emoji: "👌",
                    titleKey: "Reviewing reply",
                    content: "확인했습니다. 검토 후 답변드리겠습니다.",
                    feature: .memo, persona: .business, categoryKey: "Business / Office"),
        PersonaSeed(stableID: 90013, emoji: "💼",
                    titleKey: "Email signature template",
                    content: "{name}\n{role} | {company}\n{email} · {phone}\n{office_address}",
                    feature: .template, persona: .business, categoryKey: "Business / Office"),
        PersonaSeed(stableID: 90014, emoji: "📝",
                    titleKey: "Meeting minutes template",
                    content: "회의록 - {날짜}\n참석: {참석자}\n\n안건:\n1.\n2.\n\n결정사항:\n\n액션 아이템:",
                    feature: .template, persona: .business, categoryKey: "Business / Office"),
        PersonaSeed(stableID: 90015, emoji: "🏖️",
                    titleKey: "Out of office reply",
                    content: "Hi, I'll be out until {return_date}. For urgent items, please contact {colleague}. I'll reply on return.",
                    feature: .template, persona: .business, categoryKey: "Business / Office"),

        // Student (5)
        PersonaSeed(stableID: 90021, emoji: "🎓",
                    titleKey: "Office hours request",
                    content: "안녕하세요 교수님, {날짜} 면담 가능할까요? {주제} 관련 질문이 있어 찾아뵙고 싶습니다.",
                    feature: .template, persona: .student, categoryKey: "Student"),
        PersonaSeed(stableID: 90022, emoji: "👥",
                    titleKey: "Group project kickoff",
                    content: "Hi team, I'm {이름} ({학번}). Let's set up a kickoff — when works for everyone this week?",
                    feature: .template, persona: .student, categoryKey: "Student"),
        PersonaSeed(stableID: 90023, emoji: "📎",
                    titleKey: "Assignment submission",
                    content: "안녕하세요, {수업명} 과제 제출합니다.\n학번: {학번}\n이름: {이름}\n첨부 파일 확인 부탁드립니다.",
                    feature: .template, persona: .student, categoryKey: "Student"),
        PersonaSeed(stableID: 90024, emoji: "🏛️",
                    titleKey: "Library book request",
                    content: "도서관 책 요청\n도서명: \nISBN: \n요청일: {날짜}",
                    feature: .memo, persona: .student, categoryKey: "Student"),
        PersonaSeed(stableID: 90025, emoji: "💼",
                    titleKey: "Internship inquiry",
                    content: "{회사명} 인사 담당자님께,\n안녕하세요, {학교/전공}의 {이름}입니다. {역할} 인턴십에 관심이 있어 문의드립니다.",
                    feature: .template, persona: .student, categoryKey: "Student"),

        // General / Personal (4)
        PersonaSeed(stableID: 90031, emoji: "🏠",
                    titleKey: "Home address quick share",
                    content: "내 주소: [실제 주소 입력]",
                    feature: .memo, persona: .general, categoryKey: "Daily life"),
        PersonaSeed(stableID: 90032, emoji: "🚨",
                    titleKey: "Emergency contact",
                    content: "응급 연락처\n{이름}: {전화번호}\n관계: {가족 관계}",
                    feature: .template, persona: .general, categoryKey: "Daily life"),
        PersonaSeed(stableID: 90033, emoji: "📦",
                    titleKey: "Delivery instructions",
                    content: "택배 메모\n부재 시 경비실에 맡겨주세요.\n공동현관 비밀번호: [번호]",
                    feature: .memo, persona: .general, categoryKey: "Daily life"),
        PersonaSeed(stableID: 90034, emoji: "🍽️",
                    titleKey: "Restaurant recommendation",
                    content: "거기 맛있어요! 특히 {메뉴} 추천합니다. {주소}에 있어요.",
                    feature: .template, persona: .general, categoryKey: "Daily life"),
    ]

    // MARK: - Persistence helpers

    private var dismissedIDs: Set<Int> {
        get {
            let arr = defaults?.array(forKey: Keys.dismissedIDs) as? [Int] ?? []
            return Set(arr)
        }
        set { defaults?.set(Array(newValue), forKey: Keys.dismissedIDs) }
    }

    private var lastShownDate: Date? {
        get { defaults?.object(forKey: Keys.lastShownDate) as? Date }
        set { defaults?.set(newValue, forKey: Keys.lastShownDate) }
    }

    private var appOpenCount: Int {
        defaults?.integer(forKey: Keys.appOpenCount) ?? 0
    }

    // MARK: - App open tracking

    func recordAppOpen() {
        let count = appOpenCount + 1
        defaults?.set(count, forKey: Keys.appOpenCount)
        evaluateOccasionalSuggestion(openCount: count)
    }

    private func evaluateOccasionalSuggestion(openCount: Int) {
        guard openCount >= 3 else { return }
        if let last = lastShownDate {
            let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            guard days >= 3 else { return }
        }
        guard Double.random(in: 0...1) < 0.3 else { return }
        let dismissed = dismissedIDs
        occasionalSuggestion = allSuggestions.first { !dismissed.contains($0.stableID) }
    }

    // MARK: - User actions

    func dismissOccasionalSuggestion() {
        guard let s = occasionalSuggestion else { return }
        var dismissed = dismissedIDs
        dismissed.insert(s.stableID)
        dismissedIDs = dismissed
        lastShownDate = Date()
        occasionalSuggestion = nil
    }

    func acceptOccasionalSuggestion() {
        lastShownDate = Date()
        occasionalSuggestion = nil
    }
}
