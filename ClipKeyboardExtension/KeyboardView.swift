//
//  KeyboardView.swift
//  TokenKeyboard
//
//  Created by hyunho lee on 2023/10/03.
//

import SwiftUI
import UIKit
import CryptoKit
import LeeoKit

var showOnlyTemplates: Bool = false
var showOnlyFavorites: Bool = false
var selectedTheme: String?  // 선택된 테마 필터

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
        if let data = AppGroup.defaults?.data(forKey: key) {
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

        if let saved = AppGroup.defaults?.stringArray(forKey: oldKey) {
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
        guard let userDefaults = AppGroup.defaults,
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
    @Published var currentFocusedPlaceholder: String?
    @Published var allPlaceholdersFilled: Bool = false
    @Published var templateId: UUID?  // 현재 편집 중인 템플릿 ID
    /// v4.0.8: attachedTemplate 흐름에서 본 메모(계좌번호 등)의 ID. nil이면 일반 템플릿 흐름.
    @Published var baseMemoId: UUID?
    /// v4.0.8: 본 메모 본문 - preview 표시용으로 매번 MemoStore 조회 안 하도록 캐싱.
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

    @AppStorage("keyboardColumnCount", store: AppGroup.defaults) private var keyboardColumnCount: Int = 2
    @AppStorage("keyboardButtonHeight", store: AppGroup.defaults) private var buttonHeight: Double = 44.0
    @AppStorage("keyboardButtonFontSize", store: AppGroup.defaults) private var buttonFontSize: Double = 17.0

    // 색상 커스터마이즈 - 기본은 false (Paper 테마 사용), true면 hex 오버라이드
    @AppStorage("keyboardUseCustomColors", store: AppGroup.defaults) private var useCustomColors: Bool = false
    @AppStorage("keyboardCustomBgHex", store: AppGroup.defaults) private var customBgHex: String = ""
    @AppStorage("keyboardCustomKeyHex", store: AppGroup.defaults) private var customKeyHex: String = ""
    /// 키캡 물성 프리셋 - 색이 아니라 두께·빛·모서리·눌림만 정한다.
    @AppStorage(DefaultsKey.keyboardSkin, store: AppGroup.defaults)
    private var keyboardSkinRaw: String = KeyboardSkin.classic.rawValue
    /// 콤보 키캡의 눌림 표현에 쓴다(개별 키는 KeycapButtonStyle이 각자 읽는다).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 옵션 토글 - 기본 OFF로 화면 공간 확보
    @AppStorage("keyboardShowSearch", store: AppGroup.defaults) private var showSearchBar: Bool = false
    @AppStorage("keyboardShowRecent", store: AppGroup.defaults) private var showRecentSection: Bool = false
    // 한국어 입력 사용 여부(기본 OFF). 꺼져 있으면 한/EN 토글과 한글 자판이 아예 노출되지 않아
    // 영어 전용 사용자는 한글을 볼 일이 없다. 한국어 사용자가 설정에서 직접 켠다.
    @AppStorage("keyboardKoreanEnabled", store: AppGroup.defaults) private var koreanInputEnabled: Bool = false
    @AppStorage("keyboardTypingLang", store: AppGroup.defaults) private var defaultTypingLang: String = "english"
    /// 메모 구분 표시 마스터 토글(메인 앱과 공유). 기본 OFF = 키도 심플(타입 테두리·카테고리 틴트 숨김).
    @AppStorage("showVisualCues", store: AppGroup.defaults) private var showVisualCues: Bool = false
    /// 메모 내용 힌트(메인 앱과 공유, 기본 ON) - 키보드에서는 셀이 2초 머물면
    /// 제목이 잠시 내용으로 바뀌었다가 돌아온다(공간이 좁아 제목 자리를 빌리는 방식).
    /// ⚠️ 기본값은 앱과 **같아야** 한다(꺼짐). 같은 App Group 키인데 기본값이 다르면
    ///    토글을 만진 적 없는 사람에게 앱에서는 안 보이고 키보드에서만 보인다.
    @AppStorage(DefaultsKey.contentHintEnabled, store: AppGroup.defaults) private var contentHintEnabled: Bool = false

    /// 메모 구분 장치 노출 여부 - 오직 설정 "메모 구분 표시" 토글만 따른다
    /// (iOS "색상 없이 구별"과 무관, 앱과 동일 정책).
    private var visualCuesVisible: Bool { showVisualCues }

    /// KeyboardViewController가 init으로 주입 (let - SwiftUI 재렌더에도 유지)
    let typingProxy: TypingInputProxy?

    /// 호스트 텍스트 필드 상태 - clearAll(X) 버튼은 hasText일 때만 노출.
    /// nil이면 (preview 등) 항상 표시.
    @ObservedObject var documentState: KeyboardDocumentState

    /// 누가 이 키보드를 띄우고 있는가 - 앱 안이면 키마다 복사 버튼이 하나 더 붙는다.
    let hostKind: KeyboardHostKind

    /// 지금 **눌러 보라고 가리키는** 키. 튜토리얼에서 방금 만든 문구다.
    /// nil이면 아무것도 가리키지 않는다(평소).
    let highlightedMemoId: UUID?

    init(typingProxy: TypingInputProxy? = nil,
         documentState: KeyboardDocumentState = KeyboardDocumentState(),
         hostKind: KeyboardHostKind = .keyboardExtension,
         highlightedMemoId: UUID? = nil) {
        self.typingProxy = typingProxy
        self.documentState = documentState
        self.hostKind = hostKind
        self.highlightedMemoId = highlightedMemoId
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
    /// 전체 접근이 꺼진 상태에서 클립보드 동작을 시도했을 때의 안내.
    @State private var showFullAccessToast = false
    /// 앱 안에서 길게 눌러 복사했다는 확인. (익스텐션에서는 뜰 일이 없다)
    @State private var showCopiedToast = false
    /// 길게 눌러 복사한 직후의 키 - 이어서 들어오는 탭을 한 번 무시한다.
    /// (길게 눌렀는데 글까지 입력되면 "복사만 하려 했는데"가 된다)
    @State private var suppressTapAfterLongPress: UUID?

    // 검색 상태
    @State private var searchQuery: String = ""
    @State private var isSearching: Bool = false
    @State private var searchKeyboardLang: SearchLang = .english
    /// 검색창 한글 조합기 - 자모 버튼 입력을 음절로 결합해 searchQuery에 반영(그대로 append 시 "ㅇㅣㄴㅅㅏ" 깨짐 방지).
    @State private var hangul = HangulSearchController()

    // v4.1.0: 카테고리 swipe 현재 페이지 인덱스 (즐겨찾기 별 토글은 제거됨)
    @State private var currentCategoryPage: Int = 0

    // 보안 메모 PIN 인증
    @State private var showPINEntry = false
    @State private var pendingSecureMemo: Memo?
    @State private var enteredPIN = ""
    @State private var pinEntryWrong = false

    @StateObject private var templateInputState = TemplateInputState()
    @State private var pendingBypassTemplate: Bool = false

    @Environment(\.colorScheme) var colorScheme

    enum SearchLang { case english, korean }

    /// iOS 앱과 동일한 Paper 테마 - light/dark는 시스템 모드 따름
    private var theme: AppTheme {
        AppTheme.resolve(kind: .paper, isDark: colorScheme == .dark)
    }

    // MARK: - Computed Properties

    /// v4.1.0: 카테고리 기능 활성 시 선택된 카테고리 + 검색 적용, 비활성 시 검색만.
    /// 별 토글은 v4.1.0에서 제거됨 - 즐겨찾기는 카테고리 swipe(★favorites 페이지)로 접근.
    private var filteredMemos: [Memo] {
        var result = allMemos

        if isCategoryFeatureEnabled, let category = selectedCategoryFilter {
            switch category {
            case "★basic":
                // 기본 = **갈 수 있는** 어떤 카테고리 페이지에도 속하지 않은 비즐겨찾기 메모.
                // ⚠️ 판정은 앱과 **같은 함수**(`CategoryBucketRule`)로 한다. 두 벌로 적어 두었던
                //    동안 양쪽 다 숨긴 카테고리를 빠뜨려, 그 안의 단축어가 어느 페이지에도
                //    나타나지 않았다(검색은 고른 페이지 위에서 도므로 검색으로도 못 찾는다).
                let visible = CategoryBucketRule.visibleCategories(all: sharedUserCategories,
                                                                   hidden: sharedHiddenCategoryTabs)
                let favoritesVisible = !sharedHiddenCategoryTabs.contains(CategoryBucketRule.favoritesTabKey)
                result = result.filter {
                    CategoryBucketRule.belongsToBasicBucket(category: $0.category,
                                                            isFavorite: $0.isFavorite,
                                                            visibleCustomCategories: visible,
                                                            favoritesTabVisible: favoritesVisible)
                }
            case "★favorites":
                result = result.filter { $0.isFavorite }
            case "★all":
                break   // (레거시 안전장치 - 현재 페이지 목록엔 없음) 전체 표시
            case let c where c.hasPrefix(Self.builtInPrefix):
                let raw = String(c.dropFirst(Self.builtInPrefix.count))
                result = result.filter { builtInMatches(raw, $0) }
            default:
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
        // 앱 안 무대에서는 카테고리를 항상 켠 것으로 본다 - 처음부터 탭이 보여야 하고,
        // 페이지만 보여주고 거르지 않으면 **골라도 반응이 없는** 죽은 탭이 된다.
        // (탭 노출과 필터가 같은 값을 봐야 하는 이유)
        if hostKind == .inApp { return true }
        return AppGroup.defaults?
            .bool(forKey: DefaultsKey.categoryFeatureEnabledV1) ?? false
    }

    /// iOS 앱 ClipKeyboardListViewModel과 같은 키 - 완전 동기화
    private var sharedUserCategories: [String] {
        AppGroup.defaults?
            .stringArray(forKey: DefaultsKey.userDefinedCategoriesV1) ?? []
    }

    /// iOS 앱에서 숨긴 탭 목록 - "__favorites__" 또는 카테고리 이름
    private var sharedHiddenCategoryTabs: Set<String> {
        let arr = AppGroup.defaults?
            .stringArray(forKey: DefaultsKey.hiddenCategoryTabsV1) ?? []
        return Set(arr)
    }

    /// iOS 앱에서 켠 기본 제공 카테고리 rawValue 목록(allCases 순서 유지) - 앱 BuiltInCategory와 동일.
    /// (타깃 분리로 enum을 공유하지 못해 rawValue 문자열로 인라인 처리.)
    private static let builtInOrder = ["templates", "textMemos", "images", "combos"]
    private var sharedEnabledBuiltIns: [String] {
        let enabled = Set(AppGroup.defaults?
            .stringArray(forKey: DefaultsKey.enabledBuiltInCategoriesV1) ?? [])
        return Self.builtInOrder.filter { enabled.contains($0) }
    }

    /// 기본 제공 카테고리 페이지 키 prefix(커스텀 카테고리 이름과 충돌 방지).
    private static let builtInPrefix = "★builtin:"

    /// 앱 BuiltInCategory.matches와 동일한 타입 판정.
    private func builtInMatches(_ raw: String, _ memo: Memo) -> Bool {
        switch raw {
        case "templates": return memo.isTemplate
        case "textMemos": return !memo.isCombo && memo.contentType != .image && memo.contentType != .mixed
        case "images":    return memo.contentType == .image || memo.contentType == .mixed
        case "combos":    return memo.isCombo
        default:          return false
        }
    }

    /// 앱 BuiltInCategory.displayName과 동일(다국어 키 공유).
    private func builtInDisplayName(_ raw: String) -> String {
        switch raw {
        case "templates": return NSLocalizedString("템플릿", comment: "Built-in category: templates only")
        case "textMemos": return NSLocalizedString("단축어+템플릿", comment: "Built-in category: text memos and templates")
        case "images":    return NSLocalizedString("이미지 단축어", comment: "Built-in category: image memos only")
        case "combos":    return NSLocalizedString("콤보", comment: "Built-in category: combos only")
        default:          return raw
        }
    }

    /// 앱 BuiltInCategory.icon과 동일.
    private func builtInIcon(_ raw: String) -> String {
        switch raw {
        case "templates": return "wand.and.stars"
        case "textMemos": return "doc.text.fill"
        case "images":    return "photo.fill"
        case "combos":    return "square.stack.3d.up.fill"
        default:          return "folder.fill"
        }
    }

    /// 앱 BuiltInCategory.tint와 동일.
    private func builtInTint(_ raw: String) -> Color {
        switch raw {
        case "templates": return .purple
        case "textMemos": return .indigo
        case "images":    return .green
        case "combos":    return .orange
        default:          return .blue
        }
    }

    /// v4.1.0: 키보드 페이지 인디케이터로 선택된 카테고리. "★all"=전체, "★favorites"=즐겨찾기,
    /// 그 외=실제 카테고리 이름. 기본 nil → 전체.
    private var selectedCategoryFilter: String? {
        guard !categoryPages.isEmpty else { return nil }
        let index = max(0, min(currentCategoryPage, categoryPages.count - 1))
        return categoryPages[index]
    }

    /// 카테고리 페이지 목록 - iOS 앱 ClipKeyboardListViewModel.allCategoryTabs와 완전 동일.
    /// 순서: 기본(★basic) → 즐겨찾기(숨김 아니면 항상) → 기본 제공(켠 것) → 사용자 카테고리(메모 있는 것).
    /// "전체(★all)" 탭은 앱에서 제거됐으므로 키보드에서도 노출하지 않는다.
    private var categoryPages: [String] {
        guard isCategoryFeatureEnabled else { return [] }
        let hidden = sharedHiddenCategoryTabs
        var pages: [String] = ["★basic"]
        // 즐겨찾기: 숨기지 않은 한 메모 유무와 무관하게 항상 노출 (앱과 동일).
        if !hidden.contains("__favorites__") {
            pages.append("★favorites")
        }
        // 기본 제공 카테고리 - 사용자가 켠 것만(타입 기준이라 메모 유무 무관).
        for b in sharedEnabledBuiltIns {
            pages.append(Self.builtInPrefix + b)
        }
        // 사용자 카테고리: 숨김 아니고 해당 카테고리 메모 1개 이상일 때만.
        let usedCategories = sharedUserCategories
            .filter { name in
                !hidden.contains(name) &&
                allMemos.contains { $0.category == name }
            }
        pages.append(contentsOf: usedCategories)
        return pages
    }

    /// 그리드 표시 항목 - 메모 하나당 셀 하나.
    private var displayItems: [DisplayItem] {
        filteredMemos.map { DisplayItem(memo: $0, useTemplate: false) }
    }

    /// 최근 사용 메모 5개 - lastUsedAt 기준 1주 이내, 최신순
    private var recentMemos: [Memo] {
        let weekAgo = Date().addingTimeInterval(-60 * 60 * 24 * 7)
        return allMemos
            .filter { ($0.lastUsedAt ?? .distantPast) >= weekAgo }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    /// 최근 사용 섹션 노출 조건 - 검색 비활성일 때만
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

            // 길게 눌러 값을 크게 보는 판 - 시스템 컨텍스트 메뉴는 키보드 창에 갇혀
            // 150pt 남짓으로 잘린다. 이 자리는 우리 것이라 꽉 채워 쓸 수 있다.
            if let memo = peekMemo {
                KeyboardMemoPeek(
                    memo: memo,
                    theme: theme,
                    onCopy: {
                        copyTextToClipboard(memo.comboValues.first ?? memo.value)
                        peekMemo = nil
                    },
                    onClose: { peekMemo = nil }
                )
                .transition(.opacity)
            }
        }
    }

    private func clearAllButton(proxy: TypingInputProxy) -> some View {
        Button {
            KeyboardHaptics.mediumTap()
            proxy.clearAll()
        } label: {
            Image(systemName: AppSymbol.xmarkCircle)
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

            // 상단 헤더 - 카테고리 탭 + clear 버튼
            HStack(spacing: 0) {
                // 앱 안에서는 탭이 하나뿐이어도 보여준다 - 카테고리가 **처음부터** 있어야
                // "여기서 갈라 볼 수 있다"가 읽힌다. 익스텐션은 자리가 귀해 예전대로 둘 이상일 때만.
                if hostKind == .inApp ? !categoryPages.isEmpty : categoryPages.count > 1 {
                    categoryTabRow
                } else {
                    Spacer()
                }
                // X(전체 삭제)도 앱 안에서는 **처음부터** 서 있다. 글이 생길 때 나타나면
                // 그 순간 줄이 흔들리고, 무엇보다 "지울 수 있다"를 미리 알 수 없다.
                if let proxy = typingProxy, documentState.hasText || hostKind == .inApp {
                    clearAllButton(proxy: proxy)
                        .padding(.trailing, 4)
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                        // 빈 칸에서는 눌러도 지울 게 없다 - 있지만 흐리게.
                        .opacity(documentState.hasText ? 1 : 0.4)
                        .disabled(!documentState.hasText)
                }
            }
            .animation(.easeOut(duration: 0.18), value: documentState.hasText)

            // 검색 바 - 사용자 토글 ON일 때만
            if showSearchBar {
                searchBar
            }

            // 최근 사용 섹션 - 사용자 토글 ON + 검색 비활성일 때만
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
                                    // 앱 안에서는 키 하나가 두 가지 일을 한다
                                    // **짧게 누르면 입력창에, 길게 누르면 클립보드에.**
                                    //
                                    // ⚠️ 예전에는 키마다 작은 복사 버튼을 얹었는데, 좁은 키에
                                    //    누를 곳이 둘이라 잘못 누르기 쉬웠고 제목도 가렸다.
                                    //    길게 누르기는 자리를 차지하지 않는다.
                                    //    (익스텐션에서는 같은 길게 누르기가 값을 크게 펼친다
                                    //     `MemoPeekOnLongPress` - 한 손짓에 주인은 하나여야 한다)
                                    .modifier(InAppLongPressCopy(
                                        enabled: hostKind == .inApp,
                                        onCopy: { copyMemoInApp(item.memo) },
                                        suppressed: $suppressTapAfterLongPress,
                                        memoId: item.memo.id
                                    ))
                                    // 튜토리얼이 가리키는 키 - **여기를 누르면 된다**를
                                    // 말이 아니라 빛으로 알린다. 글로 설명하면 아무도 안 읽는다.
                                    .overlay {
                                        if item.memo.id == highlightedMemoId {
                                            RoundedRectangle(cornerRadius: keycapRadius)
                                                .strokeBorder(theme.accent, lineWidth: 3)
                                                .shadow(color: theme.accent.opacity(0.7), radius: 8)
                                                .allowsHitTesting(false)
                                        }
                                    }
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
            // 인디케이터 점 제거 - 상단 categoryTabRow에서 심볼 버튼으로 이동

            // 미니 검색 키보드 - 검색 중일 때만
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
            if showCopiedToast {
                Text(NSLocalizedString("복사됨 · 다른 앱에 붙여넣기 하세요", comment: "Copied to clipboard toast (in-app keyboard)"))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if showSecureCopyBlockedToast {
                Text(NSLocalizedString("잠긴 단축어라 복사되지 않아요. 눌러서 인증하면 입력돼요.",
                                       comment: "Toast: secure memo cannot be copied by long press"))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(.horizontal, 12)
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
            if showFullAccessToast {
                // 무엇을 켜야 하는지·어디서 켜는지를 한 줄에 담는다.
                // 이 토스트가 없으면 클립보드 동작이 조용히 실패해 앱이 고장 난 것처럼 보인다.
                Text(NSLocalizedString("설정 > 키보드에서 '전체 접근 허용'을 켜주세요", comment: "Full Access required toast"))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        // {clipboard} 치환이 전체 접근 때문에 막혔을 때 KeyboardViewController가 알려 준다.
        .onReceive(NotificationCenter.default.publisher(for: .needsFullAccess)) { _ in
            showFullAccessNotice()
        }
        .onAppear {
            loadAllMemos()

            guard templateObserverToken == nil else { return }
            // 템플릿 입력 알림 구독
            templateObserverToken = NotificationCenter.default.addObserver(forName: Notification.Name.showTemplateInput, object: nil, queue: .main) { notification in
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
            NotificationCenter.default.post(name: Notification.Name.openMainAppPaywall, object: nil)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: AppSymbol.lockFill)
                    .font(.caption2)
                Text(upgradeBannerText)
                    .font(.caption2.weight(.medium))
                Spacer()
                Image(systemName: AppSymbol.chevronRight)
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
            return String(format: NSLocalizedString("%d개 단축어 더 보기 → Pro 업그레이드", comment: "Hidden memos upgrade banner"), hiddenMemoCount)
        }
        let remaining = max(0, ProFeatureManager.memoLimit - totalMemoCount)
        return String(format: NSLocalizedString("단축어 한도까지 %d개 남음 → Pro 업그레이드", comment: "Memo limit near banner"), remaining)
    }

    /// 한도 도달 임박 (남은 슬롯 2개 이하)
    private var isMemoLimitNear: Bool {
        guard isFreeUser else { return false }
        let remaining = ProFeatureManager.memoLimit - totalMemoCount
        return remaining > 0 && remaining <= 2
    }

    // MARK: - Search Bar

    /// 키보드 상단 검색 바 - 탭하면 미니 QWERTY 펼침.
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: AppSymbol.magnifyingglass)
                .font(.footnote)
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

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
                    hangul.reset()
                    searchQuery = ""
                    isSearching = false
                } label: {
                    Image(systemName: AppSymbol.xmarkCircleFill)
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
            : NSLocalizedString("단축어 검색", comment: "Search field accessibility label"))
        .accessibilityHint(isSearching
            ? NSLocalizedString("x 버튼을 탭하면 검색을 닫습니다", comment: "Search bar active hint")
            : NSLocalizedString("탭하면 단축어를 검색합니다", comment: "Search bar hint"))
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

            // 빠져나갈 액션 - 검색·필터·콤보 탭에서 항상 명시적 escape 제공
            if let escapeAction = emptyStateEscape {
                Button {
                    KeyboardHaptics.softTap()
                    escapeAction.handler()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: AppSymbol.xmarkCircleFill)
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
                hangul.reset()
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
        return NSLocalizedString("Add snippets in the main app, they'll appear here in seconds.", comment: "Empty hint: zero memos")
    }

    // MARK: - Mini Search Keyboard

    /// 검색 전용 미니 QWERTY (높이 ~120pt). TextField 사용 X - 자체 버튼이 searchQuery 문자열에 append.
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
            // 자모/영문 모두 조합기로 라우팅 - 한글은 음절로 결합, 영문은 현재 음절 확정 후 삽입.
            if let ch = letter.first { hangul.input(ch) }
            searchQuery = hangul.buffer
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
            hangul.input(" ")   // 현재 조합 중인 음절을 확정하고 공백 삽입.
            searchQuery = hangul.buffer
        } label: {
            HStack {
                Spacer()
                Image(systemName: AppSymbol.space)
                    .font(.caption2)
                    .foregroundColor(theme.textMuted)
                Spacer()
            }
            .frame(height: 28)
            .background(theme.surface)
            .cornerRadius(theme.radiusXs)
        }
        .accessibilityLabel(NSLocalizedString("스페이스", comment: "Space key"))
    }

    private var backspaceKey: some View {
        Button {
            KeyboardHaptics.tap()
            hangul.backspace()   // 조합 중이면 한 단계 되돌리고, 아니면 마지막 글자 삭제.
            searchQuery = hangul.buffer
        } label: {
            Image(systemName: AppSymbol.deleteLeftFill)
                .font(.footnote.weight(.semibold))
                .foregroundColor(theme.text)
                .frame(width: 56, height: 28)
                .background(theme.divider)
                .cornerRadius(theme.radiusXs)
        }
        .accessibilityLabel(NSLocalizedString("지우기", comment: "Backspace key"))
    }

    private var langToggleKey: some View {
        Button {
            KeyboardHaptics.softTap()
            hangul.commitComposition()   // 전환 전 진행 중이던 음절을 확정(반쪽 음절이 다른 언어와 이어지지 않게).
            searchKeyboardLang = (searchKeyboardLang == .english) ? .korean : .english
        } label: {
            Text(searchKeyboardLang == .english ? "한" : "EN")
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.text)
                .frame(width: 40, height: 28)
                .background(theme.divider)
                .cornerRadius(theme.radiusXs)
        }
        .accessibilityLabel(NSLocalizedString("입력 언어 전환", comment: "Toggle input language key"))
    }

    private var currentRows: [[String]] {
        // 한국어 미사용이면 무조건 영어 자판 (한글 노출 방지 방어)
        switch koreanInputEnabled ? searchKeyboardLang : .english {
        case .english:
            return [
                ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                ["z", "x", "c", "v", "b", "n", "m"]
            ]
        case .korean:
            return [
                ["ㅂ", "ㅈ", "ㄷ", "ㄱ", "ㅅ", "ㅛ", "ㅕ", "ㅑ", "ㅐ", "ㅔ"],
                ["ㅁ", "ㄴ", "ㅇ", "ㄹ", "ㅎ", "ㅗ", "ㅓ", "ㅏ", "ㅣ"],
                ["ㅋ", "ㅌ", "ㅊ", "ㅍ", "ㅠ", "ㅜ", "ㅡ"]
            ]
        }
    }

    // MARK: - Category Tab Row

    private var categoryTabRow: some View {
        HStack(spacing: 6) {
            // 지구본(다음 키보드) - 스크롤 밖에 고정한다.
            // 커스텀 키보드는 다른 키보드로 넘어갈 수단을 반드시 제공해야 한다(심사 요건).
            // 예전에는 UIKit 버튼이 SwiftUI 호스팅 뷰에 가려 보이지 않아 아예 숨겨져 있었다.
            if KeyboardCapability.needsInputModeSwitchKey, let proxy = typingProxy {
                Button {
                    KeyboardHaptics.tap()
                    proxy.advanceToNextInputMode()
                } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.textMuted)
                        .frame(width: 32, height: 28)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(NSLocalizedString("다음 키보드", comment: "Next keyboard button"))
                .padding(.leading, 8)
            }

            categoryTabScroller
        }
        .padding(.vertical, 5)
    }

    private var categoryTabScroller: some View {
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
        }
    }

    /// 카테고리 페이지 키에 표시할 짧은 라벨.
    private func labelForCategoryKey(_ key: String) -> String {
        if key == "★basic" { return NSLocalizedString("기본", comment: "Category tab: default/basic") }
        if key == "★all" { return NSLocalizedString("전체", comment: "Category tab: all") }
        if key == "★favorites" { return NSLocalizedString("즐겨찾기", comment: "Category tab: favorites") }
        if key.hasPrefix(Self.builtInPrefix) {
            return builtInDisplayName(String(key.dropFirst(Self.builtInPrefix.count)))
        }
        return key
    }

    // MARK: - Recent Section

    /// 최근 1주 사용한 메모 5개 - 헤더 없이 가로 스크롤 미니 카드만 (공간 절약)
    private var recentSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                Image(systemName: AppSymbol.clockArrowCirclepath)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(theme.textFaint)
                    .accessibilityHidden(true)
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
                Text(memo.title.kbTemplateAwareAttributed(font: .caption.weight(.medium),
                                                          accent: theme.accent, accentSoft: theme.accentSoft))
                    .font(.caption.weight(.medium))
                    .foregroundColor(theme.text)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.surface)
            .clipShape(Capsule())
            .overlay(
                // 카테고리색 테두리 - 구분 표시 ON일 때만 (기본은 테두리 없이).
                Capsule()
                    .stroke(((visualCuesVisible ? categoryColorFor(memo) : nil) ?? .clear).opacity(0.3), lineWidth: 1)
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
        // 카테고리 색 틴트는 카테고리 정체성이라 항상 표시(구분 표시 토글과 무관).
        let catColor = categoryColorFor(memo)
        let isImageMemo = (memo.contentType == .image || memo.contentType == .mixed)
        let imageFileName = memo.imageFileNames.first ?? memo.imageFileName ?? ""
        let bypass = false

        if isImageMemo && !imageFileName.isEmpty && !(memo.isCombo && !memo.isSecure) {
            // 이미지 메모(콤보 아님): 전체 배경으로 이미지 표시.
            // 이미지+여러 값(콤보)이면 아래 분할 버튼으로 값을 넣게 하고, 이미지는 롱프레스로 복사.
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
            .buttonStyle(KeycapButtonStyle(skin: skin, cornerRadius: keycapRadius, skirtColor: keycapSkirtColor))
            .modifier(MemoPeekOnLongPress(memo: memo, enabled: hostKind != .inApp, onPeek: showPeek))
            .accessibilityLabel(memoAccessibilityLabel(for: memo))
            .accessibilityHint(memoAccessibilityHint(for: memo))
        } else if memo.isCombo && !memo.isSecure {
            // 여러 값(콤보) - 2/3 분할: 왼쪽 현재 값 삽입, 오른쪽 → 다음 값.
            comboSplitButton(for: memo, catColor: catColor)
                .modifier(MemoPeekOnLongPress(memo: memo, enabled: hostKind != .inApp, onPeek: showPeek))
                .accessibilityLabel(memoAccessibilityLabel(for: memo))
                .accessibilityHint(NSLocalizedString("왼쪽을 누르면 현재 값을, 오른쪽 화살표로 다음 값을 넣어요", comment: "Combo split button hint"))
        } else {
            Button {
                memoButtonAction(for: memo, bypassTemplate: bypass)
            } label: {
                memoButtonLabel(for: memo, catColor: catColor, useTemplate: useTemplate)
            }
            .buttonStyle(KeycapButtonStyle(skin: skin, cornerRadius: keycapRadius, skirtColor: keycapSkirtColor))
            .modifier(MemoPeekOnLongPress(memo: memo, enabled: hostKind != .inApp, onPeek: showPeek))
            .accessibilityLabel(memoAccessibilityLabel(for: memo))
            .accessibilityHint(memoAccessibilityHint(for: memo))
        }
    }

    // MARK: - Combo Split Button (여러 값: 왼쪽 현재 값 삽입 / 오른쪽 → 다음 값)

    /// 지금 크게 들여다보고 있는 단축어(길게 누르기). nil 이면 판이 닫혀 있다.
    @State private var peekMemo: Memo?
    /// 보안 단축어를 길게 눌러 복사하려 했을 때의 안내.
    @State private var showSecureCopyBlockedToast = false

    /// 길게 눌렀다 - 값을 크게 펼친다.
    ///
    /// ⚠️ 뒤이어 들어올 탭을 막아 둔다. 값을 보려고 눌렀는데 글까지 입력되면
    ///    지우는 일이 하나 더 생긴다(`memoButtonAction` 이 이 표식을 본다).
    private func showPeek(_ memo: Memo) {
        suppressTapAfterLongPress = memo.id
        KeyboardHaptics.mediumTap()
        withAnimation(.easeOut(duration: 0.16)) { peekMemo = memo }
    }

    /// 콤보(여러 값) 메모의 현재 선택 값 인덱스 - 메모별로 기억.
    @State private var comboValueIndex: [UUID: Int] = [:]
    /// → 누를 때마다 증가 - 값을 잠깐 보여줬다 사라지는 디졸브를 트리거한다.
    @State private var comboFlash: [UUID: Int] = [:]
    /// 지금 눌려 있는 콤보 키. 좌·우 어느 쪽을 눌러도 **키캡 하나**가 통째로 내려앉는다.
    /// (동시에 두 키를 누를 수는 없으므로 단일 값으로 충분)
    @State private var pressedComboId: UUID?

    private func comboSplitButton(for memo: Memo, catColor: Color?) -> some View {
        let values = memo.comboValues.isEmpty ? [memo.value] : memo.comboValues
        let idx = min(max(comboValueIndex[memo.id] ?? 0, 0), values.count - 1)
        let current = values[idx]
        // 좌·우 어느 쪽을 눌러도 **키캡 하나**가 통째로 내려앉는다.
        let pressedBinding = Binding<Bool>(
            get: { pressedComboId == memo.id },
            set: { pressedComboId = $0 ? memo.id : nil }
        )

        return HStack(spacing: 0) {
            // 왼쪽 2/3 - 평소엔 키(제목), → 누르면 현재 값이 디졸브로 잠깐 보였다 사라진다(iOS와 동일).
            Button {
                insertComboValue(memo: memo, value: current)
            } label: {
                ComboKeyValueLabel(
                    title: memo.title,
                    value: current,
                    fontSize: buttonFontSize,
                    titleColor: theme.text,
                    valueColor: theme.textMuted,
                    accent: theme.accent,
                    accentSoft: theme.accentSoft,
                    flashToken: comboFlash[memo.id] ?? 0
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .frame(height: buttonHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(KeycapPressReporter(pressed: pressedBinding))

            // 두 키 사이의 '틈'이 아니라 하나의 캡에 파인 '홈'으로 읽히도록 옅게.
            Rectangle()
                .fill(theme.divider.opacity(0.6))
                .frame(width: 1, height: buttonHeight * 0.42)

            // 오른쪽 1/3 - 다음 값으로 전환(값이 잠깐 보였다 사라짐).
            Button {
                advanceComboValue(memo: memo, count: values.count)
            } label: {
                VStack(spacing: 1) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: buttonFontSize * 0.9, weight: .semibold))
                    Text("\(idx + 1)/\(values.count)")
                        .font(.system(size: buttonFontSize * 0.6, weight: .medium))
                }
                .foregroundColor(theme.textMuted)
                .frame(width: max(46, buttonHeight))
                .frame(height: buttonHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(KeycapPressReporter(pressed: pressedBinding))
        }
        .background(
            RoundedRectangle(cornerRadius: keycapRadius)
                .foregroundColor(keyColor)
                .overlay(
                    Group {
                        if let catColor {
                            RoundedRectangle(cornerRadius: keycapRadius)
                                .fill(catColor.opacity(theme.isDark ? 0.22 : 0.14))
                        }
                    }
                )
                .overlay(keycapSheen)
                .shadow(color: Color.black.opacity(skin.shadowOpacity), radius: 2, y: 1)
        )
        // 점선 테두리(콤보 구분) - "메모 구분 표시" 설정이 켜졌을 때만(iOS와 동일하게 기본 심플).
        .overlay(
            RoundedRectangle(cornerRadius: keycapRadius)
                .strokeBorder(visualCuesVisible ? Color.orange : .clear,
                              style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
        )
        .clipShape(RoundedRectangle(cornerRadius: keycapRadius))
        // 통짜 키캡 - 좌·우 어디를 눌러도 한 덩어리로 내려앉는다.
        .modifier(KeycapSurface(skin: skin,
                                cornerRadius: keycapRadius,
                                skirtColor: keycapSkirtColor,
                                pressed: pressedComboId == memo.id,
                                enabled: keycapPressEnabled))
    }

    private func insertComboValue(memo: Memo, value: String) {
        if isSearching {
            withAnimation(.easeOut(duration: 0.18)) {
                hangul.reset()
                searchQuery = ""
                isSearching = false
            }
        }
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: "addTextEntry"),
            object: value,
            userInfo: ["memoId": memo.id, "skipCombo": true]
        )
    }

    private func advanceComboValue(memo: Memo, count: Int) {
        guard count > 0 else { return }
        KeyboardHaptics.softTap()
        let cur = comboValueIndex[memo.id] ?? 0
        comboValueIndex[memo.id] = (cur + 1) % count
        // 값을 잠깐 보여줬다 사라지게(디졸브) 트리거.
        comboFlash[memo.id] = (comboFlash[memo.id] ?? 0) + 1
    }

    private func memoAccessibilityLabel(for memo: Memo) -> String {
        var parts: [String] = [memo.title]
        if memo.isSecure { parts.append(NSLocalizedString("보안 단축어", comment: "VoiceOver: secure memo badge")) }
        if memo.isTemplate { parts.append(NSLocalizedString("템플릿", comment: "VoiceOver: template badge")) }
        if memo.isCombo { parts.append(NSLocalizedString("콤보", comment: "VoiceOver: combo badge")) }
        if memo.contentType == .image || memo.contentType == .mixed {
            parts.append(NSLocalizedString("이미지 단축어", comment: "VoiceOver: image memo"))
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
            return NSLocalizedString("탭하면 여러 값이 순서대로 입력됩니다", comment: "Combo memo button hint")
        } else if memo.isSecure {
            return NSLocalizedString("탭하면 PIN 인증 후 붙여넣기합니다", comment: "Secure memo button hint")
        } else {
            return NSLocalizedString("탭하면 클립보드에 복사됩니다", comment: "Clipboard item copy hint")
        }
    }

    /// attachedTemplateId가 있는 메모용 분할 버튼 - 왼쪽: 메모값만 입력, 오른쪽: 템플릿 포함 입력
    /// 키보드에서 메모 길게 누르면 떠오르는 미리보기 - Mail 스타일
    private func memoButtonAction(for memo: Memo, bypassTemplate: Bool = false) {
        // 길게 눌러 복사한 직후에 들어온 탭은 무시한다
        // 복사만 하려 했는데 글까지 입력되면 지우는 일이 하나 더 생긴다.
        if suppressTapAfterLongPress == memo.id {
            suppressTapAfterLongPress = nil
            return
        }

        // ⚠️ 여기서 햅틱을 울리지 않는다. 각 종착지가 자기 피드백을 갖고 있어서
        //    여기서도 울리면 한 번 눌렀는데 "또깍-또깍" 두 번 난다.
        //    (일반 삽입 → stamp / 이미지 → 복사 완료 / 보안 → 인증 UI)

        if isSearching {
            withAnimation(.easeOut(duration: 0.18)) {
                hangul.reset()
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
        let userInfo: [String: Any] = ["memoId": memo.id]
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: "addTextEntry"),
            object: valueToInsert,
            userInfo: userInfo
        )
    }

    private func authenticateAndInsert(memo: Memo, bypassTemplate: Bool = false) {
        let storedHash = AppGroup.defaults?.string(forKey: DefaultsKey.keyboardSecurePinHash) ?? ""
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
        let storedHash = AppGroup.defaults?.string(forKey: DefaultsKey.keyboardSecurePinHash) ?? ""
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
        guard requireFullAccess() else { return }
        let fileName = memo.imageFileNames.first ?? memo.imageFileName ?? ""
        guard !fileName.isEmpty,
              let image = MemoStore.shared.loadImage(fileName: fileName) else {
            print("⚠️ [KeyboardView] 이미지 로드 실패: \(memo.title)")
            return
        }
        UIPasteboard.general.image = image
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        print("✅ [KeyboardView] 이미지 클립보드 복사 완료: \(memo.title)")

        // 앱 무대에서는 복사에서 끝내지 않는다 - 입력창이 우리 것이라 붙여넣은 모습까지
        // 보여줄 수 있다. 익스텐션에서는 남의 텍스트 필드라 넣을 길이 없어 복사가 끝이다.
        if hostKind == .inApp {
            NotificationCenter.default.post(
                name: .addImageEntry,
                object: fileName,
                userInfo: ["memoId": memo.id]
            )
        }

        withAnimation { showImageCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showImageCopiedToast = false }
        }
    }

    /// 클립보드를 만지기 전에 반드시 통과해야 하는 관문.
    ///
    /// 전체 접근이 꺼져 있으면 `UIPasteboard` 접근을 iOS가 막는데 **에러도 예외도 없다.**
    /// 확인 없이 호출하면 사용자에게는 "눌렀는데 아무 일도 안 일어남"으로만 보인다.
    /// - Returns: 진행해도 되면 true. false면 이미 안내 토스트를 띄웠다.
    private func requireFullAccess() -> Bool {
        guard KeyboardCapability.hasFullAccess else {
            print("⚠️ [KeyboardView] 전체 접근 꺼짐 - 클립보드 동작 차단")
            showFullAccessNotice()
            return false
        }
        return true
    }

    // MARK: - 앱 안에서의 복사(길게 누르기)

    /// 길게 누르면 클립보드로 - **앱 안에서만.**
    ///
    /// 익스텐션에서는 같은 길게 누르기가 값을 크게 펼친다(`KeyboardMemoPeek`). 앱 무대에서는
    /// 목록으로 건너가면 값을 볼 수 있으므로, 여기서는 바로 복사한다.
    /// **고치는 일은 목록 화면에서** 한다. 무대는 써 보는 자리다.
    private struct InAppLongPressCopy: ViewModifier {
        let enabled: Bool
        let onCopy: () -> Void
        @Binding var suppressed: UUID?
        let memoId: UUID

        func body(content: Content) -> some View {
            if enabled {
                content
                    .onLongPressGesture(minimumDuration: 0.45) {
                        suppressed = memoId
                        onCopy()
                    }
                    // 길게 누르기를 모르는 사람도, 손이 불편한 사람도 쓸 수 있게.
                    .accessibilityAction(named: Text(NSLocalizedString("클립보드에 복사", comment: "Accessibility action: copy"))) {
                        onCopy()
                    }
            } else {
                content
            }
        }
    }

    /// 복사 버튼의 동작 - 이미지 문구는 이미지를, 그 밖에는 값을 클립보드에 넣는다.
    ///
    /// ⚠️ **보안 단축어는 여기서 나가지 않는다.** 길게 누르기는 인증을 거치지 않는 길이라,
    ///    값을 클립보드에 얹으면 잠가 둔 의미가 사라진다(화면에 안 보여줘도 붙여넣으면 나온다).
    ///    입력은 PIN 을 받고 나서만 되는데 복사만 무료 통행이던 구멍을 막는다.
    private func copyMemoInApp(_ memo: Memo) {
        guard !memo.isSecure else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            withAnimation { showSecureCopyBlockedToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation { showSecureCopyBlockedToast = false }
            }
            return
        }
        if memo.contentType == .image || memo.contentType == .mixed,
           !(memo.imageFileNames.first ?? memo.imageFileName ?? "").isEmpty {
            copyImageToClipboard(memo: memo)
            return
        }
        guard requireFullAccess() else { return }
        UIPasteboard.general.string = memo.value
        KeyboardHaptics.tap()
        withAnimation { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopiedToast = false }
        }
    }

    /// 롱프레스 메뉴의 "클립보드에 복사" - 전체 접근이 있어야 동작한다.
    private func copyTextToClipboard(_ text: String) {
        guard requireFullAccess() else { return }
        UIPasteboard.general.string = text
        KeyboardHaptics.tap()
    }

    private func showFullAccessNotice() {
        KeyboardHaptics.softTap()
        withAnimation { showFullAccessToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showFullAccessToast = false }
        }
    }

    private func memoButtonLabel(for memo: Memo, catColor: Color?, useTemplate: Bool = false) -> some View {
        let style = typeStyle(for: memo, useTemplate: useTemplate)
        return ZStack {
            // 기본 키 색(커스텀 색 설정 존중) 위에, 사용자 카테고리가 있을 때만 그 색을 옅게 틴트.
            // 제목 가독성을 위해 라이트 0.14 / 다크 0.22로 약하게만 입힌다.
            RoundedRectangle(cornerRadius: keycapRadius)
                .foregroundColor(keyColor)
                .overlay(
                    Group {
                        if let catColor {
                            RoundedRectangle(cornerRadius: keycapRadius)
                                .fill(catColor.opacity(theme.isDark ? 0.22 : 0.14))
                        }
                    }
                )
                .overlay(keycapSheen)
                .shadow(color: Color.black.opacity(skin.shadowOpacity), radius: 2, y: 1)

            // 메모 칸 안 텍스트는 제목. 보안 메모 자물쇠는 구분 표시 ON일 때만(앱과 동일, 기본 숨김).
            // 내용 힌트가 켜져 있으면 셀이 2초 머문 뒤 제목이 잠시 내용으로 바뀌었다 돌아온다.
            HStack(spacing: 4) {
                // 타입 심볼 - 앱 카드와 **같은 그림**(MemoTypeStyle). 예전에는 자물쇠만 있어서
                // 같은 템플릿 단축어가 앱에서는 지팡이, 키보드에서는 아무 표시도 없었다.
                if visualCuesVisible, MemoTypeStyle.hasDistinctType(memo, forceTemplate: useTemplate) {
                    Image(systemName: MemoTypeStyle.symbolName(for: memo, forceTemplate: useTemplate))
                        .font(.system(size: buttonFontSize * 0.82, weight: .semibold))
                        .foregroundColor(theme.textMuted)
                        .accessibilityHidden(true)
                }
                MemoTitleHintSwap(title: memo.title,
                                  hint: keyboardHintText(for: memo),
                                  seed: memo.id.hashValue,
                                  fontSize: buttonFontSize,
                                  titleColor: theme.text,
                                  hintColor: theme.textMuted,
                                  accent: theme.accent,
                                  accentSoft: theme.accentSoft)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(10)
        }
        .frame(height: buttonHeight)
        // 메모 칸 기본 테두리 - 구분 표시 ON일 때만 (기본은 배경·그림자만으로 깔끔하게).
        .overlay(
            RoundedRectangle(cornerRadius: keycapRadius)
                .strokeBorder(visualCuesVisible ? theme.divider : .clear, lineWidth: 1)
        )
        // 타입 구분 테두리(템플릿/콤보/보안) - 색맹 친화, 기본 테두리 위에 덧입힌다.
        .overlay(
            RoundedRectangle(cornerRadius: keycapRadius)
                .strokeBorder(style.color,
                              style: StrokeStyle(lineWidth: style.lineWidth, dash: style.dash))
        )
    }

    /// 키보드 셀 내용 힌트 텍스트 - 설정 OFF면 nil(스왑 없음).
    /// 사용자가 메모에 힌트를 직접 적었으면 그것이 우선이되, 메모별 동기화 토글
    /// (hintShownOnKeyboard)이 꺼져 있으면 키보드에서는 스왑하지 않는다.
    /// ⚠️ 자동 요약은 보안 메모 내용 노출 금지(값이 암호문이기도 함) → nil. 앱 카드와 동일 기준.
    private func keyboardHintText(for memo: Memo) -> String? {
        guard contentHintEnabled else { return nil }
        if let custom = memo.hint?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return memo.hintShownOnKeyboard ? custom : nil
        }
        guard !memo.isSecure else { return nil }
        let text = MemoPreviewFormatter.preview(for: memo, resolvedType: memo.autoDetectedType)
        return text.isEmpty ? nil : text
    }

    /// 메모 타입 시각 스타일 - 테두리 색·dash 패턴. 색맹 보조용 (색 + 패턴 이중 큐).
    /// iOS "색상 없이 구별"이 켜진 경우에만 노출(기본은 칸 경계 테두리만).
    /// 우선순위: useTemplate(템플릿 적용 셀) > 콤보 > 보안 > 본체 템플릿.
    /// 사용자가 고른 키캡 물성 프리셋. 색은 건드리지 않는다(테마·커스텀 색이 담당).
    private var skin: KeyboardSkin {
        KeyboardSkin.resolved(keyboardSkinRaw)
    }

    /// 키캡 모서리 - 테마 스케일을 스킨 비율로 조정한다.
    private var keycapRadius: CGFloat {
        skin.cornerRadius(base: theme.radiusMd)
    }

    /// 눌림을 그릴 수 있는 상태인가. `KeycapButtonStyle`과 같은 조건
    /// 연출 토글이 꺼졌거나, 동작 줄이기가 켜졌거나, 두께가 0인 스킨이면 내려앉지 않는다.
    private var keycapPressEnabled: Bool {
        KeyboardHaptics.delightEnabled && !reduceMotion && skin.skirtDepth > 0
    }

    /// 키캡 옆면(스커트) 색 - 키가 얹혀 있는 두께.
    /// 사용자가 키 색을 바꿔도 항상 "그 색의 그늘"이 되도록 검정을 깔아 만든다.
    private var keycapSkirtColor: Color {
        Color.black.opacity(skin.skirtOpacity(isDark: theme.isDark))
    }

    /// 키캡 표면광 - 앱 카드의 유리에 대응하는 "빛을 받는 물성".
    ///
    /// ⚠️ 여기에는 일부러 `glassEffect` 를 쓰지 않는다. 유리는 뒤가 비쳐야 의미가 있는데
    ///    키보드 배경은 불투명해서 비칠 것이 없다. 비용(익스텐션 메모리·GPU)만 내고
    ///    납작한 반투명 판이 될 뿐이다. 대신 같은 언어의 다른 재질 - 위에서 빛을 받아
    ///    윗면이 밝고 아래로 갈수록 어두워지는 **키캡**으로 간다.
    ///    (눌리는 동작은 `KeycapButtonStyle` 이 담당한다)
    private var keycapSheen: some View {
        RoundedRectangle(cornerRadius: keycapRadius)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(skin.sheenOpacity(isDark: theme.isDark)), .clear],
                    startPoint: .top, endPoint: .center
                )
            )
            .allowsHitTesting(false)
    }

    /// 앱 카드와 **같은 규칙**을 본다 (DesignSystem/MemoTypeStyle.swift).
    private func typeStyle(for memo: Memo, useTemplate: Bool) -> TypeVisualStyle {
        MemoTypeStyle.border(for: memo,
                             visualCuesVisible: visualCuesVisible,
                             forceTemplate: useTemplate)
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
        return max(0, totalMemoCount - ProFeatureManager.memoLimit)
    }

    // MARK: - PIN Entry Overlay

    private var pinEntryOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: AppSymbol.lockFill)
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
                    ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.first) { row in
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
            Image(systemName: AppSymbol.deleteLeft)
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
    /// 앱 Color.clipFavorite(#FF4A9E)와 동일 - 타깃 분리로 인라인.
    private var favoritePink: Color { Color(red: 1.0, green: 0.29, blue: 0.62) }

    private func categoryColorFor(_ memo: Memo) -> Color? {
        // 즐겨찾기는 카테고리처럼 분홍색 정체성을 갖는다 - 카테고리 색보다 우선(앱과 동일).
        if memo.isFavorite { return favoritePink }
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
    /// 사용자 커스텀 아이콘 - userCategoryIcons_v1 에서 로드
    private var customCategoryIcons: [String: String] {
        AppGroup.defaults?
            .dictionary(forKey: DefaultsKey.userCategoryIconsV1) as? [String: String] ?? [:]
    }

    /// 사용자가 지정한 카테고리 색 - userCategoryColors_v1 에서 로드(앱과 동일 키).
    private var customCategoryColors: [String: String] {
        AppGroup.defaults?
            .dictionary(forKey: DefaultsKey.userCategoryColorsV1) as? [String: String] ?? [:]
    }

    /// 커스텀 > 인덱스 팔레트 순으로 폴백 (iOS 앱과 동일)
    private func iconForCategoryKey(_ key: String) -> String {
        if key == "★basic" { return "tray.full.fill" }
        if key == "★all" { return "square.grid.2x2.fill" }
        if key == "★favorites" { return "heart.fill" }
        if key.hasPrefix(Self.builtInPrefix) {
            return builtInIcon(String(key.dropFirst(Self.builtInPrefix.count)))
        }
        if let custom = customCategoryIcons[key] { return custom }
        let icons = ["folder.fill", "bookmark.fill", "tag.fill", "briefcase.fill",
                     "star.fill", "heart.circle.fill", "person.fill", "house.fill"]
        let idx = sharedUserCategories.firstIndex(of: key) ?? 0
        return icons[idx % icons.count]
    }

    /// iOS 앱 ClipKeyboardList.customCategoryColor과 동일한 팔레트 + 인덱스 기반
    private func colorForCategoryKey(_ key: String) -> Color {
        if key == "★basic" { return .gray }   // 앱 .basic 인디케이터 색과 동일
        if key == "★all" { return .blue }
        if key == "★favorites" { return favoritePink }
        if key.hasPrefix(Self.builtInPrefix) {
            return builtInTint(String(key.dropFirst(Self.builtInPrefix.count)))
        }
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

// MARK: - Memo Title ↔ Content Hint Swap

/// 키보드 메모 셀의 제목 ↔ 내용 힌트 스왑 - 키보드는 공간이 좁아 앱 카드처럼 별도 줄을
/// 두는 대신 제목 자리를 잠시 빌린다. 셀이 화면에 나타나 2초쯤 머물면 제목이 내용으로
/// 부드럽게 바뀌었다가, 잠시 후 다시 제목으로 돌아온다. 이번 등장에서 한 번만
/// 셀이 화면 밖으로 나갔다 다시 들어오면 처음부터(앱 카드 힌트와 동일 기준).
/// 셀(seed)마다 바뀌는 시점·읽히는 시간이 조금씩 달라 키보드 전체가 동시에 변하지 않는다.
/// 콤보 분할 버튼 왼쪽 라벨 - 평소엔 키(제목), flashToken이 바뀌면(→ 누르거나 처음 나타날 때)
/// 현재 값이 디졸브(블러+페이드)로 잠깐 보였다가 다시 키로 돌아온다. iOS의 값 미리보기와 같은 경험.
/// 여러 값이면 → 를 누를 때마다 값1·값2… 가 차례로 스쳐 보인다.
struct ComboKeyValueLabel: View {
    let title: String
    let value: String
    let fontSize: Double
    let titleColor: Color
    let valueColor: Color
    /// 변수 칩 색 - 앱 카드와 같은 테마 토큰을 받는다.
    let accent: Color
    let accentSoft: Color
    /// → 를 누르거나 처음 나타날 때 증가 - 디졸브 미리보기를 트리거하는 토큰.
    let flashToken: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingValue = false

    var body: some View {
        ZStack {
            Text(title.kbTemplateAwareAttributed(font: .system(size: fontSize, weight: .semibold),
                                                 accent: accent, accentSoft: accentSoft))
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundColor(titleColor)
                .opacity(showingValue ? 0 : 1)
                .blur(radius: !reduceMotion && showingValue ? 3 : 0)
            Text(value.isEmpty ? "-" : value)
                .font(.system(size: fontSize * 0.92))
                .foregroundColor(valueColor)
                .opacity(showingValue ? 1 : 0)
                .blur(radius: !reduceMotion && !showingValue ? 3 : 0)
        }
        // 이름이 길 때 어디를 접을지는 설정을 따른다(기본: 가운데 접기).
        .keyLabelTruncation(KeyLabelTruncation.current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        // flashToken 변경(→ 또는 최초 등장) 때마다: 값을 잠깐 보여줬다 다시 키로.
        .task(id: flashToken) {
            showingValue = false
            do {
                try await Task.sleep(for: .seconds(0.2))
                withAnimation(.easeInOut(duration: 0.45)) { showingValue = true }
                try await Task.sleep(for: .seconds(1.5))
                withAnimation(.easeInOut(duration: 0.5)) { showingValue = false }
            } catch { showingValue = false }
        }
    }
}

struct MemoTitleHintSwap: View {
    let title: String
    /// nil이면(설정 OFF·보안 메모·빈 내용) 스왑 없이 제목만 표시한다.
    let hint: String?
    /// 셀별 위상 시드(메모 id 해시) - 스왑 시점·머묾 시간에 결정적 편차를 준다.
    let seed: Int
    let fontSize: Double
    let titleColor: Color
    let hintColor: Color
    /// 변수 칩 색 - 앱 카드와 같은 테마 토큰을 받는다.
    let accent: Color
    let accentSoft: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingHint = false

    /// 최소 2초는 머문 뒤에 바뀐다(바닥값, 앱 카드 힌트와 동일) - 카드별 편차가 더해진다.
    static let baseRevealDelay: Double = 2.0
    /// 제목 ↔ 내용 전환 시간 - 키보드는 시선 바로 아래라 확 바뀌면 어지럽다. 천천히 녹아들게.
    static let swapDuration: Double = 1.0

    /// 스왑 시점 2.0~3.6s - 셀들이 하나둘 차례로 바뀐다.
    private var revealDelay: Double { Self.baseRevealDelay + unit(0) * 1.6 }
    /// 내용이 읽히는 시간 3.2~4.6s - 전환이 느려진 만큼 읽는 시간도 살짝 여유 있게.
    private var holdDuration: Double { 3.2 + unit(1) * 1.4 }

    /// seed에서 뽑은 결정적 0..<1 (salt로 서로 독립적인 값) - 같은 셀은 항상 같은 리듬.
    private func unit(_ salt: UInt64) -> Double {
        var h = UInt64(bitPattern: Int64(seed)) &+ (salt &+ 1) &* 0x9E3779B97F4A7C15
        h ^= h >> 33
        h = h &* 0xFF51AFD7ED558CCD
        h ^= h >> 33
        return Double(h % 1024) / 1024.0
    }

    var body: some View {
        ZStack {
            Text(title.kbTemplateAwareAttributed(font: .system(size: fontSize, weight: .semibold),
                                                 accent: accent, accentSoft: accentSoft))
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundColor(titleColor)
                .opacity(showingHint ? 0 : 1)
                .blur(radius: !reduceMotion && showingHint ? 3 : 0)
            if let hint {
                Text(hint)
                    .font(.system(size: fontSize * 0.92))
                    .foregroundColor(hintColor)
                    .opacity(showingHint ? 1 : 0)
                    .blur(radius: !reduceMotion && !showingHint ? 3 : 0)
            }
        }
        .keyLabelTruncation(KeyLabelTruncation.current)
        .multilineTextAlignment(.center)
        // VoiceOver는 셀 버튼의 accessibilityLabel(제목+내용)이 안내 - 일시 표시는 숨김.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .task {
            // 셀이 화면을 벗어나면 task가 취소되고, 다시 나타나면 처음부터 시작된다.
            guard hint != nil else { return }
            showingHint = false
            do {
                try await Task.sleep(for: .seconds(revealDelay))
                withAnimation(.easeInOut(duration: Self.swapDuration)) { showingHint = true }
                try await Task.sleep(for: .seconds(Self.swapDuration + holdDuration))
                withAnimation(.easeInOut(duration: Self.swapDuration)) { showingHint = false }
            } catch { /* 화면 이탈로 취소 - 다음 등장 때 다시 */ }
        }
    }
}

// MARK: - Image Memo Button

// MARK: - Keycap Press (날인)

/// 문구 버튼이 **실제로 눌리는** 스타일.
///
/// 이 앱의 입력은 도장을 찍는 동작과 같다 - 한 번 눌러서, 흔적을 남기고, 끝.
/// 그래서 버튼이 그림자를 잃으며 아래로 내려가고, 뗄 때 제자리로 돌아온다.
///
/// ⚠️ 하루 20~50번 반복되는 연출이라 0.18초를 넘기지 않는다(메인 앱 `Delight.Tier.daily`와 동일).
///    타겟이 분리돼 상수를 공유할 수 없어 값만 맞춰 둔다.
/// ⚠️ 접근성 '동작 줄이기'와 사용자 토글을 모두 존중한다.
/// 키캡의 **두께와 눌림**을 입히는 단 하나의 규칙.
///
/// 스커트는 제자리에 두고 캡만 내려앉게 하려고 offset을 두 겹으로 건다:
/// 스커트를 먼저 배경으로 붙인 뒤 전체를 내리면, 스커트의 절대 위치는 그대로이고
/// 캡만 그 위로 덮인다. (`.background` → `.offset` 순서가 핵심이다)
struct KeycapSurface: ViewModifier {
    let skin: KeyboardSkin
    let cornerRadius: CGFloat
    /// 키캡 옆면(스커트) 색. 키 색에 상관없이 어둡게 깔아 두께를 만든다.
    let skirtColor: Color
    let pressed: Bool
    /// 눌림을 그릴 수 있는 상태인가(연출 토글·동작 줄이기·두께 0 스킨 반영).
    let enabled: Bool

    func body(content: Content) -> some View {
        let travel = skin.skirtDepth
        let down = pressed && enabled

        content
            // 스커트 - 평소엔 키 아래로 삐져나와 **두께**를 만들고,
            // 누르면 키가 그 위로 내려앉아 가려진다. 이 한 겹이 "또깍"의 정체다.
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(skirtColor)
                    .offset(y: (down || !enabled) ? 0 : travel)
            )
            .offset(y: down ? travel : 0)
            // 내려갈 땐 즉각(기계식 키는 travel이 거의 없다), 올라올 땐 살짝 튕기며.
            .animation(down
                       ? .easeOut(duration: skin.pressDuration)
                       : .spring(response: skin.releaseResponse, dampingFraction: skin.releaseDamping),
                       value: down)
    }
}

struct KeycapButtonStyle: ButtonStyle {
    /// 두께·눌림 곡선을 정하는 물성 프리셋.
    let skin: KeyboardSkin
    let cornerRadius: CGFloat
    let skirtColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        // 두께가 0인 스킨(납작)은 눌림도 없다 - 내려앉을 바닥이 없기 때문.
        let enabled = KeyboardHaptics.delightEnabled && !reduceMotion && skin.skirtDepth > 0
        return configuration.label
            .modifier(KeycapSurface(skin: skin,
                                    cornerRadius: cornerRadius,
                                    skirtColor: skirtColor,
                                    pressed: configuration.isPressed,
                                    enabled: enabled))
    }
}

/// 자기 눌림 상태를 부모에게 알려 주기만 하는 스타일.
///
/// 콤보 키는 좌·우 두 영역이 각각 눌리지만 **키캡은 하나**다. 두 버튼이 각자
/// 내려앉으면 한 덩어리가 반으로 쪼개져 보인다. 그래서 눌림 표현은 부모가 통짜로
/// 그리고, 이 스타일은 "지금 눌렸다"는 사실만 올려보낸다.
struct KeycapPressReporter: ButtonStyle {
    @Binding var pressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            // 뷰 갱신 중이 아니라 갱신 이후에 반영된다 - 상태 변경 경고를 피한다.
            .onChange(of: configuration.isPressed) { _, now in pressed = now }
    }
}

