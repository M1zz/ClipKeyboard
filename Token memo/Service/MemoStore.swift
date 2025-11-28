//
//  MemoStore.swift
//  Token memo
//
//  Created by hyunho lee on 2023/05/16.
//

import Foundation

enum MemoType {
    case tokenMemo
    case clipboardHistory
}

class MemoStore: ObservableObject {
    static let shared = MemoStore()
    
    @Published var memos: [Memo] = []
    @Published var clipboardHistory: [ClipboardHistory] = []
    
    private static func fileURL(type: MemoType) throws -> URL? {
        print("📁 [MemoStore.fileURL] App Group 컨테이너 경로 확인 중...")

        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo") else {
            print("❌ [MemoStore.fileURL] App Group 컨테이너를 찾을 수 없음!")
            return URL(string: "")
        }

        print("✅ [MemoStore.fileURL] App Group 컨테이너: \(containerURL.path)")

        let fileURL: URL
        switch type {
        case .tokenMemo:
            fileURL = containerURL.appendingPathComponent("memos.data")
            print("📄 [MemoStore.fileURL] 메모 파일: \(fileURL.path)")
        case .clipboardHistory:
            fileURL = containerURL.appendingPathComponent("clipboard.history.data")
            print("📄 [MemoStore.fileURL] 클립보드 히스토리 파일: \(fileURL.path)")
        }

        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        print("🔍 [MemoStore.fileURL] 파일 존재 여부: \(fileExists)")

