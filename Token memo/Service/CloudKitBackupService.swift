//
//  CloudKitBackupService.swift
//  Token memo
//
//  Created by Claude on 2025-11-28.
//

import Foundation
import CloudKit

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
            return "iCloud에 로그인되어 있지 않습니다."
        case .backupFailed(let error):
            return "백업 실패: \(error.localizedDescription)"
        case .restoreFailed(let error):
            return "복구 실패: \(error.localizedDescription)"
        case .noBackupFound:
            return "백업 데이터를 찾을 수 없습니다."
        case .encodingFailed:
            return "데이터 인코딩에 실패했습니다."
        case .decodingFailed:
            return "데이터 디코딩에 실패했습니다."
        }
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

    func backupData() async throws {
        print("☁️ [CloudKit] 백업 시작...")

        guard isAuthenticated else {
            throw CloudKitError.notAuthenticated
        }

        await MainActor.run {
            isBackingUp = true
        }

        defer {
            Task { @MainActor in
                isBackingUp = false
            }
        }

        do {
            // 1. 메모 데이터 로드
            let memos = try MemoStore.shared.load(type: .tokenMemo)
            let clipboardHistory = try MemoStore.shared.loadClipboardHistory()

            print("📦 [CloudKit] 백업할 메모: \(memos.count)개")
            print("📦 [CloudKit] 백업할 클립보드 히스토리: \(clipboardHistory.count)개")

            // 2. JSON 인코딩
            guard let memosData = try? JSONEncoder().encode(memos),
                  let clipboardData = try? JSONEncoder().encode(clipboardHistory) else {
                throw CloudKitError.encodingFailed
            }

            // 3. 기존 레코드 확인 및 가져오기
            let recordID = CKRecord.ID(recordName: "TokenMemoBackup")
            var record: CKRecord

            do {
                // 기존 레코드가 있으면 가져오기
                record = try await privateDatabase.record(for: recordID)
                print("🔄 [CloudKit] 기존 백업 레코드 업데이트")
            } catch let error as CKError where error.code == .unknownItem {
                // 기존 레코드가 없으면 새로 생성
                record = CKRecord(recordType: "Backup", recordID: recordID)
                print("✨ [CloudKit] 새 백업 레코드 생성")
            }

            // 4. 레코드 데이터 업데이트
            record["memos"] = memosData as CKRecordValue
            record["clipboardHistory"] = clipboardData as CKRecordValue
            record["backupDate"] = Date() as CKRecordValue
            record["version"] = "2.1.0" as CKRecordValue

            // 5. 저장
            _ = try await privateDatabase.save(record)

            let backupDate = Date()
            await MainActor.run {
                saveLastBackupDate(backupDate)
            }

            print("✅ [CloudKit] 백업 완료: \(backupDate)")

        } catch {
            print("❌ [CloudKit] 백업 실패: \(error)")
            throw CloudKitError.backupFailed(error)
        }
    }

    // MARK: - Restore

    func restoreData() async throws {
        print("☁️ [CloudKit] 복구 시작...")

        guard isAuthenticated else {
            throw CloudKitError.notAuthenticated
        }

        await MainActor.run {
            isRestoring = true
        }

        defer {
            Task { @MainActor in
                isRestoring = false
            }
        }

        do {
            // 1. CloudKit에서 레코드 가져오기
            let recordID = CKRecord.ID(recordName: "TokenMemoBackup")
            let record = try await privateDatabase.record(for: recordID)

            print("📦 [CloudKit] 백업 레코드 찾음")

            // 2. 데이터 추출
            guard let memosData = record["memos"] as? Data,
                  let clipboardData = record["clipboardHistory"] as? Data else {
                throw CloudKitError.noBackupFound
            }

            // 3. JSON 디코딩
            guard let memos = try? JSONDecoder().decode([Memo].self, from: memosData),
                  let clipboardHistory = try? JSONDecoder().decode([ClipboardHistory].self, from: clipboardData) else {
                throw CloudKitError.decodingFailed
            }

            print("📦 [CloudKit] 복구할 메모: \(memos.count)개")
            print("📦 [CloudKit] 복구할 클립보드 히스토리: \(clipboardHistory.count)개")

            // 4. 로컬에 저장
            try MemoStore.shared.save(memos: memos, type: .tokenMemo)
            try MemoStore.shared.saveClipboardHistory(history: clipboardHistory)

            print("✅ [CloudKit] 복구 완료")

        } catch let error as CKError where error.code == .unknownItem {
            print("❌ [CloudKit] 백업 데이터 없음")
            throw CloudKitError.noBackupFound
        } catch {
            print("❌ [CloudKit] 복구 실패: \(error)")
            throw CloudKitError.restoreFailed(error)
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
