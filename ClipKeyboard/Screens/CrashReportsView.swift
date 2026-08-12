//
//  CrashReportsView.swift
//  ClipKeyboard
//
//  안정성 화면 - `DiagnosticsService` 가 허브에 올린 크래시·행 진단을 읽어 본다.
//  (설정 > 지원 > 안정성, 마스터 모드 전용)
//
//  수집만 하고 볼 곳이 없으면 반쪽이다. 여기서 답해야 하는 질문은 하나다:
//  **"이번 버전에서 크래시가 늘었나?"**
//  그래서 버전별 건수를 먼저 보여주고, 상세는 그 아래에 둔다.
//
//  ⚠️ MetricKit 페이로드는 하루 한 번꼴로 묶여서 온다 → 방금 난 크래시는 여기 없다.
//  ⚠️ 시뮬레이터에서는 거의 안 올라온다. 실기기 + 사용자 규모가 있어야 쌓인다.
//

import SwiftUI
import CloudKit

/// 크래시 리포트 한 건 (읽기 전용 표현).
struct CrashReportRecord: Identifiable {
    let id: String
    let kind: String          // crash / hang / disk_write
    let detail: String
    let appVersion: String
    let osVersion: String
    let deviceType: String
    let stack: String
    let createdAt: Date?

    /// 사람이 읽는 종류 이름.
    var kindLabel: String {
        switch kind {
        case "crash": return NSLocalizedString("크래시", comment: "Diagnostic kind: crash")
        case "hang": return NSLocalizedString("멈춤", comment: "Diagnostic kind: hang")
        case "disk_write": return NSLocalizedString("과도한 디스크 쓰기", comment: "Diagnostic kind: disk write")
        default: return kind
        }
    }
}

struct CrashReportsView: View {

    @Environment(\.appTheme) private var theme
    @State private var reports: [CrashReportRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading {
                HStack {
                    ProgressView()
                    Text(NSLocalizedString("불러오는 중…", comment: "Loading"))
                        .foregroundColor(theme.textMuted)
                }
            } else if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
            } else if reports.isEmpty {
                Section {
                    Text(NSLocalizedString("아직 올라온 진단이 없어요. 크래시 정보는 iOS가 하루 한 번꼴로 묶어서 보내기 때문에, 방금 난 크래시는 바로 보이지 않습니다.", comment: "Crash reports empty state"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
            } else {
                versionSection
                detailSection
            }
        }
        .navigationTitle(NSLocalizedString("안정성", comment: "Stability screen title"))
        .task { await load() }
        .refreshable { await load() }
    }

    /// 버전별 건수 - "이번 버전에서 늘었나"를 한눈에.
    private var versionSection: some View {
        let grouped = Dictionary(grouping: reports, by: \.appVersion)
            .map { (version: $0.key, count: $0.value.count) }
            .sorted { $0.version > $1.version }

        return Section {
            ForEach(grouped, id: \.version) { row in
                HStack {
                    Text(row.version).font(.body.weight(.medium)).foregroundColor(theme.text)
                    Spacer()
                    Text(String(format: NSLocalizedString("%d건", comment: "Report count"), row.count))
                        .font(.body)
                        .foregroundColor(row.count > 0 ? .orange : theme.textMuted)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text(NSLocalizedString("버전별 진단 건수", comment: "Crash reports section: per version"))
        }
    }

    private var detailSection: some View {
        Section {
            ForEach(reports.prefix(50)) { report in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(report.kindLabel).font(.body.weight(.medium)).foregroundColor(theme.text)
                        Spacer()
                        Text(report.appVersion).font(.caption).foregroundColor(theme.textMuted)
                    }
                    Text("\(report.deviceType) · iOS \(report.osVersion)")
                        .font(.caption).foregroundColor(theme.textMuted)
                    if !report.detail.isEmpty && report.detail != "-" {
                        Text(report.detail).font(.caption).foregroundColor(theme.textMuted)
                    }
                    // 콜스택은 길어서 접어둔다 - 필요할 때만 펼쳐 본다.
                    DisclosureGroup(NSLocalizedString("콜스택", comment: "Call stack disclosure")) {
                        Text(report.stack)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(theme.textMuted)
                            .textSelection(.enabled)
                    }
                    .font(.caption)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text(NSLocalizedString("최근 진단", comment: "Crash reports section: recent"))
        } footer: {
            Text(NSLocalizedString("MetricKit이 보내주는 익명 진단이에요. 콜스택·앱 버전·OS만 담기고 사용자 정보는 들어가지 않습니다.", comment: "Crash reports footer"))
                .font(.body)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            reports = try await CrashReportReader.fetch()
        } catch let error where CrashReportReader.isSchemaNotReady(error) {
            // 서버 원문("Did not find record type: CrashReport")을 그대로 띄우면
            // 앱이 고장난 것처럼 보인다. 무엇을 해야 하는지로 바꿔 말한다.
            reports = []
            errorMessage = NSLocalizedString("진단 스키마가 아직 허브에 배포되지 않았어요. CloudKit Console 에서 CrashReport 레코드 타입과 인덱스를 배포하면 여기에 쌓입니다.", comment: "Crash reports schema not deployed")
            AppLog.warning(.diagnostics, "⚠️ [CrashReportsView.load] CrashReport 스키마 미배포: \(error.localizedDescription)")
        } catch {
            errorMessage = String(format: NSLocalizedString("불러오지 못했어요: %@", comment: "Crash reports load failure"),
                                  error.localizedDescription)
        }
        isLoading = false
    }
}

/// 허브에서 크래시 리포트를 읽는다.
/// ⚠️ `DiagnosticsService`(MetricKit 의존, iOS 전용)와 분리해 둔다
///    조회는 맥 카탈리스트에서도 되어야 하고, 수집과 조회는 수명주기가 다르다.
enum CrashReportReader {

    /// 허브에 `CrashReport` 레코드 타입(또는 조회에 필요한 인덱스)이 아직 없는 상태인가.
    ///
    /// CloudKit 은 **저장이 성공할 때만, 그것도 development 환경에서만** 레코드 타입을 만든다.
    /// 진단이 한 건도 안 올라온 컨테이너에서는 조회가 `unknownItem`("Did not find record type")으로,
    /// 타입은 있는데 인덱스가 없으면 `invalidArguments`("not marked queryable")로 실패한다.
    /// 둘 다 앱 버그가 아니라 스키마 배포가 안 끝난 상태다.
    static func isSchemaNotReady(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        return ckError.code == .unknownItem || ckError.code == .invalidArguments
    }

    static func fetch(limit: Int = 200) async throws -> [CrashReportRecord] {
        let config = ClipKeyboardSpec.feedback
        let database = CKContainer(identifier: config.containerIdentifier).publicCloudDatabase

        // 통계 조회와 같은 방식 - appId 인덱스 없이 클라이언트에서 거른다.
        let query = CKQuery(recordType: "CrashReport", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let page = try await database.records(matching: query, resultsLimit: limit)
        return page.matchResults.compactMap { try? $0.1.get() }
            .filter { config.appIdentifier == nil || ($0["appId"] as? String) == config.appIdentifier }
            .map { record in
                CrashReportRecord(
                    id: record.recordID.recordName,
                    kind: record["kind"] as? String ?? "-",
                    detail: record["detail"] as? String ?? "-",
                    appVersion: record["appVersion"] as? String ?? "-",
                    osVersion: record["osVersion"] as? String ?? "-",
                    deviceType: record["deviceType"] as? String ?? "-",
                    stack: record["stack"] as? String ?? "",
                    createdAt: record.creationDate
                )
            }
    }
}
