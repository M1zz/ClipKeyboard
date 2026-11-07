//
//  MemoRepository.swift
//  ClipKeyboard
//

import Foundation

final class MemoRepository: MemoRepositoryProtocol {
    func fetchAll() throws -> [Memo] {
        try MemoStore.shared.load(type: .memo)
    }

    func save(_ memos: [Memo]) throws {
        try MemoStore.shared.save(memos: memos, type: .memo)
    }

    func delete(id: UUID) throws {
        var memos = try fetchAll()
        memos.removeAll { $0.id == id }
        try save(memos)   // 배운 것(커서 자리 · 편집 습관)은 저장소가 같이 지운다
    }

    func incrementClipCount(for id: UUID) throws {
        try MemoStore.shared.incrementClipCount(for: id)
    }
}
