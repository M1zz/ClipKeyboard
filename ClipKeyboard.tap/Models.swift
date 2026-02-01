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
    case declarationNumber = "통관번호"
    case postalCode = "우편번호"
    case name = "이름"
    case birthDate = "생년월일"
    case taxID = "세금번호"
    case insuranceNumber = "보험번호"
    case vehiclePlate = "차량번호"
    case ipAddress = "IP주소"
    case membershipNumber = "회원번호"
    case trackingNumber = "송장번호"
    case confirmationCode = "예약번호"
    case medicalRecord = "진료기록번호"
    case employeeID = "사번/학번"
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
        case .declarationNumber: return "doc.text.fill"
        case .postalCode: return "mappin.circle.fill"
        case .name: return "person.fill"
        case .birthDate: return "calendar"
        case .taxID: return "number.circle.fill"
        case .insuranceNumber: return "cross.case.fill"
        case .vehiclePlate: return "car.fill"
        case .ipAddress: return "network"
        case .membershipNumber: return "star.circle.fill"
        case .trackingNumber: return "shippingbox.fill"
        case .confirmationCode: return "checkmark.seal.fill"
        case .medicalRecord: return "stethoscope"
        case .employeeID: return "person.badge.key.fill"
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
        case .declarationNumber: return "cyan"
        case .postalCode: return "teal"
        case .name: return "pink"
        case .birthDate: return "mint"
        case .taxID: return "yellow"
        case .insuranceNumber: return "teal"
        case .vehiclePlate: return "green"
        case .ipAddress: return "purple"
        case .membershipNumber: return "orange"
        case .trackingNumber: return "brown"
        case .confirmationCode: return "indigo"
        case .medicalRecord: return "red"
        case .employeeID: return "cyan"
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
        _ = NSLocalizedString("통관번호", comment: "Declaration Number")
        _ = NSLocalizedString("우편번호", comment: "Postal Code")
        _ = NSLocalizedString("이름", comment: "Name")
        _ = NSLocalizedString("생년월일", comment: "Date of Birth")
        _ = NSLocalizedString("세금번호", comment: "Tax ID")
        _ = NSLocalizedString("보험번호", comment: "Insurance Number")
        _ = NSLocalizedString("차량번호", comment: "Vehicle Plate")
        _ = NSLocalizedString("IP주소", comment: "IP Address")
        _ = NSLocalizedString("회원번호", comment: "Membership Number")
        _ = NSLocalizedString("송장번호", comment: "Tracking Number")
        _ = NSLocalizedString("예약번호", comment: "Confirmation Code")
        _ = NSLocalizedString("진료기록번호", comment: "Medical Record Number")
        _ = NSLocalizedString("사번/학번", comment: "Employee/Student ID")
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

// MARK: - Smart Clipboard History (자동 분류 + 메타데이터)
struct SmartClipboardHistory: Identifiable, Codable {
    var id = UUID()
    var content: String
    var copiedAt: Date = Date()
    var isTemporary: Bool = true

    // 콘텐츠 타입
    var contentType: ClipboardContentType = .text

    // 이미지 데이터 (Base64 인코딩)
    var imageData: String?

    // 이미지 메타데이터
    var imageWidth: Int?
    var imageHeight: Int?
    var imageFormat: String?  // "png", "jpeg", "gif"

    // 자동 분류
    var detectedType: ClipboardItemType = .text
    var confidence: Double = 0.0  // 0.0 ~ 1.0 (인식 신뢰도)

    // 메타데이터
    var sourceApp: String?  // 복사한 앱
    var tags: [String] = []
    var autoSaveOffered: Bool = false  // 자동 저장 제안 했는지

    // 사용자 피드백
    var userCorrectedType: ClipboardItemType?  // 사용자가 수정한 타입

    init(id: UUID = UUID(), content: String, copiedAt: Date = Date(), isTemporary: Bool = true, contentType: ClipboardContentType = .text, imageData: String? = nil, detectedType: ClipboardItemType = .text, confidence: Double = 0.0) {
        self.id = id
        self.content = content
        self.copiedAt = copiedAt
        self.isTemporary = isTemporary
        self.contentType = contentType
        self.imageData = imageData
        self.detectedType = detectedType
        self.confidence = confidence
    }
}

