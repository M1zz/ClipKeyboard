//
//  SyncBackwardCompatibilityTests.swift
//  ClipKeyboardTests
//
//  이미 나간 버전과의 약속. 한 계정에 옛 버전과 새 버전이 섞여 도는 동안 지켜져야 한다.
//
//  옛 버전이 동기화 구역(MemosZone)의 레코드를 다루는 방식:
//   - 엔진(iOS 4.3.3 부터 모든 버전, 맥 공유): 이름이 `category-settings` 면 카테고리 설정,
//     아니면 **이름이 UUID 가 아닐 때 건너뛴다.**
//   - 맥 5.1.4 "다시 받기"(MacSyncReset.plan): 종류가 `Memo` 이고 `deletedAt` 이 없으면
//     **이름을 보지 않고** 단축어 하나로 센다. 0개면 맥을 비우지 않는다.
//   - 맥 5.1.4 "지운 것 반영"(applyCloudDeletions): 종류 `Memo`, `deletedAt` 있음, 이름이 UUID.
//   - 맥 5.1.4 진단: 종류 `Memo` 를 단축어로, `CategorySettings` 를 "카테고리 설정 있음"으로 센다.
//  그리고 Production 스키마에 없는 필드는 저장이 거절된다.
//

import Testing
import Foundation
import CloudKit
@testable import ClipKeyboard

struct SyncBackwardCompatibilityTests {

    private let zoneID = CKRecordZone.ID(zoneName: MemoSyncEngine.zoneName, ownerName: CKCurrentUserDefaultName)

    private func sampleItem(deleted: Bool = false) -> CategoryItem {
        let now = Date(timeIntervalSince1970: 1_000)
        return CategoryItem(id: UUID(), name: "업무", order: 0, icon: "briefcase", colorHex: "#112233",
                            isHidden: false, createdAt: now, lastEdited: now, deletedAt: deleted ? now : nil)
    }

    /// 맥 5.1.4 "다시 받기"가 단축어로 세는 조건을 그대로 옮긴 것.
    private func oldMacCountsAsAliveMemo(_ record: CKRecord) -> Bool {
        record.recordType == MemoSyncEngine.recordType && record["deletedAt"] == nil
    }

    /// 모든 옛 엔진이 레코드를 단축어로 읽기 전에 거르는 조건.
    private func oldEngineSkips(_ record: CKRecord) -> Bool {
        record.recordID.recordName != MemoSyncEngine.categoryRecordName
            && UUID(uuidString: record.recordID.recordName) == nil
    }

    // MARK: - 카테고리 항목 레코드

    @Test("카테고리 항목 레코드는 옛 엔진이 건너뛰고, 맥 5.1.4 가 단축어로 세지 않는다", arguments: [false, true])
    func categoryItemRecordIsInvisibleToOldVersions(deleted: Bool) throws {
        let item = sampleItem(deleted: deleted)
        let recordID = CKRecord.ID(recordName: CategorySyncCore.recordName(item.id), zoneID: zoneID)
        let record = try #require(MemoSyncEngine.buildCategoryItemRecord(recordID, item: item, base: nil))

        #expect(oldEngineSkips(record))
        #expect(!oldMacCountsAsAliveMemo(record))
        #expect(record.recordType == MemoSyncEngine.categoryRecordType)
    }

    @Test("카테고리 항목 레코드는 Production 스키마에 이미 있는 필드만 쓴다")
    func categoryItemRecordUsesExistingFieldsOnly() throws {
        let item = sampleItem(deleted: true)
        let recordID = CKRecord.ID(recordName: CategorySyncCore.recordName(item.id), zoneID: zoneID)
        let record = try #require(MemoSyncEngine.buildCategoryItemRecord(recordID, item: item, base: nil))

        // `CategorySettings` 종류가 처음부터 쓰던 필드: payload, updatedAt
        #expect(Set(record.allKeys()).isSubset(of: ["payload", "updatedAt"]))
        // 삭제 표시와 수정 시각은 payload 안에 온전히 있다.
        let payload = try #require(record["payload"] as? Data)
        let decoded = try JSONDecoder().decode(CategoryItem.self, from: payload)
        #expect(decoded == item)
    }

