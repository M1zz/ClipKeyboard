//
//  KeyboardView.swift
//  TokenKeyboard
//
//  Created by hyunho lee on 2023/10/03.
//

import SwiftUI
import UIKit
import CryptoKit

var showOnlyTemplates: Bool = false
var showOnlyFavorites: Bool = false
var selectedTheme: String? = nil  // 선택된 테마 필터

// 미리 정의된 값들 저장소 - 새로운 구조 사용
class PredefinedValuesStore {
    static let shared = PredefinedValuesStore()

    // PlaceholderValue 모델 (키보드 전용 - 메인 앱의 PlaceholderValue와 같은 구조)
    private struct KeyboardPlaceholderValue: Codable {
        var id: UUID
        var value: String
        var sourceMemoId: UUID
        var sourceMemoTitle: String
        var addedAt: Date
    }

    // UserDefaults에서 불러오기 (새로운 구조)
    func getValues(for placeholder: String) -> [String] {
        print("🔍 [PredefinedValuesStore] getValues 호출 - placeholder: \(placeholder)")
        let key = "placeholder_values_\(placeholder)"
        print("   Key: \(key)")

        // 새로운 형식으로 로드 시도
        if let data = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.data(forKey: key) {
            print("   ✅ 데이터 발견 - 크기: \(data.count) bytes")

            if let placeholderValues = try? JSONDecoder().decode([KeyboardPlaceholderValue].self, from: data) {
                let values = placeholderValues.map { $0.value }
                print("   ✅ 디코딩 성공 - \(values.count)개 값: \(values)")
                return values
            } else {
                print("   ❌ 디코딩 실패")
            }
        } else {
            print("   ⚠️ 새 형식 데이터 없음")
        }

        // 이전 형식 호환성 (마이그레이션)
        let oldKey = "predefined_\(placeholder)"
        print("   🔄 이전 형식 시도 - Key: \(oldKey)")

        if let saved = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.stringArray(forKey: oldKey) {
            print("   ✅ 이전 형식에서 로드 - \(saved.count)개 값: \(saved)")
            return saved
        } else {
            print("   ⚠️ 이전 형식 데이터도 없음")
        }

        // 데이터가 없으면 빈 배열 반환
        print("   📭 데이터 없음 - 빈 배열 반환")
        return []
    }

    // 특정 템플릿에서 사용하는 값만 필터링
    func getValuesForTemplate(placeholder: String, templateId: UUID?) -> [String] {
        print("\n🔍 [PredefinedValuesStore] getValuesForTemplate 호출")
        print("   플레이스홀더: \(placeholder), 템플릿 ID: \(templateId?.uuidString ?? "nil")")
        logClipMemosState()

        if let values = getValuesFromMemos(placeholder: placeholder, templateId: templateId) {
            return values
        }
        return getValuesFromUserDefaults(placeholder: placeholder, templateId: templateId)
    }

    /// clipMemos 배열 상태 디버그 출력
    private func logClipMemosState() {
        print("   📚 clipMemos 배열: \(clipMemos.count)개")
        for (index, memo) in clipMemos.enumerated() {
            print("      [\(index)] ID: \(memo.id.uuidString), 제목: \(memo.title)")
            for (key, vals) in memo.placeholderValues {
                print("              \(key): \(vals)")
            }
        }
    }

    /// Memo 객체에서 플레이스홀더 값 조회
    private func getValuesFromMemos(placeholder: String, templateId: UUID?) -> [String]? {
        guard let templateId else {
            print("   ⚠️ templateId가 nil입니다")
            return nil
        }
        print("   🔎 템플릿 ID로 검색 중: \(templateId.uuidString)")
        guard let memo = clipMemos.first(where: { $0.id == templateId }) else {
            print("   ❌ templateId로 Memo를 찾을 수 없음: \(templateId.uuidString)")
            clipMemos.forEach { print("         - \($0.id.uuidString) (\($0.title))") }
            return nil
        }
        print("   ✅ Memo 객체에서 찾음: \(memo.title)")
        if let values = memo.placeholderValues[placeholder], !values.isEmpty {
            print("   ✅ Memo에 저장된 값 발견: \(values)")
            return values
        }
        print("   ⚠️ Memo에 '\(placeholder)' 값 없음, 사용 가능한 키: \(memo.placeholderValues.keys)")
        return nil
    }

    /// UserDefaults에서 플레이스홀더 값 조회
    private func getValuesFromUserDefaults(placeholder: String, templateId: UUID?) -> [String] {
        let key = "placeholder_values_\(placeholder)"
        print("   🔍 UserDefaults 확인 - Key: \(key)")
        guard let userDefaults = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo"),
              let data = userDefaults.data(forKey: key),
              let placeholderValues = try? JSONDecoder().decode([KeyboardPlaceholderValue].self, from: data) else {
            print("   ⚠️ 저장된 플레이스홀더 값 없음 - iOS 앱에서 값을 추가하세요")
            return []
        }
        print("   ✅ UserDefaults에서 디코딩 성공 - 총 \(placeholderValues.count)개")
        if let templateId {
            let filtered = placeholderValues.filter { $0.sourceMemoId == templateId }
            print("   📊 템플릿 ID로 필터링: \(filtered.count)개")
            if !filtered.isEmpty { return filtered.map { $0.value } }
        }
        let allValues = placeholderValues.map { $0.value }
        print("   ℹ️ 전체 값 반환: \(allValues)")
        return allValues
    }

}

// 템플릿 입력 상태 관리
class TemplateInputState: ObservableObject {
    @Published var isShowing: Bool = false
    @Published var placeholders: [String] = []
    @Published var inputs: [String: String] = [:]
    @Published var originalText: String = ""
    @Published var currentFocusedPlaceholder: String? = nil
    @Published var allPlaceholdersFilled: Bool = false
    @Published var templateId: UUID? = nil  // 현재 편집 중인 템플릿 ID
    /// v4.0.8: attachedTemplate 흐름에서 본 메모(계좌번호 등)의 ID. nil이면 일반 템플릿 흐름.
    @Published var baseMemoId: UUID? = nil
    /// v4.0.8: 본 메모 본문 — preview 표시용으로 매번 MemoStore 조회 안 하도록 캐싱.
    @Published var baseMemoValue: String = ""

    func updateAllPlaceholdersFilled() {
        allPlaceholdersFilled = !inputs.values.contains(where: { $0.isEmpty })
    }

    /// 현재 입력값 기준 결합 미리보기. baseMemoValue가 있으면 결합 형태, 없으면 치환 결과.
    var previewText: String {
        let resolvedTemplate = TemplateVariableProcessor.substitute(originalText, with: inputs)
        if baseMemoValue.isEmpty {
            return resolvedTemplate
        }
        return baseMemoValue + "\n" + resolvedTemplate
    }
}

struct KeyboardView: View {

