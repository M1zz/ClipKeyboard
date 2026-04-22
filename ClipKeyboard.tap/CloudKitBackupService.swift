//
//  CloudKitBackupService.swift
//  TokenMemo.tap
//
//  Created by Claude on 2025-11-28.
//

import Foundation
import CloudKit
import SwiftUI
import Combine

enum CloudKitError: Error {
    case notAuthenticated
    case backupFailed(Error)
    case restoreFailed(Error)
    case noBackupFound
    case encodingFailed
    case decodingFailed

    var localizedDescription: String {
        switch self {
        case .notAuthenticated:
            return NSLocalizedString("iCloud에 로그인되어 있지 않습니다. 설정 > [사용자 이름] > iCloud에서 로그인해주세요.",
                                   comment: "iCloud not authenticated error message")
        case .backupFailed(let error):
            return getActionableMessage(for: error, operation: "backup")
        case .restoreFailed(let error):
            return getActionableMessage(for: error, operation: "restore")
        case .noBackupFound:
            return NSLocalizedString("백업 데이터가 없습니다. 먼저 백업을 생성해주세요.",
                                   comment: "No backup found error message")
        case .encodingFailed:
            return NSLocalizedString("데이터를 준비하는 중 문제가 발생했습니다. 앱을 재시작하고 다시 시도해주세요.",
                                   comment: "Data encoding failed error message")
        case .decodingFailed:
            return NSLocalizedString("백업 데이터를 읽을 수 없습니다. 최신 버전의 앱을 사용하고 있는지 확인해주세요.",
                                   comment: "Data decoding failed error message")
        }
    }

    // MARK: - Helper

    private func getActionableMessage(for error: Error, operation: String) -> String {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                return NSLocalizedString("네트워크 연결을 확인하고 다시 시도해주세요.",
                                       comment: "Network error message")
            case .notAuthenticated:
                return NSLocalizedString("iCloud에 로그인되어 있지 않습니다. 설정 > [사용자 이름] > iCloud에서 로그인해주세요.",
                                       comment: "iCloud not authenticated error message")
            case .quotaExceeded:
                return NSLocalizedString("iCloud 저장 공간이 부족합니다. 설정 > [사용자 이름] > iCloud > 저장 공간 관리에서 확인해주세요.",
                                       comment: "iCloud quota exceeded error message")
            case .permissionFailure:
                return NSLocalizedString("iCloud Drive가 활성화되어 있는지 확인해주세요. 설정 > [사용자 이름] > iCloud > iCloud Drive를 켜주세요.",
                                       comment: "iCloud permission error message")
            case .serverResponseLost, .serviceUnavailable:
                return NSLocalizedString("iCloud 서버에 일시적인 문제가 있습니다. 잠시 후 다시 시도해주세요.",
                                       comment: "iCloud server error message")
            case .zoneBusy, .requestRateLimited:
                return NSLocalizedString("요청이 너무 많습니다. 잠시 후 다시 시도해주세요.",
                                       comment: "Rate limited error message")
            default:
                return NSLocalizedString("문제가 발생했습니다. 네트워크 연결과 iCloud 상태를 확인하고 다시 시도해주세요.",
                                       comment: "Generic iCloud error message")
            }
        }
        return NSLocalizedString("문제가 발생했습니다. 네트워크 연결과 iCloud 상태를 확인하고 다시 시도해주세요.",
                               comment: "Generic error message")
    }
}

class CloudKitBackupService: ObservableObject {
    static let shared = CloudKitBackupService()

    private let container: CKContainer
    private let privateDatabase: CKDatabase

    @Published var isAuthenticated: Bool = false
    @Published var lastBackupDate: Date?
    @Published var isBackingUp: Bool = false
    @Published var isRestoring: Bool = false

    private init() {
        self.container = CKContainer(identifier: "iCloud.com.Ysoup.TokenMemo")
        self.privateDatabase = container.privateCloudDatabase

        checkAccountStatus()
        loadLastBackupDate()
    }

