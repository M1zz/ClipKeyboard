//
//  MemoStore.swift
//  Token memo
//
//  Created by hyunho lee on 2023/05/16.
//

import Foundation
#if os(iOS)
import UIKit
import Vision
import VisionKit
#endif

enum MemoType {
    case tokenMemo
    case clipboardHistory
    case smartClipboardHistory  // 새로운 타입
    case combo  // Phase 2: Combo 시스템
}

class MemoStore: ObservableObject {
    static let shared = MemoStore()

    @Published var memos: [Memo] = []
    @Published var clipboardHistory: [ClipboardHistory] = []
    @Published var smartClipboardHistory: [SmartClipboardHistory] = []
    @Published var combos: [Combo] = []
    
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
        case .smartClipboardHistory:
            fileURL = containerURL.appendingPathComponent("smart.clipboard.history.data")
            print("📄 [MemoStore.fileURL] 스마트 클립보드 히스토리 파일: \(fileURL.path)")
        case .combo:
            fileURL = containerURL.appendingPathComponent("combos.data")
            print("📄 [MemoStore.fileURL] Combo 파일: \(fileURL.path)")
        }

        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        print("🔍 [MemoStore.fileURL] 파일 존재 여부: \(fileExists)")

        return fileURL
    }
    
    func save(memos: [Memo], type: MemoType) throws {
        print("💾 [MemoStore.save] 저장 시작 - type: \(type), count: \(memos.count)")
        let data = try JSONEncoder().encode(memos)
        print("📦 [MemoStore.save] 인코딩 완료 - \(data.count) bytes")

        guard let outfile = try Self.fileURL(type: type) else {
            print("❌ [MemoStore.save] fileURL을 가져올 수 없음!")
            return
        }
        print("📍 [MemoStore.save] 저장 경로: \(outfile.path)")

        try data.write(to: outfile)
        print("✅ [MemoStore.save] 파일 쓰기 완료")

        // 저장된 데이터 검증
        if let verifyData = try? Data(contentsOf: outfile) {
            print("✓ [MemoStore.save] 검증: 파일 크기 \(verifyData.count) bytes")
        } else {
            print("⚠️ [MemoStore.save] 검증 실패: 파일을 읽을 수 없음")
        }

        // 데이터 변경 알림 전송 (자동 백업 트리거)
        NotificationCenter.default.post(name: NSNotification.Name("MemoDataChanged"), object: nil)
    }

    func saveClipboardHistory(history: [ClipboardHistory]) throws {
        let data = try JSONEncoder().encode(history)
        guard let outfile = try Self.fileURL(type: .clipboardHistory) else { return }
        try data.write(to: outfile)

        // 데이터 변경 알림 전송 (자동 백업 트리거)
        NotificationCenter.default.post(name: NSNotification.Name("MemoDataChanged"), object: nil)
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
                print("       테마: \(memo.category)")
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

        // 카테고리 → 테마 마이그레이션 실행
        let (migratedMemos, wasMigrated) = migrateLegacyCategoriesToThemes(memos)

        // 마이그레이션이 수행되었으면 저장
        if wasMigrated {
            try? save(memos: migratedMemos, type: type)
            print("💾 [MemoStore.load] 마이그레이션된 데이터 저장 완료")
        }

        return migratedMemos
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

    // MARK: - Smart Clipboard History (자동 분류)

    /// 스마트 클립보드 히스토리 저장
    func saveSmartClipboardHistory(history: [SmartClipboardHistory]) throws {
        let data = try JSONEncoder().encode(history)
        guard let outfile = try Self.fileURL(type: .smartClipboardHistory) else { return }
        try data.write(to: outfile)

        // 데이터 변경 알림 전송 (자동 백업 트리거)
        NotificationCenter.default.post(name: NSNotification.Name("MemoDataChanged"), object: nil)
    }

    /// 스마트 클립보드 히스토리 로드
    func loadSmartClipboardHistory() throws -> [SmartClipboardHistory] {
        guard let fileURL = try Self.fileURL(type: .smartClipboardHistory) else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else {
            // 파일이 없으면 기존 클립보드 히스토리 마이그레이션 시도
            return try migrateFromLegacyClipboard()
        }

        if let history = try? JSONDecoder().decode([SmartClipboardHistory].self, from: data) {
            return history
        }
        return []
    }

    /// 스마트 클립보드 히스토리에 추가 (자동 분류 포함)
    func addToSmartClipboardHistory(content: String) throws {
        var history = try loadSmartClipboardHistory()

        // 자동 분류
        let (detectedType, confidence) = ClipboardClassificationService.shared.classify(content: content)

        // 중복 제거
        history.removeAll { $0.content == content }

        // 새 항목 추가
        let newItem = SmartClipboardHistory(
            content: content,
            detectedType: detectedType,
            confidence: confidence
        )
        history.insert(newItem, at: 0)

        // 최대 100개까지만 유지
        if history.count > 100 {
            history = Array(history.prefix(100))
        }

        // 7일 이상 된 임시 항목 자동 삭제
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        history.removeAll { $0.isTemporary && $0.copiedAt < sevenDaysAgo }

        try saveSmartClipboardHistory(history: history)

        // Published 변수 업데이트
        DispatchQueue.main.async {
            self.smartClipboardHistory = history
        }
    }

    /// 사용자 피드백으로 타입 수정
    func updateClipboardItemType(id: UUID, correctedType: ClipboardItemType) throws {
        var history = try loadSmartClipboardHistory()

        if let index = history.firstIndex(where: { $0.id == id }) {
            history[index].userCorrectedType = correctedType

            // 학습 모델에 피드백 전달
            ClipboardClassificationService.shared.updateClassificationModel(
                content: history[index].content,
                correctedType: correctedType
            )

            try saveSmartClipboardHistory(history: history)

            // Published 변수 업데이트
            DispatchQueue.main.async {
                self.smartClipboardHistory = history
            }
        }
    }

    /// 기존 클립보드 히스토리에서 마이그레이션
    private func migrateFromLegacyClipboard() throws -> [SmartClipboardHistory] {
        print("🔄 [MemoStore] 기존 클립보드 히스토리 마이그레이션 시작...")

        let legacyHistory = try loadClipboardHistory()

        let smartHistory = legacyHistory.map { item -> SmartClipboardHistory in
            let (type, confidence) = ClipboardClassificationService.shared.classify(content: item.content)
            return SmartClipboardHistory(
                id: item.id,
                content: item.content,
                copiedAt: item.copiedAt,
                isTemporary: item.isTemporary,
                detectedType: type,
                confidence: confidence
            )
        }

        // 새 형식으로 저장
        if !smartHistory.isEmpty {
            try saveSmartClipboardHistory(history: smartHistory)
            print("✅ [MemoStore] 마이그레이션 완료: \(smartHistory.count)개 항목")
        }

        return smartHistory
    }

    /// 구 카테고리 이름을 새 테마 이름으로 마이그레이션
    /// - Parameter memos: 마이그레이션할 메모 배열
    /// - Returns: (마이그레이션된 메모 배열, 마이그레이션 수행 여부)
    private func migrateLegacyCategoriesToThemes(_ memos: [Memo]) -> (memos: [Memo], migrated: Bool) {
        let oldCategories = ["개인정보", "금융", "여행", "업무", "기본"]
        var needsMigration = false

        // 마이그레이션이 필요한지 확인
        for memo in memos {
            if oldCategories.contains(memo.category) {
                needsMigration = true
                break
            }
        }

        guard needsMigration else {
            return (memos, false)
        }

        print("🔄 [MemoStore] 카테고리 → 테마 마이그레이션 시작...")

        let migratedMemos = memos.map { memo -> Memo in
            guard oldCategories.contains(memo.category) else {
                return memo
            }

            var updatedMemo = memo

            // autoDetectedType이 있으면 그것을 사용
            if let detectedType = memo.autoDetectedType {
                updatedMemo.category = detectedType.rawValue
                print("   [\(memo.title)] \(memo.category) → \(detectedType.rawValue) (자동 감지 타입 사용)")
            } else {
                // autoDetectedType이 없으면 "텍스트"로 기본 설정
                updatedMemo.category = "텍스트"
                print("   [\(memo.title)] \(memo.category) → 텍스트 (기본값)")
            }

            return updatedMemo
        }

        print("✅ [MemoStore] 마이그레이션 완료")
        return (migratedMemos, true)
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

    // MARK: - 이미지 관리

    #if os(iOS)
    /// 이미지 저장
    func saveImage(_ image: UIImage, fileName: String) throws {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo") else {
            throw NSError(domain: "MemoStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Group 컨테이너를 찾을 수 없음"])
        }

        let imagesDirectory = containerURL.appendingPathComponent("Images")

        // Images 디렉토리 생성
        if !FileManager.default.fileExists(atPath: imagesDirectory.path) {
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        // PNG 데이터로 변환하여 저장
        guard let imageData = image.pngData() else {
            throw NSError(domain: "MemoStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "이미지를 PNG로 변환할 수 없음"])
        }

        try imageData.write(to: fileURL)
        print("✅ [MemoStore] 이미지 저장 완료: \(fileName)")
    }

    /// 이미지 로드
    func loadImage(fileName: String) -> UIImage? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo") else {
            print("❌ [MemoStore] App Group 컨테이너를 찾을 수 없음")
            return nil
        }

        let imagesDirectory = containerURL.appendingPathComponent("Images")
        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("⚠️ [MemoStore] 이미지 파일이 존재하지 않음: \(fileName)")
            return nil
        }

        return UIImage(contentsOfFile: fileURL.path)
    }

    /// 이미지 삭제
    func deleteImage(fileName: String) throws {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo") else {
            throw NSError(domain: "MemoStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Group 컨테이너를 찾을 수 없음"])
        }

        let imagesDirectory = containerURL.appendingPathComponent("Images")
        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
            print("✅ [MemoStore] 이미지 삭제 완료: \(fileName)")
        }
    }
    #endif

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

    // MARK: - Combo 관리 (Phase 2)

    /// Combo 목록 저장
    func saveCombos(_ combos: [Combo]) throws {
        let data = try JSONEncoder().encode(combos)
        guard let outfile = try Self.fileURL(type: .combo) else { return }
        try data.write(to: outfile)

        // Published 변수 업데이트
        DispatchQueue.main.async {
            self.combos = combos
        }

        // 데이터 변경 알림 전송 (자동 백업 트리거)
        NotificationCenter.default.post(name: NSNotification.Name("MemoDataChanged"), object: nil)
    }

    /// Combo 목록 로드
    func loadCombos() throws -> [Combo] {
        guard let fileURL = try Self.fileURL(type: .combo) else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        if let combos = try? JSONDecoder().decode([Combo].self, from: data) {
            // Published 변수 업데이트
            DispatchQueue.main.async {
                self.combos = combos
            }
            return combos
        }
        return []
    }

    /// Combo 추가
    func addCombo(_ combo: Combo) throws {
        var combos = try loadCombos()
        combos.insert(combo, at: 0)
        try saveCombos(combos)
    }

    /// Combo 업데이트
    func updateCombo(_ combo: Combo) throws {
        var combos = try loadCombos()
        if let index = combos.firstIndex(where: { $0.id == combo.id }) {
            combos[index] = combo
            try saveCombos(combos)
        }
    }

    /// Combo 삭제
    func deleteCombo(id: UUID) throws {
        var combos = try loadCombos()
        combos.removeAll { $0.id == id }
        try saveCombos(combos)
    }

    /// Combo 사용 횟수 증가 및 마지막 사용 시간 업데이트
    func incrementComboUseCount(id: UUID) throws {
        var combos = try loadCombos()
        if let index = combos.firstIndex(where: { $0.id == id }) {
            combos[index].useCount += 1
            combos[index].lastUsed = Date()
            try saveCombos(combos)
        }
    }

    /// Combo 항목의 실제 값 가져오기
    /// - Parameters:
    ///   - item: Combo 항목
    /// - Returns: 항목의 실제 값 (복사할 텍스트)
    func getComboItemValue(_ item: ComboItem) throws -> String? {
        switch item.type {
        case .memo:
            let memos = try load(type: .tokenMemo)
            return memos.first(where: { $0.id == item.referenceId })?.value
        case .clipboardHistory:
            let history = try loadSmartClipboardHistory()
            return history.first(where: { $0.id == item.referenceId })?.content
        case .template:
            // 템플릿의 경우 displayValue 우선 사용 (플레이스홀더 값이 미리 입력됨)
            if let displayValue = item.displayValue, !displayValue.isEmpty {
                return displayValue
            }
            // displayValue가 없으면 원본 템플릿 반환
            let memos = try load(type: .tokenMemo)
            return memos.first(where: { $0.id == item.referenceId })?.value
        }
    }

    /// Combo 항목의 참조 대상이 존재하는지 검증
    /// - Parameter item: 검증할 ComboItem
    /// - Returns: 참조 대상이 존재하면 true
    func validateComboItem(_ item: ComboItem) throws -> Bool {
        switch item.type {
        case .memo:
            let memos = try load(type: .tokenMemo)
            return memos.contains(where: { $0.id == item.referenceId && !$0.isTemplate })
        case .clipboardHistory:
            let history = try loadSmartClipboardHistory()
            return history.contains(where: { $0.id == item.referenceId })
        case .template:
            let memos = try load(type: .tokenMemo)
            return memos.contains(where: { $0.id == item.referenceId && $0.isTemplate })
        }
    }

    /// Combo의 모든 항목 검증 및 유효하지 않은 항목 제거
    /// - Parameter combo: 검증할 Combo
    /// - Returns: 정리된 Combo
    func cleanupCombo(_ combo: Combo) throws -> Combo {
        var validItems: [ComboItem] = []

        for item in combo.items {
            if try validateComboItem(item) {
                validItems.append(item)
            } else {
                print("⚠️ [MemoStore] Combo '\(combo.title)'의 항목 '\(item.displayTitle ?? "unknown")' 제거됨 (참조 대상 없음)")
            }
        }

        var cleanedCombo = combo
        cleanedCombo.items = validItems

        // order 재정렬
        for (index, _) in cleanedCombo.items.enumerated() {
            cleanedCombo.items[index].order = index
        }

        return cleanedCombo
    }
}

