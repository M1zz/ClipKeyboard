//
//  UsageStatsCache.swift
//  ClipKeyboard
//
//  사용 통계(개발자 화면)가 지난번에 받아 둔 것을 디스크에 적어 두고, 다음에는
//  **새로 생긴 것만** 받아 합친다.
//
//  왜 만들었나: 화면을 열 때마다 설치 스냅샷과 이벤트를 처음부터 다시 받았다.
//  설치가 늘수록 받는 양이 그대로 늘고, 200건짜리 페이지가 도착할 때마다 화면이
//  전부를 다시 계산해서(리텐션·분포·차트) 결국 앱이 버티지 못했다.
//
//  ⚠️ 여기 있는 것은 **남의 기록이 아니라 이미 받아 본 집계**다. 개발자 화면 전용이고
//     App Group 이 아니라 앱 전용 폴더에 둔다. 키보드가 읽을 일이 없다.
//

import Foundation

/// 디스크에 적어 두는 통계 한 벌.
struct UsageStatsSnapshotCache: Codable {
    /// 설치 스냅샷. 설치마다 한 줄이라 id 로 덮어쓴다.
    var snapshots: [Row] = []
    /// 이벤트 표본. 덧붙기만 하므로 오래된 것부터 버린다.
    var events: [Event] = []
    /// 스냅샷을 어디까지 받았나(레코드가 **고쳐진** 시각 기준).
    var snapshotWatermark: Date?
    /// 이벤트를 어디까지 받았나(레코드가 **만들어진** 시각 기준).
    var eventWatermark: Date?
    /// 마지막으로 받은 시각. 화면이 "언제 기준" 인지 말할 때 쓴다.
    var fetchedAt: Date?

    /// 스냅샷 한 줄. LeeoKit 의 타입은 Codable 이 아니라 여기서 필요한 것만 옮겨 적는다.
    struct Row: Codable, Identifiable {
        let id: String
        let appVersion: String
        let platform: String
        let osVersion: String
        let locale: String
        let launchCount: Int
        let eventCount: Int
        let daysSinceInstall: Int
        let installDate: Date?
        let lastActiveAt: Date?
        let metrics: [String: Double]
    }

    struct Event: Codable {
        let name: String
        let installID: String?
        let date: Date
        /// 서버가 찍은 만든 시각. 물때(watermark)는 이걸로 잰다.
        let createdAt: Date?
    }
}

enum UsageStatsCache {

    /// 이벤트를 이만큼만 들고 있는다. 넘으면 오래된 것부터 버린다.
    /// 화면의 차트가 보는 기간이 최근 쪽이라, 옛 표본을 쌓아 둘수록 메모리만 먹는다.
    static let eventLimit = 3000

    private static var fileURL: URL? {
        guard let dir = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil, create: true) else { return nil }
        return dir.appendingPathComponent("usage.stats.cache.json")
    }

    static func load() -> UsageStatsSnapshotCache {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let cache = try? JSONDecoder().decode(UsageStatsSnapshotCache.self, from: data) else {
            return UsageStatsSnapshotCache()
        }
        return cache
    }

    static func save(_ cache: UsageStatsSnapshotCache) {
        guard let url = fileURL, let data = try? JSONEncoder().encode(cache) else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            // 캐시가 없다고 화면이 못 서는 것은 아니다. 다음에는 전부 다시 받을 뿐이다.
            print("⚠️ [UsageStatsCache.save] 적지 못했다: \(error)")
        }
    }

    static func clear() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - 합치기 (순수 함수 - 시험은 여기 건다)

    /// 새로 받은 스냅샷을 옛것 위에 얹는다. 같은 설치는 **새것이 이긴다.**
    ///
    /// ⚠️ 설치마다 한 줄이라 덧붙이면 같은 사람이 여러 번 세어진다. 반드시 id 로 덮어쓴다.
    static func merged(snapshots old: [UsageStatsSnapshotCache.Row],
                       with fresh: [UsageStatsSnapshotCache.Row]) -> [UsageStatsSnapshotCache.Row] {
        var byID = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        for row in fresh { byID[row.id] = row }
        return byID.values.sorted { ($0.lastActiveAt ?? .distantPast) > ($1.lastActiveAt ?? .distantPast) }
    }

    /// 새 이벤트를 붙이고, 상한을 넘으면 **오래된 것부터** 버린다.
    ///
    /// ⚠️ 같은 이벤트가 두 번 들어올 수 있다(물때 경계에 걸린 것). 이름·설치·시각이
    ///    모두 같으면 같은 것으로 본다. 레코드 이름을 안 들고 있어서 이 셋으로 가른다.
    static func merged(events old: [UsageStatsSnapshotCache.Event],
                       with fresh: [UsageStatsSnapshotCache.Event],
                       limit: Int = eventLimit) -> [UsageStatsSnapshotCache.Event] {
        var seen = Set(old.map { key($0) })
        var out = old
        for event in fresh where !seen.contains(key(event)) {
            seen.insert(key(event))
            out.append(event)
        }
        out.sort { $0.date > $1.date }
        return Array(out.prefix(limit))
    }

    private static func key(_ e: UsageStatsSnapshotCache.Event) -> String {
        "\(e.name)|\(e.installID ?? "-")|\(e.date.timeIntervalSince1970)"
    }

    /// 다음에 어디서부터 받을지. 받아 온 것 중 **가장 나중 것**이 다음 물때다.
    /// 받은 게 없으면 옛 물때를 그대로 둔다(뒤로 물러나면 같은 것을 또 받는다).
    static func advanced(_ current: Date?, with dates: [Date?]) -> Date? {
        let newest = dates.compactMap { $0 }.max()
        guard let newest else { return current }
        guard let current else { return newest }
        return max(current, newest)
    }
}
