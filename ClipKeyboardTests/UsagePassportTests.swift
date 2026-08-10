//
//  UsagePassportTests.swift
//  ClipKeyboardTests
//
//  비자 페이지 집계 규칙을 고정한다. 순수 함수라 저장소 없이 검증된다.
//
//  특히 지켜야 하는 두 지점:
//   ① 이 화면은 공유 대상이다 - **보안 문구는 제목조차 새어나가면 안 된다.**
//   ② 정렬이 흔들리면 도장 순서가 매번 바뀐다 - 동점 처리까지 못 박는다.
//

import XCTest
@testable import ClipKeyboard

final class UsagePassportTests: XCTestCase {

    private func memo(_ title: String,
                      uses: Int,
                      secure: Bool = false,
                      lastUsed: Date? = nil) -> Memo {
        var m = Memo(title: title, value: "value-\(title)", isSecure: secure, lastUsedAt: lastUsed)
        m.clipCount = uses
        return m
    }

    // MARK: - 합계

    func testTotalsCountEveryMemo() {
        let summary = UsagePassport.summary(
            memos: [memo("A", uses: 10), memo("B", uses: 5), memo("C", uses: 0)],
            timeSavedSeconds: 3600
        )
        XCTAssertEqual(summary.totalUses, 15)
        XCTAssertEqual(summary.usedShortcuts, 2)
        XCTAssertEqual(summary.unusedShortcuts, 1)
        XCTAssertEqual(summary.timeSavedHours, 1)
    }

    func testEmptyLibraryProducesZeroes() {
        let summary = UsagePassport.summary(memos: [], timeSavedSeconds: 0)
        XCTAssertEqual(summary.totalUses, 0)
        XCTAssertTrue(summary.stamps.isEmpty)
        XCTAssertFalse(summary.isWorthShowing)
    }

    /// 음수 시간이 들어와도(시계 변경·손상된 값) 화면이 이상해지지 않아야 한다.
    func testNegativeTimeSavedIsClamped() {
        let summary = UsagePassport.summary(memos: [memo("A", uses: 1)], timeSavedSeconds: -500)
        XCTAssertEqual(summary.timeSavedSeconds, 0)
    }

    // MARK: - 도장

    func testStampsAreRankedByUseCount() {
        let summary = UsagePassport.summary(
            memos: [memo("적게", uses: 3), memo("많이", uses: 40), memo("중간", uses: 12)],
            timeSavedSeconds: 0
        )
        XCTAssertEqual(summary.stamps.map(\.label), ["많이", "중간", "적게"])
    }

    /// 사용 횟수가 같으면 최근에 쓴 것이 앞에 온다 - 순서가 매번 흔들리면 안 된다.
    func testTiesBreakByRecency() {
        let old = Date(timeIntervalSince1970: 1_000)
        let recent = Date(timeIntervalSince1970: 9_000)
        let summary = UsagePassport.summary(
            memos: [memo("옛것", uses: 7, lastUsed: old), memo("새것", uses: 7, lastUsed: recent)],
            timeSavedSeconds: 0
        )
        XCTAssertEqual(summary.stamps.map(\.label), ["새것", "옛것"])
    }

    func testUnusedMemosNeverGetAStamp() {
        let summary = UsagePassport.summary(
            memos: [memo("쓴것", uses: 1), memo("안쓴것", uses: 0)],
            timeSavedSeconds: 0
        )
        XCTAssertEqual(summary.stamps.count, 1)
        XCTAssertEqual(summary.stamps.first?.label, "쓴것")
    }

    func testStampCountIsCapped() {
        let memos = (1...30).map { memo("문구\($0)", uses: $0) }
        let summary = UsagePassport.summary(memos: memos, timeSavedSeconds: 0, limit: 5)
        XCTAssertEqual(summary.stamps.count, 5)
    }

    // MARK: - 프라이버시 (가장 중요)

    func testSecureMemoTitleIsNeverExposed() {
        let summary = UsagePassport.summary(
            memos: [memo("회사 법인카드 비번", uses: 99, secure: true)],
            timeSavedSeconds: 0
        )
        let label = summary.stamps.first?.label ?? ""
        XCTAssertFalse(label.contains("법인카드"), "보안 문구의 제목이 공유 화면에 새어나갔다")
        XCTAssertEqual(label, UsagePassport.displayLabel(for: memo("무엇이든", uses: 1, secure: true)))
    }

    func testUntitledMemoFallsBackWithoutLeakingValue() {
        var m = Memo(title: "   ", value: "110-2402-8845-01")
        m.clipCount = 4
        let summary = UsagePassport.summary(memos: [m], timeSavedSeconds: 0)
        let label = summary.stamps.first?.label ?? ""
        XCTAssertFalse(label.contains("110"), "제목이 없다고 값을 대신 보여주면 안 된다")
        XCTAssertFalse(label.isEmpty)
    }

    // MARK: - 표시 문구

    func testTimeSavedTextHidesUnderOneMinute() {
        XCTAssertNil(UsagePassport.timeSavedText(seconds: 0))
        XCTAssertNil(UsagePassport.timeSavedText(seconds: 59))
        XCTAssertNotNil(UsagePassport.timeSavedText(seconds: 60))
    }

    func testWorthShowingThreshold() {
        let few = UsagePassport.summary(memos: [memo("A", uses: 19)], timeSavedSeconds: 0)
        let many = UsagePassport.summary(memos: [memo("A", uses: 20)], timeSavedSeconds: 0)
        XCTAssertFalse(few.isWorthShowing)
        XCTAssertTrue(many.isWorthShowing)
    }

    // MARK: - 잉크 농도

    func testInkOpacityGrowsAndCaps() {
        XCTAssertEqual(Delight.inkOpacity(forUseCount: 0), 0)
        let light = Delight.inkOpacity(forUseCount: 3)
        let heavy = Delight.inkOpacity(forUseCount: 60)
        XCTAssertGreaterThan(heavy, light)
        // 상한이 없으면 특정 행만 시커멓게 보인다.
        XCTAssertEqual(Delight.inkOpacity(forUseCount: 10_000), 0.50, accuracy: 0.0001)
    }
}
