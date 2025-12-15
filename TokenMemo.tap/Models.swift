//
//  Models.swift
//  TokenMemo.tap
//
//  Created by Claude on 2025-11-28.
//

import Foundation
import Combine
import AppKit

// Clipboard History Model
struct ClipboardHistory: Identifiable, Codable {
    var id = UUID()
    var content: String
    var copiedAt: Date = Date()
    var isTemporary: Bool = true // 자동으로 7일 후 삭제
    var imageFileName: String? // 이미지 파일명 (있는 경우)
    var imageFileNames: [String] = [] // 여러 이미지 파일명
    var contentType: ClipboardContentType = .text

    init(id: UUID = UUID(), content: String, copiedAt: Date = Date(), isTemporary: Bool = true, imageFileName: String? = nil, imageFileNames: [String] = [], contentType: ClipboardContentType = .text) {
        self.id = id
        self.content = content
        self.copiedAt = copiedAt
        self.isTemporary = isTemporary
        self.imageFileName = imageFileName
        self.imageFileNames = imageFileNames
        self.contentType = contentType
    }
}

// MARK: - Clipboard Item Type (자동 분류)
enum ClipboardItemType: String, Codable, CaseIterable {
    case email = "이메일"
    case phone = "전화번호"
    case address = "주소"
    case url = "URL"
    case creditCard = "카드번호"
    case bankAccount = "계좌번호"
    case passportNumber = "여권번호"
    case customsCode = "통관부호"
    case postalCode = "우편번호"
    case name = "이름"
    case birthDate = "생년월일"
    case rrn = "주민등록번호"
    case businessNumber = "사업자등록번호"
    case vehiclePlate = "차량번호"
    case ipAddress = "IP주소"
    case image = "이미지"
    case text = "텍스트"

    var icon: String {
        switch self {
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .address: return "location.fill"
        case .url: return "link"
        case .creditCard: return "creditcard.fill"
        case .bankAccount: return "banknote.fill"
        case .passportNumber: return "person.text.rectangle.fill"
        case .customsCode: return "shippingbox.fill"
        case .postalCode: return "mappin.circle.fill"
        case .name: return "person.fill"
        case .birthDate: return "calendar"
        case .rrn: return "person.crop.circle.badge.checkmark"
        case .businessNumber: return "building.2.fill"
        case .vehiclePlate: return "car.fill"
        case .ipAddress: return "network"
        case .image: return "photo.fill"
        case .text: return "doc.text"
        }
    }

    var color: String {
        switch self {
        case .email: return "blue"
        case .phone: return "green"
        case .address: return "purple"
        case .url: return "orange"
        case .creditCard: return "red"
        case .bankAccount: return "indigo"
        case .passportNumber: return "brown"
        case .customsCode: return "cyan"
        case .postalCode: return "teal"
        case .name: return "pink"
        case .birthDate: return "mint"
        case .rrn: return "yellow"
        case .businessNumber: return "blue"
        case .vehiclePlate: return "green"
        case .ipAddress: return "purple"
        case .image: return "pink"
        case .text: return "gray"
        }
    }

    // 다국어 지원 표시명
    var localizedName: String {
        return NSLocalizedString(self.rawValue, comment: "Clipboard item type")
    }

    // Xcode String Catalog이 문자열을 감지하도록 하는 헬퍼 함수
    static func preloadLocalizedStrings() {
        _ = NSLocalizedString("이메일", comment: "Email")
        _ = NSLocalizedString("전화번호", comment: "Phone Number")
        _ = NSLocalizedString("주소", comment: "Address")
        _ = NSLocalizedString("URL", comment: "URL")
        _ = NSLocalizedString("카드번호", comment: "Card Number")
        _ = NSLocalizedString("계좌번호", comment: "Account Number")
        _ = NSLocalizedString("여권번호", comment: "Passport Number")
        _ = NSLocalizedString("통관부호", comment: "Customs Code")
        _ = NSLocalizedString("우편번호", comment: "Postal Code")
        _ = NSLocalizedString("이름", comment: "Name")
        _ = NSLocalizedString("생년월일", comment: "Date of Birth")
        _ = NSLocalizedString("주민등록번호", comment: "Resident Registration Number")
        _ = NSLocalizedString("사업자등록번호", comment: "Business Registration Number")
        _ = NSLocalizedString("차량번호", comment: "Vehicle Plate")
        _ = NSLocalizedString("IP주소", comment: "IP Address")
        _ = NSLocalizedString("이미지", comment: "Image")
        _ = NSLocalizedString("텍스트", comment: "Text")
    }
}

