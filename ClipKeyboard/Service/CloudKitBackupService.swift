//
//  CloudKitBackupService.swift
//  ClipKeyboard
//
//  Created by Claude on 2025-11-28.
//

import Foundation
import CloudKit
import Combine

/// 백업 시도의 실제 결과. "백업했다"고 뭉뚱그리지 않고, 실제로 올라간 개수/건너뛴
/// 이유를 사용자에게 정확히 알려 조용한 실패(성공처럼 보이는 무동작)를 없앤다.
enum BackupOutcome {
    case backedUp(memoCount: Int)
    case nothingToBackUp
    case skippedToProtectExisting(existing: Int, new: Int)
}

enum CloudKitError: Error {
    case notAuthenticated
    case backupFailed(Error)
    case restoreFailed(Error)
    case noBackupFound
    case encodingFailed
    case decodingFailed
    /// 이 백업이 기존 백업을 빈/훨씬 적은 데이터로 덮어써 데이터 손실 위험이 있을 때(수동 백업에서 사용자 동의 필요).
    case backupWouldReduceData(existing: Int, new: Int)

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
        case .backupWouldReduceData(let existing, let new):
            return String(format: NSLocalizedString("기존 백업(메모 %1$d개)을 %2$d개로 덮어쓰려고 합니다. 줄어든 데이터는 백업에서 사라집니다.", comment: "Backup would reduce data warning"), existing, new)
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

// MARK: - CloudKit Database 추상화 (테스트 주입용)

/// CloudKit private DB 중 백업이 쓰는 연산만 추상화. 실제 CKDatabase가 그대로 채택하고,
/// 테스트는 인메모리 mock을 주입해 네트워크 없이 백업/복원 전 경로의 무결성을 검증한다.
protocol CloudKitBackupDatabase {
    func record(for recordID: CKRecord.ID) async throws -> CKRecord
    @discardableResult func save(_ record: CKRecord) async throws -> CKRecord
    @discardableResult func deleteRecord(withID recordID: CKRecord.ID) async throws -> CKRecord.ID
}

extension CKDatabase: CloudKitBackupDatabase {}

/// 버전 백업(타임머신) 한 항목의 메타데이터 — 복원 화면의 날짜별 목록에 쓰인다.
struct BackupSnapshotInfo: Codable, Identifiable, Equatable {
    var id: String { recordName }
    let recordName: String
    let date: Date
    let memoCount: Int
}

class CloudKitBackupService: ObservableObject {
    static let shared = CloudKitBackupService()

    private let container: CKContainer?
    private let database: CloudKitBackupDatabase
    private let fetchAccountStatus: () async throws -> CKAccountStatus

    @Published var isAuthenticated: Bool = false
    @Published var lastBackupDate: Date?
    @Published var isBackingUp: Bool = false
    @Published var isRestoring: Bool = false
    @Published var autoBackupEnabled: Bool = false

    private var autoBackupTimer: Timer?
    private let autoBackupInterval: TimeInterval = 300 // 5분마다 자동 백업

    // MARK: - Version Snapshots (타임머신)
    /// 스냅샷 목록(이름·날짜·개수)을 담는 인덱스 레코드. CKQuery 없이 단일 레코드 fetch로 목록을 읽는다.
    private let snapshotIndexRecordID = CKRecord.ID(recordName: "TokenMemoBackupIndex")
    /// 보관할 최대 스냅샷 개수(이보다 오래된 건 백업 시 자동 정리).
    private let maxSnapshots = 15

    private init() {
        let container = CKContainer(identifier: "iCloud.com.Ysoup.TokenMemo")
        self.container = container
        self.database = container.privateCloudDatabase
        self.fetchAccountStatus = { try await container.accountStatus() }

        checkAccountStatus()
        loadLastBackupDate()
        loadAutoBackupSetting()

        // 데이터 변경 알림 리스너 등록
        setupDataChangeListener()
    }

    /// 테스트 전용: mock DB/계정 상태를 주입한다.
    /// 타이머·데이터 변경 리스너·초기 자동 백업 등 부작용 없이 순수 백업/복원 로직만 동작.
    init(database: CloudKitBackupDatabase,
         accountStatus: @escaping () async throws -> CKAccountStatus) {
        self.container = nil
        self.database = database
        self.fetchAccountStatus = accountStatus
    }

