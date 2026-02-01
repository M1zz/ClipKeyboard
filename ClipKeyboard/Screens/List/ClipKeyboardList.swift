//
//  ClipKeyboardList.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/05/14.
//

import SwiftUI
import LocalAuthentication

var isFirstVisit: Bool = true
var fontSize: CGFloat = 20

struct ClipKeyboardList: View {
    @State private var tokenMemos:[Memo] = []
    @State private var loadedData:[Memo] = []
    
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var showActive: Bool = false
    
    @State private var showShortcutSheet: Bool = false
    @State private var isFirstVisit: Bool = true

    @State private var keyword: String = ""
    @State private var value: String = ""

    // 클립보드 자동 분류
    @State private var clipboardDetectedType: ClipboardItemType = .text
    @State private var clipboardConfidence: Double = 0.0

    @State private var searchQueryString = ""
    @State private var isSearchBarVisible = false

    // 보안 관련
    @State private var showAuthAlert = false
    @State private var selectedCategoryFilter: String? = nil
    @State private var selectedTypeFilter: ClipboardItemType? = nil

    // UserDefaults 키
    private let selectedFilterKey = "selectedTypeFilter"

    // 템플릿 입력 관련
    @State private var showTemplateInputSheet = false
    @State private var templatePlaceholders: [String] = []
    @State private var templateInputs: [String: String] = [:]
    @State private var currentTemplateMemo: Memo? = nil

    // 템플릿 편집 시트
    @State private var selectedTemplateIdForSheet: UUID? = nil

    // 플레이스홀더 관리 시트
    @State private var showPlaceholderManagementSheet = false

    // 데이터 리프레시 트리거
    @State private var refreshTrigger = UUID()

