//
//  TokenMemoList.swift
//  Token memo
//
//  Created by hyunho lee on 2023/05/14.
//

import SwiftUI

var isFirstVisit: Bool = true
var fontSize: CGFloat = 20

struct TokenMemoList: View {
    @State private var tokenMemos:[Memo] = []
    @State private var loadedData:[Memo] = []
    
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var showActive: Bool = false
    
    @State private var showShortcutSheet: Bool = false
    @State private var isFirstVisit: Bool = true
    
    @State private var keyword: String = ""
    @State private var value: String = ""

    @State private var searchQueryString = ""

    // 보안 관련
    @State private var showAuthAlert = false
    @State private var selectedCategoryFilter: String? = nil

    // 템플릿 입력 관련
    @State private var showTemplateInputSheet = false
    @State private var templatePlaceholders: [String] = []
    @State private var templateInputs: [String: String] = [:]
    @State private var currentTemplateMemo: Memo? = nil

    // 템플릿 편집 시트
    @State private var selectedTemplateIdForSheet: UUID? = nil

    // 플레이스홀더 관리 시트
    @State private var showPlaceholderManagementSheet = false

    // Mac Catalyst 단축키용 새 메모 시트
    @State private var showNewMemoSheet = false
    @State private var showClipboardHistorySheet = false
    @State private var showSettingsSheet = false
    @State private var showMemoListSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    if tokenMemos.isEmpty {
                        NavigationLink {
                            MemoAdd()
                        } label: {
                            EmptyListView
                        }
                    }
                    ForEach($tokenMemos) { $memo in
                        HStack {
                            Button {
                                    copyMemo(memo: memo)
                            } label: {
                                MemoRowView(memo: memo, fontSize: fontSize)
                            }
                            .buttonStyle(PlainButtonStyle())


                            Spacer()
                            Button {
                                withAnimation(.easeInOut) {
                                    memo.isFavorite.toggle()
                                    tokenMemos = sortMemos(tokenMemos)

                                    // update
                                    do {
                                        try MemoStore.shared.save(memos: tokenMemos, type: .tokenMemo)
                                        loadedData = tokenMemos
                                    } catch {
                                        fatalError(error.localizedDescription)
                                    }
                                }


                            } label: {
                                Image(systemName: memo.isFavorite ? "heart.fill" : "heart")
                                    .symbolRenderingMode(.multicolor)
                            }
                            .frame(width: 40, height: 40)
                            .buttonStyle(BorderedButtonStyle())
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            NavigationLink {
                                MemoAdd(
                                    memoId: memo.id,
                                    insertedKeyword: memo.title,
                                    insertedValue: memo.value,
                                    insertedCategory: memo.category,
                                    insertedIsTemplate: memo.isTemplate,
                                    insertedIsSecure: memo.isSecure,
                                    insertedShortcut: memo.shortcut ?? ""
                                )
                            } label: {
                                Label("수정", systemImage: "pencil")
                            }
                            .tint(.green)
                        }
                        .transition(.scale)
                    }
                    .onDelete { index in
                        tokenMemos.remove(atOffsets: index)
                        
                        // update
                        do {
                            try MemoStore.shared.save(memos: tokenMemos, type: .tokenMemo)
                            loadedData = tokenMemos
                        } catch {
                            fatalError(error.localizedDescription)
                        }
                    }
                    
                    ZStack {
                        NavigationLink {
                            MemoAdd()
                        } label: {
                            Text("")
                        }
                        .opacity(0.0)
                        .buttonStyle(PlainButtonStyle())
                        
                        HStack {
                            Spacer()
                            Image(systemName: "plus.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        .padding(.all, 8)
                    }
                }
                
                
                .listRowInsets(EdgeInsets(top: 15, leading: 0, bottom: 0, trailing: 0))

                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 8) {
                            Text("저장된 항목")
                                .font(.headline)
                                .fontWeight(.bold)

                            Menu {
                                Button("전체") {
                                    selectedCategoryFilter = nil
                                    filterByCategory()
                                }
                                ForEach(["기본", "은행", "주소", "이메일", "전화번호", "비밀번호", "기타"], id: \.self) { category in
                                    Button(category) {
                                        selectedCategoryFilter = category
                                        filterByCategory()
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if let filter = selectedCategoryFilter {
                                        Text(filter)
                                            .font(.subheadline)
                                    }
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedCategoryFilter != nil ? Color.blue : Color.clear)
                                .foregroundColor(selectedCategoryFilter != nil ? .white : .blue)
                                .cornerRadius(8)
                            }
                        }
                    }

