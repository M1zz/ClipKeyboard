//
//  MemoStore.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/05/16.
//

import Foundation
#if os(iOS)
import UIKit
import Vision
import VisionKit
#endif

enum MemoType {
    case memo
    case clipboardHistory
    case smartClipboardHistory
    case combo
}

class MemoStore: ObservableObject {
    static let shared = MemoStore()

    @Published var memos: [Memo] = []
    @Published var clipboardHistory: [ClipboardHistory] = []
    @Published var smartClipboardHistory: [SmartClipboardHistory] = []
    @Published var combos: [Combo] = []

    private static func fileURL(type: MemoType) throws -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo"
        ) else {
            return URL(string: "")
        }

        switch type {
        case .memo:
            return containerURL.appendingPathComponent("memos.data")
        case .clipboardHistory:
            return containerURL.appendingPathComponent("clipboard.history.data")
        case .smartClipboardHistory:
            return containerURL.appendingPathComponent("smart.clipboard.history.data")
        case .combo:
            return containerURL.appendingPathComponent("combos.data")
        }
    }

    func save(memos: [Memo], type: MemoType) throws {
        let data = try JSONEncoder().encode(memos)
        guard let outfile = try Self.fileURL(type: type) else { return }
        try data.write(to: outfile)
        NotificationCenter.default.post(name: NSNotification.Name("MemoDataChanged"), object: nil)
    }

    func saveClipboardHistory(history: [ClipboardHistory]) throws {
        let data = try JSONEncoder().encode(history)
        guard let outfile = try Self.fileURL(type: .clipboardHistory) else { return }
        try data.write(to: outfile)
        NotificationCenter.default.post(name: NSNotification.Name("MemoDataChanged"), object: nil)
    }

    func load(type: MemoType) throws -> [Memo] {
        guard let fileURL = try Self.fileURL(type: type) else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        let memos = decodeMemosFromData(data)
        let (migratedMemos, wasMigrated) = migrateLegacyCategoriesToThemes(memos)
        if wasMigrated {
            try? save(memos: migratedMemos, type: type)
        }
        return migratedMemos
    }

    private func decodeMemosFromData(_ data: Data) -> [Memo] {
        if let memos = try? JSONDecoder().decode([Memo].self, from: data) {
            return memos
        }
        if let oldMemos = try? JSONDecoder().decode([OldMemo].self, from: data) {
            return oldMemos.map { Memo(from: $0) }
        }
        return []
    }

    func loadClipboardHistory() throws -> [ClipboardHistory] {
        guard let fileURL = try Self.fileURL(type: .clipboardHistory) else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([ClipboardHistory].self, from: data)) ?? []
    }

    // MARK: - Clip Count

    func incrementClipCount(for memoId: UUID) throws {
        var memos = try load(type: .memo)
        if let index = memos.firstIndex(where: { $0.id == memoId }) {
            memos[index].clipCount += 1
            memos[index].lastUsedAt = Date()
            try save(memos: memos, type: .memo)
            // 일일 카운트 + 평생 절약 시간 갱신 (메모 길이 기반)
            KeyboardUsageTracker.recordMemoUse(value: memos[index].value)
        }
    }

    // MARK: - Legacy Clipboard History

    func addToClipboardHistory(content: String) throws {
        var history = try loadClipboardHistory()

        history.removeAll { $0.content == content }
        history.insert(ClipboardHistory(content: content), at: 0)

        if history.count > 100 {
            history = Array(history.prefix(100))
        }

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        history.removeAll { $0.isTemporary && $0.copiedAt < sevenDaysAgo }

        try saveClipboardHistory(history: history)
    }

    // MARK: - Smart Clipboard History

    func saveSmartClipboardHistory(history: [SmartClipboardHistory]) throws {
        let data = try JSONEncoder().encode(history)
        guard let outfile = try Self.fileURL(type: .smartClipboardHistory) else { return }
        try data.write(to: outfile)
        NotificationCenter.default.post(name: NSNotification.Name("MemoDataChanged"), object: nil)
    }

    func loadSmartClipboardHistory() throws -> [SmartClipboardHistory] {
        guard let fileURL = try Self.fileURL(type: .smartClipboardHistory) else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else {
            return try migrateFromLegacyClipboard()
        }
        return (try? JSONDecoder().decode([SmartClipboardHistory].self, from: data)) ?? []
    }

    func addToSmartClipboardHistory(content: String) throws {
        var history = try loadSmartClipboardHistory()

        let (detectedType, confidence) = ClipboardClassificationService.shared.classify(content: content)

        history.removeAll { $0.content == content }
        history.insert(
            SmartClipboardHistory(content: content, detectedType: detectedType, confidence: confidence),
            at: 0
        )

        let maxHistory = ProFeatureManager.clipboardHistoryLimit()
        if history.count > maxHistory {
            history = Array(history.prefix(maxHistory))
        }

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        history.removeAll { $0.isTemporary && $0.copiedAt < sevenDaysAgo }

        try saveSmartClipboardHistory(history: history)

        NotificationCenter.default.post(name: .reviewTriggerClipSaved, object: nil)

        DispatchQueue.main.async { [weak self] in
            self?.smartClipboardHistory = history
        }
    }

    func updateClipboardItemType(id: UUID, correctedType: ClipboardItemType) throws {
        var history = try loadSmartClipboardHistory()

        if let index = history.firstIndex(where: { $0.id == id }) {
            history[index].userCorrectedType = correctedType
            ClipboardClassificationService.shared.updateClassificationModel(
                content: history[index].content,
                correctedType: correctedType
            )
            try saveSmartClipboardHistory(history: history)
            DispatchQueue.main.async { [weak self] in
                self?.smartClipboardHistory = history
            }
        }
    }

    // MARK: - Migration

    private func migrateFromLegacyClipboard() throws -> [SmartClipboardHistory] {
        let legacyHistory = try loadClipboardHistory()

        let smartHistory = legacyHistory.map { item -> SmartClipboardHistory in
            let (type, confidence) = ClipboardClassificationService.shared.classify(content: item.content)
            return SmartClipboardHistory(
                id: item.id,
                content: item.content,
                copiedAt: item.copiedAt,
                isTemporary: item.isTemporary,
                detectedType: type,
                confidence: confidence
            )
        }

        if !smartHistory.isEmpty {
            try saveSmartClipboardHistory(history: smartHistory)
        }

        return smartHistory
    }

    private func migrateLegacyCategoriesToThemes(_ memos: [Memo]) -> (memos: [Memo], migrated: Bool) {
        let oldCategories = ["개인정보", "금융", "여행", "업무", "기본"]
        guard memos.contains(where: { oldCategories.contains($0.category) }) else {
            return (memos, false)
        }

        let migratedMemos = memos.map { memo -> Memo in
            guard oldCategories.contains(memo.category) else { return memo }
            var updated = memo
            updated.category = memo.autoDetectedType?.rawValue ?? "텍스트"
            return updated
        }

        return (migratedMemos, true)
    }

    private func removeDuplicate(_ array: [Memo]) -> [Memo] {
        var seen = Set<String>()
        return array.filter { seen.insert($0.title).inserted }
    }

    // MARK: - Favorite

    func hasFavoriteMemo() -> Bool {
        guard let memos = try? load(type: .memo) else { return false }
        return memos.contains(where: { $0.isFavorite })
    }

    // MARK: - Image Management

    #if os(iOS)
    func saveImage(_ image: UIImage, fileName: String) throws {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo"
        ) else {
            throw NSError(domain: "MemoStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Group 컨테이너를 찾을 수 없음"])
        }

        let imagesDirectory = containerURL.appendingPathComponent("Images")
        if !FileManager.default.fileExists(atPath: imagesDirectory.path) {
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        }

        guard let imageData = image.pngData() else {
            throw NSError(domain: "MemoStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "이미지를 PNG로 변환할 수 없음"])
        }
        try imageData.write(to: imagesDirectory.appendingPathComponent(fileName))
    }

    func loadImage(fileName: String) -> UIImage? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo"
        ) else { return nil }

        let fileURL = containerURL.appendingPathComponent("Images").appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return UIImage(contentsOfFile: fileURL.path)
    }

    func deleteImage(fileName: String) throws {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo"
        ) else {
            throw NSError(domain: "MemoStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Group 컨테이너를 찾을 수 없음"])
        }

        let fileURL = containerURL.appendingPathComponent("Images").appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
    #endif

    // MARK: - Placeholder Values

    func loadPlaceholderValues(for placeholder: String) -> [PlaceholderValue] {
        let key = "placeholder_values_\(placeholder)"
        guard let data = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([PlaceholderValue].self, from: data)) ?? []
    }

    func savePlaceholderValues(_ values: [PlaceholderValue], for placeholder: String) {
        let key = "placeholder_values_\(placeholder)"
        guard let data = try? JSONEncoder().encode(values) else { return }
        UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.set(data, forKey: key)
        UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.synchronize()
    }

    func addPlaceholderValue(_ value: String, for placeholder: String, sourceMemoId: UUID, sourceMemoTitle: String) {
        var values = loadPlaceholderValues(for: placeholder)
        values.removeAll { $0.value == value }
        values.insert(PlaceholderValue(value: value, sourceMemoId: sourceMemoId, sourceMemoTitle: sourceMemoTitle), at: 0)
        savePlaceholderValues(values, for: placeholder)
    }

    func deletePlaceholderValue(valueId: UUID, for placeholder: String) {
        var values = loadPlaceholderValues(for: placeholder)
        values.removeAll { $0.id == valueId }
        savePlaceholderValues(values, for: placeholder)
    }

    func deletePlaceholderValues(fromMemoId memoId: UUID) {
        let allMemos = (try? load(type: .memo)) ?? []
        var allPlaceholders: Set<String> = []

        for memo in allMemos where memo.isTemplate {
            allPlaceholders.formUnion(extractPlaceholders(from: memo.value))
        }

        for placeholder in allPlaceholders {
            var values = loadPlaceholderValues(for: placeholder)
            values.removeAll { $0.sourceMemoId == memoId }
            savePlaceholderValues(values, for: placeholder)
        }
    }

    private func extractPlaceholders(from text: String) -> [String] {
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var placeholders: [String] = []
        for match in matches {
            if let range = Range(match.range, in: text) {
                let token = String(text[range])
                if !TemplateVariableProcessor.autoVariableTokens.contains(token), !placeholders.contains(token) {
                    placeholders.append(token)
                }
            }
        }
        return placeholders
    }

    // MARK: - Combo

    func saveCombos(_ combos: [Combo]) throws {
        let data = try JSONEncoder().encode(combos)
        guard let outfile = try Self.fileURL(type: .combo) else { return }
        try data.write(to: outfile)
        DispatchQueue.main.async { [weak self] in self?.combos = combos }
        NotificationCenter.default.post(name: NSNotification.Name("MemoDataChanged"), object: nil)
    }

    func loadCombos() throws -> [Combo] {
        guard let fileURL = try Self.fileURL(type: .combo) else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        guard let combos = try? JSONDecoder().decode([Combo].self, from: data) else { return [] }
        DispatchQueue.main.async { [weak self] in self?.combos = combos }
        return combos
    }

    func addCombo(_ combo: Combo) throws {
        var combos = try loadCombos()
        combos.insert(combo, at: 0)
        try saveCombos(combos)
    }

    func updateCombo(_ combo: Combo) throws {
        var combos = try loadCombos()
        if let index = combos.firstIndex(where: { $0.id == combo.id }) {
            combos[index] = combo
            try saveCombos(combos)
        }
    }

    func deleteCombo(id: UUID) throws {
        var combos = try loadCombos()
        combos.removeAll { $0.id == id }
        try saveCombos(combos)
    }

    func incrementComboUseCount(id: UUID) throws {
        var combos = try loadCombos()
        if let index = combos.firstIndex(where: { $0.id == id }) {
            combos[index].useCount += 1
            combos[index].lastUsed = Date()
            try saveCombos(combos)
        }
    }

    func getComboItemValue(_ item: ComboItem) throws -> String? {
        switch item.type {
        case .memo:
            return try load(type: .memo).first(where: { $0.id == item.referenceId })?.value
        case .clipboardHistory:
            return try loadSmartClipboardHistory().first(where: { $0.id == item.referenceId })?.content
        case .template:
            if let displayValue = item.displayValue, !displayValue.isEmpty { return displayValue }
            return try load(type: .memo).first(where: { $0.id == item.referenceId })?.value
        }
    }

    func validateComboItem(_ item: ComboItem) throws -> Bool {
        switch item.type {
        case .memo:
            return try load(type: .memo).contains(where: { $0.id == item.referenceId && !$0.isTemplate })
        case .clipboardHistory:
            return try loadSmartClipboardHistory().contains(where: { $0.id == item.referenceId })
        case .template:
            return try load(type: .memo).contains(where: { $0.id == item.referenceId && $0.isTemplate })
        }
    }

    func cleanupCombo(_ combo: Combo) throws -> Combo {
        var validItems: [ComboItem] = []
        for item in combo.items {
            if try validateComboItem(item) {
                validItems.append(item)
            }
        }

        var cleaned = combo
        cleaned.items = validItems.enumerated().map { index, item in
            var updated = item
            updated.order = index
            return updated
        }
        return cleaned
    }
}

