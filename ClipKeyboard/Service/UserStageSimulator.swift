//
//  UserStageSimulator.swift
//  ClipKeyboard
//
//  "그 단계의 사람이 쓰는 것처럼" 앱을 보이게 하는 **개발자 전용** 장치.
//
//  단계를 고르면 두 가지가 한꺼번에 일어난다.
//   ① 그 단계 사람의 서랍(단축어·클립보드·카테고리)이 깔린다 - 화면이 진짜로 그렇게 보인다.
//   ② 상태 판정이 그 단계로 고정된다(`UserStateStore`) - 안내·띠·감춤이 그 사람 것으로 바뀐다.
//
//  ⚠️ 하나만으로는 안 된다. 데이터만 깔면 설치일·활동일 같은 것은 흉내 낼 수 없어 판정이
//     어긋나고, 판정만 바꾸면 목록은 여전히 내 것이라 화면이 거짓말을 한다.
//
//  ⚠️ **내 데이터는 안전하다.** 데모 데이터와 같은 백업을 쓴다(`DemoDataService`).
//     단계를 끄면 원래 단축어·클립보드·카테고리가 그대로 돌아온다.
//
//  자세한 설계: docs/product/USER_STATE_MODEL.md
//

import Foundation

// MARK: - 단계

/// 흉내 낼 수 있는 단계. 지도의 칸들과 같다(`docs/product/USER_STATE_MODEL.md`).
enum UserStage: String, CaseIterable, Identifiable {
    case firstDay        // 첫 방문자      L0 · T0
    case browsing        // 구경만 하는 사람 L0 · T1+
    case madeAndStopped  // 만들고 멈춘 사람 L1
    case firstUse        // 처음 써 본 사람  L2
    case fluent          // 손에 익은 사람   L3
    case expert          // 능숙한 사람      L4
    case oneTrick        // 하나만 쓰는 사람  결
    case hoarder         // 쌓아만 두는 사람  결
    case dormant         // 휴면
    case returning       // 돌아온 사람

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstDay:       return NSLocalizedString("첫 방문자", comment: "Stage simulator: first day")
        case .browsing:       return NSLocalizedString("구경만 하는 사람", comment: "Stage simulator: browsing")
        case .madeAndStopped: return NSLocalizedString("만들고 멈춘 사람", comment: "Stage simulator: created but never used")
        case .firstUse:       return NSLocalizedString("처음 써 본 사람", comment: "Stage simulator: first use")
        case .fluent:         return NSLocalizedString("손에 익은 사람", comment: "Stage simulator: habitual")
        case .expert:         return NSLocalizedString("능숙한 사람", comment: "Stage simulator: expert")
        case .oneTrick:       return NSLocalizedString("하나만 쓰는 사람", comment: "Stage simulator: one trick")
        case .hoarder:        return NSLocalizedString("쌓아만 두는 사람", comment: "Stage simulator: hoarder")
        case .dormant:        return NSLocalizedString("휴면", comment: "Stage simulator: dormant")
        case .returning:      return NSLocalizedString("돌아온 사람", comment: "Stage simulator: returning")
        }
    }

    /// 이 단계에서 **무엇이 달라 보이는지** 한 줄. 고르기 전에 알아야 고를 수 있다.
    var summary: String {
        switch self {
        case .firstDay:
            return NSLocalizedString("설치 첫날, 자기 단축어가 없다. 무대 튜토리얼만 보인다.", comment: "Stage summary: first day")
        case .browsing:
            return NSLocalizedString("일주일이 지나도 하나도 안 만들었다. 예시에서 고르는 화면이 나온다.", comment: "Stage summary: browsing")
        case .madeAndStopped:
            return NSLocalizedString("만들어만 두고 한 번도 안 썼다. 키보드 켜기 띠가 주인공이다.", comment: "Stage summary: created but never used")
        case .firstUse:
            return NSLocalizedString("몇 번 꺼내 썼다. 두 번째 쓸모 하나만 권한다.", comment: "Stage summary: first use")
        case .fluent:
            return NSLocalizedString("여러 날에 걸쳐 쓴다. 카테고리와 백업이 열린다.", comment: "Stage summary: habitual")
        case .expert:
            return NSLocalizedString("빈칸과 콤보까지 쓴다. 초심자 안내가 모두 사라진다.", comment: "Stage summary: expert")
        case .oneTrick:
            return NSLocalizedString("단축어 둘로 예순 번 썼다. 정리 기능이 빠진다.", comment: "Stage summary: one trick")
        case .hoarder:
            return NSLocalizedString("열한 개를 만들고 둘만 쓴다. 한도 안내가 빠지고 찾기가 앞에 선다.", comment: "Stage summary: hoarder")
        case .dormant:
            return NSLocalizedString("한 달 동안 안 썼다. 먼저 말을 거는 자리가 전부 꺼진다.", comment: "Stage summary: dormant")
        case .returning:
            return NSLocalizedString("오랜만에 다시 열었다. 튜토리얼도 리뷰도 다시 묻지 않는다.", comment: "Stage summary: returning")
        }
    }

    // MARK: 이 단계가 만들어 내는 상태

    /// 판정에 넣을 값.
    ///
    /// ⚠️ 서랍에서 **셀 수 있는 것은 서랍에서 센다**(개수·사용 횟수·마지막 사용). 흉내가
    ///    아니라 실제로 그 데이터가 그 값을 낳아야, 화면에 보이는 목록과 판정이 어긋나지 않는다.
    ///    설치일·활동일처럼 단축어만 봐서는 알 수 없는 것만 여기서 정한다.
    ///
    /// ⚠️ `now` 를 받는다. 기본값으로 `Date()` 를 두 번 부르면 설치일이 판정 시각보다
    ///    **몇 마이크로초 뒤**가 되고, 첫날 단계가 "설치일을 모르는 기기"로 떨어져
    ///    오랜 사용자로 판정된다.
    func facts(now: Date = Date()) -> UserStateFacts {
        let drawer = memos
        var f = UserStateFacts(
            installedAt: now.addingTimeInterval(-daysSinceInstall * 86_400),
            activeDays: activeDays,
            returnedAt: self == .returning ? now.addingTimeInterval(-2 * 86_400) : nil,
            keyboardInstalled: keyboardInstalled
        )
        f.ownShortcuts = drawer.count
        f.uses = drawer.reduce(0) { $0 + $1.clipCount }
        f.keyboardPastes = keyboardPastes
        f.lastUsedAt = drawer.compactMap(\.lastUsedAt).max()
        f.templates = drawer.filter { $0.childMemoIds.isEmpty && $0.isTemplate }.count
        f.combos = drawer.filter { !$0.childMemoIds.isEmpty || !$0.stackValues.isEmpty }.count
        f.unusedShortcuts = drawer.filter { $0.clipCount == 0 }.count
        return f
    }

    /// 이 단계로 고정될 상태.
    ///
    /// ⚠️ 바닥은 언제나 `.browsing` 이다. 진짜 바닥을 끌어오면 능숙한 사람의 기기에서
    ///    첫 방문자를 흉내 낼 수 없다 - 바닥이 레벨을 도로 올려 버린다.
    func state(now: Date = Date()) -> UserState {
        UserState.resolve(facts: facts(now: now), floor: .browsing, now: now)
    }

    private var daysSinceInstall: Double {
        switch self {
        case .firstDay:       return 0
        case .browsing:       return 9
        case .madeAndStopped: return 12
        case .firstUse:       return 5
        case .fluent:         return 40
        case .expert:         return 150
        case .oneTrick:       return 60
        case .hoarder:        return 45
        case .dormant:        return 120
        case .returning:      return 200
        }
    }

    private var activeDays: Int {
        switch self {
        case .firstDay, .browsing, .madeAndStopped: return 0
        case .firstUse:  return 2
        case .fluent:    return 9
        case .expert:    return 40
        case .oneTrick:  return 18
        case .hoarder:   return 4
        case .dormant:   return 26
        case .returning: return 31
        }
    }

    private var keyboardPastes: Int {
        switch self {
        case .firstDay, .browsing, .madeAndStopped: return 0
        case .firstUse:  return 2
        case .fluent:    return 25
        case .expert:    return 160
        case .oneTrick:  return 44
        case .hoarder:   return 5
        case .dormant:   return 70
        case .returning: return 70
        }
    }

    private var keyboardInstalled: Bool {
        switch self {
        case .firstDay, .browsing, .madeAndStopped: return false
        default: return true
        }
    }

    /// 이 단계 사람이 쓰는 카테고리. 빈 배열이면 카테고리 기능 자체가 꺼진 것처럼 보인다.
    var categories: [String] {
        switch self {
        case .fluent:  return ["업무", "개인"]
        case .expert:  return ["업무", "개인", "계약", "여행"]
        case .hoarder: return ["업무", "나중에"]
        default:       return []
        }
    }
}