// MARK: - Clipboard Classification Service

/// 클립보드 내용 자동 분류 서비스
class ClipboardClassificationService {
    static let shared = ClipboardClassificationService()

    private init() {}

    // MARK: - Public Methods

    /// 클립보드 내용을 자동으로 분류
    /// - Parameter content: 분류할 텍스트
    /// - Returns: (타입, 신뢰도) 튜플
    func classify(content: String) -> (type: ClipboardItemType, confidence: Double) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // 빈 문자열 체크
        if trimmed.isEmpty {
            return (.text, 0.0)
        }

        // 각 타입별로 검사 (높은 신뢰도 & 구체적인 패턴부터)
        // Korea-specific patterns removed for global categories
        // if let result = detectRRN(trimmed) { return result }  // Removed: Korea-specific RRN
        // if let result = detectBusinessNumber(trimmed) { return result }  // Removed: Korea-specific Business Number
        if let result = detectCreditCard(trimmed) { return result }
        if let result = detectEmail(trimmed) { return result }
        if let result = detectPhone(trimmed) { return result }
        if let result = detectURL(trimmed) { return result }
        if let result = detectPassportNumber(trimmed) { return result }
        if let result = detectDeclarationNumber(trimmed) { return result }
        if let result = detectVehiclePlate(trimmed) { return result }  // 차량번호
        if let result = detectIPAddress(trimmed) { return result }  // IP주소
        if let result = detectBirthDate(trimmed) { return result }  // 계좌번호보다 먼저!
        if let result = detectPostalCode(trimmed) { return result }
        if let result = detectBankAccount(trimmed) { return result }  // 가장 유연한 패턴은 마지막에
        if let result = detectAddress(trimmed) { return result }  // 주소 (키워드 기반)
        if let result = detectName(trimmed) { return result }  // 이름 (가장 모호함)

