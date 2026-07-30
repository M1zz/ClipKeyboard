//
//  UsageInsights.swift
//  ClipKeyboard
//
//  전환 퍼널 + 리텐션 코호트 — **이미 쌓고 있는 데이터만으로** 계산한다.
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

    /// 이탈 사유별 건수 — 퍼널만으로는 "왜 안 샀는지"가 안 보인다.
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

    /// 화면에서 쓰는 편의 오버로드 — 스냅샷을 최소 입력으로 옮겨준다.
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