    deinit {
        autoBackupTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Account Status

    func checkAccountStatus() {
        guard let container else { return }
        container.accountStatus { [weak self] status, _ in
            DispatchQueue.main.async {
                self?.isAuthenticated = (status == .available)
                print("📱 [CloudKit] Account Status: \(status.rawValue)")
            }
        }
    }

    private func loadLastBackupDate() {
        if let timestamp = UserDefaults.standard.object(forKey: DefaultsKey.lastBackupDate) as? Date {
            self.lastBackupDate = timestamp
        }
    }

    private func saveLastBackupDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: DefaultsKey.lastBackupDate)
        self.lastBackupDate = date
    }

    private func loadAutoBackupSetting() {
        let defaults = UserDefaults.standard
        // 자동 백업 기본값 ON: 한 번도 설정한 적 없으면 켠다. 다른 기기(맥)에서
        // 시작 시 바로 복원할 수 있도록 항상 최신 백업이 존재하게 한다.
        // 이미 켜거나 끈 사용자의 명시적 선택은 그대로 존중한다.
        if defaults.object(forKey: DefaultsKey.autoBackupEnabled) == nil {
            defaults.set(true, forKey: DefaultsKey.autoBackupEnabled)
            print("🔄 [CloudKit] 자동 백업 기본 활성화 (최초 실행)")
        }
        self.autoBackupEnabled = defaults.bool(forKey: DefaultsKey.autoBackupEnabled)
        if autoBackupEnabled {
            startAutoBackupTimer()
            performInitialBackupIfNeeded()
        }
    }