// MARK: - KeyboardUsageTracker

/// 키보드/메모 사용 통계 — App Group UserDefaults 기반.
/// - 일일 카운트: `kb.usage.daily.YYYY-MM-DD` (사용자 로컬 자정 기준 자연 초기화)
/// - 평생 절약 시간: `kb.timeSaved.totalSeconds` (Double 누적)
///
/// 메모 사용 시점에 `recordMemoUse(value:)` 호출. 키보드 익스텐션과 메인 앱 모두
/// `MemoStore.incrementClipCount`를 거치므로 양쪽에서 일관되게 집계된다.
enum KeyboardUsageTracker {
    private static let appGroup = "group.com.Ysoup.TokenMemo"
    private static let timeSavedKey = "kb.timeSaved.totalSeconds"
    private static let dailyKeyPrefix = "kb.usage.daily."

    /// 평균 입력 속도 가정 (한글/영문 혼용 보수적 추정).
    private static let charsPerSecond: Double = 4.0
    /// 메모 탭+선택에 드는 오버헤드 (초). 실제 절약 시간에서 차감.
    private static let memoTapOverheadSeconds: Double = 1.0

    /// 메모 사용을 1건 기록한다. 일일 카운트 +1, 평생 절약 시간 += (글자수/4 - 1, 음수 clamp).
    static func recordMemoUse(value: String) {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        let key = dailyKey(for: Date())
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)

        let saved = max(0, Double(value.count) / charsPerSecond - memoTapOverheadSeconds)
        defaults.set(defaults.double(forKey: timeSavedKey) + saved, forKey: timeSavedKey)
    }

    /// 특정 날짜의 사용 횟수 (기본: 오늘)
    static func dailyUsageCount(for date: Date = Date()) -> Int {
        UserDefaults(suiteName: appGroup)?.integer(forKey: dailyKey(for: date)) ?? 0
    }

    /// 평생 누적 절약 시간 (초)
    static func totalTimeSavedSeconds() -> Double {
        UserDefaults(suiteName: appGroup)?.double(forKey: timeSavedKey) ?? 0
    }

    private static func dailyKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return dailyKeyPrefix + formatter.string(from: date)
    }
}
