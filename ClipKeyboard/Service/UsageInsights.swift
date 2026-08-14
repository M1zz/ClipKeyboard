//
//  UsageInsights.swift
//  ClipKeyboard
//
//  전환 퍼널 + 리텐션 코호트 - **이미 쌓고 있는 데이터만으로** 계산한다.
//  새 이벤트를 추가하지 않는다(수집 항목이 늘면 개인정보 신고도 같이 늘어난다).
//
//  퍼널 근거: AnalyticsEvent 의 기존 이벤트들
//      paywall_view → paywall_cta_tapped → paywall_purchase
//      (이탈은 paywall_dismissed / purchase_cancelled / purchase_failed)
//  코호트 근거: UsageSnapshot.installDate(가입일) + `app_open` 이벤트(활동일)
//
//  ⚠️ 전부 **순수 함수**다. 네트워크·CloudKit을 모르기 때문에 유닛 테스트가 가능하고,
//     화면(UsageStatsView)은 이미 받아온 표본을 넘겨주기만 하면 된다.
//
//  ⚠️ 한계: 이벤트에 6시간 쓰로틀이 걸려 있어 **같은 사람이 하루에 여러 번 본 페이월은
//     1건으로 집계된다.** 절대 수치가 아니라 단계 간 비율을 보는 용도다.
//

import Foundation

enum UsageInsights {

    // MARK: - 전환 퍼널

    struct FunnelStage: Identifiable {
        let name: String
        /// 이 단계에 도달한 서로 다른 설치 수.
        let installs: Int
        /// 첫 단계 대비 비율 (0.0 ~ 1.0).
        let rateFromTop: Double
        /// 직전 단계 대비 비율 (0.0 ~ 1.0). 첫 단계는 1.0.
        let rateFromPrevious: Double
        var id: String { name }
    }

    /// 이벤트 이름이 슬라이스(`paywall_view:memo`)를 달고 오므로 접두사로 맞춘다.
    private static func installs(in samples: [UsageReportingService.EventSample],
                                 named prefix: String) -> Set<String> {
        var result = Set<String>()
        for sample in samples where sample.name == prefix || sample.name.hasPrefix(prefix + ":") {
            if let id = sample.installID { result.insert(id) }
        }
        return result
    }

    /// 페이월 전환 퍼널. 각 단계는 **서로 다른 설치 수** 기준이다.
    static func paywallFunnel(from samples: [UsageReportingService.EventSample]) -> [FunnelStage] {
        let steps: [(String, String)] = [
            (NSLocalizedString("페이월 노출", comment: "Funnel stage: paywall shown"), AnalyticsEvent.paywallView.rawValue),
            (NSLocalizedString("구매 버튼 탭", comment: "Funnel stage: purchase button tapped"), AnalyticsEvent.paywallCtaTapped.rawValue),
            (NSLocalizedString("구매 완료", comment: "Funnel stage: purchase completed"), AnalyticsEvent.paywallPurchase.rawValue)
        ]

        var stages: [FunnelStage] = []
        var topCount = 0
        var previousCount = 0

        for (index, step) in steps.enumerated() {
            let count = installs(in: samples, named: step.1).count
            if index == 0 { topCount = count }

            stages.append(FunnelStage(
                name: step.0,
                installs: count,
                rateFromTop: topCount > 0 ? Double(count) / Double(topCount) : 0,
                rateFromPrevious: index == 0 ? 1.0 : (previousCount > 0 ? Double(count) / Double(previousCount) : 0)
            ))
            previousCount = count
        }
        return stages
    }

    /// 이탈 사유별 건수 - 퍼널만으로는 "왜 안 샀는지"가 안 보인다.
    static func dropoffReasons(from samples: [UsageReportingService.EventSample]) -> [(name: String, count: Int)] {
        let reasons: [(String, String)] = [
            (NSLocalizedString("그냥 닫음", comment: "Dropoff: dismissed"), AnalyticsEvent.paywallDismissed.rawValue),
            (NSLocalizedString("결제 취소", comment: "Dropoff: purchase cancelled"), AnalyticsEvent.purchaseCancelled.rawValue),
            (NSLocalizedString("결제 실패", comment: "Dropoff: purchase failed"), AnalyticsEvent.purchaseFailed.rawValue)
        ]
        return reasons.map { label, event in
            let count = samples.filter { $0.name == event || $0.name.hasPrefix(event + ":") }.count
            return (label, count)
        }
    }

