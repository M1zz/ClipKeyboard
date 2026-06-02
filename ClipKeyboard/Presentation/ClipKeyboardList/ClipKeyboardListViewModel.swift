//
//  ClipKeyboardListViewModel.swift
//  ClipKeyboard
//

import SwiftUI
import LocalAuthentication
import TipKit
#if os(iOS)
import UIKit
#endif

// MARK: - CategoryTab

enum CategoryTab: Hashable, Equatable {
    case all
    case favorites
    case custom(String)

    var displayName: String {
        switch self {
        case .all:       return NSLocalizedString("전체", comment: "Category tab: all")
        case .favorites: return NSLocalizedString("즐겨찾기", comment: "Category tab: favorites")
        case .custom(let name): return name
        }
    }

    var icon: String {
        switch self {
        case .all:       return "square.grid.2x2"
        case .favorites: return "heart.fill"
        case .custom:    return "folder.fill"
        }
    }

    var isBuiltIn: Bool {
        if case .custom = self { return false }
        return true
    }
}

// MARK: - ClipKeyboardListViewModel

@MainActor
final class ClipKeyboardListViewModel: ObservableObject {

    // MARK: - Data State

    @Published var memos: [Memo] = []
    @Published var loadedData: [Memo] = []

    // MARK: - Search & Filter

    @Published var searchQueryString = ""
    @Published var selectedTypeFilter: ClipboardItemType? = nil
    @Published var selectedCategoryFilter: String? = nil
    @Published var showFavoritesFilter: Bool = false

    // MARK: - Category Tabs

    @Published var selectedCategoryTab: CategoryTab = .all
    @Published var customCategories: [String] = []
    /// 탭 바에서 숨길 카테고리 이름 집합. 즐겨찾기는 "__favorites__" 키 사용.
    @Published var hiddenCategoryTabs: Set<String> = []

    var allCategoryTabs: [CategoryTab] {
        var tabs: [CategoryTab] = [.all]
        // 즐겨찾기는 기본 제공 카테고리 — 메모 유무와 무관하게 항상 노출 (사용자가 숨기지 않는 한)
        if !hiddenCategoryTabs.contains("__favorites__") {
            tabs.append(.favorites)
        }
        // 사용자 카테고리는 해당 카테고리에 속한 메모가 1개 이상일 때만 탭 노출
        for cat in customCategories
        where !hiddenCategoryTabs.contains(cat)
              && loadedData.contains(where: { $0.category == cat }) {
            tabs.append(.custom(cat))
        }
        return tabs
    }

    var selectedCategoryIndex: Int {
        allCategoryTabs.firstIndex(of: selectedCategoryTab) ?? 0
    }

    func selectCategoryTab(_ tab: CategoryTab) {
        withAnimation(.easeInOut(duration: 0.22)) { selectedCategoryTab = tab }
    }

    func navigateToNextCategory() {
        let tabs = allCategoryTabs
        selectCategoryTab(tabs[(selectedCategoryIndex + 1) % tabs.count])
    }

    func navigateToPreviousCategory() {
        let tabs = allCategoryTabs
        let count = tabs.count
        selectCategoryTab(tabs[(selectedCategoryIndex - 1 + count) % count])
    }

    func memosForCurrentTab() -> [Memo] {
        memos(for: selectedCategoryTab)
    }

    func memos(for tab: CategoryTab) -> [Memo] {
        switch tab {
        case .all:
            return memos
        case .favorites:
            // 타입 필터와 무관하게 전체 데이터에서 즐겨찾기 추출.
            // 타입 필터가 켜져 있어도 즐겨찾기한 메모는 항상 표시.
            let base = searchQueryString.isEmpty ? loadedData : loadedData.filter {
                $0.title.localizedStandardContains(searchQueryString)
            }
            return base.filter { $0.isFavorite }
        case .custom(let name):
            // 마찬가지로 타입 필터 무관하게 카테고리 기반으로만 필터.
            let base = searchQueryString.isEmpty ? loadedData : loadedData.filter {
                $0.title.localizedStandardContains(searchQueryString)
            }
            return base.filter { $0.category == name }
        }
    }

