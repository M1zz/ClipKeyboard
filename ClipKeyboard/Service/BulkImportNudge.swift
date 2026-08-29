//
//  BulkImportNudge.swift
//  ClipKeyboard
//
//  **한 번에 정리하기를, 찾아오게 하지 않고 필요한 순간에 내놓는다.**
//
//  왜 필요한가: 대량 가져오기는 "단축어 목록의 + 안"에 있다. 안내 문구가 위치를 말로
//  알려 줘야 한다는 것 자체가 자리가 틀렸다는 뜻이다. 자리를 옮기는 대신
//  **필요한 순간 세 개**에 각각 내놓는다.
//
//  | 순간 | 무엇을 보고 아는가 |
//  | --- | --- |
//  | 여러 줄을 붙여넣는 중 | 붙여넣은 글의 줄 수 (제일 진하다. 이미 그 일을 하는 중이다) |
//  | 아직 몇 개 없는 사람 | 단축어 개수 |
//  | 손으로 줄줄이 만드는 중 | 짧은 사이에 이어서 만든 횟수 |
//
//  ⚠️ 셋 중 첫 번째가 압도적으로 진하다. 나머지 둘은 **추측**이라 문턱을 높이고,
//     한 번 물리면 다시 묻지 않는다.
//
//  ⚠️ 여기서는 **판정만** 한다. 화면을 열지도, 사용자의 글을 건드리지도 않는다.
//

import Foundation

enum BulkImportNudge {

    // MARK: - 정책

    /// 붙여넣은 글이 몇 줄부터 "나눠 담을 거리"인가.
    /// 두 줄은 그냥 두 줄짜리 글일 수 있다. 셋부터 목록으로 본다.
    static let minLinesToSplit = 3

    /// 손으로 몇 개를 잇달아 만들면 말을 거는가.
    static let manualStreakThreshold = 3

    /// 잇달아 만든 것으로 치는 사이 간격(초). 이보다 뜸하면 줄줄이 만드는 중이 아니다.
    static let manualStreakWindow: TimeInterval = 10 * 60

    /// 아직 이만큼 이하면 "처음 온 사람"으로 본다.
    static let newcomerMaxCount = 2

    // MARK: - 순수 계산 (여기만 시험한다)

    /// 붙여넣은 글이 목록처럼 생겼는가. 그렇다면 몇 개짜리인지.
    ///
    /// 빈 줄은 세지 않는다. 사람이 옮겨 적은 목록은 줄 사이가 비어 있기 일쑤라
    /// 빈 줄까지 세면 "12개네요"가 실제와 안 맞는다.
    ///
    /// ⚠️ 한 줄이 너무 길면 목록이 아니라 문단이다. 문단을 줄 단위로 쪼개 주겠다고
    ///    나서면 도움이 아니라 방해다.
    static func splittableLineCount(in text: String) -> Int? {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count >= minLinesToSplit else { return nil }
        // 줄 하나가 200자를 넘으면 목록이 아니라 글이다.
        guard lines.allSatisfy({ $0.count <= 200 }) else { return nil }
        return lines.count
    }

    /// 잇달아 만든 것으로 칠 수 있는가.
    /// - Parameters:
    ///   - lastAt: 직전에 만든 시각(없으면 처음).
    ///   - now: 지금.
    static func continuesStreak(lastAt: Date?, now: Date) -> Bool {
        guard let lastAt else { return false }
        let gap = now.timeIntervalSince(lastAt)
        return gap >= 0 && gap <= manualStreakWindow
    }

    /// 아직 몇 개 없는 사람인가.
    static func isNewcomer(memoCount: Int) -> Bool {
        memoCount <= newcomerMaxCount
    }

    // MARK: - 저장소

    private static var defaults: UserDefaults? { AppGroup.defaults }

    /// 사용자가 물렸다. 다시 내놓지 않는다.
    ///
    /// ⚠️ 붙여넣기 순간의 제안은 이 값을 보지 **않는다.** 그건 추측이 아니라
    ///    눈앞의 사실이라, 지난번에 안 썼다고 이번에도 안 쓸 이유가 없다.
    static var isDismissed: Bool {
        get { defaults?.bool(forKey: DefaultsKey.bulkImportNudgeDismissed) ?? false }
        set { defaults?.set(newValue, forKey: DefaultsKey.bulkImportNudgeDismissed) }
    }

    private static var lastManualCreateAt: Date? {
        get {
            let t = defaults?.double(forKey: DefaultsKey.bulkImportLastManualCreateAt) ?? 0
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set { defaults?.set(newValue?.timeIntervalSince1970 ?? 0,
                            forKey: DefaultsKey.bulkImportLastManualCreateAt) }
    }

    private static var manualStreak: Int {
        get { defaults?.integer(forKey: DefaultsKey.bulkImportManualStreak) ?? 0 }
        set { defaults?.set(newValue, forKey: DefaultsKey.bulkImportManualStreak) }
    }

    // MARK: - 쓰는 쪽

    /// 손으로 단축어 하나를 만들었다. 줄줄이 만드는 중인지 센다.
    ///
    /// ⚠️ 대량 가져오기로 만든 것은 여기 세지 않는다. 이미 쓰고 있는 사람에게
    ///    그 기능을 권하는 꼴이 된다.
    static func recordManualCreate(now: Date = Date()) {
        manualStreak = continuesStreak(lastAt: lastManualCreateAt, now: now) ? manualStreak + 1 : 1
        lastManualCreateAt = now
    }

    /// 목록에 한 줄 내놓을 때인가.
    /// 줄줄이 만드는 중이거나, 아직 몇 개 없는 사람이거나.
    static func shouldOfferInList(memoCount: Int, now: Date = Date()) -> Bool {
        guard !isDismissed else { return false }
        if isNewcomer(memoCount: memoCount) { return true }
        guard manualStreak >= manualStreakThreshold else { return false }
        // 한참 전에 세어 둔 것으로 지금 말을 걸지 않는다.
        return continuesStreak(lastAt: lastManualCreateAt, now: now)
    }

    /// 세어 둔 것을 지운다(제안을 내놓았거나 사용자가 썼을 때).
    static func resetStreak() {
        manualStreak = 0
        lastManualCreateAt = nil
    }
}
