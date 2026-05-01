//
//  MemoAddViewModel.swift
//  ClipKeyboard
//

import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - MemoAddViewModel

@MainActor
final class MemoAddViewModel: ObservableObject {

    // MARK: - Dependencies

    private let saveMemoUseCase: SaveMemoUseCase
    private let memoRepository: MemoRepositoryProtocol

    // MARK: - Editing Context

    /// 편집 대상 메모 — onAppear(memoId:)에서 repository 조회 후 할당.
    /// init 시점에는 nil이고, 편집 모드면 onAppear에서 채워진다.
    private(set) var editingMemo: Memo?

    // MARK: - Input Fields (@Published)

    @Published var keyword: String = ""
    @Published var value: String = ""
    @Published var selectedCategory: String = "텍스트"
    @Published var isSecure: Bool = false
    @Published var isTemplate: Bool = false
    @Published var isCombo: Bool = false
    @Published var comboValues: [String] = []
    @Published var newComboValue: String = ""

    // MARK: - Template Placeholder 관련

    @Published var detectedPlaceholders: [String] = []
    @Published var placeholderValues: [String: [String]] = [:]
    @Published var showingPlaceholderEditor: String? = nil
    @Published var newPlaceholderValue: String = ""

    // MARK: - 자동 분류 관련

    @Published var autoDetectedType: ClipboardItemType? = nil
    @Published var autoDetectedConfidence: Double = 0.0

    // MARK: - 최근 사용 카테고리

    @Published var recentlyUsedCategories: [String] = []

    // MARK: - 클립보드 스마트 제안

    @Published var clipboardContent: String? = nil
    @Published var clipboardDetectedType: ClipboardItemType? = nil
    @Published var clipboardHistory: SmartClipboardHistory? = nil
    @Published var showClipboardSuggestion: Bool = false

    // MARK: - UI 상태

    @Published var showAlert: Bool = false
    @Published var showEmojiPicker: Bool = false
    @Published var showDocumentScanner: Bool = false
    @Published var showImagePicker: Bool = false
    @Published var isProcessingOCR: Bool = false
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    @Published var showPaywall: Bool = false
    @Published var paywallTrigger: ProFeatureManager.LimitType? = nil

    // MARK: - 이미지 첨부

    @Published var attachedImages: [ImageWrapper] = []

    // MARK: - Alert 메시지 (계산 프로퍼티)

    var alertMessage: String {
        if keyword.isEmpty {
            return NSLocalizedString("제목을 입력하세요", comment: "Alert: title required")
        }
        if isCombo {
            return NSLocalizedString("Combo 값을 최소 1개 이상 추가하세요", comment: "Alert: combo value required")
        }
        return NSLocalizedString("내용을 입력하세요", comment: "Alert: content required")
    }

    // MARK: - Init

    init(
        saveMemoUseCase: SaveMemoUseCase,
        memoRepository: MemoRepositoryProtocol,
        editingMemo: Memo? = nil
    ) {
        self.saveMemoUseCase = saveMemoUseCase
        self.memoRepository = memoRepository
        self.editingMemo = editingMemo
    }

    // MARK: - 카테고리 선택

    func selectCategory(_ theme: String) {
        selectedCategory = theme
        updateRecentlyUsedCategories(theme)
    }

    // MARK: - onAppear 초기화

