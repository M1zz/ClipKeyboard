//
//  KeyboardReorderSyncTests.swift
//  ClipKeyboardTests
//
//  **키보드에서 바꾼 순서가 앱에서도 그 순서인가.**
//
//  들어온 이야기는 이랬다. "저장한 내용 중 더 자주 쓰는 문구가 있는데 저장 순서대로라
//  불편하다." 앱에는 이미 순서 바꾸기가 있었지만, 문구를 실제로 고르는 자리는 키보드다.
//  그래서 키보드 안에서도 자리를 옮길 수 있게 했다.
//
//  옮긴 자리는 **한 곳에만 적힌다**(App Group 의 `memoManualOrder_v1`). 그 한 곳을
//  키보드(`KeyboardMemoFeed.sorted`)와 앱(`ClipKeyboardListViewModel.sortMemos`)이
//  같이 읽는다. 여기서 붙잡는 것은 그 약속이다 - 쓰는 쪽이 한 벌인지가 아니라,
//  **읽는 두 쪽이 같은 답을 내는지.**
//
//  ⚠️ 순서 바꾸기 화면 자체(끌어서 옮기기)는 여기서 안 본다. 그건 손짓이라 눈으로 본다.
//     여기서 지키는 건 손을 뗀 다음의 일이다.
//

import XCTest
@testable import ClipKeyboard

@MainActor
final class KeyboardReorderSyncTests: XCTestCase {

    private var viewModel: ClipKeyboardListViewModel!
    private var savedClipMemos: [Memo] = []

    private var groupDefaults: UserDefaults? { AppGroup.defaults }

    override func setUp() {
        super.setUp()
        viewModel = ClipKeyboardListViewModel()
        savedClipMemos = clipMemos
        clearManualOrder()
    }

    override func tearDown() {
        clearManualOrder()
        clipMemos = savedClipMemos
        viewModel = nil
        super.tearDown()
    }

    private func clearManualOrder() {
        groupDefaults?.removeObject(forKey: DefaultsKey.memoManualOrderV1)
        groupDefaults?.removeObject(forKey: DefaultsKey.memoManualOrderActiveV1)
        groupDefaults?.removeObject(forKey: DefaultsKey.memosExternalChangeAt)
    }

    /// 순서만 볼 것이므로 수정 시각을 하루씩 벌려 둔다(수동 순서가 없을 때의 기본 정렬).
    private func memo(_ title: String, favorite: Bool = false, daysAgo: Int) -> Memo {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return Memo(title: title, value: "값", lastEdited: date, isFavorite: favorite)
    }

    private func titles(_ memos: [Memo]) -> [String] { memos.map(\.title) }

    // MARK: - 키보드가 적고, 키보드가 읽는다

    func testKeyboardReorder_KeyboardReadsBackTheOrderItWrote() {
        // Given - 최근 수정순이면 가·나·다
        let a = memo("가", daysAgo: 0)
        let b = memo("나", daysAgo: 1)
        let c = memo("다", daysAgo: 2)
        let all = [a, b, c]

        // When - 키보드에서 다를 맨 앞으로 끌어 놓았다
        KeyboardMemoFeed.commitManualOrder([c, a, b], within: all)

        // Then - 순서가 뒤섞여 들어와도 키보드는 정한 순서로 세운다
        XCTAssertEqual(titles(KeyboardMemoFeed.sorted([b, c, a])), ["다", "가", "나"])
    }

    // MARK: - 키보드가 적고, 앱이 읽는다 (피드백의 본론)

    func testKeyboardReorder_AppListSeesTheSameOrder() {
        let a = memo("가", daysAgo: 0)
        let b = memo("나", daysAgo: 1)
        let c = memo("다", daysAgo: 2)

        KeyboardMemoFeed.commitManualOrder([c, a, b], within: [a, b, c])

        // 앱 목록의 정렬은 키보드와 **같은 답**이어야 한다.
        // 여기가 갈리면 "키보드에서 바꿨는데 앱은 그대로"가 된다.
        XCTAssertEqual(titles(viewModel.sortMemos([a, b, c])), ["다", "가", "나"])
        XCTAssertEqual(titles(viewModel.sortMemos([a, b, c])),
                       titles(KeyboardMemoFeed.sorted([a, b, c])))
    }

