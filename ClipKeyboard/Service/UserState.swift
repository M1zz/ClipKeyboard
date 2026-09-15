//
//  UserState.swift
//  ClipKeyboard
//
//  "이 사람은 지금 어디쯤인가" - 화면과 기능을 사람에 맞춰 내주기 위한 상태 판정.
//
//  ⚠️ **순수하다.** MemoStore·UserDefaults·화면을 모르고, 값을 받아 값을 돌려줄 뿐이다.
//     기기에서 값을 긁어오는 일은 `UserStateStore` 가 한다. 그래야 테스트가 날짜와
//     숫자를 직접 만들어 25칸을 다 돌려볼 수 있다.
//
//  ⚠️ **새로 수집하는 것이 없다.** 판정에 쓰는 값은 전부 이미 기기에 쌓여 있다
//     (`app_install_date` · `Memo.clipCount` · `kb.beacon.totalCount` 등).
//     기기 밖으로 나가지 않는다.
//
//  자세한 설계: docs/product/USER_STATE_MODEL.md
//

import Foundation

// MARK: - 기간 (머문 시간)

/// 설치한 날부터 흐른 날수. 저절로 오르고 내려가지 않는다.
///
/// ⚠️ 숙련도와 **따로** 센다. 하나를 다른 하나로 대신 쓰면 한 달 된 사람에게 첫날
///    안내를 띄우거나 첫날 사람에게 콤보를 들이밀게 된다.
enum UserTenure: Int, CaseIterable, Comparable {
    /// 0 ~ 1일. 아직 이 앱이 무엇인지 모른다.
    case day0 = 0
    /// 2 ~ 7일. 쓸지 말지 정하는 기간.
    case week1
    /// 8 ~ 30일. 습관이 붙거나 잊히거나.
    case month1
    /// 31 ~ 90일. 남아 있다면 이미 쓸모를 봤다.
    case settled
    /// 91일 이상.
    case long

    static func < (lhs: UserTenure, rhs: UserTenure) -> Bool { lhs.rawValue < rhs.rawValue }

    /// 설치일에서 판정. 설치일을 모르면(예전 버전에서 올라온 기기) 가장 보수적인 `.long`.
    ///
    /// ⚠️ 모를 때 `.day0` 로 떨어뜨리면 몇 년 쓴 사람이 업데이트 한 번에 첫날 안내를 본다.
    static func at(installedAt: Date?, now: Date = Date()) -> UserTenure {
        guard let installedAt, installedAt <= now else { return .long }
        let days = Int(now.timeIntervalSince(installedAt) / 86_400)
        switch days {
        case ..<2:   return .day0
        case ..<8:   return .week1
        case ..<31:  return .month1
        case ..<91:  return .settled
        default:     return .long
        }
    }

    var localizedName: String {
        switch self {
        case .day0:    return NSLocalizedString("첫날", comment: "User tenure: first day")
        case .week1:   return NSLocalizedString("첫 주", comment: "User tenure: first week")
        case .month1:  return NSLocalizedString("첫 달", comment: "User tenure: first month")
        case .settled: return NSLocalizedString("정착", comment: "User tenure: settled")
        case .long:    return NSLocalizedString("오랜", comment: "User tenure: long time user")
        }
    }
}

// MARK: - 숙련도 (손에 익은 정도)

/// 쓴 만큼만 오르는 칸. 위에서부터 걸리는 첫 칸이 그 사람의 칸이다.
///
/// ⚠️ **내려가지 않는다.** 한 달 쉬었다고 능숙이 꺼냄으로 떨어지면, 돌아온 사람이
///    자기가 다 아는 안내를 처음부터 다시 본다. 쉰 것은 `UserActivity.dormant` 로
///    따로 표시하고 칸은 그대로 둔다(`UserState.resolve` 의 floor).
enum UserLevel: Int, CaseIterable, Comparable {
    /// 자기 단축어가 아직 없다.
    case browsing = 0
    /// 만들었는데 한 번도 꺼내 쓰지 않았다.
    case made
    /// 처음으로 실제 입력에 썼다. 키보드가 켜지는 자리.
    case used
    /// 키보드에서 꺼내 쓰고, 여러 날에 걸쳐 쓴다.
    case fluent
    /// 두 번째 도구(빈칸·콤보)까지 쓴다.
    case expert

