//
//  MemoAdd.swift
//  ClipKeyboard
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
    /// v4.0.8: 멀티 필드 focus — 키보드 toolbar "다음" 버튼이 내용 → 제목으로 이동
    @FocusState private var isTitleFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var showNewTemplateSheet = false
    /// v4.0.8: 활용사례 도움 시트 토글
    @State private var showUsageHelperSheet = false

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
                    // 📌 1단계: 카테고리(테마) — 무엇을 저장할지 정의
                    themeSelectionSection

                    // 📌 2단계: 활용사례 도움 토글
                    usageHelperToggle

                    // 📌 3단계: 붙여넣을 내용
                    if viewModel.isCombo {
                        comboDescriptionSection
                    } else {
                        ContentInputSection(
                            value: $viewModel.value,
                            selectedCategory: viewModel.selectedCategory,
                            isFocused: $isFocused,
                            autoDetectedType: $viewModel.autoDetectedType,
                            autoDetectedConfidence: $viewModel.autoDetectedConfidence,
                            attachedImages: $viewModel.attachedImages,
                            onNext: {
                                isFocused = false
                                // 키보드가 내려간 후 다음 필드 focus (즉시 호출 시 race)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    isTitleFocused = true
                                }
                            }
                        )
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        templateButton(title: NSLocalizedString("날짜", comment: "Date template button"), variable: "{날짜}")
                                        templateButton(title: NSLocalizedString("시간", comment: "Time template button"), variable: "{시간}")
                                        templateButton(title: NSLocalizedString("이름", comment: "Name template button"), variable: "{이름}")
                                        templateButton(title: NSLocalizedString("주소", comment: "Address template button"), variable: "{주소}")
                                        templateButton(title: NSLocalizedString("전화", comment: "Phone template button"), variable: "{전화}")
                                    }
                                }

                                Spacer()

                                // 다음 입력으로 이동
                                Button {
                                    isFocused = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        isTitleFocused = true
                                    }
                                } label: {
                                    Text(NSLocalizedString("다음", comment: "Next field button"))
                                        .fontWeight(.semibold)
                                }

                                Button {
                                    isFocused = false
                                } label: {
                                    Text(NSLocalizedString("완료", comment: "Done button"))
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }

                    // 📌 4단계: 키보드에 표시할 이름
                    titleInputSection

                    // 📌 5단계: 추가 옵션 (보안, 템플릿, Combo)
                    additionalOptionsSection
                    templateSection
                    comboSection
                    attachedTemplateSection
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
                memoId: memoId,
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
        .sheet(isPresented: $showNewTemplateSheet, onDismiss: {
            // 시트 닫힌 후 새로 생성된 템플릿을 자동 선택
            if let newest = availableTemplates.last {
                viewModel.attachedTemplateId = newest.id
            }
        }) {
            NavigationView {
                MemoAdd(insertedIsTemplate: true)
                    .navigationTitle(NSLocalizedString("새 템플릿", comment: "New template nav title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(NSLocalizedString("취소", comment: "Cancel")) {
                                showNewTemplateSheet = false
                            }
                        }
                    }
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

                    // All Categories — 사용자 편집 가능한 CategoryStore에서 읽음
                    ForEach(CategoryStore.shared.allCategories, id: \.self) { theme in
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

    // MARK: - Usage Helper Toggle (v4.0.8)
    /// 사용자가 무엇을 저장할지 막막할 때 활용사례에서 영감 받기.
    /// 토글 ON → showUsageHelperSheet = true → UsageScenarioPickerSheet 표시.
    /// 시나리오 카드 탭 → value 자동 채움 + 시트 dismiss.
    private var usageHelperToggle: some View {
        Button {
            showUsageHelperSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.callout)
                    .foregroundColor(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("활용사례에서 영감 받기", comment: "Usage scenario picker prompt"))
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(NSLocalizedString("실제로 쓰는 영어 템플릿을 골라 시작하세요", comment: "Usage scenario picker hint"))
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(theme.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.yellow.opacity(0.08))
            .cornerRadius(theme.radiusMd)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showUsageHelperSheet) {
            UsageScenarioPickerSheet { selectedExample in
                // 시나리오 본문을 메모 value로 적용. 사용자가 수정 가능 (샘플 표시는 안 함).
                viewModel.value = selectedExample
                showUsageHelperSheet = false
            }
        }
    }

    private var titleInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("키보드에 표시할 이름", comment: "Memo title label — what user sees on the keyboard"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(theme.textMuted)

            TextField(NSLocalizedString("예: 회사 이메일, 송금 계좌", comment: "Memo title field placeholder"), text: $viewModel.keyword)
                .font(.title3)
                .fontWeight(.semibold)
                .focused($isTitleFocused)
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

                // 빠른 삽입 — 자주 쓰는 토큰을 탭 한 번으로 내용에 추가
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("빠른 삽입", comment: "Quick insert label"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textMuted)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // 숫자 입력 타입
                            quickInsertToken("{금액}", isNumeric: true)
                            quickInsertToken("{수량}", isNumeric: true)
                            quickInsertToken("{가격}", isNumeric: true)
                            // 텍스트 선택 타입
                            quickInsertToken("{이름}", isNumeric: false)
                            quickInsertToken("{메모}", isNumeric: false)
                            quickInsertToken("{주소}", isNumeric: false)
                        }
                    }

                    // 타입 범례
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "number")
                                .font(.system(size: 9))
                                .foregroundColor(.blue)
                            Text(NSLocalizedString("숫자 입력 (키보드에서 숫자패드 표시)", comment: "Numeric token legend"))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                            Text(NSLocalizedString("선택지 (저장된 값 중 선택)", comment: "Selection token legend"))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
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

    // MARK: - Attached Template (v4.0.8)

    /// 옵션 템플릿 연결 섹션. 본 메모가 템플릿이 아닌 경우에만 노출.
    /// 평소엔 메모 단독 사용, 토글 켜면 사용 시 입력 시트 띄워 결합 출력.
    @ViewBuilder
    private var attachedTemplateSection: some View {
        if !viewModel.isTemplate && !viewModel.isCombo {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { viewModel.attachedTemplateId != nil },
                    set: { newValue in
                        if newValue {
                            // 첫 사용자 템플릿을 자동 선택
                            if viewModel.attachedTemplateId == nil {
                                viewModel.attachedTemplateId = availableTemplates.first?.id
                            }
                        } else {
                            viewModel.attachedTemplateId = nil
                        }
                    }
                )) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.badge.plus")
                            .foregroundColor(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("+ 템플릿 연결", comment: "Attach template toggle"))
                                .font(.callout)
                                .fontWeight(.medium)
                            Text(NSLocalizedString("사용 시 템플릿 입력값을 받아 함께 출력합니다", comment: "Attach template hint"))
                                .font(.caption)
                                .foregroundColor(theme.textMuted)
                        }
                    }
                }
                .disabled(availableTemplates.isEmpty)

                if availableTemplates.isEmpty {
                    HStack(spacing: 10) {
                        Text(NSLocalizedString("연결할 템플릿이 없습니다.", comment: "No templates hint"))
                            .font(.caption)
                            .foregroundColor(theme.textMuted)

                        Button {
                            showNewTemplateSheet = true
                        } label: {
                            Label(NSLocalizedString("새 템플릿 만들기", comment: "Create new template button"),
                                  systemImage: "plus.circle.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.leading, 32)
                } else if viewModel.attachedTemplateId != nil {
                    HStack {
                        Picker(NSLocalizedString("템플릿 선택", comment: "Template picker label"),
                               selection: Binding(
                                get: { viewModel.attachedTemplateId ?? availableTemplates.first?.id ?? UUID() },
                                set: { viewModel.attachedTemplateId = $0 }
                               )) {
                            ForEach(availableTemplates, id: \.id) { template in
                                Text(template.title).tag(template.id)
                            }
                        }
                        .pickerStyle(.menu)

                        Button {
                            showNewTemplateSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.purple)
                                .font(.system(size: 18))
                        }
                    }
                    .padding(.leading, 32)

                    if let selected = availableTemplates.first(where: { $0.id == viewModel.attachedTemplateId }) {
                        VStack(alignment: .leading, spacing: 8) {
                            // 템플릿 본문 표시
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("템플릿 본문", comment: "Template body label"))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(theme.textMuted)
                                Text(selected.value)
                                    .font(.caption)
                                    .foregroundColor(theme.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(theme.surfaceAlt)
                                    .cornerRadius(theme.radiusSm)
                            }

                            // 결합 결과 미리보기 (사용자가 어떤 결과가 출력될지 미리 보도록)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "eye.fill")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    Text(NSLocalizedString("출력 예시", comment: "Combined output preview header"))
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(theme.textMuted)
                                }
                                let memoPreview = viewModel.value.isEmpty
                                    ? NSLocalizedString("(메모 본문)", comment: "Memo body placeholder in preview")
                                    : viewModel.value
                                Text("\(memoPreview)\n\(selected.value)")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(Color.green.opacity(0.08))
                                    .cornerRadius(theme.radiusSm)
                                Text(NSLocalizedString("사용 시 {토큰} 부분에 입력값이 채워집니다", comment: "Token substitution hint"))
                                    .font(.caption2)
                                    .foregroundColor(theme.textMuted)
                            }
                        }
                        .padding(.leading, 32)
                    }
                }
            }
            .padding()
            .background(Color.purple.opacity(0.05))
            .cornerRadius(theme.radiusMd)
        }
    }

    /// 사용자가 만든 템플릿 메모 목록. 본 메모(`isTemplate=false`)는 자연스레 제외됨.
    private var availableTemplates: [Memo] {
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        return memos.filter { $0.isTemplate }
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
            TextField(NSLocalizedString("값 입력", comment: "Combo value input placeholder"), text: $viewModel.newComboValue)
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

    private func quickInsertToken(_ token: String, isNumeric: Bool) -> some View {
        QuickInsertTokenButton(token: token, isNumeric: isNumeric) {
            viewModel.value += token
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
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
// MARK: - Quick Insert Token Button

private struct QuickInsertTokenButton: View {
    let token: String
    let isNumeric: Bool
    let action: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isNumeric ? "number" : "list.bullet")
                    .font(.system(size: 9, weight: .semibold))
                Text(token)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isNumeric ? .blue : .green)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((isNumeric ? Color.blue : Color.green).opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder((isNumeric ? Color.blue : Color.green).opacity(0.25), lineWidth: 1)
            )
        }
    }
}

