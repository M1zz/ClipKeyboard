//
//  UsageReportingService.swift
//  ClipKeyboard
//
//  익명 사용 통계 — 피드백과 같은 공용 허브(FeedbackHub, CloudKit public DB)로 보내고 읽는다.
//  전송 엔진은 LeeoKit(LeeoUsageReporter)이고, 여기서는 이 앱의 지표·이벤트 정책만 정한다.
//
//  보내는 것
//   ① UsageSnapshot — 설치당 1개(익명 UUID recordName, upsert). 사용자 수/활성 사용자 집계용.
//   ② UsageEvent    — 주요 행동 스트림(이름만). "앱 사용 내용" 집계용, 이름당 6시간 쓰로틀.
//
//  ⚠️ PII 없음: 기기/계정 식별자, 메모 내용, 이메일 등은 절대 보내지 않는다.
//     보내는 값은 개수·시간 같은 집계 수치와 이벤트 이름뿐이다.
//  ⚠️ 옵트아웃 없음 — 앱 소유자 결정으로 항상 켜진 상태다(끄는 설정을 두지 않는다).
//     그래서 보내는 항목을 늘릴 땐 "이게 익명 집계 수치인가"를 더 엄격히 따질 것.
//  ⚠️ CloudKit Dashboard에 UsageSnapshot/UsageEvent 스키마 배포가 선행되어야 한다.
//     자세한 절차: docs/USAGE_STATS_HUB.md
//

import Foundation
import CloudKit
import LeeoKit

enum UsageReportingService {

    private static var reporter: LeeoUsageReporter {
        LeeoUsageReporter(spec: ClipKeyboardSpec.self)
    }

    /// 같은 이벤트 이름을 다시 보내기까지의 최소 간격 — 공개 DB 쓰기 폭주 방지.
    private static let eventThrottle: TimeInterval = 6 * 3600

    /// 유닛 테스트 중에는 허브에 실제로 쓰지 않는다 (쓰로틀 로직 자체는 그대로 검증된다).
    private static var isRunningTests: Bool { ClipKeyboardApp.isRunningUnitTests }

    // MARK: - 전송

    /// "이 설치가 오늘 활동했다"를 남기는 이벤트 이름 — 일간 활성 사용자(DAU) 차트의 근거.
    /// 스냅샷의 lastActiveAt은 덮어쓰기라 날짜별 이력이 남지 않아, 하루 1건 이벤트로 대신한다.
    static let appOpenEvent = "app_open"

    /// 앱 실행 시 1회. 실행 횟수를 기록하고(로컬), 설치 스냅샷을 갱신한다(12시간 쓰로틀은 LeeoKit이 담당).
    static func reportLaunch() {
        LeeoEngagement.shared.registerLaunch()

        // 하루 1건 — 일/주/월/연 차트의 "활동한 사용자"가 실제 접속을 반영하게 한다.
        record(event: appOpenEvent, minInterval: 20 * 3600)

        guard !isRunningTests else { return }
        Task(priority: .utility) {
            await reporter.report(metrics: currentMetrics())
        }
    }

    /// 주요 행동 1건. 로컬 참여도 카운터는 항상 올리고, 허브 쓰기는 이름당 쓰로틀 간격에 한 번만.
    /// - Parameters:
    ///   - name: 이벤트 이름(snake_case). 슬라이스가 있으면 `paywall_view:memo` 형태.
    ///   - minInterval: 같은 이름을 다시 보내기까지의 최소 간격 (기본 6시간).
    static func record(event name: String, minInterval: TimeInterval = eventThrottle) {
        LeeoEngagement.shared.registerSignificantEvent()

        let key = DefaultsKey.usageEventLastSentPrefix + name
        if let last = UserDefaults.standard.object(forKey: key) as? Date,
           Date().timeIntervalSince(last) < minInterval { return }
        UserDefaults.standard.set(Date(), forKey: key)

        guard !isRunningTests else { return }
        reporter.logEventInBackground(String(name.prefix(60)))
    }

