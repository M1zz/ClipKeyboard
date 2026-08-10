//
//  DiagnosticsService.swift
//  ClipKeyboard
//
//  크래시·행(hang)·성능 가시성 - MetricKit으로 받아 FeedbackHub에 쌓는다.
//
//  왜 Sentry/Crashlytics가 아닌가
//   · 외부 SDK 0개 원칙을 유지한다(개인정보 신고 항목이 늘지 않고, SDK 자체의 수집도 없다).
//   · 피드백·통계가 쓰는 CloudKit 공개 DB가 이미 있어 새 인프라 비용이 사실상 0이다.
//   · **키보드 익스텐션의 메모리 종료(jetsam)까지 잡힌다** - 이 앱에서 가장 위험한 실패
//     모드이고, 서드파티 SDK를 익스텐션에 넣는 건 메모리 예산상 부담이 크다.
//
//  한계 (알고 쓰는 것)
//   · MetricKit 페이로드는 하루 한 번꼴로 **묶여서** 온다 → 실시간 알림용이 아니다.
//     "어제 이 버전에서 크래시가 늘었나"를 보는 용도다.
//   · 시뮬레이터에서는 거의 오지 않는다. 실기기 + 사용자 규모가 있어야 데이터가 쌓인다.
//   · iOS 전용. Mac Catalyst 에서는 MetricKit 진단 페이로드를 주지 않아 비활성이다.
//
//  ⚠️ 개인정보: 콜스택·앱 버전·OS 버전만 보낸다. 사용자 데이터나 식별자는 넣지 않는다.
//     (설치 UUID조차 붙이지 않는다 - 크래시 집계에 필요 없다.)
//     App Privacy 신고는 `NSPrivacyCollectedDataTypeCrashData`(미연결·비추적)로 다룬다.
//

import Foundation
#if canImport(MetricKit) && os(iOS) && !targetEnvironment(macCatalyst)
import MetricKit
import CloudKit

final class DiagnosticsService: NSObject, MXMetricManagerSubscriber {

    static let shared = DiagnosticsService()

    private static let recordType = "CrashReport"
    /// 한 페이로드에서 올리는 최대 진단 건수 - 공개 DB 쓰기 폭주 방지.
    private static let maxReportsPerPayload = 5
    /// 콜스택 문자열 상한 (CloudKit 레코드 비대화 방지).
    private static let maxStackLength = 4000

    private override init() { super.init() }

    /// 앱 실행 시 1회 호출. 구독만 하고 즉시 반환한다(런치 비용 없음).
    func start() {
        MXMetricManager.shared.add(self)
        AppLog.info(.diagnostics, "🩺 [DiagnosticsService.start] MetricKit 구독 시작")
    }

    // MARK: - MXMetricManagerSubscriber

    /// 진단(크래시·행·디스크쓰기 예외) 페이로드. 하루 한 번꼴로 묶여서 온다.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard RemoteFlagsService.cachedValue(.usageReportingEnabled) else { return }

        var reports: [Report] = []
        for payload in payloads {
            reports += payload.crashDiagnostics?.prefix(Self.maxReportsPerPayload).map {
                Report(kind: "crash",
                       detail: $0.terminationReason ?? "-",
                       stack: Self.stackString($0.callStackTree),
                       meta: $0.metaData)
            } ?? []

            reports += payload.hangDiagnostics?.prefix(Self.maxReportsPerPayload).map {
                Report(kind: "hang",
                       detail: "\($0.hangDuration.value)\($0.hangDuration.unit.symbol)",
                       stack: Self.stackString($0.callStackTree),
                       meta: $0.metaData)
            } ?? []

            reports += payload.diskWriteExceptionDiagnostics?.prefix(Self.maxReportsPerPayload).map {
                Report(kind: "disk_write",
                       detail: "\($0.totalWritesCaused.value)\($0.totalWritesCaused.unit.symbol)",
                       stack: Self.stackString($0.callStackTree),
                       meta: $0.metaData)
            } ?? []
        }

        guard !reports.isEmpty else { return }
        AppLog.info(.diagnostics, "🩺 [DiagnosticsService] 진단 \(reports.count)건 수신 → 허브 전송")
        Task(priority: .utility) { await Self.upload(reports) }
    }

    /// 성능 지표 페이로드. 지금은 요약만 로그로 남긴다.
    /// (지표 적재는 크래시 가시성이 자리잡은 뒤 별도로 - 한 번에 다 넣으면 잡음만 는다.)
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            guard let launch = payload.applicationLaunchMetrics else { continue }
            AppLog.info(.diagnostics, "📈 [DiagnosticsService] 앱 시작 시간 분포: \(launch.histogrammedTimeToFirstDraw)")
        }
    }

    // MARK: - 내부

    private struct Report {
        let kind: String
        let detail: String
        let stack: String
        let meta: MXMetaData?
    }

    private static func stackString(_ tree: MXCallStackTree) -> String {
        let data = tree.jsonRepresentation()
        let text = String(data: data, encoding: .utf8) ?? "-"
        return String(text.prefix(maxStackLength))
    }

    private static func upload(_ reports: [Report]) async {
        let config = ClipKeyboardSpec.feedback
        let database = CKContainer(identifier: config.containerIdentifier).publicCloudDatabase
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"

        for report in reports {
            let record = CKRecord(recordType: recordType)
            record["appId"] = config.appIdentifier
            record["kind"] = report.kind
            record["detail"] = report.detail
            record["appVersion"] = appVersion
            record["osVersion"] = report.meta?.osVersion ?? "-"
            record["deviceType"] = report.meta?.deviceType ?? "-"
            record["stack"] = report.stack

            do {
                _ = try await database.save(record)
            } catch {
                // 진단 전송 실패로 앱이 시끄러워질 이유는 없다 - 로그만 남기고 넘어간다.
                AppLog.warning(.diagnostics, "⚠️ [DiagnosticsService.upload] \(report.kind) 전송 실패: \(error.localizedDescription)")
            }
        }
    }
}

#else

/// MetricKit이 없는 플랫폼(macOS Catalyst 등)용 빈 구현 - 호출부를 #if로 감싸지 않아도 되게 한다.
final class DiagnosticsService {
    static let shared = DiagnosticsService()
    private init() {}
    func start() { }
}

#endif