    static func < (lhs: UserLevel, rhs: UserLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var localizedName: String {
        switch self {
        case .browsing: return NSLocalizedString("구경", comment: "User level: browsing")
        case .made:     return NSLocalizedString("만듦", comment: "User level: created but unused")
        case .used:     return NSLocalizedString("꺼냄", comment: "User level: first real use")
        case .fluent:   return NSLocalizedString("익음", comment: "User level: habitual")
        case .expert:   return NSLocalizedString("능숙", comment: "User level: expert")
        }
    }
}

// MARK: - 결 (레벨로는 안 갈리는 모습)

/// 같은 레벨이라도 쓰는 모습이 반대인 사람이 있다. 레벨을 올리거나 내리지 않고
/// 화면을 어느 쪽으로 기울일지만 정한다.
enum UserGrain {
    /// 아무 쪽도 아니다.
    case even
    /// 적게 만들고 그것만 계속 쓴다. 나쁜 상태가 아니다.
    case oneTrick
    /// 잔뜩 만들어 놓고 대부분 안 쓴다. 칸이 모자란 게 아니라 못 찾는 것이다.
    case hoarder

    var localizedName: String {
        switch self {
        case .even:     return NSLocalizedString("고름", comment: "User grain: even")
        case .oneTrick: return NSLocalizedString("하나만 쓰는", comment: "User grain: one trick")
        case .hoarder:  return NSLocalizedString("쌓아 두는", comment: "User grain: hoarder")
        }
    }
}

// MARK: - 활동 (지금 곁에 있는가)

/// 레벨을 덮어쓰지 않고 **위에 얹는** 층. 말을 걸지 말지를 정한다.
enum UserActivity {
    case active
    /// 마지막으로 쓴 지 오래됐다. 새 기능 안내·리뷰 요청·제안을 전부 끈다.
    case dormant
    /// 휴면에서 깼다. 끊긴 자리를 이어 주되 튜토리얼을 다시 틀지 않는다.
    case returning
}

// MARK: - 판정에 넣는 값

/// 기기에 이미 쌓여 있는 값들. 이것들이면 25칸이 다 갈린다.
///
/// ⚠️ `uses` 하나로 앱과 키보드를 다 센다. 키보드도 `MemoStore.incrementClipCount` 를
///    지나기 때문이다(`KeyboardViewController.trackKeyboardPaste`). 비콘 카운터
///    (`kbBeaconTotalCount`)를 여기에 더하면 안 된다. 그쪽은 **키보드가 뜬 횟수**라,
///    단축어를 한 번도 안 넣은 사람이 "썼다"로 올라간다. 만들고 멈춘 사람을 잡아내는
///    것이 이 모델의 핵심인데 그 칸이 통째로 비게 된다.
struct UserStateFacts: Equatable {
    /// `DefaultsKey.appInstallDate`. 없으면 예전 버전에서 올라온 기기다.
    var installedAt: Date?
    /// 샘플을 **뺀** 자기 단축어 수.
    var ownShortcuts: Int
    /// 단축어를 실제로 쓴 횟수(`Memo.clipCount` 합). 앱과 키보드 양쪽이 들어 있다.
    var uses: Int
    /// 키보드에서 넣은 횟수(`DefaultsKey.keyboardPasteCount`).
    /// "만들기는 앱에서, 쓰기는 키보드에서" 까지 갔는지를 본다.
    var keyboardPastes: Int
    /// 단축어를 실제로 쓴 **날**의 수(`ActiveDayLedger`).
    var activeDays: Int
    /// 마지막으로 단축어를 쓴 때(`Memo.lastUsedAt` 중 가장 최근). 없으면 쓴 적이 없다.
    var lastUsedAt: Date?
    /// 휴면에서 깬 때. 없으면 깬 적이 없거나 이미 오래됐다.
    var returnedAt: Date?
    /// 키보드 익스텐션이 한 번이라도 떴는가.
    var keyboardInstalled: Bool
    /// 빈칸(템플릿) 단축어 수.
    var templates: Int
    /// 콤보 수.
    var combos: Int
    /// 한 번도 안 쓴 단축어 수.
    var unusedShortcuts: Int

    init(installedAt: Date? = nil,
         ownShortcuts: Int = 0,
         uses: Int = 0,
         keyboardPastes: Int = 0,
         activeDays: Int = 0,
         lastUsedAt: Date? = nil,
         returnedAt: Date? = nil,
         keyboardInstalled: Bool = false,
         templates: Int = 0,
         combos: Int = 0,
         unusedShortcuts: Int = 0) {
        self.installedAt = installedAt
        self.ownShortcuts = ownShortcuts
        self.uses = uses
        self.keyboardPastes = keyboardPastes
        self.activeDays = activeDays
        self.lastUsedAt = lastUsedAt
        self.returnedAt = returnedAt
        self.keyboardInstalled = keyboardInstalled
        self.templates = templates
        self.combos = combos
        self.unusedShortcuts = unusedShortcuts
    }
}

// MARK: - 상태

struct UserState: Equatable {
    let tenure: UserTenure
    let level: UserLevel
    let grain: UserGrain
    let activity: UserActivity
    /// 기간과 숙련도가 만나는 칸의 진단.
    let cell: Cell

