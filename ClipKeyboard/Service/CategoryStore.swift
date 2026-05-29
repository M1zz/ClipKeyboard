//
//  CategoryStore.swift
//  ClipKeyboard
//
//  사용자 편집 가능한 메모 카테고리 목록.
//  - 첫 실행 시 Locale.current.regionCode 기반으로 기본 시드.
//  - 사용자 추가/삭제/순서변경 시 App Group UserDefaults에 영구 저장.
//  - 키보드 익스텐션도 같은 키를 읽어 일관된 카테고리 표시.
//
//  설계 원칙:
//  - ClipboardItemType (자동 분류 시스템) 과는 분리. ClipboardItemType은 시스템 내부에서
//    auto-detection 용도로만 쓰이고, UI에 노출되는 사용자-페이싱 카테고리는 이 store가 담당.
//  - rawValue가 "이메일", "URL" 등 ClipboardItemType과 겹치는 항목들은 그대로 유지하되
//    사용자는 자기 만든 항목 (예: "프리랜서 클라이언트", "여행 정보") 도 추가 가능.
//

import Foundation
import Combine

final class CategoryStore: ObservableObject {
    static let shared = CategoryStore()

    private let appGroup = "group.com.Ysoup.TokenMemo"
    /// 단일 진실 공급원 — 키보드 리스트 페이지 탭(ClipKeyboardListViewModel)·아이콘/레이아웃
    /// 설정과 동일한 키. CategorySettings(이 store 사용)와 키보드 페이지가 같은 목록을 본다.
    private let storageKey = "userDefinedCategories_v1"
    /// v4.2 이전 CategoryStore 전용 키 — 통일 시 이 store/키보드 키로 머지된다.
    private let legacyStorageKey = "user.categories.v1"
    /// 두 카테고리 키 통일 머지 1회 완료 플래그.
    private let unifiedMigrationKey = "category.store.unified.v1"
    private let seededFlagKey = "user.categories.seeded.v1"
    private let personaKey = "user.selected_persona.v1"
    /// v4.1.0: 카테고리 기능 활성화 플래그. 기본 OFF, 사용자가 명시적으로 활성화.
    private let featureEnabledKey = "category.feature.enabled.v1"
    /// 활성화 배너를 사용자가 "안 쓸래요"로 닫은 적이 있는지 — 다시 표시 안 함.
    private let activationDismissedKey = "category.activation.banner.dismissed.v1"
    /// 마이그레이션 완료 flag — 기존 사용자(category != "기본"인 메모 보유)는 자동 활성.
    private let featureMigratedKey = "category.feature.migrated.v1"

    @Published private(set) var categories: [String] = []
    @Published private(set) var isFeatureEnabled: Bool = false

    private init() {
        load()
        loadFeatureEnabledState()
    }

    // MARK: - Feature toggle (v4.1.0)

    /// 카테고리 기능 켜기. 메인 화면 탭/메모 추가 picker 노출.
    func enableFeature() {
        UserDefaults(suiteName: appGroup)?.set(true, forKey: featureEnabledKey)
        isFeatureEnabled = true
        print("✅ [CategoryStore] 카테고리 기능 활성화")
    }

    /// 사용자가 "안 쓸래요" 선택 — 배너 영구 닫기. 추후 카테고리 관리 페이지에서
    /// 수동으로 다시 켤 수 있음.
    func dismissActivationBanner() {
        UserDefaults(suiteName: appGroup)?.set(true, forKey: activationDismissedKey)
        print("🙈 [CategoryStore] 활성화 배너 영구 닫힘")
    }

    /// 활성화 배너를 보여줄지 — 미활성 + 미dismiss + 메모 5개 이상일 때 true.
    func shouldShowActivationBanner(currentMemoCount: Int) -> Bool {
        guard !isFeatureEnabled else { return false }
        let defaults = UserDefaults(suiteName: appGroup)
        if defaults?.bool(forKey: activationDismissedKey) == true { return false }
        return currentMemoCount >= 5
    }

    /// 첫 실행 시 마이그레이션 — 기존 사용자(메모 중 category가 "기본"이 아닌 것이
    /// 1개라도 있으면 카테고리를 이미 쓰고 있던 것)는 자동 활성. 신규 설치는 OFF.
    func migrateFeatureEnabledIfNeeded(existingMemoCategories: [String]) {
        let defaults = UserDefaults(suiteName: appGroup)
        guard defaults?.bool(forKey: featureMigratedKey) != true else { return }
        let hasNonDefault = existingMemoCategories.contains { $0 != "기본" && !$0.isEmpty }
        if hasNonDefault {
            defaults?.set(true, forKey: featureEnabledKey)
            isFeatureEnabled = true
            print("🔄 [CategoryStore] 기존 사용자 자동 활성 (category != 기본인 메모 보유)")
        }
        defaults?.set(true, forKey: featureMigratedKey)
    }