enum ClipboardContentType: String, Codable {
    case text
    case image
    case mixed // 텍스트 + 이미지
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

    // 이미지 지원
    var imageFileName: String? // 이미지 파일명 (있는 경우) - 하위 호환성 유지
    var imageFileNames: [String] = [] // 여러 이미지 파일명
    var contentType: ClipboardContentType = .text

    init(id: UUID = UUID(), title: String, value: String, isChecked: Bool = false, lastEdited: Date = Date(), isFavorite: Bool = false, category: String = "기본", isSecure: Bool = false, isTemplate: Bool = false, templateVariables: [String] = [], shortcut: String? = nil, placeholderValues: [String: [String]] = [:], imageFileName: String? = nil, imageFileNames: [String] = [], contentType: ClipboardContentType = .text) {
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
        self.imageFileName = imageFileName
        self.imageFileNames = imageFileNames
        self.contentType = contentType
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
        case imageFileName
        case imageFileNames
        case contentType
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

    // 이미지와 함께 클립보드 히스토리 추가
    func addImageToClipboardHistory(image: NSImage) throws {
        var history = try loadClipboardHistory()

        // 이미지 파일로 저장
        let fileName = "\(UUID().uuidString).png"
        try saveImage(image, fileName: fileName)

        // 새 항목 추가
        let newItem = ClipboardHistory(
            content: "이미지",
            copiedAt: Date(),
            isTemporary: true,
            imageFileName: fileName,
            contentType: .image
        )
        history.insert(newItem, at: 0)

        // 최대 100개까지만 유지
        if history.count > 100 {
            // 삭제되는 항목의 이미지 파일도 삭제
            for item in history[100...] {
                if let imageFileName = item.imageFileName {
                    try? deleteImage(fileName: imageFileName)
                }
            }
            history = Array(history.prefix(100))
        }

        // 7일 이상 된 임시 항목 자동 삭제
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let itemsToDelete = history.filter { $0.isTemporary && $0.copiedAt < sevenDaysAgo }
        for item in itemsToDelete {
            if let imageFileName = item.imageFileName {
                try? deleteImage(fileName: imageFileName)
            }
        }
        history.removeAll { $0.isTemporary && $0.copiedAt < sevenDaysAgo }

        try saveClipboardHistory(history: history)
    }

    // 이미지 저장
    func saveImage(_ image: NSImage, fileName: String) throws {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo") else {
            throw NSError(domain: "MemoStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Group 컨테이너를 찾을 수 없음"])
        }

        let imagesDirectory = containerURL.appendingPathComponent("Images", isDirectory: true)

        // 이미지 디렉토리 생성
        if !FileManager.default.fileExists(atPath: imagesDirectory.path) {
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        }

        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        // NSImage를 PNG 데이터로 변환
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "MemoStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "이미지를 PNG로 변환할 수 없음"])
        }

        try pngData.write(to: fileURL)
    }

    // 이미지 로드
    func loadImage(fileName: String) -> NSImage? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo") else {
            return nil
        }

        let fileURL = containerURL.appendingPathComponent("Images", isDirectory: true).appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        return NSImage(contentsOf: fileURL)
    }

    // 이미지 삭제
    func deleteImage(fileName: String) throws {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo") else {
            return
        }

        let fileURL = containerURL.appendingPathComponent("Images", isDirectory: true).appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
