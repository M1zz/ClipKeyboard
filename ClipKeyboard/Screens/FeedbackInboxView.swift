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
                    }
                } header: {
                    Text(String(format: NSLocalizedString("접수 %d건", comment: "Feedback inbox count header"), records.count))
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
    }

    private func recordRow(_ record: FeedbackService.FeedbackRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                let type = FeedbackType(rawValue: record.type)
                Image(systemName: type?.icon ?? "ellipsis.bubble")
                    .font(.caption)
                    .foregroundColor(theme.accent)
                    .accessibilityHidden(true)
                Text(type?.localizedName ?? record.type)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.accent)
                Spacer()
                if let createdAt = record.createdAt {
                    Text(dateFormatter.string(from: createdAt))
                        .font(.caption2)
                        .foregroundColor(theme.textFaint)
                }
            }

            Text(record.message)
                .font(.body)
                .foregroundColor(theme.text)
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
}
