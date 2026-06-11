//
//  CategorySidecarTests.swift
//  ClipKeyboardTests
//
//  Created by Claude Code on 2026-06-11.
//  카테고리 다운그레이드 안전장치(사이드카) 무결성 테스트.
//
//  시나리오: 카테고리 필드가 없는 구버전 앱이 memos.data를 재저장하면 category 키가
//  통째로 사라진다. 신버전은 App Group UserDefaults 사이드카([메모ID: 카테고리])에서
//  복원해야 한다. 이 안전망이 깨지면 다운그레이드→재업그레이드 시 전 메모가 "기본"으로
//  떨어지는 데이터 손실 사고가 난다.
//

import XCTest
@testable import ClipKeyboard

final class CategorySidecarTests: XCTestCase {

    var sut: MemoStore!

    private let sidecarKey = "memoCategoryAssignments_v1"
    private var groupDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")
    }
    private var memosFileURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo"
        )?.appendingPathComponent("memos.data")
    }

    override func setUp() {
        super.setUp()
        sut = MemoStore.shared
        try? sut.save(memos: [], type: .memo, recordHistory: false)
        groupDefaults?.removeObject(forKey: sidecarKey)
    }

    override func tearDown() {
        try? sut.save(memos: [], type: .memo, recordHistory: false)
        groupDefaults?.removeObject(forKey: sidecarKey)
        sut = nil
        super.tearDown()
    }

    /// 구버전 앱의 재저장을 시뮬레이션: save()를 거치지 않고(=사이드카 갱신 없이)
    /// category가 "기본"으로 떨어진 메모들을 memos.data에 직접 덮어쓴다.
    private func simulateDowngradeRewrite(of memos: [Memo]) throws {
        var stripped = memos
        for i in stripped.indices { stripped[i].category = "기본" }
        let data = try JSONEncoder().encode(stripped)
        try data.write(to: XCTUnwrap(memosFileURL))
    }

    // MARK: - 사이드카 기록 규칙

    func testSave_WritesNonDefaultCategoriesToSidecar() throws {
        // Given
        let travel = Memo(title: "여행 메모", value: "값", category: "여행")
        let basic = Memo(title: "기본 메모", value: "값", category: "기본")

        // When
        try sut.save(memos: [travel, basic], type: .memo)

        // Then — 비기본 카테고리만 사이드카에 기록 (기본은 제외)
        let map = try XCTUnwrap(groupDefaults?.dictionary(forKey: sidecarKey) as? [String: String])
        XCTAssertEqual(map[travel.id.uuidString], "여행")
        XCTAssertNil(map[basic.id.uuidString])
    }

    func testRestoreFromSidecar_FillsLostCategoriesOnly() {
        // Given — 사이드카엔 "여행", memos.data 쪽은 유실(기본)
        let lost = Memo(title: "유실됨", value: "값", category: "기본")
        let intact = Memo(title: "안 유실됨", value: "값", category: "금융")
        groupDefaults?.set([lost.id.uuidString: "여행",
                            intact.id.uuidString: "여행"], forKey: sidecarKey)

        // When
        var memos = [lost, intact]
        let changed = MemoStore.restoreCategoriesFromSidecar(&memos)

        // Then — 기본(유실 신호)만 복원, 사용자가 신버전에서 바꾼 "금융"은 보존
        XCTAssertTrue(changed)
        XCTAssertEqual(memos[0].category, "여행")
        XCTAssertEqual(memos[1].category, "금융", "비기본 카테고리는 사이드카가 덮어쓰면 안 됨")
    }

    func testRestoreFromSidecar_NoSidecar_ReturnsFalse() {
        // Given — 사이드카 없음
        var memos = [Memo(title: "메모", value: "값", category: "기본")]

        // When/Then
        XCTAssertFalse(MemoStore.restoreCategoriesFromSidecar(&memos))
        XCTAssertEqual(memos[0].category, "기본")
    }

    // MARK: - 다운그레이드 → 재업그레이드 왕복 (핵심 시나리오)

    func testDowngradeRewrite_ThenLoad_HealsCategoriesFromSidecar() throws {
        // Given — 신버전에서 카테고리 지정 저장 (사이드카 기록됨)
        let travel = Memo(title: "여행", value: "값", category: "여행")
        let finance = Memo(title: "금융", value: "값", category: "금융")
        try sut.save(memos: [travel, finance], type: .memo)

        // When — 구버전이 category를 날려먹고 재저장 → 다시 신버전으로 load
        try simulateDowngradeRewrite(of: [travel, finance])
        let healed = try sut.load(type: .memo)

        // Then — 사이드카에서 복원
        XCTAssertEqual(healed.first { $0.id == travel.id }?.category, "여행")
        XCTAssertEqual(healed.first { $0.id == finance.id }?.category, "금융")

        // 치유는 파일에도 반영되어야 함 (재로드해도 유지)
        let reloaded = try sut.load(type: .memo)
        XCTAssertEqual(reloaded.first { $0.id == travel.id }?.category, "여행")
    }

    func testIntentionalMoveToBasic_IsNotResurrectedBySidecar() throws {
        // Given — "여행" 메모가 사이드카에 기록된 상태
        var memo = Memo(title: "메모", value: "값", category: "여행")
        try sut.save(memos: [memo], type: .memo)

        // When — 사용자가 신버전에서 의도적으로 "기본"으로 이동 (save가 사이드카도 갱신)
        memo.category = "기본"
        try sut.save(memos: [memo], type: .memo)
        let loaded = try sut.load(type: .memo)

        // Then — 사이드카가 옛 "여행"을 되살리면 안 됨
        XCTAssertEqual(loaded[0].category, "기본")
        let map = groupDefaults?.dictionary(forKey: sidecarKey) as? [String: String]
        XCTAssertNil(map?[memo.id.uuidString], "기본으로 옮기면 사이드카에서도 제거")
    }

    func testLoad_BootstrapsSidecarForExistingUsers() throws {
        // Given — 사이드카가 없던 기존 사용자 (메모는 파일에 직접 존재)
        let memo = Memo(title: "기존 메모", value: "값", category: "업무")
        let data = try JSONEncoder().encode([memo])
        try data.write(to: XCTUnwrap(memosFileURL))
        groupDefaults?.removeObject(forKey: sidecarKey)

        // When — 신버전 첫 로드
        _ = try sut.load(type: .memo)

        // Then — 이후 다운그레이드에 대비해 사이드카가 채워져야 함
        let map = groupDefaults?.dictionary(forKey: sidecarKey) as? [String: String]
        XCTAssertEqual(map?[memo.id.uuidString], "업무")
    }
}