    func onAppear(
        memoId: UUID? = nil,
        insertedKeyword: String = "",
        insertedValue: String = "",
        insertedCategory: String = "텍스트",
        insertedIsTemplate: Bool = false,
        insertedIsSecure: Bool = false,
        insertedIsCombo: Bool = false,
        insertedComboValues: [String] = []
    ) {
        // 편집 대상 메모 해석 — memoId 있으면 repository에서 조회해 editingMemo 설정.
        // 이게 없으면 saveMemo가 "수정"이 아닌 "새 메모"로 처리하여 원본이 안 지워짐.
        if editingMemo == nil, let id = memoId,
           let resolved = (try? memoRepository.fetchAll())?.first(where: { $0.id == id }) {
            editingMemo = resolved
        }

        // 새 메모 생성 시 클립보드 내용 확인
        if editingMemo == nil && insertedValue.isEmpty {
            checkClipboardAndSuggest()
        }

        // 수정 모드 초기화
        if !insertedKeyword.isEmpty {
            keyword = insertedKeyword
        }

        if !insertedValue.isEmpty {
            value = insertedValue

            // 클립보드에서 온 새로운 메모인 경우 자동 분류 수행
            if editingMemo == nil || insertedCategory == "텍스트" {
                let classification = ClipboardClassificationService.shared.classify(content: insertedValue)
                autoDetectedType = classification.type
                autoDetectedConfidence = classification.confidence

                // 자동으로 테마 설정
                let suggestedCategory = Constants.categoryForClipboardType(classification.type)
                selectedCategory = suggestedCategory

                // 민감한 정보는 자동으로 보안 모드
                let sensitiveTypes: [ClipboardItemType] = [.creditCard, .bankAccount, .passportNumber, .taxID]
                isSecure = sensitiveTypes.contains(classification.type)

                print("🔍 [MemoAddViewModel] 자동 분류: \(classification.type.rawValue) → 테마: \(suggestedCategory)")
            }
        } else {
            selectedCategory = insertedCategory
        }

        isTemplate = insertedIsTemplate
        isCombo = insertedIsCombo
        comboValues = insertedComboValues

        if !insertedIsSecure && autoDetectedType == nil {
            isSecure = insertedIsSecure
        }

        // 초기 플레이스홀더 감지 및 로드
        detectPlaceholders()
        loadPlaceholderValues()

        // 최근 사용 카테고리 로드
        recentlyUsedCategories = UserDefaults.standard.stringArray(forKey: "recentlyUsedCategories") ?? []
    }

    // MARK: - 초기화 (리셋)

    func reset() {
        keyword = ""
        value = ""
        selectedCategory = "텍스트"
        isSecure = false
        isTemplate = false
        isCombo = false
        comboValues = []
        newComboValue = ""
        print("🔄 [MemoAddViewModel] 폼 초기화 완료")
    }

    // MARK: - 저장