    /// 지도 한 칸의 성격. 무엇을 손봐야 하는지가 여기서 나온다.
    enum Cell {
        /// 정상 궤도. 손댈 것이 없다.
        case onTrack
        /// 지켜볼 것. 아직 막힌 건 아니다.
        case watch
        /// 막혔다. 이 칸이 이 앱이 사람을 놓친 자리다.
        case stuck
        /// 유령. 지우지만 않은 상태다. 말을 걸지 않는다.
        case ghost
    }

    // MARK: 문턱
    //
    // 눈대중이 아니라 이 앱의 구조에서 온 값이다.
    //  · 무료 한도가 10이라 8개 이상이면 "많이 만든" 쪽이다(ProFeatureManager.freeMemoLimit).
    //  · 50회는 하루 두 번씩 한 달쯤 쓴 양이다.
    // ⚠️ 한도를 바꾸면 `hoarderShortcuts` 도 같이 움직여야 한다.

    enum Threshold {
        /// 익음에 드는 최소 사용 횟수.
        static let fluentUses = 10
        /// 익음에 드는 최소 활동일.
        static let fluentDays = 3
        /// 능숙에 드는 최소 사용 횟수.
        static let expertUses = 50
        /// 하나만 쓰는 사람의 단축어 상한.
        static let oneTrickShortcuts = 3
        /// 하나만 쓰는 사람의 최소 사용 횟수.
        static let oneTrickUses = 10
        /// 쌓아 두는 사람의 단축어 하한.
        static let hoarderShortcuts = 8
        /// 쌓아 두는 사람의 안 쓴 것 비율.
        static let hoarderUnusedRatio = 0.7
        /// 이만큼 안 쓰면 휴면.
        static let dormantDays = 14
        /// 휴면에서 깬 뒤 이 기간 동안은 "돌아온 사람".
        static let returningDays = 7
    }

    // MARK: 판정

    /// 값에서 상태를 뽑는다.
    ///
    /// - Parameter floor: 지금까지 **가장 높이 올라갔던** 레벨. 여기서 내려가지 않는다.
    ///   `UserStateStore` 가 들고 있다가 넣어 준다.
    static func resolve(facts: UserStateFacts,
                        floor: UserLevel = .browsing,
                        now: Date = Date()) -> UserState {
        let level = max(rawLevel(facts), floor)
        let tenure = UserTenure.at(installedAt: facts.installedAt, now: now)
        return UserState(tenure: tenure,
                         level: level,
                         grain: grain(facts),
                         activity: activity(facts, now: now),
                         cell: cell(tenure: tenure, level: level))
    }

    /// floor 를 씌우기 전의 날것 레벨. **위에서부터 걸리는 첫 칸** 하나다.
    static func rawLevel(_ f: UserStateFacts) -> UserLevel {
        if f.ownShortcuts < 1 { return .browsing }
        if f.uses < 1 { return .made }
        if f.uses >= Threshold.expertUses, (f.templates + f.combos) >= 1 { return .expert }
        if f.uses >= Threshold.fluentUses,
           f.keyboardPastes >= 1,
           f.activeDays >= Threshold.fluentDays { return .fluent }
        return .used
    }

    /// 결. 레벨과 **무관하게** 따로 본다.
    static func grain(_ f: UserStateFacts) -> UserGrain {
        if f.ownShortcuts <= Threshold.oneTrickShortcuts,
           f.uses >= Threshold.oneTrickUses { return .oneTrick }
        if f.ownShortcuts >= Threshold.hoarderShortcuts,
           Double(f.unusedShortcuts) / Double(f.ownShortcuts) >= Threshold.hoarderUnusedRatio { return .hoarder }
        return .even
    }

    /// 활동. 쓴 적이 없는 사람은 휴면이 아니다 - 아직 시작을 안 한 것뿐이다.
    static func activity(_ f: UserStateFacts, now: Date = Date()) -> UserActivity {
        guard let lastUsedAt = f.lastUsedAt else { return .active }
        if now.timeIntervalSince(lastUsedAt) >= Double(Threshold.dormantDays) * 86_400 { return .dormant }
        if let returnedAt = f.returnedAt,
           now.timeIntervalSince(returnedAt) < Double(Threshold.returningDays) * 86_400 { return .returning }
        return .active
    }

