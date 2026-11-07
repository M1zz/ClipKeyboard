//
//  AppGroupListFile.swift
//  ClipKeyboard
//
//  **App Group 안의 JSON 목록 파일 하나.** 빠른 메모 보관함 · 임시 저장처럼 "목록을 통째로 읽고,
//  하나 바꾸고, 통째로 쓴다" 는 저장소가 같은 규칙을 한 곳에서 쓴다.
//
//  규칙 셋:
//  - **없음과 못 읽음을 섞지 않는다.** 파일이 없으면 빈 목록, 있는데 못 읽으면 던진다.
//    못 읽은 것을 빈 목록으로 치면 다음 쓰기가 멀쩡한 파일을 한 줄짜리로 덮는다.
//  - **깨진 파일은 사본을 남긴다.** 풀 수 없는 파일은 `.unreadable` 사본을 옆에 두고 빈 목록으로 시작한다.
//    사본이 있으니 덮여도 되찾을 수 있다.
//  - **고치기는 읽기에 성공했을 때만.** `modify` 가 읽기 · 바꾸기 · 쓰기를 한 번에 하고,
//    읽기에 실패하면 아무것도 쓰지 않고 던진다.
//
//  메모 본체(`memos.data`)는 이 타입을 쓰지 않는다. 캐시 · 옛 형식 · 되돌리기 스냅샷이 붙은 `MemoStore` 가 맡는다.
//

import Foundation

struct AppGroupListFile<Item: Codable> {
    let fileName: String

    private var url: URL {
        get throws {
            guard let container = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) else {
                throw AppGroupFileError.noContainer
            }
            return container.appendingPathComponent(fileName)
        }
    }

    /// 읽는다. 없으면 빈 목록, 있는데 못 읽으면 던진다, 깨졌으면 사본을 남기고 빈 목록.
    func read() throws -> [Item] {
        let url = try url
        guard let data = try Data.readIfPresent(url) else { return [] }
        do {
            return try JSONDecoder().decode([Item].self, from: data)
        } catch {
            let copy = url.appendingPathExtension("unreadable")
            if !FileManager.default.fileExists(atPath: copy.path) {
                try? FileManager.default.copyItem(at: url, to: copy)
            }
            AppLog.error(.store, "🚨 [AppGroupListFile] \(fileName) 을 풀지 못해 사본(\(copy.lastPathComponent))을 남기고 비운 채 시작한다")
            return []
        }
    }

    /// 화면에 보일 목록. 못 읽으면 빈 목록이다(보여 주기만 하므로 덮을 일이 없다).
    func readForDisplay() -> [Item] {
        (try? read()) ?? []
    }

    func write(_ items: [Item]) throws {
        let data = try JSONEncoder().encode(items)
        try data.write(to: try url, options: .atomic)
    }

    /// 읽고, 바꾸고, 쓴다. 읽기에 실패하면 **쓰지 않고** 던진다. 바꾼 뒤의 목록을 돌려준다.
    @discardableResult
    func modify(_ change: (inout [Item]) -> Void) throws -> [Item] {
        var items = try read()
        change(&items)
        try write(items)
        return items
    }
}

enum AppGroupFileError: Error {
    case noContainer
}