    func saveMemo(dismiss: @escaping () -> Void) {
        guard validateMemoInput() else { return }
        guard checkProLimitsForNewMemo() else { return }

        do {
            var loadedMemos = try memoRepository.fetchAll()
            let imageFileNames = try saveAttachedImages()
            let finalCategory = determineFinalCategory()
            updateRecentlyUsedCategories(finalCategory)

            let isNewMemo = editingMemo == nil

            let (finalMemoId, finalMemoTitle) = try applyMemoToList(
                &loadedMemos,
                imageFileNames: imageFileNames,
                finalCategory: finalCategory
            )

            try memoRepository.save(loadedMemos)
            savePlaceholderValues(memoId: finalMemoId, memoTitle: finalMemoTitle)

            // Analytics — 새 메모일 때만 (수정은 제외)
            if isNewMemo {
                let memoType: String
                if isCombo { memoType = "combo" }
                else if isTemplate { memoType = "template" }
                else if !imageFileNames.isEmpty && !value.isEmpty { memoType = "mixed" }
                else if !imageFileNames.isEmpty { memoType = "image" }
                else { memoType = "text" }
                AnalyticsService.logMemoCreated(memoType: memoType, memoCount: loadedMemos.count)
            }

            showToastMessage(NSLocalizedString("저장됨", comment: "Saved toast"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { dismiss() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                ReviewManager.shared.requestReviewIfAppropriate()
            }
            print("✅ [MemoAddViewModel] 메모 저장 완료: \(finalMemoTitle)")
        } catch {
            print("❌ [MemoAddViewModel] 저장 실패: \(error)")
        }
    }

    // MARK: - Combo Value 관리

    func addComboValue() {
        let trimmedValue = newComboValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            showToastMessage(NSLocalizedString("값을 입력하세요", comment: "Combo: empty value warning"))
            return
        }

        if comboValues.contains(trimmedValue) {
            showToastMessage(NSLocalizedString("이미 추가된 값입니다", comment: "Combo: duplicate value warning"))
            return
        }

        comboValues.append(trimmedValue)
        newComboValue = ""
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    func removeComboValue(at index: Int) {
        guard comboValues.indices.contains(index) else { return }
        comboValues.remove(at: index)
    }

    func moveComboValues(from source: IndexSet, to destination: Int) {
        comboValues.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Template Placeholder

    func onValueChanged() {
        detectPlaceholders()
    }

    func onIsTemplateChanged() {
        if isTemplate {
            detectPlaceholders()
        } else {
            detectedPlaceholders = []
        }
    }

    // MARK: - 클립보드 제안 수락

    func acceptClipboardSuggestion() {
        guard let content = clipboardContent, let detectedType = clipboardDetectedType else { return }

        if let history = clipboardHistory, history.contentType == ClipboardContentType.image {
            acceptImageClipboardSuggestion(history)
        } else {
            acceptTextClipboardSuggestion(content, detectedType)
        }

        withAnimation(.easeInOut(duration: 0.3)) { showClipboardSuggestion = false }
    }

    func dismissClipboardSuggestion() {
        showClipboardSuggestion = false
    }

    // MARK: - OCR

    #if os(iOS)
    func processOCRImages(_ images: [UIImage]) {
        isProcessingOCR = true
        var allTexts: [String] = []
        let group = DispatchGroup()

        for image in images {
            group.enter()
            OCRService.shared.recognizeText(from: image) { texts in
                allTexts.append(contentsOf: texts)
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            defer { self.isProcessingOCR = false }
            guard !allTexts.isEmpty else {
                print("❌ [OCR] 인식된 텍스트가 없습니다")
                return
            }
            print("✅ [OCR] 인식된 텍스트: \(allTexts)")
            self.applyOCRResult(allTexts)
        }
    }
    #endif

    // MARK: - Toast

    func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.showToast = false
        }
    }

    // MARK: - 최근 사용 카테고리

    func updateRecentlyUsedCategories(_ category: String) {
        var recent = UserDefaults.standard.stringArray(forKey: "recentlyUsedCategories") ?? []
        recent.removeAll { $0 == category }
        recent.insert(category, at: 0)
        recent = Array(recent.prefix(5))
        UserDefaults.standard.set(recent, forKey: "recentlyUsedCategories")
        recentlyUsedCategories = recent
    }

    // MARK: - Private Helpers

    private func validateMemoInput() -> Bool {
        if keyword.isEmpty {
            showAlert = true
            return false
        }
        let hasContent = isCombo ? !comboValues.isEmpty : (!value.isEmpty || !attachedImages.isEmpty)
        if !hasContent {
            showAlert = true
            return false
        }
        return true
    }

    private func checkProLimitsForNewMemo() -> Bool {
        guard editingMemo == nil else { return true }
        do {
            let existingMemos = try memoRepository.fetchAll()
            let templateCount = existingMemos.filter { $0.isTemplate }.count
            let imageMemoCount = existingMemos.filter { !$0.imageFileNames.isEmpty }.count

            if isTemplate && !ProFeatureManager.canAddTemplate(currentCount: templateCount) {
                paywallTrigger = .template
                showPaywall = true
                return false
            }
            if !attachedImages.isEmpty && !ProFeatureManager.canAddImageMemo(currentImageMemoCount: imageMemoCount) {
                paywallTrigger = .imageMemo
                showPaywall = true
                return false
            }
            if !ProFeatureManager.canAddMemo(currentCount: existingMemos.count) {
                paywallTrigger = .memo
                showPaywall = true
                return false
            }
        } catch {
            // 로드 실패 시 제한 체크 건너뛰기
        }
        return true
    }

    private func saveAttachedImages() throws -> [String] {
        var fileNames: [String] = []
        #if os(iOS)
        for wrapper in attachedImages {
            let fileName = "\(UUID().uuidString).png"
            try MemoStore.shared.saveImage(wrapper.image, fileName: fileName)
            fileNames.append(fileName)
        }
        #endif
        return fileNames
    }

    private func determineFinalCategory() -> String {
        if selectedCategory == "텍스트", let detected = autoDetectedType, detected != .text {
            print("🎨 [MemoAddViewModel] 테마 - 기본값 사용 중 → 자동 분류 적용: '\(detected.rawValue)'")
            return detected.rawValue
        }
        print("🎨 [MemoAddViewModel] 테마 - 사용자 선택 우선: '\(selectedCategory)'")
        return selectedCategory
    }

    private func applyMemoToList(
        _ loadedMemos: inout [Memo],
        imageFileNames: [String],
        finalCategory: String
    ) throws -> (memoId: UUID, memoTitle: String) {
        let variables = extractTemplateVariables(from: value)
        let contentType: ClipboardContentType = {
            if !value.isEmpty && !imageFileNames.isEmpty { return .mixed }
            if !imageFileNames.isEmpty { return .image }
            return .text
        }()

        if let existing = editingMemo,
           let index = loadedMemos.firstIndex(where: { $0.id == existing.id }) {
            var updatedMemo = loadedMemos[index]
            updatedMemo.title = keyword
            updatedMemo.value = value
            updatedMemo.lastEdited = Date()
            updatedMemo.category = finalCategory
            updatedMemo.isSecure = isSecure
            updatedMemo.isTemplate = isTemplate
            updatedMemo.templateVariables = variables
            updatedMemo.placeholderValues = placeholderValues
            updatedMemo.isCombo = isCombo
            updatedMemo.comboValues = comboValues
            updatedMemo.currentComboIndex = 0
            updatedMemo.imageFileNames = imageFileNames
            updatedMemo.contentType = contentType
            loadedMemos[index] = updatedMemo
            return (existing.id, keyword)
        } else {
            if !ProFeatureManager.canAddMemo(currentCount: loadedMemos.count) {
                showPaywall = true
                throw CancellationError()
            }
            let newId = UUID()
            let newMemo = Memo(
                id: newId,
                title: keyword,
                value: value,
                lastEdited: Date(),
                category: finalCategory,
                isSecure: isSecure,
                isTemplate: isTemplate,
                templateVariables: variables,
                placeholderValues: placeholderValues,
                isCombo: isCombo,
                comboValues: comboValues,
                currentComboIndex: 0,
                imageFileNames: imageFileNames,
                contentType: contentType
            )
            loadedMemos.append(newMemo)
            ReviewManager.shared.incrementMemoCreatedCount()
            return (newId, keyword)
        }
    }

    private func savePlaceholderValues(memoId: UUID, memoTitle: String) {
        for (placeholder, values) in placeholderValues where !values.isEmpty {
            for val in values {
                MemoStore.shared.addPlaceholderValue(
                    val,
                    for: placeholder,
                    sourceMemoId: memoId,
                    sourceMemoTitle: memoTitle
                )
            }
        }
    }

    private func detectPlaceholders() {
        let autoVariables = ["{날짜}", "{시간}", "{연도}", "{월}", "{일}"]
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value))
        var placeholders: [String] = []

        for match in matches {
            if let range = Range(match.range, in: value) {
                let placeholder = String(value[range])
                if !autoVariables.contains(placeholder) && !placeholders.contains(placeholder) {
                    placeholders.append(placeholder)
                }
            }
        }

        detectedPlaceholders = placeholders
    }

