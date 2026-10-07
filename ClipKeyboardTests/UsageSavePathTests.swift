//
//  UsageSavePathTests.swift
//  ClipKeyboardTests
//
//  넣을 때마다 오는 저장(쓴 횟수)이 가볍게 지나가는지.
//
//  잠그는 계약:
//  1. 쓴 횟수만 바뀐 저장은 되돌리기 이력을 만들지 않고, 알림에 "usage" 표시가 붙는다.
//     동기화 · 백업은 그 표시를 보고 건너뛴다.
//  2. 이력 비교 서명은 단축어 순서와 쓴 횟수에 흔들리지 않고, 내용이 바뀌면 달라진다.
//  3. 백업 지문은 쓴 횟수에 흔들리지 않고, 내용 · 그림 이름이 바뀌면 달라진다.
//

import XCTest
@testable import ClipKeyboard

final class UsageSavePathTests: XCTestCase {

    private let store = MemoStore.shared

    override func tearDown() {
        try? store.save(memos: [], type: .memo, recordHistory: false)
        super.tearDown()
    }

    // MARK: - 1. 쓴 횟수 저장

    func test_쓴_횟수_저장은_이력을_만들지_않고_usage_로_알린다() throws {
        let memo = Memo(title: "주소", value: "서울시 마포구")
        try store.save(memos: [memo], type: .memo, recordHistory: false)
        store.flushMemoHistory()
        let before = store.loadMemoHistory().count

        let posted = expectation(forNotification: .memoDataChanged, object: nil) { note in
            MemoStore.isUsageOnly(note)
        }
        try store.incrementClipCount(for: memo.id)
        wait(for: [posted], timeout: 2)

        store.flushMemoHistory()
        XCTAssertEqual(store.loadMemoHistory().count, before, "쓴 횟수만 바뀐 저장이 이력을 쌓으면 안 된다")
        XCTAssertEqual(try store.load(type: .memo).first?.clipCount, 1)
    }

    func test_내용_저장은_usage_가_아니다() throws {
        let posted = expectation(forNotification: .memoDataChanged, object: nil) { note in
            !MemoStore.isUsageOnly(note)
        }
        try store.save(memos: [Memo(title: "a", value: "b")], type: .memo)
        wait(for: [posted], timeout: 2)
    }

    func test_내용이_바뀌면_이력이_한_벌_쌓인다() throws {
        var memo = Memo(title: "주소", value: "서울시 마포구")
        try store.save(memos: [memo], type: .memo, recordHistory: false)
        store.flushMemoHistory()
        let before = store.loadMemoHistory().count

        memo.value = "부산시 해운대구"
        try store.save(memos: [memo], type: .memo)
        store.flushMemoHistory()

        XCTAssertEqual(store.loadMemoHistory().count, min(before + 1, MemoStore.memoHistoryLimit))
        XCTAssertEqual(store.loadMemoHistory().first?.memos.first?.value, "서울시 마포구", "덮기 전 상태가 남는다")
    }

    // MARK: - 2. 이력 비교 서명

    func test_서명은_순서와_쓴_횟수에_흔들리지_않는다() {
        let a = Memo(title: "가", value: "1")
        var b = Memo(title: "나", value: "2")
        let base = MemoStore.historySignature([a, b])
        XCTAssertEqual(MemoStore.historySignature([b, a]), base)
        b.clipCount = 99
        b.lastUsedAt = Date()
        XCTAssertEqual(MemoStore.historySignature([a, b]), base)
        b.value = "3"
        XCTAssertNotEqual(MemoStore.historySignature([a, b]), base)
        XCTAssertNotEqual(MemoStore.historySignature([a]), base, "개수가 줄면 달라진다")
    }

    // MARK: - 3. 백업 지문

    func test_백업_지문은_쓴_횟수를_무시하고_내용과_그림에_반응한다() {
        var memo = Memo(title: "주소", value: "서울시")
        func fp(_ memos: [Memo], images: Set<String> = []) -> String {
            CloudKitBackupService.contentFingerprint(memos: memos, smartClipboard: [], combos: [],
                                                     categoriesData: nil, imageNames: images)
        }
        let base = fp([memo])
        XCTAssertEqual(fp([memo]), base, "같은 내용은 같은 지문(실행 간에도)")
        memo.clipCount = 5
        memo.lastUsedAt = Date()
        XCTAssertEqual(fp([memo]), base, "쓴 횟수만 바뀌면 다시 올리지 않는다")
        XCTAssertNotEqual(fp([memo], images: ["a.jpg"]), base)
        memo.value = "부산시"
        XCTAssertNotEqual(fp([memo]), base)
    }
}