    var body: some View {
        NavigationStack {
            ZStack {
                // 메모 리스트
                if !tokenMemos.isEmpty {
                    List {
                        // 검색 바 섹션 (조건부 표시)
                        if isSearchBarVisible {
                            Section {
                                searchBarInlineSection
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // 타입 필터 바 섹션
                        if !loadedData.isEmpty {
                            Section {
                                typeFilterBarInlineSection
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        // 메모 리스트 섹션
                        Section {
                            // 메모 목록
                            ForEach($tokenMemos) { $memo in
                                memoRow(memo: $memo)
                            }
                            .onDelete(perform: deleteMemo)
                        }
                    }
                    .listStyle(PlainListStyle())
                }

                // 빈 화면
                if tokenMemos.isEmpty {
                    EmptyListView
                }
            }
            .task {
                print("🔄 [task] 메모 리프레시")
                loadMemos()
            }
            .toolbar {
                toolbarContent
            }
            // Toast 메시지 오버레이
            .overlay(alignment: .bottom) {
                toastOverlay
            }
            .animation(.easeInOut(duration: 0.5), value: showToast)

            // Navigation 설정
            .navigationTitle("저장된 항목")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            // 검색 및 필터 변경 감지
            .onChange(of: searchQueryString, perform: { _ in applyFilters() })
            .onChange(of: selectedTypeFilter, perform: { _ in
                applyFilters()
                saveSelectedFilter()
            })
            // 인증 실패 Alert
            .alert("인증 실패", isPresented: $showAuthAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("보안 메모에 접근하려면 생체 인증이 필요합니다")
            }
            // 각종 Sheet Modifiers
            .modifier(SheetModifiers(
                showTemplateInputSheet: $showTemplateInputSheet,
                showPlaceholderManagementSheet: $showPlaceholderManagementSheet,
                selectedTemplateIdForSheet: $selectedTemplateIdForSheet,
                templatePlaceholders: templatePlaceholders,
                templateInputs: $templateInputs,
                tokenMemos: tokenMemos,
                currentTemplateMemo: currentTemplateMemo,
                onTemplateComplete: {
                    guard let memo = currentTemplateMemo else { return }
                    let processedValue = processTemplateWithInputs(in: memo.value, inputs: templateInputs)
                    finalizeCopy(memo: memo, processedValue: processedValue)
                    showTemplateInputSheet = false
                },
                onTemplateCancel: { showTemplateInputSheet = false },
                onTemplateCopy: { memo, processedValue in
                    finalizeCopy(memo: memo, processedValue: processedValue)
                    selectedTemplateIdForSheet = nil
                },
                onTemplateSheetCancel: { selectedTemplateIdForSheet = nil }
            ))
            // 단축키 메모 오버레이
            .overlay(content: {
                shortcutMemoOverlay
            })
            .onAppear {
                print("🎬 [ClipKeyboardList] onAppear 시작 (최초 설정)")

                // 저장된 필터 타입 로드
                loadSavedFilter()

                // 기존 메모 자동 분류 마이그레이션 (최초 1회만)
                migrateExistingMemosClassification()

                // 클립보드 자동 확인 기능 - 클립보드에 내용이 있으면 바로가기 시트 표시
                // iOS 14+에서 처음 실행 시 "Allow Paste" 알림이 뜰 수 있습니다
                // 한 번 허용하면 이후에는 알림 없이 작동합니다
                print("📋 [ClipKeyboardList] 클립보드 확인 중...")
                let hasClipboard = !(UIPasteboard.general.string?.isEmpty ?? true)
                print("📋 [ClipKeyboardList] 클립보드 내용 있음: \(hasClipboard), isFirstVisit: \(isFirstVisit)")

                if hasClipboard, isFirstVisit {
                    print("🎯 [ClipKeyboardList] 클립보드 바로가기 시트 표시 예약")

                    value = UIPasteboard.general.string ?? "error"
                    print("📝 [ClipKeyboardList] 클립보드 값: \(value)")

                    // 자동 분류 수행
                    let classification = ClipboardClassificationService.shared.classify(content: value)
                    clipboardDetectedType = classification.type
                    clipboardConfidence = classification.confidence
                    print("🔍 [ClipKeyboardList] 자동 분류: \(classification.type.rawValue) (신뢰도: \(Int(classification.confidence * 100))%)")

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        print("📱 [ClipKeyboardList] 바로가기 시트 표시")
                        showShortcutSheet = true
                    }

                    isFirstVisit = false
                }

                fontSize = UserDefaults.standard.object(forKey: "fontSize") as? CGFloat ?? 20.0
                print("🔤 [ClipKeyboardList] 폰트 크기: \(fontSize)")

                print("✅ [ClipKeyboardList] onAppear 완료")
            }
        }
    }

    // MARK: - View Sections

    /// 검색 바 섹션 (인라인)
    private var searchBarInlineSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 16))

            TextField("검색", text: $searchQueryString)
                .textFieldStyle(PlainTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !searchQueryString.isEmpty {
                Button(action: {
                    HapticManager.shared.soft()
                    searchQueryString = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// 타입 필터 바 섹션 (인라인)
    private var typeFilterBarInlineSection: some View {
        MemoTypeFilterBar(selectedFilter: $selectedTypeFilter, memos: loadedData)
    }

    /// 새 메모 추가 행
    private var addMemoRow: some View {
        NavigationLink {
            MemoAdd()
        } label: {
            HStack {
                Spacer()
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundColor(.blue)
                Spacer()
            }
            .padding(.all, 8)
        }
        .listRowSeparator(.hidden)
        .buttonStyle(PlainButtonStyle())
    }

    /// 메모 행
    private func memoRow(memo: Binding<Memo>) -> some View {
        HStack {
            // 복사 버튼
            Button {
                copyMemo(memo: memo.wrappedValue)
            } label: {
                MemoRowView(memo: memo.wrappedValue, fontSize: fontSize)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // 즐겨찾기 버튼
            Button {
                toggleFavorite(memo: memo)
            } label: {
                Image(systemName: memo.wrappedValue.isFavorite ? "heart.fill" : "heart")
                    .symbolRenderingMode(.multicolor)
            }
            .frame(width: 40, height: 40)
            .buttonStyle(BorderedButtonStyle())
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            editButton(memo: memo.wrappedValue)
        }
        .transition(.scale)
    }

    /// 수정 버튼
    private func editButton(memo: Memo) -> some View {
        NavigationLink {
            MemoAdd(
                memoId: memo.id,
                insertedKeyword: memo.title,
                insertedValue: memo.value,
                insertedCategory: memo.category,
                insertedIsTemplate: memo.isTemplate,
                insertedIsSecure: memo.isSecure,
                insertedIsCombo: memo.isCombo,
                insertedComboValues: memo.comboValues
            )
        } label: {
            Label("수정", systemImage: "pencil")
        }
        .tint(.green)
    }

    /// Toolbar 컨텐츠
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        // iOS 하단 바
        ToolbarItemGroup(placement: .bottomBar) {
            toolbarButtons
        }
        #else
        // macOS 상단 바
        ToolbarItemGroup(placement: .automatic) {
            toolbarButtons
        }
        #endif
    }

    /// Toolbar 버튼들 (iOS/macOS 공통)
    @ViewBuilder
    private var toolbarButtons: some View {
        Button {
            HapticManager.shared.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isSearchBarVisible.toggle()
                if !isSearchBarVisible {
                    searchQueryString = ""
                }
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isSearchBarVisible ? .blue : .secondary)
        }

        NavigationLink {
            ClipboardList()
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.secondary)
        }

        Button {
            HapticManager.shared.light()
            showPlaceholderManagementSheet = true
        } label: {
            Image(systemName: "list.bullet")
                .foregroundColor(.secondary)
        }

        NavigationLink {
            SettingView()
        } label: {
            Image(systemName: "gearshape")
                .foregroundColor(.secondary)
        }

        Spacer()

        NavigationLink {
            MemoAdd()
        } label: {
            Image(systemName: "plus")
                .foregroundColor(.blue)
        }
    }

    /// Toast 오버레이
    @ViewBuilder
    private var toastOverlay: some View {
        if showToast {
            Text(toastMessage)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.toastBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                .onTapGesture {
                    HapticManager.shared.soft()
                    showToast = false
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeOut(duration: 0.2), value: showToast)
                .padding(.bottom, 50)
        }
    }

    /// 단축키 메모 오버레이
    @ViewBuilder
    private var shortcutMemoOverlay: some View {
        VStack {
            Spacer()
            if !value.isEmpty {
                ShortcutMemoView(
                    keyword: $keyword,
                    value: $value,
                    tokenMemos: $tokenMemos,
                    originalData: $loadedData,
                    showShortcutSheet: $showShortcutSheet,
                    detectedType: clipboardDetectedType,
                    confidence: clipboardConfidence
                )
                .offset(y: 0)
                .shadow(radius: 15)
                .opacity(showShortcutSheet ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).delay(0.3), value: showShortcutSheet)
            }
        }
    }

    // MARK: - Helper Functions

    /// 메모 데이터 로드
    private func loadMemos() {
        do {
            print("📂 [loadMemos] 메모 로드 시작...")
            let loadedMemos = try MemoStore.shared.load(type: .tokenMemo)
            print("📊 [loadMemos] 로드된 메모 개수: \(loadedMemos.count)")

            tokenMemos = sortMemos(loadedMemos)
            loadedData = tokenMemos

            print("✅ [loadMemos] 메모 로드 완료")

            // 필터 적용
            applyFilters()
        } catch {
            print("❌ [loadMemos] 메모 로드 실패: \(error.localizedDescription)")
        }
    }

    /// UserDefaults에서 저장된 필터 타입 로드
    private func loadSavedFilter() {
        if let savedFilterRawValue = UserDefaults.standard.string(forKey: selectedFilterKey),
           let savedFilter = ClipboardItemType(rawValue: savedFilterRawValue) {
            selectedTypeFilter = savedFilter
            print("📌 [loadSavedFilter] 저장된 필터 로드: \(savedFilter.rawValue)")
        } else {
            selectedTypeFilter = nil
            print("📌 [loadSavedFilter] 저장된 필터 없음 - 전체 표시")
        }
    }

    /// UserDefaults에 선택된 필터 타입 저장
    private func saveSelectedFilter() {
        if let filter = selectedTypeFilter {
            UserDefaults.standard.set(filter.rawValue, forKey: selectedFilterKey)
            print("💾 [saveSelectedFilter] 필터 저장: \(filter.rawValue)")
        } else {
            UserDefaults.standard.removeObject(forKey: selectedFilterKey)
            print("💾 [saveSelectedFilter] 필터 초기화 (전체)")
        }
    }

    /// 즐겨찾기 토글
    private func toggleFavorite(memo: Binding<Memo>) {
        withAnimation(.easeInOut) {
            memo.wrappedValue.isFavorite.toggle()

            do {
                // loadedData에서 해당 메모 업데이트
                if let index = loadedData.firstIndex(where: { $0.id == memo.wrappedValue.id }) {
                    loadedData[index] = memo.wrappedValue
                }
                loadedData = sortMemos(loadedData)

                try MemoStore.shared.save(memos: loadedData, type: .tokenMemo)

                // 필터 다시 적용
                applyFilters()
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }

    /// 메모 삭제
    private func deleteMemo(at offsets: IndexSet) {
        // tokenMemos에서 삭제할 메모들의 ID 수집
        let deletedIds = offsets.map { tokenMemos[$0].id }

        // loadedData에서도 삭제
        loadedData.removeAll { memo in deletedIds.contains(memo.id) }

        do {
            try MemoStore.shared.save(memos: loadedData, type: .tokenMemo)

            // 필터 다시 적용
            applyFilters()
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    private func sortMemos(_ memos: [Memo]) -> [Memo] {
        print("🔢 [sortMemos] 정렬 시작 - 입력: \(memos.count)개")

        let sorted = memos.sorted { (memo1, memo2) -> Bool in
            if memo1.isFavorite != memo2.isFavorite {
                // 즐겨찾기가 다르면 즐겨찾기를 우선
                return memo1.isFavorite && !memo2.isFavorite
            } else {
                // 즐겨찾기가 같으면 수정일 기준
                return memo1.lastEdited > memo2.lastEdited
            }
        }

        print("✅ [sortMemos] 정렬 완료 - 출력: \(sorted.count)개")
        return sorted
    }

    // 기존 메모 자동 분류 마이그레이션
    private func migrateExistingMemosClassification() {
        // 한 번만 실행되도록 체크
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
                // 자동 분류 타입이 없는 메모만 처리
                if memos[index].autoDetectedType == nil {
                    let classification = ClipboardClassificationService.shared.classify(content: memos[index].value)
                    memos[index].autoDetectedType = classification.type

                    // 테마가 "기본"인 경우에만 자동으로 변경
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
                // UI 업데이트
                loadedData = sortMemos(memos)
                applyFilters()
                print("✅ [Migration] 마이그레이션 완료 및 저장됨")
            } else {
                print("ℹ️ [Migration] 업데이트할 메모 없음")
            }

            // 마이그레이션 완료 표시
            UserDefaults.standard.set(true, forKey: migrationKey)

        } catch {
            print("❌ [Migration] 마이그레이션 실패: \(error)")
        }
    }

    /// Empty list view
    private var EmptyListView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 24) {
                Text(NSLocalizedString("자주 치는 문장이 뭔가요?", comment: "Empty state question"))
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    Text("\"\(NSLocalizedString("회의가 10분 늦어질 것 같습니다", comment: "Empty state example 1"))\"")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Text("\"\(NSLocalizedString("확인했습니다. 검토 후 답변드리겠습니다", comment: "Empty state example 2"))\"")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)

                NavigationLink {
                    MemoAdd()
                } label: {
                    Text(NSLocalizedString("첫 클립 추가", comment: "Add first clip button"))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(height: 44)
                        .padding(.horizontal, 24)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 30)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
    
    private func showToast(message: String) {
        toastMessage = String(format: NSLocalizedString("[%@] 이 복사되었습니다.", comment: "Copied toast message"), message)
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showToast = false
        }
    }

    private func copyMemo(memo: Memo) {
        print("📝 [copyMemo] 메모 선택됨: \(memo.title), 템플릿: \(memo.isTemplate), 보안: \(memo.isSecure)")

        // 🔒 보안 메모 확인
        if memo.isSecure {
            print("🔐 [copyMemo] 보안 메모 - Face ID 인증 요청")
            authenticateWithBiometrics(memo: memo)
            return
        }

        // 일반 메모는 바로 처리
        processMemoAfterAuth(memo)
    }

    private func authenticateWithBiometrics(memo: Memo) {
        let context = LAContext()
        var error: NSError?

        // 생체 인증 가능 여부 확인
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("❌ [authenticateWithBiometrics] 생체 인증 불가: \(error?.localizedDescription ?? "Unknown error")")
            showAuthAlert = true
            return
        }

        // 생체 인증 요청
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                              localizedReason: "보안 메모에 접근하려면 인증이 필요합니다") { success, authError in
            DispatchQueue.main.async {
                if success {
                    print("✅ [authenticateWithBiometrics] Face ID 인증 성공")
                    self.processMemoAfterAuth(memo)
                } else {
                    print("❌ [authenticateWithBiometrics] Face ID 인증 실패: \(authError?.localizedDescription ?? "Unknown error")")
                    self.showAuthAlert = true
                }
            }
        }
    }

    private func processMemoAfterAuth(_ memo: Memo) {
        // 템플릿이면 편집 시트 표시
        if memo.isTemplate {
            print("📄 [processMemoAfterAuth] 템플릿 메모 - TemplateEditSheet 표시")
            print("🔍 [processMemoAfterAuth] selectedTemplateIdForSheet 설정: \(memo.id)")
            selectedTemplateIdForSheet = memo.id
            print("✅ [processMemoAfterAuth] selectedTemplateIdForSheet 설정 완료")
            return
        }

        // 일반 메모는 바로 복사
        print("📋 [processMemoAfterAuth] 일반 메모 - 바로 복사")
        let processedValue = memo.value
        finalizeCopy(memo: memo, processedValue: processedValue)
    }

    private func finalizeCopy(memo: Memo, processedValue: String) {
        #if os(iOS)
        // 이미지 메모인 경우 이미지를 클립보드에 복사
        if memo.contentType == .image || memo.contentType == .mixed {
            if let firstImageFileName = memo.imageFileNames.first,
               let image = MemoStore.shared.loadImage(fileName: firstImageFileName) {
                UIPasteboard.general.image = image
                print("✅ [finalizeCopy] 이미지를 클립보드에 복사: \(firstImageFileName)")

                // 텍스트도 있으면 함께 복사
                if !processedValue.isEmpty && memo.contentType == .mixed {
                    UIPasteboard.general.string = processedValue
                }
            }
        } else {
            // 텍스트만 있는 경우
            UIPasteboard.general.string = processedValue
        }
        #else
        UIPasteboard.general.string = processedValue
        #endif

        // 사용 빈도 증가
        do {
            try MemoStore.shared.incrementClipCount(for: memo.id)

            // 이미지가 아닌 경우에만 클립보드 히스토리에 추가
            if memo.contentType != .image {
                try MemoStore.shared.addToSmartClipboardHistory(content: processedValue)
            }

            // UI 업데이트를 위해 데이터 리로드
            let allMemos = try MemoStore.shared.load(type: .tokenMemo)
            loadedData = sortMemos(allMemos)

            // 필터 다시 적용
            applyFilters()
        } catch {
            print("Error incrementing clip count: \(error)")
        }

        // Toast 메시지
        let message = memo.contentType == .image ? "이미지" : processedValue
        showToast(message: message)
    }

    private func extractCustomPlaceholders(from text: String) -> [String] {
        // 자동 변수 목록
        let autoVariables = ["{날짜}", "{시간}", "{연도}", "{월}", "{일}"]

        // 정규식으로 모든 {변수} 형태 찾기
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var placeholders: [String] = []

        for match in matches {
            if let range = Range(match.range, in: text) {
                let placeholder = String(text[range])
                // 자동 변수가 아닌 것만 추가
                if !autoVariables.contains(placeholder) && !placeholders.contains(placeholder) {
                    placeholders.append(placeholder)
                }
            }
        }

        return placeholders
    }

    private func processTemplateWithInputs(in text: String, inputs: [String: String]) -> String {
        var result = text

        // 사용자 입력값으로 치환
        for (placeholder, value) in inputs {
            result = result.replacingOccurrences(of: placeholder, with: value)
        }

        // 자동 변수 치환
        result = processTemplateVariables(in: result)

        return result
    }

    private func processTemplateVariables(in text: String) -> String {
        var result = text
        let dateFormatter = DateFormatter()

        // {날짜}
        dateFormatter.dateFormat = "yyyy-MM-dd"
        result = result.replacingOccurrences(of: "{날짜}", with: dateFormatter.string(from: Date()))

        // {시간}
        dateFormatter.dateFormat = "HH:mm:ss"
        result = result.replacingOccurrences(of: "{시간}", with: dateFormatter.string(from: Date()))

        // {연도}
        result = result.replacingOccurrences(of: "{연도}", with: String(Calendar.current.component(.year, from: Date())))

        // {월}
        result = result.replacingOccurrences(of: "{월}", with: String(Calendar.current.component(.month, from: Date())))

        // {일}
        result = result.replacingOccurrences(of: "{일}", with: String(Calendar.current.component(.day, from: Date())))

        return result
    }

    private func filterByCategory() {
        do {
            var memos = try MemoStore.shared.load(type: .tokenMemo)
            if let category = selectedCategoryFilter {
                memos = memos.filter { $0.category == category }
            }
            tokenMemos = sortMemos(memos)
            loadedData = tokenMemos
        } catch {
            print("Error filtering by category: \(error)")
        }
    }

    private func applyFilters() {
        print("🔍 [applyFilters] 시작 - loadedData: \(loadedData.count)개")
        print("🔍 [applyFilters] 검색어: '\(searchQueryString)'")
        print("🔍 [applyFilters] 타입 필터: \(selectedTypeFilter?.rawValue ?? "없음")")

        var filtered = loadedData

        // 검색어 필터
        if !searchQueryString.isEmpty {
            filtered = filtered.filter { $0.title.localizedStandardContains(searchQueryString) }
            print("🔍 [applyFilters] 검색 후: \(filtered.count)개")
        }

        // 테마 필터 (메모에 설정된 category 기준)
        if let typeFilter = selectedTypeFilter {
            let beforeCount = filtered.count
            filtered = filtered.filter { $0.category == typeFilter.rawValue }
            print("🔍 [applyFilters] 테마 필터 '\(typeFilter.rawValue)' 적용 - \(beforeCount)개 → \(filtered.count)개")

            // 필터 적용 후 결과가 0개이고 검색어가 없다면 필터를 자동으로 해제
            if filtered.isEmpty && !loadedData.isEmpty && searchQueryString.isEmpty {
                print("⚠️ [applyFilters] 필터 결과 0개 - 필터 자동 해제")
                selectedTypeFilter = nil
                filtered = loadedData
                saveSelectedFilter() // 해제된 상태 저장
            }
        }

        tokenMemos = filtered
        print("✅ [applyFilters] 완료 - tokenMemos: \(tokenMemos.count)개")
    }
}

struct ClipKeyboardList_Previews: PreviewProvider {
    static var previews: some View {
        ClipKeyboardList()
    }
}


// MARK: - Memo Type Filter Bar

struct MemoTypeFilterBar: View {
    @Binding var selectedFilter: ClipboardItemType?
    let memos: [Memo]