    // MARK: - Account Status

    func checkAccountStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                self?.isAuthenticated = (status == .available)
                print("📱 [CloudKit] Account Status: \(status.rawValue)")
            }
        }
    }

    private func loadLastBackupDate() {
        if let timestamp = UserDefaults.standard.object(forKey: "lastBackupDate") as? Date {
            self.lastBackupDate = timestamp
        }
    }

    private func saveLastBackupDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "lastBackupDate")
        self.lastBackupDate = date
    }

    // MARK: - Backup

    /// 캐시된 isAuthenticated 플래그에 의존하지 않고 호출 시점에 계정 상태를
    /// 새로 조회. 앱 시작 직후 첫 버튼 클릭이 init의 async 콜백보다 빠른
    /// race 상황에서 .notAuthenticated 오탐을 방지한다.
    private func ensureAuthenticated() async throws {
        let status = try await container.accountStatus()
        await MainActor.run { self.isAuthenticated = (status == .available) }
        guard status == .available else {
            print("⚠️ [CloudKit] accountStatus = \(status.rawValue) (not available)")
            throw CloudKitError.notAuthenticated
        }
    }

    func backupData() async throws {
        print("☁️ [CloudKit] 백업 시작...")
        try await ensureAuthenticated()

        await MainActor.run { isBackingUp = true }
        defer { Task { [weak self] in await MainActor.run { self?.isBackingUp = false } } }

        do {
            let (memos, smartClipboard, combos) = try tapLoadDataForBackup()
            let (memosData, smartClipboardData, combosData) = try tapEncodeDataForBackup(
                memos: memos, smartClipboard: smartClipboard, combos: combos
            )
            var record = try await tapFetchOrCreateRecord()
            try tapConfigureRecord(&record, memosData: memosData, smartClipboardData: smartClipboardData, combosData: combosData)

            _ = try await saveRecordWithRetry(record, maxRetries: 3)

            let backupDate = Date()
            await MainActor.run { saveLastBackupDate(backupDate) }
            print("✅ [CloudKit] 백업 완료: \(backupDate)")
        } catch let error as CKError {
            print("❌ [CloudKit] CKError \(error.code.rawValue): \(error.localizedDescription)")
            throw CloudKitError.backupFailed(error)
        } catch {
            print("❌ [CloudKit] 백업 실패: \(error)")
            throw CloudKitError.backupFailed(error)
        }
    }

    /// 재시도 로직이 포함된 저장 (iOS와 동일 패턴).
    private func saveRecordWithRetry(_ record: CKRecord, maxRetries: Int) async throws -> CKRecord {
        var lastError: Error?
        for attempt in 0..<maxRetries {
            do {
                return try await privateDatabase.save(record)
            } catch let error as CKError {
                lastError = error
                let transient: [CKError.Code] = [.zoneBusy, .requestRateLimited, .serviceUnavailable, .networkFailure, .networkUnavailable, .serverResponseLost]
                if transient.contains(error.code), attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt)) // 1s, 2s, 4s
                    print("🔁 [CloudKit] 재시도 \(attempt + 1)/\(maxRetries) — \(delay)s 후")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                throw error
            } catch {
                throw error
            }
        }
        throw lastError ?? CKError(.internalError)
    }

    /// Data를 CKAsset으로 변환 (1MB field limit 우회).
    private func createAsset(from data: Data, filename: String) throws -> CKAsset {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        try data.write(to: fileURL)
        return CKAsset(fileURL: fileURL)
    }

    /// CKAsset에서 Data 읽기.
    private func readAsset(_ asset: CKAsset) throws -> Data {
        guard let fileURL = asset.fileURL else {
            throw CloudKitError.decodingFailed
        }
        return try Data(contentsOf: fileURL)
    }

    private func tapLoadDataForBackup() throws -> (memos: [Memo], smartClipboard: [SmartClipboardHistory], combos: [Combo]) {
        let memos = try MemoStore.shared.load(type: .tokenMemo)
        let smartClipboard = try MemoStore.shared.loadSmartClipboardHistory()
        let combos = try MemoStore.shared.loadCombos()
        print("📦 [CloudKit] 백업할 메모: \(memos.count)개, 클립보드: \(smartClipboard.count)개, Combo: \(combos.count)개")
        return (memos, smartClipboard, combos)
    }

    private func tapEncodeDataForBackup(
        memos: [Memo], smartClipboard: [SmartClipboardHistory], combos: [Combo]
    ) throws -> (Data, Data, Data) {
        guard let memosData = try? JSONEncoder().encode(memos),
              let smartClipboardData = try? JSONEncoder().encode(smartClipboard),
              let combosData = try? JSONEncoder().encode(combos) else {
            print("❌ [CloudKit] JSON 인코딩 실패")
            throw CloudKitError.encodingFailed
        }
        return (memosData, smartClipboardData, combosData)
    }

    private func tapFetchOrCreateRecord() async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: "TokenMemoBackup")
        do {
            let record = try await privateDatabase.record(for: recordID)
            print("🔄 [CloudKit] 기존 백업 레코드 업데이트")
            return record
        } catch let error as CKError where error.code == .unknownItem {
            print("✨ [CloudKit] 새 백업 레코드 생성")
            return CKRecord(recordType: "Backup", recordID: recordID)
        }
    }

    /// iOS와 동일한 필드 이름(`memosAsset` 등) + CKAsset 사용.
    /// 이전 Mac 버전은 `memos` 키에 raw Data를 쓰고 있어 iOS 백업과 호환되지
    /// 않았고, 1MB 필드 크기 제한에 걸려 조용히 실패하기도 했다.
    private func tapConfigureRecord(_ record: inout CKRecord, memosData: Data, smartClipboardData: Data, combosData: Data) throws {
        record["memosAsset"] = try createAsset(from: memosData, filename: "memos.json")
        record["smartClipboardAsset"] = try createAsset(from: smartClipboardData, filename: "smartClipboard.json")
        record["combosAsset"] = try createAsset(from: combosData, filename: "combos.json")
        record["backupDate"] = Date() as CKRecordValue
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        record["version"] = appVersion as CKRecordValue
        print("💾 [CloudKit] 레코드 데이터 업데이트 완료 (CKAsset)")
    }

    // MARK: - Restore

    func restoreData() async throws {
        print("☁️ [CloudKit] 복구 시작...")

        try await ensureAuthenticated()

        await MainActor.run { isRestoring = true }
        defer { Task { [weak self] in await MainActor.run { self?.isRestoring = false } } }

        do {
            let recordID = CKRecord.ID(recordName: "TokenMemoBackup")
            let record = try await privateDatabase.record(for: recordID)
            print("📦 [CloudKit] 백업 레코드 찾음")
            if let version = record["version"] as? String {
                print("📦 [CloudKit] 백업 버전: \(version)")
            }

            let memos = try fetchMemos(from: record)
            let smartClipboard = fetchSmartClipboardHistory(from: record)
            let combos = fetchCombos(from: record)
            try saveRestoredData(memos: memos, smartClipboard: smartClipboard, combos: combos)

            print("🎉 [CloudKit] 전체 복구 완료!")

        } catch let error as CKError where error.code == .unknownItem {
            print("❌ [CloudKit] 백업 데이터 없음")
            throw CloudKitError.noBackupFound
        } catch {
            print("❌ [CloudKit] 복구 실패: \(error)")
            throw CloudKitError.restoreFailed(error)
        }
    }

    /// CKAsset (iOS/새 Mac 형식) → 없으면 raw Data (레거시 Mac 형식) 순으로 시도.
    /// iOS와 동일한 필드 이름 규약(`memosAsset`)을 우선 읽어 크로스 디바이스 호환.
    private func dataFromRecord(_ record: CKRecord, assetKey: String, legacyDataKey: String) -> Data? {
        if let asset = record[assetKey] as? CKAsset {
            if let data = try? readAsset(asset) {
                print("📦 [CloudKit] \(assetKey) 로드 (Asset)")
                return data
            }
        }
        if let legacy = record[legacyDataKey] as? Data {
            print("📦 [CloudKit] \(legacyDataKey) 로드 (레거시 Data)")
            return legacy
        }
        return nil
    }

    private func fetchMemos(from record: CKRecord) throws -> [Memo] {
        guard let data = dataFromRecord(record, assetKey: "memosAsset", legacyDataKey: "memos") else {
            print("❌ [CloudKit] 메모 데이터 없음 (memosAsset/memos 모두 비어있음)")
            throw CloudKitError.noBackupFound
        }
        guard let memos = try? JSONDecoder().decode([Memo].self, from: data) else {
            print("❌ [CloudKit] 메모 디코딩 실패")
            throw CloudKitError.decodingFailed
        }
        print("📦 [CloudKit] 복구할 메모: \(memos.count)개")
        return memos
    }

    private func fetchSmartClipboardHistory(from record: CKRecord) -> [SmartClipboardHistory] {
        guard let data = dataFromRecord(record, assetKey: "smartClipboardAsset", legacyDataKey: "smartClipboardHistory") else {
            print("ℹ️ [CloudKit] 스마트 클립보드 데이터 없음 (레거시 백업일 수 있음)")
            return []
        }
        guard let decoded = try? JSONDecoder().decode([SmartClipboardHistory].self, from: data) else {
            print("⚠️ [CloudKit] 스마트 클립보드 디코딩 실패 - 건너뛰기")
            return []
        }
        print("📦 [CloudKit] 복구할 스마트 클립보드: \(decoded.count)개")
        return decoded
    }

    private func fetchCombos(from record: CKRecord) -> [Combo] {
        guard let data = dataFromRecord(record, assetKey: "combosAsset", legacyDataKey: "combos") else {
            print("ℹ️ [CloudKit] Combo 데이터 없음 (레거시 백업일 수 있음)")
            return []
        }
        guard let decoded = try? JSONDecoder().decode([Combo].self, from: data) else {
            print("⚠️ [CloudKit] Combo 디코딩 실패 - 건너뛰기")
            return []
        }
        print("📦 [CloudKit] 복구할 Combo: \(decoded.count)개")
        return decoded
    }

    private func saveRestoredData(memos: [Memo], smartClipboard: [SmartClipboardHistory], combos: [Combo]) throws {
        print("💾 [CloudKit] 로컬 저장 시작...")
        try MemoStore.shared.save(memos: memos, type: .tokenMemo)
        print("✅ [CloudKit] 메모 \(memos.count)개 저장 완료")

        if !smartClipboard.isEmpty {
            try MemoStore.shared.saveSmartClipboardHistory(history: smartClipboard)
            print("✅ [CloudKit] 스마트 클립보드 \(smartClipboard.count)개 저장 완료")
        }

        if !combos.isEmpty {
            try MemoStore.shared.saveCombos(combos)
            print("✅ [CloudKit] Combo \(combos.count)개 저장 완료")
        }
    }

    // MARK: - Check Backup Existence

    func hasBackup() async -> Bool {
        do {
            let recordID = CKRecord.ID(recordName: "TokenMemoBackup")
            _ = try await privateDatabase.record(for: recordID)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Delete Backup

    func deleteBackup() async throws {
        print("🗑️ [CloudKit] 백업 삭제 시작...")

        try await ensureAuthenticated()

        do {
            let recordID = CKRecord.ID(recordName: "TokenMemoBackup")
            _ = try await privateDatabase.deleteRecord(withID: recordID)

            await MainActor.run {
                lastBackupDate = nil
                UserDefaults.standard.removeObject(forKey: "lastBackupDate")
            }

            print("✅ [CloudKit] 백업 삭제 완료")

        } catch {
            print("❌ [CloudKit] 백업 삭제 실패: \(error)")
            throw error
        }
    }

}
