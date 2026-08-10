//
//  QuickShortcutSave.swift
//  ClipKeyboardShareExtension / ClipKeyboardActionExtension
//
//  **앱 밖에서 단축어를 만드는 유일한 길.** 공유 확장(앱 줄)과 동작 확장(목록)이 같은 파일을 쓴다.
//
//  ⚠️ 두 익스텐션은 메인 앱 코드를 못 쓴다(타겟이 다르다). 그래서 `Memo` 의 JSON 을 손으로
//     쓰는데, 이걸 확장마다 한 벌씩 두면 한쪽만 고쳐지는 날이 반드시 온다.
//     스키마를 아는 곳은 **여기 하나**여야 한다.
//     (앱이 읽을 수 있는지는 `ClipKeyboardTests/ShareExtensionMemoWriteTests` 가 지킨다)
//
//  ⚠️ 날짜는 **2001 기준 초**(`timeIntervalSinceReferenceDate`)로 적는다.
//     메인 앱이 기본 `JSONEncoder` 를 쓰기 때문이다 - epoch(1970)로 적으면 31년 어긋난
//     시각이 되어 최근순 정렬이 무너지고, 화면에서는 "왜 맨 아래 있지"로만 보인다.
//
//  ⚠️ `memos.data` 는 **메인 앱이 통째로 덮어쓰는 파일**이다. 여기서 덧붙인 것을 앱이 모른 채
//     저장하면 사라진다. 그래서 바꾼 시각을 App Group 에 남기고(`memos.externalChangeAt`),
//     앱은 돌아올 때 그 표식을 보고 다시 읽는다.
//

import Foundation
import UIKit
import os

private let saveLog = Logger(subsystem: "com.Ysoup.TokenMemo.share", category: "quicksave")

enum QuickShortcutSave {

    static let appGroupID = "group.com.Ysoup.TokenMemo"

    /// 앱 밖 변경 표식 - 메인 앱의 `DefaultsKey.memosExternalChangeAt` 와 같은 문자열이어야 한다.
    private static let externalChangeKey = "memos.externalChangeAt"

    enum Outcome {
        /// 바로 쓸 수 있는 단축어로 저장됐다.
        case shortcut
        /// 보관함에 담겼다(사용자가 골랐거나, 단축어 저장이 안전하지 않아 물러섰다).
        case inbox
        /// 아무것도 못 했다.
        case failed
    }

    // MARK: - 제목·분류 자동 판정

    /// 공유·동작 확장이 **같은 규칙**으로 제목과 분류를 정한다.
    static func detect(text: String, hasImages: Bool) -> (title: String, category: String) {
        if hasImages {
            return (NSLocalizedString("Image", comment: "Default title for image memo"), "기본")
        }
        if text.contains("@") && text.contains(".") {
            return ("Email", "이메일")
        }
        if text.lowercased().hasPrefix("http") {
            return ("URL", "URL")
        }
        if text.range(of: #"^[A-Z]{2}\d{2}[A-Z0-9]{10,30}$"#, options: .regularExpression) != nil {
            return ("IBAN", "IBAN")
        }
        let firstLine = text.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? text
        let title = firstLine.count <= 30 ? firstLine : String(firstLine.prefix(27)) + "…"
        return (title, "기본")
    }

    // MARK: - 단축어로 저장

    /// 바로 쓸 수 있는 단축어로 저장한다 - 키보드에 곧장 올라온다.
    /// 안전하지 않은 상황(파일을 읽지 못함·쓰기 실패)에서는 **덮어쓰지 않고** 보관함으로 물러선다.
    @discardableResult
    static func saveAsShortcut(title: String,
                               value: String,
                               category: String,
                               images: [UIImage] = []) -> Outcome {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            saveLog.error("📤 [QuickSave] App Group 컨테이너 접근 실패")
            return .failed
        }

