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
    @AppStorage("keyboardButtonHeight", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var buttonHeight: Double = 40.0
    @AppStorage("keyboardButtonFontSize", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var buttonFontSize: Double = 15.0

    // 색상 커스터마이즈 — 기본은 false (Paper 테마 사용), true면 hex 오버라이드
    @AppStorage("keyboardUseCustomColors", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var useCustomColors: Bool = false
    @AppStorage("keyboardCustomBgHex", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var customBgHex: String = ""
    @AppStorage("keyboardCustomKeyHex", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var customKeyHex: String = ""

    // 옵션 토글 — 기본 OFF로 화면 공간 확보
    @AppStorage("keyboardShowSearch", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var showSearchBar: Bool = false
    @AppStorage("keyboardShowRecent", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var showRecentSection: Bool = false

    // 타이핑 모드 — Memos / Type 전환 (기본: 키보드)
    @State private var inputMode: InputMode = .typing

    /// KeyboardViewController가 init으로 주입 (let — SwiftUI 재렌더에도 유지)
    let typingProxy: TypingInputProxy?

    /// 호스트 텍스트 필드 상태 — clearAll(X) 버튼은 hasText일 때만 노출.
    /// nil이면 (preview 등) 항상 표시.
    @ObservedObject var documentState: KeyboardDocumentState

    init(typingProxy: TypingInputProxy? = nil, documentState: KeyboardDocumentState = KeyboardDocumentState()) {
        self.typingProxy = typingProxy
        self.documentState = documentState
    }

    enum InputMode { case memos, typing }

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

    // 즐겨찾기만 보기 토글 — 재실행해도 유지
    @AppStorage("keyboardShowFavoritesOnly", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo"))
    private var showFavoritesOnly: Bool = false

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

    /// 즐겨찾기 토글 + 검색만 적용
    private var filteredMemos: [Memo] {
        var result = allMemos

        if showFavoritesOnly {
            result = result.filter { $0.isFavorite }
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

    /// 최근 사용 메모 5개 — lastUsedAt 기준 1주 이내, 최신순
    private var recentMemos: [Memo] {
        let weekAgo = Date().addingTimeInterval(-60 * 60 * 24 * 7)
        return allMemos
            .filter { ($0.lastUsedAt ?? .distantPast) >= weekAgo }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    /// 최근 사용 섹션 노출 조건 — 검색·즐겨찾기 모두 비활성일 때만
    private var shouldShowRecentSection: Bool {
        searchQuery.isEmpty && !showFavoritesOnly && !recentMemos.isEmpty
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 모드 탭 — Memos / Type
                modeTabBar

                if inputMode == .typing, let proxy = typingProxy {
                    TypingKeyboardView(proxy: proxy)
                } else {
                    memoModeContent
                }
            }

            if showPINEntry {
                pinEntryOverlay
            }
        }
    }

    private var modeTabBar: some View {
        HStack(spacing: 6) {
            modeIconTab(
                icon: "keyboard",
                isSelected: inputMode == .typing,
                label: NSLocalizedString("타이핑 모드", comment: "Typing keyboard mode tab"),
                hint: NSLocalizedString("직접 타이핑 모드로 전환합니다", comment: "Typing mode tab hint")
            ) {
                inputMode = .typing
            }
            modeIconTab(
                icon: "list.bullet.rectangle",
                isSelected: inputMode == .memos,
                label: NSLocalizedString("메모 모드", comment: "Memo list mode tab"),
                hint: NSLocalizedString("저장된 메모 목록 모드로 전환합니다", comment: "Memo mode tab hint")
            ) {
                inputMode = .memos
            }
            // 메모 모드일 때만 즐겨찾기 토글 노출
            if inputMode == .memos {
                favoritesToggleButton
            }
            Spacer()
            // 텍스트 필드에 입력된 내용이 있을 때만 X 버튼 노출
            if let proxy = typingProxy, documentState.hasText {
                clearAllButton(proxy: proxy)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .animation(.easeOut(duration: 0.18), value: documentState.hasText)
    }

    /// 즐겨찾기만 보기 토글 버튼 — 활성 시 노란색 별 아이콘
    private var favoritesToggleButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showFavoritesOnly.toggle()
        } label: {
            Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(showFavoritesOnly ? .white : theme.text)
                .frame(width: 36, height: 28)
                .background(showFavoritesOnly ? Color.yellow : theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(NSLocalizedString("즐겨찾기만 보기", comment: "Toggle favorites filter"))
        .accessibilityValue(showFavoritesOnly
            ? NSLocalizedString("켬", comment: "Toggle state: on")
            : NSLocalizedString("끔", comment: "Toggle state: off"))
        .accessibilityHint(NSLocalizedString("즐겨찾기 메모만 표시하거나 전체를 표시합니다", comment: "Favorites toggle hint"))
    }

    private func modeIconTab(icon: String, isSelected: Bool, label: String, hint: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isSelected ? .white : theme.text)
                .frame(width: 36, height: 28)
                .background(isSelected ? Color.blue : theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(label)
        .accessibilityHint(hint)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func clearAllButton(proxy: TypingInputProxy) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            proxy.clearAll()
        } label: {
            Image(systemName: "xmark.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.textMuted)
                .frame(width: 36, height: 28)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
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

            // 검색 바 — 사용자 토글 ON일 때만
            if showSearchBar {
                searchBar
            }

            // 최근 사용 섹션 — 사용자 토글 ON + 검색·즐겨찾기 비활성일 때만
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
                            ForEach(filteredMemos) { memo in
                                memoButton(for: memo)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                }
            }

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
                    .font(.system(size: 13, weight: .medium))
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
                    .font(.system(size: 13, weight: .medium))
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
                    .font(.system(size: 11))
                Text(upgradeBannerText)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
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
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            if isSearching {
                Text(searchQuery.isEmpty
                     ? NSLocalizedString("Type to filter…", comment: "Search bar placeholder when active")
                     : searchQuery)
                    .font(.system(size: 14))
                    .foregroundColor(searchQuery.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    searchQuery = ""
                    isSearching = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            } else {
                Text(NSLocalizedString("Search snippets", comment: "Search bar idle"))
                    .font(.system(size: 14))
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
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
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
                .font(.system(size: 26))
                .foregroundColor(theme.textFaint)

            VStack(spacing: 3) {
                Text(emptyStateTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 16)

                Text(emptyStateSubtitle)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // 빠져나갈 액션 — 검색·필터·콤보 탭에서 항상 명시적 escape 제공
            if let escapeAction = emptyStateEscape {
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    escapeAction.handler()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                        Text(escapeAction.label)
                            .font(.system(size: 13, weight: .semibold))
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
        if showFavoritesOnly {
            return (NSLocalizedString("Show all", comment: "Empty escape: show all memos"), {
                showFavoritesOnly = false
            })
        }
        return nil
    }

    private var emptyStateIcon: String {
        if !searchQuery.isEmpty { return "magnifyingglass" }
        if showFavoritesOnly { return "star.slash" }
        return "sparkles"
    }

    private var emptyStateTitle: String {
        if !searchQuery.isEmpty {
            return String(format: NSLocalizedString("No matches for \"%@\"", comment: "Empty search result"), searchQuery)
        }
        if showFavoritesOnly {
            return NSLocalizedString("No favorites yet", comment: "Empty: no favorites")
        }
        return NSLocalizedString("Save your IBAN once. Paste forever.", comment: "Empty: zero memos")
    }

    private var emptyStateSubtitle: String {
        if !searchQuery.isEmpty {
            return NSLocalizedString("Try a shorter keyword or clear the filter.", comment: "Empty hint: search")
        }
        if showFavoritesOnly {
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
                langToggleKey
                spaceKey
                backspaceKey
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 4)
        .background(theme.surfaceAlt)
    }

    private func searchKey(letter: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            searchQuery.append(letter)
        } label: {
            Text(letter)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(theme.text)
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(theme.surface)
                .cornerRadius(6)
        }
    }

    private var spaceKey: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            searchQuery.append(" ")
        } label: {
            HStack {
                Spacer()
                Image(systemName: "space")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textMuted)
                Spacer()
            }
            .frame(height: 28)
            .background(theme.surface)
            .cornerRadius(6)
        }
    }

    private var backspaceKey: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if !searchQuery.isEmpty { searchQuery.removeLast() }
        } label: {
            Image(systemName: "delete.left.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.text)
                .frame(width: 56, height: 28)
                .background(theme.divider)
                .cornerRadius(6)
        }
    }

    private var langToggleKey: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            searchKeyboardLang = (searchKeyboardLang == .english) ? .korean : .english
        } label: {
            Text(searchKeyboardLang == .english ? "한" : "EN")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.text)
                .frame(width: 40, height: 28)
                .background(theme.divider)
                .cornerRadius(6)
        }
    }

    private var currentRows: [[String]] {
        switch searchKeyboardLang {
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

    // MARK: - Recent Section

    /// 최근 1주 사용한 메모 5개 — 헤더 없이 가로 스크롤 미니 카드만 (공간 절약)
    private var recentSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .semibold))
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
                    .font(.system(size: 10))
                    .foregroundColor(categoryColorFor(memo))
                Text(memo.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.text)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(categoryColorFor(memo).opacity(0.3), lineWidth: 1)
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
    private func memoButton(for memo: Memo) -> some View {
        let catColor = categoryColorFor(memo)
        let isNormalContent = memo.contentType != .image && memo.contentType != .mixed
        if memo.attachedTemplateId != nil && isNormalContent && !memo.isCombo {
            attachedTemplateMemoButton(for: memo, catColor: catColor)
        } else {
            Button {
                memoButtonAction(for: memo)
            } label: {
                memoButtonLabel(for: memo, catColor: catColor)
            }
            .contextMenu {
                Button {
                    UIPasteboard.general.string = memo.value
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
    @ViewBuilder
    private func attachedTemplateMemoButton(for memo: Memo, catColor: Color) -> some View {
        HStack(spacing: 0) {
            // 왼쪽: 메모 값만 입력
            Button {
                memoButtonAction(for: memo, bypassTemplate: true)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: categoryIconFor(memo))
                        .font(.system(size: 12))
                        .foregroundColor(catColor)
                    Text(memo.title)
                        .foregroundColor(theme.text)
                        .lineLimit(1)
                        .font(.system(size: buttonFontSize, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if memo.isSecure {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(memo.title)
            .accessibilityHint(NSLocalizedString("탭하면 메모 내용만 붙여넣기합니다", comment: "Split button: memo only hint"))
            .contextMenu {
                Button {
                    UIPasteboard.general.string = memo.value
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label(NSLocalizedString("Copy to clipboard", comment: "Context menu: copy"), systemImage: "doc.on.doc")
                }
            } preview: {
                memoLongPressPreview(memo: memo)
            }

            // 구분선
            catColor.opacity(0.3)
                .frame(width: 1)
                .padding(.vertical, 8)
                .accessibilityHidden(true)

            // 오른쪽: 템플릿 포함 입력
            Button {
                memoButtonAction(for: memo, bypassTemplate: false)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                    Text(NSLocalizedString("Plus Template", comment: "Tag: attached template button"))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.purple)
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(width: 44)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(String(format: NSLocalizedString("%@ +템플릿", comment: "Split button: with template label"), memo.title))
            .accessibilityHint(NSLocalizedString("탭하면 연결된 템플릿 변수를 채워 붙여넣기합니다", comment: "Split button: template hint"))
        }
        .frame(height: buttonHeight)
        .background(keyColor)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
        .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMd)
                .strokeBorder(catColor.opacity(0.4), lineWidth: 1.5)
        )
    }

    /// 키보드에서 메모 길게 누르면 떠오르는 미리보기 — Mail 스타일
    private func memoLongPressPreview(memo: Memo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: categoryIconFor(memo))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(categoryColorFor(memo))
                Text(memo.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.text)
                Spacer(minLength: 0)
                if memo.isCombo {
                    Text(NSLocalizedString("Combo", comment: "Tag: combo"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                }
                if memo.isTemplate || !memo.templateVariables.isEmpty {
                    Text(NSLocalizedString("Template", comment: "Tag: template"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .clipShape(Capsule())
                }
                if memo.isSecure {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }

            // 콤보면 단계별 라인 모두 보여주기, 아니면 본문 통째로
            if memo.isCombo && !memo.comboValues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(memo.comboValues.enumerated()), id: \.offset) { index, value in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(theme.textFaint)
                            Text(value)
                                .font(.system(size: 13))
                                .foregroundColor(theme.text)
                        }
                    }
                }
            } else {
                Text(memo.value)
                    .font(.system(size: 14))
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
        UIImpactFeedbackGenerator().impactOccurred()

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
        var userInfo: [String: Any] = ["memoId": memo.id]
        if bypassTemplate { userInfo["bypassAttachedTemplate"] = true }
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: "addTextEntry"),
            object: memo.value,
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

    @ViewBuilder
    private func memoButtonLabel(for memo: Memo, catColor: Color) -> some View {
        if memo.contentType == .image || memo.contentType == .mixed {
            let fileName = memo.imageFileNames.first ?? memo.imageFileName ?? ""
            ImageMemoButton(title: memo.title, fileName: fileName, buttonHeight: buttonHeight, buttonFontSize: buttonFontSize)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: theme.radiusMd)
                    .foregroundColor(keyColor)
                    .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMd)
                            .strokeBorder(catColor.opacity(0.4), lineWidth: 1.5)
                    )

                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: categoryIconFor(memo))
                            .font(.system(size: 12))
                            .foregroundColor(catColor)
                        Text(memo.title)
                            .foregroundColor(theme.text)
                            .lineLimit(1)
                            .font(.system(size: buttonFontSize, weight: .semibold))
                        if memo.isCombo && !memo.comboValues.isEmpty {
                            Image(systemName: "repeat")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                        }
                        if memo.isTemplate || !memo.templateVariables.isEmpty {
                            Text(NSLocalizedString("Template", comment: "Tag: template"))
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.purple)
                        }
                        if memo.isSecure {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                        }
                    }
                    if memo.isCombo && !memo.comboValues.isEmpty {
                        let nextIndex = memo.currentComboIndex < memo.comboValues.count ? memo.currentComboIndex : 0
                        Text("\(NSLocalizedString("다음", comment: "Next")): \(memo.comboValues[nextIndex])")
                            .font(.system(size: 10))
                            .foregroundColor(.orange.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
            }
            .frame(height: buttonHeight)
        }
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
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                    Text(NSLocalizedString("보안 PIN 입력", comment: "PIN entry overlay title"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.top, 14)

                if pinEntryWrong {
                    Text(NSLocalizedString("PIN이 올바르지 않습니다", comment: "PIN wrong error"))
                        .font(.system(size: 11))
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
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.25), radius: 10)
            )
            .padding(.horizontal, 40)
        }
    }

    private func pinOverlayDigitKey(_ digit: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            guard enteredPIN.count < 4 else { return }
            enteredPIN.append(digit)
            pinEntryWrong = false
            if enteredPIN.count == 4 { verifyPIN() }
        } label: {
            Text(digit)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color(UIColor.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var pinOverlayCancelKey: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showPINEntry = false
            pendingSecureMemo = nil
            enteredPIN = ""
            pinEntryWrong = false
        } label: {
            Text(NSLocalizedString("취소", comment: "Cancel"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color(UIColor.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var pinOverlayBackspaceKey: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if !enteredPIN.isEmpty { enteredPIN.removeLast() }
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color(UIColor.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Color Helpers

    private func categoryColorFor(_ memo: Memo) -> Color {
        if let type = ClipboardItemType.allCases.first(where: { $0.rawValue == memo.category }) {
            return colorFor(type.color)
        }
        return .gray
    }

    private func categoryIconFor(_ memo: Memo) -> String {
        if let type = ClipboardItemType.allCases.first(where: { $0.rawValue == memo.category }) {
            return type.icon
        }
        return "doc.text"
    }

    private func colorFor(_ name: String) -> Color {
        let colorMap: [String: Color] = [
            "blue": .blue, "green": .green, "purple": .purple,
            "orange": .orange, "red": .red, "indigo": .indigo,
            "brown": .brown, "cyan": .cyan, "teal": .teal,
            "pink": .pink, "mint": .mint, "yellow": .yellow
        ]
        return colorMap[name] ?? .gray
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

    @State private var image: UIImage? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 10)
                .foregroundColor(Color(uiColor: .systemGray5))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: buttonHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // 하단 그라디언트 + 제목
            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 4) {
                Image(systemName: "photo")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.85))
                Text(title)
                    .font(.system(size: buttonFontSize, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .frame(height: buttonHeight)
        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
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
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Text(zeros)
                                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                        .lineLimit(1)
                                        .fixedSize()
                                        .frame(height: 36)
                                        .padding(.horizontal, 10)
                                        .background(inactive ? Color.blue.opacity(0.05) : Color.blue.opacity(0.12))
                                        .foregroundColor(inactive ? Color.blue.opacity(0.35) : Color.blue)
                                        .cornerRadius(8)
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
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(state.allPlaceholdersFilled ? Color.blue : Color.gray.opacity(0.4))
                            .cornerRadius(10)
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
                            .font(.system(size: 22))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))

                Divider()

                // MARK: 컬러 프리뷰
                coloredPreviewText
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                // MARK: 플레이스홀더 입력 (스크롤)
                ScrollView {
                    VStack(spacing: 16) {
                        if state.placeholders.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 40))
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
                ? acc + Text(seg.text).foregroundColor(Color(UIColor.systemGreen)).bold()
                : acc + Text(seg.text)
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
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(value)
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(selectedValue == value ? Color.blue.opacity(0.2) : Color(UIColor.systemGray5))
                                    .foregroundColor(selectedValue == value ? .blue : .primary)
                                    .cornerRadius(12)
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(digit)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(UIColor.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var numericScrollBackspace: some View {
        Button {
            if !selectedValue.isEmpty { selectedValue.removeLast() }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 18))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(UIColor.systemGray4))
                .foregroundColor(.primary)
                .cornerRadius(8)
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
            .cornerRadius(8)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(predefinedValues, id: \.self) { value in
                        Button {
                            selectedValue = value
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text(value)
                                .font(.system(size: 14, weight: selectedValue == value ? .semibold : .regular))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedValue == value ? Color.blue : Color(UIColor.systemGray5))
                                .foregroundColor(selectedValue == value ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                }
            }
        }
    }
}
