//
//  OwnShortcutLimitTests.swift
//  ClipKeyboardTests
//
//  **무료 열 칸은 온전히 자기 몫인가.**
//
//  개수 분포에서 4~6 봉우리를 걷어내다 드러난 것이 있었다. 한도를 세는 쪽은 여전히
//  온보딩이 심어 준 샘플 4개를 함께 세고 있었다. 그래서 아무것도 안 만든 사람이
//  4/10 에서 시작했고, 실제로 쓸 수 있는 무료 칸은 6개였다. v4.1 에서 한도를
//  10으로 올린 뜻이 그만큼 도로 메워져 있었던 셈이다.
//
//  여기서 붙잡는 것은 하나다. **한도가 세는 것은 사용자가 저장한 것뿐이고,
//  무료 사용자는 자기 것 열 개를 다 채운 다음에야 결제 자리를 만난다.**
//
//  ⚠️ 샘플을 지웠는지 그냥 뒀는지, 고쳐 썼는지로 칸 수가 달라지면 안 된다.
//     그 셋은 모두 "자기 것 0개" 다.
//

import XCTest
@testable import ClipKeyboard

@MainActor
final class OwnShortcutLimitTests: XCTestCase {

    private var savedSampleIds: [String]?
    private var groupDefaults: UserDefaults? { AppGroup.defaults }

    override func setUp() {
        super.setUp()
        savedSampleIds = groupDefaults?.stringArray(forKey: DefaultsKey.sampleMemoIdsV1)
    }

    override func tearDown() {
        if let saved = savedSampleIds {
            groupDefaults?.set(saved, forKey: DefaultsKey.sampleMemoIdsV1)
        } else {
            groupDefaults?.removeObject(forKey: DefaultsKey.sampleMemoIdsV1)
        }
        UserDefaults.standard.removeObject(forKey: "sampleMemoUUIDs_v1")
        super.tearDown()
    }

    // MARK: - 거들기

    private func memo(_ title: String) -> Memo {
        Memo(title: title, value: "값", lastEdited: Date(), isFavorite: false)
    }

    /// 온보딩이 심어 준 것처럼 샘플 4개를 만들어 표에 적는다.
    private func seedSamples(count: Int = 4) -> [Memo] {
        let samples = (1...count).map { memo("샘플\($0)") }
        SampleMemoStorage.save(ids: samples.map(\.id))
        return samples
    }

    /// 무료 사용자에게만 뜻이 있는 시험이라, Pro 면 조용히 넘어간다.
    private func requireFreeUser() throws {
        try XCTSkipIf(ProFeatureManager.hasFullAccess, "Pro 는 한도가 없어 셀 것이 없다")
    }

    // MARK: - 한도가 세는 개수

    /// 갓 설치한 사람은 아무것도 안 만들었다. 심어 준 4개는 앱이 자기를 소개한 것이다.
    func testFreshInstall_StartsAtZero() {
        let samples = seedSamples()
        XCTAssertEqual(ProFeatureManager.ownMemoCount(samples), 0)
    }

    /// 샘플을 고쳐 써도 여전히 샘플이다. 고쳐 쓰라고 심어 둔 것이 칸을 뺏으면 앞뒤가 안 맞는다.
    func testEditedSample_StillDoesNotCount() {
        var samples = seedSamples()
        samples[0].title = "내 문구로 바꿈"
        samples[0].value = "내 값"
        samples[0].lastEdited = Date()

        XCTAssertEqual(ProFeatureManager.ownMemoCount(samples), 0)
    }

    /// 샘플을 지운다고 칸이 늘지 않는다. 지우든 두든 자기 칸은 그대로다.
    func testDeletingSamples_DoesNotChangeTheCount() {
        let samples = seedSamples()
        let mine = [memo("내 것1"), memo("내 것2")]

        XCTAssertEqual(ProFeatureManager.ownMemoCount(samples + mine), 2)
        XCTAssertEqual(ProFeatureManager.ownMemoCount(mine), 2, "샘플을 지워도 자기 것 개수는 같다")
    }

    // MARK: - 결제 자리까지 닿는가 (이 파일의 본론)

