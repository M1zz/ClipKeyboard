//
//  UsageBreakdownCharts.swift
//  ClipKeyboard
//
//  사용 통계 화면의 분포 차트 — 단축어 개수(막대)·종류(도넛).
//
//  색 선택 근거 (눈으로 고르지 않았다)
//   · 도넛은 슬라이스끼리 **모두** 비교되므로 all-pairs 기준으로 검증했다.
//   · 파랑·주황·청록 3색이 라이트/다크 양쪽에서 색각 이상(CVD) 및 일반 시야 분리 기준을
//     통과한다. 여기에 네 번째 유채색을 더하면 다크 모드에서 하드 FAIL이 난다
//     (보라↔파랑 ΔE 1.9, 자홍↔청록 ΔE 1.6). 그래서 **네 번째는 중립 회색**으로 둔다.
//   · 회색은 "이미지"에 **고정** 배정한다 — 크기 순으로 색을 바꾸면 필터·기간을 바꿀 때마다
//     같은 종류가 다른 색이 되어 읽는 사람이 헷갈린다(색은 순위가 아니라 대상을 따른다).
//   · 청록은 라이트 배경에서 대비가 3:1 미만이라 **슬라이스마다 값을 직접 표시**해
//     색만으로 구분하지 않게 한다.
//

import SwiftUI
import Charts

/// 검증된 카테고리 색.
/// 라이트/다크 스텝을 각각 **선택**해서 둔다 — 밝기를 자동으로 뒤집으면 다크 배경에서
/// 대비와 색각 분리가 무너진다.
enum ChartPalette {
    // #2a78d6 / #eb6834 / #1baf7a
    private static let light: [Color] = [
        Color(red: 0.165, green: 0.471, blue: 0.839),
        Color(red: 0.922, green: 0.408, blue: 0.204),
        Color(red: 0.106, green: 0.686, blue: 0.478)
    ]
    // #3987e5 / #d95926 / #199e70
    private static let dark: [Color] = [
        Color(red: 0.224, green: 0.529, blue: 0.898),
        Color(red: 0.851, green: 0.349, blue: 0.149),
        Color(red: 0.098, green: 0.620, blue: 0.439)
    ]

    /// 4번째부터는 **중립 회색**이다. 유채색을 하나 더 넣으면 다크 모드에서
    /// 색각 분리가 하드 FAIL 난다(보라↔파랑 ΔE 1.9). 검증 결과에 따른 선택.
    static func categorical(_ index: Int, dark isDark: Bool) -> Color {
        let palette = isDark ? dark : light
        guard index < palette.count else { return .gray }
        return palette[index]
    }
}

// MARK: - 단축어 개수 분포 (막대)

struct ShortcutDistributionChart: View {
    let buckets: [UsageInsights.DistributionBucket]

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var maxInstalls: Int { buckets.map(\.installs).max() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 단일 계열이라 범례를 두지 않는다 — 제목이 곧 계열 이름이다.
            Chart(buckets) { bucket in
                BarMark(
                    x: .value(NSLocalizedString("단축어 개수", comment: "Chart axis: shortcut count"), bucket.label),
                    y: .value(NSLocalizedString("사용자 수", comment: "Chart axis: install count"), bucket.installs)
                )
                .foregroundStyle(ChartPalette.categorical(0, dark: colorScheme == .dark).gradient)
                .cornerRadius(4)   // 데이터 끝만 둥글게
                // 값이 적을 때도 몇 명인지 바로 읽히도록 막대 위에 직접 표시.
                .annotation(position: .top, alignment: .center) {
                    if bucket.installs > 0 {
                        Text("\(bucket.installs)")
                            .font(.caption2)
                            .foregroundColor(theme.textMuted)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(theme.textFaint.opacity(0.25))
                    AxisValueLabel()
                }
            }
            .frame(height: 180)
            .accessibilityLabel(NSLocalizedString("단축어 개수별 사용자 분포", comment: "Chart a11y: shortcut distribution"))

            if maxInstalls == 0 {
                Text(NSLocalizedString("아직 그릴 데이터가 없어요.", comment: "Chart: no data yet"))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
            }
        }
    }
}

// MARK: - 단축어 종류 (도넛)

struct ShortcutTypeDonutChart: View {
    let shares: [UsageInsights.TypeShare]

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private func color(for index: Int) -> Color {
        ChartPalette.categorical(index, dark: colorScheme == .dark)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart(Array(shares.enumerated()), id: \.element.id) { index, share in
                SectorMark(
                    angle: .value(NSLocalizedString("개수", comment: "Chart value: count"), share.count),
                    innerRadius: .ratio(0.62),   // 도넛 — 가운데를 비워 합계를 넣는다
                    angularInset: 2              // 슬라이스 사이 2pt 간격
                )
                .foregroundStyle(color(for: index))
                .cornerRadius(3)
            }
            .frame(height: 190)
            .chartLegend(.hidden)   // 아래에 값까지 있는 직접 라벨을 따로 둔다
            .chartBackground { proxy in
                GeometryReader { geo in
                    if let anchor = proxy.plotFrame {
                        let frame = geo[anchor]
                        VStack(spacing: 2) {
                            Text("\(shares.reduce(0) { $0 + $1.count })")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(theme.text)
                            Text(NSLocalizedString("전체", comment: "Donut center: total"))
                                .font(.caption2)
                                .foregroundColor(theme.textMuted)
                        }
                        .position(x: frame.midX, y: frame.midY)
                    }
                }
            }
            .accessibilityLabel(NSLocalizedString("단축어 종류별 비율", comment: "Chart a11y: type breakdown"))

            // 색만으로 구분하지 않도록 이름·개수·비율을 함께 적는다(대비가 낮은 색 대비책).
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(shares.enumerated()), id: \.element.id) { index, share in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(for: index))
                            .frame(width: 10, height: 10)
                        Text(share.name)
                            .font(.body)
                            .foregroundColor(theme.text)
                        Spacer()
                        Text("\(share.count)")
                            .font(.body)
                            .foregroundColor(theme.textMuted)
                        Text(String(format: "%.0f%%", share.ratio * 100))
                            .font(.caption)
                            .foregroundColor(theme.textMuted)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
