//
//  CategorySnapshotTests.swift
//  ClipKeyboardTests
//
//  카테고리가 백업·동기화를 타고 새 기기로 넘어가는 경로를 고정한다.
//
//  원래 사고: 카테고리 목록은 App Group UserDefaults 에만 있어서 백업·동기화 어디에도
//  실리지 않았다. 새 기기에서 복원하면 메모는 다 살아나는데 카테고리 탭이 전부 사라졌다.
//  여기서 지켜야 하는 성질은 두 가지다:
//   ① 있는 걸 옮긴다 - 목록·아이콘·순서·숨김이 스냅샷에 담기고 그대로 복원된다
//   ② **없는 걸로 있는 걸 지우지 않는다** - 빈 스냅샷이 기존 설정을 날리면 더 큰 사고다
//

import XCTest
@testable import ClipKeyboard

final class CategorySnapshotTests: XCTestCase {

    private var defaults: UserDefaults!

    private var allKeys: [String] {
        [CategorySnapshotStore.categoriesKey, CategorySnapshotStore.iconsKey,
         CategorySnapshotStore.hiddenTabsKey, CategorySnapshotStore.enabledBuiltInsKey,
         CategorySnapshotStore.featureEnabledKey]
    }

    override func setUp() {
        super.setUp()
        defaults = AppGroup.defaults
        allKeys.forEach { defaults.removeObject(forKey: $0) }
    }

    override func tearDown() {
        allKeys.forEach { defaults.removeObject(forKey: $0) }
        super.tearDown()
    }

    // MARK: - 직렬화

    /// 스냅샷이 왕복해도 순서·아이콘·숨김이 그대로여야 한다.
    /// 순서가 곧 탭 순서라 배열 순서를 잃으면 사용자 눈에는 "뒤죽박죽 복원"이다.
    func testSnapshotRoundTripsPreservingOrder() throws {
        let original = CategorySnapshot(
            categories: ["업무", "개인", "쇼핑"],
            icons: ["업무": "briefcase", "개인": "person"],
            hiddenTabs: ["쇼핑"],
            enabledBuiltIns: ["email"],
            featureEnabled: true
        )

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(CategorySnapshot.self, from: data)

        XCTAssertEqual(restored.categories, ["업무", "개인", "쇼핑"], "순서가 유지돼야 한다")
        XCTAssertEqual(restored.icons["업무"], "briefcase")
        XCTAssertEqual(restored.hiddenTabs, ["쇼핑"])
        XCTAssertEqual(restored.enabledBuiltIns, ["email"])
        XCTAssertTrue(restored.featureEnabled)
    }

    /// 구버전이 만든(필드가 빠진) JSON도 읽혀야 한다 - 다운그레이드·상위호환 대비.
    func testDecodesSnapshotWithMissingFields() throws {
        let json = #"{"categories":["업무"]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let snapshot = try JSONDecoder().decode(CategorySnapshot.self, from: data)

        XCTAssertEqual(snapshot.categories, ["업무"])
        XCTAssertTrue(snapshot.icons.isEmpty)
        XCTAssertFalse(snapshot.featureEnabled)
    }

    // MARK: - 적용

    func testCurrentReadsFromDefaults() {
        defaults.set(["업무", "개인"], forKey: CategorySnapshotStore.categoriesKey)
        defaults.set(["업무": "briefcase"], forKey: CategorySnapshotStore.iconsKey)

        let snapshot = CategorySnapshotStore.current()

        XCTAssertEqual(snapshot.categories, ["업무", "개인"])
        XCTAssertEqual(snapshot.icons["업무"], "briefcase")
    }

    /// 복원(.replace)은 순서까지 스냅샷 기준으로 맞춘다.
    func testApplyReplaceOverwritesOrder() {
        defaults.set(["쇼핑"], forKey: CategorySnapshotStore.categoriesKey)
        let snapshot = CategorySnapshot(categories: ["업무", "개인"], featureEnabled: true)

        CategorySnapshotStore.apply(snapshot, strategy: .replace)

        XCTAssertEqual(defaults.stringArray(forKey: CategorySnapshotStore.categoriesKey), ["업무", "개인"])
    }

    /// 동기화(.merge)는 이 기기에만 있는 카테고리를 지우지 않는다.
    func testApplyMergeKeepsLocalOnlyCategories() {
        defaults.set(["로컬전용"], forKey: CategorySnapshotStore.categoriesKey)
        let snapshot = CategorySnapshot(categories: ["업무"], featureEnabled: true)

        CategorySnapshotStore.apply(snapshot, strategy: .merge)

        let result = defaults.stringArray(forKey: CategorySnapshotStore.categoriesKey) ?? []
        XCTAssertTrue(result.contains("로컬전용"), "원격에 없다고 로컬 카테고리를 지우면 안 된다")
        XCTAssertTrue(result.contains("업무"))
    }

    /// 병합 시 중복이 쌓이지 않아야 한다(동기화가 반복돼도 목록이 늘어나면 안 됨).
    func testApplyMergeIsIdempotent() {
        let snapshot = CategorySnapshot(categories: ["업무", "개인"], featureEnabled: true)

        CategorySnapshotStore.apply(snapshot, strategy: .merge)
        CategorySnapshotStore.apply(snapshot, strategy: .merge)

        XCTAssertEqual(defaults.stringArray(forKey: CategorySnapshotStore.categoriesKey), ["업무", "개인"])
    }

