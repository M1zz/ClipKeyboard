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
    var insertedHint: String = ""
    var insertedIsFavorite: Bool = false
    /// "템플릿으로 만들기"로 진입했을 때 true — 본문에 포커스를 줘 변수 삽입바를 바로 노출.
    var startInTemplateMode: Bool = false

    // MARK: - View-only State

    @State private var isFocused: Bool = false
    @FocusState private var isQuickTextFocused: Bool  // quickModeBody TextEditor 전용
    @FocusState private var isTitleFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showNewTemplateSheet = false
    @State private var showResetConfirm = false
    /// 처음엔 심플 모드. 수정·템플릿·콤보이거나 "더 설정하기"를 탭하면 전체 모드 전환.
    @State private var showAdvancedOptions: Bool = false

    private var isQuickMode: Bool {
        // "템플릿으로 만들기"로 들어온 새 메모는 변수 삽입바가 있는 전체 모드로 시작한다.
        memoId == nil && !insertedIsTemplate && !insertedIsCombo && !showAdvancedOptions && !startInTemplateMode
    }

    var body: some View {
        Group {
            if isQuickMode {
                quickModeBody
            } else {
                fullModeBody
            }
        }
        .alert(viewModel.alertMessage, isPresented: $viewModel.showAlert) {}
        .alert(NSLocalizedString("입력 내용 초기화", comment: "Reset form confirm title"),
               isPresented: $showResetConfirm) {
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("초기화", comment: "Confirm reset"), role: .destructive) {
                viewModel.reset()
                showAdvancedOptions = false
            }
        } message: {
            Text(NSLocalizedString("입력한 내용이 모두 지워집니다. 계속하시겠습니까?", comment: "Reset form confirm message"))
        }
        .overlay {
            if viewModel.showToast {
                VStack {
                    Spacer()
                    Text(viewModel.toastMessage)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(theme.radiusSm)
                        .padding(.bottom, 100)
                        .accessibilityHidden(true)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: viewModel.showToast)
            }
        }
        .onChange(of: viewModel.showToast) { _, isShowing in
            #if os(iOS)
            if isShowing {
                UIAccessibility.post(notification: .announcement, argument: viewModel.toastMessage)
            }
            #endif
        }
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
        .sheet(isPresented: $viewModel.showOCRPicker) {
            OCRTextPickerSheet(candidates: viewModel.ocrCandidates) { lines in
                viewModel.applyOCRSelection(lines)
            }
        }
        .overlay {
            if viewModel.isProcessingOCR {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.5).tint(.white)
                        Text(NSLocalizedString("텍스트 인식 중...", comment: "Recognizing text"))
                            .foregroundColor(.white).font(.headline)
                    }
                    .padding(32).background(theme.surface).cornerRadius(theme.radiusLg)
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
                insertedComboValues: insertedComboValues,
                insertedHint: insertedHint,
                insertedIsFavorite: insertedIsFavorite
            )
            // "템플릿으로 만들기" 진입 — 시트가 안착한 뒤 본문에 포커스를 줘
            // 변수 삽입바({이름}/{날짜}…)를 바로 띄운다.
            if startInTemplateMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isFocused = true
                }
            }
        }
        .onChange(of: viewModel.value) { _, _ in viewModel.onValueChanged() }
        .sheet(isPresented: $showNewTemplateSheet) {
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
        .navigationTitle({
            if memoId != nil {
                if insertedIsTemplate { return NSLocalizedString("메모 수정 타이틀_템플릿", comment: "Edit template navigation title") }
                if insertedIsCombo { return NSLocalizedString("메모 수정 타이틀_콤보", comment: "Edit combo navigation title") }
                return NSLocalizedString("메모 수정", comment: "Edit memo navigation title")
            }
            if insertedIsTemplate { return NSLocalizedString("새 템플릿", comment: "New template navigation title") }
            if insertedIsCombo { return NSLocalizedString("새 콤보", comment: "New combo navigation title") }
            return NSLocalizedString("새 메모", comment: "New memo navigation title")
        }())
        .navigationBarTitleDisplayMode(.inline)
        .solidNavBar(theme.bg)
        .toolbar {
            // 새 메모(퀵 모드): 저장 버튼을 헤더 오른쪽(취소 맞은편)에 둬서 본문이 답답하지 않게.
            if isQuickMode {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if viewModel.keyword.isEmpty {
                            viewModel.keyword = viewModel.autoGeneratedTitle()
                        }
                        viewModel.saveMemo { dismiss() }
                    } label: {
                        Text(NSLocalizedString("저장", comment: "Save"))
                            .fontWeight(.semibold)
                    }
                    .disabled(viewModel.value.isEmpty)
                }
            }
        }
    }

    // MARK: - Quick Mode Body

    private var quickModeBody: some View {
        VStack(spacing: 0) {
            if viewModel.showClipboardSuggestion,
               let content = viewModel.clipboardContent,
               let detectedType = viewModel.clipboardDetectedType {
                ClipboardSuggestionBanner(
                    content: content,
                    detectedType: detectedType,
                    clipboardHistory: viewModel.clipboardHistory,
                    onAccept: { viewModel.acceptClipboardSuggestion() },
                    onDismiss: { viewModel.showClipboardSuggestion = false }
                )
                // 슬라이드로 들어오고, 5초 후 페이드 아웃으로 사라진다.
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity))
                .task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    withAnimation(.easeOut(duration: 0.5)) {
                        viewModel.showClipboardSuggestion = false
                    }
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // 1) 붙여넣을 내용(VALUE) + 이미지 — 풀모드와 동일 컴포넌트(탭하면 복사되는 값)
                    ContentInputSection(
                        value: $viewModel.value,
                        selectedCategory: viewModel.selectedCategory,
                        isFocused: $isFocused,
                        autoDetectedType: $viewModel.autoDetectedType,
                        autoDetectedConfidence: $viewModel.autoDetectedConfidence,
                        attachedImages: $viewModel.attachedImages,
                        onNext: {
                            isFocused = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isTitleFocused = true }
                        },
                        forceTextKeyboard: startInTemplateMode
                    )

                    // 2) 키보드에 표시할 이름(KEY) — 이 메모가 키보드에서 보일 제목. 핵심.
                    titleInputSection

                    // 3) 더 설정하기 (보안·템플릿·콤보)
                    quickAdvancedButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
            .background(theme.bg)
            // 저장 버튼은 헤더 오른쪽(toolbar)에 위치.
        }
        // 붙여넣을 내용 입력 중에만 키보드 위에 변수 옵션 바 노출 (이름·기타 필드에선 숨김).
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isFocused {
                VStack(spacing: 0) {
                    Divider()
                    variableTokenBar
                }
                .background(theme.surface)
            }
        }
    }

    /// 퀵 모드 "더 설정하기" — 보안/템플릿/콤보 등 고급 옵션으로 전환.
    private var quickAdvancedButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showAdvancedOptions = true }
        } label: {
            HStack {
                Image(systemName: "slider.horizontal.3")
                Text(NSLocalizedString("더 설정하기", comment: "Show advanced options"))
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(.body)
            .foregroundColor(theme.textMuted)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(theme.surfaceAlt)
            .cornerRadius(theme.radiusMd)
        }
    }

    // MARK: - Full Mode Body (기존 UI)

    private var fullModeBody: some View {
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

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 28) {
                        // 카테고리는 저장 시 자동 분류로 결정된다 (수동 선택 UI 제거).
                        // 카테고리 목록 관리는 설정 > 카테고리 관리에서만 수행.

                        // 📌 붙여넣을 내용
                        ContentInputSection(
                            value: $viewModel.value,
                            selectedCategory: viewModel.selectedCategory,
                            isFocused: $isFocused,
                            autoDetectedType: $viewModel.autoDetectedType,
                            autoDetectedConfidence: $viewModel.autoDetectedConfidence,
                            attachedImages: $viewModel.attachedImages,
                            onNext: {
                                isFocused = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    isTitleFocused = true
                                }
                            },
                            forceTextKeyboard: startInTemplateMode
                        )
                        .id("contentField")

                        // 📌 키보드에 표시할 이름
                        titleInputSection

                        // 📌 추가 옵션 (보안)
                        additionalOptionsSection
                        // 변수가 있으면 자동으로 템플릿 도우미 노출
                        templateSection
                        // 이어지는 메모를 더하면 콤보
                        continuationsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }
                // 하단 버튼 영역 — 키보드 바로 위에 딱 붙는 영역
                .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider()

                    // 본문 포커스 시 변수 삽입 버튼 표시 — {변수}를 넣으면 자동으로 템플릿이 됨
                    if isFocused {
                        variableTokenBar
                        Divider()
                    }

                    HStack(spacing: 12) {
                        Button {
                            let hasContent = !viewModel.value.isEmpty || !viewModel.keyword.isEmpty || !viewModel.attachedImages.isEmpty
                            if hasContent {
                                showResetConfirm = true
                            } else {
                                viewModel.reset()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .accessibilityHidden(true)
                                Text(NSLocalizedString("초기화", comment: "Reset"))
                            }
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(theme.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(theme.surfaceAlt)
                            .cornerRadius(theme.radiusMd)
                        }
                        .accessibilityHint(NSLocalizedString("입력한 내용, 이름, 카테고리를 모두 지웁니다", comment: "Reset button hint"))

                        if isFocused {
                            // 내용 입력 중: 다음 필드(이름)로 이동
                            Button {
                                isFocused = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    isTitleFocused = true
                                }
                            } label: {
                                HStack {
                                    Text(NSLocalizedString("다음", comment: "Next field button in bottom bar"))
                                    Image(systemName: "arrow.forward")
                                        .accessibilityHidden(true)
                                }
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.accentColor)
                                .cornerRadius(theme.radiusMd)
                            }
                        } else {
                            Button {
                                viewModel.saveMemo { dismiss() }
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark")
                                        .accessibilityHidden(true)
                                    Text(NSLocalizedString("저장", comment: "Save"))
                                }
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.accentColor)
                                .cornerRadius(theme.radiusMd)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                }
                .background(theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
            }
                .onChange(of: isFocused) { _, focused in
                    if focused {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                            proxy.scrollTo("contentField", anchor: .top)
                        }
                    }
                }
            }  // ScrollViewReader
        }
    }

    // MARK: - View Sections

    private var titleInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("키보드에 표시할 이름", comment: "Memo title label — what user sees on the keyboard"))
                .font(.body)
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
                // VoiceOver가 placeholder 대신 필드의 의미("키보드에 표시할 이름")를 읽도록 명시.
                .accessibilityLabel(NSLocalizedString("키보드에 표시할 이름", comment: "Memo title label — what user sees on the keyboard"))
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
        }
    }

    /// "이어지는 메모" 단계 — 더하면 자동으로 콤보가 된다(본문=1단계, 아래 칸=2단계~).
    @ViewBuilder
    private var continuationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.body)
                    .foregroundColor(theme.textMuted)
                Text(NSLocalizedString("이어지는 메모", comment: "Continuation memos section"))
                    .font(.body).fontWeight(.semibold)
                    .foregroundColor(theme.textMuted)
            }

            ForEach(viewModel.continuations.indices, id: \.self) { idx in
                HStack(spacing: 8) {
                    Text("\(idx + 2).")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundColor(theme.textFaint)
                    TextField(NSLocalizedString("이어서 입력할 내용", comment: "Continuation field placeholder"),
                              text: $viewModel.continuations[idx], axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        viewModel.removeContinuation(at: idx)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(theme.textFaint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(NSLocalizedString("이 단계 삭제", comment: "Delete continuation step"))
                }
            }

            Button {
                HapticManager.shared.light()
                viewModel.addContinuation()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                    Text(NSLocalizedString("이어지는 메모 추가", comment: "Add continuation memo"))
                }
                .font(.body)
            }

            if !viewModel.continuations.isEmpty {
                Text(NSLocalizedString("내용을 이어 더하면 콤보가 돼요 — 키보드에서 순서대로 입력됩니다.", comment: "Continuation/combo explanation"))
                    .font(.caption)
                    .foregroundColor(theme.textFaint)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var templateSection: some View {
        if !viewModel.detectedPlaceholders.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                    Text(NSLocalizedString("템플릿 변수는 {날짜}, {시간}, {이름} 형식으로 작성하세요", comment: "Template variable instruction"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }

                // 빠른 삽입 — 자주 쓰는 토큰을 탭 한 번으로 내용에 추가
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("빠른 삽입", comment: "Quick insert label"))
                        .font(.body)
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
                                .font(.system(.caption2))
                                .foregroundColor(.blue)
                            Text(NSLocalizedString("숫자 입력 (키보드에서 숫자패드 표시)", comment: "Numeric token legend"))
                                .font(.system(.caption2))
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.system(.caption2))
                                .foregroundColor(.green)
                            Text(NSLocalizedString("선택지 (저장된 값 중 선택)", comment: "Selection token legend"))
                                .font(.system(.caption2))
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
                            .font(.body)
                            .foregroundColor(.blue)
                        Text(NSLocalizedString("플레이스홀더 값 설정", comment: "Placeholder value settings"))
                            .font(.body)
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

    // MARK: - Attached Template (v4.0.8)

    /// 사용자가 만든 템플릿 메모 목록. 본 메모(`isTemplate=false`)는 자연스레 제외됨.
    private var availableTemplates: [Memo] {
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        return memos.filter { $0.isTemplate }
    }




    // 템플릿 변수 버튼
    @ViewBuilder
    /// 키보드 위에 뜨는 템플릿 변수 옵션 바 — 본문(붙여넣을 내용) 입력 중에만 노출.
    /// 탭하면 커서 위치에 {변수}가 삽입되어 자동으로 템플릿이 된다.
    private var variableTokenBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                templateButton(title: NSLocalizedString("금액", comment: "Amount token button"), variable: "{금액}")
                templateButton(title: NSLocalizedString("수량", comment: "Quantity token button"), variable: "{수량}")
                templateButton(title: NSLocalizedString("이름", comment: "Name token button"), variable: "{이름}")
                templateButton(title: NSLocalizedString("날짜", comment: "Date token button"), variable: "{날짜}")
                templateButton(title: NSLocalizedString("시간", comment: "Time token button"), variable: "{시간}")
                templateButton(title: NSLocalizedString("주소", comment: "Address token button"), variable: "{주소}")
                templateButton(title: NSLocalizedString("전화", comment: "Phone token button"), variable: "{전화}")
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
    }

    private func templateButton(title: String, variable: String) -> some View {
        Button {
            viewModel.value += variable
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } label: {
            Text(title)
                .font(.body.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(theme.radiusSm)
        }
        .accessibilityLabel(title)
        .accessibilityHint(NSLocalizedString("탭하면 커서 위치에 변수가 삽입됩니다", comment: "Template variable button hint"))
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
