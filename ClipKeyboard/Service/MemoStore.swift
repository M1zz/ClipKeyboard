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
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) else {
            return URL(string: "")
        }

        switch type {
        case .memo:
            return containerURL.appendingPathComponent(StorageFile.memos)
        case .clipboardHistory:
            return containerURL.appendingPathComponent(StorageFile.clipboardHistory)
        case .smartClipboardHistory:
            return containerURL.appendingPathComponent(StorageFile.smartClipboardHistory)
        case .combo:
            return containerURL.appendingPathComponent(StorageFile.combos)
        }
    }

    func save(memos: [Memo], type: MemoType, recordHistory: Bool = true) throws {
        // 타임머신: 메모를 덮어쓰기 직전, 의미 있는 변경이면 "이전 상태"를 스냅샷으로 보관.
        // (대량 삭제·편집·마이그레이션 사고를 되돌릴 수 있는 로컬 안전망. 최근 10개 유지.)
        if type == .memo, recordHistory {
            captureMemoHistoryIfMeaningful(newMemos: memos)
        }
        let data = try JSONEncoder().encode(memos)
        guard let outfile = try Self.fileURL(type: type) else { return }
        try data.write(to: outfile, options: .atomic)
        // 다운그레이드로 유실되지 않도록 카테고리 할당을 사이드카에도 보관.
        if type == .memo {
            Self.writeCategorySidecar(memos)
        }
        NotificationCenter.default.post(name: Notification.Name.memoDataChanged, object: nil)
    }

    func saveClipboardHistory(history: [ClipboardHistory]) throws {
        let data = try JSONEncoder().encode(history)
        guard let outfile = try Self.fileURL(type: .clipboardHistory) else { return }
        try data.write(to: outfile, options: .atomic)
        NotificationCenter.default.post(name: Notification.Name.memoDataChanged, object: nil)
    }

    func load(type: MemoType) throws -> [Memo] {
        guard let fileURL = try Self.fileURL(type: type) else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        var memos = decodeMemosFromData(data)
        if type == .memo {
            if Self.restoreCategoriesFromSidecar(&memos) {
                // 다운그레이드 등으로 memos.data의 category가 유실된 흔적 →
                // 사이드카에서 복원하고 파일도 치유(재저장, 스냅샷 폭주 방지 위해 recordHistory:false).
                try? save(memos: memos, type: .memo, recordHistory: false)
                print("🔄 [MemoStore.load] 유실된 메모 카테고리를 사이드카에서 복원·치유")
            } else if Self.categorySidecarMissing() {
                // 기존 사용자 1회 부트스트랩 — 이후 다운그레이드에 대비해 사이드카를 채워둔다.
                Self.writeCategorySidecar(memos)
            }
        }
        return memos
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

    // MARK: - 카테고리 다운그레이드 안전장치 (사이드카)
    //
    // 각 메모의 `category`는 memos.data JSON 안에 저장된다. 카테고리 필드가 없는 구버전
    // Memo 모델이 이 파일을 로드한 뒤 재저장하면 `category` 키가 통째로 빠져, 다운그레이드 →
    // 재업그레이드 시 모든 메모가 "기본"으로 떨어진다(카테고리 유실). 이미 배포된 구버전의
    // 동작은 바꿀 수 없으므로, 구버전이 절대 읽지/쓰지 않는 App Group UserDefaults 키에
    // [메모ID: 카테고리] 맵을 따로 저장해두고 신버전 로드 시 복원한다.
    // (구버전엔 카테고리 편집 UI가 없으니, 신버전 저장 시점의 사이드카가 항상 정답이다.)
    private static let categorySidecarKey = "memoCategoryAssignments_v1"
    private static let defaultCategoryName = "기본"
    private static var sidecarDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }

    /// 현재 메모들의 '비기본' 카테고리 할당을 사이드카에 통째로 덮어써 항상 최신 상태로 유지.
    static func writeCategorySidecar(_ memos: [Memo]) {
        guard let d = sidecarDefaults else { return }
        var map: [String: String] = [:]
        for m in memos where !m.category.isEmpty && m.category != defaultCategoryName {
            map[m.id.uuidString] = m.category
        }
        d.set(map, forKey: categorySidecarKey)
    }

    static func categorySidecarMissing() -> Bool {
        sidecarDefaults?.dictionary(forKey: categorySidecarKey) == nil
    }

    /// 사이드카의 카테고리를 복원. memos.data 쪽이 기본/빈값(=구버전이 지운 유실 신호)인
    /// 메모만 덮어쓴다. 신버전에서 의도적으로 '기본'으로 옮긴 경우엔 저장 시 사이드카에서도
    /// 제거되므로 잘못 되살아나지 않는다. 변경이 있었으면 true.
    static func restoreCategoriesFromSidecar(_ memos: inout [Memo]) -> Bool {
        guard let d = sidecarDefaults,
              let map = d.dictionary(forKey: categorySidecarKey) as? [String: String],
              !map.isEmpty else { return false }
        var changed = false
        for i in memos.indices {
            guard let saved = map[memos[i].id.uuidString],
                  !saved.isEmpty, saved != defaultCategoryName else { continue }
            let current = memos[i].category
            if current.isEmpty || current == defaultCategoryName {
                memos[i].category = saved
                changed = true
            }
        }
        return changed
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

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        history.removeAll { $0.isTemporary && $0.copiedAt < sevenDaysAgo }

        try saveClipboardHistory(history: history)
    }

    // MARK: - Smart Clipboard History

    func saveSmartClipboardHistory(history: [SmartClipboardHistory]) throws {
        let data = try JSONEncoder().encode(history)
        guard let outfile = try Self.fileURL(type: .smartClipboardHistory) else { return }
        try data.write(to: outfile, options: .atomic)
        NotificationCenter.default.post(name: Notification.Name.memoDataChanged, object: nil)
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

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
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
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
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
        try imageData.write(to: imagesDirectory.appendingPathComponent(fileName), options: .atomic)
    }

    func loadImage(fileName: String) -> UIImage? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) else { return nil }

        let fileURL = containerURL.appendingPathComponent("Images").appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return UIImage(contentsOfFile: fileURL.path)
    }

    func deleteImage(fileName: String) throws {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
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
        guard let data = UserDefaults(suiteName: AppGroup.identifier)?.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([PlaceholderValue].self, from: data)) ?? []
    }

    func savePlaceholderValues(_ values: [PlaceholderValue], for placeholder: String) {
        let key = "placeholder_values_\(placeholder)"
        guard let data = try? JSONEncoder().encode(values) else { return }
        UserDefaults(suiteName: AppGroup.identifier)?.set(data, forKey: key)
        UserDefaults(suiteName: AppGroup.identifier)?.synchronize()
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
        try data.write(to: outfile, options: .atomic)
        DispatchQueue.main.async { [weak self] in self?.combos = combos }
        NotificationCenter.default.post(name: Notification.Name.memoDataChanged, object: nil)
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

    // MARK: - Memo Time Machine (최근 변경 스냅샷)

    /// 메모 전체 상태의 스냅샷(되돌리기용). 최근 N개만 보관.
    static let memoHistoryLimit = 10

    private static func historyFileURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent(StorageFile.memoHistory)
    }

    /// 사용량(clipCount/lastUsedAt/lastEdited)만 다른 저장은 스냅샷하지 않도록 비교용 서명 생성.
    /// 제목·본문·카테고리·타입·자식·이미지·힌트 등 "의미 있는" 필드만 포함.
    private func historySignature(_ memos: [Memo]) -> String {
        memos
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { m in
                [m.id.uuidString, m.title, m.value, m.category,
                 String(m.isTemplate), String(m.isSecure),
                 m.childMemoIds.map { $0.uuidString }.joined(separator: ","),
                 m.imageFileNames.joined(separator: ","),
                 m.hint ?? ""].joined(separator: "\u{1F}")   // unit separator
            }
            .joined(separator: "\n")
    }

    func loadMemoHistory() -> [MemoSnapshot] {
        guard let url = Self.historyFileURL(), let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([MemoSnapshot].self, from: data)) ?? []
    }

    private func saveMemoHistory(_ snapshots: [MemoSnapshot]) {
        guard let url = Self.historyFileURL() else { return }
        if let data = try? JSONEncoder().encode(snapshots) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// 현재 디스크 상태(곧 덮어쓸 이전 메모)를 스냅샷으로 push. 의미 있는 변경일 때만.
    private func captureMemoHistoryIfMeaningful(newMemos: [Memo]) {
        guard let url = try? Self.fileURL(type: .memo),
              let data = try? Data(contentsOf: url) else { return }   // 기존 데이터 없으면 스냅샷 불필요
        let current = decodeMemosFromData(data)
        guard !current.isEmpty else { return }
        guard historySignature(current) != historySignature(newMemos) else { return }  // 사용량만 변경 → skip
        pushMemoSnapshot(current)
    }

    private func pushMemoSnapshot(_ memos: [Memo]) {
        var history = loadMemoHistory()
        let snapshot = MemoSnapshot(id: UUID(), timestamp: Date(), memoCount: memos.count, memos: memos)
        history.insert(snapshot, at: 0)
        if history.count > Self.memoHistoryLimit {
            history = Array(history.prefix(Self.memoHistoryLimit))
        }
        saveMemoHistory(history)
    }

    /// 스냅샷으로 되돌린다. 되돌리기 자체도 취소할 수 있도록 현재 상태를 먼저 스냅샷에 남긴다.
    @discardableResult
    func restoreMemoSnapshot(_ id: UUID) -> Bool {
        let history = loadMemoHistory()
        guard let snapshot = history.first(where: { $0.id == id }) else { return false }
        // 현재 상태 보존(되돌리기의 되돌리기 가능)
        if let url = try? Self.fileURL(type: .memo), let data = try? Data(contentsOf: url) {
            let current = decodeMemosFromData(data)
            if !current.isEmpty { pushMemoSnapshot(current) }
        }
        do {
            try save(memos: snapshot.memos, type: .memo, recordHistory: false)
            print("↩️ [MemoStore] 스냅샷 복원: \(snapshot.memoCount)개 (\(snapshot.timestamp))")
            return true
        } catch {
            print("❌ [MemoStore] 스냅샷 복원 실패: \(error)")
            return false
        }
    }
}

