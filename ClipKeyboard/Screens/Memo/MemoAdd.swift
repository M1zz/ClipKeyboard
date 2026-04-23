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

    // MARK: - ViewModel

    @StateObject private var viewModel = MemoAddViewModel(
        saveMemoUseCase: SaveMemoUseCase(),
        memoRepository: MemoRepository()
    )

    // MARK: - Public Input Properties (backward compatibility)

    var memoId: UUID? = nil // 수정할 메모의 ID
    var insertedKeyword: String = ""
    var insertedValue: String = ""
    var insertedCategory: String = "텍스트"
    var insertedIsTemplate: Bool = false
    var insertedIsSecure: Bool = false
    var insertedIsCombo: Bool = false
    var insertedComboValues: [String] = []

    // MARK: - View-only State

    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // 📋 클립보드 스마트 제안
            if viewModel.showClipboardSuggestion, let content = viewModel.clipboardContent, let detectedType = viewModel.clipboardDetectedType {
                ClipboardSuggestionBanner(
                    content: content,
                    detectedType: detectedType,
                    clipboardHistory: viewModel.clipboardHistory,
                    onAccept: {
                        viewModel.acceptClipboardSuggestion()
                    },
                    onDismiss: {
                        viewModel.showClipboardSuggestion = false
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
                    if viewModel.isCombo {
                        // Combo용 설명 입력
                        comboDescriptionSection
                    } else {
                        // 일반 내용 입력
                        ContentInputSection(
                            value: $viewModel.value,
                            selectedCategory: viewModel.selectedCategory,
                            isFocused: $isFocused,
                            autoDetectedType: $viewModel.autoDetectedType,
                            autoDetectedConfidence: $viewModel.autoDetectedConfidence,
                            attachedImages: $viewModel.attachedImages
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
                        viewModel.reset()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text(NSLocalizedString("초기화", comment: "Reset"))
                        }
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.surfaceAlt)
                        .cornerRadius(theme.radiusMd)
                    }

                    Button {
                        viewModel.saveMemo { dismiss() }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text(NSLocalizedString("저장", comment: "Save"))
                        }
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .cornerRadius(theme.radiusMd)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 48)
            }
            .background(theme.surface)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
            .ignoresSafeArea(.keyboard)
            .zIndex(100)
        }
        .alert(viewModel.alertMessage, isPresented: $viewModel.showAlert) {

        }
        .overlay(
            Group {
                if viewModel.showToast {
                    VStack {
                        Spacer()
                        Text(viewModel.toastMessage)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.bottom, 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: viewModel.showToast)
                }
            }
        )
        .sheet(isPresented: $viewModel.showEmojiPicker) {
            EmojiPicker { selectedEmoji in
                viewModel.value += selectedEmoji
            }
        }
        .paywall(isPresented: $viewModel.showPaywall, triggeredBy: viewModel.paywallTrigger)
        #if os(iOS)
        .sheet(isPresented: $viewModel.showDocumentScanner) {
            DocumentCameraView { result in
                if case .success(let images) = result {
                    viewModel.processOCRImages(images)
                }
            }
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePickerView { image in
                if let image = image {
                    viewModel.processOCRImages([image])
                }
            }
        }
        .overlay {
            if viewModel.isProcessingOCR {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text(NSLocalizedString("텍스트 인식 중...", comment: "Recognizing text"))
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .padding(32)
                    .background(theme.surface)
                    .cornerRadius(16)
                }
            }
        }
        #endif
        .onAppear {
            viewModel.onAppear(
                insertedKeyword: insertedKeyword,
                insertedValue: insertedValue,
                insertedCategory: insertedCategory,
                insertedIsTemplate: insertedIsTemplate,
                insertedIsSecure: insertedIsSecure,
                insertedIsCombo: insertedIsCombo,
                insertedComboValues: insertedComboValues
            )
        }
        .onChange(of: viewModel.value) { _ in
            viewModel.onValueChanged()
        }
        .onChange(of: viewModel.isTemplate) { _ in
            viewModel.onIsTemplateChanged()
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
                if let detectedType = viewModel.autoDetectedType {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text(String(format: NSLocalizedString("자동: %@", comment: "Auto detected type"), detectedType.localizedName))
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.fromName(detectedType.color).opacity(0.2))
                    .foregroundColor(Color.fromName(detectedType.color))
                    .cornerRadius(theme.radiusSm)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Recently Used Section
                    if !viewModel.recentlyUsedCategories.isEmpty {
                        // Recently Used Label
                        Text(NSLocalizedString("최근", comment: "Recent"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(theme.textMuted)
                            .padding(.horizontal, 8)

                        ForEach(viewModel.recentlyUsedCategories, id: \.self) { theme in
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
                        if !viewModel.recentlyUsedCategories.contains(theme) {
                            themePillButton(theme: theme, showStar: false)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color.accentColor.opacity(0.05))
        .cornerRadius(theme.radiusMd)
    }

    // Helper view for theme pill button
    @ViewBuilder
    private func themePillButton(theme categoryString: String, showStar: Bool) -> some View {
        Button {
            viewModel.selectCategory(categoryString)
        } label: {
            HStack(spacing: 4) {
                if showStar {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(viewModel.selectedCategory == categoryString ? .white : .orange)
                }
                Text(Constants.localizedThemeName(categoryString))
                    .font(.callout)
                    .fontWeight(viewModel.selectedCategory == categoryString ? .semibold : .regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(viewModel.selectedCategory == categoryString ? Color.accentColor : theme.surfaceAlt)
            .foregroundColor(viewModel.selectedCategory == categoryString ? .white : .primary)
            .cornerRadius(theme.radiusLg)
        }
    }

    private var titleInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("제목", comment: "Title"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(theme.textMuted)

            TextField("메모 제목을 입력하세요", text: $viewModel.keyword)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(theme.surfaceAlt)
                .cornerRadius(theme.radiusMd)
        }
    }

    private var additionalOptionsSection: some View {
        VStack(spacing: 12) {
            ToggleOptionRow(
                activeIcon: "lock.fill",
                inactiveIcon: "lock",
                title: NSLocalizedString("보안 메모", comment: "Secure memo toggle"),
                description: NSLocalizedString("Face ID로 보호", comment: "Face ID protection description"),
                activeColor: .orange,
                isOn: Binding(
                    get: { viewModel.isSecure },
                    set: { newValue in
                        if newValue && !ProFeatureManager.isBiometricLockAvailable {
                            viewModel.paywallTrigger = .biometricLock
                            viewModel.showPaywall = true
                        } else {
                            viewModel.isSecure = newValue
                        }
                    }
                )
            )

            ToggleOptionRow(
                activeIcon: "doc.text.fill",
                inactiveIcon: "doc.text",
                title: NSLocalizedString("템플릿", comment: "Template toggle"),
                description: NSLocalizedString("재사용 가능한 양식", comment: "Template description"),
                activeColor: .purple,
                isOn: $viewModel.isTemplate
            )

            ToggleOptionRow(
                activeIcon: "square.stack.3d.forward.dottedline.fill",
                inactiveIcon: "square.stack.3d.forward.dottedline",
                title: NSLocalizedString("Combo", comment: "Combo toggle"),
                description: NSLocalizedString("탭마다 다음 값 입력", comment: "Combo description"),
                activeColor: .orange,
                isOn: $viewModel.isCombo
            )
        }
    }

    @ViewBuilder
    private var templateSection: some View {
        if viewModel.isTemplate {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                    Text(NSLocalizedString("템플릿 변수는 {날짜}, {시간}, {이름} 형식으로 작성하세요", comment: "Template variable instruction"))
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("예시", comment: "Example label"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textMuted)

                    Text(NSLocalizedString("안녕하세요 {이름}님, {날짜} {시간}에 미팅이 예정되어 있습니다.", comment: "Template example text"))
                        .font(.caption)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.surfaceAlt)
                        .cornerRadius(theme.radiusSm)
                }
            }
            .padding()

            // 플레이스홀더 값 설정
            if !viewModel.detectedPlaceholders.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(NSLocalizedString("플레이스홀더 값 설정", comment: "Placeholder value settings"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    ForEach(viewModel.detectedPlaceholders, id: \.self) { placeholder in
                        PlaceholderValueEditor(
                            placeholder: placeholder,
                            values: Binding(
                                get: { viewModel.placeholderValues[placeholder] ?? [] },
                                set: { viewModel.placeholderValues[placeholder] = $0 }
                            )
                        )
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(theme.radiusMd)
            }
        }
    }

    @ViewBuilder
    private var comboSection: some View {
        if viewModel.isCombo {
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
                    Text(NSLocalizedString("설명 (선택)", comment: "Description optional"))
                        .font(.callout)
                        .fontWeight(.medium)
                    Text(NSLocalizedString("키보드에서 보여질 설명 문구", comment: "Keyboard description hint"))
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                }
            }
            .padding(.bottom, 4)

            TextEditor(text: $viewModel.value)
                .frame(minHeight: 80)
                .padding(8)
                .background(theme.surfaceAlt)
                .cornerRadius(theme.radiusSm)
                .overlay(
                    Group {
                        if viewModel.value.isEmpty {
                            Text(NSLocalizedString("예: 카드번호를 입력합니다", comment: "Description example"))
                                .foregroundColor(theme.textMuted)
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
                    .foregroundColor(theme.textMuted)
                Text(NSLocalizedString("탭할 때마다 다음 값이 순서대로 입력됩니다", comment: "Combo description"))
                    .font(.caption)
                    .foregroundColor(theme.textMuted)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("예시", comment: "Example"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textMuted)

                Text(NSLocalizedString("카드번호 입력: 1234 → 5678 → 9012 → 3456", comment: "Combo example"))
                    .font(.caption)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surfaceAlt)
                    .cornerRadius(theme.radiusSm)
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
        .cornerRadius(theme.radiusMd)
    }

    private var comboValueHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "list.number")
                .font(.caption)
                .foregroundColor(.orange)
            Text(String(format: NSLocalizedString("Combo 값 설정 (%d개)", comment: "Combo value count"), viewModel.comboValues.count))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    private var comboValueInputField: some View {
        HStack(spacing: 8) {
            TextField("값 입력", text: $viewModel.newComboValue)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit {
                    viewModel.addComboValue()
                }

            Button {
                viewModel.addComboValue()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.newComboValue.isEmpty ? .gray : .orange)
            }
            .disabled(viewModel.newComboValue.isEmpty)
        }
    }

    @ViewBuilder
    private var comboValueList: some View {
        if !viewModel.comboValues.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("순서를 변경하려면 드래그하세요", comment: "Drag to reorder"))
                            .font(.caption2)
                            .foregroundColor(theme.textMuted)
                            .padding(.bottom, 4)

                        ForEach(Array(viewModel.comboValues.enumerated()), id: \.offset) { index, value in
                            HStack {
                                Image(systemName: "line.3.horizontal")
                                    .font(.caption)
                                    .foregroundColor(theme.textFaint)

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
                                        viewModel.removeComboValue(at: index)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.title3)
                                }
                            }
                            .padding(12)
                            .background(theme.surfaceAlt)
                            .cornerRadius(theme.radiusSm)
                        }
                        .onMove { from, to in
                            viewModel.moveComboValues(from: from, to: to)
                        }
                    }
        } else {
            Text(NSLocalizedString("위의 필드에서 값을 추가하세요", comment: "Add value hint"))
                .font(.caption)
                .foregroundColor(.orange)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(theme.radiusSm)
        }
    }

    // 템플릿 변수 버튼
    @ViewBuilder
    private func templateButton(title: String, variable: String) -> some View {
        Button {
            viewModel.value += variable
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(theme.radiusSm)
        }
    }
}

