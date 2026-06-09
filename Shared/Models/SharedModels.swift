//
//  SharedModels.swift
//  ClipKeyboard - Shared Models
//
//  Created by Claude Code on 2026-01-16.
//  iOS와 macOS가 공유하는 핵심 데이터 모델
//

import Foundation

// MARK: - Date Formatter

let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
}()

// MARK: - Enums

/// 클립보드 아이템 타입 (자동 분류)
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

    var localizedName: String {
        return NSLocalizedString(self.rawValue, comment: "Clipboard item type")
    }
}

/// 클립보드 콘텐츠 타입
enum ClipboardContentType: String, Codable {
    case text = "text"
    case image = "image"
    case emoji = "emoji"
    case mixed = "mixed"
}

/// Combo 아이템 타입
enum ComboItemType: String, Codable {
    case memo = "메모"
    case clipboardHistory = "클립보드"
    case template = "템플릿"

    var localizedName: String {
        return NSLocalizedString(self.rawValue, comment: "Combo item type")
    }
}

/// 메모 타입
enum MemoType {
    case memo
    case clipboardHistory
}

// MARK: - Models

/// 스마트 클립보드 히스토리 (자동 분류 + 메타데이터)
struct SmartClipboardHistory: Identifiable, Codable {
    var id = UUID()
    var content: String
    var copiedAt: Date = Date()
    var isTemporary: Bool = true
    var contentType: ClipboardContentType = .text
    var imageData: String?
    var imageWidth: Int?
    var imageHeight: Int?
    var imageFormat: String?
    var detectedType: ClipboardItemType = .text
    var confidence: Double = 0.0
    var sourceApp: String?
    var tags: [String] = []
    var autoSaveOffered: Bool = false
    var userCorrectedType: ClipboardItemType?

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

/// 클립보드 히스토리 (레거시 - 하위 호환성)
struct ClipboardHistory: Identifiable, Codable {
    var id = UUID()
    var content: String
    var copiedAt: Date = Date()
    var isTemporary: Bool = true

    init(id: UUID = UUID(), content: String, copiedAt: Date = Date(), isTemporary: Bool = true) {
        self.id = id
        self.content = content
        self.copiedAt = copiedAt
        self.isTemporary = isTemporary
    }
}

/// 플레이스홀더 값 모델
struct PlaceholderValue: Identifiable, Codable {
    var id = UUID()
    var value: String
    var sourceMemoId: UUID
    var sourceMemoTitle: String
    var addedAt: Date = Date()

    init(id: UUID = UUID(), value: String, sourceMemoId: UUID, sourceMemoTitle: String, addedAt: Date = Date()) {
        self.id = id
        self.value = value
        self.sourceMemoId = sourceMemoId
        self.sourceMemoTitle = sourceMemoTitle
        self.addedAt = addedAt
    }
}

/// 메모 모델
struct Memo: Identifiable, Codable {
    var id = UUID()
    var title: String
    var value: String
    var isChecked: Bool = false
    var lastEdited: Date = Date()
    var isFavorite: Bool = false
    var clipCount: Int = 0
    var category: String = "기본"
    var isSecure: Bool = false
    var isTemplate: Bool = false
    var templateVariables: [String] = []
    var placeholderValues: [String: [String]] = [:]
    /// 콤보 = 자식 메모 참조(순서 있음). 신 통합 모델과 직렬화 포맷 일치를 위해 유지.
    var childMemoIds: [UUID] = []
    var comboInterval: TimeInterval = 2.0
    var autoDetectedType: ClipboardItemType?
    var imageFileName: String?
    var imageFileNames: [String] = []
    var contentType: ClipboardContentType = .text