    @Test("충돌 처리는 두 종류 레코드의 수정 시각을 모두 읽는다")
    func editedDateReadsBothKinds() {
        let memo = CKRecord(recordType: MemoSyncEngine.recordType)
        memo["lastEdited"] = Date(timeIntervalSince1970: 10) as CKRecordValue
        let category = CKRecord(recordType: MemoSyncEngine.categoryRecordType)
        category["updatedAt"] = Date(timeIntervalSince1970: 20) as CKRecordValue

        #expect(MemoSyncEngine.editedDate(of: memo) == Date(timeIntervalSince1970: 10))
        #expect(MemoSyncEngine.editedDate(of: category) == Date(timeIntervalSince1970: 20))
    }

    @Test("새 이름과 옛 이름(개발 빌드의 Memo 종류) 모두에서 같은 id 를 읽고, 둘 다 옛 엔진이 건너뛴다")
    func categoryRecordNamesAreReadableAndSkipped() {
        let id = UUID()
        for name in [CategorySyncCore.recordName(id), CategorySyncCore.legacyRecordName(id)] {
            #expect(CategorySyncCore.id(fromRecordName: name) == id)
            #expect(UUID(uuidString: name) == nil)
            #expect(name != MemoSyncEngine.categoryRecordName)
        }
        #expect(CategorySyncCore.recordName(id) != CategorySyncCore.legacyRecordName(id))
    }

    // MARK: - 동기화 표식

    @Test("표식 레코드 이름은 옛 엔진이 건너뛴다")
    func epochNameIsSkippedByOldEngines() {
        for name in [MemoSyncEngine.epochRecordName, MemoSyncEngine.legacyEpochRecordName] {
            #expect(UUID(uuidString: name) == nil)
            #expect(name != MemoSyncEngine.categoryRecordName)
        }
    }

    // MARK: - 저장 형식

    @Test("다른 버전이 만든 카테고리 항목도 읽는다 - 빠진 필드는 기본값, 모르는 필드는 무시")
    func categoryItemDecodingIsTolerant() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","name":"업무","someFutureField":42}
        """
        let item = try JSONDecoder().decode(CategoryItem.self, from: Data(json.utf8))
        #expect(item.id == id)
        #expect(item.name == "업무")
        #expect(item.isHidden == false)
        #expect(item.deletedAt == nil)
        #expect(item.lastEdited == Date(timeIntervalSince1970: 0))   // 어떤 기록에도 지는 시각
    }

    @Test("옛 백업(항목 없음)을 새 버전이 읽는다")
    func oldBackupDecodes() throws {
        let json = #"{"categories":["업무"],"icons":{"업무":"star"},"hiddenTabs":[],"featureEnabled":true}"#
        let snapshot = try JSONDecoder().decode(CategorySnapshot.self, from: Data(json.utf8))
        #expect(snapshot.categories == ["업무"])
        #expect(snapshot.items == nil)
    }

    /// 옛 버전의 스냅샷 디코더를 흉내 낸다 - 아는 키만 `decodeIfPresent` 로 읽는다.
    private struct OldCategorySnapshot: Decodable {
        let categories: [String]
        let icons: [String: String]
        enum CodingKeys: String, CodingKey { case categories, icons, colors, hiddenTabs, enabledBuiltIns, featureEnabled, updatedAt }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            categories = try c.decodeIfPresent([String].self, forKey: .categories) ?? []
            icons = try c.decodeIfPresent([String: String].self, forKey: .icons) ?? [:]
        }
    }

    @Test("새 백업(항목 포함)을 옛 버전이 읽는다")
    func newBackupDecodesInOldVersion() throws {
        let snapshot = CategorySnapshot(categories: ["업무"], icons: ["업무": "star"], items: [sampleItem()])
        let data = try JSONEncoder().encode(snapshot)
        let old = try JSONDecoder().decode(OldCategorySnapshot.self, from: data)
        #expect(old.categories == ["업무"])
        #expect(old.icons == ["업무": "star"])
    }

    @Test("항목이 없으면 백업에 items 키를 쓰지 않는다")
    func snapshotWithoutItemsOmitsKey() throws {
        let data = try JSONEncoder().encode(CategorySnapshot(categories: ["업무"]))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["items"] == nil)
    }
}
