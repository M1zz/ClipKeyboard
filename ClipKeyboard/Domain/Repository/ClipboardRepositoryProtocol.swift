//
//  ClipboardRepositoryProtocol.swift
//  Token memo
//

import Foundation

protocol ClipboardRepositoryProtocol {
    func fetchHistory() throws -> [SmartClipboardHistory]
    func save(_ history: [SmartClipboardHistory]) throws
    func addEntry(content: String) throws
    func updateType(id: UUID, correctedType: ClipboardItemType) throws
    func delete(id: UUID) throws
    func clearAll() throws
}