struct MemoAdd_Previews: PreviewProvider {
    static var previews: some View {
        MemoAdd()
    }
}

// MARK: - Toggle Option Row

private struct ToggleOptionRow: View {
    let activeIcon: String
    let inactiveIcon: String
    let title: String
    let description: String
    let activeColor: Color
    @Binding var isOn: Bool

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack {
            Image(systemName: isOn ? activeIcon : inactiveIcon)
                .font(.title3)
                .foregroundColor(isOn ? activeColor : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(theme.textMuted)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(theme.surfaceAlt)
        .cornerRadius(theme.radiusMd)
    }
}

// 플레이스홀더 값 편집기
struct PlaceholderValueEditor: View {
    let placeholder: String
    @Binding var values: [String]
    @Environment(\.appTheme) private var theme
    @State private var newValue: String = ""
    @State private var isAdding: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(placeholder.strippingTemplateBraces)
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
                            .cornerRadius(theme.radiusMd)
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
                        Text(NSLocalizedString("추가", comment: "Add"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(newValue.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(theme.radiusSm)
                    }
                    .disabled(newValue.isEmpty)
                }
            }
        }
        .padding()
        .background(theme.surface)
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

    @Environment(\.appTheme) private var theme

    @State private var showImagePicker = false
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(NSLocalizedString("내용", comment: "Content"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.textMuted)

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
                                Text(NSLocalizedString("붙여넣기", comment: "Paste"))
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
                                Text(NSLocalizedString("사진", comment: "Photo"))
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
                            .cornerRadius(theme.radiusMd)
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
                                    Text(NSLocalizedString("이미지 변경", comment: "Change image"))
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(theme.radiusSm)
                            }

