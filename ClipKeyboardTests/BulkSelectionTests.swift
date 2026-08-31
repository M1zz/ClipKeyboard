//
//  BulkSelectionTests.swift
//  ClipKeyboardTests
//
//  여러 개 골라서 한꺼번에 옮기고 지우는 것.
//
//  왜 생겼나: 사용자 피드백.
//
//    Would you consider adding bulk edit (especially bulk delete)?
//    ... a capacity to select multiple snippets (really cool would be to be able to
//    switch to select mode by means of 2 finger tap or something like that),
//    so that we can send multiple to a folder/category or delete them.
//
//  여기서 지키는 약속.
//   ① 고르는 범위는 **지금 탭**이다 (순서 바꾸기와 같은 범위를 쓴다)
//   ② 꾹 눌러 들어오면 그 카드가 미리 골라져 있다
//   ③ 전체 선택은 범위 안의 것만 고른다 (다른 탭의 카드를 몰래 집어 오지 않는다)
//   ④ 한꺼번에 지우면 고른 것만 사라진다
//   ⑤ 한꺼번에 옮기면 고른 것만 옮겨 가고, 이미 그 카테고리에 있던 것은 세지 않는다
//   ⑥ 화면을 닫으면 고른 것이 남지 않는다 (다음에 열었을 때 지난 선택이 살아 있으면 위험하다)
//

import XCTest
@testable import ClipKeyboard

@MainActor
final class BulkSelectionTests: XCTestCase {

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
        CategoryStore.shared.reload()
        try? MemoStore.shared.save(memos: [], type: .memo, recordHistory: false)
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func memo(_ title: String, category: String = "기본") -> Memo {
        Memo(title: title, value: "\(title) 값", category: category)
    }

    /// ⚠️ `CategoryStore` 는 싱글톤이라 목록을 **메모리에** 들고 있다. defaults 만 갈아끼우면
    ///    저장소는 예전 목록을 보고 있어서 방금 심은 카테고리를 모른다.
    private func seed(categories: [String], memos: [Memo]) {
        groupDefaults?.set(categories, forKey: DefaultsKey.userDefinedCategoriesV1)
        groupDefaults?.set([String](), forKey: DefaultsKey.hiddenCategoryTabsV1)
        CategoryStore.shared.reload()
        try? MemoStore.shared.save(memos: memos, type: .memo, recordHistory: false)
        viewModel.loadCustomCategories()
        viewModel.loadMemos()
    }

    private func titles(_ memos: [Memo]) -> Set<String> {
        Set(memos.map(\.title))
    }

    // MARK: - ① 고르는 범위는 지금 탭이다

    func test_고르기범위는_지금_카테고리_탭이다() {
        let travel = memo("여권번호", category: "여행")
        let work = memo("사번", category: "업무")
        seed(categories: ["여행", "업무"], memos: [travel, work])

        viewModel.selectedCategoryTab = .custom("여행")
        viewModel.enterSelectionMode()

        XCTAssertEqual(titles(viewModel.selectionList), ["여권번호"],
                       "'여행' 탭에서 열었으면 그 탭의 카드만 고를 수 있어야 한다")
    }

    func test_고르기범위는_순서바꾸기와_같다() {
        let travel = memo("여권번호", category: "여행")
        let work = memo("사번", category: "업무")
        seed(categories: ["여행", "업무"], memos: [travel, work])
        viewModel.selectedCategoryTab = .custom("업무")

        viewModel.enterSelectionMode()
        let selectionScope = titles(viewModel.selectionList)
        viewModel.exitSelectionMode()

        viewModel.enterReorderMode()
        let reorderScope = titles(viewModel.reorderList)

        XCTAssertEqual(selectionScope, reorderScope,
                       "두 모드가 다른 기준으로 모으면 한쪽에만 보이는 카드가 생긴다")
    }

    // MARK: - ② 꾹 눌러 들어온 카드는 미리 골라져 있다

    func test_꾹_눌러_들어오면_그_카드가_미리_골라진다() {
        let first = memo("계좌번호")
        let second = memo("주소")
        seed(categories: [], memos: [first, second])

        viewModel.enterSelectionMode(preselect: first.id)

        XCTAssertEqual(viewModel.selectedMemoIDs, [first.id])
        XCTAssertEqual(viewModel.selectedCount, 1)
    }

    /// 범위 밖의 id 로 들어오면 아무것도 고르지 않는다 - 보이지도 않는 카드가 골라진 채로
    /// 열리면 "3개 선택됨"이라 써 놓고 화면에는 두 개만 보인다.
    func test_범위_밖의_카드는_미리_골라지지_않는다() {
        let travel = memo("여권번호", category: "여행")
        let work = memo("사번", category: "업무")
        seed(categories: ["여행", "업무"], memos: [travel, work])
        viewModel.selectedCategoryTab = .custom("여행")

        viewModel.enterSelectionMode(preselect: work.id)

        XCTAssertTrue(viewModel.selectedMemoIDs.isEmpty)
    }

    // MARK: - ③ 전체 선택은 범위 안의 것만

    func test_전체선택은_범위_안의_것만_고른다() {
        let travel = memo("여권번호", category: "여행")
        let work = memo("사번", category: "업무")
        seed(categories: ["여행", "업무"], memos: [travel, work])
        viewModel.selectedCategoryTab = .custom("여행")
        viewModel.enterSelectionMode()

        viewModel.selectAllInScope()

        XCTAssertEqual(viewModel.selectedMemoIDs, [travel.id])
        XCTAssertTrue(viewModel.isAllSelectedInScope)
    }