    /// 지도 25칸. 시간은 갔는데 숙련도가 안 오른 칸이 나쁘다.
    static func cell(tenure: UserTenure, level: UserLevel) -> Cell {
        switch level {
        case .expert, .fluent:
            return .onTrack
        case .used:
            return tenure >= .settled ? .watch : .onTrack
        case .made:
            switch tenure {
            case .day0:           return .onTrack
            case .week1:          return .watch
            case .month1, .settled: return .stuck
            case .long:           return .ghost
            }
        case .browsing:
            switch tenure {
            case .day0:            return .onTrack
            case .week1:           return .watch
            case .month1:          return .stuck
            case .settled, .long:  return .ghost
            }
        }
    }
}

// MARK: - 기능 노출

/// 상태에 따라 앞에 낼지 말지가 갈리는 자리들.
///
/// ⚠️ 여기 없는 기능은 **상태와 무관하게 늘 있는 것**이다. 목록·설정처럼 앱의 뼈대는
///    판정이 건드리지 않는다.
enum UserSurface: String, CaseIterable {
    case tutorialStage          // 무대 튜토리얼
    case createShortcut         // 단축어 만들기
    case keyboardSetupBanner    // 키보드 켜기 띠
    case clipboardCapture       // 클립보드에서 바로 만들기
    case favorites              // 즐겨찾기
    case template               // 빈칸(템플릿)
    case searchAndReorder       // 검색·순서 바꾸기
    case categories             // 카테고리
    case combo                  // 콤보
    case backupSync             // 백업·동기화
    case statsPassport          // 통계·여권
    case decoration             // 꾸미기(키컬러·배경·생활 레이어)
    case keyboardLayout         // 키보드 판 높이·레이아웃
    case widgets                // 위젯·제어센터
    case macApp                 // 맥 앱 안내
    case slotLimit              // 한도 안내·칸 추가
    case reviewRequest          // 리뷰 요청
    case bulkImport             // 한 번에 정리하기
    case exampleMart            // 예시에서 골라 담기

    /// 사람에게 **말을 거는** 자리인가. 휴면인 사람에게는 이것들이 전부 꺼진다.
    ///
    /// ⚠️ 기능 자체가 아니라 "먼저 말을 거는 것"만 해당한다. 백업이나 검색은 사람이
    ///    찾아가는 것이라 휴면이어도 그대로 둔다.
    var isPrompt: Bool {
        switch self {
        case .tutorialStage, .keyboardSetupBanner, .slotLimit, .reviewRequest, .bulkImport, .macApp:
            return true
        default:
            return false
        }
    }
}

/// 그 자리를 얼마나 앞에 두는가.
enum SurfaceVisibility {
    /// 앞에 내놓는다. 그 화면의 주인공이 될 수 있다.
    case lead
    /// 있지만 조용히. 설정 안이나 목록 아래.
    case quiet
    /// 이 상태에서는 화면에 없다.
    ///
    /// ⚠️ **없앤다는 뜻이 아니다.** 설정을 뒤지면 늘 거기 있어야 한다. 쓰던 기능이
    ///    업데이트 뒤 사라져 보이면 그것은 개인화가 아니라 고장이다.
    case hidden

    var isVisible: Bool { self != .hidden }
}

extension UserState {

    /// 이 상태에서 그 자리를 어떻게 낼지.
    ///
    /// 순서가 있다. 레벨이 바탕을 깔고, 결이 기울이고, 활동이 마지막으로 덮는다.
    func visibility(of surface: UserSurface) -> SurfaceVisibility {
        var result = Self.baseVisibility(of: surface, level: level)
        result = Self.grainAdjusted(result, surface: surface, grain: grain)
        return Self.activityAdjusted(result, surface: surface, activity: activity)
    }

    /// 지금 이 화면에서 **앞에 세울 것** 하나. 없으면 nil.
    ///
    /// ⚠️ 여럿이 각자 옳다고 뜨면 하루에 다섯 번 걸리적거린다. 한 상태에서 주인공은
    ///    언제나 하나다(`UserSurface.allCases` 순서가 곧 우선순위).
    var leadingSurface: UserSurface? {
        UserSurface.allCases.first { visibility(of: $0) == .lead && $0.isPrompt }
    }

    // MARK: 바탕 - 레벨이 정하는 표

