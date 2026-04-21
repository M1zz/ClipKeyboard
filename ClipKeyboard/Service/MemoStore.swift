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

        let memos = decodeMemosFromData(data)
        print("🏁 [MemoStore.load] 완료 - 반환: \(memos.count)개")

        let (migratedMemos, wasMigrated) = migrateLegacyCategoriesToThemes(memos)
        if wasMigrated {
            try? save(memos: migratedMemos, type: type)
            print("💾 [MemoStore.load] 마이그레이션된 데이터 저장 완료")
        }
        return migratedMemos
    }

    /// Data → [Memo] 디코딩 (신규 형식 → 구형식 폴백)
    private func decodeMemosFromData(_ data: Data) -> [Memo] {
        if let memos = try? JSONDecoder().decode([Memo].self, from: data) {
            print("✅ [MemoStore.load] 새 형식(Memo)으로 디코딩 성공 - \(memos.count)개")
            logDecodedMemos(memos)
            return memos
        }
        print("🔄 [MemoStore.load] 새 형식 디코딩 실패 - 이전 형식(OldMemo) 시도")
        if let oldMemos = try? JSONDecoder().decode([OldMemo].self, from: data) {
            print("✅ [MemoStore.load] 이전 형식(OldMemo)으로 디코딩 성공 - \(oldMemos.count)개")
            let converted = oldMemos.map { Memo(from: $0) }
            print("✅ [MemoStore.load] 변환 완료 - \(converted.count)개")
            return converted
        }
        print("❌ [MemoStore.load] 모든 형식 디코딩 실패")
        return []
    }

    private func logDecodedMemos(_ memos: [Memo]) {
        for (index, memo) in memos.enumerated() {
            print("   [\(index)] ID: \(memo.id), 제목: \(memo.title), 테마: \(memo.category)")
            print("       즐겨찾기: \(memo.isFavorite), 템플릿: \(memo.isTemplate), 보안: \(memo.isSecure)")
            print("       수정일: \(memo.lastEdited), 사용횟수: \(memo.clipCount)")
            print("       플레이스홀더 값: \(memo.placeholderValues)")
        }
    }
    
    func loadClipboardHistory() throws -> [ClipboardHistory] {
        guard let fileURL = try Self.fileURL(type: .clipboardHistory) else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        if let history = try? JSONDecoder().decode([ClipboardHistory].self, from: data) {
            return history
        }
        return []
    }

    // 사용 빈도 증가 및 마지막 사용 시점 기록
    func incrementClipCount(for memoId: UUID) throws {
        var memos = try load(type: .tokenMemo)
        if let index = memos.firstIndex(where: { $0.id == memoId }) {
            memos[index].clipCount += 1
            memos[index].lastUsedAt = Date()
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

        // Pro 여부에 따른 히스토리 제한
        let maxHistory = ProFeatureManager.clipboardHistoryLimit()
        if history.count > maxHistory {
            history = Array(history.prefix(maxHistory))
        }

        // 7일 이상 된 임시 항목 자동 삭제
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        history.removeAll { $0.isTemporary && $0.copiedAt < sevenDaysAgo }

        try saveSmartClipboardHistory(history: history)

        // 리뷰 요청 트리거: 클립 저장
        NotificationCenter.default.post(name: .reviewTriggerClipSaved, object: nil)

        // Published 변수 업데이트
        DispatchQueue.main.async { [weak self] in
            self?.smartClipboardHistory = history
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
            DispatchQueue.main.async { [weak self] in
                self?.smartClipboardHistory = history
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

    // MARK: - Favorite Helper

    /// 즐겨찾기된 메모가 있는지 확인
    func hasFavoriteMemo() -> Bool {
        guard let memos = try? load(type: .tokenMemo) else { return false }
        return memos.contains(where: { $0.isFavorite })
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
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var placeholders: [String] = []

        for match in matches {
            if let range = Range(match.range, in: text) {
                let placeholder = String(text[range])
                if !TemplateVariableProcessor.autoVariableTokens.contains(placeholder) && !placeholders.contains(placeholder) {
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
        DispatchQueue.main.async { [weak self] in
            self?.combos = combos
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
            DispatchQueue.main.async { [weak self] in
                self?.combos = combos
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
