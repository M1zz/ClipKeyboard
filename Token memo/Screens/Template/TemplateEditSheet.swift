//
//  TemplateEditSheet.swift
//  Token memo
//
//  Created by Leeo on 12/11/25.
//

import SwiftUI

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
            .navigationBarTitleDisplayMode(.inline)
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
            .navigationBarTitleDisplayMode(.inline)
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