    /// 앱은 포그라운드로 돌아올 때 이 표식을 보고 목록을 다시 읽는다.
    /// 표식을 안 찍으면 앱을 열어 둔 채 키보드에서 바꾼 순서가 앱에 안 온다.
    func testKeyboardReorder_StampsExternalChange_SoTheAppReloads() {
        let a = memo("가", daysAgo: 0)
        let b = memo("나", daysAgo: 1)
        let before = groupDefaults?.double(forKey: DefaultsKey.memosExternalChangeAt) ?? 0

        KeyboardMemoFeed.commitManualOrder([b, a], within: [a, b])

        let after = groupDefaults?.double(forKey: DefaultsKey.memosExternalChangeAt) ?? 0
        XCTAssertGreaterThan(after, before)
    }

    // MARK: - 안 보이던 것을 잃지 않는다

    /// 무료 사용자의 키보드는 앞쪽 몇 개만 보여 준다. 보이는 것만 끌어 옮겼을 때
    /// **안 보이던 뒤쪽이 사라지면 안 된다** - 사용자에겐 단축어가 없어진 것으로 보인다.
    func testKeyboardReorder_KeepsMemosBeyondWhatTheKeyboardShows() {
        let a = memo("가", daysAgo: 0)
        let b = memo("나", daysAgo: 1)
        let c = memo("다", daysAgo: 2)
        let hidden1 = memo("숨김1", daysAgo: 3)
        let hidden2 = memo("숨김2", daysAgo: 4)
        let all = [a, b, c, hidden1, hidden2]

        // 키보드에는 앞의 셋만 서 있었고, 그 셋만 자리를 바꿨다
        let merged = KeyboardMemoFeed.commitManualOrder([c, b, a], within: all)

        XCTAssertEqual(titles(merged), ["다", "나", "가", "숨김1", "숨김2"])
        XCTAssertEqual(merged.count, all.count, "안 보이던 단축어가 순서 바꾸기에 쓸려 나갔다")
        XCTAssertEqual(titles(KeyboardMemoFeed.sorted(all.shuffled())),
                       ["다", "나", "가", "숨김1", "숨김2"])
    }

    // MARK: - 앞뒤 규칙

    /// 순서를 한 번 직접 정하면 즐겨찾기 맨 위 고정이 풀린다(앱의 순서 바꾸기와 같다).
    /// 내가 둔 자리보다 앱이 아는 규칙이 세면, 옮겨도 안 옮겨진 것으로 보인다.
    func testKeyboardReorder_MyOrderBeatsFavoritesOnTop() {
        let fav = memo("즐겨찾기", favorite: true, daysAgo: 5)
        let plain = memo("보통", daysAgo: 0)

        // 손대기 전에는 즐겨찾기가 위
        XCTAssertEqual(titles(KeyboardMemoFeed.sorted([plain, fav])), ["즐겨찾기", "보통"])

        // 즐겨찾기를 아래로 끌어 내렸다
        KeyboardMemoFeed.commitManualOrder([plain, fav], within: [fav, plain])

        XCTAssertEqual(titles(KeyboardMemoFeed.sorted([fav, plain])), ["보통", "즐겨찾기"])
        XCTAssertEqual(titles(viewModel.sortMemos([fav, plain])), ["보통", "즐겨찾기"])
    }

    /// 순서를 정한 뒤에 만든 단축어는 맨 위로 온다(앱과 같은 규칙).
    /// 뒤로 붙이면 방금 만든 것이 목록 끝에 묻혀 "어디 갔지"가 된다.
    func testKeyboardReorder_NewSnippetGoesOnTop() {
        let a = memo("가", daysAgo: 1)
        let b = memo("나", daysAgo: 2)
        KeyboardMemoFeed.commitManualOrder([b, a], within: [a, b])

        let fresh = memo("새로 만든 것", daysAgo: 0)
        XCTAssertEqual(titles(KeyboardMemoFeed.sorted([a, b, fresh])), ["새로 만든 것", "나", "가"])
        XCTAssertEqual(titles(viewModel.sortMemos([a, b, fresh])), ["새로 만든 것", "나", "가"])
    }

    /// 빈 목록으로는 아무것도 적지 않는다. 화면이 아직 안 찼을 때 적히면
    /// 있던 순서가 빈 순서로 덮인다.
    func testKeyboardReorder_EmptyReorderWritesNothing() {
        let a = memo("가", daysAgo: 0)
        let b = memo("나", daysAgo: 1)
        KeyboardMemoFeed.commitManualOrder([b, a], within: [a, b])

        _ = KeyboardMemoFeed.commitManualOrder([], within: [a, b])

        XCTAssertEqual(titles(KeyboardMemoFeed.sorted([a, b])), ["나", "가"])
    }
}