    /// 빈 범위는 "모두 고름"이 아니다. 그렇지 않으면 빈 화면에서 전체 해제 버튼이 서 있다.
    func test_빈_범위는_모두_고른_것이_아니다() {
        seed(categories: ["여행"], memos: [])
        viewModel.selectedCategoryTab = .custom("여행")
        viewModel.enterSelectionMode()

        XCTAssertTrue(viewModel.selectionList.isEmpty)
        XCTAssertFalse(viewModel.isAllSelectedInScope)
    }

    func test_고른것을_다시_누르면_풀린다() {
        let one = memo("계좌번호")
        seed(categories: [], memos: [one])
        viewModel.enterSelectionMode()

        viewModel.toggleSelection(one.id)
        XCTAssertEqual(viewModel.selectedCount, 1)
        viewModel.toggleSelection(one.id)
        XCTAssertEqual(viewModel.selectedCount, 0)
    }

    // MARK: - ④ 한꺼번에 지우기

    func test_고른_것만_지워진다() {
        let a = memo("계좌번호")
        let b = memo("주소")
        let c = memo("전화번호")
        seed(categories: [], memos: [a, b, c])
        viewModel.enterSelectionMode()
        viewModel.toggleSelection(a.id)
        viewModel.toggleSelection(c.id)

        let removed = viewModel.deleteSelectedMemos()

        XCTAssertEqual(removed, 2)
        XCTAssertEqual(titles(viewModel.loadedData), ["주소"])
        XCTAssertEqual(titles((try? MemoStore.shared.load(type: .memo)) ?? []), ["주소"],
                       "디스크에도 반영돼야 한다 - 화면에서만 사라지면 다시 열 때 되살아난다")
    }

    func test_지운_뒤에는_고른_표시가_남지_않는다() {
        let a = memo("계좌번호")
        let b = memo("주소")
        seed(categories: [], memos: [a, b])
        viewModel.enterSelectionMode()
        viewModel.selectAllInScope()

        viewModel.deleteSelectedMemos()

        XCTAssertTrue(viewModel.selectedMemoIDs.isEmpty)
        XCTAssertTrue(viewModel.selectionList.isEmpty,
                      "찍어 둔 판에서도 빠져야 한다 - 안 그러면 지운 카드가 격자에 남는다")
    }

    func test_아무것도_안_골랐으면_아무것도_지우지_않는다() {
        let a = memo("계좌번호")
        seed(categories: [], memos: [a])
        viewModel.enterSelectionMode()

        XCTAssertEqual(viewModel.deleteSelectedMemos(), 0)
        XCTAssertEqual(viewModel.loadedData.count, 1)
    }

    // MARK: - ⑤ 한꺼번에 옮기기

    func test_고른_것만_다른_카테고리로_옮겨진다() {
        let a = memo("계좌번호")
        let b = memo("주소")
        seed(categories: ["금융"], memos: [a, b])
        viewModel.enterSelectionMode()
        viewModel.toggleSelection(a.id)

        let moved = viewModel.moveSelectedMemos(toCategory: "금융")

        XCTAssertEqual(moved, 1)
        XCTAssertEqual(viewModel.loadedData.first { $0.id == a.id }?.category, "금융")
        XCTAssertEqual(viewModel.loadedData.first { $0.id == b.id }?.category, "기본",
                       "안 고른 카드는 그대로 있어야 한다")
    }

    /// "3개를 옮겼어요"라고 해 놓고 실제로는 하나도 안 움직였으면 그 말이 거짓이 된다.
    func test_이미_그_카테고리에_있던_것은_세지_않는다() {
        let already = memo("계좌번호", category: "금융")
        let other = memo("주소")
        seed(categories: ["금융"], memos: [already, other])
        viewModel.selectedCategoryTab = .all
        viewModel.enterSelectionMode()
        viewModel.selectAllInScope()

        XCTAssertEqual(viewModel.moveSelectedMemos(toCategory: "금융"), 1,
                       "실제로 움직인 것은 '주소' 하나뿐이다")
    }

    func test_옮긴_뒤에도_찍어둔_판이_같이_갱신된다() {
        let a = memo("계좌번호")
        seed(categories: ["금융"], memos: [a])
        viewModel.selectedCategoryTab = .all
        viewModel.enterSelectionMode()
        viewModel.selectAllInScope()

        viewModel.moveSelectedMemos(toCategory: "금융")

        XCTAssertEqual(viewModel.selectionList.first { $0.id == a.id }?.category, "금융",
                       "이 화면에 남아 이어서 고를 수 있어야 한다")
    }

    // MARK: - ⑥ 닫으면 선택이 남지 않는다

    func test_닫으면_고른_것이_남지_않는다() {
        let a = memo("계좌번호")
        seed(categories: [], memos: [a])
        viewModel.enterSelectionMode()
        viewModel.selectAllInScope()

        viewModel.exitSelectionMode()

        XCTAssertFalse(viewModel.isSelectionMode)
        XCTAssertTrue(viewModel.selectedMemoIDs.isEmpty)
        XCTAssertTrue(viewModel.selectionList.isEmpty)
    }

    func test_다시_열면_지난_선택이_따라오지_않는다() {
        let a = memo("계좌번호")
        let b = memo("주소")
        seed(categories: [], memos: [a, b])
        viewModel.enterSelectionMode()
        viewModel.selectAllInScope()
        viewModel.exitSelectionMode()

        viewModel.enterSelectionMode()

        XCTAssertTrue(viewModel.selectedMemoIDs.isEmpty,
                      "지난 선택이 살아 있으면 삭제 버튼 한 번에 엉뚱한 것이 지워진다")
    }
}
