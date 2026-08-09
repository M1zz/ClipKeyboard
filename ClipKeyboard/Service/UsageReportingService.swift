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

    /// 원격 킬스위치 — 사용자가 끄는 옵트아웃은 없지만, **개발자는 원격으로 멈출 수 있어야 한다**.
    /// 심사(5.1.1(ii))나 GDPR 지적을 받으면 심사 없이 즉시 수집을 중단하는 안전판.
    /// 조회 실패 시엔 true(켬)라 네트워크 문제로 수집이 임의로 멈추지는 않는다.
    private static var isReportingAllowed: Bool {
        RemoteFlagsService.cachedValue(.usageReportingEnabled)
    }

    /// 키보드만 쓴 날을 소급해서 남기는 이벤트 이름 — `appOpenEvent`와 짝이다.
    /// 앱을 연 날은 `app_open`, 키보드만 쓴 날은 이쪽. 둘을 합치면 진짜 활성 사용자다.
    static let keyboardActiveDayEvent = "keyboard_active_day"

    /// 한 번에 소급 전송할 날짜 수 상한 — 백그라운드 task의 짧은 실행 시간 안에 끝내려고 자른다.
    /// 남은 날은 원장에 그대로 있다가 다음 기회에 이어서 간다.
    private static let backfillBatchLimit = 40

    /// **프로세스가 뜰 때** 1회. 설치 스냅샷을 갱신한다(12시간 쓰로틀은 LeeoKit이 담당).
    ///
    /// ⚠️ 여기에 "사람이 앱을 열었다"는 신호를 두지 말 것. 백그라운드 새로고침으로
    ///    깨어난 경우에도 이 경로는 돈다 — 앱을 열지도 않은 사람이 접속한 것으로
    ///    잡히면, 하필 지금 가려내려는 "키보드만 쓰는 사람"이 앱 사용자로 둔갑한다.
    ///    사람이 앞으로 가져온 순간은 `reportForegroundOpen()`이 맡는다.
    static func reportProcessStart() {
        guard !isRunningTests, isReportingAllowed else { return }
        Task(priority: .utility) {
            await reporter.report(metrics: currentMetrics())
        }
    }

    /// 사람이 앱을 실제로 앞으로 가져온 순간. 콜드 런치와 백그라운드 복귀 양쪽에서 불린다.
    static func reportForegroundOpen() {
        // 실행 횟수는 프로세스당 1회만 — 리뷰 요청 타이밍이 복귀할 때마다 앞당겨지면 안 된다.
        if !didRegisterLaunch {
            didRegisterLaunch = true
            LeeoEngagement.shared.registerLaunch()
        }

        // 하루 1건 — 일/주/월/연 차트의 "활동한 사용자"가 실제 접속을 반영하게 한다.
        // 프로세스가 며칠씩 살아 있어도 복귀할 때마다 확인하므로 날짜를 놓치지 않는다.
        record(event: appOpenEvent, minInterval: 20 * 3600, countsAsEngagement: false)
    }

    private static var didRegisterLaunch = false

    /// 키보드 익스텐션이 쌓아 둔 활동일을 **그날 날짜 그대로** 허브에 남긴다.
    ///
    /// 익스텐션은 네트워크를 쓰지 않으므로(메모리 상한·심사 리스크) 활동일이 App Group에만
    /// 쌓인다. 앱이 열리거나 백그라운드 새로고침이 돌 때 여기서 몰아 보내되, 각 이벤트의
    /// `occurredAt`을 실제 사용일로 찍어 2주 만에 열어도 그 2주가 차트에 복원되게 한다.
    ///
    /// **오늘은 보내지 않는다.** 오늘 치를 보내고 원장에서 지우면, 오늘 키보드를 더 쓸 때
    /// 같은 날이 다시 쌓여 중복 이벤트가 된다. 오늘 앱을 열었다면 어차피 `app_open`이
    /// 활동을 증명하고, 안 열었다면 내일 이후 이 경로가 소급해서 메운다.
    static func reportKeyboardActiveDays() async {
        guard !isRunningTests, isReportingAllowed else { return }

        let today = KeyboardDayLedger.dayKey(for: Date())
        let pending = KeyboardDayLedger.pendingDays().filter { $0 < today }
        guard !pending.isEmpty else { return }

        // 루프 밖에서 한 번만 만든다 — `reporter`는 접근할 때마다 새 인스턴스를 뽑는 계산 프로퍼티다.
        let reporter = Self.reporter

        var sent: [String] = []
        for key in pending.prefix(backfillBatchLimit) {
            // 백그라운드 task 만료 — 여기까지 보낸 건 확정하고 나머지는 다음 기회에.
            if Task.isCancelled { break }

            // 날짜를 못 읽는 항목은 되살릴 방법이 없으니 원장에서 치운다(무한 재시도 방지).
            guard let occurredAt = KeyboardDayLedger.date(fromDayKey: key) else {
                sent.append(key)
                continue
            }
            // 실패하면 **거기서 멈춘다.** 남은 날은 원장에 그대로 두고 다음 기회에 이어 간다.
            guard await reporter.logEvent(keyboardActiveDayEvent, occurredAt: occurredAt) else { break }
            sent.append(key)
        }

        KeyboardDayLedger.removeDays(sent)
        let remaining = pending.count - sent.count
        print("📈 [UsageReportingService] 키보드 활동일 \(sent.count)일 소급 전송, \(remaining)일 남음")
    }

    /// 주요 행동 1건. 로컬 참여도 카운터를 올리고, 허브 쓰기는 이름당 쓰로틀 간격에 한 번만.
    /// - Parameters:
    ///   - name: 이벤트 이름(snake_case). 슬라이스가 있으면 `paywall_view:memo` 형태.
    ///   - minInterval: 같은 이름을 다시 보내기까지의 최소 간격 (기본 6시간).
    ///   - countsAsEngagement: 참여도 카운터(`eventCount` 지표)를 올릴지.
    ///     앱을 앞으로 가져온 것 자체는 "주요 행동"이 아니다 — 그건 실행 횟수가 이미 센다.
    ///     쓰로틀보다 자주 불리는 신호가 여기로 들어오면 지표가 조용히 부풀어 오른다.
    static func record(event name: String,
                       minInterval: TimeInterval = eventThrottle,
                       countsAsEngagement: Bool = true) {
        if countsAsEngagement { LeeoEngagement.shared.registerSignificantEvent() }

        let key = DefaultsKey.usageEventLastSentPrefix + name
        if let last = UserDefaults.standard.object(forKey: key) as? Date,
           Date().timeIntervalSince(last) < minInterval { return }
        UserDefaults.standard.set(Date(), forKey: key)

        guard !isRunningTests, isReportingAllowed else { return }
        reporter.logEventInBackground(String(name.prefix(60)))
    }

    /// 이 설치의 대략 지표 — 스냅샷 한 필드(metrics JSON)로 들어간다.
    /// 개수·분 단위 수치와 0/1 플래그만 담는다(내용·식별자 없음).
    static func currentMetrics() -> [String: Double] {
        var metrics: [String: Double] = [:]

        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        metrics["shortcuts"] = Double(memos.count)

        // ⚠️ 종류는 **서로 겹치지 않게** 센다 — 도넛 차트가 "전체의 몫"을 그리는데
        //    한 메모가 두 종류에 잡히면 합이 전체를 넘어 비율이 거짓말이 된다.
        //    우선순위: 콤보 > 템플릿 > 이미지 > 텍스트 (더 구체적인 것 먼저).
        var combos = 0, templates = 0, images = 0, texts = 0
        for memo in memos {
            if !memo.childMemoIds.isEmpty { combos += 1 }
            else if memo.isTemplate { templates += 1 }
            else if memo.imageFileName != nil || !memo.imageFileNames.isEmpty { images += 1 }
            else { texts += 1 }
        }
        metrics["combos"] = Double(combos)
        metrics["templates"] = Double(templates)
        metrics["images"] = Double(images)
        metrics["texts"] = Double(texts)

        metrics["favorites"] = Double(memos.filter(\.isFavorite).count)
        metrics["uses"] = Double(memos.reduce(0) { $0 + $1.clipCount })
        metrics["timeSavedMin"] = (KeyboardUsageTracker.totalTimeSavedSeconds() / 60).rounded()

        // 마케팅 판단용 — 전부 개수/0·1 플래그다. 내용은 들어가지 않는다.
        // 카테고리를 쓰는 사람 비율 → "정리 기능"을 얼마나 원하는지의 근거.
        metrics["categories"] = Double(CategoryStore.shared.allCategories.count)
        // 한 번도 안 쓴 단축어 비율 → 만들어만 두고 안 쓰는지(가치 전달 실패) 판단.
        metrics["unusedShortcuts"] = Double(memos.filter { $0.clipCount == 0 }.count)
        // 가장 많이 쓴 단축어의 사용 횟수 → 헤비 유저의 사용 깊이.
        metrics["topUses"] = Double(memos.map(\.clipCount).max() ?? 0)
        // 클립보드 기록 보유량 → 클립보드 기능을 실제로 쓰는지.
        metrics["clips"] = Double((try? MemoStore.shared.loadSmartClipboardHistory().count) ?? 0)

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
                // ⚠️ creationDate는 서버가 "쓴 시각"으로 찍는다. 키보드 활동일처럼 소급
                //    전송된 건 보낸 날로 뭉치므로, 실제 발생 시각(occurredAt)을 우선 본다.
                //    구버전이 남긴 레코드엔 이 필드가 없어 creationDate로 떨어진다.
                let occurredAt = (record["occurredAt"] as? Date) ?? record.creationDate ?? Date()
                samples.append(EventSample(name: (record["event"] as? String) ?? "-",
                                           installID: record["installID"] as? String,
                                           date: occurredAt))
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