    /// 이 설치의 대략 지표 — 스냅샷 한 필드(metrics JSON)로 들어간다.
    /// 개수·분 단위 수치와 0/1 플래그만 담는다(내용·식별자 없음).
    static func currentMetrics() -> [String: Double] {
        var metrics: [String: Double] = [:]

        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        metrics["shortcuts"] = Double(memos.count)
        metrics["combos"] = Double(memos.filter { !$0.childMemoIds.isEmpty }.count)
        metrics["templates"] = Double(memos.filter(\.isTemplate).count)
        metrics["images"] = Double(memos.filter { $0.imageFileName != nil || !$0.imageFileNames.isEmpty }.count)
        metrics["favorites"] = Double(memos.filter(\.isFavorite).count)
        metrics["uses"] = Double(memos.reduce(0) { $0 + $1.clipCount })
        metrics["timeSavedMin"] = (KeyboardUsageTracker.totalTimeSavedSeconds() / 60).rounded()

        let group = UserDefaults(suiteName: AppGroup.identifier)
        metrics["keyboardUses"] = Double(group?.integer(forKey: DefaultsKey.kbBeaconTotalCount) ?? 0)
        metrics["flag.keyboardActive"] = (group?.double(forKey: DefaultsKey.kbBeaconLastUse) ?? 0) > 0 ? 1 : 0
        metrics["flag.syncOn"] = (group?.bool(forKey: DefaultsKey.memoSyncEnabled) ?? false) ? 1 : 0
        metrics["flag.isPro"] = ProFeatureManager.hasFullAccess ? 1 : 0
        if let persona = CategoryStore.shared.selectedPersona?.rawValue {
            metrics["persona.\(persona)"] = 1
        }

        return metrics
    }

    // MARK: - 조회 (개발자 통계 화면용)

    typealias Snapshot = LeeoUsageReporter.UsageSnapshot

    /// 설치 스냅샷 전체 (이 앱 것만, 최근 활동순).
    static func fetchSnapshots(limit: Int = 1000) async throws -> [Snapshot] {
        try await reporter.fetchSnapshots(limit: limit)
    }

    /// 이벤트 이름별 집계 결과.
    struct EventStat: Identifiable, Sendable {
        let name: String
        /// 기록된 이벤트 건수 (조회 범위 안에서).
        let count: Int
        /// 그 이벤트를 남긴 서로 다른 설치 수.
        let installs: Int
        /// 가장 최근 발생 시각.
        let lastAt: Date?
        var id: String { name }
    }

    /// 이벤트 1건 (차트용 원본 표본).
    struct EventSample: Sendable {
        let name: String
        let installID: String?
        let date: Date
    }

