//
//  MemoRepositoryProtocol.swift
//  ClipKeyboard
//

import Foundation

protocol MemoRepositoryProtocol {
    func fetchAll() throws -> [Memo]
    func save(_ memos: [Memo]) throws
    func delete(id: UUID) throws
    func incrementClipCount(for id: UUID) throws
}
