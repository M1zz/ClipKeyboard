//
//  MemoRepository.swift
//  Token memo
//

import Foundation

final class MemoRepository: MemoRepositoryProtocol {
    private let storage: AppGroupStorage

    init(storage: AppGroupStorage = .shared) {
        self.storage = storage
    }

    func fetchAll() throws -> [Memo] {
        try MemoStore.shared.load(type: .tokenMemo)
    }

    func save(_ memos: [Memo]) throws {
        try MemoStore.shared.save(memos: memos, type: .tokenMemo)
    }

    func add(_ memo: Memo) throws {
        var memos = try fetchAll()
        memos.insert(memo, at: 0)
        try save(memos)
    }

    func update(_ memo: Memo) throws {
        var memos = try fetchAll()
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }
        memos[index] = memo
        try save(memos)
    }

    func delete(id: UUID) throws {
        var memos = try fetchAll()
        memos.removeAll { $0.id == id }
        try save(memos)
    }

    func incrementClipCount(for id: UUID) throws {
        try MemoStore.shared.incrementClipCount(for: id)
    }
}
