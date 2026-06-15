//
//  Memo.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/05/15.
//

import Foundation

let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
}()

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
    // v4.0 글로벌 피봇 추가 — 영어 rawValue (신규 국제 결제/세무/크립토 식별자)
    case iban = "IBAN"
    case swift = "SWIFT/BIC"
    case vat = "VAT Number"
    case cryptoWallet = "Crypto Wallet"
    case paypalLink = "PayPal Link"

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
        case .iban: return "building.columns.fill"
        case .swift: return "globe"
        case .vat: return "doc.badge.gearshape"
        case .cryptoWallet: return "bitcoinsign.circle.fill"
        case .paypalLink: return "dollarsign.circle.fill"
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
        case .iban: return "blue"
        case .swift: return "indigo"
        case .vat: return "orange"
        case .cryptoWallet: return "yellow"
        case .paypalLink: return "blue"
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
        // v4.0 글로벌 피봇
        _ = NSLocalizedString("IBAN", comment: "IBAN (International Bank Account Number)")
        _ = NSLocalizedString("SWIFT/BIC", comment: "SWIFT/BIC bank code")
        _ = NSLocalizedString("VAT Number", comment: "VAT identification number")
        _ = NSLocalizedString("Crypto Wallet", comment: "Cryptocurrency wallet address")
        _ = NSLocalizedString("PayPal Link", comment: "PayPal.me link")
    }
}

// MARK: - Clipboard Content Type
enum ClipboardContentType: String, Codable {
    case text = "text"
    case image = "image"
    case emoji = "emoji"
    case mixed = "mixed" // 텍스트 + 이미지
}

// MARK: - Smart Clipboard History (자동 분류 클립보드)
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

// Clipboard History Model (Legacy - 하위 호환성)
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

struct OldMemo: Identifiable, Codable {
    var id = UUID()
    let title: String
    let value: String
    var isChecked: Bool = false
}

// 플레이스홀더 값 모델 - 어느 템플릿에서 추가되었는지 추적
struct PlaceholderValue: Identifiable, Codable {
    var id = UUID()
    var value: String
    var sourceMemoId: UUID  // 이 값을 추가한 메모의 ID
    var sourceMemoTitle: String  // 이 값을 추가한 메모의 제목
    var addedAt: Date = Date()