// MARK: - 서랍 (그 단계 사람의 단축어)

extension UserStage {

    var memos: [Memo] {
        switch self {
        case .firstDay:
            // 아직 아무것도 없다. 무대 튜토리얼이 채울 자리다.
            return []

        case .browsing:
            // 복사는 하는데 단축어로 만들지는 않았다. 목록은 여전히 비어 있다.
            return []

        case .madeAndStopped:
            return [
                make("계좌번호", "우리은행 1002-123-456789"),
                make("집 주소", "서울시 마포구 월드컵북로 00, 000동 0000호"),
                make("회사 이메일", "leeo@example.com")
            ]

        case .firstUse:
            return [
                make("계좌번호", "우리은행 1002-123-456789", clips: 3, daysAgo: 0.2),
                make("집 주소", "서울시 마포구 월드컵북로 00, 000동 0000호", clips: 2, daysAgo: 1.1),
                make("회사 이메일", "leeo@example.com", clips: 1, daysAgo: 2.4),
                make("주차 등록", "12가 3456")
            ]

        case .fluent:
            return [
                make("계좌번호", "우리은행 1002-123-456789", favorite: true, clips: 12, daysAgo: 0.1),
                make("집 주소", "서울시 마포구 월드컵북로 00, 000동 0000호", favorite: true, clips: 9, daysAgo: 0.4),
                make("회사 이메일", "leeo@example.com", clips: 7, daysAgo: 1.2, category: "업무"),
                make("사업자 번호", "000-00-00000", clips: 5, daysAgo: 2.0, category: "업무"),
                make("주차 등록", "12가 3456", clips: 4, daysAgo: 3.1),
                make("와이파이 비밀번호", "hello-world-0000", clips: 2, daysAgo: 5.0, category: "개인"),
                make("택배 받는 곳", "문 앞에 놓아 주세요", clips: 1, daysAgo: 6.3, category: "개인"),
                make("병원 예약 문구", "예약 확인 부탁드립니다", category: "개인")
            ]

        case .expert:
            return [
                make("계좌번호", "우리은행 1002-123-456789", favorite: true, clips: 41, daysAgo: 0.05),
                make("집 주소", "서울시 마포구 월드컵북로 00, 000동 0000호", favorite: true, clips: 33, daysAgo: 0.2),
                make("회사 이메일", "leeo@example.com", clips: 22, daysAgo: 0.5, category: "업무"),
                make("견적 회신", "{이름}님 안녕하세요. 말씀 주신 {건}은 {금액}에 가능합니다.",
                     clips: 18, daysAgo: 0.8, category: "업무", variables: ["이름", "건", "금액"]),
                make("사업자 번호", "000-00-00000", clips: 15, daysAgo: 1.1, category: "계약"),
                make("계약서 문구", "{회사}와 {이름}은 아래와 같이 계약한다.",
                     clips: 12, daysAgo: 1.6, category: "계약", variables: ["회사", "이름"]),
                make("입금 안내", "입금 확인되면 바로 시작하겠습니다.", clips: 11, daysAgo: 2.2, category: "업무"),
                make("여권 번호", "M00000000", clips: 9, daysAgo: 3.0, category: "여행"),
                make("항공 예약", "{항공사} {편명} · {날짜}", clips: 8, daysAgo: 4.0,
                     category: "여행", variables: ["항공사", "편명", "날짜"]),
                make("송장 세트", "받는 분", clips: 14, daysAgo: 1.0, category: "업무",
                     stack: ["홍길동", "010-0000-0000", "서울시 마포구 월드컵북로 00"]),
                make("계좌 한 벌", "예금주", clips: 10, daysAgo: 2.5, category: "계약",
                     stack: ["이현호", "우리은행", "1002-123-456789"]),
                make("와이파이 비밀번호", "hello-world-0000", clips: 4, daysAgo: 8.0, category: "개인"),
                make("택배 받는 곳", "문 앞에 놓아 주세요", clips: 3, daysAgo: 12.0, category: "개인"),
                make("병원 예약 문구", "예약 확인 부탁드립니다", category: "개인")
            ]

        case .oneTrick:
            return [
                make("계좌번호", "우리은행 1002-123-456789", favorite: true, clips: 47, daysAgo: 0.1),
                make("집 주소", "서울시 마포구 월드컵북로 00, 000동 0000호", clips: 13, daysAgo: 1.0)
            ]

        case .hoarder:
            var drawer = [
                make("계좌번호", "우리은행 1002-123-456789", clips: 7, daysAgo: 0.6),
                make("집 주소", "서울시 마포구 월드컵북로 00, 000동 0000호", clips: 2, daysAgo: 4.0)
            ]
            // 만들어 놓고 한 번도 안 쓴 것들. 쌓아만 두는 사람의 화면이 이렇게 생겼다.
            let unused = ["회사 이메일", "사업자 번호", "주차 등록", "와이파이 비밀번호",
                          "택배 받는 곳", "병원 예약 문구", "보험 증권 번호", "차량 번호", "회의 안내"]
            for (index, title) in unused.enumerated() {
                drawer.append(make(title, "\(title) 값",
                                   category: index.isMultiple(of: 2) ? "업무" : "나중에"))
            }
            return drawer

        case .dormant:
            // 잘 쓰던 사람인데 한 달 동안 손을 안 댔다. 마지막 사용만 멀찍이 밀어 둔다.
            return UserStage.fluent.memos.map { memo in
                var aged = memo
                aged.lastUsedAt = memo.lastUsedAt.map { $0.addingTimeInterval(-32 * 86_400) }
                aged.lastEdited = aged.lastUsedAt ?? aged.lastEdited
                return aged
            }

        case .returning:
            // 오랜만에 다시 열어 방금 한 번 썼다.
            return UserStage.fluent.memos.enumerated().map { index, memo in
                var back = memo
                if index == 0 { back.lastUsedAt = Date().addingTimeInterval(-600) }
                else { back.lastUsedAt = memo.lastUsedAt.map { $0.addingTimeInterval(-40 * 86_400) } }
                return back
            }
        }
    }

