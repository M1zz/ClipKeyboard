//
//  UsageTrendChartView.swift
//  ClipKeyboard
//
//  사용 통계 화면의 기간별 추이 차트 - 일/주/월/연 단위를 고르고, 그 단위만큼
//  좌우로 스크롤하며 과거를 훑어볼 수 있다. 데이터는 허브(UsageEvent/UsageSnapshot)에서
//  읽어온 것을 UsageReportingService.trend(...)가 빈 구간까지 채워 만든 묶음이다.
//
//  ⚠️ 통계 화면 본문(UsageStatsView)이 이미 큰 List라 차트는 별도 뷰로 떼어 둔다
//     (SwiftUI 타입 메타데이터 깊이 여유 확보).
//

import SwiftUI
import Charts

struct UsageTrendChartView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let events: [UsageReportingService.EventSample]
    let snapshots: [UsageReportingService.Snapshot]

    @State private var unit: UsageReportingService.BucketUnit = .day
    @State private var metric: TrendMetric = .activeInstalls
    @State private var scrollPosition = Date()

    // MARK: - 표시할 값

    enum TrendMetric: String, CaseIterable, Identifiable {
        case activeInstalls, events, newInstalls
        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .activeInstalls: return NSLocalizedString("활동한 사용자", comment: "Chart metric: active installs")
            case .events: return NSLocalizedString("사용 건수", comment: "Chart metric: event count")
            case .newInstalls: return NSLocalizedString("신규 사용자", comment: "Chart metric: new installs")
            }
        }

        func value(_ point: UsageReportingService.TrendPoint) -> Int {
            switch self {
            case .activeInstalls: return point.activeInstalls
            case .events: return point.events
            case .newInstalls: return point.newInstalls
            }
        }
    }

    private var points: [UsageReportingService.TrendPoint] {
        UsageReportingService.trend(unit: unit, events: events, snapshots: snapshots)
    }

    /// 스크롤 창 길이(초) - 보이는 묶음 개수만큼.
    private var visibleDomain: TimeInterval {
        let bucketSeconds: TimeInterval
        switch unit {
        case .day: bucketSeconds = 86_400
        case .week: bucketSeconds = 7 * 86_400
        case .month: bucketSeconds = 30.5 * 86_400
        case .year: bucketSeconds = 365.25 * 86_400
        }
        return bucketSeconds * Double(unit.visibleBuckets)
    }

    /// 지금 화면에 보이는 묶음들.
    private var visiblePoints: [UsageReportingService.TrendPoint] {
        let end = scrollPosition.addingTimeInterval(visibleDomain)
        return points.filter { $0.date >= scrollPosition && $0.date < end }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $unit) {
                ForEach(UsageReportingService.BucketUnit.allCases) { unit in
                    Text(unit.localizedName).tag(unit)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(NSLocalizedString("기간 단위", comment: "Chart bucket unit picker label"))

            Picker("", selection: $metric) {
                ForEach(TrendMetric.allCases) { metric in
                    Text(metric.localizedName).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(NSLocalizedString("표시할 값", comment: "Chart metric picker label"))

            if points.isEmpty {
                Text(NSLocalizedString("아직 그릴 데이터가 없어요.", comment: "Chart: no data yet"))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                chart
                summary
            }
        }
        .padding(.vertical, 4)
        .onAppear { scrollToLatest() }
        .onChange(of: unit) { _, _ in scrollToLatest() }
        .onChange(of: points.count) { _, _ in scrollToLatest() }
    }

    // MARK: - 차트

    private var chart: some View {
        Chart(points) { point in
            BarMark(
                x: .value(NSLocalizedString("기간", comment: "Chart axis: period"), point.date, unit: unit.calendarComponent),
                y: .value(metric.localizedName, metric.value(point))
            )
            .foregroundStyle(theme.accent.gradient)
            .accessibilityLabel(Self.axisLabel(point.date, unit: unit))
            .accessibilityValue("\(metric.value(point))")
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(Self.axisLabel(date, unit: unit))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4))
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleDomain)
        .chartScrollPosition(x: $scrollPosition)
        .chartScrollTargetBehavior(.valueAligned(matching: scrollAlignment))
        .frame(height: 200)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: metric)
    }

    /// 스크롤이 묶음 경계에 딱 맞게 멈추도록 - 단위별 정렬 기준.
    private var scrollAlignment: DateComponents {
        switch unit {
        case .day: return DateComponents(hour: 0)
        case .week: return DateComponents(hour: 0, weekday: Calendar.current.firstWeekday)
        case .month: return DateComponents(day: 1)
        case .year: return DateComponents(month: 1, day: 1)
        }
    }

    // MARK: - 보이는 구간 요약

    private var summary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(visibleRangeText)
                .font(.caption)
                .foregroundColor(theme.textMuted)
            Text(String(format: NSLocalizedString("이 구간 합계 %1$@ %2$d", comment: "Chart: total in visible range"),
                        metric.localizedName, visiblePoints.reduce(0) { $0 + metric.value($1) }))
                .font(.body.weight(.semibold))
                .foregroundColor(theme.text)
        }
        .accessibilityElement(children: .combine)
    }

    private var visibleRangeText: String {
        guard let first = visiblePoints.first?.date, let last = visiblePoints.last?.date else {
            return NSLocalizedString("좌우로 넘겨서 다른 기간을 보세요.", comment: "Chart: scroll hint")
        }
        let start = Self.axisLabel(first, unit: unit)
        let end = Self.axisLabel(last, unit: unit)
        return start == end ? start : "\(start) – \(end)"
    }

    // MARK: - 라벨 / 스크롤 위치

    private static func axisLabel(_ date: Date, unit: UsageReportingService.BucketUnit) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        switch unit {
        case .day, .week:
            formatter.setLocalizedDateFormatFromTemplate("Md")
        case .month:
            formatter.setLocalizedDateFormatFromTemplate("yMMM")
        case .year:
            formatter.setLocalizedDateFormatFromTemplate("y")
        }
        return formatter.string(from: date)
    }

    /// 가장 최근 구간이 보이도록 스크롤 위치를 옮긴다.
    private func scrollToLatest() {
        guard let last = points.last?.date else { return }
        scrollPosition = last.addingTimeInterval(-visibleDomain + 1)
    }
}

#if DEBUG
struct UsageTrendChartView_Previews: PreviewProvider {
    /// 최근 120일치 가짜 이벤트 - 일/주/월 단위 전환과 좌우 스크롤을 캔버스에서 확인용.
    private static var sampleEvents: [UsageReportingService.EventSample] {
        (0..<120).flatMap { dayOffset -> [UsageReportingService.EventSample] in
            let date = Date().addingTimeInterval(-Double(dayOffset) * 86_400)
            return (0..<(dayOffset % 5 + 1)).map { index in
                UsageReportingService.EventSample(name: "memo_created",
                                                  installID: "install-\((dayOffset + index) % 7)",
                                                  date: date)
            }
        }
    }

    static var previews: some View {
        List {
            Section {
                UsageTrendChartView(events: sampleEvents, snapshots: [])
            }
        }
    }
}
#endif