/// 메모 전체 상태 스냅샷(타임머신 1개 지점).
struct MemoSnapshot: Codable, Identifiable {
    var id: UUID
    var timestamp: Date
    var memoCount: Int
    var memos: [Memo]
}

// MARK: - KeyboardUsageTracker

/// 키보드/메모 사용 통계 — App Group UserDefaults 기반.
/// - 일일 카운트: `kb.usage.daily.YYYY-MM-DD` (사용자 로컬 자정 기준 자연 초기화)
/// - 평생 절약 시간: `kb.timeSaved.totalSeconds` (Double 누적)
///
/// 메모 사용 시점에 `recordMemoUse(value:)` 호출. 키보드 익스텐션과 메인 앱 모두
/// `MemoStore.incrementClipCount`를 거치므로 양쪽에서 일관되게 집계된다.
enum KeyboardUsageTracker {
    private static let timeSavedKey = "kb.timeSaved.totalSeconds"
    private static let dailyKeyPrefix = "kb.usage.daily."

    /// 평균 입력 속도 가정 (한글/영문 혼용 보수적 추정).
    private static let charsPerSecond: Double = 4.0
    /// 메모 탭+선택에 드는 오버헤드 (초). 실제 절약 시간에서 차감.
    private static let memoTapOverheadSeconds: Double = 1.0

    /// 메모 사용을 1건 기록한다. 일일 카운트 +1, 평생 절약 시간 += (글자수/4 - 1, 음수 clamp).
    static func recordMemoUse(value: String) {
        guard let defaults = UserDefaults(suiteName: AppGroup.identifier) else { return }
        let key = dailyKey(for: Date())
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)

        let saved = max(0, Double(value.count) / charsPerSecond - memoTapOverheadSeconds)
        defaults.set(defaults.double(forKey: timeSavedKey) + saved, forKey: timeSavedKey)
    }

    /// 특정 날짜의 사용 횟수 (기본: 오늘)
    static func dailyUsageCount(for date: Date = Date()) -> Int {
        UserDefaults(suiteName: AppGroup.identifier)?.integer(forKey: dailyKey(for: date)) ?? 0
    }

    /// 평생 누적 절약 시간 (초)
    static func totalTimeSavedSeconds() -> Double {
        UserDefaults(suiteName: AppGroup.identifier)?.double(forKey: timeSavedKey) ?? 0
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