    init(id: UUID = UUID(), value: String, sourceMemoId: UUID, sourceMemoTitle: String, addedAt: Date = Date()) {
        self.id = id
        self.value = value
        self.sourceMemoId = sourceMemoId
        self.sourceMemoTitle = sourceMemoTitle
        self.addedAt = addedAt
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
    /// 마지막 "사용" 시점. 편집과 구분하여 히어로 카드/최근 섹션/상대시간 라벨 등에 사용된다.
    /// Optional로 선언해 기존 memos.data와 하위 호환을 유지한다 (없으면 lastEdited 폴백).
    var lastUsedAt: Date?

    // New features
    var category: String = "기본"
    var isSecure: Bool = false
    var templateVariables: [String] = []
    /// 템플릿 여부(계산형) — 본문에 {변수}가 있으면(=templateVariables 비어있지 않으면) 템플릿.
    /// 별도 토글/타입 없이 "변수 있으면 템플릿"으로 자동 판정.
    var isTemplate: Bool { !templateVariables.isEmpty }

    // 템플릿의 플레이스홀더 값들 저장 (예: {이름}: [유미, 주디, 리이오])
    var placeholderValues: [String: [String]] = [:]

    /// 콤보 = 메모 안의 순서 있는 텍스트 단계들("이어지는 메모"). 비어있지 않으면 콤보.
    /// (출시본 4.3.x에도 있던 필드 — 기존 인라인 콤보 데이터와 그대로 호환.)
    var comboValues: [String] = []
    /// 콤보 순차 입력 시 단계 간 시간 간격(초).
    var comboInterval: TimeInterval = 2.0
    /// 콤보 여부(계산형) — 단계가 하나라도 있으면 콤보.
    var isCombo: Bool { !comboValues.isEmpty }
    /// (레거시) 콤보=자식 메모 참조. 마이그레이션 디코드용으로만 보관. 신규 로직 미사용.
    var childMemoIds: [UUID] = []

    // 자동 분류 관련 (Phase 1 추가)
    var autoDetectedType: ClipboardItemType?

    // 이미지 지원
    var imageFileName: String? // 단일 이미지 (하위 호환성)
    var imageFileNames: [String] = [] // 다중 이미지 지원
    var contentType: ClipboardContentType = .text // 콘텐츠 타입

    /// "어디서 / 언제 쓰나요?" 컨텍스트 힌트.
    /// ADHD·건망증 사용자가 나중에 이 메모를 왜 저장했는지 떠올릴 수 있도록 돕는다.
    /// 값이 있으면 카드 내용 힌트(자동 요약 대신)로도 쓰인다.
    /// Optional이라 기존 데이터와 완전 하위 호환 (없으면 nil).
    var hint: String?
    /// 힌트를 키보드에서도 표시할지 — ON이면 키보드 셀의 "표시할 이름"이 잠시 힌트로
    /// 바뀌었다 돌아온다(동기화). hint가 비어있으면 무의미. 기본 ON.
    var hintShownOnKeyboard: Bool = true

    init(id: UUID = UUID(), title: String, value: String, isChecked: Bool = false, lastEdited: Date = Date(), isFavorite: Bool = false, category: String = "기본", isSecure: Bool = false, templateVariables: [String] = [], placeholderValues: [String: [String]] = [:], comboValues: [String] = [], comboInterval: TimeInterval = 2.0, autoDetectedType: ClipboardItemType? = nil, imageFileName: String? = nil, imageFileNames: [String] = [], contentType: ClipboardContentType = .text, lastUsedAt: Date? = nil, hint: String? = nil, hintShownOnKeyboard: Bool = true) {
        self.id = id
        self.title = title
        self.value = value
        self.isChecked = isChecked
        self.lastEdited = lastEdited
        self.isFavorite = isFavorite
        self.category = category
        self.isSecure = isSecure
        self.templateVariables = templateVariables
        self.placeholderValues = placeholderValues
        self.comboValues = comboValues
        self.comboInterval = comboInterval
        self.autoDetectedType = autoDetectedType
        self.imageFileName = imageFileName
        self.imageFileNames = imageFileNames
        self.contentType = contentType
        self.lastUsedAt = lastUsedAt
        self.hint = hint
        self.hintShownOnKeyboard = hintShownOnKeyboard
    }

    init(from oldMemo: OldMemo) {
        self.id = oldMemo.id
        self.title = oldMemo.title
        self.value = oldMemo.value
        self.isChecked = oldMemo.isChecked
        self.lastEdited = Date() // 새로운 버전에서 추가된 속성 초기화
        self.isFavorite = false
    }

    /// 관용적 디코더 — 모든 필드를 `decodeIfPresent` + 기본값으로 읽는다.
    /// ⚠️ 매우 중요(하위호환): 합성 Codable은 CodingKeys의 비옵셔널 키가 JSON에
    /// 없으면 `keyNotFound`를 던져 **[Memo] 배열 전체 디코딩이 실패**한다. 그러면
    /// load 폴백이 OldMemo(title/value만)로 떨어져 카테고리·즐겨찾기·콤보 등이
    /// 통째로 사라진다. 신규 키(childMemoIds, comboValues, comboInterval 등)가
    /// 없던 구버전 memos.data도 안전하게 디코딩되도록 누락 키를 모두 허용한다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.value = try c.decodeIfPresent(String.self, forKey: .value) ?? ""
        self.isChecked = try c.decodeIfPresent(Bool.self, forKey: .isChecked) ?? false
        self.lastEdited = try c.decodeIfPresent(Date.self, forKey: .lastEdited) ?? Date()
        self.isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        self.clipCount = try c.decodeIfPresent(Int.self, forKey: .clipCount) ?? 0
        self.lastUsedAt = try c.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        self.category = try c.decodeIfPresent(String.self, forKey: .category) ?? "기본"
        self.isSecure = try c.decodeIfPresent(Bool.self, forKey: .isSecure) ?? false
        self.templateVariables = try c.decodeIfPresent([String].self, forKey: .templateVariables) ?? []
        self.placeholderValues = try c.decodeIfPresent([String: [String]].self, forKey: .placeholderValues) ?? [:]
        self.comboValues = try c.decodeIfPresent([String].self, forKey: .comboValues) ?? []
        self.comboInterval = try c.decodeIfPresent(TimeInterval.self, forKey: .comboInterval) ?? 2.0
        self.childMemoIds = try c.decodeIfPresent([UUID].self, forKey: .childMemoIds) ?? []
        self.autoDetectedType = try c.decodeIfPresent(ClipboardItemType.self, forKey: .autoDetectedType)
        self.imageFileName = try c.decodeIfPresent(String.self, forKey: .imageFileName)
        self.imageFileNames = try c.decodeIfPresent([String].self, forKey: .imageFileNames) ?? []
        self.contentType = try c.decodeIfPresent(ClipboardContentType.self, forKey: .contentType) ?? .text
        self.hint = try c.decodeIfPresent(String.self, forKey: .hint)
        self.hintShownOnKeyboard = try c.decodeIfPresent(Bool.self, forKey: .hintShownOnKeyboard) ?? true
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
        case templateVariables
        case placeholderValues
        case comboValues
        case childMemoIds
        case comboInterval
        case autoDetectedType
        case imageFileName
        case imageFileNames
        case contentType
        case lastUsedAt
        case hint
        case hintShownOnKeyboard
    }