    /// 클립보드 기록. 단계에 맞는 분량만 깔면 클립보드 화면도 같이 그 단계가 된다.
    var clipboardCount: Int {
        switch self {
        case .firstDay:       return 2
        case .browsing:       return 6
        case .madeAndStopped: return 4
        case .firstUse:       return 5
        default:              return 8
        }
    }

    // MARK: 만들기 도우미

    /// `daysAgo` 가 없으면 **한 번도 안 쓴** 단축어다.
    private func make(_ title: String,
                      _ value: String,
                      favorite: Bool = false,
                      clips: Int = 0,
                      daysAgo: Double? = nil,
                      category: String = "기본",
                      variables: [String] = [],
                      stack: [String] = []) -> Memo {
        let usedAt: Date? = daysAgo.map { Date().addingTimeInterval(-$0 * 86_400) }
        var memo = Memo(title: title,
                        value: value,
                        isFavorite: favorite,
                        category: category,
                        templateVariables: variables,
                        stackValues: stack,
                        lastUsedAt: usedAt)
        memo.clipCount = clips
        memo.lastEdited = usedAt ?? Date().addingTimeInterval(-3 * 86_400)
        return memo
    }
}

// MARK: - 켜고 끄기

enum UserStageSimulator {

    private static var defaults: UserDefaults? { AppGroup.defaults }