        // 기본값
        return (.text, 0.3)
    }

    /// 사용자 피드백을 반영하여 학습 (향후 ML 모델 개선용)
    /// - Parameters:
    ///   - content: 원본 텍스트
    ///   - correctedType: 사용자가 수정한 타입
    func updateClassificationModel(content: String, correctedType: ClipboardItemType) {
        // TODO: 나중에 Core ML 모델 학습 또는 휴리스틱 개선
        print("📚 [Classification] 학습 데이터 수집: \(content) -> \(correctedType.rawValue)")
    }

    // MARK: - Clipboard Image Detection

    #if canImport(UIKit)
    /// 클립보드에서 내용 가져오기 (텍스트 또는 이미지)
    /// - Returns: SmartClipboardHistory 객체 또는 nil
    func checkClipboard() -> SmartClipboardHistory? {
        let pasteboard = UIPasteboard.general

        // 1. 이미지 우선 확인
        if let image = pasteboard.image {
            return createHistoryFromImage(image)
        }

        // 2. 텍스트 확인
        if let text = pasteboard.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return createHistoryFromText(text)
        }

        return nil
    }

    /// 이미지로부터 클립보드 히스토리 생성
    private func createHistoryFromImage(_ image: UIImage) -> SmartClipboardHistory? {
        // 이미지 크기 제한 (메모리 절약) - 인라인 구현
        let maxDimension: CGFloat = 1024
        let maxSize = max(image.size.width, image.size.height)

        var finalImage = image
        if maxSize > maxDimension {
            let ratio = maxDimension / maxSize
            let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)

            // 리사이즈
            UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
            defer { UIGraphicsEndImageContext() }
            image.draw(in: CGRect(origin: .zero, size: newSize))

            guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
                return nil
            }
            finalImage = resizedImage
        }

        // Base64 변환 - 인라인 구현
        guard let imageData = finalImage.jpegData(compressionQuality: 0.7) else {
            return nil
        }
        let base64 = imageData.base64EncodedString()

        return SmartClipboardHistory(
            content: "이미지 (\(Int(finalImage.size.width))x\(Int(finalImage.size.height)))",
            contentType: .image,
            imageData: base64,
            detectedType: .text,
            confidence: 1.0
        )
    }

    /// 텍스트로부터 클립보드 히스토리 생성
    private func createHistoryFromText(_ text: String) -> SmartClipboardHistory {
        let classification = classify(content: text)

        return SmartClipboardHistory(
            content: text,
            contentType: .text,
            imageData: nil,
            detectedType: classification.type,
            confidence: classification.confidence
        )
    }

    /// 클립보드에 이미지가 있는지 확인
    func hasImage() -> Bool {
        return UIPasteboard.general.image != nil
    }

    /// 클립보드에 텍스트가 있는지 확인
    func hasText() -> Bool {
        if let text = UIPasteboard.general.string {
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }
    #endif

    // MARK: - Detection Methods

    /// 이메일 감지
    private func detectEmail(_ text: String) -> (ClipboardItemType, Double)? {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        if text.range(of: emailRegex, options: .regularExpression) != nil {
            return (.email, 0.95)
        }
        return nil
    }

    /// 전화번호 감지 (한국 형식)
    private func detectPhone(_ text: String) -> (ClipboardItemType, Double)? {
        let cleaned = text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

        // 한국 전화번호 패턴
        let patterns = [
            "^010[0-9]{8}$",      // 010-XXXX-XXXX
            "^01[016789][0-9]{7,8}$", // 기타 휴대폰
            "^0[2-6][0-9]{7,8}$",    // 지역번호
            "^1[5-9][0-9]{2}$"       // 단축번호
        ]

        for pattern in patterns {
            if cleaned.range(of: pattern, options: .regularExpression) != nil {
                return (.phone, 0.9)
            }
        }

        return nil
    }

    /// URL 감지
    private func detectURL(_ text: String) -> (ClipboardItemType, Double)? {
        let urlRegex = "^(https?://|www\\.)[^\\s]+"
        if text.range(of: urlRegex, options: .regularExpression) != nil {
            return (.url, 0.95)
        }

        // URL 구조 체크
        if text.contains(".com") || text.contains(".net") || text.contains(".kr") || text.contains(".io") {
            return (.url, 0.7)
        }

        return nil
    }

    /// 신용카드 번호 감지
    private func detectCreditCard(_ text: String) -> (ClipboardItemType, Double)? {
        let cleaned = text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

        // 13~19자리 숫자 (대부분의 카드)
        guard cleaned.count >= 13 && cleaned.count <= 19 else {
            return nil
        }

        // Luhn 알고리즘 검증
        if isValidLuhn(cleaned) {
            return (.creditCard, 0.85)
        }

        return nil
    }

    /// 계좌번호 감지 (한국)
    private func detectBankAccount(_ text: String) -> (ClipboardItemType, Double)? {
        // 통관부호와 구분하기 위해 P로 시작하는 경우 제외
        if text.uppercased().hasPrefix("P") {
            return nil
        }

        let cleaned = text.replacingOccurrences(of: "[^0-9-]", with: "", options: .regularExpression)

        // 한국 계좌번호 패턴: 다양한 형식 지원
        let patterns = [
            "^[0-9]{2,4}-[0-9]{2,6}-[0-9]{2,8}$",  // 하이픈 포함 (유연한 패턴)
            "^[0-9]{10,14}$"  // 숫자만
        ]

        for pattern in patterns {
            if cleaned.range(of: pattern, options: .regularExpression) != nil {
                // 카드번호와 구분하기 위해 신뢰도 낮춤
                return (.bankAccount, 0.6)
            }
        }

        return nil
    }

    /// 여권번호 감지 (한국)
    private func detectPassportNumber(_ text: String) -> (ClipboardItemType, Double)? {
        // 한국 여권: M + 8자리 숫자
        let passportRegex = "^[MmSs][0-9]{8}$"
        if text.range(of: passportRegex, options: .regularExpression) != nil {
            return (.passportNumber, 0.9)
        }

        return nil
    }

    /// 신고번호 감지 (통관고유부호 등)
    private func detectDeclarationNumber(_ text: String) -> (ClipboardItemType, Double)? {
        // P로 시작 + 12자리 숫자 (통관고유부호)
        let declarationRegex = "^[Pp][0-9]{12}$"
        if text.range(of: declarationRegex, options: .regularExpression) != nil {
            return (.declarationNumber, 0.95)
        }

        return nil
    }

    /// 우편번호 감지
    private func detectPostalCode(_ text: String) -> (ClipboardItemType, Double)? {
        let cleaned = text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

        // 한국 우편번호: 5자리
        if cleaned.count == 5 {
            return (.postalCode, 0.7)
        }

        return nil
    }

    /// 생년월일 감지
    private func detectBirthDate(_ text: String) -> (ClipboardItemType, Double)? {
        let patterns = [
            "^[0-9]{4}-[0-9]{2}-[0-9]{2}$",  // YYYY-MM-DD
            "^[0-9]{4}\\.[0-9]{2}\\.[0-9]{2}$", // YYYY.MM.DD
            "^[0-9]{4}/[0-9]{2}/[0-9]{2}$",  // YYYY/MM/DD
            "^[0-9]{6}$",                     // YYMMDD (주민번호 앞자리)
            "^[0-9]{8}$"                      // YYYYMMDD
        ]

        for pattern in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return (.birthDate, 0.75)
            }
        }

        return nil
    }

    /// 주민등록번호 감지 - Removed for global categories
    // Korea-specific pattern detection removed
    /*
    private func detectRRN(_ text: String) -> (ClipboardItemType, Double)? {
        let cleaned = text.replacingOccurrences(of: "[^0-9-]", with: "", options: .regularExpression)

        // 패턴: YYMMDD-NNNNNNN (6자리-7자리)
        let rrnPattern = "^[0-9]{6}-[1-4][0-9]{6}$"
        if cleaned.range(of: rrnPattern, options: .regularExpression) != nil {
            return (.taxID, 0.95)
        }

        // 하이픈 없이: YYMMDDNNNNNNN (13자리, 7번째 자리가 1-4)
        let rrnNoHyphenPattern = "^[0-9]{6}[1-4][0-9]{6}$"
        if cleaned.range(of: rrnNoHyphenPattern, options: .regularExpression) != nil {
            return (.taxID, 0.92)
        }

        return nil
    }
    */

    /// 사업자등록번호 감지 - Removed for global categories
    // Korea-specific pattern detection removed
    /*
    private func detectBusinessNumber(_ text: String) -> (ClipboardItemType, Double)? {
        let cleaned = text.replacingOccurrences(of: "[^0-9-]", with: "", options: .regularExpression)

        // 패턴: XXX-XX-XXXXX (3자리-2자리-5자리)
        let businessPattern = "^[0-9]{3}-[0-9]{2}-[0-9]{5}$"
        if cleaned.range(of: businessPattern, options: .regularExpression) != nil {
            return (.insuranceNumber, 0.95)
        }

        // 하이픈 없이: 10자리
        if cleaned.range(of: "^[0-9]{10}$", options: .regularExpression) != nil {
            return (.insuranceNumber, 0.85)
        }

        return nil
    }
    */

    /// 차량번호 감지 (한국)
    private func detectVehiclePlate(_ text: String) -> (ClipboardItemType, Double)? {
        // 신형: 12가1234, 123가1234
        let newPlatePattern = "^[0-9]{2,3}[가-힣][0-9]{4}$"
        if text.range(of: newPlatePattern, options: .regularExpression) != nil {
            return (.vehiclePlate, 0.9)
        }

        // 구형: 가1234, 서울12가3456
        let oldPlatePattern1 = "^[가-힣][0-9]{4}$"
        let oldPlatePattern2 = "^[가-힣]{2}[0-9]{2}[가-힣][0-9]{4}$"

        if text.range(of: oldPlatePattern1, options: .regularExpression) != nil {
            return (.vehiclePlate, 0.85)
        }

        if text.range(of: oldPlatePattern2, options: .regularExpression) != nil {
            return (.vehiclePlate, 0.9)
        }

        return nil
    }

    /// IP 주소 감지
    private func detectIPAddress(_ text: String) -> (ClipboardItemType, Double)? {
        // IPv4: 192.168.0.1
        let ipv4Pattern = "^([0-9]{1,3}\\.){3}[0-9]{1,3}$"
        if text.range(of: ipv4Pattern, options: .regularExpression) != nil {
            // 각 옥텟이 0-255 범위인지 검증
            let octets = text.split(separator: ".").compactMap { Int($0) }
            if octets.count == 4 && octets.allSatisfy({ $0 >= 0 && $0 <= 255 }) {
                return (.ipAddress, 0.95)
            }
        }

        // IPv6: 간단한 패턴 (콜론으로 구분된 16진수)
        let ipv6Pattern = "^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$"
        if text.range(of: ipv6Pattern, options: .regularExpression) != nil {
            return (.ipAddress, 0.85)
        }

        return nil
    }

    /// 이름 감지 (한글)
    private func detectName(_ text: String) -> (ClipboardItemType, Double)? {
        // 한글만 포함, 2-4글자
        let namePattern = "^[가-힣]{2,4}$"
        if text.range(of: namePattern, options: .regularExpression) != nil {
            // 신뢰도 낮음 (너무 일반적)
            return (.name, 0.5)
        }

        // 영문 이름: 대문자로 시작, 2-20글자
        let englishNamePattern = "^[A-Z][a-z]+( [A-Z][a-z]+)*$"
        if text.range(of: englishNamePattern, options: .regularExpression) != nil {
            return (.name, 0.6)
        }

        return nil
    }

    /// 주소 감지 (한글 키워드 기반)
    private func detectAddress(_ text: String) -> (ClipboardItemType, Double)? {
        // 주소 키워드
        let addressKeywords = [
            "시", "도", "구", "동", "로", "길", "번지", "아파트",
            "빌딩", "타워", "층", "호", "번길", "대로"
        ]

        var keywordCount = 0
        for keyword in addressKeywords {
            if text.contains(keyword) {
                keywordCount += 1
            }
        }

        // 2개 이상의 키워드가 있으면 주소로 판단
        if keywordCount >= 2 {
            return (.address, 0.7)
        }

        // 우편번호 + 주소 패턴 (5자리 + 한글)
        if text.range(of: "[0-9]{5}", options: .regularExpression) != nil && text.range(of: "[가-힣]+", options: .regularExpression) != nil {
            return (.address, 0.65)
        }

        return nil
    }

    // MARK: - Helper Methods

    /// Luhn 알고리즘 (신용카드 번호 검증)
    private func isValidLuhn(_ number: String) -> Bool {
        var sum = 0
        let reversedChars = number.reversed().map { String($0) }

        for (index, char) in reversedChars.enumerated() {
            guard let digit = Int(char) else { return false }

            if index % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }

        return sum % 10 == 0
    }
}


