//
//  CategorySyncCoreTests.swift
//  ClipKeyboardTests
//
//  카테고리 하나에 레코드 하나로 옮긴 동기화 규칙.
//  예전 방식(목록 한 덩어리, 더하기만)으로는 삭제와 이름 변경이 기기 사이에 갈 수 없었다.
//  여기서는 그 둘이 가고, 지운 것이 되살아나지 않고, 두 기기가 같은 결론에 닿는지를 본다.
//

import Testing
import Foundation
@testable import ClipKeyboard

struct CategorySyncCoreTests {

    private let t0 = Date(timeIntervalSince1970: 0)
    private let t100 = Date(timeIntervalSince1970: 100)
    private let t200 = Date(timeIntervalSince1970: 200)
    private let t300 = Date(timeIntervalSince1970: 300)

    private func item(_ name: String, id: UUID = UUID(), order: Double = 0, hidden: Bool = false,
                      created: Date? = nil, edited: Date, deleted: Date? = nil) -> CategoryItem {
        CategoryItem(id: id, name: name, order: order, icon: nil, colorHex: nil, isHidden: hidden,
                     createdAt: created ?? edited, lastEdited: edited, deletedAt: deleted)
    }

    private func snapshot(_ names: [String], hidden: [String] = [], icons: [String: String] = [:]) -> CategorySnapshot {
        CategorySnapshot(categories: names, icons: icons, hiddenTabs: hidden)
    }

    private let everything: (String) -> Bool = { _ in true }

    // MARK: - 열쇠 → 항목

    @Test("목록에 새로 생긴 이름은 항목이 되고, 사라진 이름은 지운 것으로 표시된다")
    func refreshCreatesAndDeletes() {
        let a = item("업무", edited: t100)
        let result = CategorySyncCore.refresh(items: [a.id: a], from: snapshot(["여행"]),
                                              eligible: everything, migrating: false, now: t200)
        #expect(result[a.id]?.deletedAt == t200)
        let alive = result.values.filter { !$0.isDeleted }
        #expect(alive.map(\.name) == ["여행"])
        #expect(alive.first?.lastEdited == t200)
    }

    @Test("내용이 같으면 수정 시각을 건드리지 않는다")
    func refreshIsStableWhenUnchanged() {
        let a = item("업무", order: 0, edited: t100)
        let result = CategorySyncCore.refresh(items: [a.id: a], from: snapshot(["업무"]),
                                              eligible: everything, migrating: false, now: t200)
        #expect(result[a.id] == a)
    }

    @Test("숨김·순서·아이콘이 바뀌면 수정 시각이 오른다")
    func refreshDetectsFieldChanges() {
        let a = item("업무", order: 0, edited: t100)
        let result = CategorySyncCore.refresh(items: [a.id: a],
                                              from: snapshot(["업무"], hidden: ["업무"], icons: ["업무": "star"]),
                                              eligible: everything, migrating: false, now: t200)
        #expect(result[a.id]?.isHidden == true)
        #expect(result[a.id]?.icon == "star")
        #expect(result[a.id]?.lastEdited == t200)
    }

    @Test("자격 없는 이름(페르소나가 숨겨 심은 빈 카테고리)은 항목으로 만들지 않는다")
    func refreshSkipsIneligible() {
        let result = CategorySyncCore.refresh(items: [:], from: snapshot(["Work Email"], hidden: ["Work Email"]),
                                              eligible: { _ in false }, migrating: false, now: t200)
        #expect(result.isEmpty)
    }

    @Test("보호 이름(기본·텍스트·이미지)은 항목으로 만들지 않는다")
    func refreshSkipsProtected() {
        let result = CategorySyncCore.refresh(items: [:], from: snapshot(["기본", "업무"]),
                                              eligible: everything, migrating: false, now: t200)
        #expect(result.values.map(\.name) == ["업무"])
    }

    // MARK: - 처음 옮기기

    @Test("두 기기가 같은 이름을 옮기면 같은 id 가 된다")
    func migrationIDsAgree() {
        let one = CategorySyncCore.refresh(items: [:], from: snapshot(["업무"]),
                                           eligible: everything, migrating: true, now: t200)
        let two = CategorySyncCore.refresh(items: [:], from: snapshot(["업무", "여행"]),
                                           eligible: everything, migrating: true, now: t300)
        #expect(Set(one.keys).isSubset(of: Set(two.keys)))
    }

    @Test("옮긴 항목은 어떤 원격 기록에도 진다 - 다른 기기에서 지운 카테고리를 되살리지 않는다")
    func migratedItemLosesToRemoteDeletion() {
        let migrated = CategorySyncCore.refresh(items: [:], from: snapshot(["업무"]),
                                                eligible: everything, migrating: true, now: t200)
        let id = CategorySyncCore.nameBasedID("업무")
        let remoteDeleted = item("업무", id: id, created: t0, edited: t100, deleted: t100)

        let merged = CategorySyncCore.merge(local: migrated, remote: [remoteDeleted])

        #expect(merged.items[id]?.isDeleted == true)
        #expect(merged.toReupload.isEmpty)
    }

    // MARK: - 병합