// MARK: - Combo Models

enum ComboItemType: String, Codable {
    case memo = "메모"
    case clipboardHistory = "클립보드"
    case template = "템플릿"

    // 다국어 지원 표시명
    var localizedName: String {
        return NSLocalizedString(self.rawValue, comment: "Combo item type")
    }

    // Xcode String Catalog이 문자열을 감지하도록 하는 헬퍼 함수
    static func preloadLocalizedStrings() {
        _ = NSLocalizedString("메모", comment: "Memo")
        _ = NSLocalizedString("클립보드", comment: "Clipboard")
        _ = NSLocalizedString("템플릿", comment: "Template")
    }
}

// Combo에 포함되는 개별 항목
struct ComboItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: ComboItemType
    var referenceId: UUID  // 메모 또는 클립보드 항목의 ID
    var order: Int  // 실행 순서

    // 표시용 정보 (캐시)
    var displayTitle: String?  // 항목의 제목/미리보기
    var displayValue: String?  // 항목의 실제 값 (미리보기용)

    init(id: UUID = UUID(), type: ComboItemType, referenceId: UUID, order: Int, displayTitle: String? = nil, displayValue: String? = nil) {
        self.id = id
        self.type = type
        self.referenceId = referenceId
        self.order = order
        self.displayTitle = displayTitle
        self.displayValue = displayValue
    }
}

// Combo - 여러 메모를 순서대로 자동 입력하는 시스템
struct Combo: Identifiable, Codable {
    var id = UUID()
    var title: String
    var items: [ComboItem]  // 순서대로 실행될 항목들
    var interval: TimeInterval = 2.0  // 각 항목 사이의 시간 간격 (초)
    var createdAt: Date = Date()
    var lastUsed: Date?
    var category: String = "텍스트"
    var useCount: Int = 0
    var isFavorite: Bool = false

    init(id: UUID = UUID(), title: String, items: [ComboItem] = [], interval: TimeInterval = 2.0, createdAt: Date = Date(), lastUsed: Date? = nil, category: String = "텍스트", useCount: Int = 0, isFavorite: Bool = false) {
        self.id = id
        self.title = title
        self.items = items.sorted(by: { $0.order < $1.order })
        self.interval = interval
        self.createdAt = createdAt
        self.lastUsed = lastUsed
        self.category = category
        self.useCount = useCount
        self.isFavorite = isFavorite
    }

    // 항목을 순서대로 정렬
    mutating func sortItems() {
        items.sort(by: { $0.order < $1.order })
    }
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

    // MARK: - Smart Clipboard History Methods

    private static func smartClipboardFileURL() throws -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo") else {
            print("❌ [MemoStore.smartClipboardFileURL] App Group 컨테이너를 찾을 수 없음!")
            return nil
        }
        return containerURL.appendingPathComponent("smart.clipboard.history.data")
    }

    func loadSmartClipboardHistory() throws -> [SmartClipboardHistory] {
        guard let fileURL = try Self.smartClipboardFileURL() else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        if let history = try? JSONDecoder().decode([SmartClipboardHistory].self, from: data) {
            return history
        }
        return []
    }

    func saveSmartClipboardHistory(history: [SmartClipboardHistory]) throws {
        let data = try JSONEncoder().encode(history)
        guard let outfile = try Self.smartClipboardFileURL() else { return }
        try data.write(to: outfile)
    }

    // MARK: - Combo Methods

    private static func combosFileURL() throws -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo") else {
            print("❌ [MemoStore.combosFileURL] App Group 컨테이너를 찾을 수 없음!")
            return nil
        }
        return containerURL.appendingPathComponent("combos.data")
    }

    func loadCombos() throws -> [Combo] {
        guard let fileURL = try Self.combosFileURL() else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        if let combos = try? JSONDecoder().decode([Combo].self, from: data) {
            return combos
        }
        return []
    }

    func saveCombos(_ combos: [Combo]) throws {
        let data = try JSONEncoder().encode(combos)
        guard let outfile = try Self.combosFileURL() else { return }
        try data.write(to: outfile)
    }
}
