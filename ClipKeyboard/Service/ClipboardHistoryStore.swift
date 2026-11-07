//
//  ClipboardHistoryStore.swift
//  ClipKeyboard
//
//  복사 기록 파일(`smart.clipboard.history.data`). 앱이 클립보드에서 담고, 키보드 '최근' 탭이 읽는다.
//  예전 판의 기록 파일(`clipboard.history.data`)은 새 파일이 없을 때 한 번 옮긴다.
//

import Foundation

final class ClipboardHistoryStore {
    static let shared = ClipboardHistoryStore()
    private init() {}

    /// 못 읽은 파일 위에 저장하지 않는다(`UnreadFileGuard`). 열쇠는 파일 이름이다.
    private let unread = UnreadFileGuard<String>()

    static var fileURL: URL? { url(StorageFile.smartClipboardHistory) }
    private static var legacyFileURL: URL? { url(StorageFile.clipboardHistory) }

    private static func url(_ name: String) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent(name)
    }

    // MARK: - 읽기 · 쓰기

    /// 복사 기록을 읽는다. **키보드도 뜰 때마다 부른다**('최근' 탭).
    ///
    /// ⚠️ 파일을 메모리로 복사하지 않고 **매핑**해서 읽는다(`.mappedIfSafe`). 예전 판이 남긴
    ///    그림 글자(base64)가 수 MB 붙어 있어도 키보드의 메모리 한도에 그만큼 잡히지 않는다.
    ///    그림 자체는 디코더가 읽지 않는다(`SmartClipboardHistory.init(from:)`).
    /// ⚠️ 그림 줄(`.image`)은 버린다. 담겨 있던 그림을 보여 주거나 붙여 넣는 화면이 없어서,
    ///    남는 것은 "이미지 (1024x768)" 라는 글자뿐이었다. 넣으면 그 글자가 들어갔다.
    func load() throws -> [SmartClipboardHistory] {
        guard let fileURL = Self.fileURL else { return [] }
        guard let data = try unread.read(fileURL, as: StorageFile.smartClipboardHistory, options: .mappedIfSafe) else {
            return try migrateFromLegacy()
        }
        let history = (try? JSONDecoder().decode([SmartClipboardHistory].self, from: data)) ?? []
        return history.filter { $0.contentType != .image }
    }

    func save(_ history: [SmartClipboardHistory]) throws {
        try unread.refuseIfUnread(StorageFile.smartClipboardHistory)
        guard let fileURL = Self.fileURL else { return }
        try JSONEncoder().encode(history).write(to: fileURL, options: .atomic)
        MemoStore.postDataChanged()
    }

    /// 읽고, 고치고, 쓴다. 못 읽었으면 고치지도 쓰지도 않는다.
    private func modify(_ change: (inout [SmartClipboardHistory]) -> Void) throws {
        var history = try load()
        change(&history)
        try save(history)
    }

    // MARK: - 고치기

    func add(content: String) throws {
        let (detectedType, confidence) = ClipboardClassificationService.shared.classify(content: content)
        let maxHistory = ProFeatureManager.clipboardHistoryLimit()
        try modify { history in
            history.removeAll { $0.content == content }
            history.insert(
                SmartClipboardHistory(content: content, detectedType: detectedType, confidence: confidence),
                at: 0
            )
            if history.count > maxHistory {
                history = Array(history.prefix(maxHistory))
            }
            // 보관 기간은 `SmartClipboardHistory.retentionDays` 한 곳에서 정한다(키보드 '최근' 탭과 같은 값).
            let now = Date()
            history.removeAll { !$0.isRetained(now: now) }
        }
        NotificationCenter.postOnMain(name: .reviewTriggerClipSaved, object: nil)
    }

    /// 한 줄을 지운다. 키보드 '최근' 탭에서 밀어서 지울 때 부른다.
    func delete(id: UUID) throws {
        try modify { $0.removeAll { $0.id == id } }
        print("🗑️ [ClipboardHistoryStore.delete] 복사 기록 1개 삭제")
    }

    /// AI 재분류 결과를 반영한다. 사용자가 수동으로 타입을 고친 항목은 건드리지 않는다.
    /// tags에 "ai"를 남겨 앱 재시작 후 같은 항목을 다시 분류하지 않도록 한다.
    func updateClassification(id: UUID, type: ClipboardItemType, confidence: Double) throws {
        var history = try load()
        guard let index = history.firstIndex(where: { $0.id == id }),
              history[index].userCorrectedType == nil else { return }
        history[index].detectedType = type
        history[index].confidence = confidence
        if !history[index].tags.contains("ai") {
            history[index].tags.append("ai")
        }
        try save(history)
        AppLog.info(.store, "🤖 [ClipboardHistoryStore.updateClassification] AI 재분류 반영: \(type.rawValue)")
    }

    /// 사용자가 고친 종류를 적고, 분류기에도 가르친다.
    func correctType(id: UUID, to correctedType: ClipboardItemType) throws {
        var history = try load()
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        history[index].userCorrectedType = correctedType
        ClipboardClassificationService.shared.updateClassificationModel(
            content: history[index].content,
            correctedType: correctedType
        )
        try save(history)
    }

    // MARK: - 옛 그림 걷기

    /// 예전 판이 복사 기록 파일에 남긴 그림 글자를 걷어 파일을 줄인다. **앱만** 부른다.
    ///
    /// 키보드는 매핑 덕에 큰 파일도 버티지만, 파일이 작아야 키보드가 저장할 때(최근 탭에 담기)도
    /// 가볍다. 그림 글자가 없으면 아무것도 하지 않는다 - 매번 다시 쓰지 않는다.
    /// - Returns: 줄였으면 true.
    @discardableResult
    func compactIfNeeded() -> Bool {
        guard let fileURL = Self.fileURL,
              let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe),
              Self.containsLegacyImages(data) else { return false }
        do {
            let before = data.count
            try save(load())
            let after = (try? Data(contentsOf: fileURL))?.count ?? 0
            print("🔄 [ClipboardHistoryStore.compactIfNeeded] 복사 기록의 옛 그림을 걷음: \(before) → \(after) 바이트")
            return true
        } catch {
            print("❌ [ClipboardHistoryStore.compactIfNeeded] 실패: \(error)")
            return false
        }
    }

    /// 파일에 예전 그림 칸(`"imageData"`) 이 남아 있는가. 해석하지 않고 바이트로만 찾는다.
    static func containsLegacyImages(_ data: Data) -> Bool {
        data.range(of: Data("\"imageData\"".utf8)) != nil
            || data.range(of: Data("\"contentType\":\"image\"".utf8)) != nil
    }

    // MARK: - 예전 기록 옮기기

    /// 예전 판의 기록 파일. 새 파일이 아직 없을 때 `load()` 가 한 번 옮긴다.
    func saveLegacy(_ history: [ClipboardHistory]) throws {
        try unread.refuseIfUnread(StorageFile.clipboardHistory)
        guard let fileURL = Self.legacyFileURL else { return }
        try JSONEncoder().encode(history).write(to: fileURL, options: .atomic)
    }

    private func migrateFromLegacy() throws -> [SmartClipboardHistory] {
        guard let fileURL = Self.legacyFileURL,
              let data = try unread.read(fileURL, as: StorageFile.clipboardHistory) else { return [] }
        let legacy = (try? JSONDecoder().decode([ClipboardHistory].self, from: data)) ?? []
        let smart = legacy.map { item -> SmartClipboardHistory in
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
        if !smart.isEmpty {
            try save(smart)
        }
        return smart
    }
}
