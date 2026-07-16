//
//  SavedDraft.swift
//  ClipKeyboard
//
//  임시 저장(드래프트) 모델 — 메모를 만들다가 저장하지 않고 나간 미완성 입력을 보관한다.
//  + 메뉴의 "임시 저장 보기"에서 나열하고, 탭하면 이어서 작성할 수 있다.
//

import Foundation

struct SavedDraft: Codable, Identifiable, Equatable {
    let id: UUID
    var keyword: String
    var value: String
    var hint: String
    var category: String
    var isSecure: Bool
    var isFavorite: Bool
    var savedAt: Date

    init(id: UUID = UUID(),
         keyword: String,
         value: String,
         hint: String = "",
         category: String = "텍스트",
         isSecure: Bool = false,
         isFavorite: Bool = false,
         savedAt: Date = Date()) {
        self.id = id
        self.keyword = keyword
        self.value = value
        self.hint = hint
        self.category = category
        self.isSecure = isSecure
        self.isFavorite = isFavorite
        self.savedAt = savedAt
    }

    /// 목록에 보여줄 제목 — 제목이 있으면 제목, 없으면 본문 앞부분.
    var displayTitle: String {
        let k = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !k.isEmpty { return k }
        let firstLine = value.components(separatedBy: "\n").first ?? value
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty
            ? NSLocalizedString("제목 없음", comment: "Draft without a title")
            : String(trimmed.prefix(30))
    }

    /// 목록 부제 — 본문 미리보기(한 줄).
    var previewLine: String {
        let firstLine = value.components(separatedBy: "\n").first ?? value
        return firstLine.trimmingCharacters(in: .whitespaces)
    }
}
