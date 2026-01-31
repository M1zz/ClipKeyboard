//
//  CloudBackupView.swift
//  TokenMemo.tap
//
//  Created by Claude on 2025-11-28.
//

import SwiftUI
import CloudKit

struct CloudBackupView: View {
    @StateObject private var cloudService = CloudKitBackupService.shared
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""

    var body: some View {
        VStack(spacing: 24) {
            // 헤더
            VStack(spacing: 8) {
                Image(systemName: "icloud.and.arrow.up.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)

                Text(NSLocalizedString("iCloud 백업 및 복구", comment: "iCloud backup and restore title"))
                    .font(.title)
                    .bold()

                Text(NSLocalizedString("데이터를 iCloud에 안전하게 백업하세요", comment: "Backup description"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)

            Divider()

            // iCloud 상태
            HStack {
                Image(systemName: cloudService.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(cloudService.isAuthenticated ? .green : .red)

                Text(NSLocalizedString("iCloud 상태:", comment: "iCloud status label"))
                    .font(.headline)

                Text(cloudService.isAuthenticated ? NSLocalizedString("연결됨", comment: "Connected status") : NSLocalizedString("연결 안 됨", comment: "Disconnected status"))
                    .foregroundStyle(cloudService.isAuthenticated ? .green : .red)

                Spacer()

                Button(NSLocalizedString("상태 확인", comment: "Check status button")) {
                    cloudService.checkAccountStatus()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            // 마지막 백업 정보
            if let lastBackupDate = cloudService.lastBackupDate {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.blue)

                    Text(NSLocalizedString("마지막 백업:", comment: "Last backup label"))
                        .font(.headline)

                    Text(lastBackupDate, style: .relative)
                        .foregroundStyle(.secondary)

                    Text(NSLocalizedString("전", comment: "ago"))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }

            Spacer()

            // 액션 버튼들
            VStack(spacing: 16) {
                Button {
                    performBackup()
                } label: {
                    HStack {
                        if cloudService.isBackingUp {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "icloud.and.arrow.up")
                        }
                        Text(cloudService.isBackingUp ? NSLocalizedString("백업 중...", comment: "Backing up status") : NSLocalizedString("백업하기", comment: "Backup button"))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!cloudService.isAuthenticated || cloudService.isBackingUp)

                Button {
                    performRestore()
                } label: {
                    HStack {
                        if cloudService.isRestoring {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "icloud.and.arrow.down")
                        }
                        Text(cloudService.isRestoring ? NSLocalizedString("복구 중...", comment: "Restoring status") : NSLocalizedString("복구하기", comment: "Restore button"))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(!cloudService.isAuthenticated || cloudService.isRestoring)

                Button {
                    performDelete()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text(NSLocalizedString("백업 삭제", comment: "Delete backup button"))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(!cloudService.isAuthenticated || cloudService.lastBackupDate == nil)
            }

            Text(NSLocalizedString("⚠️ 복구 시 현재 데이터가 백업 데이터로 교체됩니다", comment: "Restore warning"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom)
        }
        .padding(30)
        .frame(minWidth: 500, minHeight: 500)
        .alert(alertTitle, isPresented: $showAlert) {
            Button(NSLocalizedString("확인", comment: "OK button"), role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Actions

    private func performBackup() {
        Task {
            do {
                try await cloudService.backupData()
                await MainActor.run {
                    alertTitle = NSLocalizedString("백업 완료", comment: "Backup completed")
                    alertMessage = NSLocalizedString("데이터가 iCloud에 성공적으로 백업되었습니다.", comment: "Data successfully backed up to iCloud")
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
                try await cloudService.restoreData()
                await MainActor.run {
                    alertTitle = NSLocalizedString("복구 완료", comment: "Restore completed")
                    alertMessage = NSLocalizedString("백업 데이터가 성공적으로 복구되었습니다.", comment: "Backup data successfully restored")
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
                try await cloudService.deleteBackup()
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

#Preview {
    CloudBackupView()
}
