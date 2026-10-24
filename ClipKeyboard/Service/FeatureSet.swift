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
        print("🔧 [FeatureSet.set] \(feature.rawValue) = \(on)")
        NotificationCenter.postOnMain(name: .featureSetChanged, object: nil)
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
