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

    private init() {}

    enum FileKey {
        case memos
        case legacyClipboard
        case smartClipboard
        case combos

        /// 파일명은 StorageFile 단일 출처에서 위임.
        var fileName: String {
            switch self {
            case .memos: return StorageFile.memos
            case .legacyClipboard: return StorageFile.clipboardHistory
            case .smartClipboard: return StorageFile.smartClipboardHistory
            case .combos: return StorageFile.combos
            }
        }
    }

    var containerURL: URL {
        get throws {
            guard let url = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: AppGroup.identifier
            ) else { throw StorageError.containerNotFound }
            return url
        }
    }

    func fileURL(for key: FileKey) throws -> URL {
        try containerURL.appendingPathComponent(key.fileName)
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
