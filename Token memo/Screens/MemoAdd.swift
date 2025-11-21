//
//  MemoAdd.swift
//  Token memo
//
//  Created by hyunho lee on 2023/05/15.
//

import SwiftUI

struct MemoAdd: View {

    @State private var keyword: String = ""
    @State private var value: String = ""
    @State private var showAlert: Bool = false
    @State private var showSucessAlert: Bool = false

    // 수정 모드용 초기값
    var insertedKeyword: String = ""
    var insertedValue: String = ""
    var insertedCategory: String = "기본"
    var insertedIsTemplate: Bool = false
    var insertedIsSecure: Bool = false
    var insertedShortcut: String = ""

    // 새로운 기능들
    @State private var selectedCategory: String = "기본"
    @State private var isSecure: Bool = false
    @State private var isTemplate: Bool = false
    @State private var shortcut: String = ""
    @FocusState private var isFocused: Bool

    // 템플릿 플레이스홀더 값 설정
    @State private var detectedPlaceholders: [String] = []
    @State private var placeholderValues: [String: [String]] = [:]
    @State private var showingPlaceholderEditor: String? = nil
    @State private var newValue: String = ""

    let categories = ["기본", "은행", "주소", "이메일", "전화번호", "비밀번호", "기타"]

    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    // 제목 입력
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

                    // 내용 입력
                    VStack(alignment: .leading, spacing: 10) {
                        Text("내용")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        ZStack(alignment: .topLeading) {
                            if value.isEmpty {
                                Text("메모 내용을 입력하세요")
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
                                .focused($isFocused)
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
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

                    // 카테고리 선택
                    VStack(alignment: .leading, spacing: 10) {
                        Text("카테고리")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categories, id: \.self) { category in
                                    Button {
                                        selectedCategory = category
                                    } label: {
                                        Text(category)
                                            .font(.callout)
                                            .fontWeight(selectedCategory == category ? .semibold : .regular)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(selectedCategory == category ? Color.accentColor : Color(.systemGray6))
                                            .foregroundColor(selectedCategory == category ? .white : .primary)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }
                    }

                    // 스니펫 축약어
                    VStack(alignment: .leading, spacing: 10) {
                        Text("스니펫 축약어")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        TextField("예: addr, pw 등 (선택)", text: $shortcut)
                            .font(.body)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }

                    // 옵션들
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
            VStack(spacing: 12) {
                Divider()

                HStack(spacing: 12) {
                    Button {
                        keyword = ""
                        value = ""
                        shortcut = ""
                        selectedCategory = "기본"
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

                                let newMemo = Memo(
                                    title: keyword,
                                    value: value,
                                    lastEdited: Date(),
                                    category: selectedCategory,
                                    isSecure: isSecure,
                                    isTemplate: isTemplate,
                                    templateVariables: variables,
                                    shortcut: shortcut.isEmpty ? nil : shortcut
                                )

                                loadedMemos.append(newMemo)
                                try MemoStore.shared.save(memos: loadedMemos, type: .tokenMemo)

                                // 플레이스홀더 값들 저장
                                savePlaceholderValues()
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
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
        }
        .alert(Constants.insertContents, isPresented: $showAlert) {
            
        }
        .alert("Completed!", isPresented: $showSucessAlert) {
            Button("Ok", role: .cancel) {
                dismiss()
            }
        }
        .onAppear {
            // 수정 모드 초기화
            if !insertedKeyword.isEmpty {
                keyword = insertedKeyword
            }

            if !insertedValue.isEmpty {
                value = insertedValue
            }

            selectedCategory = insertedCategory
            isTemplate = insertedIsTemplate
            isSecure = insertedIsSecure
            shortcut = insertedShortcut

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
            let key = "predefined_\(placeholder)"
            if let saved = UserDefaults(suiteName: "group.com.hyunho.Token-memo")?.stringArray(forKey: key) {
                placeholderValues[placeholder] = saved
            }
        }
    }

    // 플레이스홀더 값 저장
    private func savePlaceholderValues() {
        for (placeholder, values) in placeholderValues where !values.isEmpty {
            let key = "predefined_\(placeholder)"
            UserDefaults(suiteName: "group.com.hyunho.Token-memo")?.set(values, forKey: key)
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
