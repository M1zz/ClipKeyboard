//
//  MemoRepositoryProtocol.swift
//  Token memo
//

import Foundation

protocol MemoRepositoryProtocol {
    func fetchAll() throws -> [Memo]
    func save(_ memos: [Memo]) throws
    func add(_ memo: Memo) throws
    func update(_ memo: Memo) throws
    func delete(id: UUID) throws
    func incrementClipCount(for id: UUID) throws
}
