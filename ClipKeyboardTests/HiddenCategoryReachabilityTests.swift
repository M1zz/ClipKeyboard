//
//  HiddenCategoryReachabilityTests.swift
//  ClipKeyboardTests
//
//  **어떤 단축어도 화면에서 사라지지 않는다** - 이 앱의 목록이 지켜야 할 가장 굵은 약속.
//
//  왜 이 파일이 따로 있는가: "전체" 탭이 없어진 뒤로 홈은 `기본` 탭이고, 그 탭은
//  "어떤 사용자 카테고리에도 속하지 않은 것"을 모은다. 그래서 **탭이 없는 카테고리**가
//  생기는 순간 그 안의 단축어는 어느 탭에도 나타나지 않는다(탭 기준으로 자르므로 검색도 못 찾는다).
//  탭이 없어지는 길은 하나가 아니다:
//   · 카테고리 관리에서 탭을 숨김
//   · `CategoryStore.addHidden` 으로 숨긴 채 만들어진 카테고리에 나중에 값이 들어감
//   · 카테고리를 지웠는데 그 이름을 쓰던 단축어가 남음(고아)
//
//  카테고리가 **비어 있는 것은 괜찮다**(막 만든 카테고리가 그렇다). 값이 있는데 못 찾는 것만 사고다.
//  그래서 이 테스트는 "빈 카테고리를 허용하는가"가 아니라 "값이 언제나 어느 탭엔가 있는가"를 본다.
//

import XCTest
@testable import ClipKeyboard

@MainActor
final class HiddenCategoryReachabilityTests: XCTestCase {

    private var viewModel: ClipKeyboardListViewModel!

    private var groupDefaults: UserDefaults? { AppGroup.defaults }

    override func setUp() {
        super.setUp()
        viewModel = ClipKeyboardListViewModel()
        try? MemoStore.shared.save(memos: [], type: .memo, recordHistory: false)
    }

    override func tearDown() {
        groupDefaults?.removeObject(forKey: DefaultsKey.userDefinedCategoriesV1)
        groupDefaults?.removeObject(forKey: DefaultsKey.hiddenCategoryTabsV1)
        try? MemoStore.shared.save(memos: [], type: .memo, recordHistory: false)
        viewModel = nil
        super.tearDown()
    }

    /// 카테고리 목록과 숨김 목록을 직접 깔고 뷰모델에 읽힌다(관리 화면을 거치지 않는 경로까지 재현).
    private func seed(categories: [String], hidden: [String], memos: [Memo]) {
        groupDefaults?.set(categories, forKey: DefaultsKey.userDefinedCategoriesV1)
        groupDefaults?.set(hidden, forKey: DefaultsKey.hiddenCategoryTabsV1)
        try? MemoStore.shared.save(memos: memos, type: .memo, recordHistory: false)
        viewModel.loadCustomCategories()
        viewModel.loadMemos()
    }

    /// 지금 화면에서 갈 수 있는 모든 탭을 훑어 이 단축어가 한 번이라도 나오는지 본다.
    private func isReachable(_ title: String) -> Bool {
        viewModel.allCategoryTabs.contains { tab in
            viewModel.memos(for: tab).contains { $0.title == title }
        }
    }

    // MARK: - 값이 있는데 못 찾는 상태가 되면 안 된다

    func testMemoInHiddenCategoryStillHasATab() {
        seed(categories: ["업무"], hidden: ["업무"],
             memos: [Memo(title: "숨긴 카테고리의 단축어", value: "값", category: "업무")])

        XCTAssertTrue(isReachable("숨긴 카테고리의 단축어"),
                      "탭을 숨긴 카테고리의 단축어가 어느 탭에도 없다. 값이 있는데 못 찾는 상태다")
    }

    /// 숨긴 채 만들어진 카테고리(`CategoryStore.addHidden`)에 나중에 값이 들어가는 경로.
    /// 페르소나 변경·샘플 시딩·공유 익스텐션이 이 길로 온다.
    func testMemoAddedIntoANeverShownCategoryIsStillReachable() {
        seed(categories: ["여행"], hidden: ["여행"], memos: [])
        try? MemoStore.shared.save(memos: [Memo(title: "나중에 들어온 단축어", value: "값", category: "여행")],
                                   type: .memo, recordHistory: false)
        viewModel.loadMemos()

        XCTAssertTrue(isReachable("나중에 들어온 단축어"))
    }