    @Test("이름 변경이 전파된다 - id 가 같으니 새 이름이 옛 이름을 대신한다")
    func renamePropagates() {
        let id = UUID()
        let local = item("업무", id: id, edited: t100)
        let remote = item("회사", id: id, created: t100, edited: t200)

        let merged = CategorySyncCore.merge(local: [id: local], remote: [remote])
        let projected = CategorySyncCore.project(merged.items, onto: snapshot(["업무"]), formerNames: ["업무"])

        #expect(projected.categories == ["회사"])
        // 되쓴 뒤 다시 읽어도 옛 이름이 새 카테고리로 살아나지 않는다.
        let again = CategorySyncCore.refresh(items: merged.items, from: projected,
                                             eligible: everything, migrating: false, now: t300)
        #expect(again.values.filter { !$0.isDeleted }.map(\.name) == ["회사"])
    }

    @Test("삭제가 전파된다")
    func deletionPropagates() {
        let id = UUID()
        let local = item("업무", id: id, edited: t100)
        let remote = item("업무", id: id, created: t100, edited: t200, deleted: t200)

        let merged = CategorySyncCore.merge(local: [id: local], remote: [remote])
        let projected = CategorySyncCore.project(merged.items, onto: snapshot(["업무", "여행"]))

        #expect(projected.categories == ["여행"])
    }

    @Test("로컬이 더 최신이면 유지하고 다시 올린다")
    func newerLocalWinsAndReuploads() {
        let id = UUID()
        let local = item("회사", id: id, edited: t300)
        let remote = item("업무", id: id, created: t100, edited: t200)

        let merged = CategorySyncCore.merge(local: [id: local], remote: [remote])

        #expect(merged.items[id]?.name == "회사")
        #expect(merged.toReupload == [id])
    }

    @Test("제 사본을 되받으면 아무것도 하지 않는다")
    func echoIsIgnored() {
        let a = item("업무", edited: t100)
        let merged = CategorySyncCore.merge(local: [a.id: a], remote: [a])
        #expect(merged.items[a.id] == a)
        #expect(merged.toReupload.isEmpty)
    }

    @Test("시각이 같아도 어느 기기에서 계산하든 같은 승자")
    func tieIsDeterministic() {
        let id = UUID()
        let x = item("가", id: id, created: t0, edited: t100)
        let y = item("나", id: id, created: t0, edited: t100)
        let onX = CategorySyncCore.merge(local: [id: x], remote: [y]).items[id]
        let onY = CategorySyncCore.merge(local: [id: y], remote: [x]).items[id]
        #expect(onX == onY)
    }

    // MARK: - 이름 겹침

    @Test("같은 이름이 둘이면 먼저 만든 것만 남고, 두 순서 모두 같은 쪽이 남는다")
    func dedupeKeepsOldest() {
        let old = item("업무", created: t100, edited: t100)
        let new = item("업무", created: t200, edited: t200)

        let forward = CategorySyncCore.dedupe([old.id: old, new.id: new], now: t300)
        let backward = CategorySyncCore.dedupe([new.id: new, old.id: old], now: t300)

        #expect(forward.items[old.id]?.isDeleted == false)
        #expect(forward.items[new.id]?.isDeleted == true)
        #expect(forward.items == backward.items)
        #expect(forward.changed.contains(new.id))
    }

    @Test("지는 쪽의 아이콘을 남는 쪽이 넘겨받는다")
    func dedupeCarriesIcon() {
        let old = item("업무", created: t100, edited: t100)
        var new = item("업무", created: t200, edited: t200)
        new.icon = "briefcase"

        let result = CategorySyncCore.dedupe([old.id: old, new.id: new], now: t300)

        #expect(result.items[old.id]?.icon == "briefcase")
        #expect(result.changed.contains(old.id))
    }

    // MARK: - 항목 → 열쇠

    @Test("되쓰기는 항목이 모르는 이름과 즐겨찾기 숨김을 지키고, 순서는 항목을 따른다")
    func projectKeepsUnknownNames() {
        let a = item("업무", order: 1, edited: t100)
        let b = item("여행", order: 0, hidden: true, edited: t100)
        let current = CategorySnapshot(categories: ["업무", "Work Email", "여행"],
                                       hiddenTabs: [CategoryBucketRule.favoritesTabKey, "Work Email"])

        let projected = CategorySyncCore.project([a.id: a, b.id: b], onto: current)

        #expect(projected.categories == ["여행", "업무", "Work Email"])
        #expect(Set(projected.hiddenTabs) == [CategoryBucketRule.favoritesTabKey, "Work Email", "여행"])
    }

    @Test("되쓴 결과를 다시 읽으면 바뀐 것이 없다 - 받자마자 되올리는 핑퐁이 없다")
    func projectThenRefreshIsStable() {
        let a = item("업무", order: 0, edited: t100)
        let b = item("여행", order: 1, hidden: true, edited: t100)
        let items = [a.id: a, b.id: b]

        let projected = CategorySyncCore.project(items, onto: CategorySnapshot())
        let again = CategorySyncCore.refresh(items: items, from: projected,
                                             eligible: everything, migrating: false, now: t300)

        #expect(again == items)
    }
}
