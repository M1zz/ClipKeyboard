//
//  UserStateStore.swift
//  ClipKeyboard
//
//  `UserState` 에 넣을 값을 기기에서 긁어 오고, 내려가지 않는 바닥을 들고 있는 곳.
//
//  ⚠️ 판정 규칙은 여기 없다. 전부 `UserState` 에 있고 순수하다. 이 파일이 하는 일은
//     읽기·쓰기와 화면에 알리기뿐이다.
//
//  자세한 설계: docs/product/USER_STATE_MODEL.md
//

import Foundation
import SwiftUI

@MainActor
final class UserStateStore: ObservableObject {

    static let shared = UserStateStore()

    /// 지금 이 사람의 상태. 화면은 이 값만 보면 된다.
    @Published private(set) var state: UserState = UserState.resolve(facts: UserStateFacts())

    /// 마지막으로 잰 값. 판정 결과(`state`)만으로는 모자란 화면이 쓴다(친구에게 알리기의 사용 횟수 같은).
    /// ⚠️ 화면을 다시 그릴 이유가 아니라서 `@Published` 가 아니다.
    private(set) var lastFacts = UserStateFacts()

    private var defaults: UserDefaults? { AppGroup.defaults }

    private init() {
        refresh()
    }

    // MARK: - 다시 재기

    /// 값이 달라졌을 만한 자리에서 부른다(앱이 앞으로 올 때 · 단축어를 쓴 뒤 · 목록이 바뀐 뒤).
    ///
    /// ⚠️ 매 프레임 부르지 말 것. `memos.data` 를 통째로 읽는다.
    func refresh(now: Date = Date()) {
        // 개발자가 단계를 흉내 내는 중이면 기기의 진짜 값을 보지 않는다.
        // ⚠️ 바닥도 휴면 기록도 건드리지 않는다 - 흉내가 진짜 기록을 물들이면
        //    시뮬레이터를 끈 뒤에도 그 사람의 상태가 돌아오지 않는다.
        if let stage = UserStageSimulator.activeStage {
            let simulated = stage.state(now: now)
            if simulated != state {
                state = simulated
                print("🎭 [UserState] '\(stage.rawValue)' 단계를 흉내 내는 중")
            }
            return
        }

        let loaded = try? MemoStore.shared.load(type: .memo)
        let memos = loaded ?? []
        let sampleIds = SampleMemoStorage.load()
        let facts = Self.currentFacts(now: now, memos: memos, sampleIds: sampleIds)
        lastFacts = facts
        seedFloorIfNeeded(facts: facts)

        // ⚠️ 목록을 **못 읽었을 때는** 아래 둘을 하지 않는다. 빈 목록으로 알아보면 쓰임새가
        //    일반으로 내려앉고, 빈 목록으로 걷어 내면 사용 시각이 통째로 지워진다.
        if let loaded {
            // 같은 목록을 읽은 김에 쓰임새도 다시 본다. 묻지 않고 저장한 것으로 알아본다.
            PersonaResolver.refresh(memos: loaded, sampleIDs: sampleIds)
            // 판이 바뀌었으면 키보드 붙박이도 그 판의 것으로.
            PersonaEditionStore.refresh(memos: loaded, sampleIDs: sampleIds)
            // 지워진 단축어의 사용 시각은 걷어 낸다.
            UsageRhythmLog.prune(keeping: Set(loaded.map(\.id)))
        }

        let resolved = UserState.resolve(facts: facts, floor: storedFloor, now: now)
        raiseFloor(to: resolved.level)
        noteDormancy(of: resolved, now: now)

        if resolved != state {
            state = resolved
            print("🧭 [UserState] \(resolved.tenure.rawValue)·\(resolved.level.rawValue) 결=\(resolved.grain) 활동=\(resolved.activity) 칸=\(resolved.cell)")
        }
    }

    // MARK: - 기기에서 값 긁기

    /// 지금 이 기기의 값들. 전부 이미 쌓여 있던 것이라 새로 수집하는 것은 없다.
    static func currentFacts(now: Date = Date()) -> UserStateFacts {
        currentFacts(now: now,
                     memos: (try? MemoStore.shared.load(type: .memo)) ?? [],
                     sampleIds: SampleMemoStorage.load())
    }

    /// 이미 읽어 둔 목록으로 값을 모은다. `refresh` 가 목록을 한 번만 읽으려고 쓴다.
    static func currentFacts(now: Date, memos: [Memo], sampleIds: Set<UUID>) -> UserStateFacts {
        // 앱이 심어 준 샘플은 자기 것이 아니다. 이걸 세면 아무것도 안 만든 사람이
        // 만든 사람으로 올라가고, 첫 단축어에서 막힌 사람이 지도에서 사라진다.
        let own = memos.filter { !sampleIds.contains($0.id) }

        // 종류는 겹치지 않게 센다(콤보가 템플릿이기도 한 경우가 있다).
        var combos = 0, templates = 0
        for memo in own {
            if !memo.childMemoIds.isEmpty { combos += 1 }
            else if memo.isTemplate { templates += 1 }
        }

        let group = AppGroup.defaults
        let installedAt = UserDefaults.standard.object(forKey: DefaultsKey.appInstallDate) as? Date
        let keyboardLoaded = group?.bool(forKey: DefaultsKey.keyboardExtensionDidLoad) ?? false
        let beaconLastUse = group?.double(forKey: DefaultsKey.kbBeaconLastUse) ?? 0
        let returnedEpoch = group?.double(forKey: DefaultsKey.userStateReturnedAt) ?? 0

        return UserStateFacts(
            installedAt: installedAt,
            ownShortcuts: own.count,
            uses: own.reduce(0) { $0 + $1.clipCount },
            keyboardPastes: group?.integer(forKey: DefaultsKey.keyboardPasteCount) ?? 0,
            activeDays: ActiveDayLedger.dayCount(),
            lastUsedAt: own.compactMap(\.lastUsedAt).max(),
            returnedAt: returnedEpoch > 0 ? Date(timeIntervalSince1970: returnedEpoch) : nil,
            keyboardInstalled: keyboardLoaded || beaconLastUse > 0,
            templates: templates,
            combos: combos,
            unusedShortcuts: own.filter { $0.clipCount == 0 }.count
        )
    }

