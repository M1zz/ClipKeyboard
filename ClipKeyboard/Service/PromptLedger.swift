//
//  PromptLedger.swift
//  ClipKeyboard
//
//  **말 거는 자리의 예산 장부.** 종류마다 언제 마지막으로 말했는지만 적는다.
//
//  왜 따로 두나: 예전에는 말하는 쪽마다 자기 열쇠(`proValueNudgeDismissed_v1`,
//  `didYouKnow.lastShownAt.v1` …)를 들고 있어서, 돈 이야기 다섯 갈래가 같은 날
//  모두 말할 수 있었다. 예산은 **종류**에 걸어야 한다. 누가 말했든 오늘 돈 이야기를
//  한 번 했으면 그날은 끝이다.
//
//  ⚠️ 말하는 쪽의 "평생 한 번" 열쇠는 그대로 둔다. 여기는 그 위에 얹는 종류별 예산이다.
//  ⚠️ App Group 에 둔다. 키보드도 같은 예산을 쓴다.
//  자세한 설계: docs/design/PROGRESSIVE_DISCLOSURE.md 4.3절
//

import Foundation

enum PromptLedger {

    /// 원장의 한 장면. 순수한 값이라 시험이 직접 만든다.
    struct Snapshot: Equatable, Codable {
        /// 종류마다 마지막으로 말한 때.
        var lastSpoke: [PromptKind: Date] = [:]
        /// 종류마다 마지막으로 거절당한 때(닫기·나중에).
        var lastDeclined: [PromptKind: Date] = [:]
        /// 종류마다 말할 때의 활동일 수. 소식 예산을 쓴 날로 센다.
        var activeDaysAtSpeak: [PromptKind: Int] = [:]
        /// 종류마다 마지막으로 말한 후보(`PromptCandidate.id`).
        ///
        /// ⚠️ 예산을 쓴 그 말은 **계속 서 있어도 된다.** 이걸 안 적으면 돈 이야기 카드가
        ///    뜨는 순간 예산을 다 써서, 다음 그리기에서 자기 예산에 걸려 도로 사라진다.
        var lastSpokeID: [PromptKind: String] = [:]

        static let empty = Snapshot()

        /// 말했다고 적는다.
        mutating func noteSpoke(_ kind: PromptKind, id: String, at date: Date, activeDays: Int) {
            lastSpoke[kind] = date
            activeDaysAtSpeak[kind] = activeDays
            lastSpokeID[kind] = id
        }

        /// 이 말이 지금 예산을 쥐고 있는가. 말한 뒤로 거절당하지 않았으면 쥐고 있다.
        func holdsBudget(_ kind: PromptKind, id: String) -> Bool {
            guard lastSpokeID[kind] == id, let spoke = lastSpoke[kind] else { return false }
            guard let declined = lastDeclined[kind] else { return true }
            return declined < spoke
        }

        /// 거절당했다고 적는다.
        mutating func noteDeclined(_ kind: PromptKind, at date: Date) {
            lastDeclined[kind] = date
        }
    }

    // MARK: - 기기

    private static var defaults: UserDefaults? { AppGroup.defaults }

    static var current: Snapshot {
        guard let data = defaults?.data(forKey: DefaultsKey.promptLedger),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    /// 말했다고 적는다. 이미 예산을 쥔 말이 다시 그려진 것이면 적지 않는다(시각이 밀리지 않게).
    static func noteSpoke(_ kind: PromptKind, id: String, activeDays: Int, now: Date = Date()) {
        var snapshot = current
        guard !snapshot.holdsBudget(kind, id: id) else { return }
        snapshot.noteSpoke(kind, id: id, at: now, activeDays: activeDays)
        save(snapshot)
        print("📝 [PromptLedger.noteSpoke] \(kind) \(id) 말함 (활동일 \(activeDays))")
    }

    static func noteDeclined(_ kind: PromptKind, now: Date = Date()) {
        var snapshot = current
        snapshot.noteDeclined(kind, at: now)
        save(snapshot)
        print("📝 [PromptLedger.noteDeclined] \(kind) 거절됨")
    }

    private static func save(_ snapshot: Snapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults?.set(data, forKey: DefaultsKey.promptLedger)
        } catch {
            print("❌ [PromptLedger.save] 인코딩 실패: \(error)")
        }
    }
}

// MARK: - 저장 열쇠

/// 원장에 **숫자 대신 이름**으로 적는다. 종류의 차례(rawValue)를 바꿔도 기록이 섞이지 않게.
extension PromptKind: Codable, CodingKeyRepresentable {
    private var storageName: String {
        switch self {
        case .status: return "status"
        case .moment: return "moment"
        case .unblock: return "unblock"
        case .nextFloor: return "nextFloor"
        case .money: return "money"
        case .ask: return "ask"
        case .news: return "news"
        }
    }

    private init?(storageName: String) {
        guard let kind = PromptKind.allCases.first(where: { $0.storageName == storageName }) else { return nil }
        self = kind
    }

    var codingKey: CodingKey { StorageKey(stringValue: storageName) }

    init?<T: CodingKey>(codingKey: T) {
        self.init(storageName: codingKey.stringValue)
    }

    init(from decoder: Decoder) throws {
        let name = try decoder.singleValueContainer().decode(String.self)
        guard let kind = PromptKind(storageName: name) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "알 수 없는 종류 \(name)"))
        }
        self = kind
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageName)
    }

    private struct StorageKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}