                    #if os(iOS)
                    ToolbarItemGroup(placement: .bottomBar) {
                        NavigationLink {
                            ClipboardList()
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }

                        NavigationLink {
                            SettingView()
                        } label: {
                            Image(systemName: "info.circle")
                        }

                        Button {
                            showPlaceholderManagementSheet = true
                        } label: {
                            Image(systemName: "list.bullet.circle")
                        }

                        Spacer()

                        NavigationLink {
                            MemoAdd()
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                    #else
                    ToolbarItemGroup(placement: .automatic) {
                        NavigationLink {
                            ClipboardList()
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }

                        NavigationLink {
                            SettingView()
                        } label: {
                            Image(systemName: "info.circle")
                        }

                        Button {
                            showPlaceholderManagementSheet = true
                        } label: {
                            Image(systemName: "list.bullet.circle")
                        }

                        Spacer()

                        NavigationLink {
                            MemoAdd()
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                    #endif
                }
                
                VStack {
                    Spacer()
                    if showToast {
                        Group {
                            Text(toastMessage)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(.gray)
                                .cornerRadius(8)
                                .padding()
                                .foregroundColor(.white)
                        }
                        .onTapGesture {
                            showToast = false
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.5), value: showToast)
                .transition(.opacity)
            }
            
            .onChange(of: searchQueryString, perform: { value in
                if searchQueryString.isEmpty {
                    tokenMemos = loadedData
                } else {
                    tokenMemos = tokenMemos.filter { $0.title.localizedStandardContains(searchQueryString)
                    }
                }
            })
            #if os(iOS)
            #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
            #endif
            .searchable(
                text: $searchQueryString,
                placement: .navigationBarDrawer,
                prompt: "검색"
            )
            .alert("인증 실패", isPresented: $showAuthAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("보안 메모에 접근하려면 생체 인증이 필요합니다")
            }
            .sheet(isPresented: $showTemplateInputSheet) {
                TemplateInputSheet(
                    placeholders: templatePlaceholders,
                    inputs: $templateInputs,
                    onComplete: {
                        guard let memo = currentTemplateMemo else { return }
                        let processedValue = processTemplateWithInputs(in: memo.value, inputs: templateInputs)
                        finalizeCopy(memo: memo, processedValue: processedValue)
                        showTemplateInputSheet = false
                    },
                    onCancel: {
                        showTemplateInputSheet = false
                    }
                )
            }
            .sheet(item: $selectedTemplateIdForSheet) { templateId in
                TemplateSheetResolver(
                    templateId: templateId,
                    allMemos: tokenMemos,
                    onCopy: { memo, processedValue in
                        print("✅ [SHEET] 복사 버튼 클릭 - 값: \(processedValue)")
                        finalizeCopy(memo: memo, processedValue: processedValue)
                        selectedTemplateIdForSheet = nil
                    },
                    onCancel: {
                        print("❌ [SHEET] 취소 버튼 클릭")
                        selectedTemplateIdForSheet = nil
                    }
                )
            }
            .sheet(isPresented: $showPlaceholderManagementSheet) {
                PlaceholderManagementSheet(allMemos: tokenMemos)
            }
            .sheet(isPresented: $showNewMemoSheet) {
                NavigationStack {
                    MemoAdd()
                }
            }
            .sheet(isPresented: $showClipboardHistorySheet) {
                NavigationStack {
                    ClipboardList()
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                NavigationStack {
                    SettingView()
                }
            }
            .sheet(isPresented: $showMemoListSheet) {
                NavigationStack {
                    TokenMemoList()
                }
            }
            .overlay(content: {
                VStack {
                    Spacer()
                    if !value.isEmpty {
                        ShortcutMemoView(keyword: $keyword,
                                         value: $value,
                                         tokenMemos: $tokenMemos,
                                         originalData: $loadedData,
                                         showShortcutSheet: $showShortcutSheet)
                        .offset(y: 0)
                        .shadow(radius: 15)
                        .opacity(showShortcutSheet ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5).delay(0.3), value: showShortcutSheet)
                    }
                }
            })
            .onAppear {
                print("🎬 [TokenMemoList] onAppear 시작")

                // load
                do {
                    print("📂 [TokenMemoList] 메모 로드 시작...")
                    let loadedMemos = try MemoStore.shared.load(type: .tokenMemo)
                    print("📊 [TokenMemoList] 로드된 메모 개수: \(loadedMemos.count)")

                    tokenMemos = sortMemos(loadedMemos)
                    print("🔄 [TokenMemoList] 메모 정렬 완료")
                    print("📋 [TokenMemoList] 정렬 후 메모 리스트:")
                    for (index, memo) in tokenMemos.enumerated() {
                        print("   [\(index)] \(memo.title) - 즐겨찾기: \(memo.isFavorite), 수정일: \(memo.lastEdited)")
                    }

                    loadedData = tokenMemos
                    print("✅ [TokenMemoList] loadedData에 메모 저장 완료")

                } catch {
                    print("❌ [TokenMemoList] 메모 로드 실패: \(error.localizedDescription)")
                    fatalError(error.localizedDescription)
                }

                // 클립보드 자동 확인 기능 - 클립보드에 내용이 있으면 바로가기 시트 표시
                // iOS 14+에서 처음 실행 시 "Allow Paste" 알림이 뜰 수 있습니다
                // 한 번 허용하면 이후에는 알림 없이 작동합니다
                print("📋 [TokenMemoList] 클립보드 확인 중...")
                let hasClipboard = !(UIPasteboard.general.string?.isEmpty ?? true)
                print("📋 [TokenMemoList] 클립보드 내용 있음: \(hasClipboard), isFirstVisit: \(isFirstVisit)")

                if hasClipboard, isFirstVisit {
                    print("🎯 [TokenMemoList] 클립보드 바로가기 시트 표시 예약")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        print("📱 [TokenMemoList] 바로가기 시트 표시")
                        showShortcutSheet = true
                    }

                    isFirstVisit = false
                    value = UIPasteboard.general.string ?? "error"
                    print("📝 [TokenMemoList] 클립보드 값: \(value)")
                }

                fontSize = UserDefaults.standard.object(forKey: "fontSize") as? CGFloat ?? 20.0
                print("🔤 [TokenMemoList] 폰트 크기: \(fontSize)")

                // 샘플 플레이스홀더 값 추가 (한 번만 실행)
                addSamplePlaceholderValuesIfNeeded()

                #if targetEnvironment(macCatalyst)
                // Mac Catalyst 단축키 리스너 등록
                setupMacCatalystNotifications()
                #endif

                print("✅ [TokenMemoList] onAppear 완료")
            }
            .onDisappear {
                #if targetEnvironment(macCatalyst)
                // 알림 제거
                NotificationCenter.default.removeObserver(self, name: .showNewMemo, object: nil)
                #endif
            }
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
    
    /// Empty list view
    private var EmptyListView: some View {
        VStack(spacing: 5) {
            Image(systemName: "eyes").font(.system(size: 45)).padding(10)
            Text(Constants.nothingToPaste)
                .font(.system(size: 22)).bold()
            Text(Constants.emptyDescription).opacity(0.7)
        }.multilineTextAlignment(.center).padding(30)
    }
    
    private func showToast(message: String) {
        toastMessage = "[\(message)] 이 복사되었습니다."
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showToast = false
        }
    }

    private func copyMemo(memo: Memo) {
        print("📝 [copyMemo] 메모 선택됨: \(memo.title), 템플릿: \(memo.isTemplate)")

        // 템플릿이면 편집 시트 표시
        if memo.isTemplate {
            print("📄 [copyMemo] 템플릿 메모 - TemplateEditSheet 표시")
            print("🔍 [copyMemo] selectedTemplateIdForSheet 설정: \(memo.id)")
            selectedTemplateIdForSheet = memo.id
            print("✅ [copyMemo] selectedTemplateIdForSheet 설정 완료")
            return
        }

        // 일반 메모는 바로 복사
        print("📋 [copyMemo] 일반 메모 - 바로 복사")
        let processedValue = memo.value
        finalizeCopy(memo: memo, processedValue: processedValue)
    }

    private func finalizeCopy(memo: Memo, processedValue: String) {
        UIPasteboard.general.string = processedValue

        // 사용 빈도 증가
        do {
            try MemoStore.shared.incrementClipCount(for: memo.id)
            try MemoStore.shared.addToClipboardHistory(content: processedValue)

            // UI 업데이트를 위해 데이터 리로드
            tokenMemos = sortMemos(try MemoStore.shared.load(type: .tokenMemo))
            loadedData = tokenMemos
        } catch {
            print("Error incrementing clip count: \(error)")
        }

        showToast(message: processedValue)
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

    private func addSamplePlaceholderValuesIfNeeded() {
        // 샘플 데이터 자동 추가 비활성화됨
        return

        // 이미 샘플 데이터를 추가했는지 확인
        let key = "didAddSamplePlaceholderValues"

        // 디버깅: 샘플 데이터를 강제로 다시 추가하려면 아래 주석을 해제하세요
        // UserDefaults.standard.removeObject(forKey: key)
        // print("🔄 [샘플 데이터] 플래그 리셋됨 - 샘플 데이터 재추가")

        if UserDefaults.standard.bool(forKey: key) {
            print("✅ [샘플 데이터] 이미 추가됨 - 스킵")

            // 디버깅: 저장된 데이터 확인
            print("🔍 [샘플 데이터] 저장된 플레이스홀더 값 확인:")
            let testPlaceholders = ["{이름}", "{회사명}"]
            for placeholder in testPlaceholders {
                let values = MemoStore.shared.loadPlaceholderValues(for: placeholder)
                print("   \(placeholder): \(values.count)개 - \(values.map { $0.value })")
            }
            return
        }

        print("🎁 [샘플 데이터] 플레이스홀더 샘플 값 추가 시작")

        do {
            let memos = try MemoStore.shared.load(type: .tokenMemo)

            // "새해인사" 템플릿 찾기
            if let newYearMemo = memos.first(where: { $0.title == "새해인사" && $0.isTemplate }) {
                print("📝 [샘플 데이터] '새해인사' 템플릿 발견")

                // {이름} 플레이스홀더에 샘플 값 추가
                let names = ["유미", "주디", "리이오"]
                for name in names {
                    MemoStore.shared.addPlaceholderValue(
                        name,
                        for: "{이름}",
                        sourceMemoId: newYearMemo.id,
                        sourceMemoTitle: newYearMemo.title
                    )
                    print("   ✓ {이름}에 '\(name)' 추가")
                }

                // {회사명} 플레이스홀더에 샘플 값 추가
                let companies = ["테크코리아", "글로벌인더스트리", "스마트솔루션", "이노베이션", "퓨처테크"]
                for company in companies {
                    MemoStore.shared.addPlaceholderValue(
                        company,
                        for: "{회사명}",
                        sourceMemoId: newYearMemo.id,
                        sourceMemoTitle: newYearMemo.title
                    )
                    print("   ✓ {회사명}에 '\(company)' 추가")
                }

                print("✅ [샘플 데이터] '새해인사' 템플릿에 샘플 값 추가 완료")
            } else {
                print("⚠️ [샘플 데이터] '새해인사' 템플릿을 찾을 수 없음")
            }

            // 모든 템플릿에 대해 공통 플레이스홀더 샘플 추가
            for memo in memos where memo.isTemplate {
                // 템플릿에서 플레이스홀더 추출
                let placeholders = extractCustomPlaceholders(from: memo.value)

                for placeholder in placeholders {
                    // 이미 값이 있는지 확인
                    let existingValues = MemoStore.shared.loadPlaceholderValues(for: placeholder)

                    if existingValues.isEmpty {
                        // 공통 플레이스홀더에 대한 기본 샘플
                        var samples: [String] = []

                        switch placeholder {
                        case "{주소}":
                            samples = ["서울시 강남구", "경기도 성남시", "인천시 남동구"]
                        case "{전화번호}":
                            samples = ["010-1234-5678", "010-9876-5432", "010-5555-1234"]
                        case "{이메일}":
                            samples = ["example@email.com", "user@company.com", "contact@domain.com"]
                        default:
                            // 다른 플레이스홀더는 빈 상태로 유지
                            break
                        }

                        for sample in samples {
                            MemoStore.shared.addPlaceholderValue(
                                sample,
                                for: placeholder,
                                sourceMemoId: memo.id,
                                sourceMemoTitle: memo.title
                            )
                            print("   ✓ \(placeholder)에 '\(sample)' 추가 (템플릿: \(memo.title))")
                        }
                    }
                }
            }

            // 샘플 데이터 추가 완료 플래그 설정
            UserDefaults.standard.set(true, forKey: key)
            UserDefaults.standard.synchronize()
            print("🎉 [샘플 데이터] 모든 샘플 데이터 추가 완료")

        } catch {
            print("❌ [샘플 데이터] 메모 로드 실패: \(error)")
        }
    }

    #if targetEnvironment(macCatalyst)
    // MARK: - Mac Catalyst 단축키 설정
    private func setupMacCatalystNotifications() {
        print("⌨️ [Mac Catalyst] 단축키 알림 리스너 등록")

        NotificationCenter.default.addObserver(
            forName: .showMemoList,
            object: nil,
            queue: .main
        ) { [self] _ in
            print("⌨️ [Mac Catalyst] 메모 목록 단축키 실행 (^⌥K)")
            showMemoListSheet = true
        }

        NotificationCenter.default.addObserver(
            forName: .showNewMemo,
            object: nil,
            queue: .main
        ) { [self] _ in
            print("⌨️ [Mac Catalyst] 새 메모 단축키 실행 (^⌥N)")
            showNewMemoSheet = true
        }

        NotificationCenter.default.addObserver(
            forName: .showClipboardHistory,
            object: nil,
            queue: .main
        ) { [self] _ in
            print("⌨️ [Mac Catalyst] 클립보드 히스토리 단축키 실행 (^⌥H)")
            showClipboardHistorySheet = true
        }

        NotificationCenter.default.addObserver(
            forName: .showSettings,
            object: nil,
            queue: .main
        ) { [self] _ in
            print("⌨️ [Mac Catalyst] 설정 단축키 실행 (⌘,)")
            showSettingsSheet = true
        }
    }
    #endif
}

struct TokenMemoList_Previews: PreviewProvider {
    static var previews: some View {
        TokenMemoList()
    }
}

// Separate view for memo row to reduce complexity
struct MemoRowView: View {
    let memo: Memo
    let fontSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(memo.title,
                  systemImage: memo.isChecked ? "checkmark.square.fill" : "doc.on.doc.fill")
            .font(.system(size: fontSize))

            HStack(spacing: 8) {
                Text(memo.category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)

                if memo.clipCount > 0 {
                    Label("\(memo.clipCount)", systemImage: "chart.bar.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                if memo.isSecure {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                if memo.isTemplate {
                    Image(systemName: "doc.text.fill")
                        .font(.caption)
                        .foregroundColor(.purple)
                }

                if let shortcut = memo.shortcut {
                    Text(":\(shortcut)")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
    }
}

extension Date {
    func toString(format: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }
}

// 템플릿 편집 시트
struct TemplateEditSheet: View {
    let memo: Memo
    let onCopy: (String) -> Void
    let onCancel: () -> Void

    @State private var customPlaceholders: [String] = []
    @State private var placeholderInputs: [String: String] = [:]
    @State private var editedText: String = ""
    @State private var isEditingText: Bool = false

    var previewText: String {
        var result = isEditingText ? editedText : memo.value

        // 커스텀 플레이스홀더 치환
        for (placeholder, value) in placeholderInputs {
            if !value.isEmpty {
                result = result.replacingOccurrences(of: placeholder, with: value)
            }
        }

        // 자동 변수 치환
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

    var body: some View {
        print("🎨 [TemplateEditSheet.body] body 렌더링 시작 - 메모: \(memo.title)")
        print("📊 [TemplateEditSheet.body] customPlaceholders 개수: \(customPlaceholders.count)")
        print("📝 [TemplateEditSheet.body] placeholderInputs 개수: \(placeholderInputs.count)")

        return NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 템플릿 원본
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("템플릿")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            Spacer()

                            Button {
                                isEditingText.toggle()
                                if isEditingText {
                                    editedText = memo.value
                                }
                            } label: {
                                Text(isEditingText ? "완료" : "수정")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                        }

                        if isEditingText {
                            TextEditor(text: $editedText)
                                .font(.body)
                                .frame(minHeight: 100)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        } else {
                            Text(memo.value)
                                .font(.body)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }

                    // 플레이스홀더 입력
                    if customPlaceholders.isEmpty {
                        // 플레이스홀더가 없는 경우
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.green)

                            Text("설정할 값이 없습니다")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text("이 템플릿은 바로 사용 가능합니다")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Text("값 선택")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                Spacer()

                                // 안내 메시지
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text("값을 선택하세요")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            ForEach(customPlaceholders, id: \.self) { placeholder in
                                PlaceholderSelectorView(
                                    placeholder: placeholder,
                                    sourceMemoId: memo.id,
                                    sourceMemoTitle: memo.title,
                                    selectedValue: Binding(
                                        get: { placeholderInputs[placeholder] ?? "" },
                                        set: { placeholderInputs[placeholder] = $0 }
                                    )
                                )
                            }
                        }
                    }

                    // 미리보기
                    VStack(alignment: .leading, spacing: 8) {
                        Text("미리보기")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        Text(previewText)
                            .font(.body)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle(memo.title)
            #if os(iOS)
            #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("복사") {
                        onCopy(previewText)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            print("🎬 [TemplateEditSheet] onAppear 시작 - 메모: \(memo.title)")
            extractCustomPlaceholders()
            loadPlaceholderDefaults()
            print("✅ [TemplateEditSheet] onAppear 완료")
        }
    }

    private func extractCustomPlaceholders() {
        print("🔍 [TemplateEditSheet] 플레이스홀더 추출 시작")
        let autoVariables = ["{날짜}", "{시간}", "{연도}", "{월}", "{일}"]
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            print("❌ [TemplateEditSheet] 정규식 생성 실패")
            return
        }

        let text = memo.value
        print("📄 [TemplateEditSheet] 템플릿 내용: \(text)")
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var placeholders: [String] = []

        for match in matches {
            if let range = Range(match.range, in: text) {
                let placeholder = String(text[range])
                if !autoVariables.contains(placeholder) && !placeholders.contains(placeholder) {
                    placeholders.append(placeholder)
                    print("   ✓ 발견: \(placeholder)")
                }
            }
        }

        customPlaceholders = placeholders
        print("📊 [TemplateEditSheet] 총 \(placeholders.count)개 플레이스홀더 발견: \(placeholders)")
    }

    private func loadPlaceholderDefaults() {
        print("📥 [TemplateEditSheet] 기본값 로드 시작")
        for placeholder in customPlaceholders {
            // 새로운 형식으로 로드
            print("   플레이스홀더: \(placeholder)")
            let values = MemoStore.shared.loadPlaceholderValues(for: placeholder)
            print("   로드된 값: \(values.count)개")

            if let firstValue = values.first {
                placeholderInputs[placeholder] = firstValue.value
                print("   ✓ 기본값 설정: \(firstValue.value) (출처: \(firstValue.sourceMemoTitle))")
            } else {
                placeholderInputs[placeholder] = ""
                print("   ⚠️ 값 없음 - 빈 문자열 설정")
            }
        }
        print("✅ [TemplateEditSheet] 기본값 로드 완료: \(placeholderInputs)")
    }
}

// 플레이스홀더 선택 뷰 (수정 가능)
struct PlaceholderSelectorView: View {
    let placeholder: String
    let sourceMemoId: UUID
    let sourceMemoTitle: String
    @Binding var selectedValue: String

    @State private var values: [PlaceholderValue] = []
    @State private var isAdding: Bool = false
    @State private var newValue: String = ""
    @State private var showDeleteConfirm: PlaceholderValue? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(placeholder.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    isAdding.toggle()
                } label: {
                    Image(systemName: isAdding ? "xmark.circle.fill" : "plus.circle.fill")
                        .foregroundColor(isAdding ? .red : .blue)
                        .font(.system(size: 18))
                }
            }

            // 값 추가 입력
            if isAdding {
                HStack(spacing: 8) {
                    TextField("새 값 입력", text: $newValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout)

                    Button {
                        if !newValue.isEmpty && !values.contains(where: { $0.value == newValue }) {
                            // 새 값 추가 (출처 정보 포함)
                            MemoStore.shared.addPlaceholderValue(
                                newValue,
                                for: placeholder,
                                sourceMemoId: sourceMemoId,
                                sourceMemoTitle: sourceMemoTitle
                            )
                            loadValues()
                            selectedValue = newValue
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

            // 값 목록
            if values.isEmpty {
                Text("+ 버튼을 눌러 값을 추가하세요")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(values) { placeholderValue in
                            HStack(spacing: 6) {
                                Button {
                                    selectedValue = placeholderValue.value
                                } label: {
                                    Text(placeholderValue.value)
                                        .font(.system(size: 14, weight: selectedValue == placeholderValue.value ? .semibold : .regular))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedValue == placeholderValue.value ? Color.blue : Color(.systemGray5))
                                        .foregroundColor(selectedValue == placeholderValue.value ? .white : .primary)
                                        .cornerRadius(16)
                                }

                                Button {
                                    showDeleteConfirm = placeholderValue
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .onAppear {
            print("🎬 [PlaceholderSelectorView] onAppear - 플레이스홀더: \(placeholder)")
            loadValues()
            print("✅ [PlaceholderSelectorView] onAppear 완료 - 로드된 값: \(values.count)개, 선택된 값: '\(selectedValue)'")
        }
        .alert("삭제 확인", isPresented: .constant(showDeleteConfirm != nil)) {
            Button("취소", role: .cancel) {
                showDeleteConfirm = nil
            }
            Button("삭제", role: .destructive) {
                if let valueToDelete = showDeleteConfirm {
                    MemoStore.shared.deletePlaceholderValue(valueId: valueToDelete.id, for: placeholder)
                    loadValues()
                    if selectedValue == valueToDelete.value {
                        selectedValue = ""
                    }
                }
                showDeleteConfirm = nil
            }
        } message: {
            if let value = showDeleteConfirm {
                Text("'\(value.value)'을(를) 삭제하시겠습니까?")
            }
        }
    }

    private func loadValues() {
        print("   📥 [PlaceholderSelectorView.loadValues] 값 로드 중...")
        values = MemoStore.shared.loadPlaceholderValues(for: placeholder)
        print("   ✅ [PlaceholderSelectorView.loadValues] 완료 - \(values.count)개")
    }
}

// 템플릿 입력 시트
struct TemplateInputSheet: View {
    let placeholders: [String]
    @Binding var inputs: [String: String]
    let onComplete: () -> Void
    let onCancel: () -> Void

    @FocusState private var focusedField: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("템플릿을 완성하세요")
                        .font(.headline)
                        .foregroundColor(.secondary)
                } header: {
                    EmptyView()
                }

                Section {
                    ForEach(placeholders, id: \.self) { placeholder in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(placeholder.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("입력하세요", text: Binding(
                                get: { inputs[placeholder] ?? "" },
                                set: { inputs[placeholder] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: placeholder)
                            .submitLabel(.next)
                            .onSubmit {
                                // 다음 필드로 이동
                                if let currentIndex = placeholders.firstIndex(of: placeholder),
                                   currentIndex < placeholders.count - 1 {
                                    focusedField = placeholders[currentIndex + 1]
                                } else {
                                    focusedField = nil
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("템플릿 입력")
            #if os(iOS)
            #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("복사") {
                        onComplete()
                    }
                    .disabled(inputs.values.contains(where: { $0.isEmpty }))
                }
            }
            .onAppear {
                // 첫 번째 필드에 자동 포커스
                if let first = placeholders.first {
                    focusedField = first
                }
            }
        }
    }
}

// 플레이스홀더 관리 시트
struct PlaceholderManagementSheet: View {
    let allMemos: [Memo]
    @Environment(\.dismiss) private var dismiss

    var templateMemos: [Memo] {
        allMemos.filter { $0.isTemplate }
    }

    var body: some View {
        NavigationStack {
            if templateMemos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("템플릿이 없습니다")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("템플릿 메모를 생성하고 {} 를 사용하면\n여기서 관리할 수 있습니다")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("플레이스홀더 관리")
                #if os(iOS)
            #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
            #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("완료") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            } else {
                List {
                    ForEach(templateMemos) { template in
                        NavigationLink {
                            TemplateDetailPlaceholderView(template: template)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.title)
                                    .font(.headline)

                                Text(extractPlaceholderPreview(from: template.value))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .navigationTitle("플레이스홀더 관리")
                #if os(iOS)
            #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
            #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("완료") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func extractPlaceholderPreview(from text: String) -> String {
        let autoVariables = ["{날짜}", "{시간}", "{연도}", "{월}", "{일}"]
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return "플레이스홀더 없음" }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var placeholders: [String] = []

        for match in matches {
            if let range = Range(match.range, in: text) {
                let placeholder = String(text[range])
                if !autoVariables.contains(placeholder) && !placeholders.contains(placeholder) {
                    placeholders.append(placeholder)
                }
            }
        }

        if placeholders.isEmpty {
            return "플레이스홀더 없음"
        }

        return placeholders.map { $0.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "") }.joined(separator: ", ")
    }
}

// 템플릿별 플레이스홀더 상세 관리 화면
struct TemplateDetailPlaceholderView: View {
    let template: Memo
    @State private var placeholders: [String] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 템플릿 미리보기
                VStack(alignment: .leading, spacing: 8) {
                    Text("템플릿 내용")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Text(template.value)
                        .font(.body)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top)

                // 플레이스홀더 목록
                if placeholders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)

                        Text("이 템플릿에는 플레이스홀더가 없습니다")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 50)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("플레이스홀더 (\(placeholders.count)개)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            ForEach(placeholders, id: \.self) { placeholder in
                                TemplatePlaceholderRow(
                                    placeholder: placeholder,
                                    templateId: template.id,
                                    templateTitle: template.title
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle(template.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            extractPlaceholders()
        }
    }

    private func extractPlaceholders() {
        let autoVariables = ["{날짜}", "{시간}", "{연도}", "{월}", "{일}"]
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let matches = regex.matches(in: template.value, range: NSRange(template.value.startIndex..., in: template.value))
        var extractedPlaceholders: [String] = []

        for match in matches {
            if let range = Range(match.range, in: template.value) {
                let placeholder = String(template.value[range])
                if !autoVariables.contains(placeholder) && !extractedPlaceholders.contains(placeholder) {
                    extractedPlaceholders.append(placeholder)
                }
            }
        }

        placeholders = extractedPlaceholders
    }
}

// 템플릿 내의 개별 플레이스홀더 행
struct TemplatePlaceholderRow: View {
    let placeholder: String
    let templateId: UUID
    let templateTitle: String

    @State private var values: [PlaceholderValue] = []
    @State private var showDeleteConfirm: PlaceholderValue? = nil
    @State private var editingValue: PlaceholderValue? = nil
    @State private var editText: String = ""
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더 - 전체 영역이 터치 가능
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(placeholder.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("값 \(values.count)개")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 20)

                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 24))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }

            // 확장된 내용
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                // 값 목록
                VStack(spacing: 12) {
                    if values.isEmpty {
                        Text("값이 없습니다.\n템플릿 사용 시 값을 추가하세요.")
                            .font(.callout)
                            .foregroundColor(.orange)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                            .multilineTextAlignment(.center)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(values) { value in
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(value.value)
                                            .font(.body)
                                            .fontWeight(.semibold)

                                        Text(formatDate(value.addedAt))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    HStack(spacing: 16) {
                                        Button {
                                            editingValue = value
                                            editText = value.value
                                        } label: {
                                            Image(systemName: "pencil.circle.fill")
                                                .font(.system(size: 28))
                                                .foregroundColor(.blue)
                                        }

                                        Button {
                                            showDeleteConfirm = value
                                        } label: {
                                            Image(systemName: "trash.circle.fill")
                                                .font(.system(size: 28))
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .onAppear {
            loadValues()
        }
        .alert("삭제 확인", isPresented: .constant(showDeleteConfirm != nil)) {
            Button("취소", role: .cancel) {
                showDeleteConfirm = nil
            }
            Button("삭제", role: .destructive) {
                if let valueToDelete = showDeleteConfirm {
                    MemoStore.shared.deletePlaceholderValue(valueId: valueToDelete.id, for: placeholder)
                    loadValues()
                }
                showDeleteConfirm = nil
            }
        } message: {
            if let value = showDeleteConfirm {
                Text("'\(value.value)'을(를) 삭제하시겠습니까?")
            }
        }
        .alert("값 수정", isPresented: .constant(editingValue != nil)) {
            TextField("값", text: $editText)
            Button("취소", role: .cancel) {
                editingValue = nil
            }
            Button("저장") {
                if let oldValue = editingValue, !editText.isEmpty {
                    // 기존 값 삭제
                    MemoStore.shared.deletePlaceholderValue(valueId: oldValue.id, for: placeholder)
                    // 새 값 추가
                    MemoStore.shared.addPlaceholderValue(editText, for: placeholder, sourceMemoId: templateId, sourceMemoTitle: templateTitle)
                    loadValues()
                }
                editingValue = nil
            }
        } message: {
            if let value = editingValue {
                Text("'\(value.value)' 값을 수정하세요.")
            }
        }
    }

    private func loadValues() {
        values = MemoStore.shared.loadPlaceholderValues(for: placeholder)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// 플레이스홀더 관리 행 (출처 정보 포함) - DEPRECATED, 사용하지 않음
struct PlaceholderManagementRow: View {
    let placeholder: String

    @State private var values: [PlaceholderValue] = []
    @State private var showDeleteConfirm: PlaceholderValue? = nil
    @State private var isExpanded: Bool = false
    @State private var editingValue: PlaceholderValue? = nil
    @State private var editText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(placeholder.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("값 \(values.count)개")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .buttonStyle(PlainButtonStyle())

            // 확장된 내용
            if isExpanded {
                Divider()

                HStack {
                    Text("값 목록")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("템플릿에서 값을 추가하세요")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 값 목록
                if values.isEmpty {
                    Text("값이 없습니다.\n템플릿 메모에서 값을 추가하세요.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .multilineTextAlignment(.center)
                } else {
                    VStack(spacing: 8) {
                        ForEach(values) { value in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(value.value)
                                            .font(.body)
                                            .fontWeight(.semibold)

                                        HStack(spacing: 6) {
                                            Image(systemName: "doc.text.fill")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                            Text(value.sourceMemoTitle)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Text(formatDate(value.addedAt))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    HStack(spacing: 12) {
                                        Button {
                                            editingValue = value
                                            editText = value.value
                                        } label: {
                                            Image(systemName: "pencil")
                                                .font(.system(size: 14))
                                                .foregroundColor(.blue)
                                        }

                                        Button {
                                            showDeleteConfirm = value
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 14))
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .onAppear {
            loadValues()
        }
        .alert("삭제 확인", isPresented: .constant(showDeleteConfirm != nil)) {
            Button("취소", role: .cancel) {
                showDeleteConfirm = nil
            }
            Button("삭제", role: .destructive) {
                if let valueToDelete = showDeleteConfirm {
                    MemoStore.shared.deletePlaceholderValue(valueId: valueToDelete.id, for: placeholder)
                    loadValues()
                }
                showDeleteConfirm = nil
            }
        } message: {
            if let value = showDeleteConfirm {
                Text("'\(value.value)'을(를) 삭제하시겠습니까?\n\n출처: \(value.sourceMemoTitle)")
            }
        }
        .alert("값 수정", isPresented: .constant(editingValue != nil)) {
            TextField("값", text: $editText)
            Button("취소", role: .cancel) {
                editingValue = nil
                editText = ""
            }
            Button("저장") {
                if let valueToEdit = editingValue, !editText.isEmpty {
                    // 기존 값 삭제
                    MemoStore.shared.deletePlaceholderValue(valueId: valueToEdit.id, for: placeholder)
                    // 새 값 추가 (출처 정보 유지)
                    MemoStore.shared.addPlaceholderValue(
                        editText,
                        for: placeholder,
                        sourceMemoId: valueToEdit.sourceMemoId,
                        sourceMemoTitle: valueToEdit.sourceMemoTitle
                    )
                    loadValues()
                }
                editingValue = nil
                editText = ""
            }
        } message: {
            if let value = editingValue {
                Text("'\(value.value)' 값을 수정하세요.\n\n출처: \(value.sourceMemoTitle)")
            }
        }
    }

    private func loadValues() {
        values = MemoStore.shared.loadPlaceholderValues(for: placeholder)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// Template Sheet Resolver - UUID를 Identifiable로 만들고 메모를 찾아서 TemplateEditSheet 표시
struct TemplateSheetResolver: View {
    let templateId: UUID
    let allMemos: [Memo]
    let onCopy: (Memo, String) -> Void
    let onCancel: () -> Void

    @State private var loadedMemo: Memo? = nil
    @State private var isLoading: Bool = false

    var body: some View {
        Group {
            if let memo = loadedMemo {
                TemplateEditSheet(
                    memo: memo,
                    onCopy: { processedValue in
                        onCopy(memo, processedValue)
                    },
                    onCancel: onCancel
                )
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)

                    Text("템플릿 불러오는 중...")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            print("🎬 [TemplateSheetResolver] onAppear - ID: \(templateId)")
            loadMemo()
        }
    }

    private func loadMemo() {
        guard !isLoading else {
            print("⚠️ [TemplateSheetResolver] 이미 로딩 중...")
            return
        }

        isLoading = true
        print("🔄 [TemplateSheetResolver] 메모 로드 시작 - ID: \(templateId)")

        // 1. 먼저 현재 메모리의 allMemos에서 찾기
        if let memo = allMemos.first(where: { $0.id == templateId }) {
            print("✅ [TemplateSheetResolver] 메모리에서 메모 찾음: \(memo.title)")
            loadedMemo = memo
            isLoading = false
            return
        }

        // 2. 메모리에 없으면 파일에서 다시 로드
        print("🔍 [TemplateSheetResolver] 메모리에 없음 - 파일에서 로드 시도")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let memos = try MemoStore.shared.load(type: .tokenMemo)
                print("📥 [TemplateSheetResolver] 파일에서 \(memos.count)개 메모 로드됨")

                if let memo = memos.first(where: { $0.id == templateId }) {
                    DispatchQueue.main.async {
                        print("✅ [TemplateSheetResolver] 파일에서 메모 찾음: \(memo.title)")
                        loadedMemo = memo
                        isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        print("❌ [TemplateSheetResolver] 메모를 찾을 수 없음 - ID: \(templateId)")
                        isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print("❌ [TemplateSheetResolver] 메모 로드 실패: \(error)")
                    isLoading = false
                }
            }
        }
    }
}

// UUID를 Identifiable로 만들기 위한 extension
extension UUID: Identifiable {
    public var id: UUID { self }
}