    /// 최근 이벤트를 원본 표본 그대로 읽는다 — 이름별 집계와 기간별 차트가 이 하나를 함께 쓴다.
    /// LeeoKit은 스냅샷 조회만 제공해서, 이벤트 스트림은 여기서 직접 읽는다.
    /// CloudKit이 한 요청에 주는 개수는 서버가 정하므로 커서로 이어 받는다.
    /// ⚠️ 남의 레코드를 읽으므로 컨테이너 read 권한이 필요하다(피드백 인박스와 동일).
    static func fetchEvents(limit: Int = 3000) async throws -> [EventSample] {
        let config = ClipKeyboardSpec.feedback
        let database = CKContainer(identifier: config.containerIdentifier).publicCloudDatabase

        // 허브 전체를 읽고 appId는 클라이언트에서 거른다 — appId Queryable 인덱스 없이 동작하게.
        let query = CKQuery(recordType: LeeoUsageReporter.eventType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        var samples: [EventSample] = []
        var cursor: CKQueryOperation.Cursor?
        repeat {
            let page: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
            if let cursor {
                page = try await database.records(continuingMatchFrom: cursor,
                                                  resultsLimit: min(200, limit - samples.count))
            } else {
                page = try await database.records(matching: query,
                                                  resultsLimit: min(200, limit))
            }

            for record in page.matchResults.compactMap({ try? $0.1.get() }) {
                guard config.appIdentifier == nil || (record["appId"] as? String) == config.appIdentifier else { continue }
                samples.append(EventSample(name: (record["event"] as? String) ?? "-",
                                           installID: record["installID"] as? String,
                                           date: record.creationDate ?? Date()))
            }
            cursor = page.queryCursor
        } while cursor != nil && samples.count < limit

        return samples
    }

    /// 표본 → 이름별 집계 (화면 계산용, 네트워크 없음).
    static func eventStats(from samples: [EventSample]) -> [EventStat] {
        var counts: [String: (count: Int, installs: Set<String>, lastAt: Date?)] = [:]
        for sample in samples {
            var entry = counts[sample.name] ?? (0, [], nil)
            entry.count += 1
            if let install = sample.installID { entry.installs.insert(install) }
            if (entry.lastAt ?? .distantPast) < sample.date { entry.lastAt = sample.date }
            counts[sample.name] = entry
        }
        return counts
            .map { EventStat(name: $0.key, count: $0.value.count, installs: $0.value.installs.count, lastAt: $0.value.lastAt) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - 기간별 추이 (일·주·월·연)

    /// 차트 묶음 단위.
    enum BucketUnit: String, CaseIterable, Identifiable {
        case day, week, month, year
        var id: String { rawValue }

        var calendarComponent: Calendar.Component {
            switch self {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            case .year: return .year
            }
        }

        /// 한 화면에 보이는 묶음 개수 — 나머지는 좌우로 스크롤해서 본다.
        var visibleBuckets: Int {
            switch self {
            case .day: return 14
            case .week: return 12
            case .month: return 12
            case .year: return 5
            }
        }

        var localizedName: String {
            switch self {
            case .day: return NSLocalizedString("일간", comment: "Chart bucket: daily")
            case .week: return NSLocalizedString("주간", comment: "Chart bucket: weekly")
            case .month: return NSLocalizedString("월간", comment: "Chart bucket: monthly")
            case .year: return NSLocalizedString("연간", comment: "Chart bucket: yearly")
            }
        }
    }

    /// 한 묶음(하루/한 주/한 달/한 해)의 집계값.
    struct TrendPoint: Identifiable, Sendable {
        /// 묶음의 시작 시각 (차트 X축 값).
        let date: Date
        /// 그 기간에 기록된 이벤트 건수.
        let events: Int
        /// 그 기간에 활동한 서로 다른 설치 수.
        let activeInstalls: Int
        /// 그 기간에 처음 설치된 수.
        let newInstalls: Int
        var id: Date { date }
    }

    /// 빈 구간까지 채운 연속 추이를 만든다 — 차트가 끊기지 않도록.
    /// 데이터가 없으면 빈 배열. 안전장치로 최대 400묶음까지만 만든다.
    static func trend(unit: BucketUnit,
                      events: [EventSample],
                      snapshots: [Snapshot],
                      calendar: Calendar = .current,
                      now: Date = Date()) -> [TrendPoint] {
        func bucketStart(_ date: Date) -> Date? {
            calendar.dateInterval(of: unit.calendarComponent, for: date)?.start
        }

        var eventCounts: [Date: Int] = [:]
        var installsByBucket: [Date: Set<String>] = [:]
        for sample in events {
            guard let start = bucketStart(sample.date) else { continue }
            eventCounts[start, default: 0] += 1
            if let install = sample.installID {
                installsByBucket[start, default: []].insert(install)
            }
        }

        var newInstalls: [Date: Int] = [:]
        for snapshot in snapshots {
            guard let installDate = snapshot.installDate, let start = bucketStart(installDate) else { continue }
            newInstalls[start, default: 0] += 1
        }

        let starts = Set(eventCounts.keys).union(installsByBucket.keys).union(newInstalls.keys)
        guard let first = starts.min(), let today = bucketStart(now) else { return [] }
        let last = max(starts.max() ?? today, today)

        var points: [TrendPoint] = []
        var cursor = first
        while cursor <= last && points.count < 400 {
            points.append(TrendPoint(date: cursor,
                                     events: eventCounts[cursor] ?? 0,
                                     activeInstalls: installsByBucket[cursor]?.count ?? 0,
                                     newInstalls: newInstalls[cursor] ?? 0))
            guard let next = calendar.date(byAdding: unit.calendarComponent, value: 1, to: cursor) else { break }
            cursor = next
        }
        return points
    }

    /// 허브에 접수된 이 앱의 피드백 (최신순). 통계 화면 요약용.
    static func fetchFeedback(limit: Int = 100) async throws -> [LeeoFeedbackService.FeedbackRecord] {
        try await LeeoFeedbackService(spec: ClipKeyboardSpec.self).fetchAll(limit: limit)
    }
}
