//
//  MemoTimeMachineTests.swift
//  ClipKeyboardTests
//
//  Created by Claude Code on 2026-06-11.
//  메모 타임머신(변경 기록/되돌리기) 무결성 테스트.
//
//  사용자 시나리오: 대량 삭제·편집·마이그레이션 사고가 나도
//  "설정 → 변경 기록"에서 직전 상태로 되돌릴 수 있어야 한다.
//

import XCTest
@testable import ClipKeyboard

final class MemoTimeMachineTests: XCTestCase {

    var sut: MemoStore!

    private var historyFileURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo"
        )?.appendingPathComponent("memo.history.data")
    }

    override func setUp() {
        super.setUp()
        sut = MemoStore.shared
        resetState()
    }

    override func tearDown() {
        resetState()
        sut = nil
        super.tearDown()
    }

    /// 메모와 스냅샷 히스토리를 모두 비운다. (recordHistory:false로 정리 자체가 스냅샷을 남기지 않게)
    private func resetState() {
        try? sut.save(memos: [], type: .memo, recordHistory: false)
        if let url = historyFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - 스냅샷 생성 규칙

    func testMeaningfulChange_CapturesPreviousState() throws {
        // Given — 첫 저장 (이전 상태가 비어 있으므로 스냅샷 없음)
        let v1 = [Memo(title: "원본 제목", value: "원본 값", category: "업무")]
        try sut.save(memos: v1, type: .memo)
        XCTAssertTrue(sut.loadMemoHistory().isEmpty, "빈 상태에서의 첫 저장은 스냅샷을 만들지 않음")

        // When — 제목 변경(의미 있는 변경)
        var v2 = v1
        v2[0].title = "수정된 제목"
        try sut.save(memos: v2, type: .memo)

        // Then — 덮어쓰기 직전 상태(v1)가 스냅샷으로 보관됨
        let history = sut.loadMemoHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].memoCount, 1)
        XCTAssertEqual(history[0].memos[0].title, "원본 제목")
        XCTAssertEqual(history[0].memos[0].category, "업무")
    }

    func testUsageOnlyChange_DoesNotCaptureSnapshot() throws {
        // Given
        let memo = Memo(title: "메모", value: "값")
        try sut.save(memos: [memo], type: .memo)

        // When — 사용량만 변경 (clipCount/lastUsedAt — 키보드에서 메모 쓸 때마다 발생)
        try sut.incrementClipCount(for: memo.id)
        try sut.incrementClipCount(for: memo.id)

        // Then — 사용량 변경은 스냅샷을 만들지 않아야 함 (히스토리 오염 방지)
        XCTAssertTrue(sut.loadMemoHistory().isEmpty)

        // 그래도 clipCount 자체는 정상 반영
        let loaded = try sut.load(type: .memo)
        XCTAssertEqual(loaded[0].clipCount, 2)
    }

    func testRecordHistoryFalse_SkipsSnapshot() throws {
        // Given
        try sut.save(memos: [Memo(title: "A", value: "1")], type: .memo)

        // When — 내부 치유/마이그레이션 경로처럼 recordHistory:false로 저장
        try sut.save(memos: [Memo(title: "B", value: "2")], type: .memo, recordHistory: false)

        // Then
        XCTAssertTrue(sut.loadMemoHistory().isEmpty)
    }

    func testHistory_KeepsOnlyRecentTenSnapshots() throws {
        // Given — 11번의 의미 있는 변경 (첫 저장 제외 = 스냅샷 11개 후보)
        try sut.save(memos: [Memo(title: "v0", value: "값")], type: .memo)
        for i in 1...11 {
            try sut.save(memos: [Memo(title: "v\(i)", value: "값")], type: .memo)
        }

        // Then — 링버퍼: 최근 10개만, 최신이 맨 앞
        let history = sut.loadMemoHistory()
        XCTAssertEqual(history.count, MemoStore.memoHistoryLimit)
        XCTAssertEqual(history[0].memos[0].title, "v10", "가장 최근에 덮어쓰인 상태가 맨 앞")
        XCTAssertEqual(history.last?.memos[0].title, "v1", "가장 오래된 v0 스냅샷은 밀려남")
    }

    // MARK: - 복원 (되돌리기)

    func testRestoreSnapshot_RevertsToPreviousState() throws {
        // Given — 메모 3개 → 사고로 1개만 남음 (대량 삭제 시나리오)
        let original = [
            Memo(title: "중요 메모1", value: "값1", category: "금융"),
            Memo(title: "중요 메모2", value: "값2", isFavorite: true),
            Memo(title: "중요 메모3", value: "값3", isSecure: true)
        ]
        try sut.save(memos: original, type: .memo)
        try sut.save(memos: [original[0]], type: .memo)   // 2개 유실!

        // When — 변경 기록에서 직전 시점으로 복원
        let snapshot = try XCTUnwrap(sut.loadMemoHistory().first)
        XCTAssertTrue(sut.restoreMemoSnapshot(snapshot.id))

        // Then — 3개 전부, 필드까지 복구
        let restored = try sut.load(type: .memo)
        XCTAssertEqual(restored.count, 3)
        XCTAssertEqual(restored.map(\.id), original.map(\.id))
        XCTAssertEqual(restored[0].category, "금융")
        XCTAssertTrue(restored[1].isFavorite)
        XCTAssertTrue(restored[2].isSecure)
    }

    func testRestoreSnapshot_IsItselfUndoable() throws {
        // Given — v1 → v2 (v1 스냅샷 생성)
        try sut.save(memos: [Memo(title: "v1", value: "값")], type: .memo)
        try sut.save(memos: [Memo(title: "v2", value: "값")], type: .memo)
        let v1Snapshot = try XCTUnwrap(sut.loadMemoHistory().first)

        // When — v1로 되돌리기
        XCTAssertTrue(sut.restoreMemoSnapshot(v1Snapshot.id))

        // Then — 되돌리기 직전 상태(v2)도 스냅샷으로 보존 → 되돌리기를 취소할 수 있음
        let v2Snapshot = try XCTUnwrap(sut.loadMemoHistory().first)
        XCTAssertEqual(v2Snapshot.memos[0].title, "v2")

        XCTAssertTrue(sut.restoreMemoSnapshot(v2Snapshot.id))
        let final = try sut.load(type: .memo)
        XCTAssertEqual(final[0].title, "v2")
    }

    func testRestoreSnapshot_UnknownId_ReturnsFalseAndKeepsData() throws {
        // Given
        let memos = [Memo(title: "현재 메모", value: "값")]
        try sut.save(memos: memos, type: .memo)

        // When
        let result = sut.restoreMemoSnapshot(UUID())

        // Then
        XCTAssertFalse(result)
        let loaded = try sut.load(type: .memo)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "현재 메모")
    }
}