    /// ⚠️ 핵심 안전장치: **빈 스냅샷은 아무것도 지우지 않는다.**
    func testEmptySnapshotDoesNotWipeExisting() {
        defaults.set(["소중한카테고리"], forKey: CategorySnapshotStore.categoriesKey)

        CategorySnapshotStore.apply(CategorySnapshot(), strategy: .replace)

        XCTAssertEqual(defaults.stringArray(forKey: CategorySnapshotStore.categoriesKey), ["소중한카테고리"])
    }

    /// 카테고리가 복원되면 기능도 켜 준다 - 꺼져 있으면 탭이 안 보여 "복원 실패"로 보인다.
    func testApplyEnablesFeatureWhenCategoriesExist() {
        CategorySnapshotStore.apply(CategorySnapshot(categories: ["업무"]), strategy: .replace)

        XCTAssertTrue(defaults.bool(forKey: CategorySnapshotStore.featureEnabledKey))
    }

    // MARK: - 옛 백업 구제 (메모에서 역산)

    private func memo(_ title: String, category: String) -> Memo {
        var m = Memo(title: title, value: "v")
        m.category = category
        return m
    }

    /// 카테고리 정보가 없는 옛 백업 → 메모의 category 값에서 이름을 되살린다.
    func testRebuildFromMemosRecoversNames() {
        let memos = [memo("a", category: "업무"), memo("b", category: "개인"), memo("c", category: "업무")]

        let added = CategorySnapshotStore.rebuildFromMemos(memos)

        XCTAssertEqual(added, ["업무", "개인"], "등장 순서를 유지하고 중복은 제거한다")
        XCTAssertTrue(defaults.bool(forKey: CategorySnapshotStore.featureEnabledKey))
    }

    /// "기본"은 시스템 기본값이라 사용자 정의 목록에 넣지 않는다.
    func testRebuildSkipsDefaultCategory() {
        let added = CategorySnapshotStore.rebuildFromMemos([memo("a", category: "기본")])

        XCTAssertTrue(added.isEmpty)
    }

    /// 이미 있는 카테고리는 다시 추가하지 않는다.
    func testRebuildDoesNotDuplicateExisting() {
        defaults.set(["업무"], forKey: CategorySnapshotStore.categoriesKey)

        let added = CategorySnapshotStore.rebuildFromMemos([memo("a", category: "업무"), memo("b", category: "개인")])

        XCTAssertEqual(added, ["개인"])
        XCTAssertEqual(defaults.stringArray(forKey: CategorySnapshotStore.categoriesKey), ["업무", "개인"])
    }

    /// 복구할 게 없으면 아무것도 건드리지 않는다.
    func testRebuildWithNoCategoriesChangesNothing() {
        let added = CategorySnapshotStore.rebuildFromMemos([memo("a", category: "")])

        XCTAssertTrue(added.isEmpty)
        XCTAssertNil(defaults.stringArray(forKey: CategorySnapshotStore.categoriesKey))
    }

    // MARK: - 동기화 대상 추리기 (폰 2대·다국어 오염 방지)

    /// 온보딩 페르소나가 심은 카테고리는 **기기 언어별로 이름이 다르다**
    /// (회사 이메일 / Work Email). 안 쓰는 것까지 동기화하면 폰 2대에서 중복이 쌓인다.
    /// → 비샘플 메모가 붙은 카테고리만 동기화한다.
    func testSyncableKeepsOnlyCategoriesInUse() {
        defaults.set(["업무", "안쓰는시드"], forKey: CategorySnapshotStore.categoriesKey)
        defaults.set(["업무": "briefcase", "안쓰는시드": "star"], forKey: CategorySnapshotStore.iconsKey)

        let snapshot = CategorySnapshotStore.syncable(memos: [memo("a", category: "업무")], sampleIDs: [])

        XCTAssertEqual(snapshot.categories, ["업무"])
        XCTAssertNil(snapshot.icons["안쓰는시드"], "안 쓰는 카테고리의 아이콘도 함께 빠져야 한다")
    }

    /// 샘플 메모에만 붙은 카테고리는 동기화하지 않는다.
    /// 샘플은 기기 언어를 따라 심기므로 그대로 올리면 언어별 중복이 생긴다.
    func testSyncableExcludesCategoriesUsedOnlyBySamples() {
        defaults.set(["샘플전용"], forKey: CategorySnapshotStore.categoriesKey)
        let sample = memo("s", category: "샘플전용")

        let snapshot = CategorySnapshotStore.syncable(memos: [sample], sampleIDs: [sample.id])

        XCTAssertTrue(snapshot.categories.isEmpty)
    }

    /// 백업(`current`)은 전부 담는다 - "이 기기 상태를 그대로 되살리기"라
    /// 아직 안 쓴 카테고리도 남아야 한다. 동기화와 기준이 다르다.
    func testCurrentKeepsUnusedCategoriesForBackup() {
        defaults.set(["업무", "아직안씀"], forKey: CategorySnapshotStore.categoriesKey)

        XCTAssertEqual(CategorySnapshotStore.current().categories, ["업무", "아직안씀"])
    }
}
