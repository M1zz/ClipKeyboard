//
//  FeedbackInboxView.swift
//  ClipKeyboard
//
//  개발자 전용 피드백 인박스 (마스터 모드) — CloudKit Public DB의 Feedback 레코드를
//  앱 안에서 바로 확인한다. 설정 > 앱 정보의 버전 행을 7번 탭하면 진입점이 나타난다.
//
//  ⚠️ 다른 사용자의 레코드를 읽으려면 CloudKit Dashboard에서 admin 역할을 만들어
//  read 권한과 본인 userRecordName을 등록해야 한다 (docs/FEEDBACK_CLOUDKIT.md).
//

import SwiftUI

struct FeedbackInboxView: View {
    @Environment(\.appTheme) private var theme

    @State private var records: [FeedbackService.FeedbackRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var userRecordName: String?
    @State private var didCopyId = false
    @State private var pendingDelete: FeedbackService.FeedbackRecord?

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("yyMMdjmm")
        return f
    }

    var body: some View {
        List {
            if isLoading && records.isEmpty {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(NSLocalizedString("불러오는 중…", comment: "Feedback inbox loading"))
                            .font(.body)
                            .foregroundColor(theme.textMuted)
                    }
                }
            } else if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: AppSymbol.xmarkCircleFill)
                        .font(.body)
                        .foregroundColor(.red)
                } footer: {
                    Text(NSLocalizedString("권한 오류라면 CloudKit Dashboard에서 admin 역할에 read 권한과 아래 사용자 ID를 등록했는지 확인하세요.", comment: "Feedback inbox permission hint"))
                        .font(.body)
                }
            } else if records.isEmpty {
                Section {
                    Text(NSLocalizedString("아직 접수된 피드백이 없어요", comment: "Feedback inbox empty"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
            } else {
                Section {
                    ForEach(records) { record in
                        recordRow(record)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    toggleDone(record)
                                } label: {
                                    Label(record.isDone
                                          ? NSLocalizedString("완료 해제", comment: "Feedback inbox: unmark done")
                                          : NSLocalizedString("완료 표시", comment: "Feedback inbox: mark done"),
                                          systemImage: record.isDone ? "arrow.uturn.backward" : "checkmark")
                                }
                                .tint(record.isDone ? .orange : .green)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    pendingDelete = record
                                } label: {
                                    Label(NSLocalizedString("삭제", comment: "Delete"), systemImage: AppSymbol.trash)
                                }
                            }
                    }
                } header: {
                    Text(String(format: NSLocalizedString("접수 %d건 · 완료 %d건", comment: "Feedback inbox count header (total, done)"),
                                records.count, records.filter(\.isDone).count))
                } footer: {
                    Text(NSLocalizedString("왼쪽으로 밀면 삭제, 오른쪽으로 밀면 완료 표시. 완료/삭제는 CloudKit admin 역할에 쓰기 권한이 있어야 반영돼요.", comment: "Feedback inbox actions footer"))
                        .font(.body)
                }
            }

            // Dashboard admin 역할 등록용 내 사용자 ID
            if let userRecordName {
                Section {
                    Button {
                        UIPasteboard.general.string = userRecordName
                        withAnimation { didCopyId = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { didCopyId = false }
                        }
                    } label: {
                        HStack {
                            Text(userRecordName)
                                .font(.caption.monospaced())
                                .foregroundColor(theme.textMuted)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Image(systemName: didCopyId ? AppSymbol.checkmarkCircleFill : "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(didCopyId ? .green : theme.accent)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("내 사용자 ID", comment: "Feedback inbox: my user record id header"))
                } footer: {
                    Text(NSLocalizedString("CloudKit Dashboard의 admin 역할에 이 ID를 추가하면 앱에서 모든 피드백을 읽을 수 있어요. 탭하면 복사됩니다.", comment: "Feedback inbox: user record id footer"))
                        .font(.body)
                }
            }
        }
        .navigationTitle(NSLocalizedString("접수된 피드백", comment: "Feedback inbox title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .solidNavBar(theme.bg)
        .refreshable { await load() }
        .task { await load() }
        .alert(
            NSLocalizedString("이 피드백을 삭제할까요?", comment: "Feedback inbox delete confirm title"),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button(NSLocalizedString("삭제", comment: "Delete"), role: .destructive) {
                if let record = pendingDelete { deleteRecord(record) }
                pendingDelete = nil
            }
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { pendingDelete = nil }
        } message: {
            Text(NSLocalizedString("서버에서 완전히 삭제되며 되돌릴 수 없어요.", comment: "Feedback inbox delete confirm message"))
        }
    }

    private func recordRow(_ record: FeedbackService.FeedbackRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                let type = FeedbackType(rawValue: record.type)
                Image(systemName: record.isDone ? AppSymbol.checkmarkCircleFill : (type?.icon ?? "ellipsis.bubble"))
                    .font(.caption)
                    .foregroundColor(record.isDone ? .green : theme.accent)
                    .accessibilityHidden(true)
                Text(type?.localizedName ?? record.type)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(record.isDone ? theme.textMuted : theme.accent)
                if record.isDone {
                    Text(NSLocalizedString("완료", comment: "Feedback inbox: done badge"))
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }
                Spacer()
                if let createdAt = record.createdAt {
                    Text(dateFormatter.string(from: createdAt))
                        .font(.caption2)
                        .foregroundColor(theme.textFaint)
                }
            }

            Text(record.message)
                .font(.body)
                .foregroundColor(record.isDone ? theme.textMuted : theme.text)
                .textSelection(.enabled)

            Text(record.deviceInfo.isEmpty
                 ? "\(record.appVersion) · \(record.platform) · \(record.locale)"
                 : "\(record.deviceInfo) · \(record.locale)")
                .font(.caption2)
                .foregroundColor(theme.textFaint)
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if userRecordName == nil {
            userRecordName = await FeedbackService.shared.currentUserRecordName()
        }
        do {
            records = try await FeedbackService.shared.fetchAll()
        } catch {
            print("❌ [FeedbackInboxView.load] \(error)")
            errorMessage = String(format: NSLocalizedString("피드백을 불러오지 못했어요: %@", comment: "Feedback inbox load error"), error.localizedDescription)
        }
    }

    /// 완료/미완료 토글 — 서버 반영 후 로컬 목록 갱신. 실패 시 에러 표시(권한 안내 포함).
    private func toggleDone(_ record: FeedbackService.FeedbackRecord) {
        Task {
            do {
                try await FeedbackService.shared.setDone(recordName: record.id, done: !record.isDone)
                if let index = records.firstIndex(where: { $0.id == record.id }) {
                    records[index].status = record.isDone ? nil : "done"
                }
            } catch {
                print("❌ [FeedbackInboxView.toggleDone] \(error)")
                errorMessage = String(format: NSLocalizedString("처리하지 못했어요: %@", comment: "Feedback inbox action error"), error.localizedDescription)
            }
        }
    }

    /// 서버에서 레코드 삭제 후 로컬 목록에서 제거.
    private func deleteRecord(_ record: FeedbackService.FeedbackRecord) {
        Task {
            do {
                try await FeedbackService.shared.delete(recordName: record.id)
                records.removeAll { $0.id == record.id }
            } catch {
                print("❌ [FeedbackInboxView.deleteRecord] \(error)")
                errorMessage = String(format: NSLocalizedString("처리하지 못했어요: %@", comment: "Feedback inbox action error"), error.localizedDescription)
            }
        }
    }
}
