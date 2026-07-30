//
//  UsageStatsView.swift
//  ClipKeyboard
//
//  개발자(마스터 모드) 전용 — 공용 허브(FeedbackHub)에서 실제 데이터를 읽어와 보여준다.
//   ① 사용자 수·활성 사용자 (UsageSnapshot)
//   ② 앱 사용 내용 — 이벤트별 발생 건수/설치 수 (UsageEvent)
//   ③ 접수된 피드백 요약 (Feedback) → 인박스로 이동
//
//  ⚠️ 남의 레코드를 읽는 화면이라 CloudKit 컨테이너 read 권한이 필요하다(피드백 인박스와 동일).
//     스키마·권한 절차: docs/USAGE_STATS_HUB.md
//

import SwiftUI
import LeeoKit

struct UsageStatsView: View {
    @Environment(\.appTheme) private var theme

    @State private var snapshots: [UsageReportingService.Snapshot] = []
    @State private var eventSamples: [UsageReportingService.EventSample] = []
    @State private var feedback: [LeeoFeedbackService.FeedbackRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// 이벤트 표본을 이름별로 묶은 것 — 차트와 같은 원본을 쓴다.
    private var events: [UsageReportingService.EventStat] {
        UsageReportingService.eventStats(from: eventSamples)
    }

    var body: some View {
        List {
            if isLoading && snapshots.isEmpty && eventSamples.isEmpty {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(NSLocalizedString("불러오는 중…", comment: "Loading usage stats"))
                            .font(.body)
                            .foregroundColor(theme.textMuted)
                    }
                }
            } else {
                // 일부만 실패해도(예: 아직 스키마 미배포) 읽어온 것은 그대로 보여준다.
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.red)
                    } footer: {
                        Text(NSLocalizedString("전체 통계를 읽으려면 CloudKit 컨테이너의 read 권한과 UsageSnapshot·UsageEvent 스키마 배포가 필요해요.", comment: "Usage stats permission footer"))
                            .font(.body)
                    }
                }
                usersSection
                trendSection
                usageSection
                metricsSection
                shareSection
                distributionSection
                feedbackSection
            }
        }
        .navigationTitle(NSLocalizedString("사용 통계", comment: "Usage stats title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.bg.ignoresSafeArea())
        .solidNavBar(theme.bg)
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - 사용자 수

    private var usersSection: some View {
        Section {
            statRow(NSLocalizedString("사용 중인 사람 (설치)", comment: "Usage stats: total installs"), "\(snapshots.count)")
            statRow(NSLocalizedString("최근 7일 활성", comment: "Usage stats: active last 7 days"), "\(activeCount(days: 7))")
            statRow(NSLocalizedString("최근 30일 활성", comment: "Usage stats: active last 30 days"), "\(activeCount(days: 30))")
            statRow(NSLocalizedString("최근 7일 신규", comment: "Usage stats: new installs last 7 days"), "\(newCount(days: 7))")
            statRow(NSLocalizedString("누적 실행", comment: "Usage stats: total launches"), "\(total(\.launchCount))")
        } header: {
            Text(NSLocalizedString("사용자", comment: "Usage stats section: users"))
        } footer: {
            Text(NSLocalizedString("설치마다 익명 스냅샷 1건이라, 설치 수 = 이 앱을 쓰는 기기 수예요.", comment: "Usage stats users footer"))
                .font(.body)
        }
    }

    // MARK: - 기간별 추이 (일·주·월·연 + 좌우 스크롤)

    private var trendSection: some View {
        Section {
            UsageTrendChartView(events: eventSamples, snapshots: snapshots)
        } header: {
            Text(NSLocalizedString("기간별 추이", comment: "Usage stats section: trend over time"))
        } footer: {
            Text(NSLocalizedString("일·주·월·연 단위로 묶어서 보여줘요. 차트를 좌우로 넘기면 그 단위만큼 과거로 이동합니다.", comment: "Usage stats trend footer"))
                .font(.body)
        }
    }

    // MARK: - 앱 사용 내용 (이벤트)

    @ViewBuilder
    private var usageSection: some View {
        Section {
            if events.isEmpty {
                Text(NSLocalizedString("아직 기록된 사용 내용이 없어요.", comment: "Usage stats: no events yet"))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
            } else {
                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.name)
                            .font(.body.weight(.medium))
                            .foregroundColor(theme.text)
                        Text(String(format: NSLocalizedString("%1$d건 · 설치 %2$d곳", comment: "Usage stats: event count and installs"),
                                    event.count, event.installs))
                            .font(.caption)
                            .foregroundColor(theme.textMuted)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        } header: {
            Text(NSLocalizedString("앱 사용 내용", comment: "Usage stats section: what people do"))
        } footer: {
            Text(NSLocalizedString("최근 이벤트 3,000건 기준이에요. 같은 이벤트는 설치당 6시간에 한 번만 기록되니, 건수보다 '설치 몇 곳이 쓰는지'를 보세요.", comment: "Usage stats events footer"))
                .font(.body)
        }
    }

    // MARK: - 설치당 평균 지표

    @ViewBuilder
    private var metricsSection: some View {
        let averages = metricAverages
        if !averages.isEmpty {
            Section(NSLocalizedString("설치당 평균", comment: "Usage stats section: per-install averages")) {
                ForEach(averages, id: \.key) { item in
                    statRow(Self.metricLabel(item.key), Self.format(item.value))
                }
            }
        }
    }

    // MARK: - 사용자 비율 (0/1 플래그 · 페르소나)

    @ViewBuilder
    private var shareSection: some View {
        let shares = flagShares
        if !shares.isEmpty {
            Section(NSLocalizedString("사용자 비율", comment: "Usage stats section: user share")) {
                ForEach(shares, id: \.key) { item in
                    statRow(Self.metricLabel(item.key),
                            String(format: NSLocalizedString("%1$d%% (%2$d)", comment: "Usage stats: percent and count"),
                                   Int((item.value * 100).rounded()), item.count))
                }
            }
        }
    }

    // MARK: - 버전 / 플랫폼

    @ViewBuilder
    private var distributionSection: some View {
        if !snapshots.isEmpty {
            Section(NSLocalizedString("버전 분포", comment: "Usage stats section: version distribution")) {
                ForEach(distribution(\.appVersion), id: \.key) { item in
                    statRow(item.key, "\(item.count)")
                }
            }
            Section(NSLocalizedString("플랫폼", comment: "Usage stats section: platform distribution")) {
                ForEach(distribution(\.platform), id: \.key) { item in
                    statRow(item.key, "\(item.count)")
                }
            }
        }
    }

    // MARK: - 피드백

    private var feedbackSection: some View {
        Section {
            statRow(NSLocalizedString("접수된 피드백", comment: "Usage stats: feedback count"), "\(feedback.count)")
            statRow(NSLocalizedString("아직 처리 안 함", comment: "Usage stats: feedback not done"),
                    "\(feedback.filter { !$0.isDone }.count)")
            NavigationLink(destination: FeedbackInboxView()) {
                Label(NSLocalizedString("피드백 전부 보기", comment: "Usage stats: open feedback inbox"),
                      systemImage: AppSymbol.trayFull)
            }
        } header: {
            Text(NSLocalizedString("피드백", comment: "Usage stats section: feedback"))
        } footer: {
            Text(NSLocalizedString("최근 100건 기준이에요. 완료 표시는 이 기기에만 저장됩니다.", comment: "Usage stats feedback footer"))
                .font(.body)
        }
    }

    // MARK: - Row

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundColor(theme.text)
            Spacer()
            Text(value)
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundColor(theme.textMuted)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 집계 (클라이언트 계산)

    private func activeCount(days: Int) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return snapshots.filter { ($0.lastActiveAt ?? .distantPast) >= cutoff }.count
    }

    private func newCount(days: Int) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return snapshots.filter { ($0.installDate ?? .distantPast) >= cutoff }.count
    }

    private func total(_ keyPath: KeyPath<UsageReportingService.Snapshot, Int>) -> Int {
        snapshots.reduce(0) { $0 + $1[keyPath: keyPath] }
    }

    private struct Bucket: Identifiable { let key: String; let count: Int; var id: String { key } }
    private func distribution(_ keyPath: KeyPath<UsageReportingService.Snapshot, String>) -> [Bucket] {
        Dictionary(grouping: snapshots) { $0[keyPath: keyPath] }
            .map { Bucket(key: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    /// 0/1 플래그가 아닌 수치 지표 — 값을 가진 설치들의 평균.
    private struct MetricAvg { let key: String; let value: Double }
    private var metricAverages: [MetricAvg] {
        var sums: [String: (total: Double, n: Int)] = [:]
        for snapshot in snapshots {
            for (key, value) in snapshot.metrics where !Self.isFlag(key) {
                let current = sums[key] ?? (0, 0)
                sums[key] = (current.total + value, current.n + 1)
            }
        }
        return sums
            .map { MetricAvg(key: $0.key, value: $0.value.n > 0 ? $0.value.total / Double($0.value.n) : 0) }
            .sorted { $0.key < $1.key }
    }

    /// 0/1 플래그(Pro·키보드 사용·페르소나) — 전체 설치 대비 비율.
    private struct FlagShare { let key: String; let value: Double; let count: Int }
    private var flagShares: [FlagShare] {
        guard !snapshots.isEmpty else { return [] }
        var counts: [String: Int] = [:]
        for snapshot in snapshots {
            for (key, value) in snapshot.metrics where Self.isFlag(key) && value >= 1 {
                counts[key, default: 0] += 1
            }
        }
        return counts
            .map { FlagShare(key: $0.key, value: Double($0.value) / Double(snapshots.count), count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private static func isFlag(_ key: String) -> Bool {
        key.hasPrefix("flag.") || key.hasPrefix("persona.")
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    /// 전송 키(고정) → 화면 라벨. 모르는 키는 원본 그대로 보여준다.
    private static func metricLabel(_ key: String) -> String {
        switch key {
        case "shortcuts":          return NSLocalizedString("단축어 수", comment: "Usage metric: shortcuts")
        case "combos":             return NSLocalizedString("콤보 수", comment: "Usage metric: combos")
        case "templates":          return NSLocalizedString("템플릿 수", comment: "Usage metric: templates")
        case "images":             return NSLocalizedString("이미지 단축어 수", comment: "Usage metric: image shortcuts")
        case "favorites":          return NSLocalizedString("즐겨찾기 수", comment: "Usage metric: favorites")
        case "uses":               return NSLocalizedString("누적 사용 횟수", comment: "Usage metric: total uses")
        case "timeSavedMin":       return NSLocalizedString("절약한 시간 (분)", comment: "Usage metric: time saved minutes")
        case "keyboardUses":       return NSLocalizedString("키보드 사용 횟수", comment: "Usage metric: keyboard uses")
        case "flag.isPro":         return NSLocalizedString("Pro 사용자", comment: "Usage metric: pro users")
        case "flag.keyboardActive": return NSLocalizedString("키보드를 쓰는 사용자", comment: "Usage metric: keyboard active users")
        case "flag.syncOn":        return NSLocalizedString("동기화 켠 사용자", comment: "Usage metric: sync enabled users")
        default:
            if key.hasPrefix("persona.") {
                let raw = String(key.dropFirst("persona.".count))
                return Persona(rawValue: raw)?.localizedTitle ?? raw
            }
            return key
        }
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        errorMessage = nil
        var failures: [String] = []

        do { snapshots = try await UsageReportingService.fetchSnapshots() }
        catch { failures.append(error.localizedDescription) }

        do { eventSamples = try await UsageReportingService.fetchEvents() }
        catch { failures.append(error.localizedDescription) }

        do { feedback = try await UsageReportingService.fetchFeedback() }
        catch { failures.append(error.localizedDescription) }

        if !failures.isEmpty {
            errorMessage = String(format: NSLocalizedString("불러오지 못했어요: %@", comment: "Usage stats load failed"),
                                  Set(failures).joined(separator: "\n"))
        }
        isLoading = false
    }
}
