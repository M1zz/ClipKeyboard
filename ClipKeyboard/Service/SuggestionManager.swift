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

    var allSuggestions: [SuggestionTemplate] {
        usageCategories.flatMap { category in
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
    }

    var emptyStateSuggestions: [SuggestionTemplate] {
        Array(allSuggestions.prefix(8))
    }

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
