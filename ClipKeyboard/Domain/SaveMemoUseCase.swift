//
//  SaveMemoUseCase.swift
//  ClipKeyboard
//

import Foundation
#if os(iOS)
import UIKit
#endif

struct MemoDraft {
    var title: String
    var value: String
    var category: String
    var isSecure: Bool = false
    var isTemplate: Bool = false
    var isFavorite: Bool = false
    var autoDetectedType: ClipboardItemType?
    #if os(iOS)
    var images: [UIImage] = []
    #endif
}

struct SaveMemoUseCase {
    private let memoRepository: MemoRepositoryProtocol

    init(memoRepository: MemoRepositoryProtocol = MemoRepository()) {
        self.memoRepository = memoRepository
    }

    /// 보안 메모면 값을 암호화해 저장한다. 보안 해제 시 암호문이면 복호화해 평문으로 되돌린다.
    /// 암복호화 모두 idempotent + 평문 통과라 어떤 상태의 draft.value가 와도 안전.
    private func storedValue(for draft: MemoDraft) -> String {
        if draft.isSecure {
            return SecureMemoCrypto.encrypt(draft.value) ?? draft.value
        }
        if SecureMemoCrypto.isEncrypted(draft.value) {
            return SecureMemoCrypto.decrypt(draft.value) ?? draft.value
        }
        return draft.value
    }

    /// 새 메모 저장. 이미지가 있으면 App Group에 저장 후 fileName 연결.
    @discardableResult
    func execute(_ draft: MemoDraft, editingMemo: Memo? = nil) throws -> Memo {
        let valueToStore = storedValue(for: draft)
        var memo: Memo
        if var existing = editingMemo {
            existing.title = draft.title
            existing.value = valueToStore
            existing.category = draft.category
            existing.isSecure = draft.isSecure
            existing.isFavorite = draft.isFavorite
            existing.autoDetectedType = draft.autoDetectedType
            existing.lastEdited = Date()
            memo = existing
            try memoRepository.update(memo)
        } else {
            memo = Memo(
                title: draft.title,
                value: valueToStore,
                isFavorite: draft.isFavorite,
                category: draft.category,
                isSecure: draft.isSecure,
                autoDetectedType: draft.autoDetectedType
            )
            try memoRepository.add(memo)
        }
        return memo
    }
}