    static func baseVisibility(of surface: UserSurface, level: UserLevel) -> SurfaceVisibility {
        // 순서는 UserLevel 그대로: 구경 · 만듦 · 꺼냄 · 익음 · 능숙
        let row: [SurfaceVisibility]
        switch surface {
        case .tutorialStage:       row = [.lead,   .quiet,  .hidden, .hidden, .hidden]
        case .createShortcut:      row = [.lead,   .quiet,  .lead,   .lead,   .lead]
        // ⚠️ 능숙한 칸이 `.hidden` 이 아니다. 앱 안에서만 쓰며 200번을 넘긴 사람도 있고,
        //    그 사람은 키보드를 **켤 줄 몰라서** 가 아니라 켠 적이 없을 뿐이다. 그에게
        //    "다른 앱에서도 쓸 수 있어요" 는 초심자 안내가 아니라 가장 값진 한마디다.
        //    앞에 세우지만 않는다. 이미 켠 사람에게는 어차피 문(`keyboardUsable`)이 막는다.
        case .keyboardSetupBanner: row = [.hidden, .lead,   .quiet,  .hidden, .quiet]
        case .clipboardCapture:    row = [.hidden, .quiet,  .lead,   .lead,   .lead]
        case .favorites:           row = [.hidden, .hidden, .lead,   .lead,   .lead]
        case .template:            row = [.hidden, .hidden, .quiet,  .lead,   .lead]
        case .searchAndReorder:    row = [.hidden, .hidden, .quiet,  .lead,   .lead]
        case .categories:          row = [.hidden, .hidden, .hidden, .lead,   .lead]
        case .combo:               row = [.hidden, .hidden, .hidden, .quiet,  .lead]
        case .backupSync:          row = [.hidden, .hidden, .quiet,  .lead,   .lead]
        case .statsPassport:       row = [.hidden, .hidden, .hidden, .quiet,  .lead]
        case .decoration:          row = [.hidden, .hidden, .quiet,  .lead,   .lead]
        case .keyboardLayout:      row = [.hidden, .hidden, .quiet,  .lead,   .lead]
        case .widgets:             row = [.hidden, .hidden, .hidden, .quiet,  .lead]
        case .macApp:              row = [.hidden, .hidden, .hidden, .quiet,  .lead]
        case .slotLimit:           row = [.hidden, .hidden, .hidden, .quiet,  .lead]
        case .reviewRequest:       row = [.hidden, .hidden, .hidden, .quiet,  .quiet]
        case .bulkImport:          row = [.quiet,  .hidden, .quiet,  .lead,   .lead]
        // 아직 자기 것이 없는 사람에게 빈 서랍 대신 **고를 것**을 준다.
        // 한 번이라도 만든 사람에게는 조용히 두고, 쓰기 시작한 사람에게는 치운다.
        case .exampleMart:         row = [.lead,   .quiet,  .hidden, .hidden, .hidden]
        }
        return row[level.rawValue]
    }

    // MARK: 결이 기울인다

    static func grainAdjusted(_ base: SurfaceVisibility,
                              surface: UserSurface,
                              grain: UserGrain) -> SurfaceVisibility {
        switch grain {
        case .even:
            return base

        case .oneTrick:
            // 셋 가지고는 정리할 것이 없다. 늘리라고 하지 않고, 쓰는 것이 더 편해지는 길만 낸다.
            switch surface {
            case .searchAndReorder, .categories, .bulkImport: return .hidden
            case .template: return base == .hidden ? .quiet : .lead
            default: return base
            }

        case .hoarder:
            // 칸이 모자란 게 아니라 못 찾는 것이다. 더 만들라는 말과 한도 안내를 뺀다.
            switch surface {
            case .slotLimit: return .hidden
            case .favorites, .searchAndReorder: return .lead
            case .bulkImport: return base == .hidden ? .quiet : base
            default: return base
            }
        }
    }

    // MARK: 활동이 마지막으로 덮는다

    static func activityAdjusted(_ base: SurfaceVisibility,
                                 surface: UserSurface,
                                 activity: UserActivity) -> SurfaceVisibility {
        switch activity {
        case .active:
            return base

        case .dormant:
            // 돌아온 것 자체가 좋은 신호다. 먼저 말을 걸지 않는다.
            return surface.isPrompt ? .hidden : base

        case .returning:
            // 끊긴 자리를 이어 준다. 튜토리얼을 다시 틀거나 리뷰를 묻지 않는다.
            switch surface {
            case .tutorialStage, .reviewRequest, .slotLimit: return .hidden
            default: return base
            }
        }
    }
}