    /// 지금 흉내 내는 단계. 없으면 진짜 상태를 쓴다.
    static var activeStage: UserStage? {
        guard let raw = defaults?.string(forKey: DefaultsKey.userStateSimulatedStage) else { return nil }
        return UserStage(rawValue: raw)
    }

    /// 단계 하나를 깐다.
    ///
    /// 내 데이터는 데모 데이터와 같은 백업에 들어간다. `clear()` 로 그대로 돌아온다.
    @discardableResult
    static func apply(_ stage: UserStage) -> Bool {
        backupCategoriesIfNeeded()

        let clipboard = Array(DemoDataService.demoClipboard().prefix(stage.clipboardCount))
        guard DemoDataService.shared.apply(memos: stage.memos, clipboard: clipboard) else { return false }

        applyCategories(stage.categories)
        defaults?.set(stage.rawValue, forKey: DefaultsKey.userStateSimulatedStage)
        print("🎭 [UserStageSimulator] '\(stage.rawValue)' 단계로 갈아입음")
        return true
    }

    /// 단계를 끄고 내 데이터·카테고리를 되돌린다.
    @discardableResult
    static func clear() -> Bool {
        defaults?.removeObject(forKey: DefaultsKey.userStateSimulatedStage)
        restoreCategories()
        let restored = DemoDataService.shared.disable()
        print("🎭 [UserStageSimulator] 단계 끄고 원래대로")
        return restored
    }