    // 메모에 설정된 category(테마) 기준으로 개수 계산
    var typeCounts: [ClipboardItemType: Int] {
        var counts: [ClipboardItemType: Int] = [:]
        for type in ClipboardItemType.allCases {
            counts[type] = memos.filter { $0.category == type.rawValue }.count
        }
        return counts
    }

    // 개수가 많은 순서대로 타입 정렬
    var sortedTypes: [ClipboardItemType] {
        ClipboardItemType.allCases.sorted { type1, type2 in
            let count1 = typeCounts[type1, default: 0]
            let count2 = typeCounts[type2, default: 0]
            return count1 > count2
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // 전체 버튼 (항상 첫 번째)
                MemoFilterChip(
                    title: NSLocalizedString("전체", comment: "All"),
                    icon: "list.bullet",
                    count: memos.count,
                    isSelected: selectedFilter == nil
                ) {
                    selectedFilter = nil
                }

                // 타입별 필터 (개수가 많은 순서대로 정렬)
                ForEach(sortedTypes, id: \.self) { type in
                    MemoFilterChip(
                        title: type.localizedName,
                        icon: type.icon,
                        count: typeCounts[type, default: 0],
                        color: type.color,
                        isSelected: selectedFilter == type
                    ) {
                        selectedFilter = type
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MemoFilterChip: View {
    let title: String
    let icon: String
    let count: Int
    var color: String = "blue"
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .fontWeight(isSelected ? .semibold : .regular)
                Text(title)
                    .font(.system(size: 13))
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("\(count)")
                    .font(.system(size: 11))
                    .fontWeight(isSelected ? .bold : .medium)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        isSelected
                            ? Color.white.opacity(0.25)
                            : Color.black.opacity(0.1)
                    )
                    .cornerRadius(8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? colorFor(color) : Color(.systemGray4))
                    .shadow(
                        color: isSelected ? colorFor(color).opacity(0.3) : Color.clear,
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            )
            .foregroundColor(isSelected ? .white : Color(.systemGray))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        isSelected ? Color.white.opacity(0.2) : Color.clear,
                        lineWidth: 1
                    )
            )
            .scaleEffect(isSelected ? 1.0 : 0.96)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }

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
}

// MARK: - Sheet Modifiers
/// 모든 Sheet 프레젠테이션을 관리하는 ViewModifier
/// - 템플릿 입력 시트
/// - 플레이스홀더 관리 시트
/// - 템플릿 편집 시트
struct SheetModifiers: ViewModifier {
    // Sheet 표시 상태
    @Binding var showTemplateInputSheet: Bool
    @Binding var showPlaceholderManagementSheet: Bool
    @Binding var selectedTemplateIdForSheet: UUID?

