//
//  ClipboardRepository.swift
//  Token memo
//

import Foundation

final class ClipboardRepository: ClipboardRepositoryProtocol {
    private let storage: AppGroupStorage

    init(storage: AppGroupStorage = .shared) {
        self.storage = storage
    }

    func fetchHistory() throws -> [SmartClipboardHistory] {
        try MemoStore.shared.loadSmartClipboardHistory()
    }

    func save(_ history: [SmartClipboardHistory]) throws {
        try MemoStore.shared.saveSmartClipboardHistory(history: history)
    }

    func addEntry(content: String) throws {
        try MemoStore.shared.addToSmartClipboardHistory(content: content)
    }

    func updateType(id: UUID, correctedType: ClipboardItemType) throws {
        try MemoStore.shared.updateClipboardItemType(id: id, correctedType: correctedType)
    }

    func delete(id: UUID) throws {
        var history = try fetchHistory()
        history.removeAll { $0.id == id }
        try save(history)
    }

    func clearAll() throws {
        try save([])
    }
}
