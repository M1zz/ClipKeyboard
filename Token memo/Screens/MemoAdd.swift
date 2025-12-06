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

struct MemoAdd: View {

    @State private var keyword: String = ""
    @State private var value: String = ""
    @State private var showAlert: Bool = false
    @State private var showSucessAlert: Bool = false

    // 수정 모드용 초기값
    var memoId: UUID? = nil // 수정할 메모의 ID
    var insertedKeyword: String = ""
    var insertedValue: String = ""
    var insertedCategory: String = "텍스트"
    var insertedIsTemplate: Bool = false
    var insertedIsSecure: Bool = false

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

    @Environment(\.dismiss) private var dismiss
    
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
                    // 📌 1단계: 테마 선택 (가장 먼저!)
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
                                    Text("자동: \(detectedType.rawValue)")
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
                                ForEach(Constants.themes, id: \.self) { theme in
                                    Button {
                                        selectedCategory = theme
                                    } label: {
                                        Text(theme)
                                            .font(.callout)
                                            .fontWeight(selectedCategory == theme ? .semibold : .regular)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(selectedCategory == theme ? Color.accentColor : Color(.systemGray6))
                                            .foregroundColor(selectedCategory == theme ? .white : .primary)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.accentColor.opacity(0.05))
                    .cornerRadius(12)

                    // 📌 2단계: 제목 입력
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

                    // 📌 3단계: 내용 입력 (테마별 맞춤형)
                    ContentInputSection(
                        value: $value,
                        selectedCategory: selectedCategory,
                        isFocused: $isFocused,
                        autoDetectedType: $autoDetectedType,
                        autoDetectedConfidence: $autoDetectedConfidence
                    )
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            // OCR 스캔 버튼
                            #if os(iOS)
                            Menu {
                                Button {
                                    isFocused = false
                                    showDocumentScanner = true
                                } label: {
                                    Label("문서 스캔", systemImage: "doc.text.viewfinder")
                                }

                                Button {
                                    isFocused = false
                                    showImagePicker = true
                                } label: {
                                    Label("사진에서 텍스트 인식", systemImage: "photo")
                                }
                            } label: {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 20))
                            }
                            #endif

                            // 이모지 버튼
                            Button {
                                isFocused = false
                                showEmojiPicker = true
                            } label: {
                                Image(systemName: "face.smiling")
                                    .font(.system(size: 20))
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    // 템플릿 변수 버튼들
                                    templateButton(title: "날짜", variable: "{날짜}")
                                    templateButton(title: "시간", variable: "{시간}")
                                    templateButton(title: "이름", variable: "{이름}")
                                    templateButton(title: "주소", variable: "{주소}")
                                    templateButton(title: "전화", variable: "{전화}")
                                }
                            }

                            Spacer()

                            // 완료 버튼
                            Button {
                                isFocused = false
                            } label: {
                                Text("완료")
                                    .fontWeight(.semibold)
                            }
                        }
                    }

                    // 📌 4단계: 추가 옵션
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: isSecure ? "lock.fill" : "lock")
                                .font(.title3)
                                .foregroundColor(isSecure ? .orange : .secondary)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("보안 메모")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                Text("Face ID로 보호")
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
                                Text("템플릿")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                Text("재사용 가능한 양식")
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
                    }

                    if isTemplate {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("템플릿 변수는 {날짜}, {시간}, {이름} 형식으로 작성하세요")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("예시")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                Text("안녕하세요 {이름}님, {날짜} {시간}에 미팅이 예정되어 있습니다.")
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
                            .background(Color(.systemGray6).opacity(0.5))
                            .cornerRadius(12)
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
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("초기화")
                        }
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    Button {
                        if !keyword.isEmpty,
                           !value.isEmpty {
                            showSucessAlert = true
                            // success
                            // save
                            do {
                                var loadedMemos:[Memo] = []
                                loadedMemos = try MemoStore.shared.load(type: .tokenMemo)

                                // 템플릿 변수 추출
                                let variables = extractTemplateVariables(from: value)

                                let finalMemoId: UUID
                                let finalMemoTitle: String

                                if let existingId = memoId,
                                   let index = loadedMemos.firstIndex(where: { $0.id == existingId }) {
                                    // 기존 메모 업데이트
                                    var updatedMemo = loadedMemos[index]
                                    updatedMemo.title = keyword
                                    updatedMemo.value = value
                                    updatedMemo.lastEdited = Date()
                                    updatedMemo.category = selectedCategory
                                    updatedMemo.isSecure = isSecure
                                    updatedMemo.isTemplate = isTemplate
                                    updatedMemo.templateVariables = variables
                                    updatedMemo.placeholderValues = placeholderValues

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
                                        category: selectedCategory,
                                        isSecure: isSecure,
                                        isTemplate: isTemplate,
                                        templateVariables: variables,
                                        placeholderValues: placeholderValues
                                    )
                                    loadedMemos.append(newMemo)
                                    finalMemoId = newMemoId
                                    finalMemoTitle = keyword
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
                            } catch {
                                fatalError(error.localizedDescription)
                            }
                        } else {
                            showAlert = true
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
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .background(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
        }
        .alert(Constants.insertContents, isPresented: $showAlert) {
            
        }
        .alert("Completed!", isPresented: $showSucessAlert) {
            Button("Ok", role: .cancel) {
                dismiss()
            }
        }
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
                    let sensitiveTypes: [ClipboardItemType] = [.creditCard, .bankAccount, .passportNumber, .rrn]
                    isSecure = sensitiveTypes.contains(classification.type)

                    print("🔍 [MemoAdd] 자동 분류: \(classification.type.rawValue) → 테마: \(suggestedCategory)")
                }
            } else {
                // 기존 설정 사용
                selectedCategory = insertedCategory
            }

            isTemplate = insertedIsTemplate
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
            if selectedCategory == "카드번호" {
                let cardInfo = OCRService.shared.parseCardInfo(from: allTexts)

                if let cardNumber = cardInfo["카드번호"] {
                    value = cardNumber
                    print("💳 [OCR] 카드번호 인식: \(cardNumber)")
                }

                if let expiryDate = cardInfo["유효기간"] {
                    // 유효기간은 메모나 추가 필드에 넣을 수 있음
                    print("📅 [OCR] 유효기간 인식: \(expiryDate)")
                }
            } else if selectedCategory == "주소" {
                let address = OCRService.shared.parseAddress(from: allTexts)
                if !address.isEmpty {
                    value = address
                    print("🏠 [OCR] 주소 인식: \(address)")
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

        // 이미지인 경우 클립보드 히스토리에 영구 저장
        if let history = clipboardHistory, history.contentType == ClipboardContentType.image {
            var permanentHistory = history
            permanentHistory.isTemporary = false

            // 클립보드 히스토리 저장
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
        let sensitiveTypes: [ClipboardItemType] = [.creditCard, .bankAccount, .passportNumber, .rrn]
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("내용")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                // 테마별 힌트
                Text(placeholderText)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }

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

    private var placeholderText: String {
        switch selectedCategory {
        case "이메일": return "example@email.com"
        case "전화번호": return "010-1234-5678"
        case "주소": return "서울시 강남구 테헤란로 123"
        case "URL": return "https://example.com"
        case "카드번호": return "1234-5678-9012-3456"
        case "계좌번호": return "123-456789-12-345"
        case "여권번호": return "M12345678"
        case "통관부호": return "P123456789012"
        case "우편번호": return "12345"
        case "이름": return "홍길동"
        case "생년월일": return "1990-01-01"
        case "주민등록번호": return "900101-1234567"
        case "사업자등록번호": return "123-45-67890"
        case "차량번호": return "12가1234"
        case "IP주소": return "192.168.0.1"
        default: return "내용을 입력하세요"
        }
    }

    private var keyboardTypeForTheme: UIKeyboardType {
        switch selectedCategory {
        case "이메일": return .emailAddress
        case "전화번호", "카드번호", "계좌번호", "우편번호", "주민등록번호", "사업자등록번호": return .numberPad
        case "IP주소": return .decimalPad
        case "URL": return .URL
        case "생년월일": return .numberPad
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

                            Text(detectedType.rawValue)
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
                Text(category.rawValue)
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
