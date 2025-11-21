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
    @State private var showTemplateEditSheet = false
    @State private var selectedMemo: Memo? = nil

    // 플레이스홀더 관리 시트
    @State private var showPlaceholderManagementSheet = false
    
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
                                // TODO: Enable after adding BiometricAuthManager.swift to Xcode project
                                // if memo.isSecure {
                                //     BiometricAuthManager.shared.authenticateUser { success, error in
                                //         if success {
                                //             copyMemo(memo: memo)
                                //         } else {
                                //             showAuthAlert = true
                                //         }
                                //     }
                                // } else {
                                    copyMemo(memo: memo)
                                // }
                            } label: {
                                MemoRowView(memo: memo, fontSize: fontSize)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    NavigationLink {
                                        MemoAdd(
                                            insertedKeyword: memo.title,
                                            insertedValue: memo.value,
                                            insertedCategory: memo.category,
                                            insertedIsTemplate: memo.isTemplate,
                                            insertedIsSecure: memo.isSecure,
                                            insertedShortcut: memo.shortcut ?? ""
                                        )
                                    } label: {
                                        Label("update", systemImage: "pencil")
                                    }
                                    .tint(.green)
                                }
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
            .navigationBarTitleDisplayMode(.inline)
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
            .sheet(isPresented: $showTemplateEditSheet) {
                if let memo = selectedMemo {
                    TemplateEditSheet(
                        memo: memo,
                        onCopy: { processedValue in
                            finalizeCopy(memo: memo, processedValue: processedValue)
                            showTemplateEditSheet = false
                        },
                        onCancel: {
                            showTemplateEditSheet = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showPlaceholderManagementSheet) {
                PlaceholderManagementSheet(allMemos: tokenMemos)
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
                // load
                do {
                    tokenMemos = sortMemos(try MemoStore.shared.load(type: .tokenMemo))
                    //tokenMemos.sort {$0.lastEdited > $1.lastEdited}
                    loadedData = tokenMemos
                    
                } catch {
                    fatalError(error.localizedDescription)
                }
                
                if !(UIPasteboard.general.string?.isEmpty ?? true),
                   isFirstVisit {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        showShortcutSheet = true
                    }
                    
                    isFirstVisit = false
                    value = UIPasteboard.general.string ?? "error"
                }
                
                fontSize = UserDefaults.standard.object(forKey: "fontSize") as? CGFloat ?? 20.0
            }
        }
    }

    private func sortMemos(_ memos: [Memo]) -> [Memo] {
        return memos.sorted { (memo1, memo2) -> Bool in
            if memo1.isFavorite != memo2.isFavorite {
                return memo1.isFavorite && !memo2.isFavorite
            } else {
                return memo1.lastEdited > memo2.lastEdited
            }
        }
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
        // 템플릿이면 편집 시트 표시
        if memo.isTemplate {
            selectedMemo = memo
            showTemplateEditSheet = true
            return
        }

        // 일반 메모는 바로 복사
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
        NavigationStack {
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
                    if !customPlaceholders.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("값 선택")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            ForEach(customPlaceholders, id: \.self) { placeholder in
                                PlaceholderSelectorView(
                                    placeholder: placeholder,
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
            .navigationBarTitleDisplayMode(.inline)
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
            extractCustomPlaceholders()
            loadPlaceholderDefaults()
        }
    }

    private func extractCustomPlaceholders() {
        let autoVariables = ["{날짜}", "{시간}", "{연도}", "{월}", "{일}"]
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let text = memo.value
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

        customPlaceholders = placeholders
    }

    private func loadPlaceholderDefaults() {
        for placeholder in customPlaceholders {
            placeholderInputs[placeholder] = ""
        }
    }
}

// 플레이스홀더 선택 뷰 (수정 가능)
struct PlaceholderSelectorView: View {
    let placeholder: String
    @Binding var selectedValue: String

    @State private var values: [String] = []
    @State private var isAdding: Bool = false
    @State private var newValue: String = ""
    @State private var showDeleteConfirm: String? = nil

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
                        if !newValue.isEmpty && !values.contains(newValue) {
                            values.append(newValue)
                            saveValues()
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
                        ForEach(values, id: \.self) { value in
                            HStack(spacing: 6) {
                                Button {
                                    selectedValue = value
                                } label: {
                                    Text(value)
                                        .font(.system(size: 14, weight: selectedValue == value ? .semibold : .regular))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedValue == value ? Color.blue : Color(.systemGray5))
                                        .foregroundColor(selectedValue == value ? .white : .primary)
                                        .cornerRadius(16)
                                }

                                Button {
                                    showDeleteConfirm = value
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
            loadValues()
        }
        .alert("삭제 확인", isPresented: .constant(showDeleteConfirm != nil)) {
            Button("취소", role: .cancel) {
                showDeleteConfirm = nil
            }
            Button("삭제", role: .destructive) {
                if let valueToDelete = showDeleteConfirm {
                    values.removeAll { $0 == valueToDelete }
                    saveValues()
                    if selectedValue == valueToDelete {
                        selectedValue = ""
                    }
                }
                showDeleteConfirm = nil
            }
        } message: {
            if let value = showDeleteConfirm {
                Text("'\(value)'을(를) 삭제하시겠습니까?")
            }
        }
    }

    private func loadValues() {
        let key = "predefined_\(placeholder)"
        if let saved = UserDefaults(suiteName: "group.com.hyunho.Token-memo")?.stringArray(forKey: key) {
            values = saved
        }
    }

    private func saveValues() {
        let key = "predefined_\(placeholder)"
        UserDefaults(suiteName: "group.com.hyunho.Token-memo")?.set(values, forKey: key)
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
            .navigationBarTitleDisplayMode(.inline)
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

    @State private var allPlaceholders: [String] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if allPlaceholders.isEmpty {
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
                        .padding(.top, 50)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(allPlaceholders, id: \.self) { placeholder in
                                PlaceholderManagementRow(placeholder: placeholder)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("플레이스홀더 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                extractAllPlaceholders()
            }
        }
    }

    private func extractAllPlaceholders() {
        let autoVariables = ["{날짜}", "{시간}", "{연도}", "{월}", "{일}"]
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        var placeholders: Set<String> = []

        // 모든 템플릿 메모에서 플레이스홀더 추출
        for memo in allMemos where memo.isTemplate {
            let matches = regex.matches(in: memo.value, range: NSRange(memo.value.startIndex..., in: memo.value))

            for match in matches {
                if let range = Range(match.range, in: memo.value) {
                    let placeholder = String(memo.value[range])
                    if !autoVariables.contains(placeholder) {
                        placeholders.insert(placeholder)
                    }
                }
            }
        }

        allPlaceholders = Array(placeholders).sorted()
    }
}

// 플레이스홀더 관리 행
struct PlaceholderManagementRow: View {
    let placeholder: String

    @State private var values: [String] = []
    @State private var isAdding: Bool = false
    @State private var newValue: String = ""
    @State private var showDeleteConfirm: String? = nil
    @State private var isExpanded: Bool = false

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

                    Button {
                        isAdding.toggle()
                    } label: {
                        Label(isAdding ? "취소" : "추가", systemImage: isAdding ? "xmark.circle.fill" : "plus.circle.fill")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(isAdding ? .red : .blue)
                    }
                }

                // 값 추가 입력
                if isAdding {
                    HStack(spacing: 8) {
                        TextField("새 값 입력", text: $newValue)
                            .textFieldStyle(.roundedBorder)
                            .font(.callout)

                        Button("추가") {
                            if !newValue.isEmpty && !values.contains(newValue) {
                                values.append(newValue)
                                saveValues()
                                newValue = ""
                                isAdding = false
                            }
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(newValue.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(newValue.isEmpty)
                    }
                }

                // 값 목록
                if values.isEmpty {
                    Text("값이 없습니다. + 버튼을 눌러 추가하세요.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(values, id: \.self) { value in
                            HStack {
                                Text(value)
                                    .font(.body)

                                Spacer()

                                Button {
                                    showDeleteConfirm = value
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
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
                    values.removeAll { $0 == valueToDelete }
                    saveValues()
                }
                showDeleteConfirm = nil
            }
        } message: {
            if let value = showDeleteConfirm {
                Text("'\(value)'을(를) 삭제하시겠습니까?")
            }
        }
    }

    private func loadValues() {
        let key = "predefined_\(placeholder)"
        if let saved = UserDefaults(suiteName: "group.com.hyunho.Token-memo")?.stringArray(forKey: key) {
            values = saved
        }
    }

    private func saveValues() {
        let key = "predefined_\(placeholder)"
        UserDefaults(suiteName: "group.com.hyunho.Token-memo")?.set(values, forKey: key)
    }
}
