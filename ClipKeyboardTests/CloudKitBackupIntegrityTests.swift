//
//  CloudKitBackupIntegrityTests.swift
//  ClipKeyboardTests
//
//  Created by Claude Code on 2026-06-11.
//  iCloud 백업/복원 무결성 테스트 — 네트워크 없이 mock DB로 전체 경로 검증.
//
//  CloudKitBackupService에 CloudKitBackupDatabase(프로토콜)를 주입해
//  실제 CKDatabase 호출만 인메모리로 대체하고, 인코딩→CKRecord/CKAsset 구성→
//  저장→복원 디코딩→MemoStore 반영까지 출시 코드 경로를 그대로 태운다.
//

import XCTest
import CloudKit
@testable import ClipKeyboard

// MARK: - Mock Database

/// 인메모리 CloudKit DB. 레코드 저장/조회/삭제 + 에러 주입(재시도 검증용)을 지원.
final class MockCloudKitDatabase: CloudKitBackupDatabase {
    var records: [CKRecord.ID: CKRecord] = [:]
    /// save 호출 시 앞에서부터 하나씩 꺼내 던질 에러 큐. 비면 정상 저장.
    var saveErrorQueue: [Error] = []
    private(set) var saveCallCount = 0

    func record(for recordID: CKRecord.ID) async throws -> CKRecord {
        guard let record = records[recordID] else {
            throw CKError(.unknownItem)
        }
        return record
    }

    @discardableResult
    func save(_ record: CKRecord) async throws -> CKRecord {
        saveCallCount += 1
        if !saveErrorQueue.isEmpty {
            throw saveErrorQueue.removeFirst()
        }
        records[record.recordID] = record
        return record
    }

    @discardableResult
    func deleteRecord(withID recordID: CKRecord.ID) async throws -> CKRecord.ID {
        records.removeValue(forKey: recordID)
        return recordID
    }
}

// MARK: - Tests

final class CloudKitBackupIntegrityTests: XCTestCase {

    var mockDB: MockCloudKitDatabase!
    var sut: CloudKitBackupService!
    var memoStore: MemoStore!

    private let backupRecordID = CKRecord.ID(recordName: "TokenMemoBackup")
    private let appGroupDefaults = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")

    override func setUp() {
        super.setUp()
        mockDB = MockCloudKitDatabase()
        sut = CloudKitBackupService(
            database: mockDB,
            accountStatus: { .available }
        )
        memoStore = MemoStore.shared
        clearLocalData()
    }

    override func tearDown() {
        clearLocalData()
        UserDefaults.standard.removeObject(forKey: "lastBackupDate")
        memoStore = nil
        sut = nil
        mockDB = nil
        super.tearDown()
    }

    private func clearLocalData() {
        try? memoStore.save(memos: [], type: .memo, recordHistory: false)
        try? memoStore.saveSmartClipboardHistory(history: [])
        try? memoStore.saveCombos([])
    }

    /// 모든 의미 있는 필드를 채운 메모 — 라운드트립에서 어느 필드가 유실돼도 잡아낸다.
    private func makeRichMemo() -> Memo {
        var memo = Memo(
            title: "계좌 안내",
            value: "{이름}님 국민 123-45 입금 부탁드립니다",
            isChecked: true,
            lastEdited: Date(timeIntervalSince1970: 1_750_000_000),
            isFavorite: true,
            category: "업무",
            isSecure: true,
            templateVariables: ["이름"],
            placeholderValues: ["이름": ["유미", "주디"]],
            comboValues: ["1단계 텍스트", "2단계 텍스트"],
            comboInterval: 1.5,
            autoDetectedType: .bankAccount,
            imageFileName: "legacy.jpg",
            imageFileNames: ["a.jpg", "b.jpg"],
            contentType: .text,
            lastUsedAt: Date(timeIntervalSince1970: 1_750_100_000),
            hint: "급여일에 사용"
        )
        memo.clipCount = 7
        return memo
    }

    // MARK: - 백업: 레코드 구성

