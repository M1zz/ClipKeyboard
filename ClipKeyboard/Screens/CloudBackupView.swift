//
//  CloudBackupView.swift
//  Token memo
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

    var body: some View {
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
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 8)

                if !backupService.isAuthenticated {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("iCloud에 로그인하세요", comment: "iCloud login prompt"))
                            .font(.subheadline)
                            .foregroundColor(.orange)

                        Text(NSLocalizedString("설정 > [사용자 이름] > iCloud에서 로그인할 수 있습니다.", comment: "iCloud login instruction"))
                            .font(.caption)
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
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(lastBackup, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "checkmark.circle.fill")
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
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(NSLocalizedString("백업 정보", comment: "Backup information section header"))
                }

                // 백업 작업 섹션
                Section {
                    // 백업 버튼
                    Button {
                        performBackup()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.doc.fill")
                                .foregroundColor(.blue)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("백업하기", comment: "Backup button label"))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(NSLocalizedString("현재 데이터를 iCloud에 백업합니다", comment: "Backup button description"))
                                    .font(.caption)
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
                            Image(systemName: "arrow.down.doc.fill")
                                .foregroundColor(.green)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("복구하기", comment: "Restore button label"))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(NSLocalizedString("iCloud에서 데이터를 복구합니다", comment: "Restore button description"))
                                    .font(.caption)
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

                    // 백업 삭제 버튼
                    if backupService.lastBackupDate != nil {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(NSLocalizedString("백업 삭제", comment: "Delete backup button label"))
                                        .font(.headline)
                                    Text(NSLocalizedString("iCloud의 백업 데이터를 삭제합니다", comment: "Delete backup button description"))
                                        .font(.caption)
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
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                }
            }
        }
        .navigationTitle(NSLocalizedString("iCloud 백업", comment: "iCloud backup navigation title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
            Text(NSLocalizedString("현재 데이터가 백업 데이터로 교체됩니다. 계속하시겠습니까?", comment: "Restore confirmation message"))
        }
        .confirmationDialog(NSLocalizedString("백업 삭제", comment: "Delete backup dialog title"), isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(NSLocalizedString("삭제", comment: "Delete button"), role: .destructive) {
                performDelete()
            }
            Button(NSLocalizedString("취소", comment: "Cancel button"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("iCloud의 백업 데이터를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.", comment: "Delete confirmation message"))
        }
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
                try await backupService.restoreData()
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

struct CloudBackupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CloudBackupView()
        }
    }
}
