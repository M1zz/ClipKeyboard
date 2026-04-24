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
    var isCombo: Bool = false
    var comboValues: [String] = []
    var isFavorite: Bool = false
    var autoDetectedType: ClipboardItemType? = nil
    #if os(iOS)
    var images: [UIImage] = []
    #endif
}

struct SaveMemoUseCase {
    private let memoRepository: MemoRepositoryProtocol

    init(memoRepository: MemoRepositoryProtocol = MemoRepository()) {
        self.memoRepository = memoRepository
    }

    /// 새 메모 저장. 이미지가 있으면 App Group에 저장 후 fileName 연결.
    @discardableResult
    func execute(_ draft: MemoDraft, editingMemo: Memo? = nil) throws -> Memo {
        var memo: Memo
        if var existing = editingMemo {
            existing.title = draft.title
            existing.value = draft.value
            existing.category = draft.category
            existing.isSecure = draft.isSecure
            existing.isTemplate = draft.isTemplate
            existing.isCombo = draft.isCombo
            existing.comboValues = draft.comboValues
            existing.isFavorite = draft.isFavorite
            existing.autoDetectedType = draft.autoDetectedType
            existing.lastEdited = Date()
            memo = existing
            try memoRepository.update(memo)
        } else {
            memo = Memo(
                title: draft.title,
                value: draft.value,
                isFavorite: draft.isFavorite,
                category: draft.category,
                isSecure: draft.isSecure,
                isTemplate: draft.isTemplate,
                isCombo: draft.isCombo,
                comboValues: draft.comboValues,
                autoDetectedType: draft.autoDetectedType
            )
            try memoRepository.add(memo)
        }
        return memo
    }
}
