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

    /// 편집 대상 메모 - onAppear(memoId:)에서 repository 조회 후 할당.
    /// init 시점에는 nil이고, 편집 모드면 onAppear에서 채워진다.
    private(set) var editingMemo: Memo?

    // MARK: - Draft(임시 저장) Context

    /// "임시 저장 보기"에서 이어쓰기로 진입했을 때 그 드래프트 id. 저장/폐기 시 이 드래프트를 정리한다.
    var resumedDraftId: UUID?
    /// "템플릿으로 만들기"의 원본 단축어 id - keepOriginalSource가 꺼져 있으면 저장 시 원본을 함께 삭제한다.
    var templateSourceMemoId: UUID?
    /// 기존(원본) 단축어 남기기 - 기본 ON. 끄면 새 단축어 저장과 같은 쓰기에서 원본이 제거된다.
    @Published var keepOriginalSource: Bool = true
    /// 정식 저장을 커밋했는지 - 저장 후 화면이 닫힐 때 임시저장이 다시 생기지 않게 하는 가드.
    private var didCommitSave = false
    /// 진입 직후(onAppear 완료 시점)의 입력 스냅샷 - 제안 카드/템플릿 프리필을 "사용자 입력"으로
    /// 오인해 드래프트를 만들지 않도록, 여기서 달라졌을 때만 새 드래프트를 생성한다.
    private var initialKeyword = ""
    private var initialValue = ""
    private var initialHint = ""

    // MARK: - Input Fields (@Published)

    @Published var keyword: String = ""
    @Published var value: String = ""
    @Published var hint: String = ""
    /// 힌트를 키보드에서도 표시(제목과 잠시 스왑)할지 - 힌트가 비어있으면 무의미. 기본 ON.
    @Published var hintShownOnKeyboard: Bool = true
    @Published var selectedCategory: String = "텍스트"
    @Published var isSecure: Bool = false
    @Published var isTemplate: Bool = false
    @Published var isFavorite: Bool = false
    /// "이어지는 메모" 단계들(본문 value=1단계, 이 배열=2..N단계). 비어있으면 일반 메모.
    @Published var continuations: [String] = []

    /// 저장용 콤보 단계 = [본문] + 비어있지 않은 이어지는 단계들. 이어지는 단계가 없으면 빈 배열(=일반 메모).
    private var resolvedComboValues: [String] {
        let extra = continuations
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return extra.isEmpty ? [] : ([value] + extra)
    }

    // MARK: - Template Placeholder 관련

    @Published var detectedPlaceholders: [String] = []
    @Published var placeholderValues: [String: [String]] = [:]
    @Published var showingPlaceholderEditor: String?
    @Published var newPlaceholderValue: String = ""

    // MARK: - 자동 분류 관련

    @Published var autoDetectedType: ClipboardItemType?
    @Published var autoDetectedConfidence: Double = 0.0

    // MARK: - 최근 사용 카테고리

    @Published var recentlyUsedCategories: [String] = []

    // MARK: - 클립보드 스마트 제안

    @Published var clipboardContent: String?
    @Published var clipboardDetectedType: ClipboardItemType?
    @Published var clipboardHistory: SmartClipboardHistory?
    @Published var showClipboardSuggestion: Bool = false

    // MARK: - UI 상태

    @Published var showAlert: Bool = false
    @Published var showEmojiPicker: Bool = false
    @Published var showDocumentScanner: Bool = false
    @Published var showImagePicker: Bool = false
    @Published var isProcessingOCR: Bool = false
    /// OCR로 인식된 텍스트 후보들 - 사용자가 값으로 담을 줄을 직접 고른다.
    @Published var ocrCandidates: [String] = []
    @Published var showOCRPicker: Bool = false
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    @Published var showPaywall: Bool = false
    @Published var paywallTrigger: ProFeatureManager.LimitType?

    // MARK: - 이미지 첨부

    @Published var attachedImages: [ImageWrapper] = []

    // MARK: - Alert 메시지 (계산 프로퍼티)

    var alertMessage: String {
        if keyword.isEmpty {
            return NSLocalizedString("제목을 입력하세요", comment: "Alert: title required")
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
        let previousCategory = selectedCategory
        selectedCategory = theme
        updateRecentlyUsedCategories(theme)
        applySampleIfAppropriate(newCategory: theme, previousCategory: previousCategory)
    }

    /// v4.0.8: 백지 부담 줄이기 - 카테고리에 맞는 샘플 자동 채움 (value + keyword).
    /// 1) value/keyword가 비어있거나
    /// 2) 이전 카테고리의 샘플 그대로(=사용자가 수정 안 함)일 때만 갱신.
    /// 사용자가 직접 입력한 값은 절대 덮어쓰지 않는다.
    /// selectCategory + setupView 양쪽에서 호출 (직접 set하는 경로도 자동 채움 trigger).
    private func applySampleIfAppropriate(newCategory: String, previousCategory: String) {
        // 1) 붙여넣을 내용 (value)
        if let sample = Constants.sampleValue(for: newCategory) {
            if value.isEmpty || Constants.isSampleValue(value, forCategory: previousCategory) {
                value = sample
                isSampleValue = true
            }
        }
        // 2) 키보드에 표시할 이름 (keyword) - 카테고리 다국어명을 기본값으로
        if let titleSample = Constants.sampleTitle(for: newCategory) {
            if keyword.isEmpty || Constants.isSampleTitle(keyword, forCategory: previousCategory) {
                keyword = titleSample
            }
        }
    }

    // MARK: - v4.0.8 Sample value tracking

    /// 현재 value가 카테고리 샘플과 동일한지 (= 사용자가 아직 수정 안 함).
    /// View에서 바인딩의 set 콜백에서 갱신해야 사용자 수정 즉시 false로 바뀜.
    @Published var isSampleValue: Bool = false

    /// value 변경 시 호출 - 사용자가 입력하면 isSampleValue를 자동으로 false 처리.
    /// View에서 TextEditor onChange에서 호출.
    func didChangeValue() {
        if isSampleValue && !Constants.isSampleValue(value, forCategory: selectedCategory) {
            isSampleValue = false
        }
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
        insertedComboValues: [String] = [],
        insertedHint: String = "",
        insertedIsFavorite: Bool = false
    ) {
        // 편집 대상 메모 해석 - memoId 있으면 repository에서 조회해 editingMemo 설정.
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

            if insertedCategory != "텍스트" {
                // 명시적 카테고리로 진입(카테고리 추가 카드·템플릿으로 만들기 등)
                // 자동 분류로 덮어쓰지 않고 진입한 카테고리를 그대로 사용.
                selectedCategory = insertedCategory
            } else {
                // 기본 카테고리로 진입한 경우만 자동 분류 수행 (클립보드에서 온 새 메모 등)
                let classification = ClipboardClassificationService.shared.classify(content: insertedValue)
                autoDetectedType = classification.type
                autoDetectedConfidence = classification.confidence

                // 자동으로 테마 설정
                let suggestedCategory = Constants.categoryForClipboardType(classification.type)
                let prev = selectedCategory
                selectedCategory = suggestedCategory
                applySampleIfAppropriate(newCategory: suggestedCategory, previousCategory: prev)

                // 민감한 정보는 자동으로 보안 모드
                let sensitiveTypes: [ClipboardItemType] = [.creditCard, .bankAccount, .passportNumber, .taxID]
                isSecure = sensitiveTypes.contains(classification.type)

                print("🔍 [MemoAddViewModel] 자동 분류: \(classification.type.rawValue) → 테마: \(suggestedCategory)")
            }
        } else {
            let prev = selectedCategory
            selectedCategory = insertedCategory
            // 빈 메모로 진입 시점에도 인접 카테고리에 매핑이 있으면 샘플 자동 채움.
            // insertedCategory가 "텍스트"이면 sampleValue가 없어 자연스럽게 no-op.
            applySampleIfAppropriate(newCategory: insertedCategory, previousCategory: prev)
        }

        // 편집 모드: 기존 메모의 카테고리를 그대로 보존한다.
        // (위 자동 분류 블록이 선택 카테고리를 건드렸을 수 있으므로 여기서 확정적으로 덮어쓴다.
        //  템플릿·콤보·일반 메모 모두 카테고리가 자동 재분류로 사라지지 않게 하는 핵심.)
        if editingMemo != nil {
            selectedCategory = insertedCategory
        }

        isTemplate = insertedIsTemplate
        if editingMemo == nil { isFavorite = insertedIsFavorite }

        // 편집 모드면 기존 메모의 hint + 콤보 단계 로드 (본문=1단계, 나머지=이어지는 단계)
        if let existing = editingMemo {
            hint = existing.hint ?? ""
            hintShownOnKeyboard = existing.hintShownOnKeyboard
            if !existing.comboValues.isEmpty {
                // 보안 콤보면 단계 값이 암호문 - 편집용으로 복호화해 보여준다.
                let steps = SecureMemoCrypto.decryptSteps(existing.comboValues)
                continuations = Array(steps.dropFirst())
                if value.isEmpty { value = steps.first ?? "" }
            }
        } else if !insertedHint.isEmpty {
            hint = insertedHint
        }

        if !insertedIsSecure && autoDetectedType == nil {
            isSecure = insertedIsSecure
        }

        // 보안 메모 편집: 저장된 값이 암호문이면 평문으로 풀어 보여준다.
        // (편집 후 저장 시 SaveMemoUseCase가 다시 암호화)
        if SecureMemoCrypto.isEncrypted(value) {
            value = SecureMemoCrypto.decrypt(value) ?? value
        }

        // 본문에 {변수}가 있으면 템플릿 도우미가 바로 보이도록 진입 시 1회 감지.
        detectPlaceholders()

        // 초기 플레이스홀더 감지 및 로드
        detectPlaceholders()
        loadPlaceholderValues()

        // 최근 사용 카테고리 로드
        recentlyUsedCategories = UserDefaults.standard.stringArray(forKey: DefaultsKey.recentlyUsedCategories) ?? []

        // 드래프트 판정용 진입 스냅샷 - 프리필(제안 카드·샘플·이어쓰기)을 기준선으로 삼아,
        // 이후 사용자가 실제로 고친 경우에만 새 드래프트가 생기게 한다.
        initialKeyword = keyword
        initialValue = value
        initialHint = hint
    }

    // MARK: - 이어지는 메모(콤보 단계)

    func addContinuation() { continuations.append("") }
    func removeContinuation(at index: Int) {
        guard continuations.indices.contains(index) else { return }
        continuations.remove(at: index)
    }

    // MARK: - 초기화 (리셋)

    func reset() {
        keyword = ""
        value = ""
        hint = ""
        hintShownOnKeyboard = true
        selectedCategory = "텍스트"
        isSecure = false
        isTemplate = false
        continuations = []
        print("🔄 [MemoAddViewModel] 폼 초기화 완료")
    }

    // MARK: - Draft (임시 저장)

    /// 저장하지 않고 화면을 떠날 때 호출 - 사용자가 직접 입력한 의미있는 내용이 있으면 자동 임시저장한다.
    /// - 기존 메모 편집 중이거나(editingMemo != nil), 이미 정식 저장했으면(didCommitSave) 대상이 아니다.
    /// - 새 작성: 진입 스냅샷에서 실제로 고쳤고(제안 카드/샘플 프리필 그대로면 제외) 본문이 있을 때만.
    /// - 이어쓰기(resumedDraftId): 내용이 비워졌으면 드래프트 삭제, 아니면 수정 여부와 무관하게 보존/갱신.
    func saveDraftIfNeeded() {
        guard editingMemo == nil, !didCommitSave else { return }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)

        func persistDraft(id: UUID) {
            DraftStore.shared.save(SavedDraft(
                id: id,
                keyword: trimmedKeyword,
                value: value,
                hint: hint,
                category: selectedCategory,
                isSecure: isSecure,
                isFavorite: isFavorite
            ))
        }

        // 이어쓰기로 들어온 드래프트: 비우면 삭제, 아니면 항상 유지(안 고쳤어도 삭제되면 안 됨).
        if let draftId = resumedDraftId {
            if trimmedValue.isEmpty {
                DraftStore.shared.remove(draftId)
            } else {
                persistDraft(id: draftId)
            }
            return
        }

        // 새 작성: 사용자가 진입 후 실제로 입력/수정한 경우에만. (임시저장은 텍스트 기반)
        let edited = value != initialValue || keyword != initialKeyword || hint != initialHint
        guard edited, !trimmedValue.isEmpty, !isSampleValue else { return }
        persistDraft(id: UUID())
    }

    /// 내용의 첫 줄을 최대 20자로 잘라 제목을 자동 생성한다.
    func autoGeneratedTitle() -> String {
        let first = value.components(separatedBy: "\n").first ?? value
        return String(first.trimmingCharacters(in: .whitespaces).prefix(20))
    }

    // MARK: - 저장

    func saveMemo(dismiss: @escaping () -> Void) {
        guard validateMemoInput() else { return }
        guard checkProLimitsForNewMemo() else { return }

        // 손으로 친 한 판이 끝났다. 쓸 만한 표본이면 넘기고, 아니면 조용히 버린다
        // (붙여넣었거나·너무 짧거나·중간에 오래 멈췄으면 표본이 아니다).
        typingRun.commit()
        typingRun = TypingRun(startingWith: value)

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

            // "템플릿으로 만들기" - 기존 단축어 남기기를 끈 경우 같은 쓰기에서 원본을 제거(원자적).
            if !keepOriginalSource, let sourceId = templateSourceMemoId, sourceId != finalMemoId {
                loadedMemos.removeAll { $0.id == sourceId }
            }

            try memoRepository.save(loadedMemos)
            savePlaceholderValues(memoId: finalMemoId, memoTitle: finalMemoTitle)

            // 정식 저장 성공 - 이어쓰던 임시저장이 있으면 정리하고, 종료 시 재-임시저장 방지.
            didCommitSave = true
            if let draftId = resumedDraftId { DraftStore.shared.remove(draftId) }

            // Analytics - 새 메모일 때만 (수정은 제외)
            if isNewMemo {
                let memoType: String
                if isTemplate { memoType = "template" } else if !imageFileNames.isEmpty && !value.isEmpty { memoType = "mixed" } else if !imageFileNames.isEmpty { memoType = "image" } else { memoType = "text" }
                AnalyticsService.logMemoCreated(memoType: memoType, memoCount: loadedMemos.count)
            }

            showToastMessage(NSLocalizedString("저장됨", comment: "Saved toast"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { dismiss() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                ReviewManager.shared.requestReviewIfAppropriate()
            }
            print("✅ [MemoAddViewModel] 메모 저장 완료: \(finalMemoTitle)")
        } catch {
            // 저장 실패 시 화면을 닫지 않는다(작성 내용 보존) - 토스트로 알리고 사용자가 재시도할 수 있게 한다.
            print("❌ [MemoAddViewModel.saveMemo] 메모 저장 실패: \(error)")
            showToastMessage(NSLocalizedString("저장에 실패했습니다. 다시 시도해주세요.", comment: "Memo save failed toast"))
        }
    }

    // MARK: - Template Placeholder

    func onValueChanged() {
        detectPlaceholders()
        // 이 사람이 실제로 얼마나 빨리 치는지 지켜본다. 이 앱에서 "손으로 했다면"을
        // 가정이 아니라 관측으로 말할 수 있는 유일한 자리다(TypingSpeedMeter 참고).
        typingRun.note(value, at: Date())
    }

    /// 값 편집기에서 지금 치고 있는 한 판. 저장할 때 표본으로 넘긴다.
    /// ⚠️ 실패해도 아무 일도 안 일어난다 - 재는 일이 저장을 방해하면 안 된다.
    private var typingRun = TypingRun()

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
            self.isProcessingOCR = false
            let candidates = self.buildOCRCandidates(allTexts)
            guard !candidates.isEmpty else {
                print("❌ [OCR] 인식된 텍스트가 없습니다")
                self.showToastMessage(NSLocalizedString("인식된 텍스트가 없어요", comment: "OCR: no text recognized toast"))
                return
            }
            print("✅ [OCR] 인식된 텍스트 후보 \(candidates.count)개")
            // 자동으로 값에 쏟아붓지 않고 - 사용자가 담을 줄을 직접 고르게 한다.
            self.ocrCandidates = candidates
            self.showOCRPicker = true
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
        var recent = UserDefaults.standard.stringArray(forKey: DefaultsKey.recentlyUsedCategories) ?? []
        recent.removeAll { $0 == category }
        recent.insert(category, at: 0)
        recent = Array(recent.prefix(5))
        UserDefaults.standard.set(recent, forKey: DefaultsKey.recentlyUsedCategories)
        recentlyUsedCategories = recent
    }

    // MARK: - Private Helpers

    private func validateMemoInput() -> Bool {
        if keyword.isEmpty {
            showAlert = true
            return false
        }
        let hasContent = !value.isEmpty || !attachedImages.isEmpty
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
            // 로드 실패 시 제한 체크를 건너뛰고 저장을 허용 (사용자 흐름 차단 방지)
            print("⚠️ [MemoAddViewModel.checkProLimitsForNewMemo] 기존 메모 로드 실패, Pro 제한 체크 건너뜀: \(error)")
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
        // 0) 편집 모드면 기존 카테고리를 그대로 유지(자동 재분류로 덮어쓰지 않음).
        //    신규 메모만 자동 분류 대상. 템플릿/콤보 포함 모든 메모의 카테고리 보존.
        if editingMemo != nil { return selectedCategory }
        // 1) autoDetectedType이 setupView 시점에 채워져 있으면 그대로 사용
        if selectedCategory == "텍스트", let detected = autoDetectedType, detected != .text {
            print("🎨 [MemoAddViewModel] 테마 - 기본값 사용 중 → 자동 분류 적용: '\(detected.rawValue)'")
            return detected.rawValue
        }
        // 2) selectedCategory가 기본값("텍스트")인데 사용자가 value를 직접 입력한 경우
        //    value 변경에 자동 분류가 반응하지 않으므로 저장 시점에 한 번 더 분류 시도.
        //    이게 없으면 메모 카드의 분류 배지(resolvedType)와 저장된 category가 어긋남.
        if selectedCategory == "텍스트", !value.isEmpty {
            let result = ClipboardClassificationService.shared.classify(content: value)
            if result.type != .text && result.confidence >= 0.7 {
                print("🎨 [MemoAddViewModel] 테마 - 저장 시점 재분류 적용: '\(result.type.rawValue)' (신뢰도 \(result.confidence))")
                return result.type.rawValue
            }
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

        // 보안 단축어는 저장 시점에 값·콤보 단계를 암호화한다(편집 화면은 평문으로 다룸).
        // 보안 해제 상태면 남아있을 수 있는 암호문을 평문으로 되돌린다. 모두 idempotent.
        let storedValue: String
        let storedComboValues: [String]
        if isSecure {
            storedValue = SecureMemoCrypto.encrypt(value) ?? value
            storedComboValues = SecureMemoCrypto.encryptSteps(resolvedComboValues)
        } else {
            storedValue = SecureMemoCrypto.isEncrypted(value) ? (SecureMemoCrypto.decrypt(value) ?? value) : value
            storedComboValues = SecureMemoCrypto.decryptSteps(resolvedComboValues)
        }

        if let existing = editingMemo,
           let index = loadedMemos.firstIndex(where: { $0.id == existing.id }) {
            var updatedMemo = loadedMemos[index]
            updatedMemo.title = keyword
            updatedMemo.value = storedValue
            updatedMemo.hint = hint.isEmpty ? nil : hint
            updatedMemo.hintShownOnKeyboard = hintShownOnKeyboard
            updatedMemo.lastEdited = Date()
            updatedMemo.category = finalCategory
            updatedMemo.isSecure = isSecure
            updatedMemo.templateVariables = variables   // isTemplate은 계산형(변수 있으면 자동)
            updatedMemo.comboValues = storedComboValues   // isCombo는 계산형(이어지는 단계 있으면 자동)
            updatedMemo.placeholderValues = placeholderValues
            updatedMemo.imageFileNames = imageFileNames
            updatedMemo.contentType = contentType
            // childMemoIds/comboInterval는 기존 값 보존(콤보 편집은 ComboList에서)
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
                value: storedValue,
                lastEdited: Date(),
                isFavorite: isFavorite,
                category: finalCategory,
                isSecure: isSecure,
                templateVariables: variables,   // isTemplate은 계산형(변수 있으면 자동)
                placeholderValues: placeholderValues,
                comboValues: storedComboValues,
                imageFileNames: imageFileNames,
                contentType: contentType,
                hint: hint.isEmpty ? nil : hint,
                hintShownOnKeyboard: hintShownOnKeyboard
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

    /// ⚠️ 예전에는 자동 변수 목록을 여기에 다섯 개만 따로 적어 두었다. 본진
    ///    (`TemplateVariableProcessor.autoVariableTokens`)이 스무 개 넘게 늘어난 뒤에도
    ///    이 목록은 그대로여서, `{도시}` 같은 자동 변수가 "값을 채워야 하는 칸"으로 잡혔다.
    private func detectPlaceholders() {
        detectedPlaceholders = TemplatePlaceholder.customTokens(in: value)
    }

    private func loadPlaceholderValues() {
        for placeholder in detectedPlaceholders {
            let values = MemoStore.shared.loadPlaceholderValues(for: placeholder)
            placeholderValues[placeholder] = values.map { $0.value }
        }
    }

    private func extractTemplateVariables(from text: String) -> [String] {
        TemplatePlaceholder.names(in: text)
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
        // 카테고리에서 진입했거나 사용자가 이미 고른 카테고리는 유지
        // 기본값("텍스트")일 때만 자동 설정. (determineFinalCategory의 재분류 규칙과 동일)
        if selectedCategory == "텍스트" {
            selectedCategory = "이미지"
        }
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
        // 카테고리에서 진입했거나 사용자가 이미 고른 카테고리는 유지
        // 기본값("텍스트")일 때만 자동 분류로 대체. (determineFinalCategory의 재분류 규칙과 동일)
        if selectedCategory == "텍스트" {
            selectedCategory = Constants.themeForClipboardType(detectedType)
        }
        autoDetectedType = detectedType
        autoDetectedConfidence = ClipboardClassificationService.shared.classify(content: content).confidence
        let sensitiveTypes: [ClipboardItemType] = [.creditCard, .bankAccount, .passportNumber, .taxID]
        isSecure = sensitiveTypes.contains(detectedType)
        print("✅ [MemoAddViewModel] 클립보드 내용 적용: \(detectedType.rawValue)")
    }

    // MARK: - OCR Private Helpers

    #if os(iOS)
    /// 인식 텍스트에서 선택 후보 목록을 만든다.
    /// 카테고리에 맞는 스마트 파싱 결과(카드번호·주소)를 맨 앞 추천으로 올리고,
    /// 이어서 인식된 줄들을 중복 제거해 나열한다.
    private func buildOCRCandidates(_ texts: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        func push(_ s: String) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, !seen.contains(t) else { return }
            seen.insert(t)
            result.append(t)
        }
        // 1) 카테고리 스마트 파싱을 맨 앞 추천으로
        if let categoryType = ClipboardItemType(rawValue: selectedCategory) {
            switch categoryType {
            case .creditCard:
                if let card = OCRService.shared.parseCardInfo(from: texts)["카드번호"] { push(card) }
            case .address:
                push(OCRService.shared.parseAddress(from: texts))
            default:
                break
            }
        }
        // 2) 인식된 줄들
        texts.forEach { push($0) }
        return result
    }

    /// 사용자가 고른 줄(들)을 값에 담는다. 기존 값이 있으면 줄바꿈으로 이어 붙인다.
    func applyOCRSelection(_ lines: [String]) {
        let chosen = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        showOCRPicker = false
        guard !chosen.isEmpty else { return }
        let joined = chosen.joined(separator: "\n")
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            value = joined
        } else {
            value += "\n" + joined
        }
        showToastMessage(NSLocalizedString("값에 담았어요", comment: "OCR: applied selection toast"))
    }
    #endif
}
