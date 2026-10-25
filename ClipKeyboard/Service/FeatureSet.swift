//
//  FeatureSet.swift
//  ClipKeyboard
//
//  **켤 수 있는 기능 다섯 가지**와 그 스위치. 설정 ▸ 기능 더하기에서 켜고 끈다.
//
//  백지 첫 실행으로 시작한 사람(새 설치)은 다섯 다 꺼진 채 시작한다. 이름 · 내용만 있는
//  단축어로 쓰다가, 쓰는 모습이 부를 때(넛지) 또는 스스로 설정에서 켠다.
//
//  ⚠️ 기존 사용자는 언제나 다 켜져 있다. 이 저장소를 한 번도 읽지 않은 것과 같다.
//     업데이트했다고 쓰던 기능이 사라지면 안 된다(docs/design/blank-start-onboarding.html).
//  ⚠️ App Group 에 둔다. 키보드도 같은 스위치를 본다(최근 탭 · 템플릿 칩 등).
//

import Foundation

enum AppFeature: String, CaseIterable, Identifiable {
    case template, stack, secure, category, recent

    var id: String { rawValue }

    /// 이 기능을 처음 배울 때의 장부 칸. 이름이 같다.
    var lesson: Lesson {
        switch self {
        case .template: return .template
        case .stack: return .stack
        case .secure: return .secure
        case .category: return .category
        case .recent: return .recent
        }
    }
}

enum FeatureSet {

    // MARK: - 누구인가

    /// 백지 첫 실행으로 시작한 사람인가. 아니면 기존 사용자다(기능 전부 켜짐 · 화면 그대로).
    ///
    /// ⚠️ 그룹에도 적어 둔다. 키보드 익스텐션은 앱의 표준 UserDefaults 를 못 본다.
    static func isBlankStartUser(standard: UserDefaults = .standard,
                                 group: UserDefaults? = AppGroup.defaults) -> Bool {
        standard.bool(forKey: DefaultsKey.blankStartV1) || group?.bool(forKey: DefaultsKey.blankStartV1) == true
    }

    // MARK: - 스위치

    static func isOn(_ feature: AppFeature,
                     standard: UserDefaults = .standard,
                     group: UserDefaults? = AppGroup.defaults) -> Bool {
        guard isBlankStartUser(standard: standard, group: group) else { return true }
        return group?.bool(forKey: key(feature)) ?? false
    }

    static func set(_ feature: AppFeature, on: Bool, group: UserDefaults? = AppGroup.defaults) {
        group?.set(on, forKey: key(feature))
        // 이미 있는 스위치 둘은 그쪽을 같이 움직인다. 화면 · 키보드는 그 스위치를 본다
        switch feature {
        case .recent: group?.set(on, forKey: KeyboardPrefs.showRecentClipsTab.key)   // 목록 · 키보드의 '최근'
        case .category: on ? CategoryStore.shared.enableFeature() : CategoryStore.shared.disableFeature()
        case .template, .stack, .secure: break
        }
        print("🔧 [FeatureSet.set] \(feature.rawValue) = \(on)")
        NotificationCenter.postOnMain(name: .featureSetChanged, object: nil)
    }

    // MARK: - 졸업

    /// 백지 사용자가 단순한 화면을 **졸업**했는가. 졸업하면 + 가 원래 메뉴(임시 저장 · 단축어 마트 ·
    /// 한번에 정리 · 빈칸 관리)가 되고, 사용 기록 탭이 원래 조건대로 서고, 팁이 돌아온다.
    /// 안내 띠 · 카드는 졸업해도 숨긴 채다.
    ///
    /// 언제: 기능 다섯을 다 켰다('전부 쓸래요'), 또는 손에 붙었다(`UserLevel.fluent` 이상:
    /// 10번 넘게 쓰고, 키보드로 넣어 봤고, 3일 넘게 썼다). 기존 사용자는 처음부터 졸업한 것과 같다.
    ///
    /// ⚠️ 졸업 길이 없으면 처음 사용자는 1년을 써도 + 메뉴 · 사용 기록을 영영 못 본다(설계 검토, 2026-10).
    /// - Parameter level: 사용자 단계. 앱이 `UserStateStore` 에서 넘긴다(시험이 값을 넣어 볼 수 있게).
    static func hasGraduated(level: UserLevel,
                             standard: UserDefaults = .standard,
                             group: UserDefaults? = AppGroup.defaults) -> Bool {
        guard isBlankStartUser(standard: standard, group: group) else { return true }
        // 한 번 졸업하면 그대로다(기능을 하나 꺼도 메뉴가 다시 숨지 않는다). 앱이 켜질 때는 이 값만 읽는다
        if group?.bool(forKey: DefaultsKey.blankStartGraduated) == true { return true }
        let now = AppFeature.allCases.allSatisfy({ isOn($0, standard: standard, group: group) }) || level >= .fluent
        if now {
            group?.set(true, forKey: DefaultsKey.blankStartGraduated)
            print("🎓 [FeatureSet.hasGraduated] 단순한 화면을 졸업")
        }
        return now
    }

    /// 아무 기능도 안 켠 백지 사용자. 목록 · 새 단축어가 가장 단순한 모양이 된다.
    static func isPlain(standard: UserDefaults = .standard, group: UserDefaults? = AppGroup.defaults) -> Bool {
        isBlankStartUser(standard: standard, group: group)
            && !AppFeature.allCases.contains { isOn($0, standard: standard, group: group) }
    }

    // MARK: - Private Helpers

    private static func key(_ feature: AppFeature) -> String {
        DefaultsKey.featureOnPrefix + feature.rawValue
    }
}