    /// 카테고리를 지웠는데 그 이름을 쓰던 단축어가 남은 경우(고아) - 원래도 기본 탭이 받아 주던 계약.
    func testOrphanMemoFallsIntoBasicTab() {
        seed(categories: [], hidden: [],
             memos: [Memo(title: "고아 단축어", value: "값", category: "사라진카테고리")])

        XCTAssertTrue(viewModel.memos(for: .basic).contains { $0.title == "고아 단축어" })
    }

    /// 보이는 카테고리의 단축어는 **그 탭에만** 있어야 한다. 기본 탭까지 나오면 같은 것이 두 번 보인다.
    func testVisibleCategoryMemoStaysInItsOwnTab() {
        seed(categories: ["업무"], hidden: [],
             memos: [Memo(title: "보이는 카테고리의 단축어", value: "값", category: "업무")])

        XCTAssertTrue(viewModel.memos(for: .custom("업무")).contains { $0.title == "보이는 카테고리의 단축어" })
        XCTAssertFalse(viewModel.memos(for: .basic).contains { $0.title == "보이는 카테고리의 단축어" },
                       "보이는 탭이 있는데 기본 탭에도 나오면 중복 노출이다")
    }

    /// 빈 카테고리는 사고가 아니다 - 막 만든 카테고리가 그 모습이고, 탭은 그대로 서 있어야 한다.
    func testEmptyCategoryKeepsItsTab() {
        seed(categories: ["막만든카테고리"], hidden: [], memos: [])

        XCTAssertTrue(viewModel.allCategoryTabs.contains(.custom("막만든카테고리")))
        XCTAssertTrue(viewModel.memos(for: .custom("막만든카테고리")).isEmpty)
    }

    // MARK: - 재정렬 화면도 같은 규칙을 따른다

    // MARK: - 규칙 그 자체 (앱·키보드가 같이 부르는 함수)

    /// 키보드(`KeyboardView`)는 SwiftUI 뷰라 직접 테스트가 닿지 않는다. 대신 **두 곳이 같이 부르는**
    /// 이 함수를 붙잡아 둔다 - 규칙이 한 곳이라 여기가 맞으면 양쪽이 같이 맞는다.
    func testBucketRuleCatchesEveryUnreachableMemo() {
        let visible = CategoryBucketRule.visibleCategories(all: ["업무", "여행"], hidden: ["여행"])
        XCTAssertEqual(visible, ["업무"])

        // 숨긴 카테고리 → 갈 페이지가 없으니 기본이 받는다.
        XCTAssertTrue(CategoryBucketRule.belongsToBasicBucket(
            category: "여행", visibleCustomCategories: visible))
        // 지워진 카테고리의 고아 → 기본이 받는다.
        XCTAssertTrue(CategoryBucketRule.belongsToBasicBucket(
            category: "사라진카테고리", visibleCustomCategories: visible))
        // 카테고리 없음 → 기본이 받는다.
        XCTAssertTrue(CategoryBucketRule.belongsToBasicBucket(
            category: "", visibleCustomCategories: visible))
        // 보이는 카테고리 → 자기 탭에만. 기본이 받으면 두 번 보인다.
        XCTAssertFalse(CategoryBucketRule.belongsToBasicBucket(
            category: "업무", visibleCustomCategories: visible))
    }

    /// 별표는 자리를 옮기지 않는다.
    ///
    /// 예전에는 즐겨찾기를 기본 칸에서 빼냈다. 그래서 기본 탭에서 별을 누르면 그 단축어가
    /// 눈앞에서 사라졌고, 카테고리를 안 쓰는 사람은 별을 누를수록 첫 화면이 비어 갔다.
    /// 정작 '업무' 안의 즐겨찾기는 업무에도 즐겨찾기에도 그대로 있었다. 같은 별표가 두 가지
    /// 뜻을 가졌던 것이다.
    func testFavoriteDoesNotMoveTheShortcutOutOfItsBucket() {
        let visible = CategoryBucketRule.visibleCategories(all: ["업무"], hidden: [])

        XCTAssertTrue(CategoryBucketRule.belongsToBasicBucket(
            category: "", visibleCustomCategories: visible),
            "카테고리 없는 즐겨찾기는 기본 칸에 그대로 있어야 한다")
        XCTAssertFalse(CategoryBucketRule.belongsToBasicBucket(
            category: "업무", visibleCustomCategories: visible),
            "'업무' 안의 즐겨찾기는 예나 지금이나 업무 탭에 있다")
    }