    func testBackup_RecordContainsAssetsAndMetadata() async throws {
        // Given
        try memoStore.save(memos: [makeRichMemo()], type: .memo)
        try memoStore.saveSmartClipboardHistory(history: [
            SmartClipboardHistory(content: "test@example.com", detectedType: .email, confidence: 0.95)
        ])

        // When
        try await sut.backupData()

        // Then — 레코드 1개에 3개 Asset + 메타데이터
        XCTAssertEqual(mockDB.records.count, 1)
        let record = try XCTUnwrap(mockDB.records[backupRecordID])
        XCTAssertNotNil(record["memosAsset"] as? CKAsset)
        XCTAssertNotNil(record["smartClipboardAsset"] as? CKAsset)
        XCTAssertNotNil(record["combosAsset"] as? CKAsset)
        XCTAssertNotNil(record["backupDate"] as? Date)
        XCTAssertNotNil(record["version"] as? String)

        // Asset 안의 메모 데이터가 실제로 디코딩 가능하고 내용이 일치해야 함
        let asset = try XCTUnwrap(record["memosAsset"] as? CKAsset)
        let data = try Data(contentsOf: try XCTUnwrap(asset.fileURL))
        let backedUp = try JSONDecoder().decode([Memo].self, from: data)
        XCTAssertEqual(backedUp.count, 1)
        XCTAssertEqual(backedUp[0].title, "계좌 안내")

        // 성공한 백업은 lastBackupDate를 갱신
        XCTAssertNotNil(sut.lastBackupDate)
    }

    func testBackup_SecondBackupUpdatesExistingRecord() async throws {
        // Given — 1차 백업
        try memoStore.save(memos: [Memo(title: "v1", value: "값1")], type: .memo)
        try await sut.backupData()

        // When — 데이터 변경 후 2차 백업
        try memoStore.save(memos: [Memo(title: "v2", value: "값2"), Memo(title: "v2-2", value: "값")], type: .memo)
        try await sut.backupData()

        // Then — 레코드는 여전히 1개, 내용은 최신
        XCTAssertEqual(mockDB.records.count, 1)
        let record = try XCTUnwrap(mockDB.records[backupRecordID])
        let asset = try XCTUnwrap(record["memosAsset"] as? CKAsset)
        let data = try Data(contentsOf: try XCTUnwrap(asset.fileURL))
        let backedUp = try JSONDecoder().decode([Memo].self, from: data)
        XCTAssertEqual(backedUp.count, 2)
        XCTAssertEqual(backedUp[0].title, "v2")
    }

    // MARK: - 라운드트립 무결성 (핵심)

    func testBackupThenRestore_PreservesAllMemoFields() async throws {
        // Given — 모든 필드가 채워진 메모 + 클립보드 + 콤보
        let original = makeRichMemo()
        let clipboard = SmartClipboardHistory(content: "010-1234-5678", detectedType: .phone, confidence: 0.9)
        let combo = Combo(title: "출근 콤보", items: [
            ComboItem(type: .memo, referenceId: original.id, order: 0)
        ], interval: 3.0)

        try memoStore.save(memos: [original], type: .memo)
        try memoStore.saveSmartClipboardHistory(history: [clipboard])
        try memoStore.saveCombos([combo])

        // When — 백업 → 로컬 전체 삭제(기기 변경 시나리오) → 복원
        try await sut.backupData()
        clearLocalData()
        XCTAssertTrue(try memoStore.load(type: .memo).isEmpty, "사전 조건: 로컬이 비어 있어야 함")
        try await sut.restoreData(forceOverwrite: true)

        // Then — 메모의 모든 필드가 보존되어야 함
        let restored = try memoStore.load(type: .memo)
        XCTAssertEqual(restored.count, 1)
        let memo = try XCTUnwrap(restored.first)
        XCTAssertEqual(memo.id, original.id)
        XCTAssertEqual(memo.title, original.title)
        XCTAssertEqual(memo.value, original.value)
        XCTAssertEqual(memo.isChecked, original.isChecked)
        XCTAssertEqual(memo.isFavorite, original.isFavorite)
        XCTAssertEqual(memo.clipCount, original.clipCount)
        XCTAssertEqual(memo.category, original.category)
        XCTAssertEqual(memo.isSecure, original.isSecure)
        XCTAssertEqual(memo.templateVariables, original.templateVariables)
        XCTAssertEqual(memo.placeholderValues, original.placeholderValues)
        XCTAssertEqual(memo.comboValues, original.comboValues)
        XCTAssertEqual(memo.comboInterval, original.comboInterval)
        XCTAssertEqual(memo.autoDetectedType, original.autoDetectedType)
        XCTAssertEqual(memo.imageFileName, original.imageFileName)
        XCTAssertEqual(memo.imageFileNames, original.imageFileNames)
        XCTAssertEqual(memo.contentType, original.contentType)
        XCTAssertEqual(memo.hint, original.hint)
        XCTAssertTrue(memo.isTemplate, "템플릿 판정(계산형)이 복원 후에도 유지")
        XCTAssertTrue(memo.isCombo, "콤보 판정(계산형)이 복원 후에도 유지")
        // 날짜는 JSON 인코딩 정밀도 내에서 일치
        XCTAssertEqual(memo.lastEdited.timeIntervalSince1970,
                       original.lastEdited.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(memo.lastUsedAt).timeIntervalSince1970,
                       try XCTUnwrap(original.lastUsedAt).timeIntervalSince1970, accuracy: 0.001)

        // 클립보드/콤보도 보존
        let restoredClipboard = try memoStore.loadSmartClipboardHistory()
        XCTAssertEqual(restoredClipboard.count, 1)
        XCTAssertEqual(restoredClipboard[0].content, clipboard.content)
        XCTAssertEqual(restoredClipboard[0].detectedType, .phone)

        let restoredCombos = try memoStore.loadCombos()
        XCTAssertEqual(restoredCombos.count, 1)
        XCTAssertEqual(restoredCombos[0].title, combo.title)
        XCTAssertEqual(restoredCombos[0].items.count, 1)
        XCTAssertEqual(restoredCombos[0].items[0].referenceId, original.id)
    }