struct PlaceholderValueEditor: View {
    let placeholder: String
    @Binding var values: [String]
    @Environment(\.appTheme) private var theme
    @State private var newValue: String = ""
    @State private var isAdding: Bool = false

    private var isNumeric: Bool { TemplateVariableProcessor.isNumericToken(placeholder) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(placeholder.strippingTemplateBraces)
                    .font(.callout)
                    .fontWeight(.semibold)

                // 타입 뱃지 — 숫자 입력 vs 선택지
                HStack(spacing: 4) {
                    Image(systemName: isNumeric ? "number" : "list.bullet")
                        .font(.system(size: 10, weight: .semibold))
                    Text(isNumeric
                         ? NSLocalizedString("숫자 입력", comment: "Numeric placeholder badge")
                         : NSLocalizedString("선택지", comment: "Selection placeholder badge"))
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(isNumeric ? .blue : .green)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background((isNumeric ? Color.blue : Color.green).opacity(0.12))
                .cornerRadius(6)

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
                    TextField(NSLocalizedString("값 입력", comment: "Placeholder value input"), text: $newValue)
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
    /// v4.0.8: 키보드 toolbar "다음" 버튼 — 다음 필드(제목)로 focus 이동.
    /// nil이면 버튼 숨김.
    var onNext: (() -> Void)? = nil

    @Environment(\.appTheme) private var theme

    /// v4.0.8: 현재 value가 카테고리의 샘플 값과 동일한지 — 매번 판정.
    /// 사용자가 수정하면 자동으로 false. 우연히 샘플과 같아지면 다시 true (드문 케이스).
    private var isSampleValue: Bool {
        Constants.isSampleValue(value, forCategory: selectedCategory)
    }

    @State private var showImagePicker = false
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(NSLocalizedString("붙여넣을 내용", comment: "Content label — what gets pasted when user taps the memo"))
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
                // v4.0.8: 샘플 값이면 안내 배너 — "수정해서 사용하세요"
                if isSampleValue {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil.tip")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(NSLocalizedString("샘플 — 수정해서 사용하세요", comment: "Sample value hint"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        Spacer()
                        Button {
                            value = ""
                        } label: {
                            Text(NSLocalizedString("지우기", comment: "Clear sample"))
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(theme.radiusSm)
                }

                // 텍스트 테마: 동적 높이 TextField (iOS 16+ axis: .vertical)
                // 처음엔 작게 시작(2줄), 내용이 길어지면 최대 10줄까지 자동 확장.
                TextField(placeholderText, text: $value, axis: .vertical)
                    .font(.body)
                    .lineLimit(2...10)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(theme.surfaceAlt)
                    .cornerRadius(theme.radiusMd)
                    #if os(iOS)
                    .keyboardType(keyboardTypeForTheme)
                    #endif
                    .focused($isFocused)
                    .onChange(of: value) { newValue in
                        if !newValue.isEmpty {
                            let classification = ClipboardClassificationService.shared.classify(content: newValue)
                            autoDetectedType = classification.type
                            autoDetectedConfidence = classification.confidence
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

// MARK: - Usage Scenario Picker (v4.0.8)

/// 메모 추가 화면의 "활용사례에서 영감 받기" 토글이 띄우는 시트.
/// UsageGuideView의 시나리오 데이터(`usageCategories`)를 그대로 사용.
struct UsageScenarioPickerSheet: View {
    /// 시나리오 본문(영어 템플릿)을 받아 부모가 value에 채워넣고 시트를 닫음.
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    /// v4.0.8: 카테고리 필터 — nil이면 "전체" (모든 카테고리 표시)
    @State private var selectedCategoryId: UUID? = nil

    /// 필터링된 카테고리 목록
    private var filteredCategories: [UsageCategory] {
        guard let id = selectedCategoryId else { return usageCategories }
        return usageCategories.filter { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 카테고리 필터 칩
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(
                            label: NSLocalizedString("전체", comment: "All categories filter"),
                            emoji: "🌐",
                            isSelected: selectedCategoryId == nil,
                            action: { selectedCategoryId = nil }
                        )
                        ForEach(usageCategories) { category in
                            filterChip(
                                label: category.title,
                                emoji: category.emoji,
                                isSelected: selectedCategoryId == category.id,
                                action: { selectedCategoryId = category.id }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(theme.surface)

                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(filteredCategories) { category in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Text(category.emoji)
                                    Text(category.title)
                                        .font(.headline)
                                }
                                Text(category.desc)
                                    .font(.caption)
                                    .foregroundColor(theme.textMuted)

                                VStack(spacing: 8) {
                                    ForEach(category.scenarios) { scenario in
                                        scenarioCard(scenario)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle(NSLocalizedString("활용사례", comment: "Usage scenarios picker title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("닫기", comment: "Close")) { dismiss() }
                }
            }
        }
    }

    private func filterChip(label: String, emoji: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(emoji)
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : theme.surfaceAlt)
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func scenarioCard(_ scenario: UsageScenario) -> some View {
        Button {
            onSelect(scenario.example)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scenario.title)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        if let context = scenario.context {
                            Text(context)
                                .font(.caption)
                                .foregroundColor(theme.textMuted)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Spacer(minLength: 0)
                    // 버튼 affordance — 탭하면 입력된다는 명시 표시
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.caption2)
                        Text(NSLocalizedString("입력", comment: "Tap-to-insert hint"))
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                }

                // example 본문 — `[Your Name]` 같은 더미 placeholder는 빨간색으로 강조.
                // `{토큰}`은 앱이 입력 받는 템플릿 변수라 다르게 처리(여기선 그대로 회색).
                Text(highlightedExample(scenario.example))
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surfaceAlt)
                    .cornerRadius(6)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 1.2)
            )
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    /// `[Your Name]` 같은 더미 placeholder를 빨간색으로 강조한 AttributedString 생성.
    /// 사용자가 "여기는 직접 입력해야 하는 부분"이라는 걸 즉시 인지할 수 있도록.
    private func highlightedExample(_ raw: String) -> AttributedString {
        var attr = AttributedString(raw)
        attr.foregroundColor = .secondary

        let pattern = "\\[[^\\]]+\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return attr }
        let nsRange = NSRange(raw.startIndex..., in: raw)
        let matches = regex.matches(in: raw, range: nsRange)
        for match in matches.reversed() {
            guard let stringRange = Range(match.range, in: raw),
                  let attrRange = Range(stringRange, in: attr) else { continue }
            attr[attrRange].foregroundColor = .red
            attr[attrRange].font = .system(size: 12, weight: .semibold, design: .monospaced)
        }
        return attr
    }
}