    /// 무료 사용자는 **자기 것 열 개**를 다 채운 다음에야 막힌다.
    /// 예전에는 샘플 4개 때문에 여섯 개째에서 막혔다.
    func testFreeUserReachesTheFullLimitBeforeThePaywall() throws {
        try requireFreeUser()
        let limit = ProFeatureManager.memoLimit
        let samples = seedSamples()

        // 한도 바로 앞: 아직 하나 더 만들 수 있다.
        let almost = samples + (1...(limit - 1)).map { memo("내 것\($0)") }
        XCTAssertEqual(ProFeatureManager.ownMemoCount(almost), limit - 1)
        XCTAssertTrue(ProFeatureManager.canAddMemo(currentCount: ProFeatureManager.ownMemoCount(almost)))

        // 자기 것으로 한도를 채웠을 때 비로소 막힌다(전체는 샘플까지 limit + 4개).
        let full = samples + (1...limit).map { memo("내 것\($0)") }
        XCTAssertEqual(ProFeatureManager.ownMemoCount(full), limit)
        XCTAssertEqual(full.count, limit + 4, "샘플은 한도 밖에 있다")
        XCTAssertFalse(ProFeatureManager.canAddMemo(currentCount: ProFeatureManager.ownMemoCount(full)))
    }

    /// 예전 방식(전체 개수)으로 세면 여섯 개째에서 막혔다는 것을 못박아 둔다.
    /// 이 시험이 깨지면 누군가 다시 전체를 세기 시작한 것이다.
    func testCountingEverything_WouldBlockFourEarly() throws {
        try requireFreeUser()
        let limit = ProFeatureManager.memoLimit
        let samples = seedSamples()
        let mine = (1...(limit - 4)).map { memo("내 것\($0)") }
        let all = samples + mine

        XCTAssertFalse(ProFeatureManager.canAddMemo(currentCount: all.count), "전체를 세면 여기서 막힌다")
        XCTAssertTrue(ProFeatureManager.canAddMemo(currentCount: ProFeatureManager.ownMemoCount(all)),
                      "자기 것만 세면 아직 네 칸이 남아 있다")
    }

    // MARK: - 키보드에서 보이는 것

    /// 샘플이 앞자리를 차지해도 자기 단축어는 한 개도 가려지지 않는다.
    /// 한도에서 빼 준 것을 화면에서 도로 세면 아무것도 안 바뀐 것과 같다.
    func testKeyboardShowsEveryOwnShortcut_EvenBehindSamples() throws {
        try requireFreeUser()
        let limit = ProFeatureManager.memoLimit
        let samples = seedSamples()
        let mine = (1...limit).map { memo("내 것\($0)") }

        let visible = ProFeatureManager.memosWithinLimit(samples + mine)

        XCTAssertEqual(visible.count, limit + 4)
        for m in mine {
            XCTAssertTrue(visible.contains(where: { $0.id == m.id }), "\(m.title) 이 가려졌다")
        }
    }

    /// 한도를 넘긴 자기 것은 여전히 가려진다(그랜드파더·칸 반납 등으로 넘칠 수 있다).
    func testKeyboardStillHidesOwnShortcutsBeyondTheLimit() throws {
        try requireFreeUser()
        let limit = ProFeatureManager.memoLimit
        let samples = seedSamples()
        let mine = (1...(limit + 3)).map { memo("내 것\($0)") }

        let visible = ProFeatureManager.memosWithinLimit(samples + mine)
        let visibleOwn = visible.filter { m in mine.contains(where: { $0.id == m.id }) }

        XCTAssertEqual(visibleOwn.count, limit)
        XCTAssertEqual(visibleOwn.map(\.title), mine.prefix(limit).map(\.title), "앞에서부터 남긴다")
    }

    // MARK: - 표를 옮겨 오기

    /// 이미 쓰고 있던 사람의 샘플 id 는 App Group 으로 옮겨진다.
    /// 안 옮기면 그 사람의 샘플이 전부 "자기 것" 이 되어, 늘려 주려던 칸이 도리어 줄어든다.
    func testLegacySampleIds_MoveIntoTheAppGroup() {
        let ids = (1...4).map { _ in UUID() }
        groupDefaults?.removeObject(forKey: DefaultsKey.sampleMemoIdsV1)
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: "sampleMemoUUIDs_v1")

        SampleMemoStorage.migrateToAppGroupIfNeeded()

        XCTAssertEqual(ProFeatureManager.sampleMemoIds, Set(ids), "키보드도 같은 표를 봐야 한다")
    }

    /// 옮기기 전에 물어봐도 앱은 옛 자리를 같이 본다.
    func testLoadSeesLegacyIds_BeforeTheMigrationRuns() {
        let ids = (1...4).map { _ in UUID() }
        groupDefaults?.removeObject(forKey: DefaultsKey.sampleMemoIdsV1)
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: "sampleMemoUUIDs_v1")

        XCTAssertEqual(SampleMemoStorage.load(), Set(ids))
    }
}
