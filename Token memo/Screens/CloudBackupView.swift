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
                        Text("iCloud 상태")
                            .font(.headline)
                        Text(backupService.isAuthenticated ? "연결됨" : "연결 안 됨")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 8)

                if !backupService.isAuthenticated {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("iCloud에 로그인하세요")
                            .font(.subheadline)
                            .foregroundColor(.orange)

                        Text("설정 > [사용자 이름] > iCloud에서 로그인할 수 있습니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("연결 상태")
            }

            // 백업 정보 섹션
            if backupService.isAuthenticated {
                Section {
                    if let lastBackup = backupService.lastBackupDate {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("마지막 백업")
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
                                Text("백업 없음")
                                    .font(.headline)
                                Text("데이터를 백업하지 않았습니다")
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
                    Text("백업 정보")
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
                                Text("백업하기")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("현재 데이터를 iCloud에 백업합니다")
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
                                Text("복구하기")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("iCloud에서 데이터를 복구합니다")
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
                                    Text("백업 삭제")
                                        .font(.headline)
                                    Text("iCloud의 백업 데이터를 삭제합니다")
                                        .font(.caption)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .disabled(backupService.isBackingUp || backupService.isRestoring)
                    }
                } header: {
                    Text("백업 관리")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• 백업은 메모와 클립보드 히스토리를 모두 포함합니다")
                        Text("• 복구 시 현재 데이터는 백업 데이터로 교체됩니다")
                        Text("• 백업 데이터는 iCloud에 안전하게 저장됩니다")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                }
            }
        }
        .navigationTitle("iCloud 백업")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert(alertTitle, isPresented: $showAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog("백업 데이터 복구", isPresented: $showRestoreConfirmation, titleVisibility: .visible) {
            Button("복구", role: .destructive) {
                performRestore()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("현재 데이터가 백업 데이터로 교체됩니다. 계속하시겠습니까?")
        }
        .confirmationDialog("백업 삭제", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                performDelete()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("iCloud의 백업 데이터를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.")
        }
    }

    // MARK: - Actions

    private func performBackup() {
        Task {
            do {
                try await backupService.backupData()
                await MainActor.run {
                    alertTitle = "백업 완료"
                    alertMessage = "데이터가 성공적으로 백업되었습니다."
                    showAlert = true
                }
            } catch let error as CloudKitError {
                await MainActor.run {
                    alertTitle = "백업 실패"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = "백업 실패"
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
                    alertTitle = "복구 완료"
                    alertMessage = "데이터가 성공적으로 복구되었습니다. 앱을 재시작하여 변경사항을 확인하세요."
                    showAlert = true
                }
            } catch let error as CloudKitError {
                await MainActor.run {
                    alertTitle = "복구 실패"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = "복구 실패"
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
                    alertTitle = "삭제 완료"
                    alertMessage = "백업 데이터가 삭제되었습니다."
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = "삭제 실패"
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
