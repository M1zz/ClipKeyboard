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

    /// 탭한 막대의 시각 - 정확한 날짜와 숫자를 읽으려고 고른 자리.
    ///
    /// ⚠️ 이 화면의 막대는 **눈으로 읽을 수가 없다.** y축 눈금이 4개뿐이라 "3인지 4인지"를
    ///    막대 높이로 알아맞히게 되고, x축 라벨은 5개만 나와서 그 막대가 며칠인지도 모른다.
    ///    그래서 탭한 자리의 값을 글자로 못박아 준다.
    @State private var selectedDate: Date?

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

    // MARK: - 고른 막대

    /// 탭한 x 좌표에 해당하는 묶음.
    ///
    /// `chartXSelection` 이 주는 건 **누른 자리의 시각**이지 막대가 아니다. 그래서 그 시각이
    /// 속한 묶음을 직접 찾는다 - 가장 가까운 것으로 고르면 묶음 사이 빈틈을 눌러도 답이 나온다.
    private var selectedPoint: UsageReportingService.TrendPoint? {
        guard let selectedDate else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private func isSelected(_ point: UsageReportingService.TrendPoint) -> Bool {
        selectedPoint?.id == point.id
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
        // 단위가 바뀌면 고른 자리도 뜻이 달라진다(같은 날을 가리켜도 이제 '그 달'이다) - 지운다.
        .onChange(of: unit) { _, _ in
            selectedDate = nil
            scrollToLatest()
        }
        .onChange(of: points.count) { _, _ in scrollToLatest() }
    }

    // MARK: - 차트

    private var chart: some View {
        Chart(points) { point in
            BarMark(
                x: .value(NSLocalizedString("기간", comment: "Chart axis: period"), point.date, unit: unit.calendarComponent),
                y: .value(metric.localizedName, metric.value(point))
            )
            // 고른 막대만 제 색으로 두고 나머지는 물린다 - 어느 것을 읽고 있는지 한눈에.
            .foregroundStyle(theme.accent.gradient)
            .opacity(selectedPoint == nil || isSelected(point) ? 1 : 0.35)
            .accessibilityLabel(Self.axisLabel(point.date, unit: unit))
            .accessibilityValue("\(metric.value(point))")

            if let selected = selectedPoint, isSelected(point) {
                // ⚠️ 값을 **차트 안 말풍선으로 띄우지 않는다.** 막대가 높으면 말풍선이
                //    그림 영역 위로 넘어가 잘려서, 하이라이트만 되고 숫자는 안 보였다.
                //    읽을 글은 차트 아래 고정된 자리(`summary`)에 둔다. 거기서는 어떤 막대를
                //    골라도 같은 자리에 같은 크기로 나온다.
                RuleMark(x: .value(NSLocalizedString("기간", comment: "Chart axis: period"), selected.date, unit: unit.calendarComponent))
                    .foregroundStyle(theme.textMuted.opacity(0.35))
                    .zIndex(-1)
            }
        }
        .chartXSelection(value: $selectedDate)
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

    /// 차트 아래 고정된 한 자리.
    ///
    /// 막대를 고르면 **그 막대의 정확한 날짜와 값**을, 아무것도 안 고르면 보이는 구간의
    /// 합계를 보여준다. 자리가 고정이라 어떤 막대를 눌러도 눈이 같은 곳으로 간다.
    private var summary: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let selected = selectedPoint {
                Text(Self.fullLabel(selected.date, unit: unit))
                    .font(.caption)
                    .foregroundColor(theme.textMuted)
                HStack(spacing: 8) {
                    Text(String(format: NSLocalizedString("%1$@ %2$d", comment: "Chart readout: metric name and exact value"),
                                metric.localizedName, metric.value(selected)))
                        .font(.title3.weight(.bold))
                        .foregroundColor(theme.text)
                    Spacer(minLength: 0)
                    // 고른 것을 놓는 길 - 안 그러면 합계로 돌아갈 방법이 없다.
                    Button {
                        selectedDate = nil
                    } label: {
                        Text(NSLocalizedString("선택 해제", comment: "Chart: clear the selected bar"))
                            .font(.caption)
                            .foregroundColor(theme.accent)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text(visibleRangeText)
                    .font(.caption)
                    .foregroundColor(theme.textMuted)
                Text(String(format: NSLocalizedString("이 구간 합계 %1$@ %2$d", comment: "Chart: total in visible range"),
                            metric.localizedName, visiblePoints.reduce(0) { $0 + metric.value($1) }))
                    .font(.body.weight(.semibold))
                    .foregroundColor(theme.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var visibleRangeText: String {
        guard let first = visiblePoints.first?.date, let last = visiblePoints.last?.date else {
            return NSLocalizedString("좌우로 넘겨서 다른 기간을 보세요.", comment: "Chart: scroll hint")
        }
        let start = Self.axisLabel(first, unit: unit)
        let end = Self.axisLabel(last, unit: unit)
        // ⚠️ 붙임표(en dash)를 쓰지 않는다 - 저장소 규칙. 범위는 물결표로.
        return start == end ? start : "\(start) ~ \(end)"
    }

    // MARK: - 라벨 / 스크롤 위치

    /// 탭했을 때 보여줄 **정확한** 날짜.
    ///
    /// ⚠️ 축 라벨(`axisLabel`)과 다른 형식을 쓴다. 축은 자리가 좁아 연도를 뺀 "8/14"인데,
    ///    탭해서 읽는 자리에서까지 연도를 빼면 몇 년 것인지 알 수 없다. 주 단위는 그 주가
    ///    언제부터인지가 값의 뜻이라 "시작" 임을 밝힌다.
    private static func fullLabel(_ date: Date, unit: UsageReportingService.BucketUnit) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        switch unit {
        case .day:
            formatter.setLocalizedDateFormatFromTemplate("yMMMd")
            return formatter.string(from: date)
        case .week:
            formatter.setLocalizedDateFormatFromTemplate("yMMMd")
            return String(format: NSLocalizedString("%@ 주 시작", comment: "Chart readout: week starting on this date"),
                          formatter.string(from: date))
        case .month:
            formatter.setLocalizedDateFormatFromTemplate("yMMMM")
            return formatter.string(from: date)
        case .year:
            formatter.setLocalizedDateFormatFromTemplate("y")
            return formatter.string(from: date)
        }
    }

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
                                                  date: date,
                                                  createdAt: date)
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