    // MARK: - 단축어 개수 분포 (막대)

    struct DistributionBucket: Identifiable {
        let label: String
        /// 이 구간에 속한 설치 수.
        let installs: Int
        /// 정렬용 하한값.
        let lowerBound: Int
        var id: String { label }
    }

    /// "몇 개 쓰는 사람이 몇 명인지" - 설치를 단축어 개수 구간으로 나눈다.
    /// 무료 한도(10개) 근처가 중요해서 그 앞뒤를 촘촘히 끊었다:
    /// 한도 직전(7~9)에 몰려 있으면 한도가 전환을 만들고 있다는 뜻이고,
    /// 1~3에 몰려 있으면 만들다 마는 것(가치 전달 실패)이다.
    ///
    /// ⚠️ **9개는 따로 센다.** 한 칸 남은 사람이 몇 명인지가 이 화면에서 가장 값진 숫자다
    /// (할인 제안이 겨냥하는 바로 그 무리이고, 그 수가 곧 제안이 닿을 수 있는 사람의 수다).
    /// 7~9로 뭉뚱그리면 7개인 사람과 섞여서 그 크기를 알 수 없다.
    /// 화면용 편의 오버로드.
    static func shortcutDistribution(snapshots: [UsageReportingService.Snapshot]) -> [DistributionBucket] {
        shortcutDistribution(metrics: snapshots.map(\.metrics))
    }

    /// ⚠️ 지표 딕셔너리만 받는다 - `UsageSnapshot` 은 CKRecord 전용 생성자뿐이라
    ///    그대로 받으면 유닛 테스트로 검증할 수 없다(리텐션에서 겪은 것과 같은 문제).
    static func shortcutDistribution(metrics snapshots: [[String: Double]]) -> [DistributionBucket] {
        // ⚠️ 라벨에 붙임표(en dash)를 쓰지 않는다 - 저장소 규칙. 범위는 물결표로.
        let bounds: [(String, Int, Int)] = [
            (NSLocalizedString("0개", comment: "Distribution bucket: none"), 0, 0),
            ("1~3", 1, 3),
            ("4~6", 4, 6),
            ("7~8", 7, 8),
            // ⚠️ 라벨은 짧게 - x축에 일곱 칸이 서므로 길면 다 잘린다.
            //    "한 칸 남은 사람"이라는 뜻은 화면 아래 설명이 맡는다.
            (NSLocalizedString("9개", comment: "Distribution bucket: exactly 9, one slot left before the free limit"), 9, 9),
            ("10~19", 10, 19),
            (NSLocalizedString("20개 이상", comment: "Distribution bucket: 20 or more"), 20, Int.max)
        ]
        return bounds.map { label, lower, upper in
            let count = snapshots.filter { metrics in
                let n = Int(metrics["shortcuts"] ?? 0)
                return n >= lower && n <= upper
            }.count
            return DistributionBucket(label: label, installs: count, lowerBound: lower)
        }
    }

    // MARK: - 단축어 종류 (도넛)

    struct TypeShare: Identifiable {
        let name: String
        let count: Int
        /// 전체 대비 비율 (0.0 ~ 1.0).
        let ratio: Double
        var id: String { name }
    }

    /// 종류별 단축어 총합. `currentMetrics()` 가 **겹치지 않게** 세므로 합이 전체와 맞는다.
    /// ⚠️ `texts` 는 4.4.3부터 수집한다 - 그 이전 스냅샷에는 없어서 0으로 잡힌다.
    ///    옛 스냅샷이 섞이면 텍스트 비중이 실제보다 낮게 보인다(시간이 지나면 해소).
    static func typeBreakdown(snapshots: [UsageReportingService.Snapshot]) -> [TypeShare] {
        typeBreakdown(metrics: snapshots.map(\.metrics))
    }

