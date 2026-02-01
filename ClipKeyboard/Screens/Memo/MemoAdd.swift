//
//  MemoAdd.swift
//  Token memo
//
//  Created by hyunho lee on 2023/05/15.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Image Wrapper
struct ImageWrapper: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct MemoAdd: View {

    @State private var keyword: String = ""
    @State private var value: String = ""
    @State private var showAlert: Bool = false
    @State private var attachedImages: [ImageWrapper] = [] // 첨부된 이미지들

    // 수정 모드용 초기값
    var memoId: UUID? = nil // 수정할 메모의 ID
    var insertedKeyword: String = ""
    var insertedValue: String = ""
    var insertedCategory: String = "텍스트"
    var insertedIsTemplate: Bool = false
    var insertedIsSecure: Bool = false
    var insertedIsCombo: Bool = false
    var insertedComboValues: [String] = []

    // 새로운 기능들
    @State private var selectedCategory: String = "텍스트"
    @State private var isSecure: Bool = false
    @State private var isTemplate: Bool = false
    @FocusState private var isFocused: Bool

    // 템플릿 플레이스홀더 값 설정
    @State private var detectedPlaceholders: [String] = []
    @State private var placeholderValues: [String: [String]] = [:]
    @State private var showingPlaceholderEditor: String? = nil
    @State private var newValue: String = ""

    // Combo 기능
    @State private var isCombo: Bool = false
    @State private var comboValues: [String] = []
    @State private var newComboValue: String = ""

    // 자동 분류 관련
    @State private var autoDetectedType: ClipboardItemType? = nil
    @State private var autoDetectedConfidence: Double = 0.0

    // 클립보드 스마트 제안
    @State private var clipboardContent: String? = nil
    @State private var clipboardDetectedType: ClipboardItemType? = nil
    @State private var clipboardHistory: SmartClipboardHistory? = nil
    @State private var showClipboardSuggestion: Bool = false

    // 이모지 피커
    @State private var showEmojiPicker: Bool = false

    // OCR 문서 스캔
    @State private var showDocumentScanner: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var isProcessingOCR: Bool = false

    // Toast 메시지
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    @Environment(\.dismiss) private var dismiss

