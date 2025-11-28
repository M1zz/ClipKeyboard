//
//  CloudBackupView.swift
//  TokenMemo.mac
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

                Text("iCloud 백업 및 복구")
                    .font(.title)
                    .bold()

                Text("데이터를 iCloud에 안전하게 백업하세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)

            Divider()

            // iCloud 상태
            HStack {
                Image(systemName: cloudService.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(cloudService.isAuthenticated ? .green : .red)

                Text("iCloud 상태:")
                    .font(.headline)

                Text(cloudService.isAuthenticated ? "연결됨" : "연결 안 됨")
                    .foregroundStyle(cloudService.isAuthenticated ? .green : .red)

                Spacer()

                Button("상태 확인") {
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

                    Text("마지막 백업:")
                        .font(.headline)

                    Text(lastBackupDate, style: .relative)
                        .foregroundStyle(.secondary)

                    Text("전")
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
                        Text(cloudService.isBackingUp ? "백업 중..." : "백업하기")
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
                        Text(cloudService.isRestoring ? "복구 중..." : "복구하기")
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
                        Text("백업 삭제")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(!cloudService.isAuthenticated || cloudService.lastBackupDate == nil)
            }

            Text("⚠️ 복구 시 현재 데이터가 백업 데이터로 교체됩니다")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom)
        }
        .padding(30)
        .frame(minWidth: 500, minHeight: 500)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("확인", role: .cancel) {}
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
                    alertTitle = "백업 완료"
                    alertMessage = "데이터가 iCloud에 성공적으로 백업되었습니다."
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
                try await cloudService.restoreData()
                await MainActor.run {
                    alertTitle = "복구 완료"
                    alertMessage = "백업 데이터가 성공적으로 복구되었습니다."
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
                try await cloudService.deleteBackup()
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

#Preview {
    CloudBackupView()
}
