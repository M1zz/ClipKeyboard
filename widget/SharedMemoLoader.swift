//
//  SharedMemoLoader.swift
//  widget
//
//  Loads favorite memos from the shared App Group container.
//

import Foundation

// MARK: - Widget용 경량 Memo 모델

/// 위젯에서 사용하는 경량 메모 구조체
/// 메인 앱의 Memo와 동일한 CodingKeys를 사용하여 디코딩 호환
struct WidgetMemo: Identifiable, Codable {
    var id: UUID
    var title: String
    var value: String
    var isFavorite: Bool
    var lastEdited: Date
    var category: String
    var isSecure: Bool

    // 위젯에서 불필요한 필드는 기본값으로 디코딩
    var isChecked: Bool = false
    var clipCount: Int = 0
    var isTemplate: Bool = false
    var templateVariables: [String] = []
    var placeholderValues: [String: [String]] = [:]
    var isCombo: Bool = false
    var comboValues: [String] = []
    var currentComboIndex: Int = 0
    var imageFileName: String?
    var imageFileNames: [String] = []

    enum CodingKeys: String, CodingKey {
        case id, title, value, isFavorite, lastEdited, category, isSecure
        case isChecked, clipCount, isTemplate, templateVariables, placeholderValues
        case isCombo, comboValues, currentComboIndex
        case imageFileName, imageFileNames
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        value = try container.decode(String.self, forKey: .value)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        lastEdited = try container.decodeIfPresent(Date.self, forKey: .lastEdited) ?? Date()
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "기본"
        isSecure = try container.decodeIfPresent(Bool.self, forKey: .isSecure) ?? false
        isChecked = try container.decodeIfPresent(Bool.self, forKey: .isChecked) ?? false
        clipCount = try container.decodeIfPresent(Int.self, forKey: .clipCount) ?? 0
        isTemplate = try container.decodeIfPresent(Bool.self, forKey: .isTemplate) ?? false
        templateVariables = try container.decodeIfPresent([String].self, forKey: .templateVariables) ?? []
        placeholderValues = try container.decodeIfPresent([String: [String]].self, forKey: .placeholderValues) ?? [:]
        isCombo = try container.decodeIfPresent(Bool.self, forKey: .isCombo) ?? false
        comboValues = try container.decodeIfPresent([String].self, forKey: .comboValues) ?? []
        currentComboIndex = try container.decodeIfPresent(Int.self, forKey: .currentComboIndex) ?? 0
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        imageFileNames = try container.decodeIfPresent([String].self, forKey: .imageFileNames) ?? []
    }
}

// MARK: - Shared Memo Loader

struct SharedMemoLoader {
    static let appGroupID = "group.com.Ysoup.TokenMemo"

    /// App Group 컨테이너에서 전체 메모를 로드
    static func loadAllMemos() -> [WidgetMemo] {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            print("❌ [Widget] App Group 컨테이너를 찾을 수 없음")
            return []
        }

        let fileURL = containerURL.appendingPathComponent("memos.data")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("⚠️ [Widget] memos.data 파일 없음")
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let memos = try JSONDecoder().decode([WidgetMemo].self, from: data)
            print("✅ [Widget] 메모 \(memos.count)개 로드")
            return memos
        } catch {
            print("❌ [Widget] 메모 디코딩 실패: \(error)")
            return []
        }
    }

    /// 즐겨찾기 메모만 로드 (보안 메모 제외)
    static func loadFavoriteMemos() -> [WidgetMemo] {
        return loadAllMemos().filter { $0.isFavorite && !$0.isSecure }
    }

    /// 특정 ID의 메모 로드
    static func loadMemo(id: UUID) -> WidgetMemo? {
        return loadAllMemos().first { $0.id == id }
    }
}