    static func typeBreakdown(metrics snapshots: [[String: Double]]) -> [TypeShare] {
        func total(_ key: String) -> Int {
            snapshots.reduce(0) { $0 + Int($1[key] ?? 0) }
        }
        let raw: [(String, Int)] = [
            (NSLocalizedString("텍스트", comment: "Shortcut type: plain text"), total("texts")),
            (NSLocalizedString("템플릿", comment: "Shortcut type: template"), total("templates")),
            (NSLocalizedString("콤보", comment: "Shortcut type: combo"), total("combos")),
            (NSLocalizedString("이미지", comment: "Shortcut type: image"), total("images"))
        ]
        let sum = raw.reduce(0) { $0 + $1.1 }
        guard sum > 0 else { return [] }
        return raw.map { TypeShare(name: $0.0, count: $0.1, ratio: Double($0.1) / Double(sum)) }
    }

    // MARK: - 사용 유형 (사람을 무리로 나눈다)

    /// 쓰는 모습으로 나눈 무리 하나.
    struct UserSegment: Identifiable {
        let kind: SegmentKind
        /// 이 무리에 속한 설치 수.
        let installs: Int
        /// 전체 대비 비율 (0.0 ~ 1.0).
        let ratio: Double
        var id: String { kind.rawValue }
        var name: String { kind.localizedName }
        /// 이 무리에게 무엇을 해야 하는가 - 숫자만 보면 다음 할 일이 안 나온다.
        var hint: String { kind.localizedHint }
    }

    /// ⚠️ 순서가 곧 판정 순서다. 위에서부터 걸리는 첫 무리가 그 사람의 무리이고,
    ///    그래서 **한 사람은 정확히 한 무리에만** 속한다(합이 전체와 맞는다).
    enum SegmentKind: String, CaseIterable {
        /// 아직 하나도 안 만들었다.
        case notStarted
        /// 만들어 놓고 한 번도 안 썼다 - 이 앱의 값어치를 아직 못 봤다.
        case lost
        /// 많이 쓴다.
        case heavy
        /// 적게 만들고 그것만 계속 쓴다.
        case oneTrick
        /// 잔뜩 만들어 놓고 대부분 안 쓴다.
        case hoarder
        /// 꾸준히 쓴다.
        case regular
        /// 이제 막 써 보는 중.
        case dabbling

        var localizedName: String {
            switch self {
            case .notStarted: return NSLocalizedString("아직 안 만든 사람", comment: "User segment: created nothing yet")
            case .lost:       return NSLocalizedString("만들고 안 쓴 사람", comment: "User segment: created but never used")
            case .heavy:      return NSLocalizedString("많이 쓰는 사람", comment: "User segment: heavy user")
            case .oneTrick:   return NSLocalizedString("하나만 계속 쓰는 사람", comment: "User segment: one shortcut, used a lot")
            case .hoarder:    return NSLocalizedString("쌓아만 두는 사람", comment: "User segment: many shortcuts, mostly unused")
            case .regular:    return NSLocalizedString("꾸준히 쓰는 사람", comment: "User segment: regular user")
            case .dabbling:   return NSLocalizedString("이제 막 써 보는 사람", comment: "User segment: just getting started")
            }
        }

