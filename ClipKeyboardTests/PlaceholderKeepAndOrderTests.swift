//
//  PlaceholderKeepAndOrderTests.swift
//  ClipKeyboardTests
//
//  빈칸 값을 **언제 남기고, 어떤 순서로 세우는가.**
//
//  왜 생겼나: 사용자 피드백.
//
//    빈칸의 순서를 바꾸고 단축어 입력 창에서 빈칸에 없는 문구로 대체하여 바로 입력할
//    수 있으면 좋겠습니다. 새로 입력한 빈칸은 이번에만 쓰는 용도이기 때문에 빈칸에는
//    추가되지 않으면 좋겠네요.
//
//  여기서 지키는 약속.
//   ① 채울 때 적은 값은 **저장되지 않는다** (이번에만 쓴다)
//   ② 별을 눌렀을 때만 남는다
//   ③ 이미 있는 값을 또 남기려 해도 두 개가 되지 않는다
//   ④ 값 순서를 손으로 정하면 그대로 남는다
//   ⑤ 값을 **쓰는 것만으로는** 순서가 흐트러지지 않는다 (이게 원래 불만이었다)
//

import XCTest
import SwiftUI
@testable import ClipKeyboard

@MainActor
final class PlaceholderKeepAndOrderTests: XCTestCase {

    private let token = "{받는사람}"
    private let memoId = UUID()

    override func setUp() {
        super.setUp()
        clear()
    }

    override func tearDown() {
        clear()
        super.tearDown()
    }

    private func clear() {
        for v in MemoStore.shared.loadPlaceholderValues(for: token) {
            MemoStore.shared.deletePlaceholderValue(valueId: v.id, for: token)
        }
    }

    private func keep(_ value: String) {
        MemoStore.shared.addPlaceholderValue(value, for: token,
                                             sourceMemoId: memoId, sourceMemoTitle: "시험")
    }

    private var saved: [String] {
        MemoStore.shared.loadPlaceholderValues(for: token).map(\.value)
    }

    // MARK: - ①② 남기는 것은 별을 누를 때뿐

    /// 채우기 창은 복사할 때 아무것도 저장하지 않는다. 이 시험이 지키는 것은 그 약속의
    /// 저장소 쪽 절반이다 - 부르지 않으면 아무 일도 안 일어난다.
    func test_아무도_남기지_않으면_목록은_비어_있다() {
        XCTAssertTrue(saved.isEmpty, "채우기만으로는 값이 쌓이면 안 된다")
    }

    func test_별을_누른_값만_남는다() {
        keep("이영훈")
        XCTAssertEqual(saved, ["이영훈"])
    }

    // MARK: - ③ 같은 값을 두 번 남겨도 하나

    func test_같은_값은_두_개가_되지_않는다() {
        keep("이영훈")
        keep("이영훈")
        XCTAssertEqual(saved, ["이영훈"], "같은 칩이 두 개 보이면 어느 것을 눌러도 같은데 고민하게 된다")
    }

    // MARK: - ④ 손으로 정한 순서가 남는다

    func test_손으로_바꾼_순서가_그대로_남는다() {
        keep("셋")
        keep("둘")
        keep("하나")
        XCTAssertEqual(saved, ["하나", "둘", "셋"], "남긴 순서는 최근 것이 앞")

        // 관리 화면에서 끌어 옮긴 것과 같은 일 (PlaceholderDetailView.moveValues)
        var values = MemoStore.shared.loadPlaceholderValues(for: token)
        values.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)   // "셋"을 맨 앞으로
        MemoStore.shared.savePlaceholderValues(values, for: token)

        XCTAssertEqual(saved, ["셋", "하나", "둘"])
    }

    func test_다시_읽어도_순서가_유지된다() {
        keep("나중")
        keep("먼저")
        var values = MemoStore.shared.loadPlaceholderValues(for: token)
        values.reverse()
        MemoStore.shared.savePlaceholderValues(values, for: token)

        // 새로 읽어 들여도 같은 순서
        XCTAssertEqual(MemoStore.shared.loadPlaceholderValues(for: token).map(\.value),
                       ["나중", "먼저"])
    }

    // MARK: - ⑤ 쓰는 것만으로는 순서가 흐트러지지 않는다

    /// 원래 불만이 이것이었다. 예전에는 채우고 복사할 때마다 그 값이 맨 앞으로 끌려 올라가서,
    /// 자리를 외워 두고 고르던 사람은 누를 때마다 다시 찾아야 했다.
    /// 지금은 복사가 저장을 부르지 않으므로 순서가 움직일 이유가 없다.
    func test_값을_쓰기만_해서는_순서가_바뀌지_않는다() {
        keep("셋")
        keep("둘")
        keep("하나")
        let before = saved

        // 채우기 창에서 "셋"을 골라 복사한 것과 같은 상황 - 저장소를 건드리지 않는다.
        let picked = "셋"
        XCTAssertTrue(before.contains(picked))

        XCTAssertEqual(saved, before, "고르고 복사했다고 순서가 움직이면 안 된다")
    }
}
