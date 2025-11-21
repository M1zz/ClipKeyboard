//
//  MemoStore.swift
//  Token memo
//
//  Created by hyunho lee on 2023/05/16.
//

import Foundation

enum MemoType {
    case tokenMemo
    case clipboardHistory
}

class MemoStore: ObservableObject {
    static let shared = MemoStore()
    
    @Published var memos: [Memo] = []
    @Published var clipboardHistory: [ClipboardHistory] = []
    
    private static func fileURL(type: MemoType) throws -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo") else {
            return URL(string: "")
        }
        switch type {
        case .tokenMemo:
            return containerURL.appendingPathComponent("memos.data")
        case .clipboardHistory:
            return containerURL.appendingPathComponent("clipboard.history.data")
        }
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
        guard let fileURL = try Self.fileURL(type: type) else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        var memos: [Memo] = []
        //print(String(data: data, encoding: .utf8))
        
        if let newMemos = try? JSONDecoder().decode([Memo].self, from: data) {
            memos = newMemos
        } else {
            if let oldMemos = try? JSONDecoder().decode([OldMemo].self, from: data) {
                oldMemos.forEach { oldMemo in
                    memos.append(Memo(from: oldMemo))
                }
                
                //memos = oldMemos
            }
        }
        
        return memos
    }
    
    func loadClipboardHistory() throws -> [ClipboardHistory] {
        guard let fileURL = try Self.fileURL(type: .clipboardHistory) else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        if let history = try? JSONDecoder().decode([ClipboardHistory].self, from: data) {
            return history
        }
        return []
    }

    // 사용 빈도 증가
    func incrementClipCount(for memoId: UUID) throws {
        var memos = try load(type: .tokenMemo)
        if let index = memos.firstIndex(where: { $0.id == memoId }) {
            memos[index].clipCount += 1
            memos[index].lastEdited = Date()
            try save(memos: memos, type: .tokenMemo)
        }
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

    private func removeDuplicate(_ array: [Memo]) -> [Memo] {
        var removedArray = [Memo]()
        var tempKeyArray = [String]()
        for item in array {
            if !tempKeyArray.contains(item.title) {
                tempKeyArray.append(item.title)
                removedArray.append(item)
            }
        }
        return removedArray
    }
}