    // MARK: - 바닥 (레벨은 내려가지 않는다)

    private var storedFloor: UserLevel {
        let raw = defaults?.integer(forKey: DefaultsKey.userStateLevelFloor) ?? 0
        return UserLevel(rawValue: raw) ?? .browsing
    }

    private func raiseFloor(to level: UserLevel) {
        guard level > storedFloor else { return }
        defaults?.set(level.rawValue, forKey: DefaultsKey.userStateLevelFloor)
    }

    /// 예전부터 쓰던 사람의 바닥을 한 번 깔아 준다.
    ///
    /// 활동일 원장은 이 기능과 함께 생겨서, 업데이트로 올라온 기기는 처음에 늘 0이다.
    /// 그 값을 그대로 믿으면 반년 쓴 사람이 "이제 막 써 보는 사람" 으로 떨어지고,
    /// 초심자 안내가 다시 얼굴을 내민다. 그래서 **활동일 조건만 뺀** 계산을 한 번 해서
    /// 바닥으로 깔고, 그 뒤로는 원장이 스스로 쌓인다.
    private func seedFloorIfNeeded(facts: UserStateFacts) {
        guard defaults?.bool(forKey: DefaultsKey.userStateFloorSeeded) != true else { return }
        defaults?.set(true, forKey: DefaultsKey.userStateFloorSeeded)

        var seeded = facts
        seeded.activeDays = max(facts.activeDays, UserState.Threshold.fluentDays)
        raiseFloor(to: UserState.rawLevel(seeded))
    }

    // MARK: - 휴면과 복귀

    /// 휴면에서 깬 순간을 잡아 둔다. 그 뒤 7일이 "돌아온 사람" 이다.
    ///
    /// ⚠️ 판정이 아니라 **기록**이다. 깼는지 아닌지는 `UserState.activity` 가 정한다.
    private func noteDormancy(of resolved: UserState, now: Date) {
        guard let defaults else { return }
        let wasDormant = defaults.bool(forKey: DefaultsKey.userStateWasDormant)

        switch resolved.activity {
        case .dormant:
            if !wasDormant { defaults.set(true, forKey: DefaultsKey.userStateWasDormant) }
        case .active, .returning:
            guard wasDormant else { return }
            defaults.set(false, forKey: DefaultsKey.userStateWasDormant)
            defaults.set(now.timeIntervalSince1970, forKey: DefaultsKey.userStateReturnedAt)
        }
    }

    // MARK: - 화면이 묻는 것

    func visibility(of surface: UserSurface) -> SurfaceVisibility {
        state.visibility(of: surface)
    }

    func isVisible(_ surface: UserSurface) -> Bool {
        state.visibility(of: surface).isVisible
    }

    /// 지금 화면에서 앞에 세울 안내 하나. 없으면 nil.
    var leadingSurface: UserSurface? { state.leadingSurface }
}

// MARK: - 화면에서 쓰기

extension View {

    /// 이 상태에서 낼 자리가 아니면 통째로 빼고, 조용히 낼 자리면 흐리게 둔다.
    ///
    /// ```swift
    /// KeyboardSetupBanner()
    ///     .userSurface(.keyboardSetupBanner)
    /// ```
    ///
    /// ⚠️ 설정 화면처럼 **사람이 찾아간 자리** 에는 쓰지 말 것. 감춘다는 것은 없앤다는
    ///    뜻이 아니라 앞에 안 낸다는 뜻이고, 찾아간 사람에게까지 없으면 그건 고장이다.
    ///
    /// ⚠️ 기본 인자로 `.shared` 를 받지 않는다. 기본 인자는 메인 액터 밖에서 값이 매겨져서
    ///    Swift 6 에서는 오류가 된다. 몸통 안에서 집어 오면 그 자리는 이미 메인 액터다.
    @MainActor
    func userSurface(_ surface: UserSurface) -> some View {
        modifier(UserSurfaceGate(surface: surface, store: .shared))
    }
}

private struct UserSurfaceGate: ViewModifier {
    let surface: UserSurface
    @ObservedObject var store: UserStateStore

    func body(content: Content) -> some View {
        switch store.visibility(of: surface) {
        case .lead:
            content
        case .quiet:
            // 있지만 주인공은 아니다. 자리는 지키되 눈을 먼저 끌지 않는다.
            content.opacity(0.72)
        case .hidden:
            EmptyView()
        }
    }
}