                            Button {
                                withAnimation {
                                    attachedImages.removeAll()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text(NSLocalizedString("이미지 제거", comment: "Remove image"))
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(theme.radiusSm)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                } else {
                    // 이미지가 선택되지 않았을 때 - placeholder (탭 시 갤러리 열기)
                    Button {
                        showImagePicker = true
                    } label: {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))

                            Text(NSLocalizedString("이미지를 선택하세요", comment: "Select an image"))
                                .font(.headline)
                                .foregroundColor(theme.textMuted)

                            Text(NSLocalizedString("탭하여 사진 선택", comment: "Tap to select photo"))
                                .font(.caption)
                                .foregroundColor(.blue.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .background(theme.surfaceAlt)
                        .cornerRadius(theme.radiusMd)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        )
                    }
                    .buttonStyle(.plain)
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
                        .background(theme.surfaceAlt)
                        .cornerRadius(theme.radiusMd)
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
                        .cornerRadius(theme.radiusSm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
                Spacer()
            }
            .animation(.easeInOut, value: showToast)
        )
    }

    private func pasteImageFromClipboard() {
        #if os(iOS)
        guard UIPasteboard.general.hasImages else {
            showToastMessage(NSLocalizedString("클립보드에 이미지가 없습니다", comment: ""))
            return
        }

        let image = UIPasteboard.general.image
            ?? UIPasteboard.general.data(forPasteboardType: "public.png").flatMap(UIImage.init)
            ?? UIPasteboard.general.data(forPasteboardType: "public.jpeg").flatMap(UIImage.init)

        if let image {
            withAnimation { attachedImages.append(ImageWrapper(image: image)) }
            showToastMessage(NSLocalizedString("이미지를 추가했습니다", comment: ""))
        } else {
            showToastMessage(NSLocalizedString("이미지 형식을 지원하지 않습니다", comment: ""))
        }
        #endif
    }

    // 이미지 클립보드에 복사
    private func copyImageToClipboard(_ image: UIImage) {
        #if os(iOS)
        UIPasteboard.general.image = image
        showToastMessage(NSLocalizedString("이미지를 복사했습니다", comment: ""))
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

    @Environment(\.appTheme) private var theme

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
                                .foregroundColor(Color.fromName(detectedType.color))

                            Text(detectedType.localizedName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(Color.fromName(detectedType.color))
                        }
                    }

                    Text(previewText)
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
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
                            Text(NSLocalizedString("사용", comment: "Use"))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(theme.radiusSm)
                    }

                    Button {
                        onDismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.caption)
                            Text(NSLocalizedString("무시", comment: "Ignore"))
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(theme.surfaceAlt)
                        .foregroundColor(theme.textMuted)
                        .cornerRadius(theme.radiusSm)
                    }
                }
            }
            .padding(16)
            .background(theme.surface)

            Divider()
        }
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    private var previewText: String {
        content.count > 40 ? String(content.prefix(40)) + "..." : content
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
    @Environment(\.appTheme) private var theme
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
                .background(theme.surface)

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

    @Environment(\.appTheme) private var theme
    @State private var isPressed = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 이미지
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipped()
                .cornerRadius(theme.radiusSm)
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

// MARK: - String Helper

private extension String {
    var strippingTemplateBraces: String {
        replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
    }
}