    @AppStorage("keyboardColumnCount", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var keyboardColumnCount: Int = 2
    @AppStorage("keyboardButtonHeight", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var buttonHeight: Double = 44.0
    @AppStorage("keyboardButtonFontSize", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var buttonFontSize: Double = 17.0

    // 색상 커스터마이즈 — 기본은 false (Paper 테마 사용), true면 hex 오버라이드
    @AppStorage("keyboardUseCustomColors", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var useCustomColors: Bool = false
    @AppStorage("keyboardCustomBgHex", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var customBgHex: String = ""
    @AppStorage("keyboardCustomKeyHex", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var customKeyHex: String = ""

    // 옵션 토글 — 기본 OFF로 화면 공간 확보
    @AppStorage("keyboardShowSearch", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var showSearchBar: Bool = false
    @AppStorage("keyboardShowRecent", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var showRecentSection: Bool = false
    // 한국어 입력 사용 여부(기본 OFF). 꺼져 있으면 한/EN 토글과 한글 자판이 아예 노출되지 않아
    // 영어 전용 사용자는 한글을 볼 일이 없다. 한국어 사용자가 설정에서 직접 켠다.
    @AppStorage("keyboardKoreanEnabled", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var koreanInputEnabled: Bool = false
    @AppStorage("keyboardTypingLang", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var defaultTypingLang: String = "english"

    /// KeyboardViewController가 init으로 주입 (let — SwiftUI 재렌더에도 유지)
    let typingProxy: TypingInputProxy?

    /// 호스트 텍스트 필드 상태 — clearAll(X) 버튼은 hasText일 때만 노출.
    /// nil이면 (preview 등) 항상 표시.
    @ObservedObject var documentState: KeyboardDocumentState

    init(typingProxy: TypingInputProxy? = nil, documentState: KeyboardDocumentState = KeyboardDocumentState()) {
        self.typingProxy = typingProxy
        self.documentState = documentState
    }

    // 동적 그리드 레이아웃 (열 개수에 따라 변경)
    private var gridItemLayout: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: max(1, min(5, keyboardColumnCount)))
    }

    // 데이터 상태
    @State private var allMemos: [Memo] = []
    @State private var templateObserverToken: NSObjectProtocol?
    @State private var showImageCopiedToast = false
    @State private var showPinNotSetToast = false

    // 검색 상태
    @State private var searchQuery: String = ""
    @State private var isSearching: Bool = false
    @State private var searchKeyboardLang: SearchLang = .english

    // v4.1.0: 카테고리 swipe 현재 페이지 인덱스 (즐겨찾기 별 토글은 제거됨)
    @State private var currentCategoryPage: Int = 0

    // 보안 메모 PIN 인증
    @State private var showPINEntry = false
    @State private var pendingSecureMemo: Memo? = nil
    @State private var enteredPIN = ""
    @State private var pinEntryWrong = false

    @StateObject private var templateInputState = TemplateInputState()
    @State private var pendingBypassTemplate: Bool = false

    @Environment(\.colorScheme) var colorScheme

    enum SearchLang { case english, korean }

    /// iOS 앱과 동일한 Paper 테마 — light/dark는 시스템 모드 따름
    private var theme: AppTheme {
        AppTheme.resolve(kind: .paper, isDark: colorScheme == .dark)
    }

    // MARK: - Computed Properties

    /// v4.1.0: 카테고리 기능 활성 시 선택된 카테고리 + 검색 적용, 비활성 시 검색만.
    /// 별 토글은 v4.1.0에서 제거됨 — 즐겨찾기는 카테고리 swipe(★favorites 페이지)로 접근.
    private var filteredMemos: [Memo] {
        var result = allMemos

        if isCategoryFeatureEnabled, let category = selectedCategoryFilter {
            if category == "★favorites" {
                result = result.filter { $0.isFavorite }
            } else if category != "★all" {
                result = result.filter { $0.category == category }
            }
        }

        if !searchQuery.isEmpty {
            let q = searchQuery
            result = result.filter {
                $0.title.localizedStandardContains(q) ||
                $0.value.localizedStandardContains(q) ||
                $0.category.localizedStandardContains(q)
            }
        }
        return result
    }

    /// 키보드 익스텐션은 메인 앱 타겟의 CategoryStore에 직접 접근할 수 없으므로
    /// App Group UserDefaults에서 같은 flag/배열을 읽어 동일 동작 보장.
    private var isCategoryFeatureEnabled: Bool {
        UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?
            .bool(forKey: "category.feature.enabled.v1") ?? false
    }

    /// iOS 앱 ClipKeyboardListViewModel과 같은 키 — 완전 동기화
    private var sharedUserCategories: [String] {
        UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?
            .stringArray(forKey: "userDefinedCategories_v1") ?? []
    }

    /// iOS 앱에서 숨긴 탭 목록 — "__favorites__" 또는 카테고리 이름
    private var sharedHiddenCategoryTabs: Set<String> {
        let arr = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?
            .stringArray(forKey: "hiddenCategoryTabs_v1") ?? []
        return Set(arr)
    }

    /// v4.1.0: 키보드 페이지 인디케이터로 선택된 카테고리. "★all"=전체, "★favorites"=즐겨찾기,
    /// 그 외=실제 카테고리 이름. 기본 nil → 전체.
    private var selectedCategoryFilter: String? {
        guard !categoryPages.isEmpty else { return nil }
        let index = max(0, min(currentCategoryPage, categoryPages.count - 1))
        return categoryPages[index]
    }

    /// 카테고리 페이지 목록 — iOS 앱 ClipKeyboardListViewModel.allCategoryTabs와 동일 로직
    private var categoryPages: [String] {
        guard isCategoryFeatureEnabled else { return [] }
        let hidden = sharedHiddenCategoryTabs
        var pages: [String] = ["★all"]
        // 즐겨찾기: 숨김 처리 + 메모 1개 이상일 때만
        if !hidden.contains("__favorites__"),
           allMemos.contains(where: { $0.isFavorite }) {
            pages.append("★favorites")
        }
        // 사용자 카테고리: 숨김 처리 + 해당 카테고리 메모 1개 이상일 때만
        let usedCategories = sharedUserCategories
            .filter { name in
                !hidden.contains(name) &&
                allMemos.contains { $0.category == name }
            }
        pages.append(contentsOf: usedCategories)
        return pages
    }

    /// 그리드 표시 항목 — attached template이 있는 일반 메모는 두 셀로 expand:
    /// 1) 원본 메모만 입력, 2) 원본 + 템플릿 적용. 각각 다른 셀로 보여 사용자가 선택.
    private var displayItems: [DisplayItem] {
        filteredMemos.flatMap { memo -> [DisplayItem] in
            let canSplit = memo.attachedTemplateId != nil
                && !memo.isCombo
                && memo.contentType != .image
                && memo.contentType != .mixed
            if canSplit {
                return [
                    DisplayItem(memo: memo, useTemplate: false),
                    DisplayItem(memo: memo, useTemplate: true)
                ]
            }
            return [DisplayItem(memo: memo, useTemplate: false)]
        }
    }

    /// 최근 사용 메모 5개 — lastUsedAt 기준 1주 이내, 최신순
    private var recentMemos: [Memo] {
        let weekAgo = Date().addingTimeInterval(-60 * 60 * 24 * 7)
        return allMemos
            .filter { ($0.lastUsedAt ?? .distantPast) >= weekAgo }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    /// 최근 사용 섹션 노출 조건 — 검색 비활성일 때만
    private var shouldShowRecentSection: Bool {
        searchQuery.isEmpty && !recentMemos.isEmpty
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                memoModeContent
            }

            if showPINEntry {
                pinEntryOverlay
            }
        }
    }

    private func clearAllButton(proxy: TypingInputProxy) -> some View {
        Button {
            KeyboardHaptics.mediumTap()
            proxy.clearAll()
        } label: {
            Image(systemName: "xmark.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.textMuted)
                .frame(width: 36, height: 28)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
        }
        .buttonStyle(PlainButtonStyle())
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(NSLocalizedString("전체 삭제", comment: "Clear all text"))
        .accessibilityHint(NSLocalizedString("현재 입력된 텍스트를 모두 지웁니다", comment: "Clear all button hint"))
    }

    @ViewBuilder
    private var memoModeContent: some View {
        VStack(spacing: 0) {
            // 무료 유저: 숨겨진 메모 있을 때 또는 한도 임박(2개 이내) 시 업그레이드 배너
            if isFreeUser && (hiddenMemoCount > 0 || isMemoLimitNear) {
                freeUpgradeBanner
            }

            // 상단 헤더 — 카테고리 탭 + clear 버튼
            HStack(spacing: 0) {
                if categoryPages.count > 1 {
                    categoryTabRow
                } else {
                    Spacer()
                }
                if let proxy = typingProxy, documentState.hasText {
                    clearAllButton(proxy: proxy)
                        .padding(.trailing, 4)
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
            .animation(.easeOut(duration: 0.18), value: documentState.hasText)

            // 검색 바 — 사용자 토글 ON일 때만
            if showSearchBar {
                searchBar
            }

            // 최근 사용 섹션 — 사용자 토글 ON + 검색 비활성일 때만
            if showRecentSection && !isSearching && shouldShowRecentSection {
                recentSection
            }

            // 메모 그리드
            ZStack {
                backgroundColor

                if filteredMemos.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridItemLayout, spacing: 10) {
                            ForEach(displayItems) { item in
                                memoButton(for: item.memo, useTemplate: item.useTemplate)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    // v4.1.0: 좌우 swipe로 카테고리 페이지 전환
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 40)
                            .onEnded { value in
                                guard categoryPages.count > 1 else { return }
                                let h = value.translation.width
                                let v = value.translation.height
                                guard abs(h) > abs(v) * 1.5, abs(h) > 60 else { return }
                                if h < 0, currentCategoryPage < categoryPages.count - 1 {
                                    KeyboardHaptics.tap()
                                    currentCategoryPage += 1
                                } else if h > 0, currentCategoryPage > 0 {
                                    KeyboardHaptics.tap()
                                    currentCategoryPage -= 1
                                }
                            }
                    )
                }
            }
            // 인디케이터 점 제거 — 상단 categoryTabRow에서 심볼 버튼으로 이동

            // 미니 검색 키보드 — 검색 중일 때만
            if isSearching {
                miniSearchKeyboard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.22), value: isSearching)
        .overlay(
            Group {
                if templateInputState.isShowing {
                    TemplateInputOverlay(state: templateInputState)
                }
            }
        )
        .overlay(alignment: .bottom) {
            if showImageCopiedToast {
                Text(NSLocalizedString("이미지 복사됨 · 붙여넣기 하세요", comment: "Image copied toast"))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if showPinNotSetToast {
                Text(NSLocalizedString("앱에서 보안 PIN을 먼저 설정하세요", comment: "Set PIN in app first"))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onAppear {
            loadAllMemos()

            guard templateObserverToken == nil else { return }
            // 템플릿 입력 알림 구독
            templateObserverToken = NotificationCenter.default.addObserver(forName: NSNotification.Name("showTemplateInput"), object: nil, queue: .main) { notification in
                if let userInfo = notification.userInfo,
                   let text = userInfo["text"] as? String,
                   let placeholders = userInfo["placeholders"] as? [String],
                   let memoId = userInfo["memoId"] as? UUID {

                    print("🔍 템플릿 입력 요청 받음")
                    print("   메모 ID: \(memoId)")
                    print("   플레이스홀더: \(placeholders)")

                    templateInputState.originalText = text
                    templateInputState.placeholders = placeholders
                    templateInputState.templateId = memoId
                    // v4.0.8: attached 흐름이면 baseMemoId + baseMemoValue 캐시. 없으면 비움.
                    let baseMemoId = userInfo["baseMemoId"] as? UUID
                    templateInputState.baseMemoId = baseMemoId
                    if let baseId = baseMemoId,
                       let baseMemo = (try? MemoStore.shared.load(type: .memo))?.first(where: { $0.id == baseId }) {
                        templateInputState.baseMemoValue = baseMemo.value
                    } else {
                        templateInputState.baseMemoValue = ""
                    }

                    var initialInputs: [String: String] = [:]

                    for placeholder in placeholders {
                        print("   🔍 [KeyboardView] 플레이스홀더 값 로드 시도: \(placeholder)")
                        let values = PredefinedValuesStore.shared.getValuesForTemplate(placeholder: placeholder, templateId: memoId)
                        print("   📊 [KeyboardView] \(placeholder): \(values.count)개 - \(values)")

                        if let firstValue = values.first, !firstValue.isEmpty {
                            initialInputs[placeholder] = firstValue
                            print("   ✅ [KeyboardView] \(placeholder) 기본값 설정: \(firstValue)")
                        } else {
                            initialInputs[placeholder] = ""
                            print("   ⚠️ [KeyboardView] \(placeholder) 값 없음 - 빈 문자열 설정")
                        }
                    }

                    templateInputState.inputs = initialInputs
                    templateInputState.updateAllPlaceholdersFilled()

                    print("   초기 입력값: \(initialInputs)")

                    print("🎨 템플릿 값 선택 UI 표시")
                    withAnimation {
                        templateInputState.isShowing = true
                    }
                }
            }
        }
        .onDisappear {
            if let token = templateObserverToken {
                NotificationCenter.default.removeObserver(token)
                templateObserverToken = nil
            }
        }
    }

    // MARK: - Free Upgrade Banner

    private var freeUpgradeBanner: some View {
        Button {
            // KeyboardViewController가 이 알림을 받아 URL scheme으로 메인 앱 열기
            NotificationCenter.default.post(name: NSNotification.Name("openMainAppPaywall"), object: nil)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text(upgradeBannerText)
                    .font(.caption2.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.orange.opacity(0.85))
        }
        .buttonStyle(.plain)
    }

    /// 배너 문구: hidden 메모가 있으면 그 개수, 없으면 한도까지 남은 개수
    private var upgradeBannerText: String {
        if hiddenMemoCount > 0 {
            return String(format: NSLocalizedString("%d개 메모 더 보기 → Pro 업그레이드", comment: "Hidden memos upgrade banner"), hiddenMemoCount)
        }
        let remaining = max(0, ProFeatureManager.freeMemoLimit - totalMemoCount)
        return String(format: NSLocalizedString("메모 한도까지 %d개 남음 → Pro 업그레이드", comment: "Memo limit near banner"), remaining)
    }

    /// 한도 도달 임박 (남은 슬롯 2개 이하)
    private var isMemoLimitNear: Bool {
        guard isFreeUser else { return false }
        let remaining = ProFeatureManager.freeMemoLimit - totalMemoCount
        return remaining > 0 && remaining <= 2
    }

    // MARK: - Search Bar

    /// 키보드 상단 검색 바 — 탭하면 미니 QWERTY 펼침.
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.footnote)
                .foregroundColor(.secondary)

            if isSearching {
                Text(searchQuery.isEmpty
                     ? NSLocalizedString("Type to filter…", comment: "Search bar placeholder when active")
                     : searchQuery)
                    .font(.footnote)
                    .foregroundColor(searchQuery.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button {
                    KeyboardHaptics.softTap()
                    searchQuery = ""
                    isSearching = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(NSLocalizedString("Search snippets", comment: "Search bar idle"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm))
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isSearching else { return }
            KeyboardHaptics.softTap()
            isSearching = true
        }
        .accessibilityLabel(isSearching
            ? (searchQuery.isEmpty ? NSLocalizedString("검색 중", comment: "Search bar active empty") : searchQuery)
            : NSLocalizedString("메모 검색", comment: "Search field accessibility label"))
        .accessibilityHint(isSearching
            ? NSLocalizedString("x 버튼을 탭하면 검색을 닫습니다", comment: "Search bar active hint")
            : NSLocalizedString("탭하면 메모를 검색합니다", comment: "Search bar hint"))
        .accessibilityAddTraits(isSearching ? [] : .isButton)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: emptyStateIcon)
                .font(.title)
                .foregroundColor(theme.textFaint)

            VStack(spacing: 3) {
                Text(emptyStateTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(theme.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 16)

                Text(emptyStateSubtitle)
                    .font(.caption2)
                    .foregroundColor(theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // 빠져나갈 액션 — 검색·필터·콤보 탭에서 항상 명시적 escape 제공
            if let escapeAction = emptyStateEscape {
                Button {
                    KeyboardHaptics.softTap()
                    escapeAction.handler()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                        Text(escapeAction.label)
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.blue)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 4)
            }
        }
    }

    /// empty state에서 노출되는 escape 버튼 (있으면).
    private var emptyStateEscape: (label: String, handler: () -> Void)? {
        if !searchQuery.isEmpty {
            return (NSLocalizedString("Clear search", comment: "Empty escape: clear search"), {
                searchQuery = ""
                isSearching = false
            })
        }
        if selectedCategoryFilter == "★favorites" {
            return (NSLocalizedString("Show all", comment: "Empty escape: show all memos"), {
                currentCategoryPage = 0
            })
        }
        return nil
    }

    private var emptyStateIcon: String {
        if !searchQuery.isEmpty { return "magnifyingglass" }
        if selectedCategoryFilter == "★favorites" { return "heart.slash" }
        return "sparkles"
    }

    private var emptyStateTitle: String {
        if !searchQuery.isEmpty {
            return String(format: NSLocalizedString("No matches for \"%@\"", comment: "Empty search result"), searchQuery)
        }
        if selectedCategoryFilter == "★favorites" {
            return NSLocalizedString("No favorites yet", comment: "Empty: no favorites")
        }
        return NSLocalizedString("Save your IBAN once. Paste forever.", comment: "Empty: zero memos")
    }

    private var emptyStateSubtitle: String {
        if !searchQuery.isEmpty {
            return NSLocalizedString("Try a shorter keyword or clear the filter.", comment: "Empty hint: search")
        }
        if selectedCategoryFilter == "★favorites" {
            return NSLocalizedString("Mark snippets as favorite in the main app to see them here.", comment: "Empty hint: favorites")
        }
        return NSLocalizedString("Add snippets in the main app — they'll appear here in seconds.", comment: "Empty hint: zero memos")
    }

    // MARK: - Mini Search Keyboard

    /// 검색 전용 미니 QWERTY (높이 ~120pt). TextField 사용 X — 자체 버튼이 searchQuery 문자열에 append.
    private var miniSearchKeyboard: some View {
        VStack(spacing: 4) {
            ForEach(Array(currentRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 3) {
                    ForEach(row, id: \.self) { letter in
                        searchKey(letter: letter)
                    }
                }
            }
            HStack(spacing: 3) {
                if koreanInputEnabled { langToggleKey }   // 한국어 미사용 시 토글 숨김
                spaceKey
                backspaceKey
            }
        }
        .padding(.horizontal, 3)
        .onAppear {
            // 한국어 미사용이면 항상 영어 자판. 사용 중이면 기본 언어 설정을 시작값으로.
            searchKeyboardLang = (koreanInputEnabled && defaultTypingLang == "korean") ? .korean : .english
        }
        .padding(.vertical, 4)
        .background(theme.surfaceAlt)
    }

    private func searchKey(letter: String) -> some View {
        Button {
            KeyboardHaptics.tap()
            searchQuery.append(letter)
        } label: {
            Text(letter)
                .font(.subheadline.weight(.medium))
                .foregroundColor(theme.text)
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(theme.surface)
                .cornerRadius(theme.radiusXs)
        }
    }

    private var spaceKey: some View {
        Button {
            KeyboardHaptics.tap()
            searchQuery.append(" ")
        } label: {
            HStack {
                Spacer()
                Image(systemName: "space")
                    .font(.caption2)
                    .foregroundColor(theme.textMuted)
                Spacer()
            }
            .frame(height: 28)
            .background(theme.surface)
            .cornerRadius(theme.radiusXs)
        }
    }

    private var backspaceKey: some View {
        Button {
            KeyboardHaptics.tap()
            if !searchQuery.isEmpty { searchQuery.removeLast() }
        } label: {
            Image(systemName: "delete.left.fill")
                .font(.footnote.weight(.semibold))
                .foregroundColor(theme.text)
                .frame(width: 56, height: 28)
                .background(theme.divider)
                .cornerRadius(theme.radiusXs)
        }
    }

    private var langToggleKey: some View {
        Button {
            KeyboardHaptics.softTap()
            searchKeyboardLang = (searchKeyboardLang == .english) ? .korean : .english
        } label: {
            Text(searchKeyboardLang == .english ? "한" : "EN")
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.text)
                .frame(width: 40, height: 28)
                .background(theme.divider)
                .cornerRadius(theme.radiusXs)
        }
    }

    private var currentRows: [[String]] {
        // 한국어 미사용이면 무조건 영어 자판 (한글 노출 방지 방어)
        switch (koreanInputEnabled ? searchKeyboardLang : .english) {
        case .english:
            return [
                ["q","w","e","r","t","y","u","i","o","p"],
                ["a","s","d","f","g","h","j","k","l"],
                ["z","x","c","v","b","n","m"]
            ]
        case .korean:
            return [
                ["ㅂ","ㅈ","ㄷ","ㄱ","ㅅ","ㅛ","ㅕ","ㅑ","ㅐ","ㅔ"],
                ["ㅁ","ㄴ","ㅇ","ㄹ","ㅎ","ㅗ","ㅓ","ㅏ","ㅣ"],
                ["ㅋ","ㅌ","ㅊ","ㅍ","ㅠ","ㅜ","ㅡ"]
            ]
        }
    }

    // MARK: - Category Tab Row

    private var categoryTabRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(categoryPages.enumerated()), id: \.offset) { index, key in
                    let isSelected = currentCategoryPage == index
                    let accent = colorForCategoryKey(key)
                    Button {
                        KeyboardHaptics.tap()
                        currentCategoryPage = index
                    } label: {
                        Image(systemName: iconForCategoryKey(key))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSelected ? .white : theme.textMuted)
                            .frame(width: 32, height: 28)
                            .background(isSelected ? accent : theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(labelForCategoryKey(key))
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
    }

    /// 카테고리 페이지 키에 표시할 짧은 라벨.
    private func labelForCategoryKey(_ key: String) -> String {
        if key == "★all" { return NSLocalizedString("전체", comment: "Category tab: all") }
        if key == "★favorites" { return NSLocalizedString("즐겨찾기", comment: "Category tab: favorites") }
        return key
    }

    // MARK: - Recent Section

    /// 최근 1주 사용한 메모 5개 — 헤더 없이 가로 스크롤 미니 카드만 (공간 절약)
    private var recentSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(theme.textFaint)
                ForEach(recentMemos) { memo in
                    recentChip(memo)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 2)
    }

    private func recentChip(_ memo: Memo) -> some View {
        Button {
            memoButtonAction(for: memo)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: categoryIconFor(memo))
                    .font(.caption2)
                    .foregroundColor(categoryColorFor(memo) ?? theme.textMuted)
                Text(memo.title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(theme.text)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke((categoryColorFor(memo) ?? .clear).opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(String(format: NSLocalizedString("최근: %@", comment: "Recent memo chip label"), memo.title))
        .accessibilityHint(memoAccessibilityHint(for: memo))
    }

    // MARK: - Memo Button

    @ViewBuilder
    private func memoButton(for memo: Memo, useTemplate: Bool = false) -> some View {
        let catColor = categoryColorFor(memo)
        let isImageMemo = (memo.contentType == .image || memo.contentType == .mixed)
        let imageFileName = memo.imageFileNames.first ?? memo.imageFileName ?? ""
        // attached template 메모는 useTemplate=true일 때 템플릿 적용, false면 메모만 (bypass).
        let bypass = memo.attachedTemplateId != nil && !useTemplate

        if isImageMemo && !imageFileName.isEmpty {
            // 이미지 메모: 전체 배경으로 이미지 표시
            Button {
                memoButtonAction(for: memo)
            } label: {
                ImageMemoButton(
                    title: memo.title,
                    fileName: imageFileName,
                    buttonHeight: buttonHeight,
                    buttonFontSize: buttonFontSize
                )
            }
            .contextMenu {
                Button {
                    UIPasteboard.general.string = memo.value
                    KeyboardHaptics.tap()
                } label: {
                    Label(NSLocalizedString("Copy to clipboard", comment: "Context menu: copy"), systemImage: "doc.on.doc")
                }
            } preview: { memoLongPressPreview(memo: memo) }
            .accessibilityLabel(memoAccessibilityLabel(for: memo))
            .accessibilityHint(memoAccessibilityHint(for: memo))
        } else {
            Button {
                memoButtonAction(for: memo, bypassTemplate: bypass)
            } label: {
                memoButtonLabel(for: memo, catColor: catColor, useTemplate: useTemplate)
            }
            .contextMenu {
                Button {
                    UIPasteboard.general.string = memo.value
                    KeyboardHaptics.tap()
                } label: {
                    Label(NSLocalizedString("Copy to clipboard", comment: "Context menu: copy"), systemImage: "doc.on.doc")
                }
            } preview: {
                memoLongPressPreview(memo: memo)
            }
            .accessibilityLabel(memoAccessibilityLabel(for: memo))
            .accessibilityHint(memoAccessibilityHint(for: memo))
        }
    }

    private func memoAccessibilityLabel(for memo: Memo) -> String {
        var parts: [String] = [memo.title]
        if memo.isSecure { parts.append(NSLocalizedString("보안 메모", comment: "VoiceOver: secure memo badge")) }
        if memo.isTemplate { parts.append(NSLocalizedString("템플릿", comment: "VoiceOver: template badge")) }
        if memo.isCombo { parts.append(NSLocalizedString("콤보", comment: "VoiceOver: combo badge")) }
        if memo.contentType == .image || memo.contentType == .mixed {
            parts.append(NSLocalizedString("이미지 메모", comment: "VoiceOver: image memo"))
        } else if !memo.value.isEmpty {
            let preview = String(memo.value.prefix(40))
            parts.append(preview)
        }
        return parts.joined(separator: ", ")
    }

    private func memoAccessibilityHint(for memo: Memo) -> String {
        if memo.isTemplate {
            return NSLocalizedString("탭하면 변수 값을 입력 후 붙여넣기합니다", comment: "Template memo button hint")
        } else if memo.isCombo {
            return NSLocalizedString("탭할 때마다 다음 값이 순서대로 입력됩니다", comment: "Combo memo button hint")
        } else if memo.isSecure {
            return NSLocalizedString("탭하면 PIN 인증 후 붙여넣기합니다", comment: "Secure memo button hint")
        } else {
            return NSLocalizedString("탭하면 클립보드에 복사됩니다", comment: "Clipboard item copy hint")
        }
    }

    /// attachedTemplateId가 있는 메모용 분할 버튼 — 왼쪽: 메모값만 입력, 오른쪽: 템플릿 포함 입력
    /// 키보드에서 메모 길게 누르면 떠오르는 미리보기 — Mail 스타일
    private func memoLongPressPreview(memo: Memo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: categoryIconFor(memo))
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(categoryColorFor(memo) ?? theme.textMuted)
                Text(memo.title)
                    .font(.callout.weight(.semibold))
                    .foregroundColor(theme.text)
                Spacer(minLength: 0)
                if memo.isCombo {
                    Text(NSLocalizedString("Combo", comment: "Tag: combo"))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                }
                if memo.isTemplate || !memo.templateVariables.isEmpty {
                    Text(NSLocalizedString("Template", comment: "Tag: template"))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .clipShape(Capsule())
                }
                if memo.isSecure {
                    badgeLetter("S", color: .gray)
                }
            }

            // 콤보면 단계별 라인 모두 보여주기, 아니면 본문 통째로
            if memo.isCombo && !memo.comboValues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(memo.comboValues.enumerated()), id: \.offset) { index, value in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.system(.caption, design: .monospaced, weight: .semibold))
                                .foregroundColor(theme.textFaint)
                            Text(value)
                                .font(.footnote)
                                .foregroundColor(theme.text)
                        }
                    }
                }
            } else {
                Text(memo.value)
                    .font(.footnote)
                    .foregroundColor(theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 360, minHeight: 100, idealHeight: 200, maxHeight: 400)
        .background(theme.surface)
    }

    private func memoButtonAction(for memo: Memo, bypassTemplate: Bool = false) {
        KeyboardHaptics.tap()

        if isSearching {
            withAnimation(.easeOut(duration: 0.18)) {
                searchQuery = ""
                isSearching = false
            }
        }

        if memo.contentType == .image || memo.contentType == .mixed {
            copyImageToClipboard(memo: memo)
            return
        }

        if memo.isSecure {
            authenticateAndInsert(memo: memo, bypassTemplate: bypassTemplate)
            return
        }

        insertMemo(memo, bypassTemplate: bypassTemplate)
    }

    private func insertMemo(_ memo: Memo, bypassTemplate: Bool = false) {
        // 보안 메모면 복호화한 값을 넣는다(PIN 인증 후 호출됨). 키 미동기화로 복호화 불가면 중단.
        let valueToInsert: String
        if SecureMemoCrypto.isEncrypted(memo.value) {
            guard let decrypted = SecureMemoCrypto.decrypt(memo.value) else {
                print("🔒 [insertMemo] 보안 키 미동기화 - 복호화 불가, 삽입 중단")
                return
            }
            valueToInsert = decrypted
        } else {
            valueToInsert = memo.value
        }
        var userInfo: [String: Any] = ["memoId": memo.id]
        if bypassTemplate { userInfo["bypassAttachedTemplate"] = true }
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: "addTextEntry"),
            object: valueToInsert,
            userInfo: userInfo
        )
        if memo.isCombo && !memo.comboValues.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                loadAllMemos()
            }
        }
    }

    private func authenticateAndInsert(memo: Memo, bypassTemplate: Bool = false) {
        let storedHash = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.string(forKey: "keyboard_secure_pin_hash") ?? ""
        guard !storedHash.isEmpty else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            withAnimation { showPinNotSetToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation { showPinNotSetToast = false }
            }
            return
        }
        pendingSecureMemo = memo
        pendingBypassTemplate = bypassTemplate
        enteredPIN = ""
        pinEntryWrong = false
        showPINEntry = true
    }