    private func loadPlaceholderValues() {
        for placeholder in detectedPlaceholders {
            let values = MemoStore.shared.loadPlaceholderValues(for: placeholder)
            placeholderValues[placeholder] = values.map { $0.value }
        }
    }

    private func extractTemplateVariables(from text: String) -> [String] {
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    // MARK: - Clipboard Helpers

    private func checkClipboardAndSuggest() {
        #if os(iOS)
        guard let history = ClipboardClassificationService.shared.checkClipboard() else { return }

        if history.contentType == ClipboardContentType.text {
            guard history.content.count < 500 else { return }
            guard history.content != value else { return }

            if history.detectedType != ClipboardItemType.text || history.confidence > 0.5 {
                clipboardHistory = history
                clipboardContent = history.content
                clipboardDetectedType = history.detectedType

                withAnimation(.easeInOut(duration: 0.3)) {
                    showClipboardSuggestion = true
                }

                print("📋 [MemoAddViewModel] 클립보드 텍스트 감지: \(history.detectedType.rawValue)")
            }
        } else if history.contentType == ClipboardContentType.image {
            clipboardHistory = history
            clipboardContent = history.content
            clipboardDetectedType = ClipboardItemType.text

            withAnimation(.easeInOut(duration: 0.3)) {
                showClipboardSuggestion = true
            }

            print("📋 [MemoAddViewModel] 클립보드 이미지 감지: \(history.content)")
        }
        #endif
    }

    private func acceptImageClipboardSuggestion(_ history: SmartClipboardHistory) {
        #if os(iOS)
        if let image = UIPasteboard.general.image {
            withAnimation { attachedImages = [ImageWrapper(image: image)] }
            print("✅ [MemoAddViewModel] 클립보드에서 이미지를 가져왔습니다")
        }
        #endif
        selectedCategory = "이미지"
        autoDetectedType = .image
        autoDetectedConfidence = 1.0
        persistImageHistory(history)
    }

    private func persistImageHistory(_ history: SmartClipboardHistory) {
        var permanentHistory = history
        permanentHistory.isTemporary = false
        var existingHistory = (try? MemoStore.shared.loadSmartClipboardHistory()) ?? []
        existingHistory.insert(permanentHistory, at: 0)
        if existingHistory.count > 100 { existingHistory = Array(existingHistory.prefix(100)) }
        do {
            try MemoStore.shared.saveSmartClipboardHistory(history: existingHistory)
            print("✅ [MemoAddViewModel] 이미지를 클립보드 히스토리에 저장했습니다")
        } catch {
            print("❌ [MemoAddViewModel] 이미지 저장 실패: \(error)")
        }
    }

    private func acceptTextClipboardSuggestion(_ content: String, _ detectedType: ClipboardItemType) {
        value = content
        selectedCategory = Constants.themeForClipboardType(detectedType)
        autoDetectedType = detectedType
        autoDetectedConfidence = ClipboardClassificationService.shared.classify(content: content).confidence
        let sensitiveTypes: [ClipboardItemType] = [.creditCard, .bankAccount, .passportNumber, .taxID]
        isSecure = sensitiveTypes.contains(detectedType)
        print("✅ [MemoAddViewModel] 클립보드 내용 적용: \(detectedType.rawValue)")
    }

    // MARK: - OCR Private Helpers

    #if os(iOS)
    private func applyOCRResult(_ texts: [String]) {
        guard let categoryType = ClipboardItemType(rawValue: selectedCategory) else {
            value = texts.joined(separator: "\n")
            return
        }
        switch categoryType {
        case .creditCard:
            applyOCRCreditCardResult(texts)
        case .address:
            let address = OCRService.shared.parseAddress(from: texts)
            if !address.isEmpty {
                value = address
                print("🏠 [OCR] 주소 인식: \(address)")
            }
        default:
            value = texts.joined(separator: "\n")
        }
    }

    private func applyOCRCreditCardResult(_ texts: [String]) {
        let cardInfo = OCRService.shared.parseCardInfo(from: texts)
        if let cardNumber = cardInfo["카드번호"] {
            value = cardNumber
            print("💳 [OCR] 카드번호 인식: \(cardNumber)")
        }
        if let expiryDate = cardInfo["유효기간"] {
            print("📅 [OCR] 유효기간 인식: \(expiryDate)")
        }
    }
    #endif
}