// MARK: - OCR Service

#if os(iOS)
class OCRService {
    static let shared = OCRService()
    
    private init() {}
    
    /// 이미지에서 텍스트 인식
    /// - Parameter image: 인식할 이미지
    /// - Returns: 인식된 텍스트 배열
    func recognizeText(from image: UIImage, completion: @escaping ([String]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }
        
        let request = VNRecognizeTextRequest { (request, error) in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                completion([])
                return
            }
            
            let recognizedTexts = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            DispatchQueue.main.async {
                completion(recognizedTexts)
            }
        }
        
        // 한국어 + 영어 인식
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("❌ [OCR] 텍스트 인식 실패: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
    /// 카드 정보 파싱
    /// - Parameter texts: OCR로 인식된 텍스트 배열
    /// - Returns: 파싱된 카드 정보
    func parseCardInfo(from texts: [String]) -> [String: String] {
        var result: [String: String] = [:]
        
        for text in texts {
            let cleaned = text.replacingOccurrences(of: " ", with: "")
                              .replacingOccurrences(of: "-", with: "")
            
            // 카드번호 패턴 (13-19자리)
            if cleaned.range(of: "^[0-9]{13,19}$", options: .regularExpression) != nil {
                // 4자리씩 나눠서 저장
                let formatted = cleaned.enumerated().map { (index, char) -> String in
                    return (index > 0 && index % 4 == 0) ? "-\(char)" : String(char)
                }.joined()
                result["카드번호"] = formatted
            }
            
            // 유효기간 패턴 (MM/YY)
            if let match = text.range(of: "(0[1-9]|1[0-2])/([0-9]{2})", options: .regularExpression) {
                result["유효기간"] = String(text[match])
            }
        }
        
        return result
    }
    
    /// 주소 정보 파싱
    /// - Parameter texts: OCR로 인식된 텍스트 배열
    /// - Returns: 파싱된 주소 정보
    func parseAddress(from texts: [String]) -> String {
        var addressComponents: [String] = []
        
        // 주소 키워드
        let addressKeywords = ["시", "도", "구", "동", "로", "길", "번지", "아파트", "빌딩", "타워", "층", "호"]
        
        for text in texts {
            // 주소 키워드를 포함하는 텍스트만 추출
            if addressKeywords.contains(where: { text.contains($0) }) {
                addressComponents.append(text)
            }
            
            // 우편번호 (5자리)
            if text.range(of: "^[0-9]{5}$", options: .regularExpression) != nil {
                addressComponents.insert(text, at: 0)
            }
        }
        
        return addressComponents.joined(separator: " ")
    }
}
#endif

