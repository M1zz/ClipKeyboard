//
//  MemoRepository.swift
//  ClipKeyboard
//

import Foundation

final class MemoRepository: MemoRepositoryProtocol {
    private let storage: AppGroupStorage

    init(storage: AppGroupStorage = .shared) {
        self.storage = storage
    }

    func fetchAll() throws -> [Memo] {
        try MemoStore.shared.load(type: .memo)
    }

    func save(_ memos: [Memo]) throws {
        try MemoStore.shared.save(memos: memos, type: .memo)
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
        // 단축어가 사라지면 그 단축어에 대해 배운 캐럿 자리도 같이 지운다.
        // 안 지우면 새 단축어가 같은 id 를 받을 일은 없어도 값이 계속 쌓인다.
        CursorMemory.forget(for: id)
        EditPattern.forget(for: id)
    }

    func incrementClipCount(for id: UUID) throws {
        try MemoStore.shared.incrementClipCount(for: id)
    }
}
