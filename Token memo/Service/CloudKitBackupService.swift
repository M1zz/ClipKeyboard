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
            let smartClipboardHistory = try MemoStore.shared.loadSmartClipboardHistory()
            let combos = try MemoStore.shared.loadCombos()

            print("📦 [CloudKit] 백업할 메모: \(memos.count)개")
            print("📦 [CloudKit] 백업할 스마트 클립보드: \(smartClipboardHistory.count)개")
            print("📦 [CloudKit] 백업할 Combo: \(combos.count)개")

            // 2. JSON 인코딩
            guard let memosData = try? JSONEncoder().encode(memos),
                  let smartClipboardData = try? JSONEncoder().encode(smartClipboardHistory),
                  let combosData = try? JSONEncoder().encode(combos) else {
                print("❌ [CloudKit] JSON 인코딩 실패")
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
            record["smartClipboardHistory"] = smartClipboardData as CKRecordValue
            record["combos"] = combosData as CKRecordValue
            record["backupDate"] = Date() as CKRecordValue

            // 앱 버전을 Info.plist에서 자동으로 가져오기
            let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
            record["version"] = appVersion as CKRecordValue

            print("💾 [CloudKit] 레코드 데이터 업데이트 완료")

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
            if let version = record["version"] as? String {
                print("📦 [CloudKit] 백업 버전: \(version)")
            }

            // 2. 메모 데이터 복구 (필수)
            guard let memosData = record["memos"] as? Data else {
                print("❌ [CloudKit] 메모 데이터 없음")
                throw CloudKitError.noBackupFound
            }

            guard let memos = try? JSONDecoder().decode([Memo].self, from: memosData) else {
                print("❌ [CloudKit] 메모 디코딩 실패")
                throw CloudKitError.decodingFailed
            }

            print("📦 [CloudKit] 복구할 메모: \(memos.count)개")

            // 3. 스마트 클립보드 복구 (옵션 - 없으면 건너뛰기)
            var smartClipboardHistory: [SmartClipboardHistory] = []
            if let smartClipboardData = record["smartClipboardHistory"] as? Data {
                if let decoded = try? JSONDecoder().decode([SmartClipboardHistory].self, from: smartClipboardData) {
                    smartClipboardHistory = decoded
                    print("📦 [CloudKit] 복구할 스마트 클립보드: \(smartClipboardHistory.count)개")
                } else {
                    print("⚠️ [CloudKit] 스마트 클립보드 디코딩 실패 - 건너뛰기")
                }
            } else {
                print("ℹ️ [CloudKit] 스마트 클립보드 데이터 없음 (레거시 백업일 수 있음)")
            }

            // 4. Combo 복구 (옵션 - 없으면 건너뛰기)
            var combos: [Combo] = []
            if let combosData = record["combos"] as? Data {
                if let decoded = try? JSONDecoder().decode([Combo].self, from: combosData) {
                    combos = decoded
                    print("📦 [CloudKit] 복구할 Combo: \(combos.count)개")
                } else {
                    print("⚠️ [CloudKit] Combo 디코딩 실패 - 건너뛰기")
                }
            } else {
                print("ℹ️ [CloudKit] Combo 데이터 없음 (레거시 백업일 수 있음)")
            }

            // 5. 로컬에 저장
            print("💾 [CloudKit] 로컬 저장 시작...")
            try MemoStore.shared.save(memos: memos, type: .tokenMemo)
            print("✅ [CloudKit] 메모 \(memos.count)개 저장 완료")

            if !smartClipboardHistory.isEmpty {
                try MemoStore.shared.saveSmartClipboardHistory(history: smartClipboardHistory)
                print("✅ [CloudKit] 스마트 클립보드 \(smartClipboardHistory.count)개 저장 완료")
            }

            if !combos.isEmpty {
                try MemoStore.shared.saveCombos(combos)
                print("✅ [CloudKit] Combo \(combos.count)개 저장 완료")
            }

            print("🎉 [CloudKit] 전체 복구 완료!")

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
