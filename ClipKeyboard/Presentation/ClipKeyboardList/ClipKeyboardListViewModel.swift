//
//  ClipKeyboardListViewModel.swift
//  ClipKeyboard
//

import SwiftUI
import LocalAuthentication

// MARK: - ClipKeyboardListViewModel

@MainActor
final class ClipKeyboardListViewModel: ObservableObject {

    // MARK: - Data State

    @Published var tokenMemos: [Memo] = []
    @Published var loadedData: [Memo] = []

    // MARK: - Search & Filter

    @Published var searchQueryString = ""
    @Published var selectedTypeFilter: ClipboardItemType? = nil
    @Published var selectedCategoryFilter: String? = nil

    // MARK: - Clipboard Shortcut Sheet

    @Published var keyword: String = ""
    @Published var value: String = ""
    @Published var clipboardDetectedType: ClipboardItemType = .text
    @Published var clipboardConfidence: Double = 0.0
    @Published var showShortcutSheet: Bool = false

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

    // MARK: - Toast

    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""

    // MARK: - UI

    @Published var showFavoriteNudge: Bool = false

    // MARK: - Private

    private let selectedFilterKey = "selectedTypeFilter"
    private var isFirstVisit = true

    // MARK: - onAppear

    func onAppear() {
        print("🎬 [ClipKeyboardListViewModel] onAppear 시작")
        loadSavedFilter()
        migrateExistingMemosClassification()

        #if os(iOS)
        print("📋 [ClipKeyboardListViewModel] 클립보드 확인 중...")
        let clipboardString = UIPasteboard.general.string
        let hasClipboard = !(clipboardString?.isEmpty ?? true)
        print("📋 [ClipKeyboardListViewModel] 클립보드 내용 있음: \(hasClipboard), isFirstVisit: \(isFirstVisit)")

        if hasClipboard, isFirstVisit {
            print("🎯 [ClipKeyboardListViewModel] 클립보드 바로가기 시트 표시 예약")
            value = clipboardString ?? ""
            let classification = ClipboardClassificationService.shared.classify(content: value)
            clipboardDetectedType = classification.type
            clipboardConfidence = classification.confidence
            print("🔍 [ClipKeyboardListViewModel] 자동 분류: \(classification.type.rawValue) (신뢰도: \(Int(classification.confidence * 100))%)")

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.showShortcutSheet = true
            }
            isFirstVisit = false
        }
        #endif

        FavoriteNudgeManager.shared.resetIfNeeded()
        if FavoriteNudgeManager.shared.shouldShowNudge {
            print("💝 [ClipKeyboardListViewModel] 즐겨찾기 넛지 표시")
            showFavoriteNudge = true
            FavoriteNudgeManager.shared.recordNudgeShown()
        }

        print("✅ [ClipKeyboardListViewModel] onAppear 완료")
    }

    // MARK: - Data Loading

    func loadMemos() {
        do {
            print("📂 [loadMemos] 메모 로드 시작...")
            let loadedMemos = try MemoStore.shared.load(type: .tokenMemo)
            print("📊 [loadMemos] 로드된 메모 개수: \(loadedMemos.count)")
            tokenMemos = sortMemos(loadedMemos)
            loadedData = tokenMemos
            print("✅ [loadMemos] 메모 로드 완료")
            applyFilters()
        } catch {
            print("❌ [loadMemos] 메모 로드 실패: \(error.localizedDescription)")
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

        if let typeFilter = selectedTypeFilter {
            let beforeCount = filtered.count
            filtered = filtered.filter { $0.category == typeFilter.rawValue }
            print("🔍 [applyFilters] 테마 필터 '\(typeFilter.rawValue)' 적용 - \(beforeCount)개 → \(filtered.count)개")

            if filtered.isEmpty && !loadedData.isEmpty && searchQueryString.isEmpty {
                print("⚠️ [applyFilters] 필터 결과 0개 - 필터 자동 해제")
                selectedTypeFilter = nil
                filtered = loadedData
                saveSelectedFilter()
            }
        }

        tokenMemos = filtered
        print("✅ [applyFilters] 완료 - tokenMemos: \(tokenMemos.count)개")
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
                try MemoStore.shared.save(memos: loadedData, type: .tokenMemo)
                applyFilters()
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }

    func deleteMemo(at offsets: IndexSet) {
        let deletedIds = offsets.map { tokenMemos[$0].id }
        loadedData.removeAll { memo in deletedIds.contains(memo.id) }

        do {
            try MemoStore.shared.save(memos: loadedData, type: .tokenMemo)
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

    func confirmTemplateInput() {
        guard let memo = currentTemplateMemo else { return }
        let processedValue = processTemplateWithInputs(in: memo.value, inputs: templateInputs)
        finalizeCopy(memo: memo, processedValue: processedValue)
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

            let allMemos = try MemoStore.shared.load(type: .tokenMemo)
            loadedData = sortMemos(allMemos)
            applyFilters()
        } catch {
            print("❌ [finalizeCopy] 오류: \(error)")
        }

        let message = memo.contentType == .image
            ? NSLocalizedString("이미지", comment: "Image")
            : processedValue
        showToastMessage(message)
    }

    // MARK: - Toast

    func showToastMessage(_ message: String) {
        toastMessage = String(format: NSLocalizedString("[%@] 이 복사되었습니다.", comment: "Copied toast message"), message)
        showToast = true
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

    // MARK: - Sorting

    func sortMemos(_ memos: [Memo]) -> [Memo] {
        memos.sorted { memo1, memo2 in
            if memo1.isFavorite != memo2.isFavorite {
                return memo1.isFavorite && !memo2.isFavorite
            } else {
                // 편집 이후에 '사용'만 일어난 경우에도 상단으로 올라오도록
                // lastUsedAt과 lastEdited 중 늦은 시점을 기준으로 정렬한다.
                let r1 = max(memo1.lastUsedAt ?? .distantPast, memo1.lastEdited)
                let r2 = max(memo2.lastUsedAt ?? .distantPast, memo2.lastEdited)
                return r1 > r2
            }
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
            var memos = try MemoStore.shared.load(type: .tokenMemo)
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
                try MemoStore.shared.save(memos: memos, type: .tokenMemo)
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

        print("📋 [processMemoAfterAuth] 일반 메모 - 바로 복사")
        finalizeCopy(memo: memo, processedValue: memo.value)
    }

    private func processTemplateVariables(in text: String) -> String {
        var result = text
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "yyyy-MM-dd"
        result = result.replacingOccurrences(of: "{날짜}", with: dateFormatter.string(from: Date()))

        dateFormatter.dateFormat = "HH:mm:ss"
        result = result.replacingOccurrences(of: "{시간}", with: dateFormatter.string(from: Date()))

        result = result.replacingOccurrences(of: "{연도}", with: String(Calendar.current.component(.year, from: Date())))
        result = result.replacingOccurrences(of: "{월}", with: String(Calendar.current.component(.month, from: Date())))
        result = result.replacingOccurrences(of: "{일}", with: String(Calendar.current.component(.day, from: Date())))

        return result
    }
}
