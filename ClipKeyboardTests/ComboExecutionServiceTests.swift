//
//  ComboExecutionServiceTests.swift
//  ClipKeyboardTests
//
//  Combo 실행 서비스 테스트 (통합 모델: 콤보 = comboValues 단계를 가진 Memo)
//

import XCTest
@testable import ClipKeyboard

final class ComboExecutionServiceTests: XCTestCase {

    var sut: ComboExecutionService!
    var memoStore: MemoStore!
    var testMemos: [Memo]!

    override func setUp() {
        super.setUp()
        sut = ComboExecutionService.shared
        memoStore = MemoStore.shared

        // 싱글톤 격리: 이전 테스트가 비-idle 상태로 끝났으면 startCombo가 막힌다.
        sut.stopCombo()

        testMemos = [
            Memo(title: "메모1", value: "값1"),
            Memo(title: "메모2", value: "값2"),
            Memo(title: "메모3", value: "값3")
        ]
        try? memoStore.save(memos: testMemos, type: .memo)
    }

    override func tearDown() {
        sut.stopCombo()
        try? memoStore.save(memos: [], type: .memo)
        testMemos = nil
        memoStore = nil
        sut = nil
        super.tearDown()
    }

    /// testMemos 값으로 콤보 단계(comboValues)를 구성해 콤보 Memo 생성.
    private func makeCombo(_ indexes: [Int], interval: TimeInterval = 0.1) -> Memo {
        let values = indexes.map { testMemos[$0].value }
        return Memo(id: UUID(), title: "테스트", value: values.first ?? "",
                    comboValues: values, comboInterval: interval)
    }

    // MARK: - State Tests

    func testInitialState() {
        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(sut.currentItemIndex, 0)
    }

    func testStartCombo_ChangesStateToRunning() {
        sut.startCombo(makeCombo([0, 1], interval: 0.1))
        if case .running = sut.state {} else { XCTFail("State should be running") }
    }

    func testStopCombo_ResetsToIdle() {
        sut.startCombo(makeCombo([0, 1], interval: 0.1))
        sut.stopCombo()
        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(sut.currentItemIndex, 0)
    }

    func testPauseCombo() {
        sut.startCombo(makeCombo([0, 1], interval: 5.0))
        sut.pauseCombo()
        if case .paused = sut.state {} else { XCTFail("State should be paused") }
    }

    func testResumeCombo() {
        sut.startCombo(makeCombo([0, 1], interval: 5.0))
        sut.pauseCombo()
        sut.resumeCombo()
        if case .running = sut.state {} else { XCTFail("State should be running after resume") }
    }

    func testSingleItemCombo_CompletesImmediately() {
        sut.startCombo(makeCombo([0], interval: 0.1))
        // 단일 항목은 startCombo 내에서 즉시 completeExecution → .completed
        XCTAssertEqual(sut.state, .completed)
    }

    func testProgress() {
        sut.startCombo(makeCombo([0, 1, 2], interval: 5.0))
        XCTAssertEqual(sut.progress, 0.0, accuracy: 0.001)
    }

    func testConcurrentStart_IsIgnored() {
        let first = makeCombo([0, 1], interval: 5.0)
        sut.startCombo(first)
        let firstState = sut.state
        sut.startCombo(makeCombo([2], interval: 5.0)) // 실행 중 → 무시
        XCTAssertEqual(sut.state, firstState)
    }

    func testComboWithEmptyStep_StillRuns() {
        // 중간에 빈 단계가 섞여도 실행은 진행된다(크래시 없이).
        let combo = Memo(id: UUID(), title: "테스트", value: "값1",
                         comboValues: ["값1", "", "값3"], comboInterval: 0.1)
        sut.startCombo(combo)
        XCTAssertNotEqual(sut.state, .idle)
    }

    func testEmptyCombo_DoesNotStart() {
        sut.startCombo(Memo(title: "빈 콤보", value: ""))  // comboValues 없음
        XCTAssertEqual(sut.state, .idle)
    }

    func testCompletion_IncrementsClipCount() {
        var combo = makeCombo([0], interval: 0.1)
        combo.title = "사용 횟수"
        // 콤보 메모도 저장돼 있어야 incrementClipCount가 찾는다.
        var all = (try? memoStore.load(type: .memo)) ?? []
        all.append(combo)
        try? memoStore.save(memos: all, type: .memo)

        sut.startCombo(combo)   // 단일 항목 → 즉시 완료 → incrementClipCount

        let exp = expectation(description: "clipCount incremented")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let reloaded = (try? self.memoStore.load(type: .memo)) ?? []
            let saved = reloaded.first(where: { $0.id == combo.id })
            XCTAssertEqual(saved?.clipCount, 1)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }
}