    // 데이터
    let templatePlaceholders: [String]
    @Binding var templateInputs: [String: String]
    let tokenMemos: [Memo]
    let currentTemplateMemo: Memo?

    // 콜백
    let onTemplateComplete: () -> Void
    let onTemplateCancel: () -> Void
    let onTemplateCopy: (Memo, String) -> Void
    let onTemplateSheetCancel: () -> Void

    func body(content: Content) -> some View {
        content
            // 템플릿 입력 시트
            .sheet(isPresented: $showTemplateInputSheet) {
                if currentTemplateMemo != nil {
                    TemplateInputSheet(
                        placeholders: templatePlaceholders,
                        inputs: $templateInputs,
                        onComplete: onTemplateComplete,
                        onCancel: onTemplateCancel
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
            // 플레이스홀더 관리 시트
            .sheet(isPresented: $showPlaceholderManagementSheet) {
                PlaceholderManagementSheet(allMemos: tokenMemos)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            // 템플릿 편집 시트
            .sheet(item: $selectedTemplateIdForSheet) { templateId in
                TemplateSheetResolver(
                    templateId: templateId,
                    allMemos: tokenMemos,
                    onCopy: onTemplateCopy,
                    onCancel: onTemplateSheetCancel
                )
            }
    }
}

// UUID를 Identifiable로 만들기 위한 extension
extension UUID: Identifiable {
    public var id: UUID { self }
}
