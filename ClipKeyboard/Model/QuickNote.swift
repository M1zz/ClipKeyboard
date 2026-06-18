//
//  QuickNote.swift
//  ClipKeyboard
//
//  빠른 메모(Quick Note) — 애플 메모앱의 "빠른 메모"처럼 어디서든 빠르게 던져 넣고,
//  나중에 "이걸 키보드 메모로 쓸지"를 결정하는 결정-보류 보관함(Inbox) 항목.
//
//  · 정식 Memo 와 분리된 별도 저장소(StorageFile.quickNotes)에 보관한다.
//  · 사용자가 "메모로 저장"을 누르면 toMemo() 로 Memo 를 만들어 승격하고 원본은 삭제한다.
//  · 자동 만료 없음 — 사용자가 직접 분류/삭제하기 전까지 계속 보관된다.
//
//  ⚠️ 공유 익스텐션·App Intent 등 앱 코드를 공유하지 않는 타겟이 raw JSON 으로 직접
//     append 하므로, JSON 스키마(키 이름·타입)가 이 Codable 과 정확히 일치해야 한다.
//     특히 createdAt 은 Date 인코딩 전략 모호성을 피하려고 epoch 초(Double)로 고정한다.
//

import Foundation

struct QuickNote: Identifiable, Codable {
    var id = UUID()

    /// 본문 텍스트(이미지 전용 캡처면 빈 문자열일 수 있음).
    var text: String = ""

    /// App Group `Images/` 폴더에 저장된 이미지 파일명들(메모와 동일 규약).
    /// 승격 시 파일을 그대로 두고 Memo 가 같은 파일명을 참조한다(재인코딩/이동 없음).
    var imageFileNames: [String] = []

    /// 콘텐츠 타입(텍스트/이미지/혼합).
    var contentType: ClipboardContentType = .text

    /// 생성 시점. epoch 초(timeIntervalSince1970)로 저장해 raw-JSON 타겟과 표현을 일치시킨다.
    var createdAt: Date = Date()

    /// 어떤 진입점에서 담겼는지("share" | "shortcut" | "control" | "manual"). 분석/표시용.
    var source: String = "manual"

    /// 캡처를 만든 앱 이름(공유 익스텐션 등에서 알 수 있으면). 표시용.
    var sourceApp: String?

    /// 승격 시 제안할 제목(없으면 본문 첫 줄에서 유도).
    var suggestedTitle: String?

    /// 승격 시 제안할 카테고리(없으면 "기본").
    var suggestedCategory: String?

    init(id: UUID = UUID(),
         text: String = "",
         imageFileNames: [String] = [],
         contentType: ClipboardContentType = .text,
         createdAt: Date = Date(),
         source: String = "manual",
         sourceApp: String? = nil,
         suggestedTitle: String? = nil,
         suggestedCategory: String? = nil) {
        self.id = id
        self.text = text
        self.imageFileNames = imageFileNames
        self.contentType = contentType
        self.createdAt = createdAt
        self.source = source
        self.sourceApp = sourceApp
        self.suggestedTitle = suggestedTitle
        self.suggestedCategory = suggestedCategory
    }

    // MARK: - Codable (관용 디코더)
    //
    // 누락 키를 모두 허용해 raw-JSON(공유 익스텐션 등)이나 향후 스키마 변화에도 안전하게 읽는다.
    // createdAt 은 epoch 초(Double)로 읽되, 혹시 Date 로 인코딩된 값도 폴백 허용한다.

    enum CodingKeys: String, CodingKey {
        case id, text, imageFileNames, contentType, createdAt, source, sourceApp, suggestedTitle, suggestedCategory
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        self.imageFileNames = try c.decodeIfPresent([String].self, forKey: .imageFileNames) ?? []
        self.contentType = try c.decodeIfPresent(ClipboardContentType.self, forKey: .contentType) ?? .text
        if let epoch = try? c.decodeIfPresent(Double.self, forKey: .createdAt) {
            self.createdAt = Date(timeIntervalSince1970: epoch)
        } else if let date = try? c.decodeIfPresent(Date.self, forKey: .createdAt) {
            self.createdAt = date
        } else {
            self.createdAt = Date()
        }
        self.source = try c.decodeIfPresent(String.self, forKey: .source) ?? "manual"
        self.sourceApp = try c.decodeIfPresent(String.self, forKey: .sourceApp)
        self.suggestedTitle = try c.decodeIfPresent(String.self, forKey: .suggestedTitle)
        self.suggestedCategory = try c.decodeIfPresent(String.self, forKey: .suggestedCategory)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(text, forKey: .text)
        try c.encode(imageFileNames, forKey: .imageFileNames)
        try c.encode(contentType, forKey: .contentType)
        try c.encode(createdAt.timeIntervalSince1970, forKey: .createdAt)
        try c.encode(source, forKey: .source)
        try c.encodeIfPresent(sourceApp, forKey: .sourceApp)
        try c.encodeIfPresent(suggestedTitle, forKey: .suggestedTitle)
        try c.encodeIfPresent(suggestedCategory, forKey: .suggestedCategory)
    }

    // MARK: - Derived

    var hasImages: Bool { !imageFileNames.isEmpty }

    /// 보관함 셀에 보여줄 미리보기용 제목(제안 제목 우선, 없으면 본문 첫 줄 유도).
    var displayTitle: String {
        if let t = suggestedTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return t
        }
        return Self.deriveTitle(from: text, hasImage: hasImages)
    }

    /// 본문에서 제목을 유도한다(첫 줄, 30자 제한). 이미지 전용이면 "이미지" 라벨.
    static func deriveTitle(from text: String, hasImage: Bool) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return hasImage
                ? NSLocalizedString("Image", comment: "Default title for image quick note")
                : NSLocalizedString("Quick Note", comment: "Default title for empty quick note")
        }
        let firstLine = trimmed.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? trimmed
        return firstLine.count <= 30 ? firstLine : String(firstLine.prefix(27)) + "…"
    }

    /// 보류 항목을 정식 Memo 로 승격한다(키보드 메모로 사용 가능).
    func toMemo() -> Memo {
        Memo(
            title: displayTitle,
            value: text,
            category: suggestedCategory?.isEmpty == false ? suggestedCategory! : "기본",
            imageFileNames: imageFileNames,
            contentType: contentType
        )
    }
}