    func testRestore_ResetsComboMigrationFlag() async throws {
        // Given — 마이그레이션 완료 상태에서 옛 백업을 복원하는 상황
        appGroupDefaults?.set(true, forKey: "comboModelUnifyMigrated_v1")
        try memoStore.save(memos: [Memo(title: "백업", value: "값")], type: .memo)
        try await sut.backupData()

        // When
        try await sut.restoreData(forceOverwrite: true)

        // Then — 복원된 레거시 데이터가 다음 실행에 재변환되도록 플래그 리셋
        XCTAssertEqual(appGroupDefaults?.bool(forKey: "comboModelUnifyMigrated_v1"), false)
    }

    // MARK: - 복원: 사용자 보호 장치

    func testRestore_WithLocalData_RequiresConfirmationAndKeepsData() async throws {
        // Given — 백업 존재 + 로컬에 다른 데이터 존재
        try memoStore.save(memos: [Memo(title: "백업본", value: "값")], type: .memo)
        try await sut.backupData()
        let localOnly = [Memo(title: "로컬 신규 메모", value: "아직 백업 안 됨")]
        try memoStore.save(memos: localOnly, type: .memo)

        // When/Then — forceOverwrite 없이 복원하면 거부(사용자 확인 필요)
        do {
            try await sut.restoreData(forceOverwrite: false)
            XCTFail("로컬 데이터가 있으면 확인 없이 덮어쓰면 안 됨")
        } catch {
            // 거부 후 로컬 데이터는 그대로여야 함 (무결성)
            let memos = try memoStore.load(type: .memo)
            XCTAssertEqual(memos.count, 1)
            XCTAssertEqual(memos[0].title, "로컬 신규 메모")
        }
    }

    func testRestore_NoBackup_ThrowsNoBackupFound() async throws {
        // Given — mock DB에 레코드 없음
        // When/Then
        do {
            try await sut.restoreData(forceOverwrite: true)
            XCTFail("백업이 없으면 noBackupFound를 던져야 함")
        } catch let error as CloudKitError {
            guard case .noBackupFound = error else {
                return XCTFail("noBackupFound 기대, 실제: \(error)")
            }
        }
    }

    func testRestore_CorruptedMemoAsset_FailsAndKeepsLocalData() async throws {
        // Given — 깨진 JSON이 든 백업 레코드 + 로컬 데이터
        let record = CKRecord(recordType: "Backup", recordID: backupRecordID)
        let corruptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("corrupt-memos.json")
        try Data("이건 JSON이 아님 {{{".utf8).write(to: corruptURL)
        record["memosAsset"] = CKAsset(fileURL: corruptURL)
        mockDB.records[backupRecordID] = record

        let sentinel = [Memo(title: "지켜야 할 메모", value: "값")]
        try memoStore.save(memos: sentinel, type: .memo)

        // When/Then — 복원은 실패하고 로컬 데이터는 손대지 않아야 함
        do {
            try await sut.restoreData(forceOverwrite: true)
            XCTFail("깨진 백업은 복원에 실패해야 함")
        } catch {
            let memos = try memoStore.load(type: .memo)
            XCTAssertEqual(memos.count, 1)
            XCTAssertEqual(memos[0].title, "지켜야 할 메모")
        }
    }

    // MARK: - 레거시 백업 포맷 호환

