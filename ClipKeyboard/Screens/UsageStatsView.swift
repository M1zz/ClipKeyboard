//
//  UsageStatsView.swift
//  ClipKeyboard
//
//  개발자(마스터 모드) 전용 - 공용 허브(FeedbackHub)에서 실제 데이터를 읽어와 보여준다.
//   ① 사용자 수·활성 사용자 (UsageSnapshot)
//   ② 앱 사용 내용 - 이벤트별 발생 건수/설치 수 (UsageEvent)
//   ③ 접수된 피드백 요약 (Feedback) → 인박스로 이동
//
//  ⚠️ 남의 레코드를 읽는 화면이라 CloudKit 컨테이너 read 권한이 필요하다(피드백 인박스와 동일).
//     스키마·권한 절차: docs/engineering/USAGE_STATS_HUB.md
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
    /// 조회 하나하나가 왜 멈췄는지. 받는 중이면 nil.
    /// 나눠 받는 조회에서 이게 없으면, 낮은 숫자가 "아직 받는 중"인지 "원래 그만큼"인지
    /// "중간에 끊긴 것"인지 사람이 구분할 수 없다 - 셋은 할 일이 서로 다르다.
    @State private var snapshotStop: LeeoCloudStop?
    @State private var eventStop: LeeoCloudStop?
    /// 지금까지 받은 페이지 수 - 진행이 실제로 일어나고 있다는 증거.
    @State private var snapshotPages = 0
    @State private var eventPages = 0
    private var pagesLoaded: Int { snapshotPages + eventPages }
    /// 지금 보이는 숫자가 언제 기준인지.
    @State private var loadedAt: Date?

    /// 이벤트 표본을 이름별로 묶은 것 - 차트와 같은 원본을 쓴다.
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
                statusSection
                usersSection
                trendSection
                keyboardSection
                distributionChartSection
                segmentSection
                typeChartSection
                marketingSection
                savedTimeSection
                funnelSection
                retentionSection
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

    // MARK: - 어디까지 왔나

    /// 지금 보이는 숫자가 중간 집계인지 최종본인지 화면이 직접 말한다.
    /// 허브가 커지면 조회는 수십 번의 왕복이 된다. 그동안 아무 말도 없으면
    /// "다 불러온 건가?" 를 사람이 알 방법이 없고, 낮은 숫자를 사실로 믿게 된다.
    @ViewBuilder
    private var statusSection: some View {
        if isLoading {
            Section {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(String(format: NSLocalizedString("불러오는 중… 설치 %lld · 이벤트 %lld (%lld페이지)", comment: "Usage stats: loading progress"),
                                snapshots.count, eventSamples.count, pagesLoaded))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
            } footer: {
                Text(NSLocalizedString("한 번에 200건씩 나눠 받아요. 지금 숫자는 중간 집계라 계속 올라가요.", comment: "Usage stats: paged loading footer"))
                    .font(.body)
            }
        } else if let text = completionText {
            Section {
                Label {
                    Text(text).font(.body)
                } icon: {
                    Image(systemName: isFullyLoaded ? "checkmark.circle" : "exclamationmark.triangle")
                }
                .foregroundColor(isFullyLoaded ? theme.textMuted : .orange)
            }
        }
    }

    /// 두 조회가 모두 끝까지 갔는가.
    private var isFullyLoaded: Bool {
        snapshotStop?.isComplete == true && eventStop?.isComplete == true
    }

    /// 다 받았으면 언제 기준인지, 못 받았으면 무엇이 왜 빠졌는지.
    private var completionText: String? {
        guard snapshotStop != nil || eventStop != nil else { return nil }
        if isFullyLoaded {
            let at = loadedAt.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .short) } ?? "-"
            return String(format: NSLocalizedString("설치 %lld · 이벤트 %lld건을 전부 불러왔어요 (%@ 기준).", comment: "Usage stats: fully loaded"),
                          snapshots.count, eventSamples.count, at)
        }
        var lines: [String] = []
        if let reason = incompleteReason(snapshotStop, what: NSLocalizedString("설치", comment: "Usage stats: installs"), count: snapshots.count) {
            lines.append(reason)
        }
        if let reason = incompleteReason(eventStop, what: NSLocalizedString("이벤트", comment: "Usage stats: events"), count: eventSamples.count) {
            lines.append(reason)
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private func incompleteReason(_ stop: LeeoCloudStop?, what: String, count: Int) -> String? {
        switch stop {
        case .none, .some(.exhausted):
            return nil
        case .some(.reachedLimit):
            return String(format: NSLocalizedString("%1$@은(는) 상한인 %2$lld건까지만 받았어요. 더 오래된 기록은 빠져 있어요.", comment: "Usage stats: stopped at limit"), what, count)
        case .some(.cancelled):
            return String(format: NSLocalizedString("%1$@을(를) 받다가 멈췄어요(%2$lld건). 당겨서 새로고침하면 다시 받아요.", comment: "Usage stats: cancelled"), what, count)
        case .some(.failed(let why)):
            return String(format: NSLocalizedString("%1$@은(는) 중간에 끊겨 %2$lld건까지만 받았어요: %3$@", comment: "Usage stats: interrupted"), what, count, why)
        }
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
            Text(NSLocalizedString("일·주·월·연 단위로 묶어서 보여줘요. 차트를 좌우로 넘기면 그 단위만큼 과거로 이동하고, 막대를 탭하면 그 기간의 정확한 날짜와 숫자가 나와요.", comment: "Usage stats trend footer"))
                .font(.body)
        }
    }

    // MARK: - 키보드 사용량

    /// 차트가 아니라 숫자로 보여준다 - "얼마나 쓰나"는 한 값이라 막대를 그릴 이유가 없다.
    @ViewBuilder
    private var keyboardSection: some View {
        let usage = UsageInsights.keyboardUsage(snapshots: snapshots)
        if usage.totalInstalls > 0 {
            Section {
                statRow(NSLocalizedString("키보드를 켠 사용자", comment: "Keyboard adoption"),
                        String(format: NSLocalizedString("%1$d명 (%2$@)", comment: "Count with ratio"),
                               usage.activeInstalls, percent(usage.adoptionRate)))
                statRow(NSLocalizedString("키보드 입력 횟수", comment: "Keyboard total uses"),
                        "\(usage.totalUses)")
                statRow(NSLocalizedString("켠 사용자당 평균 입력", comment: "Uses per active install"),
                        String(format: "%.1f", usage.usesPerActiveInstall))
                statRow(NSLocalizedString("절약한 시간 합계", comment: "Total time saved"),
                        String(format: NSLocalizedString("%d분", comment: "Minutes"), usage.totalTimeSavedMin))
            } header: {
                Text(NSLocalizedString("키보드 사용량", comment: "Usage stats section: keyboard"))
            } footer: {
                Text(NSLocalizedString("키보드를 켠 비율이 이 앱에서 가장 중요한 숫자예요. 앱만 깔고 키보드를 안 켰다면 핵심 가치를 아직 못 받은 거예요.", comment: "Keyboard section footer"))
                    .font(.body)
            }
        }
    }

    // MARK: - 단축어 개수 분포 (막대)

    @ViewBuilder
    private var distributionChartSection: some View {
        let buckets = UsageInsights.shortcutDistribution(snapshots: snapshots)
        let counted = buckets.reduce(0) { $0 + $1.installs }
        let legacy = UsageInsights.legacyShortcutSnapshotCount(snapshots: snapshots)
        if !snapshots.isEmpty {
            Section {
                // 셀 것이 하나도 없으면 0짜리 막대 일곱 개 대신 이유를 적는다.
                // 빈 차트는 "아무도 안 만들었다" 로 읽히는데, 실제로는 아직 안 모인 것이다.
                if counted == 0 {
                    Text(NSLocalizedString("아직 집계할 기록이 없어요. 새 지표(직접 저장한 개수)는 앱이 다시 켜질 때부터 쌓여요.", comment: "Distribution empty state"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    ShortcutDistributionChart(buckets: buckets)
                        .padding(.vertical, 4)
                }
            } header: {
                Text(NSLocalizedString("단축어 개수 분포", comment: "Usage stats section: shortcut distribution"))
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("사용자가 직접 저장한 개수예요(온보딩 샘플 4개는 빼고 세요). 무료 한도(10개) 앞뒤를 촘촘히 끊었고, 9개는 따로 세요. 한 칸 남은 사람이라 할인 제안이 닿는 무리이고, 1~3개에 몰려 있으면 만들다 마는 거예요.", comment: "Distribution footer"))
                    // 한도 판정(`ProFeatureManager.ownMemoCount`)도 같은 개수를 센다.
                    // 그래서 여기 보이는 거리가 곧 결제 자리까지의 거리다. 둘이 다른 값을
                    // 보기 시작하면 이 차트는 다시 거짓말이 된다.
                    if legacy > 0 {
                        Text(String(format: NSLocalizedString("구버전 기록 %d개는 이 개수를 안 보내서 빠졌어요.", comment: "Distribution footer: legacy snapshots excluded"), legacy))
                    }
                }
                .font(.body)
            }
        }
    }

    // MARK: - 단축어 종류 (도넛)

    @ViewBuilder
    private var typeChartSection: some View {
        let shares = UsageInsights.typeBreakdown(snapshots: snapshots)
        if !shares.isEmpty {
            Section {
                ShortcutTypeDonutChart(shares: shares)
                    .padding(.vertical, 4)
            } header: {
                Text(NSLocalizedString("단축어 종류", comment: "Usage stats section: shortcut types"))
            } footer: {
                Text(NSLocalizedString("한 단축어는 한 종류로만 세요(콤보 > 템플릿 > 이미지 > 텍스트 순). 텍스트 수치는 4.4.3부터 모여서, 그 전 기록이 섞이면 실제보다 낮게 보일 수 있어요.", comment: "Type breakdown footer"))
                    .font(.body)
            }
        }
    }

    // MARK: - 사용 유형 (사람을 무리로)

    /// 개수 분포가 "몇 개 가졌나"라면, 이쪽은 **"그래서 쓰고 있나"** 다.
    /// 같은 5개라도 매일 꺼내 쓰는 사람과 만들어만 둔 사람은 다른 사람이고, 할 일도 다르다.
    @ViewBuilder
    private var segmentSection: some View {
        let segments = UsageInsights.userSegments(snapshots: snapshots)
        if !segments.isEmpty {
            Section {
                ForEach(segments) { segment in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(segment.name)
                                .font(.body)
                                .foregroundColor(theme.text)
                            Spacer()
                            Text(String(format: NSLocalizedString("%1$d명 (%2$@)", comment: "Count with ratio"),
                                        segment.installs, percent(segment.ratio)))
                                .font(.body.weight(.medium))
                                .foregroundColor(theme.text)
                        }
                        // 막대 하나로 크기를 눈에 - 숫자만 늘어놓으면 어디가 큰지 안 읽힌다.
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(theme.surfaceAlt)
                                Capsule()
                                    .fill(theme.accent)
                                    .frame(width: max(0, geo.size.width * segment.ratio))
                            }
                        }
                        .frame(height: 4)
                        Text(segment.hint)
                            .font(.caption)
                            .foregroundColor(theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text(NSLocalizedString("사용 유형", comment: "Usage stats section: user segments"))
            } footer: {
                Text(NSLocalizedString("한 사람은 한 무리에만 들어가요(합이 전체와 같아요). 위에서부터 걸리는 첫 무리로 정해져요. '만들고 안 쓴 사람'이 크면 키보드를 켜는 데까지 못 간 거고, '쌓아만 두는 사람'이 크면 만드는 것보다 꺼내 쓰는 게 어려운 거예요.", comment: "User segments footer"))
                    .font(.body)
            }
        }
    }

    // MARK: - 이벤트 이름을 사람 말로

    /// `app_open` 같은 기록용 id 를 읽을 수 있는 말로 바꾼다.
    ///
    /// ⚠️ 이름은 슬라이스를 달고 온다(`paywall_view:memo` = 메모 한도 때문에 뜬 페이월).
    ///    앞의 이벤트 이름만 바꾸고 **꼬리는 그대로 살린다** - 그 꼬리가 "어느 한도가
    ///    결제를 만드는가"의 답이라 지우면 안 된다.
    ///
    /// ⚠️ 모르는 이름은 **원문 그대로 둔다.** 여기 없는 이벤트가 화면에서 사라지면,
    ///    새 이벤트를 넣고도 통계에서 못 찾는 일이 생긴다.
    static func eventLabel(_ raw: String) -> String {
        let parts = raw.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let base = String(parts[0])
        let slice = parts.count > 1 ? String(parts[1]) : nil

        let named: String
        switch base {
        case UsageReportingService.appOpenEvent:
            named = NSLocalizedString("앱을 연 횟수", comment: "Event label: app opened")
        case AnalyticsEvent.memoCreated.rawValue:
            named = NSLocalizedString("단축어를 만듦", comment: "Event label: shortcut created")
        case AnalyticsEvent.keyboardUsed.rawValue:
            named = NSLocalizedString("키보드로 입력함", comment: "Event label: keyboard used")
        case AnalyticsEvent.bulkImported.rawValue:
            named = NSLocalizedString("한꺼번에 가져옴", comment: "Event label: bulk imported")
        case AnalyticsEvent.onboardingCompleted.rawValue:
            named = NSLocalizedString("처음 안내를 끝냄", comment: "Event label: onboarding completed")
        case AnalyticsEvent.paywallView.rawValue:
            named = NSLocalizedString("페이월을 봄", comment: "Event label: paywall shown")
        case AnalyticsEvent.paywallCtaTapped.rawValue:
            named = NSLocalizedString("구매 버튼을 누름", comment: "Event label: purchase button tapped")
        case AnalyticsEvent.paywallPurchase.rawValue:
            named = NSLocalizedString("구매함", comment: "Event label: purchased")
        case AnalyticsEvent.paywallDismissed.rawValue:
            named = NSLocalizedString("페이월을 닫음", comment: "Event label: paywall dismissed")
        case AnalyticsEvent.purchaseCancelled.rawValue:
            named = NSLocalizedString("결제를 취소함", comment: "Event label: purchase cancelled")
        case AnalyticsEvent.purchaseFailed.rawValue:
            named = NSLocalizedString("결제가 실패함", comment: "Event label: purchase failed")
        case AnalyticsEvent.trialStarted.rawValue:
            named = NSLocalizedString("체험을 시작함", comment: "Event label: trial started")
        case AnalyticsEvent.offerCodeRedeemed.rawValue:
            named = NSLocalizedString("오퍼 코드를 씀", comment: "Event label: offer code redeemed")
        case AnalyticsEvent.proNudgeShown.rawValue:
            named = NSLocalizedString("Pro 권유를 봄", comment: "Event label: pro nudge shown")
        case AnalyticsEvent.proNudgeTapped.rawValue:
            named = NSLocalizedString("Pro 권유를 누름", comment: "Event label: pro nudge tapped")
        default:
            named = base
        }

        guard let slice else { return named }
        return String(format: NSLocalizedString("%1$@ (%2$@)", comment: "Event label with slice"), named, slice)
    }

    // MARK: - 마케팅 지표

    @ViewBuilder
    private var marketingSection: some View {
        let signals = UsageInsights.marketingSignals(snapshots: snapshots)
        if !signals.isEmpty {
            Section {
                ForEach(signals) { signal in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(signal.name).font(.body).foregroundColor(theme.text)
                            Spacer()
                            Text(signal.value).font(.body.weight(.medium)).foregroundColor(theme.text)
                        }
                        Text(signal.hint).font(.caption).foregroundColor(theme.textMuted)
                    }
                    .padding(.vertical, 1)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text(NSLocalizedString("마케팅 지표", comment: "Usage stats section: marketing signals"))
            }
        }
    }

    // MARK: - 정말 시간을 아끼고 있나

    /// 아낀 시간이 어느 칸까지 갔나 - 이 앱이 팔린 것인지 쓰이는 것인지가 여기서 갈린다.
    ///
    /// ⚠️ 1분은 누구나 넘는다(몇 번만 써도 넘는다). 봐야 할 것은 **5분과 한 시간**이다.
    ///    1분에서 5분으로 못 넘어가는 비율이 크면 "한 번 써 보고 말았다"는 뜻이고,
    ///    그건 기능이 아니라 첫 흐름의 문제다.
    ///
    /// ⚠️ 초 단위 값은 애초에 올라오지 않는다 - 이정표 이름만 온다.
    @ViewBuilder
    private var savedTimeSection: some View {
        let stages = UsageInsights.savedTimeStages(from: eventSamples)
        if stages.first?.installs ?? 0 > 0 {
            Section {
                ForEach(stages) { stage in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(stage.milestone.localizedTitle)
                                .font(.body.weight(.medium))
                                .foregroundColor(theme.text)
                            Spacer()
                            Text(String(format: NSLocalizedString("설치 %d곳", comment: "Funnel: install count"), stage.installs))
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(theme.textFaint.opacity(0.2))
                                Capsule().fill(Color.accentColor)
                                    .frame(width: max(2, geo.size.width * stage.rateFromFirst))
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text(NSLocalizedString("아낀 시간", comment: "Usage stats section: time saved"))
            } footer: {
                Text(NSLocalizedString("사용자가 아낀 시간이 어느 칸까지 갔는지예요. 큰 칸에 있는 사람은 작은 칸에도 들어가 있어요. 1분은 누구나 넘으니, 5분과 한 시간의 비율을 보세요.",
                                       comment: "Usage stats time saved footer"))
                    .font(.body)
            }
        }
    }

    // MARK: - 전환 퍼널 (페이월)

    /// 페이월 노출 → 구매 버튼 탭 → 구매 완료. 각 단계는 **설치 수** 기준이다.
    /// ⚠️ 이벤트에 6시간 쓰로틀이 걸려 있어 절대 수치는 실제보다 작다
    ///    단계 **사이의 비율**을 보는 용도다.
    @ViewBuilder
    private var funnelSection: some View {
        let stages = UsageInsights.paywallFunnel(from: eventSamples)
        let dropoffs = UsageInsights.dropoffReasons(from: eventSamples)

        if stages.first?.installs ?? 0 > 0 {
            Section {
                ForEach(stages) { stage in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(stage.name)
                                .font(.body.weight(.medium))
                                .foregroundColor(theme.text)
                            Spacer()
                            Text(String(format: NSLocalizedString("설치 %d곳", comment: "Funnel: install count"), stage.installs))
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                        }
                        // 첫 단계 대비 비율을 막대로 - 숫자만 있으면 감이 안 온다
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(theme.textFaint.opacity(0.2))
                                Capsule().fill(Color.accentColor)
                                    .frame(width: max(2, geo.size.width * stage.rateFromTop))
                            }
                        }
                        .frame(height: 6)
                        Text(String(format: NSLocalizedString("전체 대비 %1$@ · 직전 단계 대비 %2$@",
                                                              comment: "Funnel: conversion rates"),
                                    percent(stage.rateFromTop), percent(stage.rateFromPrevious)))
                            .font(.caption)
                            .foregroundColor(theme.textMuted)
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }

                ForEach(dropoffs.filter { $0.count > 0 }, id: \.name) { reason in
                    HStack {
                        Text(reason.name).font(.body).foregroundColor(theme.textMuted)
                        Spacer()
                        Text("\(reason.count)").font(.body).foregroundColor(theme.textMuted)
                    }
                }
            } header: {
                Text(NSLocalizedString("결제 전환 퍼널", comment: "Usage stats section: paywall funnel"))
            } footer: {
                Text(NSLocalizedString("같은 이벤트는 설치당 6시간에 한 번만 기록돼요. 절대 건수보다 단계 사이의 비율을 보세요.", comment: "Usage stats funnel footer"))
                    .font(.body)
            }
        }
    }

    // MARK: - 리텐션 코호트

    /// 설치한 주별로 묶어 D1/D7/D30 잔존을 본다.
    /// ⚠️ 아직 그날이 오지 않은 설치는 잔존으로 세지 않는다 → 최근 코호트의 D30은 낮게 보인다.
    @ViewBuilder
    private var retentionSection: some View {
        let rows = UsageInsights.weeklyRetention(snapshots: snapshots, events: eventSamples)

        if !rows.isEmpty {
            Section {
                ForEach(rows.prefix(8)) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(cohortLabel(row.cohortStart))
                                .font(.body.weight(.medium))
                                .foregroundColor(theme.text)
                            Spacer()
                            Text(String(format: NSLocalizedString("설치 %d곳", comment: "Cohort: install count"), row.size))
                                .font(.caption)
                                .foregroundColor(theme.textMuted)
                        }
                        HStack(spacing: 14) {
                            retentionCell("D1", row.rate(row.day1))
                            retentionCell("D7", row.rate(row.day7))
                            retentionCell("D30", row.rate(row.day30))
                        }
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text(NSLocalizedString("리텐션 (주간 코호트)", comment: "Usage stats section: weekly retention"))
            } footer: {
                Text(NSLocalizedString("설치한 주별로 묶어 며칠 뒤에도 앱을 열었는지 봐요. 아직 그날이 오지 않은 설치는 세지 않으니, 최근 코호트의 D30은 낮게 보입니다.", comment: "Usage stats retention footer"))
                    .font(.body)
            }
        }
    }

    private func retentionCell(_ label: String, _ rate: Double) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundColor(theme.textMuted)
            Text(percent(rate)).font(.body.weight(.medium)).foregroundColor(theme.text)
        }
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }

    private func cohortLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("M월 d일 주", comment: "Cohort week label format")
        return formatter.string(from: date)
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
                        Text(Self.eventLabel(event.name))
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

    /// 0/1 플래그가 아닌 수치 지표 - 값을 가진 설치들의 평균.
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

    /// 0/1 플래그(Pro·키보드 사용·페르소나) - 전체 설치 대비 비율.
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

        // 한 번에 다 달라고 하지 않는다 - 200건씩 이어 받으며 도착하는 대로 화면을 갱신한다.
        // 설치가 900건이 됐을 때 단일 요청이 서버 상한(400)에 걸려 화면 전체가 0이 됐던 게
        // 이 방식으로 바꾼 이유다. 도중에 끊겨도 그때까지 채워진 숫자는 남는다.
        //
        // 진행 상황(건수·페이지)과 "왜 멈췄는지" 를 같은 통로로 받아 두는 이유는 하나다.
        // 나눠 받기 시작한 순간부터, 화면은 지금 보이는 숫자가 최종본인지 말할 의무가 생긴다.
        snapshotStop = nil
        eventStop = nil
        snapshotPages = 0
        eventPages = 0

        do {
            snapshots = try await UsageReportingService.fetchSnapshots { progress in
                snapshots = progress.items
                snapshotPages = progress.pages
                snapshotStop = progress.stop
            }
        } catch { failures.append(error.localizedDescription) }

        do {
            eventSamples = try await UsageReportingService.fetchEvents { progress in
                eventSamples = progress.items
                eventPages = progress.pages
                eventStop = progress.stop
            }
        } catch { failures.append(error.localizedDescription) }

        do { feedback = try await UsageReportingService.fetchFeedback() }
        catch { failures.append(error.localizedDescription) }

        if !failures.isEmpty {
            errorMessage = String(format: NSLocalizedString("불러오지 못했어요: %@", comment: "Usage stats load failed"),
                                  Set(failures).joined(separator: "\n"))
        }
        loadedAt = Date()
        isLoading = false
    }
}
