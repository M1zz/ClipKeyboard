//
//  SmartClipboardLifecycleTests.swift
//  ClipKeyboardTests
//
//  Created by Claude Code on 2026-06-11.
//  스마트 클립보드 히스토리 수명주기 테스트.
//
//  사용자 시나리오: 복사할 때마다 자동 분류되어 히스토리에 쌓이고,
//  같은 내용은 중복 없이 맨 앞으로, 개수 제한 초과분과 보관 기간(30일) 지난 임시 항목은
//  자동 정리되어야 한다. 구버전 레거시 히스토리는 첫 로드에 이관된다.
//

import XCTest
@testable import ClipKeyboard

final class SmartClipboardLifecycleTests: XCTestCase {

    var sut: MemoStore!

    private var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        )
    }

    override func setUp() {
        super.setUp()
        sut = MemoStore.shared
        clearAll()
    }

    override func tearDown() {
        clearAll()
        sut = nil
        super.tearDown()
    }

    private func clearAll() {
        try? sut.saveSmartClipboardHistory(history: [])
        try? sut.saveClipboardHistory(history: [])
    }

    // MARK: - 추가 + 자동 분류

    func testAdd_ClassifiesContentAutomatically() throws {
        // When
        try sut.addToSmartClipboardHistory(content: "test@example.com")

        // Then - 이메일로 자동 분류 + 맨 앞 삽입
        let history = try sut.loadSmartClipboardHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].content, "test@example.com")
        XCTAssertEqual(history[0].detectedType, .email)
        XCTAssertGreaterThan(history[0].confidence, 0.5)
    }

    func testAdd_DuplicateContent_MovesToFrontWithoutDuplicating() throws {
        // Given
        try sut.addToSmartClipboardHistory(content: "첫 번째")
        try sut.addToSmartClipboardHistory(content: "두 번째")

        // When - 같은 내용을 다시 복사
        try sut.addToSmartClipboardHistory(content: "첫 번째")

        // Then - 중복 없이 맨 앞으로
        let history = try sut.loadSmartClipboardHistory()
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].content, "첫 번째")
        XCTAssertEqual(history[1].content, "두 번째")
    }

    // MARK: - 개수 제한 / 자동 정리

    func testAdd_EnforcesHistoryLimit() throws {
        // Given - 현재 요금제 기준 제한(무료 50 / Pro 100)
        let limit = ProFeatureManager.clipboardHistoryLimit()
        let seed = (0..<limit).map {
            SmartClipboardHistory(content: "항목 \($0)", detectedType: .text)
        }
        try sut.saveSmartClipboardHistory(history: seed)

        // When - 제한을 넘는 추가
        try sut.addToSmartClipboardHistory(content: "새 항목")

        // Then - 가장 오래된 항목이 밀려나고 제한 유지
        let history = try sut.loadSmartClipboardHistory()
        XCTAssertEqual(history.count, limit)
        XCTAssertEqual(history[0].content, "새 항목")
        XCTAssertFalse(history.contains { $0.content == "항목 \(limit - 1)" }, "가장 오래된 항목은 제거")
    }

    func testAdd_RemovesTemporaryItemsPastRetention() throws {
        // Given - 보관 기간을 하루 넘긴 임시 항목 + 같은 날짜의 비임시(보존) 항목 + 8일 된 임시 항목
        let pastRetention = Calendar.current.date(
            byAdding: .day, value: -(SmartClipboardHistory.retentionDays + 1), to: Date())!
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        let oldTemporary = SmartClipboardHistory(
            content: "오래된 임시", copiedAt: pastRetention, isTemporary: true, detectedType: .text)
        let oldKept = SmartClipboardHistory(
            content: "오래된 보관", copiedAt: pastRetention, isTemporary: false, detectedType: .text)
        let weekOld = SmartClipboardHistory(
            content: "8일 된 임시", copiedAt: eightDaysAgo, isTemporary: true, detectedType: .text)
        try sut.saveSmartClipboardHistory(history: [oldTemporary, oldKept, weekOld])

        // When - 새 복사가 일어나면 정리 트리거
        try sut.addToSmartClipboardHistory(content: "새 항목")

        // Then - 기간 지난 임시만 삭제. 보관 항목과 한 주 넘은 임시 항목은 유지(예전 7일 규칙이면 사라졌다)
        let history = try sut.loadSmartClipboardHistory()
        XCTAssertFalse(history.contains { $0.content == "오래된 임시" })
        XCTAssertTrue(history.contains { $0.content == "오래된 보관" })
        XCTAssertTrue(history.contains { $0.content == "8일 된 임시" })
        XCTAssertTrue(history.contains { $0.content == "새 항목" })
    }

    func testKeyboardRecents_TextOnlyNewestFirst() {
        let now = Date()
        let older = SmartClipboardHistory(content: "먼저", copiedAt: now.addingTimeInterval(-60))
        let newer = SmartClipboardHistory(content: "나중", copiedAt: now)
        let blank = SmartClipboardHistory(content: "   ", copiedAt: now)
        let image = SmartClipboardHistory(content: "", copiedAt: now, contentType: .image)

        let recents = SmartClipboardHistory.keyboardRecents([older, blank, image, newer], now: now)

        XCTAssertEqual(recents.map(\.content), ["나중", "먼저"], "넣을 글이 있는 것만, 최근 순으로")
    }

    /// 키보드 저장 버튼이 누르기 전에 보여 주는 글: 한 줄로 펴고, 카드번호는 끝 네 자리만.
    func testCaptureButtonPreview_OneLineAndMasksSensitive() {
        XCTAssertEqual(KeyboardRecentClipsPanel.maskedPreview("서울시 마포구\n월드컵북로 396"),
                       "서울시 마포구 월드컵북로 396")
        let card = KeyboardRecentClipsPanel.maskedPreview("4111 1111 1111 1111")
        XCTAssertFalse(card.contains("4111"), "카드번호 앞자리는 키보드에 보이면 안 된다")
        XCTAssertTrue(card.hasSuffix("1111"))
    }

    // MARK: - 사용자 분류 수정

    func testUpdateClipboardItemType_StoresUserCorrection() throws {
        // Given - 잘못 분류된 항목
        try sut.addToSmartClipboardHistory(content: "12345678")
        let item = try XCTUnwrap(sut.loadSmartClipboardHistory().first)

        // When - 사용자가 직접 타입을 수정
        try sut.updateClipboardItemType(id: item.id, correctedType: .membershipNumber)

        // Then - 수정값이 영구 저장
        let updated = try XCTUnwrap(sut.loadSmartClipboardHistory().first)
        XCTAssertEqual(updated.userCorrectedType, .membershipNumber)
    }

    // MARK: - 레거시 클립보드 마이그레이션

    func testLoad_MigratesLegacyClipboardOnFirstLoad() throws {
        // Given - 스마트 히스토리 파일이 없고(구버전 사용자) 레거시 히스토리만 존재
        let legacy = [
            ClipboardHistory(content: "legacy@example.com"),
            ClipboardHistory(content: "그냥 텍스트")
        ]
        try sut.saveClipboardHistory(history: legacy)
        let smartURL = try XCTUnwrap(containerURL).appendingPathComponent("smart.clipboard.history.data")
        try? FileManager.default.removeItem(at: smartURL)

        // When - 신버전 첫 로드
        let migrated = try sut.loadSmartClipboardHistory()

        // Then - id 보존 + 자동 분류 적용 + 영구 저장(재로드에도 유지)
        XCTAssertEqual(migrated.count, 2)
        XCTAssertEqual(migrated.map(\.id), legacy.map(\.id))
        XCTAssertEqual(migrated[0].detectedType, .email)

        let reloaded = try sut.loadSmartClipboardHistory()
        XCTAssertEqual(reloaded.count, 2)
    }

    // MARK: - 예전 판이 남긴 그림 (키보드가 열리지 않던 원인)

    /// 예전 판 모양 그대로의 한 줄. 그림은 base64 글자로 줄 안에 들어 있었다.
    private func legacyRow(content: String, type: String = "text", image: String? = nil,
                           ageDays: Double = 0) -> [String: Any] {
        var row: [String: Any] = [
            "id": UUID().uuidString, "content": content,
            "copiedAt": Date().addingTimeInterval(-ageDays * 86_400).timeIntervalSinceReferenceDate,
            "isTemporary": true, "contentType": type, "detectedType": "텍스트",
            "confidence": 0.3, "tags": [String](), "autoSaveOffered": false
        ]
        if let image { row["imageData"] = image }
        return row
    }

    private func writeLegacyHistory(_ rows: [[String: Any]]) throws -> URL {
        let url = try XCTUnwrap(try MemoStore.fileURL(type: .smartClipboardHistory))
        try JSONSerialization.data(withJSONObject: rows).write(to: url, options: .atomic)
        return url
    }

    /// 그림 20장(한 장 약 400KB)이 남은 파일. 키보드가 이걸 통째로 올리다 죽었다.
    func testLegacyImages_LoadWithoutImagePayload() throws {
        let fakeImage = String(repeating: "A", count: 400_000)
        var rows = (0..<20).map { _ in self.legacyRow(content: "이미지 (1024x768)", type: "image", image: fakeImage) }
        rows.insert(legacyRow(content: "서울시 마포구"), at: 0)
        _ = try writeLegacyHistory(rows)

        let history = try sut.loadSmartClipboardHistory()

        XCTAssertEqual(history.map(\.content), ["서울시 마포구"], "그림 줄은 버리고 글은 남는다")
        XCTAssertEqual(SmartClipboardHistory.keyboardRecents(history).map(\.content), ["서울시 마포구"])
    }

    func testCompaction_RemovesLegacyImageBytesFromDisk() throws {
        let fakeImage = String(repeating: "B", count: 300_000)
        let url = try writeLegacyHistory([
            legacyRow(content: "남길 글"),
            legacyRow(content: "이미지 (800x600)", type: "image", image: fakeImage)
        ])
        let before = try Data(contentsOf: url).count

        XCTAssertTrue(sut.compactSmartClipboardHistoryIfNeeded())

        let after = try Data(contentsOf: url)
        XCTAssertLessThan(after.count, before / 100)
        XCTAssertFalse(MemoStore.containsLegacyClipboardImages(after))
        XCTAssertEqual(try sut.loadSmartClipboardHistory().map(\.content), ["남길 글"])
        XCTAssertFalse(sut.compactSmartClipboardHistoryIfNeeded(), "한 번 줄였으면 다시 쓰지 않는다")
    }

    /// 칸 하나가 빠졌다고 기록 전체가 사라지면 안 된다(예전 판·다른 기기 백업).
    func testDecode_MissingFieldsKeepsHistory() throws {
        let url = try XCTUnwrap(try MemoStore.fileURL(type: .smartClipboardHistory))
        let rows: [[String: Any]] = [["content": "칸이 적은 줄",
                                      "copiedAt": Date().timeIntervalSinceReferenceDate]]
        try JSONSerialization.data(withJSONObject: rows).write(to: url, options: .atomic)

        let history = try sut.loadSmartClipboardHistory()
        XCTAssertEqual(history.map(\.content), ["칸이 적은 줄"])
        XCTAssertEqual(history.first?.contentType, .text)
    }
}