// MARK: - Template Chip Rendering (키보드 전용)

extension String {
    /// `{변수}`가 있으면 중괄호 없는 하이라이트 칩으로, 없으면 그대로 반환.
    /// 앱 타겟 String.templateChipAttributed와 동일 규칙 - 타깃 분리로 확장을 공유하지 못해
    /// 키보드 전용으로 복제(색은 시스템 블루 고정). "플레이스홀더는 어디서든 하이라이트" 규칙.
    /// - Parameters:
    ///   - accent / accentSoft: 앱의 `templateChipAttributed` 와 **같은 테마 토큰**을 받는다.
    ///     예전에는 여기서만 시스템 블루로 고정돼 있어서, 테마를 바꾸면 앱 카드의 변수 칩과
    ///     키보드 키의 변수 칩 색이 서로 달라졌다.
    func kbTemplateAwareAttributed(font: Font,
                                   accent: Color,
                                   accentSoft: Color) -> AttributedString {
        guard contains("{"), let regex = try? NSRegularExpression(pattern: "\\{([^}]+)\\}") else {
            return AttributedString(self)
        }
        let ns = self as NSString
        var out = AttributedString()
        var cursor = 0
        for match in regex.matches(in: self, range: NSRange(location: 0, length: ns.length)) {
            let full = match.range
            if full.location > cursor {
                out += AttributedString(ns.substring(with: NSRange(location: cursor, length: full.location - cursor)))
            }
            // 중괄호는 숨기고 변수명만, 양옆 얇은 공백(U+2009)으로 칩 패딩을 흉내낸다.
            var chip = AttributedString("\u{2009}\(ns.substring(with: match.range(at: 1)))\u{2009}")
            chip.foregroundColor = accent
            chip.backgroundColor = accentSoft
            chip.font = font
            out += chip
            cursor = full.location + full.length
        }
        if cursor < ns.length {
            out += AttributedString(ns.substring(from: cursor))
        }
        return out
    }
}