    init(id: UUID = UUID(), title: String, value: String, isChecked: Bool = false, lastEdited: Date = Date(), isFavorite: Bool = false, category: String = "기본", isSecure: Bool = false, isTemplate: Bool = false, templateVariables: [String] = [], placeholderValues: [String: [String]] = [:], childMemoIds: [UUID] = [], comboInterval: TimeInterval = 2.0, autoDetectedType: ClipboardItemType? = nil, imageFileName: String? = nil, imageFileNames: [String] = [], contentType: ClipboardContentType = .text) {
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
        self.placeholderValues = placeholderValues
        self.childMemoIds = childMemoIds
        self.comboInterval = comboInterval
        self.autoDetectedType = autoDetectedType
        self.imageFileName = imageFileName
        self.imageFileNames = imageFileNames
        self.contentType = contentType
    }

    enum CodingKeys: String, CodingKey {
        case id, title, value, isChecked
        case lastEdited = "lastEdited"
        case isFavorite = "isFavorite"
        case clipCount, category, isSecure, isTemplate
        case templateVariables, placeholderValues, autoDetectedType
        case childMemoIds, comboInterval
        case imageFileName, imageFileNames, contentType
    }

    /// 관용 디코더 — 누락 키를 모두 기본값으로 허용한다. ⚠️ 하위호환 필수:
    /// 합성 Codable은 비옵셔널 키 누락 시 keyNotFound를 던져 [Memo] 전체 디코딩을
    /// 무너뜨린다. 메인 앱이 쓴 데이터(isTemplate 키 없음, comboValues 키 추가)나
    /// childMemoIds/comboInterval이 없던 구버전 데이터를 키보드·위젯이 읽어도
    /// 메모가 통째로 사라지지 않게 한다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.value = try c.decodeIfPresent(String.self, forKey: .value) ?? ""
        self.isChecked = try c.decodeIfPresent(Bool.self, forKey: .isChecked) ?? false
        self.lastEdited = try c.decodeIfPresent(Date.self, forKey: .lastEdited) ?? Date()
        self.isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        self.clipCount = try c.decodeIfPresent(Int.self, forKey: .clipCount) ?? 0
        self.category = try c.decodeIfPresent(String.self, forKey: .category) ?? "기본"
        self.isSecure = try c.decodeIfPresent(Bool.self, forKey: .isSecure) ?? false
        self.isTemplate = try c.decodeIfPresent(Bool.self, forKey: .isTemplate) ?? false
        self.templateVariables = try c.decodeIfPresent([String].self, forKey: .templateVariables) ?? []
        self.placeholderValues = try c.decodeIfPresent([String: [String]].self, forKey: .placeholderValues) ?? [:]
        self.childMemoIds = try c.decodeIfPresent([UUID].self, forKey: .childMemoIds) ?? []
        self.comboInterval = try c.decodeIfPresent(TimeInterval.self, forKey: .comboInterval) ?? 2.0
        self.autoDetectedType = try c.decodeIfPresent(ClipboardItemType.self, forKey: .autoDetectedType)
        self.imageFileName = try c.decodeIfPresent(String.self, forKey: .imageFileName)
        self.imageFileNames = try c.decodeIfPresent([String].self, forKey: .imageFileNames) ?? []
        self.contentType = try c.decodeIfPresent(ClipboardContentType.self, forKey: .contentType) ?? .text
    }
}

/// Combo 아이템
struct ComboItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: ComboItemType
    var referenceId: UUID
    var order: Int
    var displayTitle: String?
    var displayValue: String?

    init(id: UUID = UUID(), type: ComboItemType, referenceId: UUID, order: Int, displayTitle: String? = nil, displayValue: String? = nil) {
        self.id = id
        self.type = type
        self.referenceId = referenceId
        self.order = order
        self.displayTitle = displayTitle
        self.displayValue = displayValue
    }
}

/// Combo - 여러 메모를 순서대로 자동 입력
struct Combo: Identifiable, Codable {
    var id = UUID()
    var title: String
    var items: [ComboItem]
    var interval: TimeInterval = 2.0
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

    mutating func sortItems() {
        items.sort(by: { $0.order < $1.order })
    }
}