        var localizedHint: String {
            switch self {
            case .notStarted:
                return NSLocalizedString("첫 단축어까지 못 갔어요. 여기가 막히면 그 뒤는 전부 안 일어나요.", comment: "Segment hint: not started")
            case .lost:
                return NSLocalizedString("만들었는데 쓸 자리를 못 찾았어요. 키보드를 켜는 데까지 데려가야 해요.", comment: "Segment hint: lost")
            case .heavy:
                return NSLocalizedString("이 앱이 하루에 박혀 있는 사람들이에요. 리뷰와 입소문이 여기서 나와요.", comment: "Segment hint: heavy")
            case .oneTrick:
                return NSLocalizedString("한 가지 일에 딱 맞게 쓰고 있어요. 두 번째 쓸모를 알려주면 늘어나요.", comment: "Segment hint: one trick")
            case .hoarder:
                return NSLocalizedString("만드는 건 쉬운데 꺼내 쓰는 게 어려운 거예요. 찾기와 순서를 봐야 해요.", comment: "Segment hint: hoarder")
            case .regular:
                return NSLocalizedString("자리를 잡았어요. 한도에 닿으면 결제로 이어지는 무리예요.", comment: "Segment hint: regular")
            case .dabbling:
                return NSLocalizedString("아직 판단 중이에요. 이 무리가 어디로 가는지가 다음 버전의 답이에요.", comment: "Segment hint: dabbling")
            }
        }
    }

    /// 화면용 편의 오버로드.
    static func userSegments(snapshots: [UsageReportingService.Snapshot]) -> [UserSegment] {
        userSegments(metrics: snapshots.map(\.metrics))
    }

    /// 설치를 쓰는 모습으로 나눈다.
    ///
    /// 개수 분포가 "몇 개 가졌나"를 본다면 이쪽은 **"그래서 쓰고 있나"** 를 본다.
    /// 같은 5개라도 매일 꺼내 쓰는 사람과 만들어만 둔 사람은 전혀 다른 사람이고,
    /// 해야 할 일도 다르다(전자는 결제 대상, 후자는 사용성 문제).
    ///
    /// ⚠️ 판정은 `SegmentKind.allCases` 순서대로 **첫 번째로 걸리는 것** 하나다.
    ///    그래야 합이 전체와 맞고, "이 사람은 어느 무리인가"에 답이 하나로 나온다.
    static func userSegments(metrics snapshots: [[String: Double]]) -> [UserSegment] {
        guard !snapshots.isEmpty else { return [] }

        var counts: [SegmentKind: Int] = [:]
        for m in snapshots {
            counts[classify(m), default: 0] += 1
        }
        let total = Double(snapshots.count)
        return SegmentKind.allCases.map { kind in
            let n = counts[kind] ?? 0
            return UserSegment(kind: kind, installs: n, ratio: Double(n) / total)
        }
    }

    /// 설치 하나가 어느 무리인가.
    ///
    /// 기준값은 눈대중이 아니라 이 앱의 구조에서 온다.
    ///  · 무료 한도가 10이라 8개 이상이면 "많이 만든" 쪽이다.
    ///  · 사용 50회는 하루 두 번씩 한 달쯤 쓴 양이다.
    static func classify(_ m: [String: Double]) -> SegmentKind {
        func v(_ key: String) -> Double { m[key] ?? 0 }

        let shortcuts = v("shortcuts")
        let uses = v("uses")
        let keyboardUses = v("keyboardUses")
        let unused = v("unusedShortcuts")
        let totalUses = uses + keyboardUses

        if shortcuts < 1 { return .notStarted }
        if totalUses < 1 { return .lost }
        if totalUses >= 50 { return .heavy }
        if shortcuts <= 3, totalUses >= 10 { return .oneTrick }
        // 많이 만들어 놓고 대부분(70% 이상) 한 번도 안 썼다.
        if shortcuts >= 8, unused / shortcuts >= 0.7 { return .hoarder }
        if totalUses >= 5 { return .regular }
        return .dabbling
    }

    // MARK: - 키보드 사용량

    struct KeyboardUsage {
        /// 키보드를 한 번이라도 쓴 설치 수.
        let activeInstalls: Int
        /// 전체 설치 수.
        let totalInstalls: Int
        /// 키보드 입력 총 횟수.
        let totalUses: Int
        /// 절약한 시간 합계(분).
        let totalTimeSavedMin: Int

