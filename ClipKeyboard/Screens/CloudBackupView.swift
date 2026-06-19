//
//  CloudBackupView.swift
//  ClipKeyboard
//
//  Created by Claude on 2025-11-28.
//

import SwiftUI

struct CloudBackupView: View {
    @StateObject private var backupService = CloudKitBackupService.shared
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showRestoreConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showPaywall = false
    @Environment(\.appTheme) private var theme

    var body: some View {
        if !ProFeatureManager.isCloudBackupAvailable {
            // 무료 유저: Pro 유도
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: AppSymbol.icloudFill)
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text(NSLocalizedString("iCloud 백업은 Pro 기능입니다", comment: "Cloud backup pro"))
                    .font(.title3)
                    .fontWeight(.medium)
                Text(NSLocalizedString("한번 구매로 데이터를 안전하게 백업하세요", comment: "Cloud backup pro desc"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    showPaywall = true
                } label: {
                    Text(NSLocalizedString("Pro 업그레이드", comment: "Upgrade"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(height: 50)
                        .frame(maxWidth: 240)
                        .background(.orange.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                }
                Spacer()
            }
            .navigationTitle(NSLocalizedString("백업 및 복원", comment: "Backup and restore"))
            .paywall(isPresented: $showPaywall, triggeredBy: .cloudBackup)
        } else {
        List {
            // iCloud 상태 섹션
            Section {
                HStack {
                    Image(systemName: backupService.isAuthenticated ? "checkmark.icloud.fill" : "xmark.icloud.fill")
                        .foregroundColor(backupService.isAuthenticated ? .green : .red)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("iCloud 상태", comment: "iCloud status label"))
                            .font(.headline)
                        Text(backupService.isAuthenticated ? NSLocalizedString("연결됨", comment: "Connected status") : NSLocalizedString("연결 안 됨", comment: "Disconnected status"))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 8)

                if !backupService.isAuthenticated {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("iCloud에 로그인하세요", comment: "iCloud login prompt"))
                            .font(.body)
                            .foregroundColor(.orange)

                        Text(NSLocalizedString("설정 > [사용자 이름] > iCloud에서 로그인할 수 있습니다.", comment: "iCloud login instruction"))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text(NSLocalizedString("연결 상태", comment: "Connection status section header"))
            }

            // 백업 정보 섹션
            if backupService.isAuthenticated {
                Section {
                    if let lastBackup = backupService.lastBackupDate {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("마지막 백업", comment: "Last backup label"))
                                    .font(.headline)
                                Text(lastBackup, style: .relative)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                Text(lastBackup, style: .date)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: AppSymbol.checkmarkCircleFill)
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("백업 없음", comment: "No backup label"))
                                    .font(.headline)
                                Text(NSLocalizedString("데이터를 백업하지 않았습니다", comment: "No backup description"))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: AppSymbol.exclamationmarkCircleFill)
                                .foregroundColor(.orange)
                                .font(.title2)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(NSLocalizedString("백업 정보", comment: "Backup information section header"))
                }

                // 자동 백업 섹션
                Section {
                    Toggle(isOn: Binding(
                        get: { backupService.autoBackupEnabled },
                        set: { newValue in
                            if newValue {
                                backupService.enableAutoBackup()
                            } else {
                                backupService.disableAutoBackup()
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("자동 백업", comment: "Auto backup label"))
                                .font(.headline)
                            Text(NSLocalizedString("데이터 변경 시 자동으로 백업합니다", comment: "Auto backup description"))
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(NSLocalizedString("자동 백업 설정", comment: "Auto backup settings section header"))
                } footer: {
                    Text(NSLocalizedString("• 자동 백업이 활성화되면 메모, 클립보드, 콤보 변경 시 자동으로 백업됩니다\n• 5분마다 정기적으로 백업이 실행됩니다", comment: "Auto backup info"))
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                // 백업 작업 섹션
                Section {
                    // 백업 버튼
                    Button {
                        performBackup()
                    } label: {
                        HStack {
                            Image(systemName: AppSymbol.arrowUpDocFill)
                                .foregroundColor(.blue)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("백업하기", comment: "Backup button label"))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(NSLocalizedString("현재 데이터를 iCloud에 백업합니다", comment: "Backup button description"))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if backupService.isBackingUp {
                                ProgressView()
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .disabled(backupService.isBackingUp || backupService.isRestoring)

                    // 복구 버튼
                    Button {
                        showRestoreConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: AppSymbol.arrowDownDocFill)
                                .foregroundColor(.green)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("복구하기", comment: "Restore button label"))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(NSLocalizedString("iCloud에서 데이터를 복구합니다", comment: "Restore button description"))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if backupService.isRestoring {
                                ProgressView()
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .disabled(backupService.isBackingUp || backupService.isRestoring)

                    // 버전(타임머신)에서 복원 — 날짜별 스냅샷 선택
                    NavigationLink {
                        BackupVersionsView()
                    } label: {
                        HStack {
                            Image(systemName: AppSymbol.clockArrowCirclepath)
                                .foregroundColor(.green)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("이전 버전에서 복원", comment: "Restore from a previous version"))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(NSLocalizedString("날짜별 백업에서 골라서 복원합니다", comment: "Restore from dated snapshots description"))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .disabled(backupService.isBackingUp || backupService.isRestoring)

                    // 백업 삭제 버튼
                    if backupService.lastBackupDate != nil {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: AppSymbol.trashFill)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(NSLocalizedString("백업 삭제", comment: "Delete backup button label"))
                                        .font(.headline)
                                    Text(NSLocalizedString("iCloud의 백업 데이터를 삭제합니다", comment: "Delete backup button description"))
                                        .font(.body)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .disabled(backupService.isBackingUp || backupService.isRestoring)
                    }
                } header: {
                    Text(NSLocalizedString("백업 관리", comment: "Backup management section header"))
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("• 백업은 메모와 클립보드 히스토리를 모두 포함합니다", comment: "Backup info 1"))
                        Text(NSLocalizedString("• 복구 시 현재 데이터는 백업 데이터로 교체됩니다", comment: "Backup info 2"))
                        Text(NSLocalizedString("• 백업 데이터는 iCloud에 안전하게 저장됩니다", comment: "Backup info 3"))
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                }
            }
        }
        .navigationTitle(NSLocalizedString("iCloud 백업", comment: "iCloud backup navigation title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .solidNavBar(theme.bg)
        .alert(alertTitle, isPresented: $showAlert) {
            Button(NSLocalizedString("확인", comment: "OK button"), role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(NSLocalizedString("백업 데이터 복구", comment: "Restore backup dialog title"), isPresented: $showRestoreConfirmation, titleVisibility: .visible) {
            Button(NSLocalizedString("복구", comment: "Restore button"), role: .destructive) {
                performRestore()
            }
            Button(NSLocalizedString("취소", comment: "Cancel button"), role: .cancel) { }
        } message: {
            if backupService.hasLocalData() {
                Text(NSLocalizedString("⚠️ 현재 기기에 데이터가 있습니다.\n\n복구하면 현재의 모든 메모, 클립보드, 콤보가 삭제되고 백업 데이터로 교체됩니다.\n\n이 작업은 되돌릴 수 없습니다. 계속하시겠습니까?", comment: "Restore with data warning message"))
            } else {
                Text(NSLocalizedString("백업 데이터를 복구합니다.", comment: "Restore empty device message"))
            }
        }
        .confirmationDialog(NSLocalizedString("백업 삭제", comment: "Delete backup dialog title"), isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(NSLocalizedString("삭제", comment: "Delete button"), role: .destructive) {
                performDelete()
            }
            Button(NSLocalizedString("취소", comment: "Cancel button"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("iCloud의 백업 데이터를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.", comment: "Delete confirmation message"))
        }
        } // else (Pro 유저)
    }

    // MARK: - Actions

    private func performBackup() {
        Task {
            do {
                try await backupService.backupData()
                await MainActor.run {
                    alertTitle = NSLocalizedString("백업 완료", comment: "Backup completed")
                    alertMessage = NSLocalizedString("데이터가 성공적으로 백업되었습니다.", comment: "Data successfully backed up")
                    showAlert = true
                }
            } catch let error as CloudKitError {
                await MainActor.run {
                    alertTitle = NSLocalizedString("백업 실패", comment: "Backup failed")
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = NSLocalizedString("백업 실패", comment: "Backup failed")
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }

    private func performRestore() {
        Task {
            do {
                // 사용자가 확인 대화상자에서 "복구"를 선택했으므로 forceOverwrite = true
                try await backupService.restoreData(forceOverwrite: true)
                await MainActor.run {
                    alertTitle = NSLocalizedString("복구 완료", comment: "Restore completed")
                    alertMessage = NSLocalizedString("데이터가 성공적으로 복구되었습니다. 앱을 재시작하여 변경사항을 확인하세요.", comment: "Data successfully restored")
                    showAlert = true
                }
            } catch let error as CloudKitError {
                await MainActor.run {
                    alertTitle = NSLocalizedString("복구 실패", comment: "Restore failed")
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = NSLocalizedString("복구 실패", comment: "Restore failed")
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }

    private func performDelete() {
        Task {
            do {
                try await backupService.deleteBackup()
                await MainActor.run {
                    alertTitle = NSLocalizedString("삭제 완료", comment: "Deletion completed")
                    alertMessage = NSLocalizedString("백업 데이터가 삭제되었습니다.", comment: "Backup data deleted")
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = NSLocalizedString("삭제 실패", comment: "Deletion failed")
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - 버전(타임머신) 복원 화면

/// 보관 중인 백업 스냅샷을 날짜별로 보여주고, 선택한 시점으로 복원한다.
struct BackupVersionsView: View {
    @ObservedObject private var backupService = CloudKitBackupService.shared
    @State private var snapshots: [BackupSnapshotInfo] = []
    @State private var isLoading = true
    @State private var pendingRestore: BackupSnapshotInfo?
    @State private var showConfirm = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if snapshots.isEmpty {
                Text(NSLocalizedString("저장된 버전이 없습니다", comment: "No backup versions available"))
                    .foregroundColor(.secondary)
            } else {
                Section {
                    ForEach(snapshots) { snap in
                        Button {
                            pendingRestore = snap
                            showConfirm = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(snap.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(String(format: NSLocalizedString("메모 %d개", comment: "Memo count in a backup snapshot"), snap.memoCount))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: AppSymbol.arrowDownDocFill)
                                    .foregroundColor(.green)
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(backupService.isRestoring)
                    }
                } footer: {
                    Text(NSLocalizedString("선택한 시점의 데이터로 복원됩니다. 현재 데이터는 교체됩니다.", comment: "Version restore footer"))
                }
            }
        }
        .navigationTitle(NSLocalizedString("버전에서 복원", comment: "Restore from a version — screen title"))
        .task { await load() }
        .confirmationDialog(
            NSLocalizedString("이 버전으로 복원할까요?", comment: "Restore this version confirmation"),
            isPresented: $showConfirm, titleVisibility: .visible
        ) {
            Button(NSLocalizedString("복원", comment: "Restore"), role: .destructive) {
                if let snap = pendingRestore { restore(snap) }
            }
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {}
        } message: {
            if let snap = pendingRestore {
                Text(String(format: NSLocalizedString("%@ · 메모 %d개 — 현재 데이터는 이 시점으로 교체됩니다.", comment: "Version restore confirm message"),
                            snap.date.formatted(date: .abbreviated, time: .shortened), snap.memoCount))
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button(NSLocalizedString("확인", comment: "OK")) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func load() async {
        let snaps = await backupService.listSnapshots()
        await MainActor.run {
            snapshots = snaps
            isLoading = false
        }
    }

    private func restore(_ snap: BackupSnapshotInfo) {
        Task {
            do {
                try await backupService.restoreData(forceOverwrite: true, snapshotName: snap.recordName)
                await MainActor.run {
                    NotificationCenter.default.post(name: .dataRestored, object: nil)
                    alertTitle = NSLocalizedString("복구 완료", comment: "Restore completed")
                    alertMessage = NSLocalizedString("데이터가 성공적으로 복구되었습니다. 앱을 재시작하여 변경사항을 확인하세요.", comment: "Data successfully restored")
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = NSLocalizedString("복구 실패", comment: "Restore failed")
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
}

struct CloudBackupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CloudBackupView()
        }
    }
}