    func addCustomCategory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !customCategories.contains(trimmed) else { return }
        customCategories.append(trimmed)
        saveCustomCategories()
    }

    func deleteCustomCategory(_ name: String) {
        customCategories.removeAll { $0 == name }
        if case .custom(let cur) = selectedCategoryTab, cur == name {
            selectedCategoryTab = .all
        }
        saveCustomCategories()
    }

    // MARK: - Smart Category Suggestion

    /// 제안을 띄울 최소 메모 수.
    static let categorySuggestionThreshold = 3

    /// 메모를 보고 만들 만한 카테고리를 제안한다.
    /// 자동 분류로 `category` 값은 이미 붙어 있으나 아직 사용자 카테고리 목록엔 없는 그룹 중
    /// 가장 큰 것을 고른다(임계치 이상). 메모는 이미 그 값을 가지므로 카테고리를 추가하기만
    /// 하면 곧바로 해당 탭에 모인다. (저장값은 rawValue, 표시는 호출부에서 현지화)
    var suggestedCategory: (name: String, count: Int)? {
        let excluded: Set<String> = ["기본", "텍스트", "이미지", ""]
        var counts: [String: Int] = [:]
        for memo in loadedData {
            let c = memo.category
            guard !excluded.contains(c), !customCategories.contains(c) else { continue }
            counts[c, default: 0] += 1
        }
        guard let best = counts.max(by: { $0.value < $1.value }),
              best.value >= Self.categorySuggestionThreshold else { return nil }
        return (best.key, best.value)
    }

    /// 제안 수락 — 카테고리를 추가하고 해당 탭으로 이동.
    /// 메모는 이미 분류돼 있어 추가 즉시 그 탭에 모인다.
    func acceptSuggestedCategory(_ name: String) {
        addCustomCategory(name)
        selectCategoryTab(.custom(name))
    }

    func moveMemo(_ memo: Memo, toCategory category: String) {
        guard let idx = loadedData.firstIndex(where: { $0.id == memo.id }) else { return }
        loadedData[idx].category = category
        do {
            try MemoStore.shared.save(memos: loadedData, type: .memo)
            applyFilters()
        } catch {
            print("❌ [moveMemo] 저장 실패: \(error)")
        }
    }

    func loadCustomCategories() {
        let ud = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")
        // 카테고리는 기본 제공하지 않음 — 사용자가 직접 만든 목록만 로드.
        customCategories = ud?.stringArray(forKey: "userDefinedCategories_v1") ?? []
        let hidden = ud?.stringArray(forKey: "hiddenCategoryTabs_v1") ?? []
        hiddenCategoryTabs = Set(hidden)
    }

    func saveCustomCategories() {
        UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?
            .set(customCategories, forKey: "userDefinedCategories_v1")
    }

    func setCategoryVisible(_ key: String, visible: Bool) {
        if visible {
            hiddenCategoryTabs.remove(key)
        } else {
            hiddenCategoryTabs.insert(key)
            if key == "__favorites__", case .favorites = selectedCategoryTab {
                selectedCategoryTab = .all
            } else if case .custom(let cur) = selectedCategoryTab, cur == key {
                selectedCategoryTab = .all
            }
        }
        UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?
            .set(Array(hiddenCategoryTabs), forKey: "hiddenCategoryTabs_v1")
    }

    func isCategoryVisible(_ key: String) -> Bool {
        !hiddenCategoryTabs.contains(key)
    }

    func reorderCustomCategories(from: IndexSet, to: Int) {
        customCategories.move(fromOffsets: from, toOffset: to)
        saveCustomCategories()
    }

    // MARK: - Clipboard Capture State

    @Published var keyword: String = ""
    @Published var value: String = ""
    @Published var clipboardDetectedType: ClipboardItemType = .text
    @Published var clipboardConfidence: Double = 0.0

    /// 상단 인라인 캡처 카드 노출 여부. onAppear에서 새 클립보드 감지 시 true.
    @Published var hasFreshClipboard: Bool = false

    /// 마지막으로 사용자가 "숨기기"한 클립보드 값. 같은 값이 다시 나타나면 재노출하지 않는다.
    private let lastDismissedClipboardKey = "lastDismissedClipboard"

    // MARK: - Sheet Presentation State

    @Published var showTemplateInputSheet: Bool = false
    @Published var showPlaceholderManagementSheet: Bool = false
    @Published var selectedTemplateIdForSheet: UUID? = nil
    @Published var selectedComboIdForSheet: UUID? = nil
    @Published var showAuthAlert: Bool = false

    // MARK: - Template Input

    @Published var templatePlaceholders: [String] = []
    @Published var templateInputs: [String: String] = [:]
    @Published var currentTemplateMemo: Memo? = nil
    /// v4.0.8: attachedTemplate 흐름에서 본 메모 (계좌번호 등). nil이면 일반 템플릿 흐름.
    /// 본 메모 + 입력값 치환된 템플릿을 줄바꿈으로 결합해 출력.
    @Published var attachedTemplateBaseMemo: Memo? = nil

    // MARK: - Toast

    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""

    // MARK: - UI

    @Published var showFavoriteNudge: Bool = false

    // MARK: - Activation Card (첫 붙여넣기 유도)

    @Published var showActivationCard: Bool = false
    @Published var showTemplateHint: Bool = false
    private var lastKnownPasteCount: Int = 0
    private let practicePromptShownKey = "keyboard_practice_prompt_shown_v1"
    private let activationCardSnoozedKey = "activation_card_snoozed_until"
    private let templateHintShownKey = "template_hint_shown_v1"

    // MARK: - Private

    private let selectedFilterKey = "selectedTypeFilter"

    // MARK: - onAppear

    func onAppear() {
        print("🎬 [ClipKeyboardListViewModel] onAppear 시작")
        loadSavedFilter()
        loadCustomCategories()
        migrateExistingMemosClassification()

        checkFreshClipboard()
        checkActivationCard()

        FavoriteNudgeManager.shared.resetIfNeeded()
        if FavoriteNudgeManager.shared.shouldShowNudge {
            print("💝 [ClipKeyboardListViewModel] 즐겨찾기 넛지 표시")
            showFavoriteNudge = true
            FavoriteNudgeManager.shared.recordNudgeShown()
        }

        print("✅ [ClipKeyboardListViewModel] onAppear 완료")
    }

    // MARK: - Scene Resume (앱 포그라운드 복귀 시 호출)

    func onSceneResume() {
        checkFreshClipboard()
        let newCount = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.integer(forKey: "keyboard_paste_count") ?? 0
        if lastKnownPasteCount == 0 && newCount > 0 {
            showActivationCard = false
            showCelebrationToast()
            print("🎉 [ViewModel] 첫 붙여넣기 감지 — 축하 토스트 표시")
        }
        lastKnownPasteCount = newCount
        checkActivationCard()
    }

    private func showCelebrationToast() {
        toastMessage = NSLocalizedString("🎉 첫 붙여넣기 완료! 이제 진짜 ClipKeyboard 사용자예요", comment: "First paste celebration toast")
        showToast = true
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: toastMessage)
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            self?.showToast = false
        }
    }

    // MARK: - Activation Card

    private func checkActivationCard() {
        let pasted = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.integer(forKey: "keyboard_paste_count") ?? 0
        lastKnownPasteCount = pasted
        guard pasted == 0 else {
            showActivationCard = false
            return
        }
        guard UserDefaults.standard.bool(forKey: practicePromptShownKey) else { return }
        if let snoozedUntil = UserDefaults.standard.object(forKey: activationCardSnoozedKey) as? Date,
           snoozedUntil > Date() {
            showActivationCard = false
            return
        }
        showActivationCard = true
    }

    func snoozeActivationCard() {
        UserDefaults.standard.set(Date().addingTimeInterval(24 * 60 * 60), forKey: activationCardSnoozedKey)
        showActivationCard = false
    }

    // MARK: - Template Hint

    func checkTemplateHintIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: templateHintShownKey) else { return }
        guard loadedData.count >= 3 else { return }
        showTemplateHint = true
    }

    func dismissTemplateHint() {
        UserDefaults.standard.set(true, forKey: templateHintShownKey)
        showTemplateHint = false
    }

    // MARK: - Section Helpers (ADHD 친화 섹션 분리)

    /// 고정(즐겨찾기)된 메모
    var pinnedMemos: [Memo] {
        memos.filter { $0.isFavorite }
    }

    /// 최근 사용한 메모 (비고정, lastUsedAt 있는 것 중 상위 3개)
    var recentlyUsedMemos: [Memo] {
        let pinnedIds = Set(pinnedMemos.map { $0.id })
        return memos
            .filter { !$0.isFavorite && !pinnedIds.contains($0.id) && $0.lastUsedAt != nil }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(3)
            .map { $0 }
    }

    /// 고정·최근 사용 제외한 나머지 전체 메모
    var remainingMemos: [Memo] {
        let excludeIds = Set((pinnedMemos + recentlyUsedMemos).map { $0.id })
        return memos.filter { !excludeIds.contains($0.id) }
    }

    // MARK: - Data Loading

    func loadMemos() {
        do {
            print("📂 [loadMemos] 메모 로드 시작...")
            diagnoseMemoStorage()
            let loadedMemos = try MemoStore.shared.load(type: .memo)
            print("📊 [loadMemos] 로드된 메모 개수: \(loadedMemos.count)")
            let noImageCount = loadedMemos.filter { ($0.imageFileNames.first ?? $0.imageFileName ?? "").isEmpty }.count
            print("🖼️ [loadMemos] 이미지 있는 메모: \(loadedMemos.count - noImageCount)개 / 전체: \(loadedMemos.count)개")
            memos = sortMemos(loadedMemos)
            loadedData = memos
            print("✅ [loadMemos] 메모 로드 완료")
            applyFilters()
            checkTemplateHintIfNeeded()
            updateCleanUpTipParameter(memos: loadedMemos)
        } catch {
            print("❌ [loadMemos] 메모 로드 실패: \(error.localizedDescription)")
        }
    }

    private func updateCleanUpTipParameter(memos: [Memo]) {
        let sampleIds = SampleMemoStorage.load()
        let userCount = memos.filter { !sampleIds.contains($0.id) }.count
        CleanUpSamplesTip.userCreatedMemoCount = userCount
    }

    // MARK: - Storage Diagnosis

    private func diagnoseMemoStorage() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo"
        ) else {
            print("🔴 [diagnosis] App Group 컨테이너를 찾을 수 없음")
            return
        }

        // 1. Images 폴더에 실제 파일이 있는지 확인
        let imagesDir = containerURL.appendingPathComponent("Images")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: imagesDir.path) {
            print("🖼️ [diagnosis] Images 폴더 파일 수: \(files.count)")
            for f in files.prefix(10) { print("  └ \(f)") }
        } else {
            print("🖼️ [diagnosis] Images 폴더 없음 또는 비어있음")
        }

        // 2. memos.data JSON에 imageFileName 키가 존재하는지 raw 검색
        let memoFile = containerURL.appendingPathComponent("memos.data")
        if let data = try? Data(contentsOf: memoFile),
           let json = String(data: data, encoding: .utf8) {
            let hasImageField = json.contains("imageFileName")
            let hasImageNamesField = json.contains("imageFileNames")
            print("🖼️ [diagnosis] memos.data 크기: \(data.count) bytes")
            print("🖼️ [diagnosis] JSON에 'imageFileName' 포함: \(hasImageField)")
            print("🖼️ [diagnosis] JSON에 'imageFileNames' 포함: \(hasImageNamesField)")
        } else {
            print("🔴 [diagnosis] memos.data 파일을 읽을 수 없음")
        }
    }

    // MARK: - Filter

    func loadSavedFilter() {
        if let savedFilterRawValue = UserDefaults.standard.string(forKey: selectedFilterKey),
           let savedFilter = ClipboardItemType(rawValue: savedFilterRawValue) {
            selectedTypeFilter = savedFilter
            print("📌 [loadSavedFilter] 저장된 필터 로드: \(savedFilter.rawValue)")
        } else {
            selectedTypeFilter = nil
            print("📌 [loadSavedFilter] 저장된 필터 없음 - 전체 표시")
        }
    }

    func saveSelectedFilter() {
        if let filter = selectedTypeFilter {
            UserDefaults.standard.set(filter.rawValue, forKey: selectedFilterKey)
            print("💾 [saveSelectedFilter] 필터 저장: \(filter.rawValue)")
        } else {
            UserDefaults.standard.removeObject(forKey: selectedFilterKey)
            print("💾 [saveSelectedFilter] 필터 초기화 (전체)")
        }
    }

    func applyFilters() {
        print("🔍 [applyFilters] 시작 - loadedData: \(loadedData.count)개")

        var filtered = loadedData

        if !searchQueryString.isEmpty {
            filtered = filtered.filter { $0.title.localizedStandardContains(searchQueryString) }
            print("🔍 [applyFilters] 검색 후: \(filtered.count)개")
        }

        if showFavoritesFilter {
            filtered = filtered.filter { $0.isFavorite }
            print("🔍 [applyFilters] 즐겨찾기 필터 적용 - \(filtered.count)개")
        } else if let typeFilter = selectedTypeFilter {
            let beforeCount = filtered.count
            // resolvedType 기반 필터링: 이미지/자동분류된 타입까지 정확히 반영
            filtered = filtered.filter {
                ClipboardClassificationService.shared.resolvedType(for: $0) == typeFilter
            }
            print("🔍 [applyFilters] 타입 필터 '\(typeFilter.rawValue)' 적용 - \(beforeCount)개 → \(filtered.count)개")

            if filtered.isEmpty && !loadedData.isEmpty && searchQueryString.isEmpty {
                print("⚠️ [applyFilters] 필터 결과 0개 - 필터 자동 해제")
                selectedTypeFilter = nil
                filtered = loadedData
                saveSelectedFilter()
            }
        }

        memos = filtered
        print("✅ [applyFilters] 완료 - memos: \(memos.count)개")
    }

    // MARK: - Memo Actions

    func toggleFavorite(memoId: UUID) {
        guard let index = loadedData.firstIndex(where: { $0.id == memoId }) else { return }

        withAnimation(.easeInOut) {
            loadedData[index].isFavorite.toggle()

            if loadedData[index].isFavorite {
                showFavoriteNudge = false
            }

            loadedData = sortMemos(loadedData)

            do {
                try MemoStore.shared.save(memos: loadedData, type: .memo)
                applyFilters()
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }

    func deleteMemo(at offsets: IndexSet) {
        let deletedIds = offsets.map { memos[$0].id }
        loadedData.removeAll { memo in deletedIds.contains(memo.id) }

        do {
            try MemoStore.shared.save(memos: loadedData, type: .memo)
            applyFilters()
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    func copyMemo(memo: Memo) {
        print("📝 [copyMemo] 메모 선택됨: \(memo.title), 템플릿: \(memo.isTemplate), 보안: \(memo.isSecure)")

        if memo.isSecure {
            print("🔐 [copyMemo] 보안 메모 - Face ID 인증 요청")
            authenticateWithBiometrics(memo: memo)
            return
        }

        processMemoAfterAuth(memo)
    }

    /// 보안 메모면 복호화한 값을 반환. 평문/비보안은 그대로. 복호화 불가(키 미동기화)면 nil.
    private func usableValue(of memo: Memo) -> String? {
        guard SecureMemoCrypto.isEncrypted(memo.value) else { return memo.value }
        return SecureMemoCrypto.decrypt(memo.value)
    }

    func confirmTemplateInput() {
        guard let memo = currentTemplateMemo else { return }
        guard let memoValue = usableValue(of: memo) else { showAuthAlert = true; return }
        let processedTemplate = processTemplateWithInputs(in: memoValue, inputs: templateInputs)

        if let base = attachedTemplateBaseMemo {
            guard let baseValue = usableValue(of: base) else { showAuthAlert = true; return }
            // v4.0.8 attachedTemplate 흐름: 본 메모 + \n + 치환된 템플릿
            let combined = TemplateVariableProcessor.compose(
                memoValue: baseValue,
                templateBody: processedTemplate,
                templateInputs: [:] // 이미 substituted
            )
            finalizeCopy(memo: base, processedValue: combined)
            attachedTemplateBaseMemo = nil
        } else {
            finalizeCopy(memo: memo, processedValue: processedTemplate)
        }
        showTemplateInputSheet = false
    }

    /// v4.0.8: attachedTemplate 입력 스킵 — 본 메모 단독 출력 (사용자가 시트에서 "템플릿 없이").
    func skipAttachedTemplate() {
        guard let base = attachedTemplateBaseMemo else { return }
        guard let baseValue = usableValue(of: base) else { showAuthAlert = true; return }
        finalizeCopy(memo: base, processedValue: baseValue)
        attachedTemplateBaseMemo = nil
        currentTemplateMemo = nil
        templateInputs = [:]
        showTemplateInputSheet = false
    }

    func finalizeCopy(memo: Memo, processedValue: String) {
        #if os(iOS)
        if memo.contentType == .image || memo.contentType == .mixed {
            if let firstImageFileName = memo.imageFileNames.first,
               let image = MemoStore.shared.loadImage(fileName: firstImageFileName) {
                UIPasteboard.general.image = image
                print("✅ [finalizeCopy] 이미지를 클립보드에 복사: \(firstImageFileName)")

                if !processedValue.isEmpty && memo.contentType == .mixed {
                    UIPasteboard.general.string = processedValue
                }
                // 이미지 메모 탭 시 복사됨 안내 토스트.
                showPlainToast(NSLocalizedString("이미지가 복사되었습니다", comment: "Image copied toast"))
            }
        } else {
            UIPasteboard.general.string = processedValue
        }
        #else
        UIPasteboard.general.string = processedValue
        #endif

        do {
            try MemoStore.shared.incrementClipCount(for: memo.id)

            if memo.contentType != .image {
                try MemoStore.shared.addToSmartClipboardHistory(content: processedValue)
            }

            let allMemos = try MemoStore.shared.load(type: .memo)
            loadedData = sortMemos(allMemos)
            applyFilters()
        } catch {
            print("❌ [finalizeCopy] 오류: \(error)")
        }

        // 첫 복사 시 KeyboardTip 표시 조건 충족
        KeyboardTip.hasCopiedMemo = true

        // 청각 장애 접근성: 시각적 토스트를 놓쳐도 복사 완료를 인지할 수 있도록 success 햅틱
        #if os(iOS)
        HapticManager.shared.success()
        #endif

        let message = memo.contentType == .image
            ? NSLocalizedString("이미지", comment: "Image")
            : processedValue
        showToastMessage(message)
    }

    // MARK: - Toast

    func showToastMessage(_ message: String) {
        showPlainToast(String(format: NSLocalizedString("[%@] 이 복사되었습니다.", comment: "Copied toast message"), message))
    }

    /// 포맷 없이 메시지를 그대로 토스트로 표시(예: 이미지 복사 안내).
    func showPlainToast(_ message: String) {
        toastMessage = message
        showToast = true
        // 시각 장애 접근성: VoiceOver 사용 시 토스트를 볼 수 없으므로 announcement로 알림
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: toastMessage)
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showToast = false
        }
    }

    // MARK: - Template Processing

    func processTemplateWithInputs(in text: String, inputs: [String: String]) -> String {
        var result = text
        for (placeholder, value) in inputs {
            result = result.replacingOccurrences(of: placeholder, with: value)
        }
        return processTemplateVariables(in: result)
    }

    // MARK: - Clipboard Capture Card

    /// 앱 진입 시 클립보드 내용을 분류하고, 이전에 "숨기기"한 값과 다르면 상단 카드를 표시한다.
    func checkFreshClipboard() {
        #if os(iOS)
        guard let clipboardString = UIPasteboard.general.string,
              !clipboardString.isEmpty else {
            hasFreshClipboard = false
            return
        }

        let lastDismissed = UserDefaults.standard.string(forKey: lastDismissedClipboardKey) ?? ""
        if clipboardString == lastDismissed {
            hasFreshClipboard = false
            return
        }

        value = clipboardString
        let classification = ClipboardClassificationService.shared.classify(content: value)
        clipboardDetectedType = classification.type
        clipboardConfidence = classification.confidence
        hasFreshClipboard = true
        print("📋 [checkFreshClipboard] 새 클립보드 감지: \(classification.type.rawValue)")
        #endif
    }

    /// 사용자가 "숨기기"한 경우: 같은 값이 다시 나타나지 않도록 저장하고 카드 닫기.
    func dismissClipboardCapture() {
        UserDefaults.standard.set(value, forKey: lastDismissedClipboardKey)
        hasFreshClipboard = false
    }

    /// 저장 플로우로 진입한 경우: 카드만 닫고 dismissed 기록은 남기지 않는다
    /// (저장 이후 사용자가 다시 보고 싶을 수도 있으므로).
    func markClipboardSaved() {
        hasFreshClipboard = false
    }

    /// 감지 타입 기반 자동 제목(키) 제안. 분류 안 된 텍스트는 본문 첫 줄에서 추출.
    var suggestedClipboardTitle: String {
        if clipboardDetectedType == .text {
            let firstLine = value
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespaces) ?? value
            let snippet = String(firstLine.prefix(20))
            return snippet.isEmpty
                ? NSLocalizedString("메모", comment: "Default memo title")
                : snippet
        }
        return clipboardDetectedType.suggestedMemoTitle
    }

    /// 원탭 저장: 방금 복사한 클립보드를 제안된 제목으로 즉시 메모로 저장한다.
    /// 제목 입력 없이 키보드에서 바로 꺼내 쓸 수 있게 — 이 앱의 핵심 마찰을 제거.
    func saveClipboardAsMemo() {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            hasFreshClipboard = false
            return
        }

        let title = suggestedClipboardTitle
        let memo = Memo(
            title: title,
            value: value,
            autoDetectedType: clipboardDetectedType
        )

        do {
            var memos = try MemoStore.shared.load(type: .memo)
            memos.insert(memo, at: 0)
            try MemoStore.shared.save(memos: memos, type: .memo)
            loadedData = sortMemos(memos)
            applyFilters()
            hasFreshClipboard = false
            // 같은 값이 다시 카드로 뜨지 않도록 기록 (저장했으니 재노출 불필요).
            UserDefaults.standard.set(value, forKey: lastDismissedClipboardKey)
            #if os(iOS)
            HapticManager.shared.success()
            #endif
            showPlainToast(String(format: NSLocalizedString("'%@' 메모로 저장했어요", comment: "Saved clipboard as memo toast"), title))
            print("✅ [saveClipboardAsMemo] '\(title)' 저장 완료")
        } catch {
            print("❌ [saveClipboardAsMemo] 저장 실패: \(error)")
        }
    }

    // MARK: - Sorting

    func sortMemos(_ memos: [Memo]) -> [Memo] {
        memos.sorted { memo1, memo2 in
            if memo1.isFavorite != memo2.isFavorite {
                return memo1.isFavorite && !memo2.isFavorite
            }
            return memo1.lastEdited > memo2.lastEdited
        }
    }

    // MARK: - Migration

    func migrateExistingMemosClassification() {
        let migrationKey = "autoClassificationMigrationCompleted_v1"
        if UserDefaults.standard.bool(forKey: migrationKey) {
            print("ℹ️ [Migration] 이미 마이그레이션 완료됨")
            return
        }

        print("🔄 [Migration] 기존 메모 자동 분류 시작...")

        do {
            var memos = try MemoStore.shared.load(type: .memo)
            var updated = false

            for index in memos.indices {
                if memos[index].autoDetectedType == nil {
                    let classification = ClipboardClassificationService.shared.classify(content: memos[index].value)
                    memos[index].autoDetectedType = classification.type

                    if memos[index].category == "기본" {
                        let suggestedCategory = Constants.categoryForClipboardType(classification.type)
                        memos[index].category = suggestedCategory
                        print("   ✅ [\(memos[index].title)] \(classification.type.rawValue) → \(suggestedCategory)")
                    } else {
                        print("   ℹ️ [\(memos[index].title)] \(classification.type.rawValue) (테마 유지: \(memos[index].category))")
                    }

                    updated = true
                }
            }

            if updated {
                try MemoStore.shared.save(memos: memos, type: .memo)
                loadedData = sortMemos(memos)
                applyFilters()
                print("✅ [Migration] 마이그레이션 완료 및 저장됨")
            } else {
                print("ℹ️ [Migration] 업데이트할 메모 없음")
            }

            UserDefaults.standard.set(true, forKey: migrationKey)
        } catch {
            print("❌ [Migration] 마이그레이션 실패: \(error)")
        }
    }

    // MARK: - Private Helpers

    private func authenticateWithBiometrics(memo: Memo) {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("❌ [authenticateWithBiometrics] 생체 인증 불가: \(error?.localizedDescription ?? "Unknown error")")
            showAuthAlert = true
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: NSLocalizedString("보안 메모에 접근하려면 인증이 필요합니다", comment: "Biometric auth reason")
        ) { [weak self] success, authError in
            DispatchQueue.main.async {
                if success {
                    print("✅ [authenticateWithBiometrics] Face ID 인증 성공")
                    self?.processMemoAfterAuth(memo)
                } else {
                    print("❌ [authenticateWithBiometrics] Face ID 인증 실패: \(authError?.localizedDescription ?? "Unknown error")")
                    self?.showAuthAlert = true
                }
            }
        }
    }

    private func processMemoAfterAuth(_ memo: Memo) {
        if memo.isCombo {
            print("🔁 [processMemoAfterAuth] Combo 메모 - ComboEditSheet 표시")
            selectedComboIdForSheet = memo.id
            return
        }

        if memo.isTemplate {
            print("📄 [processMemoAfterAuth] 템플릿 메모 - TemplateEditSheet 표시")
            selectedTemplateIdForSheet = memo.id
            return
        }

        // v4.0.8: 옵션 템플릿 연결 메모 → 입력 시트 트리거
        if let attachedId = memo.attachedTemplateId,
           let attached = (try? MemoStore.shared.load(type: .memo))?.first(where: { $0.id == attachedId }) {
            print("🔗 [processMemoAfterAuth] attachedTemplate 흐름 — base=\(memo.title), template=\(attached.title)")
            attachedTemplateBaseMemo = memo
            currentTemplateMemo = attached
            // 연결된 템플릿의 사용자 플레이스홀더를 추출해야 입력 필드가 나타난다(누락 시 값 입력 불가).
            templatePlaceholders = TemplateVariableProcessor.extractCustomTokens(in: attached.value)
            templateInputs = [:]
            showTemplateInputSheet = true
            return
        }

        print("📋 [processMemoAfterAuth] 일반 메모 - 바로 복사")
        guard let value = usableValue(of: memo) else { showAuthAlert = true; return }
        finalizeCopy(memo: memo, processedValue: value)
    }

    private func processTemplateVariables(in text: String) -> String {
        TemplateVariableProcessor.process(text)
    }
}