// MARK: - Search Hangul Composition

/// 검색창 한글 조합 컨트롤러.
/// 검색 미니 키보드는 자모 버튼을 직접 누르는 방식이라, 자모를 그대로 append하면
/// "인사"가 "ㅇㅣㄴㅅㅏ"처럼 깨진다. 메인 입력과 동일한 `HangulComposer`(2벌식 오토마타)에
/// 통과시켜 자모를 음절로 조합한 뒤 `buffer`(가시 검색 텍스트)에 반영한다.
final class HangulSearchController: HangulInputProxy {
    /// 조합 결과가 반영된 검색 문자열 - 화면에 보이는 텍스트와 항상 일치.
    private(set) var buffer: String = ""
    private let composer = HangulComposer()

    init() { composer.proxy = self }

    /// 키 한 글자 입력 - 한글 자모는 조합되고, 영문·숫자·기호·스페이스는 현재 음절을 확정 후 그대로 삽입.
    func input(_ character: Character) { composer.input(character) }

    /// 백스페이스 - 조합 중이면 한 단계 되돌리고, 아니면 마지막 글자 삭제.
    func backspace() { composer.backspace() }

    /// 진행 중인 조합만 확정(버퍼는 유지) - 입력 언어 전환 시 반쪽 음절이 이어지지 않게 한다.
    func commitComposition() { composer.commit() }

    /// 검색 초기화 - 조합 상태와 버퍼를 모두 비운다.
    func reset() {
        composer.commit()
        buffer = ""
    }

    // MARK: HangulInputProxy
    func insertText(_ text: String) { buffer.append(text) }
    func deleteBackward() { if !buffer.isEmpty { buffer.removeLast() } }
}
