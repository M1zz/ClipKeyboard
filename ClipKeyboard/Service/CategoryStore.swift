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

    /// 단일 진실 공급원 - 키보드 리스트 페이지 탭(ClipKeyboardListViewModel)·아이콘/레이아웃
    /// 설정과 동일한 키. CategorySettings(이 store 사용)와 키보드 페이지가 같은 목록을 본다.
    private let storageKey = "userDefinedCategories_v1"
    /// v4.2 이전 CategoryStore 전용 키 - 통일 시 이 store/키보드 키로 머지된다.
    private let legacyStorageKey = "user.categories.v1"
    /// 두 카테고리 키 통일 머지 1회 완료 플래그.
    private let unifiedMigrationKey = "category.store.unified.v1"
    private let seededFlagKey = "user.categories.seeded.v1"
    private let personaKey = "user.selected_persona.v1"
    /// v4.1.0: 카테고리 기능 활성화 플래그. 기본 OFF, 사용자가 명시적으로 활성화.
    private let featureEnabledKey = "category.feature.enabled.v1"
    /// 활성화 배너를 사용자가 "안 쓸래요"로 닫은 적이 있는지 - 다시 표시 안 함.
    private let activationDismissedKey = "category.activation.banner.dismissed.v1"
    /// 마이그레이션 완료 flag - 기존 사용자(category != "기본"인 메모 보유)는 자동 활성.
    private let featureMigratedKey = "category.feature.migrated.v1"

    /// 기본 제공 카테고리(타입별 모아보기) 활성화 목록. 키보드 리스트와 동일 키 공유.
    private let enabledBuiltInKey = "enabledBuiltInCategories_v1"

    @Published private(set) var categories: [String] = []
    @Published private(set) var isFeatureEnabled: Bool = false
    /// 사용자가 켠 기본 제공 카테고리 rawValue 집합 (BuiltInCategory.rawValue).
    @Published private(set) var enabledBuiltIns: Set<String> = []

    /// 복원·가져오기가 App Group 값을 갈아끼웠을 때 다시 읽기 위한 구독.
    private var restoreObserver: NSObjectProtocol?

    private init() {
        load()
        loadFeatureEnabledState()
        loadBuiltInState()

        // ⚠️ 복원·가져오기·동기화는 이 값들을 **파일이 아니라 App Group UserDefaults 에**
        //    직접 써 넣는다. 그때 이 저장소가 들고 있는 목록은 복원 이전 것 그대로다.
        //    그러면 두 가지가 한꺼번에 벌어진다.
        //      · 화면에는 되살아난 카테고리가 안 보인다("복원했는데 다 날아갔다")
        //      · 그 뒤 아무 편집이나 하면 `persist()` 가 **낡은 목록을 되살린 값 위에 덮는다**
        //    그래서 알림을 듣고 곧바로 다시 읽는다.
        restoreObserver = NotificationCenter.default.addObserver(
            forName: .dataRestored, object: nil, queue: .main
        ) { [weak self] _ in
            self?.reload()
            self?.loadFeatureEnabledState()
            self?.loadBuiltInState()
        }
    }

    // MARK: - 기본 제공 카테고리 (타입별 모아보기)

    private func loadBuiltInState() {
        enabledBuiltIns = Set(AppGroup.defaults?.stringArray(forKey: enabledBuiltInKey) ?? [])
    }

    /// 해당 기본 제공 카테고리가 켜져 있는지.
    func isBuiltInEnabled(_ rawValue: String) -> Bool {
        enabledBuiltIns.contains(rawValue)
    }

    /// 기본 제공 카테고리 켜기/끄기. App Group에 영구 저장 → 리스트 탭에 즉시 반영.
    func setBuiltInEnabled(_ rawValue: String, _ enabled: Bool) {
        if enabled { enabledBuiltIns.insert(rawValue) } else { enabledBuiltIns.remove(rawValue) }
        AppGroup.defaults?.set(Array(enabledBuiltIns), forKey: enabledBuiltInKey)
        print("\(enabled ? "✅" : "🚫") [CategoryStore] 기본 제공 카테고리 '\(rawValue)' \(enabled ? "켜짐" : "꺼짐")")
    }

    // MARK: - Feature toggle (v4.1.0)

    /// 카테고리 기능 켜기. 메인 화면 탭/메모 추가 picker 노출.
    func enableFeature() {
        AppGroup.defaults?.set(true, forKey: featureEnabledKey)
        isFeatureEnabled = true
        print("✅ [CategoryStore] 카테고리 기능 활성화")
    }

    /// 사용자가 "안 쓸래요" 선택 - 배너 영구 닫기. 추후 카테고리 관리 페이지에서
    /// 수동으로 다시 켤 수 있음.
    func dismissActivationBanner() {
        AppGroup.defaults?.set(true, forKey: activationDismissedKey)
        print("🙈 [CategoryStore] 활성화 배너 영구 닫힘")
    }

    /// 활성화 배너를 보여줄지 - 미활성 + 미dismiss + 메모 5개 이상일 때 true.
    func shouldShowActivationBanner(currentMemoCount: Int) -> Bool {
        guard !isFeatureEnabled else { return false }
        let defaults = AppGroup.defaults
        if defaults?.bool(forKey: activationDismissedKey) == true { return false }
        return currentMemoCount >= 5
    }

    /// 첫 실행 시 마이그레이션 - 기존 사용자(메모 중 category가 "기본"이 아닌 것이
    /// 1개라도 있으면 카테고리를 이미 쓰고 있던 것)는 자동 활성. 신규 설치는 OFF.
    func migrateFeatureEnabledIfNeeded(existingMemoCategories: [String]) {
        let defaults = AppGroup.defaults
        guard defaults?.bool(forKey: featureMigratedKey) != true else { return }
        let hasNonDefault = existingMemoCategories.contains { $0 != "기본" && !$0.isEmpty }
        if hasNonDefault {
            defaults?.set(true, forKey: featureEnabledKey)
            isFeatureEnabled = true
            print("🔄 [CategoryStore] 기존 사용자 자동 활성 (category != 기본인 메모 보유)")
        }
        defaults?.set(true, forKey: featureMigratedKey)
    }

    /// 카테고리 기능은 **처음부터 켜져 있다.**
    ///
    /// ⚠️ 예전에는 꺼진 채로 시작해서, 메모가 5개 넘어야 뜨는 배너를 눌러야 켜졌다.
    ///    그 사이 화면은 '전체' 한 장뿐 - 탭도 스와이프도 없어서 **이 앱에 카테고리가
    ///    있다는 사실 자체를 알 수 없었다.** 켠 뒤에야 보이는 기능은 없는 기능과 같다.
    ///
    /// ⚠️ 다만 **직접 끈 사람의 선택은 존중한다.** 저장된 값이 있으면 그대로 따르고,
    ///    값이 아예 없을 때(= 아직 고른 적 없음)만 켜진 것으로 본다.
    private func loadFeatureEnabledState() {
        let defaults = AppGroup.defaults
        if let stored = defaults?.object(forKey: featureEnabledKey) as? Bool {
            isFeatureEnabled = stored
        } else {
            isFeatureEnabled = true
            // 값을 **적어 둔다.** 키보드 익스텐션은 이 키를 직접 읽어서(앱 코드를 못 본다)
            // 안 적어 두면 앱에는 탭이 보이고 키보드에는 안 보이는 어긋남이 생긴다.
            defaults?.set(true, forKey: featureEnabledKey)
        }
    }

    // MARK: - Persona

    /// 사용자가 온보딩에서 선택한 페르소나. nil이면 미선택.
    var selectedPersona: Persona? {
        get {
            guard let raw = AppGroup.defaults?.string(forKey: personaKey) else {
                return nil
            }
            return Persona(rawValue: raw)
        }
    }

    /// 페르소나 선택을 저장한다. (카테고리는 기본 제공하지 않으므로 시드하지 않음
    /// 사용자가 직접 카테고리를 만들어 쓴다. persona 값은 제안/연습 등 다른 기능에서 사용.)
    func applyPersona(_ persona: Persona, language: String? = nil) {
        AppGroup.defaults?.set(persona.rawValue, forKey: personaKey)
        print("👤 [CategoryStore] 페르소나 선택 저장: \(persona.rawValue)")
    }

    // MARK: - Public API

    /// 사용자가 보는 전체 카테고리 목록 - 순서대로.
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

    /// 보호 카테고리 - 삭제 불가.
    static let protectedCategories: Set<String> = ["기본", "텍스트", "이미지"]

    // MARK: - Visibility (표시/숨김 토글)
    // 메인 리스트·키보드 탭에 노출할지 여부. ClipKeyboardListViewModel과 동일한 키 사용.

    private let hiddenTabsKey = "hiddenCategoryTabs_v1"

    /// 카테고리가 탭으로 표시되는지(숨김 집합에 없으면 표시).
    func isVisible(_ name: String) -> Bool {
        let hidden = AppGroup.defaults?.stringArray(forKey: hiddenTabsKey) ?? []
        return !hidden.contains(name)
    }

    /// 카테고리 표시/숨김 설정.
    func setVisible(_ name: String, _ visible: Bool) {
        guard let defaults = AppGroup.defaults else { return }
        var hidden = Set(defaults.stringArray(forKey: hiddenTabsKey) ?? [])
        if visible { hidden.remove(name) } else { hidden.insert(name) }
        defaults.set(Array(hidden), forKey: hiddenTabsKey)
    }

    /// 카테고리 추가 후 표시 토글을 OFF(숨김)로 둔다 - 페르소나 변경 등으로 자동 추가될 때
    /// 사용자가 카테고리 관리에서 직접 켜기 전까지 탭을 어지럽히지 않도록.
    @discardableResult
    func addHidden(_ name: String) -> Bool {
        let added = add(name)
        if added { setVisible(name, false) }
        return added
    }

    // MARK: - Color (카테고리 색 편집)
    // 미지정 시 호출부(ClipKeyboardList)가 팔레트 인덱스로 결정. 지정 시 이 값 우선.

    private let categoryColorsKey = "userCategoryColors_v1"

    /// 사용자가 지정한 카테고리 색(hex). 미지정이면 nil.
    func colorHex(for name: String) -> String? {
        (AppGroup.defaults?.dictionary(forKey: categoryColorsKey) as? [String: String])?[name]
    }

    /// 카테고리 색 지정/해제. nil이면 기본 팔레트로 되돌린다.
    func setColorHex(_ hex: String?, for name: String) {
        guard let defaults = AppGroup.defaults else { return }
        var map = (defaults.dictionary(forKey: categoryColorsKey) as? [String: String]) ?? [:]
        if let hex { map[name] = hex } else { map.removeValue(forKey: name) }
        defaults.set(map, forKey: categoryColorsKey)
    }

    // MARK: - Storage

    /// 외부(예: CategorySettings.onAppear)에서 디스크 최신값으로 다시 읽기.
    /// 키보드 컨텍스트 메뉴 등 다른 경로가 같은 키를 갱신했을 수 있으므로.
    func reload() {
        load()
    }

    private func load() {
        guard let defaults = AppGroup.defaults else {
            categories = []
            return
        }
        // v4.2: 두 카테고리 키(레거시 user.categories.v1 + 키보드 userDefinedCategories_v1) 통일.
        migrateUnifyIfNeeded(defaults)

        if let stored = defaults.stringArray(forKey: storageKey), !stored.isEmpty {
            // 레거시 시드가 남긴 보호 버킷 이름("기본"/"텍스트"/"이미지")은 사용자 카테고리가 아니다
            // 전용 탭이 따로 있어 중복 노출되고, 영어 UI에도 한글 raw 문자열("기본" 칩)이 그대로
            // 보이므로 목록에서 걸러내고 저장본도 정리한다. (메모의 category 값은 건드리지 않음)
            let sanitized = stored.filter { !Self.protectedCategories.contains($0) }
            if sanitized.count != stored.count {
                defaults.set(sanitized, forKey: storageKey)
                print("🔄 [CategoryStore] 레거시 보호 카테고리 이름 정리: \(stored.count - sanitized.count)개 제거")
            }
            categories = sanitized
        } else {
            // 기본 제공 카테고리 없음 - 사용자가 직접 만들어 쓴다.
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
        guard let defaults = AppGroup.defaults else { return }
        defaults.set(categories, forKey: storageKey)
    }
}