        /// 키보드 활성화율 - **온보딩 성패를 가장 잘 보여주는 숫자**.
        /// 앱은 깔았는데 키보드를 안 켰다면 이 앱의 핵심 가치를 아직 못 받은 것이다.
        var adoptionRate: Double {
            totalInstalls > 0 ? Double(activeInstalls) / Double(totalInstalls) : 0
        }
        /// 키보드를 쓰는 설치당 평균 입력 횟수.
        var usesPerActiveInstall: Double {
            activeInstalls > 0 ? Double(totalUses) / Double(activeInstalls) : 0
        }
    }

    static func keyboardUsage(snapshots: [UsageReportingService.Snapshot]) -> KeyboardUsage {
        keyboardUsage(metrics: snapshots.map(\.metrics))
    }

    static func keyboardUsage(metrics snapshots: [[String: Double]]) -> KeyboardUsage {
        KeyboardUsage(
            activeInstalls: snapshots.filter { ($0["flag.keyboardActive"] ?? 0) > 0 }.count,
            totalInstalls: snapshots.count,
            totalUses: snapshots.reduce(0) { $0 + Int($1["keyboardUses"] ?? 0) },
            totalTimeSavedMin: snapshots.reduce(0) { $0 + Int($1["timeSavedMin"] ?? 0) }
        )
    }

    // MARK: - 마케팅 지표

    struct MarketingSignal: Identifiable {
        let name: String
        let value: String
        /// 이 숫자를 어떻게 읽어야 하는지 - 숫자만 있으면 판단을 못 한다.
        let hint: String
        var id: String { name }
    }

    /// 마케팅·제품 판단에 바로 쓰이는 비율들.
    static func marketingSignals(snapshots: [UsageReportingService.Snapshot]) -> [MarketingSignal] {
        marketingSignals(metrics: snapshots.map(\.metrics))
    }

    static func marketingSignals(metrics snapshots: [[String: Double]]) -> [MarketingSignal] {
        guard !snapshots.isEmpty else { return [] }
        let n = Double(snapshots.count)

        func ratio(_ predicate: ([String: Double]) -> Bool) -> String {
            String(format: "%.0f%%", Double(snapshots.filter(predicate).count) / n * 100)
        }
        func average(_ key: String) -> String {
            String(format: "%.1f", snapshots.reduce(0.0) { $0 + ($1[key] ?? 0) } / n)
        }

        let totalShortcuts = snapshots.reduce(0.0) { $0 + ($1["shortcuts"] ?? 0) }
        let totalUnused = snapshots.reduce(0.0) { $0 + ($1["unusedShortcuts"] ?? 0) }
        let unusedRate = totalShortcuts > 0 ? totalUnused / totalShortcuts * 100 : 0

        return [
            MarketingSignal(name: NSLocalizedString("Pro 전환율", comment: "Marketing: pro conversion"),
                            value: ratio { ($0["flag.isPro"] ?? 0) > 0 },
                            hint: NSLocalizedString("결제까지 간 비율이에요.", comment: "Marketing hint: pro")),
            MarketingSignal(name: NSLocalizedString("카테고리 사용", comment: "Marketing: category adoption"),
                            value: ratio { ($0["categories"] ?? 0) > 0 },
                            hint: NSLocalizedString("정리 기능을 실제로 쓰는 비율이에요.", comment: "Marketing hint: category")),
            MarketingSignal(name: NSLocalizedString("클립보드 사용", comment: "Marketing: clipboard adoption"),
                            value: ratio { ($0["clips"] ?? 0) > 0 },
                            hint: NSLocalizedString("클립보드 기록을 쓰는 비율이에요.", comment: "Marketing hint: clipboard")),
            MarketingSignal(name: NSLocalizedString("동기화 사용", comment: "Marketing: sync adoption"),
                            value: ratio { ($0["flag.syncOn"] ?? 0) > 0 },
                            hint: NSLocalizedString("기기를 2대 이상 쓰는 신호예요.", comment: "Marketing hint: sync")),
            MarketingSignal(name: NSLocalizedString("안 쓰는 단축어", comment: "Marketing: unused shortcuts"),
                            value: String(format: "%.0f%%", unusedRate),
                            hint: NSLocalizedString("만들어만 두고 안 쓰는 비율. 높으면 가치 전달이 덜 된 거예요.", comment: "Marketing hint: unused")),
            MarketingSignal(name: NSLocalizedString("설치당 단축어", comment: "Marketing: shortcuts per install"),
                            value: average("shortcuts"),
                            hint: NSLocalizedString("평균 몇 개를 만드는지예요.", comment: "Marketing hint: avg shortcuts"))
        ]
    }