    /// 시작 직후 최신 백업을 한 번 보장한다 — 맥/다른 기기가 바로 복원할 수 있게.
    /// 인증이 확정될 때까지 잠깐 대기하고, 최근(1시간 내) 백업이 있으면 생략한다.
    private func performInitialBackupIfNeeded() {
        Task { [weak self] in
            guard let self else { return }
            // init의 accountStatus 콜백이 비동기라 인증 확정까지 최대 5초 대기.
            for _ in 0..<10 {
                if self.isAuthenticated { break }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            guard self.autoBackupEnabled, self.isAuthenticated, !self.isBackingUp else { return }
            if let last = self.lastBackupDate, Date().timeIntervalSince(last) < 3600 {
                print("ℹ️ [CloudKit] 최근 백업 존재 - 시작 초기 백업 생략")
                return
            }
            do {
                try await self.backupData(isAutomatic: true)
                print("✅ [CloudKit] 시작 직후 초기 백업 완료")
            } catch {
                print("⚠️ [CloudKit] 시작 초기 백업 실패: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Auto Backup

    func enableAutoBackup() {
        print("🔄 [CloudKit] 자동 백업 활성화")
        UserDefaults.standard.set(true, forKey: DefaultsKey.autoBackupEnabled)
        DispatchQueue.main.async { [weak self] in
            self?.autoBackupEnabled = true
        }
        startAutoBackupTimer()
    }

    func disableAutoBackup() {
        print("⏸️ [CloudKit] 자동 백업 비활성화")
        UserDefaults.standard.set(false, forKey: DefaultsKey.autoBackupEnabled)
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
                    try await self.backupData(isAutomatic: true)
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
            forName: Notification.Name.memoDataChanged,
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
                    try await self.backupData(isAutomatic: true)
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

    // MARK: - Image Backup (App Group Images/ ↔ CKAsset)

    /// App Group 내 이미지 폴더.
    private var imagesBackupDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent("Images")
    }

    /// 메모들이 참조하는 PNG들을 백업 레코드에 CKAsset 배열로 첨부(존재하는 파일만).
    /// 이미지가 없으면 필드를 비워 이전 백업의 잔존 이미지를 정리한다.
    private func attachImages(to record: inout CKRecord, memos: [Memo]) {
        var names = Set<String>()
        for memo in memos {
            names.formUnion(memo.imageFileNames)
            if let single = memo.imageFileName, !single.isEmpty { names.insert(single) }
        }
        guard let dir = imagesBackupDirectory else { return }
        var assets: [CKAsset] = []
        var attachedNames: [String] = []
        for name in names.sorted() {
            let url = dir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                assets.append(CKAsset(fileURL: url))
                attachedNames.append(name)
            }
        }
        if assets.isEmpty {
            record["imageAssets"] = nil
            record["imageNames"] = nil
        } else {
            record["imageAssets"] = assets as CKRecordValue
            record["imageNames"] = attachedNames as CKRecordValue
        }
        print("🖼️ [CloudKit] 백업 이미지: \(attachedNames.count)개")
    }

    /// 백업 레코드의 이미지 CKAsset들을 App Group Images/에 복원(덮어쓰기).
    private func restoreImages(from record: CKRecord) {
        guard let assets = record["imageAssets"] as? [CKAsset],
              let names = record["imageNames"] as? [String],
              let dir = imagesBackupDirectory else {
            print("ℹ️ [CloudKit] 복원할 이미지 없음")
            return
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var restored = 0
        for (asset, name) in zip(assets, names) {
            guard let src = asset.fileURL else { continue }
            let dest = dir.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: dest)   // 덮어쓰기
            do { try FileManager.default.copyItem(at: src, to: dest); restored += 1 }
            catch { print("⚠️ [CloudKit] 이미지 복원 실패 \(name): \(error)") }
        }
        print("🖼️ [CloudKit] 이미지 \(restored)개 복원 완료")
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
        let status = try await fetchAccountStatus()
        await MainActor.run { self.isAuthenticated = (status == .available) }
        guard status == .available else {
            print("⚠️ [CloudKit] accountStatus = \(status.rawValue) (not available)")
            throw CloudKitError.notAuthenticated
        }
    }

    /// - Parameters:
    ///   - isAutomatic: 자동 백업(시작/타이머/데이터변경) 여부.
    ///   - allowReduce: 기존 백업을 빈/훨씬 적은 데이터로 덮어쓰는 것을 사용자가 동의했는지(수동 백업에서 확인 후 true).
    ///
    ///   데이터 손실 방지 정책:
    ///   · 자동 백업: 기존 백업을 빈/대폭(절반 이하)으로 축소하지 못한다(조용히 건너뜀).
    ///   · 수동 백업: 같은 상황이면 `backupWouldReduceData`를 던져 **사용자 동의**를 받는다(동의 시 allowReduce=true로 재호출).
    @discardableResult
    func backupData(isAutomatic: Bool = false, allowReduce: Bool = false) async throws -> BackupOutcome {
        print("☁️ [CloudKit] 백업 시작... (자동=\(isAutomatic), 축소동의=\(allowReduce))")

        try await ensureAuthenticated()

        await MainActor.run { isBackingUp = true }
        defer { Task { @MainActor [weak self] in self?.isBackingUp = false } }

        do {
            let (memos, smartClipboard, combos) = try loadDataForBackup()

            // 시드 샘플을 제외한 "실데이터" 개수.
            let sampleIDs = SampleMemoStorage.load()
            let realMemos = memos.filter { !sampleIDs.contains($0.id) }
            let newCount = memos.count

            var record = try await fetchOrCreateRecord()
            let existingCount = Self.existingMemoCount(from: record) ?? 0

            // ⚠️ 데이터 손실 방지 정책 (백업은 단일 레코드를 덮어쓰므로):
            //  · 빈/샘플뿐 + 기존 백업 없음 → 백업할 게 없으니 건너뜀.
            //  · "파괴적"(실데이터 0 또는 기존 백업의 절반 이하로 축소) →
            //      - 자동 백업: 조용히 건너뜀(절대 기존 백업을 망가뜨리지 않음).
            //      - 수동 백업: backupWouldReduceData를 던져 사용자 동의를 받음(allowReduce로 재호출).
            let nothingReal = realMemos.isEmpty
            let drasticReduce = existingCount >= 4 && newCount * 2 < existingCount
            let destructive = nothingReal || drasticReduce

            if nothingReal && existingCount == 0 {
                print("🛑 [CloudKit] 실데이터 없음 + 기존 백업 없음 — 백업할 것 없음")
                return .nothingToBackUp
            }
            if destructive {
                if isAutomatic {
                    print("🛑 [CloudKit] 자동 백업 보호: 빈/대폭축소(기존 \(existingCount)→\(newCount)) — 건너뜀(기존 백업 보존)")
                    return .skippedToProtectExisting(existing: existingCount, new: newCount)
                }
                if !allowReduce {
                    print("⚠️ [CloudKit] 수동 백업이 기존 \(existingCount)→\(newCount)로 축소 — 사용자 동의 필요")
                    throw CloudKitError.backupWouldReduceData(existing: existingCount, new: newCount)
                }
                print("✅ [CloudKit] 사용자 동의됨 — 축소 백업 진행(\(existingCount)→\(newCount))")
            }

            let (memosData, smartClipboardData, combosData) = try encodeDataForBackup(
                memos: memos, smartClipboard: smartClipboard, combos: combos
            )
            try configureRecord(&record, memosData: memosData, smartClipboardData: smartClipboardData, combosData: combosData)
            record["memoCount"] = memos.count as CKRecordValue  // 다음 백업의 축소 가드용(저렴한 비교 필드)
            attachImages(to: &record, memos: memos)   // 첨부 이미지(PNG)도 함께 백업

            _ = try await saveRecordWithRetry(record, maxRetries: 3)

            let backupDate = Date()
            await MainActor.run { saveLastBackupDate(backupDate) }

            // 버전 스냅샷(타임머신) 보관 — 메인 백업 성공 직후 타임스탬프 스냅샷을 쌓는다.
            // 실패해도 메인 백업은 정상 처리(스냅샷은 추가 안전망일 뿐 메인 백업을 막지 않는다).
            do {
                try await writeVersionSnapshot(
                    memosData: memosData, smartClipboardData: smartClipboardData, combosData: combosData,
                    memos: memos, memoCount: memos.count, date: backupDate
                )
            } catch {
                print("⚠️ [CloudKit] 버전 스냅샷 저장 실패(메인 백업은 정상): \(error.localizedDescription)")
            }
            print("✅ [CloudKit] 백업 완료: \(backupDate)")
            return .backedUp(memoCount: memos.count)

        } catch let ckError as CloudKitError {
            // 정책상 던진 CloudKitError(backupWouldReduceData 등)는 그대로 전달(backupFailed로 감싸지 않음).
            throw ckError
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
        let memos = try MemoStore.shared.load(type: .memo)
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

    /// 기존 백업 레코드의 메모 개수. memoCount 필드(빠름) 우선, 없으면(레거시 백업) memosAsset/
    /// memos를 디코드해 센다. 알 수 없으면 nil(가드 미적용 → 통과).
    private static func existingMemoCount(from record: CKRecord) -> Int? {
        if let n = record["memoCount"] as? Int { return n }
        var data: Data?
        if let asset = record["memosAsset"] as? CKAsset, let url = asset.fileURL {
            data = try? Data(contentsOf: url)
        }
        if data == nil, let legacy = record["memos"] as? Data { data = legacy }
        guard let d = data, let memos = try? JSONDecoder().decode([Memo].self, from: d) else { return nil }
        return memos.count
    }

    private func fetchOrCreateRecord() async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: "TokenMemoBackup")
        do {
            let record = try await database.record(for: recordID)
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
                let savedRecord = try await database.save(record)
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
            let memos = try MemoStore.shared.load(type: .memo)
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
    // MARK: - Version Snapshots (타임머신)

    /// 보관 중인 버전 스냅샷 목록(최신순). 복원 화면의 날짜별 목록에 사용.
    func listSnapshots() async -> [BackupSnapshotInfo] {
        await loadSnapshotIndex()
    }

    /// 현재 iCloud 백업(최신 레코드)에 들어있는 메모 개수 — "무엇이 백업돼 있는지" 한눈에 확인용.
    func currentBackupMemoCount() async -> Int? {
        guard let record = try? await database.record(for: CKRecord.ID(recordName: "TokenMemoBackup")) else { return nil }
        return Self.existingMemoCount(from: record)
    }

    /// 메인 백업 성공 후 타임스탬프 스냅샷을 따로 저장하고, 최신 maxSnapshots개만 남기고 정리한다.
    /// 단일 레코드를 덮어쓰던 구조의 약점(이전 백업 소실)을 보완 — 잘못된 백업이 끼어도 과거로 복원 가능.
    private func writeVersionSnapshot(memosData: Data, smartClipboardData: Data, combosData: Data,
                                      memos: [Memo], memoCount: Int, date: Date) async throws {
        let snapName = "TokenMemoBackup_snap_\(UUID().uuidString)"
        var snap = CKRecord(recordType: "BackupSnapshot", recordID: CKRecord.ID(recordName: snapName))
        // 스냅샷마다 고유 파일명으로 asset 생성(임시파일 충돌 방지).
        snap["memosAsset"] = try createAsset(from: memosData, filename: "\(snapName)_memos.json")
        snap["smartClipboardAsset"] = try createAsset(from: smartClipboardData, filename: "\(snapName)_smart.json")
        snap["combosAsset"] = try createAsset(from: combosData, filename: "\(snapName)_combos.json")
        snap["backupDate"] = date as CKRecordValue
        snap["memoCount"] = memoCount as CKRecordValue
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        snap["version"] = appVersion as CKRecordValue
        attachImages(to: &snap, memos: memos)
        _ = try await saveRecordWithRetry(snap, maxRetries: 2)

        // 인덱스 갱신 + 오래된 스냅샷 정리(최신 maxSnapshots개 유지).
        var infos = await loadSnapshotIndex()
        infos.append(BackupSnapshotInfo(recordName: snapName, date: date, memoCount: memoCount))
        infos.sort { $0.date > $1.date }
        let keep = Array(infos.prefix(maxSnapshots))
        for old in infos.dropFirst(maxSnapshots) {
            try? await database.deleteRecord(withID: CKRecord.ID(recordName: old.recordName))
        }
        try await saveSnapshotIndex(keep)
        print("📚 [CloudKit] 버전 스냅샷 저장(메모 \(memoCount)개) · 보관 \(keep.count)개")
    }

    private func loadSnapshotIndex() async -> [BackupSnapshotInfo] {
        guard let record = try? await database.record(for: snapshotIndexRecordID),
              let data = record["snapshots"] as? Data,
              let infos = try? JSONDecoder().decode([BackupSnapshotInfo].self, from: data) else {
            return []
        }
        return infos.sorted { $0.date > $1.date }
    }

    private func saveSnapshotIndex(_ infos: [BackupSnapshotInfo]) async throws {
        let record = (try? await database.record(for: snapshotIndexRecordID))
            ?? CKRecord(recordType: "BackupIndex", recordID: snapshotIndexRecordID)
        record["snapshots"] = try JSONEncoder().encode(infos) as CKRecordValue
        _ = try await saveRecordWithRetry(record, maxRetries: 2)
    }

    /// - Parameter snapshotName: 특정 버전 스냅샷에서 복원할 때 그 레코드명. nil이면 최신 백업.
    func restoreData(forceOverwrite: Bool = false, snapshotName: String? = nil) async throws {
        print("☁️ [CloudKit] 복구 시작... (스냅샷=\(snapshotName ?? "최신"))")

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
        defer { Task { @MainActor [weak self] in self?.isRestoring = false } }

        do {
            let recordID = CKRecord.ID(recordName: snapshotName ?? "TokenMemoBackup")
            let record = try await database.record(for: recordID)
            print("📦 [CloudKit] 백업 레코드 찾음")
            if let version = record["version"] as? String {
                print("📦 [CloudKit] 백업 버전: \(version)")
            }

            let memos = try fetchMemos(from: record)
            let smartClipboard = fetchSmartClipboardHistory(from: record)
            let combos = fetchCombos(from: record)

            // 메모 본문을 저장하기 전에 첨부 이미지를 Images/에 먼저 복원(깨진 참조 방지).
            restoreImages(from: record)
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
        try MemoStore.shared.save(memos: memos, type: .memo)
        print("✅ [CloudKit] 메모 \(memos.count)개 저장 완료")

        if !smartClipboard.isEmpty {
            try MemoStore.shared.saveSmartClipboardHistory(history: smartClipboard)
            print("✅ [CloudKit] 스마트 클립보드 \(smartClipboard.count)개 저장 완료")
        }
        if !combos.isEmpty {
            try MemoStore.shared.saveCombos(combos)
            print("✅ [CloudKit] Combo \(combos.count)개 저장 완료")
        }

        // 옛 백업을 복원하면 레거시 포맷(combos.data / isCombo / attachedTemplateId)이 되살아날 수 있다.
        // 콤보 통합 마이그레이션 플래그를 리셋해 다음 실행 시 신 모델(childMemoIds)로 재변환되게 한다.
        // (마이그레이션은 hasLegacyComboData()로도 자동 감지하지만, 플래그 리셋으로 명시 보장.)
        UserDefaults(suiteName: AppGroup.identifier)?
            .set(false, forKey: DefaultsKey.comboModelUnifyMigratedV1)
    }

    // MARK: - Check Backup Existence

    func hasBackup() async -> Bool {
        do {
            let recordID = CKRecord.ID(recordName: "TokenMemoBackup")
            _ = try await database.record(for: recordID)
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
            _ = try await database.deleteRecord(withID: recordID)

            await MainActor.run {
                lastBackupDate = nil
                UserDefaults.standard.removeObject(forKey: DefaultsKey.lastBackupDate)
            }

            print("✅ [CloudKit] 백업 삭제 완료")
        } catch {
            print("❌ [CloudKit] 백업 삭제 실패: \(error)")
            throw error
        }
    }
}
