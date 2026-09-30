//
//  FreeUseTests.swift
//  ClipKeyboardTests
//
//  무료로 쓰는 기간(`FreeUse`)의 약속을 지킨다.
//
//   ① 문턱 전에는 전부 열려 있다(Pro 와 같다)
//   ② 세는 값은 줄지 않는다. 단축어를 지워도 남는다
//   ③ 이정표는 하나씩, 한 번만, 지나간 낮은 것은 건너뛴다. 돈을 낸 사람에게는 없다
//   ④ 원격 문턱은 허용 범위 안에서만 받는다
//   ⑤ 문턱 뒤에도 만든 것은 전부 키보드에 실린다
//

import XCTest
@testable import ClipKeyboard

@MainActor
final class FreeUseTests: XCTestCase {

    private var defaults: UserDefaults? { AppGroup.defaults }
    private let keys = [DefaultsKey.freeUseCount, DefaultsKey.freeUseFirstAt,
                        DefaultsKey.freeUseMilestonesSeen, DefaultsKey.remoteFreeUseThreshold]
    private var saved: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        saved = [:]
        for key in keys {
            if let value = defaults?.object(forKey: key) { saved[key] = value }
            defaults?.removeObject(forKey: key)
        }
        try? MemoStore.shared.save(memos: [], type: .memo, recordHistory: false)
    }

    override func tearDown() {
        for key in keys {
            if let value = saved[key] { defaults?.set(value, forKey: key) } else { defaults?.removeObject(forKey: key) }
        }
        try? MemoStore.shared.save(memos: [], type: .memo, recordHistory: false)
        super.tearDown()
    }

    private var paidOnThisDevice: Bool {
        ProFeatureManager.isPro || ProFeatureManager.isGrandfathered || ProFeatureManager.isInTrial
    }

    // MARK: - ① 문턱 전에는 전부 열려 있다

    func test_문턱_전에는_전부_열려_있고_문턱에서_닫힌다() {
        XCTAssertTrue(FreeUse.isActive(uses: 0, threshold: 100))
        XCTAssertTrue(FreeUse.isActive(uses: 99, threshold: 100))
        XCTAssertFalse(FreeUse.isActive(uses: 100, threshold: 100), "100번째를 넣은 순간 끝난다")
    }

    func test_무료_기간에는_Pro와_같다() throws {
        try XCTSkipIf(paidOnThisDevice, "이 기기가 이미 Pro 라 무료 기간을 가를 수 없다")
        defaults?.set(10, forKey: DefaultsKey.freeUseCount)
        XCTAssertTrue(ProFeatureManager.hasFullAccess)
        XCTAssertTrue(ProFeatureManager.canAddMemo(currentCount: 500), "무료 기간에는 개수 벽이 없다")
        XCTAssertTrue(ProFeatureManager.canAddTemplate(currentCount: 50))

        defaults?.set(FreeUse.threshold, forKey: DefaultsKey.freeUseCount)
        XCTAssertFalse(ProFeatureManager.hasFullAccess)
        XCTAssertFalse(ProFeatureManager.canAddMemo(currentCount: ProFeatureManager.memoLimit),
                       "문턱 뒤에는 예전 무료 한도가 선다")
        XCTAssertTrue(ProFeatureManager.canAddMemo(currentCount: 0), "예전에 무료였던 만큼은 계속 무료다")
    }

    // MARK: - ② 세는 값은 줄지 않는다

    func test_쓸_때마다_세고_지워도_줄지_않는다() throws {
        let memo = Memo(title: "인사", value: "안녕하세요")
        try MemoStore.shared.save(memos: [memo], type: .memo, recordHistory: false)

        try MemoStore.shared.incrementClipCount(for: memo.id)
        try MemoStore.shared.incrementClipCount(for: memo.id)
        XCTAssertEqual(FreeUse.uses, 2, "키보드 · 앱이 지나는 한 길목에서 센다")
        XCTAssertNotNil(FreeUse.firstUseAt)

        try MemoStore.shared.save(memos: [], type: .memo, recordHistory: false)
        XCTAssertEqual(FreeUse.uses, 2, "지웠다 만들기로 문턱을 피할 수 없어야 한다")
    }

    func test_처음_쓴_날은_한_번만_적는다() {
        let first = Date(timeIntervalSince1970: 1_800_000_000)
        FreeUse.recordUse(now: first)
        FreeUse.recordUse(now: first.addingTimeInterval(86_400 * 3))
        XCTAssertEqual(FreeUse.firstUseAt, first)
        XCTAssertEqual(FreeUse.daysSinceFirstUse(now: first.addingTimeInterval(86_400 * 3)), 4)
    }

    // MARK: - ③ 이정표

    func test_이정표는_닿은_가장_높은_것_하나만() {
        let seen: Set<FreeUse.Milestone> = []
        XCTAssertNil(FreeUse.pendingMilestone(uses: 49, threshold: 100, seen: seen, hasPaid: false))
        XCTAssertEqual(FreeUse.pendingMilestone(uses: 50, threshold: 100, seen: seen, hasPaid: false), .half)
        XCTAssertEqual(FreeUse.pendingMilestone(uses: 85, threshold: 100, seen: seen, hasPaid: false), .nearEnd,
                       "오래 안 열다 85번에 열었으면 50번 카드는 건너뛴다")
        XCTAssertEqual(FreeUse.pendingMilestone(uses: 130, threshold: 100, seen: seen, hasPaid: false), .reached)
    }

    func test_본_이정표는_다시_뜨지_않고_돈을_낸_사람에게는_없다() {
        XCTAssertNil(FreeUse.pendingMilestone(uses: 60, threshold: 100, seen: [.half], hasPaid: false))
        XCTAssertEqual(FreeUse.pendingMilestone(uses: 80, threshold: 100, seen: [.half], hasPaid: false), .nearEnd)
        XCTAssertNil(FreeUse.pendingMilestone(uses: 100, threshold: 100, seen: [], hasPaid: true))
    }

    func test_이정표는_문턱에_비례한다() {
        XCTAssertEqual(FreeUse.Milestone.half.uses(threshold: 200), 100)
        XCTAssertEqual(FreeUse.Milestone.nearEnd.uses(threshold: 200), 160)
        XCTAssertEqual(FreeUse.Milestone.reached.uses(threshold: 200), 200)
    }

    func test_본_표시는_저장된다() {
        FreeUse.markSeen(.half)
        FreeUse.markSeen(.half)
        XCTAssertEqual(FreeUse.seenMilestones, [.half])
    }

    // MARK: - ④ 원격 문턱

    func test_원격_문턱은_허용_범위_안에서만() {
        XCTAssertEqual(FreeUse.resolvedThreshold(remote: nil), 100)
        XCTAssertEqual(FreeUse.resolvedThreshold(remote: 150), 150)
        XCTAssertEqual(FreeUse.resolvedThreshold(remote: 0), 100, "0 이면 모두가 첫날부터 막힌다")
        XCTAssertEqual(FreeUse.resolvedThreshold(remote: 100_000), 100, "너무 크면 영영 안 닫힌다")
    }

    func test_원격_서비스와_키보드가_같은_자리를_본다() {
        XCTAssertEqual(RemoteFlagsService.Number.freeUseThreshold.cacheKey, DefaultsKey.remoteFreeUseThreshold)
        defaults?.set(60, forKey: DefaultsKey.remoteFreeUseThreshold)
        XCTAssertEqual(FreeUse.threshold, 60)
    }

    // MARK: - ⑤ 만든 것은 전부 실린다

    func test_문턱_뒤에도_만든_것은_전부_키보드에_실린다() {
        let memos = (0..<25).map { Memo(title: "문구 \($0)", value: "값 \($0)") }
        defaults?.set(FreeUse.threshold + 50, forKey: DefaultsKey.freeUseCount)
        XCTAssertEqual(ProFeatureManager.memosWithinLimit(memos).count, 25,
                       "어제까지 되던 키가 오늘 사라지면 결제 안내가 아니라 고장이다")
    }

    // MARK: - 영수증

    func test_영수증은_샘플을_빼고_가장_많이_쓴_것을_고른다() {
        var mail = Memo(title: "회사 메일", value: "leeo@kakao.com"); mail.clipCount = 41
        var hello = Memo(title: "인사", value: "안녕하세요"); hello.clipCount = 9
        let sample = Memo(title: "샘플", value: "예시")
        let receipt = FreeUseReceipt.make(uses: 100, days: 34, secondsSaved: 37 * 60 + 20,
                                          memos: [mail, hello, sample], samples: [sample.id])
        XCTAssertEqual(receipt.ownCount, 2)
        XCTAssertEqual(receipt.minutesSaved, 37)
        XCTAssertEqual(receipt.topSnippet, .init(title: "회사 메일", count: 41))
    }
}