    func testRestore_LegacyDataFieldRecord_StillWorks() async throws {
        // Given — CKAsset 도입 전, Data 필드에 직접 저장하던 옛 백업 레코드
        let legacyMemos = [Memo(title: "옛 백업 메모", value: "레거시 값", category: "여행")]
        let record = CKRecord(recordType: "Backup", recordID: backupRecordID)
        record["memos"] = try JSONEncoder().encode(legacyMemos) as NSData
        record["smartClipboardHistory"] = try JSONEncoder().encode(
            [SmartClipboardHistory(content: "legacy@example.com", detectedType: .email, confidence: 0.9)]
        ) as NSData
        mockDB.records[backupRecordID] = record

        // When
        try await sut.restoreData(forceOverwrite: true)

        // Then
        let memos = try memoStore.load(type: .memo)
        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos[0].title, "옛 백업 메모")
        XCTAssertEqual(memos[0].category, "여행")

        let clipboard = try memoStore.loadSmartClipboardHistory()
        XCTAssertEqual(clipboard.count, 1)
        XCTAssertEqual(clipboard[0].content, "legacy@example.com")
    }

    // MARK: - 인증

    func testBackup_NotAuthenticated_Throws() async throws {
        // Given — iCloud 미로그인
        let unauthSut = CloudKitBackupService(database: mockDB, accountStatus: { .noAccount })
        try memoStore.save(memos: [Memo(title: "메모", value: "값")], type: .memo)

        // When/Then
        do {
            try await unauthSut.backupData()
            XCTFail("미인증 상태에서 백업은 실패해야 함")
        } catch let error as CloudKitError {
            guard case .notAuthenticated = error else {
                return XCTFail("notAuthenticated 기대, 실제: \(error)")
            }
            XCTAssertEqual(mockDB.saveCallCount, 0, "인증 실패 시 네트워크 저장 시도 자체가 없어야 함")
        }
    }

    func testRestore_NotAuthenticated_Throws() async throws {
        // Given
        let unauthSut = CloudKitBackupService(database: mockDB, accountStatus: { .restricted })

        // When/Then
        do {
            try await unauthSut.restoreData(forceOverwrite: true)
            XCTFail("미인증 상태에서 복원은 실패해야 함")
        } catch let error as CloudKitError {
            guard case .notAuthenticated = error else {
                return XCTFail("notAuthenticated 기대, 실제: \(error)")
            }
        }
    }

    // MARK: - 재시도 정책

    func testBackup_RetriesOnTransientNetworkFailure() async throws {
        // Given — 첫 저장은 네트워크 실패, 두 번째는 성공
        mockDB.saveErrorQueue = [CKError(.networkFailure)]
        try memoStore.save(memos: [Memo(title: "재시도", value: "값")], type: .memo)

        // When
        try await sut.backupData()

        // Then — 1회 재시도 후 성공, 레코드 저장됨
        XCTAssertEqual(mockDB.saveCallCount, 2)
        XCTAssertNotNil(mockDB.records[backupRecordID])
    }

    func testBackup_NonRetryableError_FailsImmediately() async throws {
        // Given — 권한 오류는 재시도해도 소용없음
        mockDB.saveErrorQueue = [CKError(.permissionFailure)]
        try memoStore.save(memos: [Memo(title: "메모", value: "값")], type: .memo)

        // When/Then
        do {
            try await sut.backupData()
            XCTFail("재시도 불가 에러는 즉시 실패해야 함")
        } catch {
            XCTAssertEqual(mockDB.saveCallCount, 1, "재시도 없이 1회만 시도해야 함")
        }
    }

    // MARK: - 백업 존재 확인 / 삭제

    func testHasBackup_ReflectsRecordExistence() async throws {
        // Given/When/Then — 백업 전엔 false
        let before = await sut.hasBackup()
        XCTAssertFalse(before)

        // 백업 후엔 true
        try memoStore.save(memos: [Memo(title: "메모", value: "값")], type: .memo)
        try await sut.backupData()
        let after = await sut.hasBackup()
        XCTAssertTrue(after)
    }

    func testDeleteBackup_RemovesRecordAndClearsDate() async throws {
        // Given — 백업 존재
        try memoStore.save(memos: [Memo(title: "메모", value: "값")], type: .memo)
        try await sut.backupData()
        XCTAssertNotNil(sut.lastBackupDate)

        // When
        try await sut.deleteBackup()

        // Then
        let exists = await sut.hasBackup()
        XCTAssertFalse(exists)
        await MainActor.run {
            XCTAssertNil(sut.lastBackupDate)
        }
        XCTAssertNil(UserDefaults.standard.object(forKey: "lastBackupDate"))
    }
}