    // MARK: - 빈 탭은 세우지 않는다

    /// 별을 하나도 안 단 사람에게 즐겨찾기 탭은 영영 빈 페이지다.
    func testFavoritesTabStandsOnlyWhenSomethingIsStarred() {
        seed(categories: [], hidden: [], memos: [Memo(title: "그냥 단축어", value: "값")])
        XCTAssertFalse(viewModel.allCategoryTabs.contains(.favorites))

        seed(categories: [], hidden: [],
             memos: [Memo(title: "별 단축어", value: "값", isFavorite: true)])
        XCTAssertTrue(viewModel.allCategoryTabs.contains(.favorites))
    }

    /// 단축어를 전부 카테고리로 옮기면 기본 칸은 빈다. 그때 첫 자리를 지키고 서 있을 이유가 없다.
    func testBasicTabRestsWhenEverythingMovedIntoCategories() {
        seed(categories: ["업무"], hidden: [],
             memos: [Memo(title: "옮긴 단축어", value: "값", category: "업무")])

        XCTAssertFalse(viewModel.allCategoryTabs.contains(.basic))
        XCTAssertTrue(viewModel.allCategoryTabs.contains(.custom("업무")))
    }

    /// 기본은 마지막 안전망이다. 다른 탭이 하나도 없으면 비어도 선다.
    func testBasicTabAlwaysStandsWhenItIsTheOnlyOne() {
        seed(categories: [], hidden: [], memos: [])

        XCTAssertEqual(viewModel.allCategoryTabs, [.basic],
                       "탭이 0개가 되면 화면이 통째로 사라진다")
    }

    /// 접힌 탭에 서 있지 않게 한다.
    func testSelectedTabMovesWhenItsTabRests() {
        seed(categories: ["업무"], hidden: [],
             memos: [Memo(title: "옮긴 단축어", value: "값", category: "업무")])

        viewModel.selectedCategoryTab = .basic
        viewModel.normalizeSelectedCategoryTabIfNeeded()

        XCTAssertEqual(viewModel.selectedCategoryTab, .custom("업무"))
    }

    /// 즐겨찾기 탭도 숨길 수 있다. 숨긴 사람의 즐겨찾기 단축어가 갈 곳이 없으면 같은 사고다.
    func testFavoriteMemoIsReachableWhenFavoritesTabIsHidden() {
        seed(categories: [], hidden: ["__favorites__"],
             memos: [Memo(title: "숨긴 즐겨찾기", value: "값", isFavorite: true)])

        XCTAssertTrue(isReachable("숨긴 즐겨찾기"),
                      "즐겨찾기 탭을 숨겼는데 기본 탭도 안 받으면 그 단축어는 어디에도 없다")
    }

    /// 별을 달아도 제자리에 있고, 즐겨찾기 탭에서 한 번 더 보인다.
    ///
    /// ⚠️ 예전에는 기본 탭에서 빠지는 것이 규칙이었다("두 번 보이면 안 된다").
    ///    그 규칙 때문에 기본 탭에서 별을 누르면 단축어가 눈앞에서 사라졌다.
    func testFavoriteIsShownInBothItsBucketAndFavorites() {
        seed(categories: [], hidden: [],
             memos: [Memo(title: "보이는 즐겨찾기", value: "값", isFavorite: true)])

        XCTAssertTrue(viewModel.memos(for: .basic).contains { $0.title == "보이는 즐겨찾기" },
                      "별을 눌렀다고 기본 칸에서 사라지면 안 된다")
        XCTAssertTrue(viewModel.memos(for: .favorites).contains { $0.title == "보이는 즐겨찾기" })
        XCTAssertTrue(isReachable("보이는 즐겨찾기"))
    }

    func testReorderScopeAlsoCatchesHiddenCategoryMemos() {
        seed(categories: ["업무"], hidden: ["업무"],
             memos: [Memo(title: "숨긴 카테고리의 단축어", value: "값", category: "업무")])

        let scoped = viewModel.allCategoryTabs.flatMap { viewModel.reorderScopeMemos(for: $0) }
        XCTAssertTrue(scoped.contains { $0.title == "숨긴 카테고리의 단축어" },
                      "재정렬 대상에서도 빠지면 그 단축어는 손댈 방법이 없다")
    }
}