        return fileURL
    }
    
    func save(memos: [Memo], type: MemoType) throws {
        let data = try JSONEncoder().encode(memos)
        guard let outfile = try Self.fileURL(type: type) else { return }
        try data.write(to: outfile)
    }

    func saveClipboardHistory(history: [ClipboardHistory]) throws {
        let data = try JSONEncoder().encode(history)
        guard let outfile = try Self.fileURL(type: .clipboardHistory) else { return }
        try data.write(to: outfile)
    }
    
    func load(type: MemoType) throws -> [Memo] {
        print("📥 [MemoStore.load] 시작 - type: \(type)")

        guard let fileURL = try Self.fileURL(type: type) else {
            print("⚠️ [MemoStore.load] fileURL을 가져올 수 없음 - 빈 배열 반환")
            return []
        }

        print("📍 [MemoStore.load] 파일 경로: \(fileURL.path)")

        guard let data = try? Data(contentsOf: fileURL) else {
            print("⚠️ [MemoStore.load] 파일에서 데이터를 읽을 수 없음 - 빈 배열 반환")
            return []
        }

        print("💾 [MemoStore.load] 데이터 크기: \(data.count) bytes")

        var memos: [Memo] = []

        // 새 형식으로 디코딩 시도
        if let newMemos = try? JSONDecoder().decode([Memo].self, from: data) {
            print("✅ [MemoStore.load] 새 형식(Memo)으로 디코딩 성공 - \(newMemos.count)개")
            memos = newMemos

            // 각 메모 정보 출력
            for (index, memo) in newMemos.enumerated() {
                print("   [\(index)] ID: \(memo.id)")
                print("       제목: \(memo.title)")
                print("       카테고리: \(memo.category)")
                print("       즐겨찾기: \(memo.isFavorite)")
                print("       템플릿: \(memo.isTemplate)")
                print("       보안: \(memo.isSecure)")
                print("       수정일: \(memo.lastEdited)")
                print("       사용횟수: \(memo.clipCount)")
                print("       플레이스홀더 값: \(memo.placeholderValues)")
            }
        } else {
            // 이전 형식으로 디코딩 시도
            print("🔄 [MemoStore.load] 새 형식 디코딩 실패 - 이전 형식(OldMemo) 시도")

            if let oldMemos = try? JSONDecoder().decode([OldMemo].self, from: data) {
                print("✅ [MemoStore.load] 이전 형식(OldMemo)으로 디코딩 성공 - \(oldMemos.count)개")
                print("🔄 [MemoStore.load] 이전 형식 -> 새 형식 변환 중...")

                oldMemos.forEach { oldMemo in
                    let converted = Memo(from: oldMemo)
                    memos.append(converted)
                    print("   변환: \(oldMemo.title) -> Memo")
                }

                print("✅ [MemoStore.load] 변환 완료 - \(memos.count)개")
            } else {
                print("❌ [MemoStore.load] 모든 형식 디코딩 실패")
            }
        }

        print("🏁 [MemoStore.load] 완료 - 반환: \(memos.count)개")
        return memos
    }
    
    func loadClipboardHistory() throws -> [ClipboardHistory] {
        guard let fileURL = try Self.fileURL(type: .clipboardHistory) else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        if let history = try? JSONDecoder().decode([ClipboardHistory].self, from: data) {
            return history
        }
        return []
    }

    // 사용 빈도 증가
    func incrementClipCount(for memoId: UUID) throws {
        var memos = try load(type: .tokenMemo)
        if let index = memos.firstIndex(where: { $0.id == memoId }) {
            memos[index].clipCount += 1
            memos[index].lastEdited = Date()
            try save(memos: memos, type: .tokenMemo)
        }
    }

    // 클립보드 히스토리 추가
    func addToClipboardHistory(content: String) throws {
        var history = try loadClipboardHistory()

        // 중복 제거
        history.removeAll { $0.content == content }

        // 새 항목 추가
        let newItem = ClipboardHistory(content: content)
        history.insert(newItem, at: 0)

        // 최대 100개까지만 유지
        if history.count > 100 {
            history = Array(history.prefix(100))
        }

        // 7일 이상 된 임시 항목 자동 삭제
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        history.removeAll { $0.isTemporary && $0.copiedAt < sevenDaysAgo }

        try saveClipboardHistory(history: history)
    }

    private func removeDuplicate(_ array: [Memo]) -> [Memo] {
        var removedArray = [Memo]()
        var tempKeyArray = [String]()
        for item in array {
            if !tempKeyArray.contains(item.title) {
                tempKeyArray.append(item.title)
                removedArray.append(item)
            }
        }
        return removedArray
    }

    // MARK: - 플레이스홀더 값 관리

    // 플레이스홀더의 모든 값 불러오기
    func loadPlaceholderValues(for placeholder: String) -> [PlaceholderValue] {
        print("   🔑 [MemoStore.loadPlaceholderValues] 로드 시작: \(placeholder)")
        let key = "placeholder_values_\(placeholder)"

        guard let data = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.data(forKey: key) else {
            print("   ⚠️ [MemoStore.loadPlaceholderValues] 데이터 없음")
            return []
        }

        print("   💾 [MemoStore.loadPlaceholderValues] 데이터 크기: \(data.count) bytes")

        guard let values = try? JSONDecoder().decode([PlaceholderValue].self, from: data) else {
            print("   ❌ [MemoStore.loadPlaceholderValues] 디코딩 실패")
            return []
        }

        print("   ✅ [MemoStore.loadPlaceholderValues] \(values.count)개 값 로드 성공")
        for (index, value) in values.enumerated() {
            print("      [\(index)] \(value.value) - 출처: \(value.sourceMemoTitle)")
        }

        return values
    }

    // 플레이스홀더 값 저장
    func savePlaceholderValues(_ values: [PlaceholderValue], for placeholder: String) {
        let key = "placeholder_values_\(placeholder)"
        print("💾 [MemoStore.savePlaceholderValues] 저장 시작")
        print("   플레이스홀더: \(placeholder)")
        print("   Key: \(key)")
        print("   값 개수: \(values.count)")

        if let data = try? JSONEncoder().encode(values) {
            print("   인코딩 성공 - 데이터 크기: \(data.count) bytes")
            UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.set(data, forKey: key)
            UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.synchronize()
            print("   ✅ UserDefaults에 저장 완료")

            // 저장 직후 확인
            if let savedData = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.data(forKey: key) {
                print("   ✅ 저장 확인됨 - 크기: \(savedData.count) bytes")
            } else {
                print("   ❌ 저장 확인 실패!")
            }
        } else {
            print("   ❌ 인코딩 실패")
        }
    }

    // 플레이스홀더 값 추가 (출처 정보 포함)
    func addPlaceholderValue(_ value: String, for placeholder: String, sourceMemoId: UUID, sourceMemoTitle: String) {
        var values = loadPlaceholderValues(for: placeholder)

        // 중복 제거 (같은 값이 이미 있으면 제거)
        values.removeAll { $0.value == value }

        // 새 값 추가
        let newValue = PlaceholderValue(
            value: value,
            sourceMemoId: sourceMemoId,
            sourceMemoTitle: sourceMemoTitle
        )
        values.insert(newValue, at: 0)

        savePlaceholderValues(values, for: placeholder)
    }

    // 플레이스홀더 값 삭제
    func deletePlaceholderValue(valueId: UUID, for placeholder: String) {
        var values = loadPlaceholderValues(for: placeholder)
        values.removeAll { $0.id == valueId }
        savePlaceholderValues(values, for: placeholder)
    }

    // 특정 메모에서 추가된 플레이스홀더 값들 삭제
    func deletePlaceholderValues(fromMemoId memoId: UUID) {
        // 모든 플레이스홀더 확인
        let allMemos = (try? load(type: .tokenMemo)) ?? []
        var allPlaceholders: Set<String> = []

        for memo in allMemos where memo.isTemplate {
            let placeholders = extractPlaceholders(from: memo.value)
            allPlaceholders.formUnion(placeholders)
        }

        // 각 플레이스홀더에서 해당 메모에서 추가된 값 삭제
        for placeholder in allPlaceholders {
            var values = loadPlaceholderValues(for: placeholder)
            values.removeAll { $0.sourceMemoId == memoId }
            savePlaceholderValues(values, for: placeholder)
        }
    }

    // 플레이스홀더 추출 (내부 헬퍼 함수)
    private func extractPlaceholders(from text: String) -> [String] {
        let autoVariables = ["{날짜}", "{시간}", "{연도}", "{월}", "{일}"]
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

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

        return placeholders
    }
}