    /// ⚠️ 하위호환(다운그레이드 안전): 구버전(4.3.0 이하)의 **합성** Codable 디코더는
    /// `isTemplate`/`isCombo`/`currentComboIndex`(비옵셔널) 키가 JSON에 없으면 keyNotFound를
    /// 던져 `[Memo]` 디코딩이 통째로 실패하고, OldMemo(title/value만) 폴백으로 카테고리·
    /// 즐겨찾기·콤보가 전멸한다. 4.3.1에서 이 키들을 stored→계산형으로 바꾸며 인코딩에서
    /// 누락시킨 것이 원인. 계산형 값을 레거시 키로도 함께 써서 구버전이 안전하게 읽게 한다.
    /// (attachedTemplateId는 Optional이라 구버전이 누락을 허용 → 생략.)
    private enum LegacyCompatKeys: String, CodingKey {
        case isTemplate
        case isCombo
        case currentComboIndex
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(value, forKey: .value)
        try c.encode(isChecked, forKey: .isChecked)
        try c.encode(lastEdited, forKey: .lastEdited)
        try c.encode(isFavorite, forKey: .isFavorite)
        try c.encode(clipCount, forKey: .clipCount)
        try c.encode(category, forKey: .category)
        try c.encode(isSecure, forKey: .isSecure)
        try c.encode(templateVariables, forKey: .templateVariables)
        try c.encode(placeholderValues, forKey: .placeholderValues)
        try c.encode(comboValues, forKey: .comboValues)
        try c.encode(childMemoIds, forKey: .childMemoIds)
        try c.encode(comboInterval, forKey: .comboInterval)
        try c.encodeIfPresent(autoDetectedType, forKey: .autoDetectedType)
        try c.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try c.encode(imageFileNames, forKey: .imageFileNames)
        try c.encode(contentType, forKey: .contentType)
        try c.encodeIfPresent(lastUsedAt, forKey: .lastUsedAt)
        try c.encodeIfPresent(hint, forKey: .hint)
        try c.encode(hintShownOnKeyboard, forKey: .hintShownOnKeyboard)

        // 레거시 키도 함께 기록 — 구버전 디코더가 필수로 요구하는 키.
        var legacy = encoder.container(keyedBy: LegacyCompatKeys.self)
        try legacy.encode(isTemplate, forKey: .isTemplate)
        try legacy.encode(isCombo, forKey: .isCombo)
        try legacy.encode(0, forKey: .currentComboIndex)
    }

    static var dummyData: [Memo] = {
        let date = dateFormatter.date(from: "2023-08-31 10:00:00") ?? Date()
        return [
            Memo(title: "계좌번호",
                 value: "123412341234123412341234123412341234123412341234",
                 lastEdited: date),
            Memo(title: "부모님 댁 주소",
                 value: "거기 어딘가",
                 lastEdited: date),
            Memo(title: "통관번호",
                 value: "p12341234",
                 lastEdited: date)
        ]
    }()
}

// MARK: - Combo System (Phase 2)

// Combo Item Type - 어떤 종류의 항목인지
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
