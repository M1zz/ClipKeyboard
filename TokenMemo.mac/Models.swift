//
//  Models.swift
//  TokenMemo.mac
//
//  Created by Claude on 2025-11-28.
//

import Foundation
import Combine

// Clipboard History Model
struct ClipboardHistory: Identifiable, Codable {
    var id = UUID()
    var content: String
    var copiedAt: Date = Date()
    var isTemporary: Bool = true // 자동으로 7일 후 삭제

    init(id: UUID = UUID(), content: String, copiedAt: Date = Date(), isTemporary: Bool = true) {
        self.id = id
        self.content = content
        self.copiedAt = copiedAt
        self.isTemporary = isTemporary
    }
}

struct Memo: Identifiable, Codable {
    var id = UUID()
    var title: String
    var value: String
    var isChecked: Bool = false
    var lastEdited: Date = Date()
    var isFavorite: Bool = false
    var clipCount: Int = 0

    // New features
    var category: String = "기본"
    var isSecure: Bool = false
    var isTemplate: Bool = false
    var templateVariables: [String] = []
    var shortcut: String?

    // 템플릿의 플레이스홀더 값들 저장 (예: {이름}: [유미, 주디, 리이오])
    var placeholderValues: [String: [String]] = [:]

    init(id: UUID = UUID(), title: String, value: String, isChecked: Bool = false, lastEdited: Date = Date(), isFavorite: Bool = false, category: String = "기본", isSecure: Bool = false, isTemplate: Bool = false, templateVariables: [String] = [], shortcut: String? = nil, placeholderValues: [String: [String]] = [:]) {
        self.id = id
        self.title = title
        self.value = value
        self.isChecked = isChecked
        self.lastEdited = lastEdited
        self.isFavorite = isFavorite
        self.category = category
        self.isSecure = isSecure
        self.isTemplate = isTemplate
        self.templateVariables = templateVariables
        self.shortcut = shortcut
        self.placeholderValues = placeholderValues
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case value
        case isChecked
        case lastEdited = "lastEdited"
        case isFavorite = "isFavorite"
        case clipCount
        case category
        case isSecure
        case isTemplate
        case templateVariables
        case shortcut
        case placeholderValues
    }
}

enum MemoType {
    case tokenMemo
    case clipboardHistory
}

// MemoStore - Simplified for macOS
class MemoStore: ObservableObject {
    static let shared = MemoStore()

    @Published var memos: [Memo] = []
    @Published var clipboardHistory: [ClipboardHistory] = []

    private static func fileURL(type: MemoType) throws -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo") else {
            print("❌ [MemoStore.fileURL] App Group 컨테이너를 찾을 수 없음!")
            return nil
        }

        let fileURL: URL
        switch type {
        case .tokenMemo:
            fileURL = containerURL.appendingPathComponent("memos.data")
        case .clipboardHistory:
            fileURL = containerURL.appendingPathComponent("clipboard.history.data")
        }

        return fileURL
    }

    func save(memos: [Memo], type: MemoType) throws {
        let data = try JSONEncoder().encode(memos)
        guard let outfile = try Self.fileURL(type: type) else { return }
        try data.write(to: outfile)
    }

    func saveClipboardHistory(history: [ClipboardHistory]) throws {
        let data = try JSONEncoder().encode(history)
        guard let outfile = try Self.fileURL(type: .clipboardHistory) else { return }
        try data.write(to: outfile)
    }

    func load(type: MemoType) throws -> [Memo] {
        guard let fileURL = try Self.fileURL(type: type) else {
            return []
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }

        if let memos = try? JSONDecoder().decode([Memo].self, from: data) {
            return memos
        }

        return []
    }

    func loadClipboardHistory() throws -> [ClipboardHistory] {
        guard let fileURL = try Self.fileURL(type: .clipboardHistory) else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        if let history = try? JSONDecoder().decode([ClipboardHistory].self, from: data) {
            return history
        }
        return []
    }

    // 클립보드 히스토리 추가
    func addToClipboardHistory(content: String) throws {
        var history = try loadClipboardHistory()

        // 중복 제거
        history.removeAll { $0.content == content }

        // 새 항목 추가
        let newItem = ClipboardHistory(content: content)
        history.insert(newItem, at: 0)

        // 최대 100개까지만 유지
        if history.count > 100 {
            history = Array(history.prefix(100))
        }

        // 7일 이상 된 임시 항목 자동 삭제
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        history.removeAll { $0.isTemporary && $0.copiedAt < sevenDaysAgo }

        try saveClipboardHistory(history: history)
    }
}