        let memosURL = containerURL.appendingPathComponent("memos.data")
        var memos: [[String: Any]] = []
        if let data = try? Data(contentsOf: memosURL),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            memos = decoded
        } else if FileManager.default.fileExists(atPath: memosURL.path) {
            // ⚠️ 읽지 못한 파일을 덮어쓰면 남의 단축어가 통째로 날아간다.
            saveLog.error("📤 [QuickSave] memos.data 를 읽지 못함. 덮어쓰지 않고 보관함으로 우회")
            return saveToInbox(title: title, value: value, category: category, images: images)
        }

        let id = UUID().uuidString
        let imageFileNames = persistImages(images, id: id, containerURL: containerURL)
        let hasText = !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let contentType = imageFileNames.isEmpty ? "text" : (hasText ? "mixed" : "image")

        // 빠진 키는 앱의 관용적 디코더가 기본값으로 채운다(Memo.init(from:)).
        let newMemo: [String: Any] = [
            "id": id,
            "title": title.isEmpty ? String(value.prefix(20)) : title,
            "value": value,
            "lastEdited": Date().timeIntervalSinceReferenceDate,
            "category": category,
            "contentType": contentType,
            "imageFileNames": imageFileNames,
            "isFavorite": false
        ]
        // 맨 앞에 둔다 - 방금 담은 것이 목록 위에 보여야 "들어갔구나"가 확인된다.
        memos.insert(newMemo, at: 0)

        do {
            let data = try JSONSerialization.data(withJSONObject: memos, options: [])
            try data.write(to: memosURL, options: .atomic)
            markExternalChange()
            saveLog.info("📤 [QuickSave] 단축어로 저장 완료, 총 \(memos.count)개")
            return .shortcut
        } catch {
            saveLog.error("📤 [QuickSave] 단축어 저장 실패: \(error), 보관함으로 우회")
            return saveToInbox(title: title, value: value, category: category, images: images)
        }
    }

    // MARK: - 보관함에 담기

    /// 나중에 정하도록 빠른 메모(Inbox)에 보류 저장한다.
    ///
    /// ⚠️ 스키마는 메인 앱의 `QuickNote` Codable 과 정확히 일치해야 한다
    ///    `createdAt` 은 **epoch 초**이고, `contentType` 은 "text"/"image"/"mixed" 다.
    ///    (단축어 쪽과 날짜 기준이 다르다. 저쪽은 `Memo` 의 Date 라 2001 기준이다)
    @discardableResult
    static func saveToInbox(title: String,
                            value: String,
                            category: String,
                            images: [UIImage] = []) -> Outcome {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            saveLog.error("📤 [QuickSave] App Group 컨테이너 접근 실패")
            return .failed
        }

        let inboxURL = containerURL.appendingPathComponent("quicknotes.data")
        var notes: [[String: Any]] = []
        if let data = try? Data(contentsOf: inboxURL),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            notes = decoded
        }

        let id = UUID().uuidString
        let imageFileNames = persistImages(images, id: id, containerURL: containerURL)
        let hasText = !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let contentType = imageFileNames.isEmpty ? "text" : (hasText ? "mixed" : "image")

        notes.append([
            "id": id,
            "text": value,
            "imageFileNames": imageFileNames,
            "contentType": contentType,
            "createdAt": Date().timeIntervalSince1970,
            "source": "share",
            "suggestedTitle": title,
            "suggestedCategory": category
        ])

        do {
            let data = try JSONSerialization.data(withJSONObject: notes, options: [])
            try data.write(to: inboxURL, options: .atomic)
            UserDefaults(suiteName: appGroupID)?.set(Date().timeIntervalSince1970,
                                                     forKey: "quicknote.lastSavedAt")
            saveLog.info("📤 [QuickSave] 보관함 저장 완료, 총 \(notes.count)개")
            return .inbox
        } catch {
            saveLog.error("📤 [QuickSave] 보관함 저장 실패: \(error)")
            return .failed
        }
    }

    // MARK: - 거들기

    /// 앱이 돌아올 때 다시 읽도록 표식을 남긴다. 이게 없으면 앱이 낡은 목록으로 덮어쓴다.
    private static func markExternalChange() {
        UserDefaults(suiteName: appGroupID)?.set(Date().timeIntervalSince1970, forKey: externalChangeKey)
    }

    private static func persistImages(_ images: [UIImage], id: String, containerURL: URL) -> [String] {
        guard !images.isEmpty else { return [] }
        let imagesDir = containerURL.appendingPathComponent("Images")
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        var names: [String] = []
        for (index, image) in images.enumerated() {
            let fileName = index == 0 ? "\(id).jpg" : "\(id)_\(index).jpg"
            let fileURL = imagesDir.appendingPathComponent(fileName)
            if let data = resized(image, maxDimension: 1024).jpegData(compressionQuality: 0.7) {
                try? data.write(to: fileURL, options: .atomic)
                names.append(fileName)
            }
        }
        return names
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