    private func verifyPIN() {
        let digest = SHA256.hash(data: Data(enteredPIN.utf8))
        let hash = digest.compactMap { String(format: "%02x", $0) }.joined()
        let storedHash = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.string(forKey: "keyboard_secure_pin_hash") ?? ""
        if hash == storedHash {
            showPINEntry = false
            if let memo = pendingSecureMemo { insertMemo(memo, bypassTemplate: pendingBypassTemplate) }
            pendingSecureMemo = nil
            enteredPIN = ""
            pinEntryWrong = false
            pendingBypassTemplate = false
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            enteredPIN = ""
            pinEntryWrong = true
        }
    }

    private func copyImageToClipboard(memo: Memo) {
        let fileName = memo.imageFileNames.first ?? memo.imageFileName ?? ""
        guard !fileName.isEmpty,
              let image = MemoStore.shared.loadImage(fileName: fileName) else {
            print("⚠️ [KeyboardView] 이미지 로드 실패: \(memo.title)")
            return
        }
        UIPasteboard.general.image = image
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        print("✅ [KeyboardView] 이미지 클립보드 복사 완료: \(memo.title)")
        withAnimation { showImageCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showImageCopiedToast = false }
        }
    }

    /// T/C/S 같은 글자 뱃지 — 메모 셀의 type 표시 (심볼 대신 통일된 작은 라벨).
    @ViewBuilder
    private func badgeLetter(_ letter: String, color: Color) -> some View {
        Text(letter)
            .font(.caption2.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color)
            .cornerRadius(theme.radiusXs)
    }

    private func memoButtonLabel(for memo: Memo, catColor: Color?, useTemplate: Bool = false) -> some View {
        let style = typeStyle(for: memo, useTemplate: useTemplate)
        return ZStack {
            // 기본 키 색(커스텀 색 설정 존중) 위에, 사용자 카테고리가 있을 때만 그 색을 옅게 틴트.
            // 제목 가독성을 위해 라이트 0.14 / 다크 0.22로 약하게만 입힌다.
            RoundedRectangle(cornerRadius: theme.radiusMd)
                .foregroundColor(keyColor)
                .overlay(
                    Group {
                        if let catColor {
                            RoundedRectangle(cornerRadius: theme.radiusMd)
                                .fill(catColor.opacity(theme.isDark ? 0.22 : 0.14))
                        }
                    }
                )
                .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)

            // 메모 칸 안 텍스트는 제목만. 타입 구분은 테두리(색+dash 패턴)으로 — 색맹 친화.
            Text(memo.title)
                .foregroundColor(theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .font(.system(size: buttonFontSize, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(10)
        }
        .frame(height: buttonHeight)
        // 모든 메모 칸에 기본 테두리 — 칸 경계가 또렷하게 보이도록.
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMd)
                .strokeBorder(theme.divider, lineWidth: 1)
        )
        // 타입 구분 테두리(템플릿/콤보/보안) — 색맹 친화, 기본 테두리 위에 덧입힌다.
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMd)
                .strokeBorder(style.color,
                              style: StrokeStyle(lineWidth: style.lineWidth, dash: style.dash))
        )
    }

    /// 메모 타입 시각 스타일 — 테두리 색·dash 패턴. 색맹 보조용 (색 + 패턴 이중 큐).
    /// 우선순위: useTemplate(템플릿 적용 셀) > 콤보 > 보안 > 본체 템플릿.
    private func typeStyle(for memo: Memo, useTemplate: Bool) -> TypeVisualStyle {
        if useTemplate || memo.isTemplate || !memo.templateVariables.isEmpty {
            return TypeVisualStyle(color: .purple, lineWidth: 1.5, dash: [])
        }
        if memo.isCombo {
            return TypeVisualStyle(color: .orange, lineWidth: 1.5, dash: [5, 3])
        }
        if memo.isSecure {
            return TypeVisualStyle(color: .gray, lineWidth: 1.5, dash: [1, 3])
        }
        return TypeVisualStyle(color: .clear, lineWidth: 0, dash: [])
    }

    // MARK: - Data Loading

    private func loadAllMemos() {
        let limit = ProFeatureManager.keyboardMemoDisplayLimit
        allMemos = limit == Int.max ? clipMemos : Array(clipMemos.prefix(limit))
    }

    // MARK: - Free tier

    private var isFreeUser: Bool {
        !ProFeatureManager.hasFullAccess
    }

    private var totalMemoCount: Int { clipMemos.count }
    private var hiddenMemoCount: Int {
        guard isFreeUser else { return 0 }
        return max(0, totalMemoCount - ProFeatureManager.freeMemoLimit)
    }

    // MARK: - PIN Entry Overlay

    private var pinEntryOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.orange)
                    Text(NSLocalizedString("보안 PIN 입력", comment: "PIN entry overlay title"))
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.primary)
                }
                .padding(.top, 14)

                if pinEntryWrong {
                    Text(NSLocalizedString("PIN이 올바르지 않습니다", comment: "PIN wrong error"))
                        .font(.caption2)
                        .foregroundColor(.red)
                }

                // 4-dot indicator
                HStack(spacing: 14) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i < enteredPIN.count ? Color.orange : Color(UIColor.systemGray4))
                            .frame(width: 11, height: 11)
                    }
                }
                .padding(.vertical, 4)

                // Number grid
                VStack(spacing: 4) {
                    ForEach([[1,2,3],[4,5,6],[7,8,9]], id: \.first) { row in
                        HStack(spacing: 4) {
                            ForEach(row, id: \.self) { n in
                                pinOverlayDigitKey(String(n))
                            }
                        }
                    }
                    HStack(spacing: 4) {
                        pinOverlayCancelKey
                        pinOverlayDigitKey("0")
                        pinOverlayBackspaceKey
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: theme.radiusLg)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.25), radius: 10)
            )
            .padding(.horizontal, 40)
        }
    }

    private func pinOverlayDigitKey(_ digit: String) -> some View {
        Button {
            KeyboardHaptics.tap()
            guard enteredPIN.count < 4 else { return }
            enteredPIN.append(digit)
            pinEntryWrong = false
            if enteredPIN.count == 4 { verifyPIN() }
        } label: {
            Text(digit)
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color(UIColor.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var pinOverlayCancelKey: some View {
        Button {
            KeyboardHaptics.softTap()
            showPINEntry = false
            pendingSecureMemo = nil
            enteredPIN = ""
            pinEntryWrong = false
        } label: {
            Text(NSLocalizedString("취소", comment: "Cancel"))
                .font(.footnote.weight(.medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color(UIColor.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var pinOverlayBackspaceKey: some View {
        Button {
            KeyboardHaptics.tap()
            if !enteredPIN.isEmpty { enteredPIN.removeLast() }
        } label: {
            Image(systemName: "delete.left")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color(UIColor.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Color Helpers

    /// 메모가 **사용자가 만든 카테고리**에 속할 때만 그 카테고리 색을 반환한다.
    /// 카테고리가 없으면(자동 분류값만 있는 경우 포함) nil → 색을 입히지 않는다.
    /// (이전엔 자동 분류 타입에도 색을 반환해, 사용자 카테고리가 없는데도 메모에 색이
    ///  칠해지는 버그가 있었음. 카테고리는 이제 사용자가 직접 만들어 쓰므로 그 색만 사용.)
    private func categoryColorFor(_ memo: Memo) -> Color? {
        guard let idx = sharedUserCategories.firstIndex(of: memo.category) else { return nil }
        if let hex = customCategoryColors[memo.category], let c = Color(hex: hex) { return c }
        let palette: [Color] = [.blue, .green, .orange, .purple, .teal, .indigo, .cyan]
        return palette[idx % palette.count]
    }

    private func categoryIconFor(_ memo: Memo) -> String {
        if let type = ClipboardItemType.allCases.first(where: { $0.rawValue == memo.category }) {
            return type.icon
        }
        return "doc.text"
    }

    /// 카테고리 페이지 키(★all/★favorites/이름)에 대응되는 SF Symbol.
    /// 사용자 커스텀 아이콘 — userCategoryIcons_v1 에서 로드
    private var customCategoryIcons: [String: String] {
        UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?
            .dictionary(forKey: "userCategoryIcons_v1") as? [String: String] ?? [:]
    }

    /// 사용자가 지정한 카테고리 색 — userCategoryColors_v1 에서 로드(앱과 동일 키).
    private var customCategoryColors: [String: String] {
        UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?
            .dictionary(forKey: "userCategoryColors_v1") as? [String: String] ?? [:]
    }

    /// 커스텀 > 인덱스 팔레트 순으로 폴백 (iOS 앱과 동일)
    private func iconForCategoryKey(_ key: String) -> String {
        if key == "★all" { return "square.grid.2x2.fill" }
        if key == "★favorites" { return "heart.fill" }
        if let custom = customCategoryIcons[key] { return custom }
        let icons = ["folder.fill", "bookmark.fill", "tag.fill", "briefcase.fill",
                     "star.fill", "heart.circle.fill", "person.fill", "house.fill"]
        let idx = sharedUserCategories.firstIndex(of: key) ?? 0
        return icons[idx % icons.count]
    }

    /// iOS 앱 ClipKeyboardList.customCategoryColor과 동일한 팔레트 + 인덱스 기반
    private func colorForCategoryKey(_ key: String) -> Color {
        if key == "★all" { return .blue }
        // 즐겨찾기 지정색 — 앱의 Color.clipFavorite(#FF4A9E)와 동일 (타깃 분리로 인라인).
        if key == "★favorites" { return Color(red: 1.0, green: 0.29, blue: 0.62) }
        if let hex = customCategoryColors[key], let c = Color(hex: hex) { return c }
        let palette: [Color] = [.blue, .green, .orange, .purple, .teal, .indigo, .cyan]
        let idx = sharedUserCategories.firstIndex(of: key) ?? 0
        return palette[idx % palette.count]
    }

    // MARK: - Theme-derived Colors (Paper 테마 + 사용자 커스텀 오버라이드)

    /// 기본은 iOS 앱 Paper 테마. `useCustomColors=true`이면 사용자 hex로 오버라이드.
    private var backgroundColor: Color {
        if useCustomColors, !customBgHex.isEmpty, let custom = Color(hex: customBgHex) {
            return custom
        }
        return theme.bg
    }

    private var keyColor: Color {
        if useCustomColors, !customKeyHex.isEmpty, let custom = Color(hex: customKeyHex) {
            return custom
        }
        return theme.surface
    }
}

// MARK: - Image Memo Button

struct ImageMemoButton: View {
    let title: String
    let fileName: String
    let buttonHeight: Double
    let buttonFontSize: Double

    @Environment(\.colorScheme) private var colorScheme
    private var theme: AppTheme { AppTheme.resolve(kind: .paper, isDark: colorScheme == .dark) }

    @State private var image: UIImage? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: theme.radiusSm)
                .foregroundColor(Color(uiColor: .systemGray5))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: buttonHeight)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm))
            }

            // 텍스트 가독성을 위한 하단 그라디언트
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm))

            Text(title)
                .font(.system(size: buttonFontSize, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .padding(10)
        }
        .frame(height: buttonHeight)
        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
        .onAppear {
            guard image == nil, !fileName.isEmpty else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                let loaded = MemoStore.shared.loadImage(fileName: fileName)
                DispatchQueue.main.async { image = loaded }
            }
        }
    }
}


#Preview {
    KeyboardView()
}

// 템플릿 입력 오버레이
struct TemplateInputOverlay: View {
    @ObservedObject var state: TemplateInputState

    @Environment(\.colorScheme) private var colorScheme
    private var theme: AppTheme { AppTheme.resolve(kind: .paper, isDark: colorScheme == .dark) }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: 헤더 — 항상 보임: [00][000][0000] + 입력 + 닫기
            HStack(spacing: 8) {
                    Spacer()

                    // 숫자 플레이스홀더가 있을 때만 자릿수 패드 표시
                    if let numericPH = state.placeholders.first(where: { TemplateVariableProcessor.isNumericToken($0) }) {
                        HStack(spacing: 6) {
                            ForEach(["0", "00", "000", "0000"], id: \.self) { zeros in
                                let cur = state.inputs[numericPH] ?? ""
                                let inactive = cur.isEmpty || cur == "0"
                                Button {
                                    let v = state.inputs[numericPH] ?? ""
                                    guard !v.isEmpty && v != "0" else { return }
                                    guard v.count + zeros.count <= 13 else { return }
                                    state.inputs[numericPH] = v + zeros
                                    state.updateAllPlaceholdersFilled()
                                    KeyboardHaptics.tap()
                                } label: {
                                    Text(zeros)
                                        .font(.system(.footnote, design: .monospaced, weight: .semibold))
                                        .lineLimit(1)
                                        .fixedSize()
                                        .frame(height: 36)
                                        .padding(.horizontal, 10)
                                        .background(inactive ? Color.blue.opacity(0.05) : Color.blue.opacity(0.12))
                                        .foregroundColor(inactive ? Color.blue.opacity(0.35) : Color.blue)
                                        .cornerRadius(theme.radiusXs)
                                }
                                .disabled(inactive)
                            }
                        }
                    }

                    // 입력 버튼 (항상 노출)
                    Button {
                        completeInput()
                    } label: {
                        Text(NSLocalizedString("입력하기", comment: "Insert with template button"))
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(state.allPlaceholdersFilled ? Color.blue : Color.gray.opacity(0.4))
                            .cornerRadius(theme.radiusSm)
                    }
                    .disabled(!state.allPlaceholdersFilled)

                    // 닫기
                    Button {
                        withAnimation {
                            state.isShowing = false
                            state.currentFocusedPlaceholder = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))

                Divider()

                // MARK: 컬러 프리뷰
                coloredPreviewText
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(theme.radiusXs)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                // MARK: 플레이스홀더 입력 (스크롤)
                ScrollView {
                    VStack(spacing: 16) {
                        if state.placeholders.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "questionmark.circle")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text(NSLocalizedString("No template variables", comment: "Empty state: no template variables"))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(NSLocalizedString("This template has no values to set.\nPlease try again.", comment: "Empty state: no template variables hint"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(40)
                        } else {
                            ForEach(state.placeholders, id: \.self) { placeholder in
                                PlaceholderInputView(
                                    placeholder: placeholder,
                                    selectedValue: Binding(
                                        get: { state.inputs[placeholder] ?? "" },
                                        set: { newValue in
                                            state.inputs[placeholder] = newValue
                                            state.updateAllPlaceholdersFilled()
                                            let hasNumeric = state.placeholders.contains { TemplateVariableProcessor.isNumericToken($0) }
                                            if state.allPlaceholdersFilled && !hasNumeric {
                                                completeInput()
                                            }
                                        }
                                    ),
                                    templateId: state.templateId
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(Color(UIColor.systemBackground))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }

    private struct PreviewSegment {
        let text: String
        let isValue: Bool
    }

    private func parseSegments() -> [PreviewSegment] {
        let original = state.originalText
        var segments: [PreviewSegment] = []
        guard let regex = try? NSRegularExpression(pattern: "\\{([^}]+)\\}") else {
            return [PreviewSegment(text: original, isValue: false)]
        }
        var lastEnd = original.startIndex
        for match in regex.matches(in: original, range: NSRange(original.startIndex..., in: original)) {
            guard let range = Range(match.range, in: original) else { continue }
            if lastEnd < range.lowerBound {
                segments.append(PreviewSegment(text: String(original[lastEnd..<range.lowerBound]), isValue: false))
            }
            let key = String(original[range])
            let value = state.inputs[key] ?? ""
            segments.append(PreviewSegment(text: value.isEmpty ? key : value, isValue: !value.isEmpty))
            lastEnd = range.upperBound
        }
        if lastEnd < original.endIndex {
            segments.append(PreviewSegment(text: String(original[lastEnd...]), isValue: false))
        }
        return segments
    }

    private var coloredPreviewText: Text {
        let base: Text = state.baseMemoValue.isEmpty ? Text("") : Text(state.baseMemoValue + "\n")
        return parseSegments().reduce(base) { acc, seg in
            seg.isValue
                ? Text("\(acc)\(Text(seg.text).foregroundColor(Color(UIColor.systemGreen)).bold())")
                : Text("\(acc)\(Text(seg.text))")
        }
    }

    private func completeInput() {
        var userInfo: [String: Any] = [
            "text": state.originalText,
            "inputs": state.inputs
        ]
        if let baseId = state.baseMemoId { userInfo["baseMemoId"] = baseId }
        if let templateId = state.templateId { userInfo["memoId"] = templateId }
        NotificationCenter.default.post(
            name: NSNotification.Name("templateInputComplete"),
            object: nil,
            userInfo: userInfo
        )
        withAnimation {
            state.isShowing = false
            state.currentFocusedPlaceholder = nil
            state.baseMemoId = nil
        }
    }
}

// 플레이스홀더 입력 뷰 (선택 방식 + 숫자 토큰 직접 입력)
struct PlaceholderInputView: View {
    let placeholder: String
    @Binding var selectedValue: String
    let templateId: UUID?

    @Environment(\.colorScheme) private var colorScheme
    private var theme: AppTheme { AppTheme.resolve(kind: .paper, isDark: colorScheme == .dark) }

    private var predefinedValues: [String] {
        let storedValues = PredefinedValuesStore.shared.getValuesForTemplate(placeholder: placeholder, templateId: templateId)
        return storedValues
    }

    /// v4.0.8: 토큰명에 금액/amount/qty 등 키워드가 있으면 numeric 직접 입력 모드.
    private var isNumericToken: Bool {
        TemplateVariableProcessor.isNumericToken(placeholder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isNumericToken {
                numericInputSection
            } else {
                textPredefinedSection
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Numeric input
    // 자릿수 패드(00·000·0000) + 1-9 수평 스크롤.

    @ViewBuilder
    private var numericInputSection: some View {
        VStack(spacing: 8) {
            // 전체 너비: [1][2][3][4][5][6][7][8][9][⌫]
            HStack(spacing: 6) {
                ForEach(["1","2","3","4","5","6","7","8","9"], id: \.self) { digit in
                    numericScrollKey(digit)
                }
                numericScrollBackspace
            }

            // 사전 저장 값 빠른 선택
            if !predefinedValues.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(predefinedValues, id: \.self) { value in
                            Button {
                                selectedValue = value
                                KeyboardHaptics.tap()
                            } label: {
                                Text(value)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(selectedValue == value ? Color.blue.opacity(0.2) : Color(UIColor.systemGray5))
                                    .foregroundColor(selectedValue == value ? .blue : .primary)
                                    .cornerRadius(theme.radiusSm)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func numericScrollKey(_ digit: String) -> some View {
        Button {
            guard selectedValue.count + digit.count <= 13 else { return }
            if selectedValue.isEmpty && digit == "00" {
                selectedValue = "0"
            } else if selectedValue == "0" {
                selectedValue = digit == "0" || digit == "00" ? "0" : digit
            } else {
                selectedValue += digit
            }
            KeyboardHaptics.tap()
        } label: {
            Text(digit)
                .font(.system(.headline, design: .monospaced, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(UIColor.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(theme.radiusXs)
        }
    }

    @ViewBuilder
    private var numericScrollBackspace: some View {
        Button {
            if !selectedValue.isEmpty { selectedValue.removeLast() }
            KeyboardHaptics.tap()
        } label: {
            Image(systemName: "delete.left")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(UIColor.systemGray4))
                .foregroundColor(.primary)
                .cornerRadius(theme.radiusXs)
        }
    }

    // MARK: - Text predefined (existing flow)

    @ViewBuilder
    private var textPredefinedSection: some View {
        if predefinedValues.isEmpty {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(NSLocalizedString("No saved values", comment: "Placeholder values empty title"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }

                Text(String(format: NSLocalizedString("Open the app to add values for '%@' in placeholder settings", comment: "Placeholder values empty hint"), placeholder.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(theme.radiusXs)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(predefinedValues, id: \.self) { value in
                        Button {
                            selectedValue = value
                            KeyboardHaptics.tap()
                        } label: {
                            Text(value)
                                .font(.footnote.weight(selectedValue == value ? .semibold : .regular))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedValue == value ? Color.blue : Color(UIColor.systemGray5))
                                .foregroundColor(selectedValue == value ? .white : .primary)
                                .cornerRadius(theme.radiusLg)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Type Visual Style (색맹 보조 — 색 + dash 패턴)

/// 메모 타입 시각 표현. 테두리 색 + dash 패턴 차이로 색약·색맹 사용자도
/// 패턴만으로 구분 가능.
private struct TypeVisualStyle {
    let color: Color
    let lineWidth: CGFloat
    let dash: [CGFloat]
}

// MARK: - DisplayItem

/// 메모 그리드 1셀. 같은 메모가 attached template으로 2셀로 expand될 때
/// useTemplate 값으로 구분. id는 (memoId, useTemplate) 합성으로 SwiftUI ForEach 충돌 방지.
private struct DisplayItem: Identifiable {
    let memo: Memo
    let useTemplate: Bool
    var id: String { "\(memo.id.uuidString)-\(useTemplate ? "t" : "n")" }
}

