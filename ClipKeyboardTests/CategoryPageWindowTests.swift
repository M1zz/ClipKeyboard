//
//  CategoryPageWindowTests.swift
//  ClipKeyboardTests
//
//  카테고리 페이지를 옆으로 넘길 때 **무엇을 지어 두는가**를 못 박는다.
//
//  이 규칙은 두 가지를 동시에 지켜야 해서 한쪽만 보면 반드시 하나가 깨진다.
//
//   · 적게 지어야 부드럽다. 페이지를 전부 지으면 카드가 통째로 뷰 그래프에 올라가고,
//     키보드가 올라와 safe area 가 한 번 바뀌는 것만으로 전부 더럽혀진다(722ms 행).
//   · 그런데 너무 적게 지으면 넘기는 동안 빈 화면이 스친다.
//
//  창을 한 박자 늦게 옮기는 것이 그 사이를 지나는 길이고, 그때 "지금 보고 있는
//  페이지"라는 안전선이 없으면 빠른 스와이프에서 빈 화면이 나온다. 그 안전선을 지킨다.
//

import XCTest
@testable import ClipKeyboard

final class CategoryPageWindowTests: XCTestCase {

    private func built(_ index: Int, center: Int, selected: Int) -> Bool {
        CategoryPageWindow.isBuilt(index: index, center: center, selected: selected)
    }

    // MARK: - 창 안

    func test_창의_한가운데와_좌우_두_장을_짓는다() {
        for index in 3...7 {
            XCTAssertTrue(built(index, center: 5, selected: 5), "\(index)번은 창 안이다")
        }
    }

    func test_창_밖은_짓지_않는다() {
        XCTAssertFalse(built(2, center: 5, selected: 5))
        XCTAssertFalse(built(8, center: 5, selected: 5))
        XCTAssertFalse(built(0, center: 5, selected: 5))
    }

    // MARK: - 창이 아직 못 따라온 사이

    /// 한 장 넘긴 직후. 창은 아직 이전 자리에 있지만 목적지는 이미 지어져 있다.
    /// 이것이 성립해야 **미끄러지는 동안 새로 지을 것이 없다**.
    func test_이웃으로_넘긴_직후에는_지을_것이_없다() {
        // 5번에서 6번으로 넘겼다. 창은 아직 5.
        XCTAssertTrue(built(6, center: 5, selected: 6), "목적지는 이미 창 안이라 새로 지을 일이 없다")
        XCTAssertFalse(built(8, center: 5, selected: 6), "그 너머는 손이 멎은 뒤에 짓는다")
    }

    /// 창이 늦는 동안 **한 칸 더** 넘겨도 도착할 페이지가 이미 서 있어야 한다.
    /// 이게 깨지면 한 칸씩 연달아 넘길 때 두 번째마다 빈 화면이 스친다.
    func test_창이_늦는_동안_한_칸_더_넘겨도_비지_않는다() {
        // 5에서 6으로 넘긴 직후(창은 5), 손을 떼기 전에 7로 끌기 시작한다.
        XCTAssertTrue(built(7, center: 5, selected: 6),
                      "끄는 동안 따라오는 페이지가 비어 있으면 깜빡인다")
    }

    /// 빠르게 여러 장을 넘기면 창이 못 따라온다. 그래도 보고 있는 페이지는 서 있어야 한다.
    /// 이 조건이 없던 시절의 증상이 "넘기는 중에 빈 화면이 스친다" 였다.
    func test_창이_못_따라와도_보고_있는_페이지는_짓는다() {
        XCTAssertTrue(built(12, center: 5, selected: 12),
                      "창 밖이어도 지금 보고 있는 페이지를 비워 두면 안 된다")
    }

    /// 탭 바로 멀리 건너뛴 경우도 같다.
    func test_멀리_건너뛴_자리도_짓는다() {
        XCTAssertTrue(built(0, center: 12, selected: 0))
    }

    // MARK: - 규모

    /// 카테고리가 몇 개든 짓는 페이지 수는 늘지 않는다. 이 성질이 깨지면
    /// 카테고리가 늘수록 느려지던 예전으로 돌아간다.
    func test_카테고리가_늘어도_짓는_페이지_수는_그대로다() {
        for total in [12, 20, 60] {
            let count = (0..<total).filter { built($0, center: 5, selected: 5) }.count
            XCTAssertEqual(count, 5, "카테고리 \(total)개에서도 다섯 장만 짓는다")
        }
    }

    /// 창이 목록 끝에 걸치면 그만큼만 짓는다. 없는 페이지를 세지 않는다.
    func test_끝에서는_창이_잘린다() {
        let total = 4
        let count = (0..<total).filter { built($0, center: 0, selected: 0) }.count
        XCTAssertEqual(count, 3, "0번에 있으면 0·1·2 만 있다")
    }

    /// 창이 못 따라온 사이에는 한 장이 더 설 수 있다. 그 이상은 아니다.
    func test_창이_뒤처져도_최대_여섯_장이다() {
        let count = (0..<60).filter { built($0, center: 5, selected: 20) }.count
        XCTAssertEqual(count, 6, "창 다섯 장 + 보고 있는 한 장")
    }
}