    // MARK: 카테고리

    /// ⚠️ 한 번만 적어 둔다. 단계를 옮겨 다니는 동안 덮어쓰면 시뮬레이터가 깔아 준
    ///    카테고리가 "원래 것"으로 굳는다.
    ///
    /// ⚠️ **목록과 함께 스위치도 적어 둔다.** 목록만 되돌리면 카테고리 기능이 꺼진 채로
    ///    남아서, 되돌렸는데도 화면에서는 카테고리가 사라진 것으로 보인다.
    private static func backupCategoriesIfNeeded() {
        guard defaults?.object(forKey: DefaultsKey.userStageCategoryBackup) == nil else { return }
        let current = defaults?.stringArray(forKey: DefaultsKey.userDefinedCategoriesV1) ?? []
        defaults?.set(current, forKey: DefaultsKey.userStageCategoryBackup)
        // ⚠️ **켜짐·꺼짐만으로는 모자란다.** 이 스위치는 값이 아예 없으면 **켜진 것**으로
        //    친다(`CategoryStore.loadFeatureEnabledState`). 없던 것을 false 로 적어 두면
        //    되돌릴 때 "사용자가 직접 껐다" 로 굳어, 원래 보이던 카테고리가 사라진다.
        //    그래서 없었다는 사실까지 남긴다.
        let switchState: String
        switch defaults?.object(forKey: DefaultsKey.categoryFeatureEnabledV1) as? Bool {
        case .some(true):  switchState = "on"
        case .some(false): switchState = "off"
        case .none:        switchState = "unset"
        }
        defaults?.set(switchState, forKey: DefaultsKey.userStageCategoryFeatureBackup)
    }

    private static func applyCategories(_ categories: [String]) {
        defaults?.set(categories, forKey: DefaultsKey.userDefinedCategoriesV1)
        defaults?.set(!categories.isEmpty, forKey: DefaultsKey.categoryFeatureEnabledV1)
        CategoryStore.shared.reload()
        NotificationCenter.postOnMain(name: .memoDataChanged, object: nil)
    }

    /// 적어 둔 것이 있으면 목록과 스위치를 **함께** 되돌린다.
    private static func restoreCategories() {
        guard let saved = defaults?.stringArray(forKey: DefaultsKey.userStageCategoryBackup) else { return }
        defaults?.set(saved, forKey: DefaultsKey.userDefinedCategoriesV1)
        switch defaults?.string(forKey: DefaultsKey.userStageCategoryFeatureBackup) {
        case "on":    defaults?.set(true, forKey: DefaultsKey.categoryFeatureEnabledV1)
        case "off":   defaults?.set(false, forKey: DefaultsKey.categoryFeatureEnabledV1)
        case "unset": defaults?.removeObject(forKey: DefaultsKey.categoryFeatureEnabledV1)
        default:      break
        }
        defaults?.removeObject(forKey: DefaultsKey.userStageCategoryBackup)
        defaults?.removeObject(forKey: DefaultsKey.userStageCategoryFeatureBackup)
        CategoryStore.shared.reload()
        CategoryStore.shared.reloadFeatureState()
        NotificationCenter.postOnMain(name: .memoDataChanged, object: nil)
    }
}

// MARK: - 시험용 창구

/// ⚠️ 되돌리기가 제대로 되는지는 **화면 없이** 확인할 수 있어야 한다.
///    한 번 빠뜨려서 사람의 카테고리가 사라져 보였던 자리라, 문을 따로 낸다.
extension UserStageSimulator {
    static func backupCategoriesForTesting() { backupCategoriesIfNeeded() }
    static func applyCategoriesForTesting(_ categories: [String]) { applyCategories(categories) }
    static func restoreCategoriesForTesting() { restoreCategories() }
}