    // MARK: - 리텐션 코호트

    struct RetentionRow: Identifiable {
        /// 설치 주 시작일 (코호트 라벨).
        let cohortStart: Date
        /// 이 코호트의 설치 수.
        let size: Int
        /// D1 / D7 / D30 잔존 설치 수.
        let day1: Int
        let day7: Int
        let day30: Int
        var id: Date { cohortStart }

        func rate(_ retained: Int) -> Double { size > 0 ? Double(retained) / Double(size) : 0 }
    }

    /// 코호트 계산에 실제로 필요한 것만 담은 입력.
    /// ⚠️ `UsageSnapshot`(CloudKit `CKRecord` 전용 생성자만 있음)에 직접 의존하면
    ///    이 함수를 유닛 테스트로 검증할 수 없다. 그래서 한 겹 분리한다.
    struct Install {
        let id: String
        let installDate: Date?
    }

    /// 화면에서 쓰는 편의 오버로드 - 스냅샷을 최소 입력으로 옮겨준다.
    static func weeklyRetention(snapshots: [UsageReportingService.Snapshot],
                                events: [UsageReportingService.EventSample],
                                calendar: Calendar = .current,
                                now: Date = Date()) -> [RetentionRow] {
        weeklyRetention(installs: snapshots.map { Install(id: $0.id, installDate: $0.installDate) },
                        events: events, calendar: calendar, now: now)
    }

    /// 주간 코호트 리텐션.
    /// - installDate 로 코호트를 나누고, `app_open` 이벤트로 "그날 활동했는가"를 본다.
    /// - ⚠️ `app_open` 은 20시간 쓰로틀이라 하루 1건 이하다 → 날짜 단위 판정에 적합하다.
    static func weeklyRetention(installs snapshots: [Install],
                                events: [UsageReportingService.EventSample],
                                calendar: Calendar = .current,
                                now: Date = Date()) -> [RetentionRow] {

        // 설치별 활동일(자정 기준) 집합
        var activeDays: [String: Set<Date>] = [:]
        for event in events where event.name == UsageReportingService.appOpenEvent {
            guard let id = event.installID else { continue }
            activeDays[id, default: []].insert(calendar.startOfDay(for: event.date))
        }

        // 코호트(설치 주)별로 묶는다
        var cohorts: [Date: [(id: String, installedAt: Date)]] = [:]
        for snapshot in snapshots {
            guard let installDate = snapshot.installDate else { continue }
            guard let week = calendar.dateInterval(of: .weekOfYear, for: installDate)?.start else { continue }
            cohorts[week, default: []].append((snapshot.id, installDate))
        }

        return cohorts.map { week, members in
            /// 설치 후 `offset`일째에 활동했는지. 아직 그날이 오지 않은 설치는 분모에서 빼야
            /// 하지만, 여기서는 단순화를 위해 **경과한 설치만** 센다(아래 guard).
            func retained(after offset: Int) -> Int {
                members.filter { member in
                    guard let target = calendar.date(byAdding: .day, value: offset,
                                                     to: calendar.startOfDay(for: member.installedAt)),
                          target <= now else { return false }   // 아직 안 온 날은 잔존으로 세지 않는다
                    return activeDays[member.id]?.contains(target) ?? false
                }.count
            }

            return RetentionRow(cohortStart: week,
                                size: members.count,
                                day1: retained(after: 1),
                                day7: retained(after: 7),
                                day30: retained(after: 30))
        }
        .sorted { $0.cohortStart > $1.cohortStart }
    }
}
