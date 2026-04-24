//
//  AppGroupStorage.swift
//  ClipKeyboard
//

import Foundation

enum StorageError: Error {
    case containerNotFound
    case fileNotFound
    case encodingFailed
    case decodingFailed
}

final class AppGroupStorage {
    static let shared = AppGroupStorage()
    private let groupID = "group.com.Ysoup.TokenMemo"

    private init() {}

    enum FileKey: String {
        case memos = "memos.data"
        case legacyClipboard = "clipboard.history.data"
        case smartClipboard = "smart.clipboard.history.data"
        case combos = "combos.data"
    }

    var containerURL: URL {
        get throws {
            guard let url = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: groupID
            ) else { throw StorageError.containerNotFound }
            return url
        }
    }

    func fileURL(for key: FileKey) throws -> URL {
        try containerURL.appendingPathComponent(key.rawValue)
    }

    func read(key: FileKey) throws -> Data {
        let url = try fileURL(for: key)
        guard let data = try? Data(contentsOf: url) else {
            throw StorageError.fileNotFound
        }
        return data
    }

    func write(_ data: Data, key: FileKey) throws {
        let url = try fileURL(for: key)
        try data.write(to: url, options: .atomic)
    }

    func imagesDirectory() throws -> URL {
        let dir = try containerURL.appendingPathComponent("Images")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
