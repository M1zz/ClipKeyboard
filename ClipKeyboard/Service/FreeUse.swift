//
//  FreeUse.swift
//  ClipKeyboard / ClipKeyboardExtension
//
//  **쓴 만큼 확신이 쌓이면 그때 묻는다.** 단축어를 N번(기본 100) 넣을 때까지는 전부 무료다.
//
//  왜 이렇게 하나: 예전에는 "10개까지 무료"였다. 그 벽은 가치를 받기 **전에** 선다.
//  10개를 만든 사람이 그걸 실제로 쓰는지는 모른다. 반대로 100번 넣은 사람은 이 앱이 이미
//  생활에 들어와 있다. 결제할까 망설이는 사람에게 필요한 것은 그 증거이고, 그 증거가
//  쌓인 뒤에 묻는다. (결정: 2026-09-30, 시안 docs/product/FREE_USE_MODEL.md)
//
//  문턱을 넘은 뒤 결제하지 않으면:
//   - **이미 만든 것은 전부 그대로 쓴다.** 어제까지 되던 키가 남의 앱에서 글을 쓰다가 안 눌리면
//     그건 결제 안내가 아니라 고장으로 읽힌다.
//   - 새로 만드는 것에만 예전 무료 한도(단축어 10 · 템플릿 3 · 스택 3 · 이미지 5)가 선다.
//     예전에 무료였던 것은 앞으로도 무료다.
//
//  ⚠️ 세는 곳은 `MemoStore.incrementClipCount` 한 곳이다. 키보드 · 앱 · 템플릿 · 스택 · 보안
//     인증 뒤, 어느 길로 넣어도 그 함수를 지난다. 다른 곳에서 세면 두 번 센다.
//  ⚠️ 단축어별 `clipCount` 의 합을 쓰지 않는다. 단축어를 지우면 그 횟수가 사라져서,
//     지웠다 만들기를 반복하면 영영 문턱에 닿지 않는다. 여기 값은 줄지 않는다.
//

import Foundation

enum FreeUse {

    // MARK: - 문턱

    /// 기본 문턱. 원격 값(`RemoteFlagsService.Number.freeUseThreshold`)이 있으면 그 값을 쓴다.
    /// 앱을 새로 내지 않고 문턱을 옮기려고 원격에 둔다. 몇이 맞는지는 데이터로 정한다
    /// (`scripts/analyze_use_threshold.py`).
    static let defaultThreshold = 100

    /// 원격 값으로 받아 줄 범위. 잘못 넣은 값(0 이나 10만)이 모두를 막거나 영영 열지 않게.
    static let allowedThresholds = 20...1000

    /// 지금의 문턱. 앱과 키보드가 같은 값을 봐야 해서 App Group 에서 읽는다.
    static var threshold: Int {
        // 키보드에는 RemoteFlagsService 가 없다. 그 서비스가 App Group 에 적어 둔 값을 읽는다.
        let raw = defaults?.object(forKey: DefaultsKey.remoteFreeUseThreshold) as? Int
        return resolvedThreshold(remote: raw)
    }

    static func resolvedThreshold(remote: Int?) -> Int {
        guard let remote, allowedThresholds.contains(remote) else { return defaultThreshold }
        return remote
    }

    // MARK: - 센 값

    private static var defaults: UserDefaults? { AppGroup.defaults }

    /// 지금까지 넣은 횟수. 줄지 않는다.
    static var uses: Int {
        defaults?.integer(forKey: DefaultsKey.freeUseCount) ?? 0
    }

    /// 처음 넣은 날. 결제 화면의 "지난 N일 동안" 이 여기서 나온다.
    static var firstUseAt: Date? {
        let value = defaults?.double(forKey: DefaultsKey.freeUseFirstAt) ?? 0
        return value > 0 ? Date(timeIntervalSince1970: value) : nil
    }

    /// 한 번 넣었다. `MemoStore.incrementClipCount` 만 부른다.
    static func recordUse(now: Date = Date()) {
        guard let defaults else { return }
        defaults.set(defaults.integer(forKey: DefaultsKey.freeUseCount) + 1, forKey: DefaultsKey.freeUseCount)
        if defaults.double(forKey: DefaultsKey.freeUseFirstAt) <= 0 {
            defaults.set(now.timeIntervalSince1970, forKey: DefaultsKey.freeUseFirstAt)
        }
    }

    // MARK: - 지금 어디쯤인가

    /// 무료 기간인가. 이 동안은 Pro 와 같다(`ProFeatureManager.hasFullAccess`).
    static var isActive: Bool { isActive(uses: uses, threshold: threshold) }

    static func isActive(uses: Int, threshold: Int) -> Bool { uses < threshold }

    /// 문턱까지 남은 횟수.
    static var remaining: Int { max(0, threshold - uses) }

    /// 처음 넣은 날부터 며칠이 지났나(적어도 1).
    static func daysSinceFirstUse(now: Date = Date()) -> Int {
        guard let first = firstUseAt else { return 1 }
        return max(1, Int(now.timeIntervalSince(first) / 86_400) + 1)
    }

    // MARK: - 이정표

    /// 알려 주는 순간 셋. 계속 알리지 않는다. 계속 뜨는 안내는 곧 배경 소음이 되고,
    /// 앱 전체를 광고처럼 느끼게 한다.
    enum Milestone: Int, CaseIterable, Comparable {
        /// 절반. 받은 것을 처음 보여 준다.
        case half = 50
        /// 80%. 문턱 뒤에 **무엇이 그대로인지**를 먼저 말한다.
        case nearEnd = 80
        /// 문턱. 영수증과 요금제.
        case reached = 100

        static func < (lhs: Milestone, rhs: Milestone) -> Bool { lhs.rawValue < rhs.rawValue }

        /// 이 이정표가 서는 횟수.
        func uses(threshold: Int) -> Int {
            self == .reached ? threshold : threshold * rawValue / 100
        }
    }

    /// 지금 닿아 있는 가장 높은 이정표.
    static func reachedMilestone(uses: Int, threshold: Int) -> Milestone? {
        Milestone.allCases.reversed().first { uses >= $0.uses(threshold: threshold) }
    }

    /// 아직 안 보여 준 이정표 중 보여 줄 것. **지나간 낮은 것은 건너뛴다**
    /// (앱을 오래 안 열다가 90번째에 열었으면 50번 카드는 뜻이 없다).
    static func pendingMilestone(uses: Int, threshold: Int, seen: Set<Milestone>,
                                 hasPaid: Bool) -> Milestone? {
        guard !hasPaid, let top = reachedMilestone(uses: uses, threshold: threshold),
              !seen.contains(top) else { return nil }
        return top
    }

    static var seenMilestones: Set<Milestone> {
        let raw = defaults?.array(forKey: DefaultsKey.freeUseMilestonesSeen) as? [Int] ?? []
        return Set(raw.compactMap(Milestone.init(rawValue:)))
    }

    static func markSeen(_ milestone: Milestone) {
        var raw = defaults?.array(forKey: DefaultsKey.freeUseMilestonesSeen) as? [Int] ?? []
        guard !raw.contains(milestone.rawValue) else { return }
        raw.append(milestone.rawValue)
        defaults?.set(raw, forKey: DefaultsKey.freeUseMilestonesSeen)
    }

    /// 지금 보여 줄 이정표. 이미 돈을 낸 사람(평생 · 구독 · 예전 구매)에게는 없다.
    static var pendingMilestone: Milestone? {
        pendingMilestone(uses: uses, threshold: threshold, seen: seenMilestones,
                         hasPaid: ProFeatureManager.hasPermanentPro)
    }
}