    private func loadFeatureEnabledState() {
        isFeatureEnabled = UserDefaults(suiteName: appGroup)?.bool(forKey: featureEnabledKey) ?? false
    }

    // MARK: - Persona

    /// 사용자가 온보딩에서 선택한 페르소나. nil이면 미선택.
    var selectedPersona: Persona? {
        get {
            guard let raw = UserDefaults(suiteName: appGroup)?.string(forKey: personaKey) else {
                return nil
            }
            return Persona(rawValue: raw)
        }
    }

    /// 페르소나 선택을 저장한다. (카테고리는 기본 제공하지 않으므로 시드하지 않음 —
    /// 사용자가 직접 카테고리를 만들어 쓴다. persona 값은 제안/연습 등 다른 기능에서 사용.)
    func applyPersona(_ persona: Persona, language: String? = nil) {
        UserDefaults(suiteName: appGroup)?.set(persona.rawValue, forKey: personaKey)
        print("👤 [CategoryStore] 페르소나 선택 저장: \(persona.rawValue)")
    }

    // MARK: - Public API

    /// 사용자가 보는 전체 카테고리 목록 — 순서대로.
    var allCategories: [String] { categories }

    /// 새 카테고리 추가. 중복 시 무시.
    @discardableResult
    func add(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !categories.contains(trimmed) else { return false }
        categories.append(trimmed)
        persist()
        return true
    }

    /// 카테고리 이름 변경. 중복 시 무시.
    @discardableResult
    func rename(from oldName: String, to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, oldName != trimmed,
              let idx = categories.firstIndex(of: oldName),
              !categories.contains(trimmed) else { return false }
        categories[idx] = trimmed
        persist()
        return true
    }

    /// 카테고리 삭제. 보호 카테고리 (기본/텍스트/이미지) 제외.
    @discardableResult
    func remove(_ name: String) -> Bool {
        guard !Self.protectedCategories.contains(name) else { return false }
        guard let idx = categories.firstIndex(of: name) else { return false }
        categories.remove(at: idx)
        persist()
        return true
    }

    /// 순서 변경 (SwiftUI .onMove에서 호출).
    func move(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    /// 모든 카테고리 삭제 (메모는 유지되며 카테고리 탭만 사라짐).
    func removeAll() {
        categories = []
        persist()
    }

    /// 보호 카테고리 — 삭제 불가.
    static let protectedCategories: Set<String> = ["기본", "텍스트", "이미지"]

    // MARK: - Storage

    /// 외부(예: CategorySettings.onAppear)에서 디스크 최신값으로 다시 읽기.
    /// 키보드 컨텍스트 메뉴 등 다른 경로가 같은 키를 갱신했을 수 있으므로.
    func reload() {
        load()
    }

    private func load() {
        guard let defaults = UserDefaults(suiteName: appGroup) else {
            categories = []
            return
        }
        // v4.2: 두 카테고리 키(레거시 user.categories.v1 + 키보드 userDefinedCategories_v1) 통일.
        migrateUnifyIfNeeded(defaults)

        if let stored = defaults.stringArray(forKey: storageKey), !stored.isEmpty {
            categories = stored
        } else {
            // 기본 제공 카테고리 없음 — 사용자가 직접 만들어 쓴다.
            // (전체/즐겨찾기 탭은 카테고리 목록과 무관하게 항상 제공됨)
            categories = []
            defaults.set(true, forKey: seededFlagKey)
        }
    }

    /// 레거시 CategoryStore 키와 키보드 키에 흩어진 카테고리를 canonical 키로 합친다(손실 없음).
    /// 기존 canonical(키보드) 순서를 우선 유지하고, 레거시에만 있던 항목을 뒤에 덧붙인다.
    private func migrateUnifyIfNeeded(_ defaults: UserDefaults) {
        guard !defaults.bool(forKey: unifiedMigrationKey) else { return }

        let canonical = defaults.stringArray(forKey: storageKey) ?? []
        let legacy = defaults.stringArray(forKey: legacyStorageKey) ?? []

        if !(canonical.isEmpty && legacy.isEmpty) {
            var merged = canonical
            for cat in legacy where !merged.contains(cat) {
                merged.append(cat)
            }
            // 보호 카테고리 누락 방지
            if !merged.contains("기본") { merged.insert("기본", at: 0) }
            defaults.set(merged, forKey: storageKey)
            print("🔄 [CategoryStore] 카테고리 통일 머지: 키보드 \(canonical.count) + 레거시 \(legacy.count) → \(merged.count)")
        }
        defaults.set(true, forKey: unifiedMigrationKey)
    }

    private func persist() {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        defaults.set(categories, forKey: storageKey)
    }
}
