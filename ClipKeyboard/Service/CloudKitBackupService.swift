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
            return NSLocalizedString("iCloud에 로그인되어 있지 않습니다. 설정 > [사용자 이름] > iCloud에서 로그인해주세요.",
                                   comment: "iCloud not authenticated error message")
        case .backupFailed(let error):
            return getActionableMessage(for: error, operation: "backup")
        case .restoreFailed(let error):
            return getActionableMessage(for: error, operation: "restore")
        case .noBackupFound:
            return NSLocalizedString("백업이 없습니다.",
                                   comment: "No backup found error message")
        case .encodingFailed:
            return NSLocalizedString("저장 실패. 앱을 재시작해주세요.",
                                   comment: "Data encoding failed error message")
        case .decodingFailed:
            return NSLocalizedString("백업을 읽을 수 없습니다. 앱을 업데이트해주세요.",
                                   comment: "Data decoding failed error message")
        }
    }

    // MARK: - Helper

    private func getActionableMessage(for error: Error, operation: String) -> String {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                return NSLocalizedString("네트워크 연결을 확인해주세요.",
                                       comment: "Network error message")
            case .notAuthenticated:
                return NSLocalizedString("iCloud에 로그인해주세요.",
                                       comment: "iCloud not authenticated error message")
            case .quotaExceeded:
                return NSLocalizedString("iCloud 저장 공간이 부족합니다.",
                                       comment: "iCloud quota exceeded error message")
            case .permissionFailure:
                return NSLocalizedString("iCloud Drive를 켜주세요.",
                                       comment: "iCloud permission error message")
            case .serverResponseLost, .serviceUnavailable:
                return NSLocalizedString("서버 문제. 잠시 후 다시 시도해주세요.",
                                       comment: "iCloud server error message")
            case .zoneBusy, .requestRateLimited:
                return NSLocalizedString("요청 초과. 잠시 후 다시 시도해주세요.",
                                       comment: "Rate limited error message")
            default:
                return NSLocalizedString("오류 발생. 네트워크와 iCloud를 확인해주세요.",
                                       comment: "Generic iCloud error message")
            }
        }
        return NSLocalizedString("오류 발생. 네트워크와 iCloud를 확인해주세요.",
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
    @Published var autoBackupEnabled: Bool = false

    private var autoBackupTimer: Timer?
    private let autoBackupInterval: TimeInterval = 300 // 5분마다 자동 백업

    private init() {
        self.container = CKContainer(identifier: "iCloud.com.Ysoup.TokenMemo")
        self.privateDatabase = container.privateCloudDatabase

        checkAccountStatus()
        loadLastBackupDate()
        loadAutoBackupSetting()

        // 데이터 변경 알림 리스너 등록
        setupDataChangeListener()
    }

    deinit {
        autoBackupTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
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

    private func loadAutoBackupSetting() {
        self.autoBackupEnabled = UserDefaults.standard.bool(forKey: "autoBackupEnabled")
        if autoBackupEnabled {
            startAutoBackupTimer()
        }
    }

    // MARK: - Auto Backup

    func enableAutoBackup() {
        print("🔄 [CloudKit] 자동 백업 활성화")
        UserDefaults.standard.set(true, forKey: "autoBackupEnabled")
        DispatchQueue.main.async { [weak self] in
            self?.autoBackupEnabled = true
        }
        startAutoBackupTimer()
    }

    func disableAutoBackup() {
        print("⏸️ [CloudKit] 자동 백업 비활성화")
        UserDefaults.standard.set(false, forKey: "autoBackupEnabled")
        DispatchQueue.main.async { [weak self] in
            self?.autoBackupEnabled = false
        }
        stopAutoBackupTimer()
    }

    private func startAutoBackupTimer() {
        stopAutoBackupTimer() // 기존 타이머 제거

        autoBackupTimer = Timer.scheduledTimer(withTimeInterval: autoBackupInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.isAuthenticated && !self.isBackingUp else { return }

            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.backupData()
                    print("✅ [CloudKit] 자동 백업 성공")
                } catch {
                    print("⚠️ [CloudKit] 자동 백업 실패: \(error.localizedDescription)")
                }
            }
        }

        print("⏰ [CloudKit] 자동 백업 타이머 시작 (간격: \(Int(autoBackupInterval))초)")
    }

    private func stopAutoBackupTimer() {
        autoBackupTimer?.invalidate()
        autoBackupTimer = nil
        print("⏹️ [CloudKit] 자동 백업 타이머 중지")
    }

    private func setupDataChangeListener() {
        // MemoStore에서 데이터 변경 알림을 받으면 자동 백업 트리거
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MemoDataChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            guard self.autoBackupEnabled && self.isAuthenticated && !self.isBackingUp else { return }

            print("📢 [CloudKit] 데이터 변경 감지 - 자동 백업 예약")

            // 변경사항이 연속으로 발생할 수 있으므로 디바운스 (5초 후 실행)
            self.scheduleAutoBackup()
        }
    }

    private var autoBackupWorkItem: DispatchWorkItem?

    private func scheduleAutoBackup() {
        // 기존 예약된 백업 취소
        autoBackupWorkItem?.cancel()

        // 새로운 백업 예약 (5초 후)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.backupData()
                    print("✅ [CloudKit] 변경사항 자동 백업 완료")
                } catch {
                    print("⚠️ [CloudKit] 자동 백업 실패: \(error.localizedDescription)")
                }
            }
        }

        autoBackupWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }

    // MARK: - Helper Methods

    /// Data를 CKAsset으로 변환 (대용량 데이터 저장용)
    private func createAsset(from data: Data, filename: String) throws -> CKAsset {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        try data.write(to: fileURL)

        return CKAsset(fileURL: fileURL)
    }

    /// CKAsset에서 Data 읽기
    private func readAsset(_ asset: CKAsset) throws -> Data {
        guard let fileURL = asset.fileURL else {
            throw CloudKitError.decodingFailed
        }

        return try Data(contentsOf: fileURL)
    }

    // MARK: - Backup

    /// 호출 시점에 계정 상태를 새로 확인. init의 async 콜백이 아직 돌아오지
    /// 않은 상태에서 첫 버튼 클릭으로 .notAuthenticated 오탐이 나던 race를 제거.
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
            let (memos, smartClipboard, combos) = try loadDataForBackup()
            let (memosData, smartClipboardData, combosData) = try encodeDataForBackup(
                memos: memos, smartClipboard: smartClipboard, combos: combos
            )
            var record = try await fetchOrCreateRecord()
            try configureRecord(&record, memosData: memosData, smartClipboardData: smartClipboardData, combosData: combosData)

            _ = try await saveRecordWithRetry(record, maxRetries: 3)

            let backupDate = Date()
            await MainActor.run { saveLastBackupDate(backupDate) }
            print("✅ [CloudKit] 백업 완료: \(backupDate)")

        } catch let error as CKError {
            print("❌ [CloudKit] 백업 실패: \(error)")
            print("   코드: \(error.code.rawValue)")
            print("   설명: \(error.localizedDescription)")
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? Error {
                print("   Underlying Error: \(underlyingError)")
            }
            throw CloudKitError.backupFailed(error)
        } catch {
            print("❌ [CloudKit] 백업 실패 (일반 에러): \(error)")
            throw CloudKitError.backupFailed(error)
        }
    }

    private func loadDataForBackup() throws -> (memos: [Memo], smartClipboard: [SmartClipboardHistory], combos: [Combo]) {
        let memos = try MemoStore.shared.load(type: .tokenMemo)
        let smartClipboard = try MemoStore.shared.loadSmartClipboardHistory()
        let combos = try MemoStore.shared.loadCombos()
        print("📦 [CloudKit] 백업할 메모: \(memos.count)개")
        print("📦 [CloudKit] 백업할 스마트 클립보드: \(smartClipboard.count)개")
        print("📦 [CloudKit] 백업할 Combo: \(combos.count)개")
        return (memos, smartClipboard, combos)
    }

    private func encodeDataForBackup(
        memos: [Memo], smartClipboard: [SmartClipboardHistory], combos: [Combo]
    ) throws -> (memosData: Data, smartClipboardData: Data, combosData: Data) {
        guard let memosData = try? JSONEncoder().encode(memos),
              let smartClipboardData = try? JSONEncoder().encode(smartClipboard),
              let combosData = try? JSONEncoder().encode(combos) else {
            print("❌ [CloudKit] JSON 인코딩 실패")
            throw CloudKitError.encodingFailed
        }
        print("📊 [CloudKit] 메모 데이터 크기: \(ByteCountFormatter.string(fromByteCount: Int64(memosData.count), countStyle: .file))")
        print("📊 [CloudKit] 스마트 클립보드 크기: \(ByteCountFormatter.string(fromByteCount: Int64(smartClipboardData.count), countStyle: .file))")
        print("📊 [CloudKit] Combo 데이터 크기: \(ByteCountFormatter.string(fromByteCount: Int64(combosData.count), countStyle: .file))")
        return (memosData, smartClipboardData, combosData)
    }

    private func fetchOrCreateRecord() async throws -> CKRecord {
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

    private func configureRecord(_ record: inout CKRecord, memosData: Data, smartClipboardData: Data, combosData: Data) throws {
        record["memosAsset"] = try createAsset(from: memosData, filename: "memos.json")
        record["smartClipboardAsset"] = try createAsset(from: smartClipboardData, filename: "smartClipboard.json")
        record["combosAsset"] = try createAsset(from: combosData, filename: "combos.json")
        record["backupDate"] = Date() as CKRecordValue
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        record["version"] = appVersion as CKRecordValue
        print("💾 [CloudKit] 레코드 데이터 업데이트 완료")
    }

    /// 재시도 로직이 포함된 레코드 저장
    private func saveRecordWithRetry(_ record: CKRecord, maxRetries: Int) async throws -> CKRecord {
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                print("💾 [CloudKit] 저장 시도 \(attempt)/\(maxRetries)...")
                let savedRecord = try await privateDatabase.save(record)
                print("✅ [CloudKit] 저장 성공 (시도 \(attempt))")
                return savedRecord
            } catch let error as CKError {
                lastError = error
                print("⚠️ [CloudKit] 저장 실패 (시도 \(attempt)): \(error.code.rawValue)")

                // 재시도 가능한 에러인지 확인
                switch error.code {
                case .networkUnavailable, .networkFailure, .serviceUnavailable, .zoneBusy, .requestRateLimited:
                    if attempt < maxRetries {
                        // 지수 백오프: 1초, 2초, 4초
                        let delay = UInt64(pow(2.0, Double(attempt - 1)) * 1_000_000_000)
                        print("   ⏳ \(attempt)초 후 재시도...")
                        try await Task.sleep(nanoseconds: delay)
                        continue
                    }
                default:
                    // 재시도 불가능한 에러는 즉시 throw
                    throw error
                }
            } catch {
                lastError = error
                throw error
            }
        }

        // 모든 재시도 실패
        throw lastError ?? CloudKitError.backupFailed(NSError(domain: "CloudKitBackup", code: -1))
    }

    // MARK: - Restore

    /// 로컬에 데이터가 있는지 확인
    func hasLocalData() -> Bool {
        do {
            let memos = try MemoStore.shared.load(type: .tokenMemo)
            let smartClipboard = try MemoStore.shared.loadSmartClipboardHistory()
            let combos = try MemoStore.shared.loadCombos()

            let totalCount = memos.count + smartClipboard.count + combos.count
            print("📊 [CloudKit] 로컬 데이터 확인: 메모 \(memos.count)개, 클립보드 \(smartClipboard.count)개, Combo \(combos.count)개")

            return totalCount > 0
        } catch {
            print("⚠️ [CloudKit] 로컬 데이터 확인 실패: \(error)")
            return false
        }
    }

    /// 복원 (기존 데이터 덮어쓰기 여부를 외부에서 확인 필요)
    /// - Parameter forceOverwrite: true면 확인 없이 덮어쓰기, false면 호출 전에 hasLocalData()로 확인 필요
    func restoreData(forceOverwrite: Bool = false) async throws {
        print("☁️ [CloudKit] 복구 시작...")

        try await ensureAuthenticated()

        if !forceOverwrite && hasLocalData() {
            print("⚠️ [CloudKit] 기존 데이터 존재 - 사용자 확인 필요")
            throw CloudKitError.restoreFailed(
                NSError(domain: "CloudKitBackup", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString(
                        "기존 데이터가 있습니다. 복원하면 현재 데이터가 모두 삭제됩니다. 계속하시겠습니까?",
                        comment: "Restore confirmation message"
                    )
                ])
            )
        }

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

    // MARK: - restoreData Helpers

    private func fetchMemos(from record: CKRecord) throws -> [Memo] {
        var memosData: Data?

        if let asset = record["memosAsset"] as? CKAsset {
            memosData = try? readAsset(asset)
            print("📦 [CloudKit] 메모 데이터 (Asset): \(memosData != nil ? "성공" : "실패")")
        }
        if memosData == nil, let legacyData = record["memos"] as? Data {
            memosData = legacyData
            print("📦 [CloudKit] 메모 데이터 (레거시): 성공")
        }

        guard let data = memosData else {
            print("❌ [CloudKit] 메모 데이터 없음")
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
        if let asset = record["smartClipboardAsset"] as? CKAsset,
           let data = try? readAsset(asset),
           let decoded = try? JSONDecoder().decode([SmartClipboardHistory].self, from: data) {
            print("📦 [CloudKit] 복구할 스마트 클립보드 (Asset): \(decoded.count)개")
            return decoded
        }
        if let legacyData = record["smartClipboardHistory"] as? Data,
           let decoded = try? JSONDecoder().decode([SmartClipboardHistory].self, from: legacyData) {
            print("📦 [CloudKit] 복구할 스마트 클립보드 (레거시): \(decoded.count)개")
            return decoded
        }
        print("ℹ️ [CloudKit] 스마트 클립보드 데이터 없음")
        return []
    }

    private func fetchCombos(from record: CKRecord) -> [Combo] {
        if let asset = record["combosAsset"] as? CKAsset,
           let data = try? readAsset(asset),
           let decoded = try? JSONDecoder().decode([Combo].self, from: data) {
            print("📦 [CloudKit] 복구할 Combo (Asset): \(decoded.count)개")
            return decoded
        }
        if let legacyData = record["combos"] as? Data,
           let decoded = try? JSONDecoder().decode([Combo].self, from: legacyData) {
            print("📦 [CloudKit] 복구할 Combo (레거시): \(decoded.count)개")
            return decoded
        }
        print("ℹ️ [CloudKit] Combo 데이터 없음")
        return []
    }

    private func saveRestoredData(
        memos: [Memo],
        smartClipboard: [SmartClipboardHistory],
        combos: [Combo]
    ) throws {
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