    // 에러 메시지
    private var alertMessage: String {
        if keyword.isEmpty {
            return "제목을 입력하세요"
        }
        if isCombo {
            return "Combo 값을 최소 1개 이상 추가하세요"
        }
        return "내용을 입력하세요"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 📋 클립보드 스마트 제안
            if showClipboardSuggestion, let content = clipboardContent, let detectedType = clipboardDetectedType {
                ClipboardSuggestionBanner(
                    content: content,
                    detectedType: detectedType,
                    clipboardHistory: clipboardHistory,
                    onAccept: {
                        acceptClipboardSuggestion()
                    },
                    onDismiss: {
                        showClipboardSuggestion = false
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            ScrollView {
                VStack(spacing: 28) {
                    themeSelectionSection
                    titleInputSection

                    // 📌 2단계: 추가 옵션 (보안, 템플릿, Combo)
                    additionalOptionsSection
                    templateSection
                    comboSection

                    // 📌 3단계: 내용 입력
                    if isCombo {
                        // Combo용 설명 입력
                        comboDescriptionSection
                    } else {
                        // 일반 내용 입력
                        ContentInputSection(
                            value: $value,
                            selectedCategory: selectedCategory,
                            isFocused: $isFocused,
                            autoDetectedType: $autoDetectedType,
                            autoDetectedConfidence: $autoDetectedConfidence,
                            attachedImages: $attachedImages
                        )
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {


                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        // 템플릿 변수 버튼들
                                        templateButton(title: NSLocalizedString("날짜", comment: "Date template button"), variable: "{날짜}")
                                        templateButton(title: NSLocalizedString("시간", comment: "Time template button"), variable: "{시간}")
                                        templateButton(title: NSLocalizedString("이름", comment: "Name template button"), variable: "{이름}")
                                        templateButton(title: NSLocalizedString("주소", comment: "Address template button"), variable: "{주소}")
                                        templateButton(title: NSLocalizedString("전화", comment: "Phone template button"), variable: "{전화}")
                                    }
                                }

                                Spacer()

                                // 완료 버튼
                                Button {
                                    isFocused = false
                                } label: {
                                    Text(NSLocalizedString("완료", comment: "Done button"))
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 100)
            }

            // 하단 버튼 영역
            VStack(spacing: 0) {
                Divider()

                HStack(spacing: 12) {
                    Button {
                        keyword = ""
                        value = ""
                        selectedCategory = "텍스트"
                        isSecure = false
                        isTemplate = false
                        isCombo = false
                        comboValues = []
                        newComboValue = ""
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("초기화")
                        }
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    Button {
                        // 유효성 검사
                        if keyword.isEmpty {
                            showAlert = true
                            return
                        }

                        // Combo인 경우 comboValues 확인, 일반인 경우 value 또는 attachedImages 확인
                        let hasContent = isCombo ? !comboValues.isEmpty : (!value.isEmpty || !attachedImages.isEmpty)

                        if !hasContent {
                            showAlert = true
                            return
                        }

                        // save
                        do {
                            var loadedMemos:[Memo] = []
                            loadedMemos = try MemoStore.shared.load(type: .tokenMemo)

                            // 이미지들을 파일로 저장
                            var savedImageFileNames: [String] = []
                            #if os(iOS)
                            for wrapper in attachedImages {
                                let fileName = "\(UUID().uuidString).png"
                                try MemoStore.shared.saveImage(wrapper.image, fileName: fileName)
                                savedImageFileNames.append(fileName)
                            }
                            #endif

                            // 템플릿 변수 추출
                            let variables = extractTemplateVariables(from: value)

                            // 컨텐츠 타입 결정
                            let contentType: ClipboardContentType
                            if !value.isEmpty && !savedImageFileNames.isEmpty {
                                contentType = .mixed
                            } else if !savedImageFileNames.isEmpty {
                                contentType = .image
                            } else {
                                contentType = .text
                            }

                            // 카테고리 결정: 사용자가 선택한 카테고리 우선 사용
                            // 사용자가 기본값(텍스트)을 그대로 두었고 자동 분류 결과가 있으면 자동 분류 사용
                            let finalCategory: String
                            if selectedCategory == "텍스트" && autoDetectedType != nil && autoDetectedType != .text {
                                // 기본값이고 자동 분류가 텍스트가 아니면 자동 분류 사용
                                finalCategory = autoDetectedType!.rawValue
                                print("🎨 [MemoAdd] 테마 - 기본값 사용 중 → 자동 분류 적용: '\(finalCategory)'")
                            } else {
                                // 사용자가 의도적으로 선택한 경우 사용자 선택 우선
                                finalCategory = selectedCategory
                                print("🎨 [MemoAdd] 테마 - 사용자 선택 우선: '\(finalCategory)' (자동 분류: '\(autoDetectedType?.rawValue ?? "없음")')")
                            }

                            // Update recently used categories
                            updateRecentlyUsedCategories(finalCategory)

                            let finalMemoId: UUID
                            let finalMemoTitle: String

                            if let existingId = memoId,
                               let index = loadedMemos.firstIndex(where: { $0.id == existingId }) {
                                // 기존 메모 업데이트
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
                                updatedMemo.imageFileNames = savedImageFileNames
                                updatedMemo.contentType = contentType

                                loadedMemos[index] = updatedMemo
                                finalMemoId = existingId
                                finalMemoTitle = keyword
                            } else {
                                // 새 메모 추가
                                let newMemoId = UUID()
                                let newMemo = Memo(
                                    id: newMemoId,
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
                                    imageFileNames: savedImageFileNames,
                                    contentType: contentType
                                )
                                loadedMemos.append(newMemo)
                                finalMemoId = newMemoId
                                finalMemoTitle = keyword

                                // 새 메모 생성 횟수 증가
                                ReviewManager.shared.incrementMemoCreatedCount()
                            }

                            try MemoStore.shared.save(memos: loadedMemos, type: .tokenMemo)

                            // 플레이스홀더 값들 저장 (출처 정보 포함)
                            for (placeholder, values) in placeholderValues where !values.isEmpty {
                                for value in values {
                                    MemoStore.shared.addPlaceholderValue(
                                        value,
                                        for: placeholder,
                                        sourceMemoId: finalMemoId,
                                        sourceMemoTitle: finalMemoTitle
                                    )
                                }
                            }

                            // 저장 완료 토스트
                            toastMessage = NSLocalizedString("저장됨", comment: "Saved toast")
                            showToast = true

                            // 토스트 표시 후 화면 닫기
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                dismiss()
                            }

                            // 적절한 타이밍에 리뷰 요청
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                ReviewManager.shared.requestReviewIfAppropriate()
                            }
                        } catch {
                            fatalError(error.localizedDescription)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("저장")
                        }
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 48)
            }
            .background(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
            .ignoresSafeArea(.keyboard)
            .zIndex(100)
        }
        .alert(alertMessage, isPresented: $showAlert) {

        }
        .overlay(
            Group {
                if showToast {
                    VStack {
                        Spacer()
                        Text(toastMessage)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.bottom, 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: showToast)
                }
            }
        )
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPicker { selectedEmoji in
                // 선택한 이모지를 value에 추가
                value += selectedEmoji
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showDocumentScanner) {
            DocumentCameraView { result in
                switch result {
                case .success(let images):
                    processOCRImages(images)
                case .failure(let error):
                    print("❌ [OCR] 문서 스캔 실패: \(error)")
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView { image in
                if let image = image {
                    processOCRImages([image])
                }
            }
        }
        .overlay {
            if isProcessingOCR {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text("텍스트 인식 중...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .padding(32)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                }
            }
        }
        #endif
        .onAppear {
            // 📋 새 메모 생성 시 클립보드 내용 확인
            if memoId == nil && insertedValue.isEmpty {
                checkClipboardAndSuggest()
            }

            // 수정 모드 초기화
            if !insertedKeyword.isEmpty {
                keyword = insertedKeyword
            }

            if !insertedValue.isEmpty {
                value = insertedValue

                // 클립보드에서 온 새로운 메모인 경우 자동 분류 수행
                if memoId == nil || insertedCategory == "텍스트" {
                    let classification = ClipboardClassificationService.shared.classify(content: insertedValue)
                    autoDetectedType = classification.type
                    autoDetectedConfidence = classification.confidence

                    // 자동으로 테마 설정
                    let suggestedCategory = Constants.categoryForClipboardType(classification.type)
                    selectedCategory = suggestedCategory

                    // 민감한 정보는 자동으로 보안 모드
                    let sensitiveTypes: [ClipboardItemType] = [.creditCard, .bankAccount, .passportNumber, .taxID]
                    isSecure = sensitiveTypes.contains(classification.type)

                    print("🔍 [MemoAdd] 자동 분류: \(classification.type.rawValue) → 테마: \(suggestedCategory)")
                }
            } else {
                // 기존 설정 사용
                selectedCategory = insertedCategory
            }

            isTemplate = insertedIsTemplate
            isCombo = insertedIsCombo
            comboValues = insertedComboValues

            if !insertedIsSecure && autoDetectedType == nil {
                // 자동 분류로 보안 설정되지 않았으면 기존 설정 사용
                isSecure = insertedIsSecure
            }

            // 초기 플레이스홀더 감지 및 로드
            detectPlaceholders()
            loadPlaceholderValues()
        }
        .onChange(of: value) { _ in
            detectPlaceholders()
        }
        .onChange(of: isTemplate) { _ in
            if isTemplate {
                detectPlaceholders()
            } else {
                detectedPlaceholders = []
            }
        }
    }

    // MARK: - View Sections

    private var themeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("테마 선택", systemImage: "tag.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)

                // 자동 분류 표시
                if let detectedType = autoDetectedType {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text("자동: \(detectedType.localizedName)")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colorFor(detectedType.color).opacity(0.2))
                    .foregroundColor(colorFor(detectedType.color))
                    .cornerRadius(8)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Recently Used Section
                    if !recentlyUsedCategories.isEmpty {
                        // Recently Used Label
                        Text("최근")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)

                        ForEach(recentlyUsedCategories, id: \.self) { theme in
                            themePillButton(theme: theme, showStar: true)
                        }

                        // Divider
                        Divider()
                            .frame(height: 28)
                            .padding(.horizontal, 4)
                    }

                    // All Categories
                    ForEach(Constants.themes, id: \.self) { theme in
                        // Don't show in main list if already in recently used
                        if !recentlyUsedCategories.contains(theme) {
                            themePillButton(theme: theme, showStar: false)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color.accentColor.opacity(0.05))
        .cornerRadius(12)
    }

    // Helper view for theme pill button
    @ViewBuilder
    private func themePillButton(theme: String, showStar: Bool) -> some View {
        Button {
            selectedCategory = theme
            updateRecentlyUsedCategories(theme)
        } label: {
            HStack(spacing: 4) {
                if showStar {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(selectedCategory == theme ? .white : .orange)
                }
                Text(Constants.localizedThemeName(theme))
                    .font(.callout)
                    .fontWeight(selectedCategory == theme ? .semibold : .regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(selectedCategory == theme ? Color.accentColor : Color(.systemGray6))
            .foregroundColor(selectedCategory == theme ? .white : .primary)
            .cornerRadius(20)
        }
    }

    // Get recently used categories (max 5)
    private var recentlyUsedCategories: [String] {
        let recent = UserDefaults.standard.stringArray(forKey: "recentlyUsedCategories") ?? []
        return Array(recent.prefix(5))
    }

    // Update recently used categories
    private func updateRecentlyUsedCategories(_ category: String) {
        var recent = UserDefaults.standard.stringArray(forKey: "recentlyUsedCategories") ?? []

        // Remove if already exists
        recent.removeAll { $0 == category }

        // Add to front
        recent.insert(category, at: 0)

        // Keep only last 5
        recent = Array(recent.prefix(5))

        UserDefaults.standard.set(recent, forKey: "recentlyUsedCategories")
    }

    private var titleInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("제목")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            TextField("메모 제목을 입력하세요", text: $keyword)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }

    private var additionalOptionsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: isSecure ? "lock.fill" : "lock")
                    .font(.title3)
                    .foregroundColor(isSecure ? .orange : .secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("보안 메모", comment: "Secure memo toggle"))
                        .font(.callout)
                        .fontWeight(.medium)
                    Text(NSLocalizedString("Face ID로 보호", comment: "Face ID protection description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $isSecure)
                    .labelsHidden()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)

            HStack {
                Image(systemName: isTemplate ? "doc.text.fill" : "doc.text")
                    .font(.title3)
                    .foregroundColor(isTemplate ? .purple : .secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("템플릿", comment: "Template toggle"))
                        .font(.callout)
                        .fontWeight(.medium)
                    Text(NSLocalizedString("재사용 가능한 양식", comment: "Template description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $isTemplate)
                    .labelsHidden()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)

            HStack {
                Image(systemName: isCombo ? "square.stack.3d.forward.dottedline.fill" : "square.stack.3d.forward.dottedline")
                    .font(.title3)
                    .foregroundColor(isCombo ? .orange : .secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("Combo", comment: "Combo toggle"))
                        .font(.callout)
                        .fontWeight(.medium)
                    Text(NSLocalizedString("탭마다 다음 값 입력", comment: "Combo description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $isCombo)
                    .labelsHidden()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    @ViewBuilder
    private var templateSection: some View {
        if isTemplate {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("템플릿 변수는 {날짜}, {시간}, {이름} 형식으로 작성하세요", comment: "Template variable instruction"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("예시", comment: "Example label"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Text(NSLocalizedString("안녕하세요 {이름}님, {날짜} {시간}에 미팅이 예정되어 있습니다.", comment: "Template example text"))
                        .font(.caption)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            .padding()

            // 플레이스홀더 값 설정
            if !detectedPlaceholders.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("플레이스홀더 값 설정")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    ForEach(detectedPlaceholders, id: \.self) { placeholder in
                        PlaceholderValueEditor(
                            placeholder: placeholder,
                            values: Binding(
                                get: { placeholderValues[placeholder] ?? [] },
                                set: { placeholderValues[placeholder] = $0 }
                            )
                        )
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    @ViewBuilder
    private var comboSection: some View {
        if isCombo {
            comboInfoSection
            comboValueInputSection
        }
    }

    // Combo 설명 입력 섹션
    private var comboDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .font(.title3)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("설명 (선택)")
                        .font(.callout)
                        .fontWeight(.medium)
                    Text("키보드에서 보여질 설명 문구")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 4)

            TextEditor(text: $value)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    Group {
                        if value.isEmpty {
                            Text("예: 카드번호를 입력합니다")
                                .foregroundColor(.secondary)
                                .padding(.leading, 12)
                                .padding(.top, 16)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
        }
        .padding(.horizontal, 20)
    }

    private var comboInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("탭할 때마다 다음 값이 순서대로 입력됩니다")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("예시")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Text("카드번호 입력: 1234 → 5678 → 9012 → 3456")
                    .font(.caption)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .padding()
    }

    private var comboValueInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            comboValueHeader
            comboValueInputField
            comboValueList
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private var comboValueHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "list.number")
                .font(.caption)
                .foregroundColor(.orange)
            Text("Combo 값 설정 (\(comboValues.count)개)")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    private var comboValueInputField: some View {
        HStack(spacing: 8) {
            TextField("값 입력", text: $newComboValue)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit {
                    addComboValue()
                }

            Button {
                addComboValue()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(newComboValue.isEmpty ? .gray : .orange)
            }
            .disabled(newComboValue.isEmpty)
        }
    }

    @ViewBuilder
    private var comboValueList: some View {
        if !comboValues.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("순서를 변경하려면 드래그하세요")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)

                        ForEach(Array(comboValues.enumerated()), id: \.offset) { index, value in
                            HStack {
                                Image(systemName: "line.3.horizontal")
                                    .font(.caption)
                                    .foregroundColor(.gray)

                                Text("\(index + 1).")
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                                    .frame(width: 30, alignment: .leading)

                                Text(value)
                                    .font(.body)

                                Spacer()

                                Button {
                                    withAnimation {
                                        _ = comboValues.remove(at: index)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.title3)
                                }
                            }
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .onMove { from, to in
                            comboValues.move(fromOffsets: from, toOffset: to)
                        }
                    }
        } else {
            Text("위의 필드에서 값을 추가하세요")
                .font(.caption)
                .foregroundColor(.orange)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
        }
    }

    private func addComboValue() {
        // 빈 값 체크
        let trimmedValue = newComboValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            showToastMessage("값을 입력하세요")
            return
        }

        // 중복 체크
        if comboValues.contains(trimmedValue) {
            showToastMessage("이미 추가된 값입니다")
            return
        }

        comboValues.append(trimmedValue)
        newComboValue = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // Toast 메시지 표시
    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }

    // 커스텀 플레이스홀더 감지
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

    // 플레이스홀더 값 로드
    private func loadPlaceholderValues() {
        for placeholder in detectedPlaceholders {
            // 새로운 형식으로 로드
            let values = MemoStore.shared.loadPlaceholderValues(for: placeholder)
            placeholderValues[placeholder] = values.map { $0.value }
        }
    }


    // 템플릿 변수 추출 함수
    private func extractTemplateVariables(from text: String) -> [String] {
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    // 템플릿 변수 버튼
    @ViewBuilder
    private func templateButton(title: String, variable: String) -> some View {
        Button {
            value += variable
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }

    // 색상 헬퍼 함수
    private func colorFor(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "indigo": return .indigo
        case "brown": return .brown
        case "cyan": return .cyan
        case "teal": return .teal
        case "pink": return .pink
        case "mint": return .mint
        default: return .gray
        }
    }

    // MARK: - Clipboard Helper Functions

    /// 클립보드 내용을 확인하고 사용자에게 제안
    private func checkClipboardAndSuggest() {
        #if os(iOS)
        // 새로운 통합 클립보드 체크 사용 (텍스트 + 이미지 지원)
        guard let history = ClipboardClassificationService.shared.checkClipboard() else { return }

        // 텍스트인 경우 추가 검증
        if history.contentType == ClipboardContentType.text {
            guard history.content.count < 500 else { return }
            guard history.content != value else { return }

            // 의미 있는 데이터만 제안
            if history.detectedType != ClipboardItemType.text || history.confidence > 0.5 {
                clipboardHistory = history
                clipboardContent = history.content
                clipboardDetectedType = history.detectedType

                withAnimation(.easeInOut(duration: 0.3)) {
                    showClipboardSuggestion = true
                }

                print("📋 [MemoAdd] 클립보드 텍스트 감지: \(history.detectedType.rawValue)")
            }
        } else if history.contentType == ClipboardContentType.image {
            // 이미지는 항상 제안
            clipboardHistory = history
            clipboardContent = history.content
            clipboardDetectedType = ClipboardItemType.text

            withAnimation(.easeInOut(duration: 0.3)) {
                showClipboardSuggestion = true
            }

            print("📋 [MemoAdd] 클립보드 이미지 감지: \(history.content)")
        }
        #endif
    }

    #if os(iOS)
    /// OCR 이미지 처리
    private func processOCRImages(_ images: [UIImage]) {
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

        group.notify(queue: .main) {
            defer { isProcessingOCR = false }

            guard !allTexts.isEmpty else {
                print("❌ [OCR] 인식된 텍스트가 없습니다")
                return
            }

            print("✅ [OCR] 인식된 텍스트: \(allTexts)")

            // 카테고리에 따라 파싱 및 자동 입력
            if let categoryType = ClipboardItemType(rawValue: selectedCategory) {
                switch categoryType {
                case .creditCard:
                    let cardInfo = OCRService.shared.parseCardInfo(from: allTexts)

                    if let cardNumber = cardInfo["카드번호"] {
                        value = cardNumber
                        print("💳 [OCR] 카드번호 인식: \(cardNumber)")
                    }

                    if let expiryDate = cardInfo["유효기간"] {
                        // 유효기간은 메모나 추가 필드에 넣을 수 있음
                        print("📅 [OCR] 유효기간 인식: \(expiryDate)")
                    }

                case .address:
                    let address = OCRService.shared.parseAddress(from: allTexts)
                    if !address.isEmpty {
                        value = address
                        print("🏠 [OCR] 주소 인식: \(address)")
                    }

                default:
                    // 일반 텍스트로 처리
                    value = allTexts.joined(separator: "\n")
                }
            } else {
                // 일반 텍스트로 처리
                value = allTexts.joined(separator: "\n")
            }
        }
    }
    #endif

    /// 클립보드 제안 수락
    private func acceptClipboardSuggestion() {
        guard let content = clipboardContent, let detectedType = clipboardDetectedType else { return }

        // 이미지인 경우
        if let history = clipboardHistory, history.contentType == ClipboardContentType.image {
            #if os(iOS)
            // 클립보드에서 이미지 가져오기
            if let image = UIPasteboard.general.image {
                withAnimation {
                    attachedImages = [ImageWrapper(image: image)]
                }
                print("✅ [MemoAdd] 클립보드에서 이미지를 가져왔습니다")
            }
            #endif

            // 테마를 이미지로 자동 선택
            selectedCategory = "이미지"

            // 자동 분류 정보 설정
            autoDetectedType = .image
            autoDetectedConfidence = 1.0

            // 클립보드 히스토리에 영구 저장
            var permanentHistory = history
            permanentHistory.isTemporary = false

            var existingHistory = (try? MemoStore.shared.loadSmartClipboardHistory()) ?? []
            existingHistory.insert(permanentHistory, at: 0)

            // 최대 100개 제한
            if existingHistory.count > 100 {
                existingHistory = Array(existingHistory.prefix(100))
            }

            do {
                try MemoStore.shared.saveSmartClipboardHistory(history: existingHistory)
                print("✅ [MemoAdd] 이미지를 클립보드 히스토리에 저장했습니다")
            } catch {
                print("❌ [MemoAdd] 이미지 저장 실패: \(error)")
            }

            // 제안 배너 숨기기
            withAnimation(.easeInOut(duration: 0.3)) {
                showClipboardSuggestion = false
            }

            return
        }

        // 텍스트 내용 채우기
        value = content

        // 테마 자동 선택
        let suggestedTheme = Constants.themeForClipboardType(detectedType)
        selectedCategory = suggestedTheme

        // 자동 분류 정보 설정
        autoDetectedType = detectedType
        autoDetectedConfidence = ClipboardClassificationService.shared.classify(content: content).confidence

        // 민감한 정보는 자동으로 보안 모드
        let sensitiveTypes: [ClipboardItemType] = [.creditCard, .bankAccount, .passportNumber, .taxID]
        isSecure = sensitiveTypes.contains(detectedType)

        // 제안 배너 숨기기
        withAnimation(.easeInOut(duration: 0.3)) {
            showClipboardSuggestion = false
        }

        print("✅ [MemoAdd] 클립보드 내용 적용: \(detectedType.rawValue)")
    }
}

struct MemoAdd_Previews: PreviewProvider {
    static var previews: some View {
        MemoAdd()
    }
}

// 플레이스홀더 값 편집기
struct PlaceholderValueEditor: View {
    let placeholder: String
    @Binding var values: [String]
    @State private var newValue: String = ""
    @State private var isAdding: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(placeholder.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))
                    .font(.callout)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    isAdding.toggle()
                } label: {
                    Image(systemName: isAdding ? "xmark.circle.fill" : "plus.circle.fill")
                        .foregroundColor(isAdding ? .red : .blue)
                }
            }

            // 값 목록
            if !values.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(values, id: \.self) { value in
                            HStack(spacing: 6) {
                                Text(value)
                                    .font(.caption)

                                Button {
                                    values.removeAll { $0 == value }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
            }

            // 값 추가
            if isAdding {
                HStack(spacing: 8) {
                    TextField("값 입력", text: $newValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)

                    Button {
                        if !newValue.isEmpty && !values.contains(newValue) {
                            values.append(newValue)
                            newValue = ""
                            isAdding = false
                        }
                    } label: {
                        Text("추가")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(newValue.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(newValue.isEmpty)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Content Input Section

struct ContentInputSection: View {
    @Binding var value: String
    let selectedCategory: String
    @FocusState.Binding var isFocused: Bool
    @Binding var autoDetectedType: ClipboardItemType?
    @Binding var autoDetectedConfidence: Double
    @Binding var attachedImages: [ImageWrapper]

    @State private var showImagePicker = false
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("내용")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                // 이미지 버튼들 (이미지 테마일 때만 표시)
                if selectedCategory == "이미지" {
                    HStack(spacing: 8) {
                        // 클립보드에서 이미지 붙여넣기
                        Button {
                            pasteImageFromClipboard()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.caption)
                                Text("붙여넣기")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.1))
                            .foregroundColor(.purple)
                            .cornerRadius(6)
                        }

                        // 파일에서 이미지 선택
                        Button {
                            showImagePicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "photo")
                                    .font(.caption)
                                Text("사진")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                        }
                    }
                }
            }

            // 이미지 테마: 이미지 뷰 표시
            if selectedCategory == "이미지" {
                // 이미지가 선택되었을 때
                if let firstImage = attachedImages.first {
                    VStack(spacing: 12) {
                        Image(uiImage: firstImage.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        // 이미지 변경/제거 버튼
                        HStack(spacing: 12) {
                            Button {
                                showImagePicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "photo.badge.plus")
                                    Text("이미지 변경")
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            }

                            Button {
                                withAnimation {
                                    attachedImages.removeAll()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("이미지 제거")
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                } else {
                    // 이미지가 선택되지 않았을 때 - placeholder
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))

                        Text("이미지를 선택하세요")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("위의 버튼을 사용하여\n클립보드에서 붙여넣거나\n사진을 선택할 수 있습니다")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            } else {
                // 텍스트 테마: 텍스트 입력 영역
                ZStack(alignment: .topLeading) {
                    if value.isEmpty {
                        Text(placeholderText)
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                    }

                    TextEditor(text: $value)
                        .font(.body)
                        .frame(minHeight: 150)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .scrollContentBackground(.hidden)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .keyboardType(keyboardTypeForTheme)
                        .focused($isFocused)
                        .onChange(of: value) { newValue in
                            // 자동 분류
                            if !newValue.isEmpty {
                                let classification = ClipboardClassificationService.shared.classify(content: newValue)
                                autoDetectedType = classification.type
                                autoDetectedConfidence = classification.confidence
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView { image in
                if let image = image {
                    withAnimation {
                        attachedImages.append(ImageWrapper(image: image))
                    }
                }
            }
        }
        .overlay(
            // Toast 메시지
            VStack {
                if showToast {
                    Text(toastMessage)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
                Spacer()
            }
            .animation(.easeInOut, value: showToast)
        )
    }

    // 클립보드에서 이미지 붙여넣기
    private func pasteImageFromClipboard() {
        #if os(iOS)
        print("📋 [MemoAdd] 클립보드에서 이미지 붙여넣기 시도")

        // 1. 먼저 hasImages로 확인
        if UIPasteboard.general.hasImages {
            print("   ✅ 클립보드에 이미지 있음")

            // 2. 이미지 가져오기 시도
            if let image = UIPasteboard.general.image {
                print("   ✅ 이미지 가져오기 성공")
                withAnimation {
                    attachedImages.append(ImageWrapper(image: image))
                }
                showToastMessage("이미지를 추가했습니다")
                return
            }

            // 3. 이미지를 가져오지 못했으면 데이터에서 시도
            print("   ⚠️ .image로 가져오기 실패, 데이터에서 시도")
            if let imageData = UIPasteboard.general.data(forPasteboardType: "public.png"),
               let image = UIImage(data: imageData) {
                print("   ✅ PNG 데이터에서 이미지 생성 성공")
                withAnimation {
                    attachedImages.append(ImageWrapper(image: image))
                }
                showToastMessage("이미지를 추가했습니다")
                return
            }

            if let imageData = UIPasteboard.general.data(forPasteboardType: "public.jpeg"),
               let image = UIImage(data: imageData) {
                print("   ✅ JPEG 데이터에서 이미지 생성 성공")
                withAnimation {
                    attachedImages.append(ImageWrapper(image: image))
                }
                showToastMessage("이미지를 추가했습니다")
                return
            }

            print("   ❌ 이미지 데이터 변환 실패")
            showToastMessage("이미지 형식을 지원하지 않습니다")
        } else {
            print("   ❌ 클립보드에 이미지 없음")
            showToastMessage("클립보드에 이미지가 없습니다")
        }
        #endif
    }

    // 이미지 클립보드에 복사
    private func copyImageToClipboard(_ image: UIImage) {
        #if os(iOS)
        UIPasteboard.general.image = image
        showToastMessage("이미지를 복사했습니다")
        #endif
    }

    // Toast 메시지 표시
    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }

    private var placeholderText: String {
        guard let type = ClipboardItemType(rawValue: selectedCategory) else {
            return NSLocalizedString("내용을 입력하세요", comment: "Default placeholder")
        }

        switch type {
        case .email: return "example@email.com"
        case .phone: return "010-1234-5678"
        case .address: return NSLocalizedString("서울시 강남구 테헤란로 123", comment: "Address placeholder")
        case .url: return "https://example.com"
        case .creditCard: return "1234-5678-9012-3456"
        case .bankAccount: return "123-456789-12-345"
        case .passportNumber: return "M12345678"
        case .declarationNumber: return "P123456789012"
        case .postalCode: return "12345"
        case .name: return NSLocalizedString("홍길동", comment: "Name placeholder")
        case .birthDate: return "1990-01-01"
        case .taxID: return "123-45-6789"
        case .insuranceNumber: return "A12345678"
        case .vehiclePlate: return NSLocalizedString("12가1234", comment: "Vehicle plate placeholder")
        case .ipAddress: return "192.168.0.1"
        case .membershipNumber: return "M123456"
        case .trackingNumber: return "1Z999AA10123456784"
        case .confirmationCode: return "ABC123XYZ"
        case .medicalRecord: return "MR-2024-001"
        case .employeeID: return "E12345"
        default: return NSLocalizedString("내용을 입력하세요", comment: "Default placeholder")
        }
    }

    private var keyboardTypeForTheme: UIKeyboardType {
        guard let type = ClipboardItemType(rawValue: selectedCategory) else {
            return .default
        }

        switch type {
        case .email: return .emailAddress
        case .phone, .creditCard, .bankAccount, .postalCode, .taxID, .insuranceNumber: return .numberPad
        case .ipAddress: return .decimalPad
        case .url: return .URL
        case .birthDate: return .numberPad
        default: return .default
        }
    }
}

// MARK: - Clipboard Suggestion Banner

struct ClipboardSuggestionBanner: View {
    let content: String
    let detectedType: ClipboardItemType
    let clipboardHistory: SmartClipboardHistory?
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 이미지 또는 아이콘
                if let history = clipboardHistory,
                   history.contentType == .image,
                   let imageData = history.imageData,
                   let uiImage = UIImage.from(base64: imageData) {
                    // 이미지 썸네일
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipped()
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                        )
                } else {
                    // 텍스트 아이콘
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(10)
                }

                // 내용
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(clipboardHistory?.contentType == .image ? "이미지 감지" : "클립보드 감지")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if clipboardHistory?.contentType != .image {
                            Image(systemName: detectedType.icon)
                                .font(.caption)
                                .foregroundColor(colorFor(detectedType.color))

                            Text(detectedType.localizedName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(colorFor(detectedType.color))
                        }
                    }

                    Text(previewText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // 액션 버튼들
                VStack(spacing: 8) {
                    Button {
                        onAccept()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                            Text("사용")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }

                    Button {
                        onDismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.caption)
                            Text("무시")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .foregroundColor(.secondary)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))

            Divider()
        }
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    private var previewText: String {
        if content.count > 40 {
            return String(content.prefix(40)) + "..."
        }
        return content
    }

    private func colorFor(_ colorName: String) -> Color {
        switch colorName {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "indigo": return .indigo
        case "brown": return .brown
        case "cyan": return .cyan
        case "teal": return .teal
        case "pink": return .pink
        case "mint": return .mint
        case "yellow": return .yellow
        default: return .gray
        }
    }
}

// MARK: - Emoji Picker

enum EmojiCategory: String, CaseIterable {
    case recent = "최근"
    case smileys = "표정"
    case gestures = "손짓"
    case animals = "동물"
    case food = "음식"
    case activities = "활동"
    case symbols = "기호"

    var icon: String {
        switch self {
        case .recent: return "clock.fill"
        case .smileys: return "face.smiling"
        case .gestures: return "hand.raised.fill"
        case .animals: return "pawprint.fill"
        case .food: return "fork.knife"
        case .activities: return "sportscourt.fill"
        case .symbols: return "heart.fill"
        }
    }

    var localizedName: String {
        return NSLocalizedString(self.rawValue, comment: "Emoji category name")
    }

    var emojis: [String] {
        switch self {
        case .recent:
            return UserDefaults.standard.stringArray(forKey: "recentEmojis") ?? []
        case .smileys:
            return ["😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙", "🥲", "😋", "😛", "😜", "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔", "🤐", "🤨", "😐", "😑", "😶", "😏", "😒", "🙄", "😬", "😌", "😔", "😪", "🤤", "😴", "😷", "🤒", "🤕", "🥵", "🥶", "😎", "🤓", "🧐"]
        case .gestures:
            return ["👋", "🤚", "🖐", "✋", "🖖", "👌", "🤌", "🤏", "✌️", "🤞", "🤟", "🤘", "🤙", "👈", "👉", "👆", "👇", "☝️", "👍", "👎", "✊", "👊", "🤛", "🤜", "👏", "🙌", "👐", "🤲", "🤝", "🙏"]
        case .animals:
            return ["🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🙈", "🙉", "🙊", "🐒", "🐔", "🐧", "🐦", "🐤", "🐣", "🐥", "🦆", "🦅", "🦉", "🦇", "🐺", "🐗", "🐴", "🦄", "🐝", "🐛", "🦋", "🐌", "🐞", "🐢", "🐍", "🦎", "🦖", "🦕", "🐙", "🦑", "🦐", "🦞", "🦀", "🐡", "🐠", "🐟", "🐬", "🐳", "🐋", "🦈"]
        case .food:
            return ["🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", "🥒", "🌶", "🌽", "🥕", "🧄", "🧅", "🥔", "🍠", "🥐", "🍞", "🥖", "🥨", "🧀", "🥚", "🍳", "🥞", "🥓", "🍗", "🍖", "🌭", "🍔", "🍟", "🍕", "🥪", "🌮", "🌯", "🥗", "🍝", "🍜", "🍲", "🍛", "🍣", "🍱", "🍤", "🍙", "🍚"]
        case .activities:
            return ["⚽️", "🏀", "🏈", "⚾️", "🎾", "🏐", "🏉", "🎱", "🏓", "🏸", "🏒", "🏑", "🥅", "⛳️", "🏹", "🎣", "🥊", "🥋", "🎽", "🛹", "🛼", "⛸", "🥌", "🎿", "⛷", "🏂", "🤼", "🤸", "⛹️", "🤺", "🤾", "🏌️"]
        case .symbols:
            return ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "☮️", "✝️", "☪️", "🕉", "☸️", "✡️", "🔯", "🕎", "☯️", "⛎", "♈️", "♉️", "♊️", "♋️", "♌️", "♍️", "♎️", "♏️", "♐️", "♑️", "♒️", "♓️", "⚛️", "✴️", "💮"]
        }
    }
}

struct EmojiPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: EmojiCategory = .smileys

    let onEmojiSelected: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(EmojiCategory.allCases, id: \.self) { category in
                            if category == .recent && category.emojis.isEmpty {
                                EmptyView()
                            } else {
                                CategoryTabButton(
                                    category: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedCategory = category
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))

                Divider()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(selectedCategory.emojis, id: \.self) { emoji in
                            Button {
                                selectEmoji(emoji)
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 32))
                            }
                            .buttonStyle(EmojiButtonStyle())
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("이모지 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func selectEmoji(_ emoji: String) {
        var recents = UserDefaults.standard.stringArray(forKey: "recentEmojis") ?? []
        recents.removeAll { $0 == emoji }
        recents.insert(emoji, at: 0)
        if recents.count > 30 {
            recents = Array(recents.prefix(30))
        }
        UserDefaults.standard.set(recents, forKey: "recentEmojis")

        onEmojiSelected(emoji)
        dismiss()
    }
}

struct CategoryTabButton: View {
    let category: EmojiCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.system(size: 20))
                Text(category.localizedName)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .blue : .secondary)
            .frame(width: 60)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct EmojiButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.2 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Document Camera View
#if os(iOS)
import VisionKit

struct DocumentCameraView: UIViewControllerRepresentable {
    let completion: (Result<[UIImage], Error>) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completion: (Result<[UIImage], Error>) -> Void

        init(completion: @escaping (Result<[UIImage], Error>) -> Void) {
            self.completion = completion
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []

            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                images.append(image)
            }

            controller.dismiss(animated: true) {
                self.completion(.success(images))
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) {
                self.completion(.success([]))
            }
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true) {
                self.completion(.failure(error))
            }
        }
    }
}

// MARK: - Image Attachment View
struct ImageAttachmentView: View {
    let image: UIImage
    let onRemove: () -> Void
    let onCopy: () -> Void

    @State private var isPressed = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 이미지
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipped()
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            // 버튼들
            VStack(spacing: 4) {
                // 삭제 버튼
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .background(Circle().fill(Color.red).frame(width: 20, height: 20))
                }

                // 복사 버튼
                Button {
                    onCopy()
                } label: {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .background(Circle().fill(Color.blue).frame(width: 20, height: 20))
                }
            }
            .padding(4)
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Image Picker View
struct ImagePickerView: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (UIImage?) -> Void

        init(completion: @escaping (UIImage?) -> Void) {
            self.completion = completion
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true) {
                self.completion(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                self.completion(nil)
            }
        }
    }
}
#endif
