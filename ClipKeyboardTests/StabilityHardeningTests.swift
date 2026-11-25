//
//  StabilityHardeningTests.swift
//  ClipKeyboardTests
//
//  안정화(2026-11-25)에서 막은 자리들. 죽는 자리 · 데이터가 사라지는 자리 · 조용히 틀리는 자리.
//  자세한 것은 docs/postmortem/KEYBOARD_LAUNCH_INCOMPLETE_STAGES.md
//

import XCTest
@testable import ClipKeyboard

final class StabilityHardeningTests: XCTestCase {

    // MARK: - 키보드가 어디서 멈췄는가 (KeyboardLaunchTrail)

    private var defaults: UserDefaults!
    private let suiteName = "StabilityHardeningTests.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testReportSplitsStagesAndKeepsIdleOutOfIncomplete() {
        let report = KeyboardLaunchTrail.report(missed: 3, stages: ["load", "idle", "shown"])
        XCTAssertEqual(report.sources, ["keyboard-load", "keyboard-shown"])
        XCTAssertEqual(report.idleExits, 1, "보이지도 않은 채 정리된 실행은 따로 센다")
    }

    func testReportFallsBackToPlainKeyboardWhenStageUnknown() {
        // 단계를 적기 전 판이 남긴 몫(가드는 셌지만 단계 기록이 없다)과 빈 단계는 예전 이름 그대로.
        let report = KeyboardLaunchTrail.report(missed: 3, stages: [""])
        XCTAssertEqual(report.sources, ["keyboard", "keyboard", "keyboard"])
        XCTAssertEqual(report.idleExits, 0)
    }

    func testReportUsesOnlyTheLatestStagesAndCapsEvents() {
        let stages = ["load", "load", "appearing", "appearing", "appearing", "idle"]
        let report = KeyboardLaunchTrail.report(missed: 5, stages: stages)
        XCTAssertEqual(report.sources.count, KeyboardLaunchTrail.maxEventsPerReport)
        XCTAssertEqual(report.sources, ["keyboard-load", "keyboard-appearing", "keyboard-appearing"])
        XCTAssertEqual(report.idleExits, 1)
        XCTAssertEqual(KeyboardLaunchTrail.report(missed: 0, stages: stages),
                       .init(sources: [], idleExits: 0), "가드가 센 것이 없으면 아무것도 안 보낸다")
    }

    func testIdleExitDoesNotForceSafeMode() {
        XCTAssertTrue(KeyboardLaunchTrail.opensSafeMode(guardSaysSafe: true, lastIncompleteStage: "load"))
        XCTAssertTrue(KeyboardLaunchTrail.opensSafeMode(guardSaysSafe: true, lastIncompleteStage: nil))
        XCTAssertTrue(KeyboardLaunchTrail.opensSafeMode(guardSaysSafe: true, lastIncompleteStage: "appearing"))
        XCTAssertFalse(KeyboardLaunchTrail.opensSafeMode(guardSaysSafe: true, lastIncompleteStage: "idle"))
        XCTAssertFalse(KeyboardLaunchTrail.opensSafeMode(guardSaysSafe: false, lastIncompleteStage: "load"))
    }

    func testPendingStagesAreCappedAndTakenOnce() {
        for _ in 0..<(KeyboardLaunchTrail.maxPending + 4) {
            KeyboardLaunchTrail.noteIncomplete(at: .appearing, in: defaults)
        }
        KeyboardLaunchTrail.noteIncomplete(at: nil, in: defaults)
        XCTAssertEqual(defaults.string(forKey: DefaultsKey.keyboardLastIncompleteStage), "")

        let taken = KeyboardLaunchTrail.takePendingStages(in: defaults)
        XCTAssertEqual(taken.count, KeyboardLaunchTrail.maxPending)
        XCTAssertEqual(taken.last, "")
        XCTAssertTrue(KeyboardLaunchTrail.takePendingStages(in: defaults).isEmpty, "꺼내면 비운다")
    }

    func testMarkIsReadBack() {
        XCTAssertNil(KeyboardLaunchTrail.lastStage(in: defaults))
        KeyboardLaunchTrail.mark(.shown, in: defaults)
        XCTAssertEqual(KeyboardLaunchTrail.lastStage(in: defaults), .shown)
        defaults.set("모르는 값", forKey: DefaultsKey.keyboardLaunchStage)
        XCTAssertNil(KeyboardLaunchTrail.lastStage(in: defaults), "모르는 값은 단계 없음으로 읽는다")
    }

    // MARK: - 키보드가 쓴 것을 앱에 알린다

    func testExtensionSaveMarksExternalChange() {
        MemoStore.markExternalChangeIfExtension(isExtension: false, defaults: defaults)
        XCTAssertEqual(defaults.double(forKey: DefaultsKey.memosExternalChangeAt), 0, "앱 자신의 저장은 표식을 세우지 않는다")
        MemoStore.markExternalChangeIfExtension(isExtension: true, defaults: defaults)
        XCTAssertGreaterThan(defaults.double(forKey: DefaultsKey.memosExternalChangeAt), 0)
    }

    // MARK: - 모르는 종류 값 한 칸이 목록 전체를 깎지 않는다

    func testUnknownEnumValueKeepsTheRestOfTheMemo() throws {
        let id = UUID()
        let json = """
        [{"id":"\(id.uuidString)","title":"주민번호","value":"900101-1234567","isFavorite":true,
          "clipCount":7,"category":"개인","autoDetectedType":"주민등록번호","contentType":"hologram"}]
        """
        let memos = try JSONDecoder().decode([Memo].self, from: Data(json.utf8))
        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos[0].id, id)
        XCTAssertTrue(memos[0].isFavorite, "즐겨찾기가 남아야 한다(예전에는 옛 형식으로 떨어져 사라졌다)")
        XCTAssertEqual(memos[0].clipCount, 7)
        XCTAssertNil(memos[0].autoDetectedType)
        XCTAssertEqual(memos[0].contentType, .text)
    }

    func testQuickNoteWithUnknownContentTypeStillDecodes() throws {
        let json = #"[{"text":"메모","contentType":"hologram","createdAt":0}]"#
        let notes = try JSONDecoder().decode([QuickNote].self, from: Data(json.utf8))
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].text, "메모")
        XCTAssertEqual(notes[0].contentType, .text)
    }

    // MARK: - 한 칸이 깨져도 다른 칸은 온전히 (MemoStore.load)

    func testOneBrokenMemoDoesNotStripTheOthers() throws {
        guard let url = try MemoStore.fileURL(type: .memo), !url.path.isEmpty else {
            throw XCTSkip("App Group 컨테이너가 없다")
        }
        let folder = url.deletingLastPathComponent()
        let copiesBefore = Set(corruptCopies(in: folder))
        let flagBefore = MemoStore.hasDetectedCorruption
        defer {
            try? MemoStore.shared.save(memos: [], type: .memo)
            for name in Set(corruptCopies(in: folder)).subtracting(copiesBefore) {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
            }
        }

        let good = UUID(), broken = UUID()
        let json = """
        [{"id":"\(good.uuidString)","title":"멀쩡","value":"a","isChecked":false,"isFavorite":true,"clipCount":3},
         {"id":"\(broken.uuidString)","title":"깨짐","value":"b","isChecked":false,"clipCount":"셋"}]
        """
        try Data(json.utf8).write(to: url, options: .atomic)

        let memos = try MemoStore.shared.load(type: .memo)
        XCTAssertEqual(memos.map(\.id), [good, broken], "순서와 개수가 그대로")
        XCTAssertTrue(memos[0].isFavorite, "멀쩡한 칸은 즐겨찾기 · 쓴 횟수를 잃지 않는다")
        XCTAssertEqual(memos[0].clipCount, 3)
        XCTAssertEqual(memos[1].title, "깨짐", "못 푼 칸도 제목 · 본문은 건진다")

        let newCopies = Set(corruptCopies(in: folder)).subtracting(copiesBefore)
        XCTAssertEqual(newCopies.count, 1, "다음 저장이 굳히기 전에 원본 사본을 하나 남긴다")
        XCTAssertEqual(MemoStore.hasDetectedCorruption, flagBefore, "목록은 서므로 복구 안내는 세우지 않는다")

        // 같은 파일을 다시 읽어도(캐시가 비어도) 사본이 늘지 않는다.
        try Data(json.utf8).write(to: url, options: .atomic)
        _ = try MemoStore.shared.load(type: .memo)
        XCTAssertEqual(Set(corruptCopies(in: folder)).subtracting(copiesBefore).count, 1)
        XCTAssertTrue(MemoStore.storedFileHasContent(type: .memo))
    }

    // MARK: - 건진 단축어가 다른 기기의 온전한 사본을 덮지 않는다 (MemoStore.SalvageHold)

    func testSalvagedMemoKeepsItsEditTimeAndIsHeldFromSync() throws {
        guard let url = try MemoStore.fileURL(type: .memo), !url.path.isEmpty else {
            throw XCTSkip("App Group 컨테이너가 없다")
        }
        let folder = url.deletingLastPathComponent()
        let copiesBefore = Set(corruptCopies(in: folder))
        let originalStore = MemoStore.SalvageHold.store
        MemoStore.SalvageHold.store = defaults
        defer {
            MemoStore.SalvageHold.store = originalStore
            try? MemoStore.shared.save(memos: [], type: .memo)
            for name in Set(corruptCopies(in: folder)).subtracting(copiesBefore) {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
            }
        }

        let good = UUID(), dated = UUID(), undated = UUID()
        let edited = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let json = """
        [{"id":"\(good.uuidString)","title":"멀쩡","value":"a","isChecked":false},
         {"id":"\(dated.uuidString)","title":"깨짐","value":"b","isChecked":false,"clipCount":"셋",
          "lastEdited":\(edited.timeIntervalSinceReferenceDate),"isFavorite":true},
         {"id":"\(undated.uuidString)","title":"깨짐2","value":"c","isChecked":false,"clipCount":"넷"}]
        """
        try Data(json.utf8).write(to: url, options: .atomic)

        let memos = try MemoStore.shared.load(type: .memo)
        XCTAssertEqual(memos.map(\.id), [good, dated, undated])
        XCTAssertEqual(memos[1].lastEdited, edited, "건진 칸은 원래 고친 시각을 지킨다(지금 시각이면 동기화에서 이긴다)")
        XCTAssertEqual(memos[2].lastEdited, .distantPast, "고친 시각을 못 읽으면 어떤 사본과 겨뤄도 지는 옛날")
        XCTAssertEqual(MemoStore.SalvageHold.heldIDs(in: memos), [dated, undated], "멀쩡한 칸은 붙잡지 않는다")

        // 파일이 다시 저장돼 다음 읽기에서 멀쩡히 풀려도 붙잡은 것은 남는다.
        try MemoStore.shared.save(memos: memos, type: .memo)
        let reloaded = try MemoStore.shared.load(type: .memo)
        XCTAssertEqual(MemoStore.SalvageHold.heldIDs(in: reloaded), [dated, undated])

        // 사용자가 고치면 풀린다(그 편집은 사용자 뜻이라 올라간다).
        var touched = reloaded
        touched[1].lastEdited = Date()
        XCTAssertEqual(MemoStore.SalvageHold.heldIDs(in: touched), [undated])
    }

    func testMergeLetsRemoteReplaceHeldSalvageAndNeverReuploadsIt() {
        let id = UUID()
        var degraded = Memo(id: id, title: "깨짐", value: "b")
        degraded.lastEdited = Date()   // 혹시 더 최신이어도
        var intact = Memo(id: id, title: "깨짐", value: "b", isFavorite: true, category: "업무", isSecure: true)
        intact.lastEdited = Date(timeIntervalSinceNow: -3600)
        let remote = [RemoteMemo(id: id, memo: intact, lastEdited: intact.lastEdited)]

        let held = MemoSyncCore.merge(local: [degraded], localTombstones: [:], remote: remote, heldBack: [id])
        XCTAssertTrue(held.toReupload.isEmpty, "건진 사본은 다시 올리지 않는다")
        XCTAssertEqual(held.memos.first?.isFavorite, true, "온전한 원격 사본이 건진 사본을 대신한다")
        XCTAssertEqual(held.memos.first?.category, "업무")

        let deleted = MemoSyncCore.merge(local: [degraded], localTombstones: [:],
                                         remote: [RemoteMemo(id: id, memo: nil, lastEdited: .distantPast)],
                                         heldBack: [id])
        XCTAssertTrue(deleted.memos.isEmpty, "건진 사본은 원격 삭제를 되살리지 않는다")
        XCTAssertTrue(deleted.toReupload.isEmpty)

        let old = Memo(from: OldMemo(title: "옛", value: "값"))
        XCTAssertEqual(old.lastEdited, .distantPast, "옛 형식으로 건진 사본은 지금 시각을 받지 않는다")
    }

    private func corruptCopies(in folder: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
            .filter { $0.hasPrefix("\(StorageFile.memos).corrupt-") }
    }

    // MARK: - 사전 열쇠가 겹쳐도 죽지 않는다

    func testCategoryShadowWithCaseDuplicateKeysDoesNotTrap() {
        guard let group = AppGroup.defaults else { return }
        let saved = group.data(forKey: CategoryItemStore.shadowKey)
        defer { group.set(saved, forKey: CategoryItemStore.shadowKey) }

        let id = UUID()
        let raw = [id.uuidString.uppercased(): "a", id.uuidString.lowercased(): "b"]
        group.set(try? JSONEncoder().encode(raw), forKey: CategoryItemStore.shadowKey)
        let shadow = CategoryItemStore.loadShadow()
        XCTAssertEqual(shadow.count, 1)
        XCTAssertNotNil(shadow[id])
    }

    // MARK: - 찾은 자리가 글자 묶음 안쪽이어도 죽지 않는다

    func testTypedShortcutPlaceAroundComposedCharacters() {
        XCTAssertEqual(TypedShortcut.place(of: "카드", in: "🇰🇷카드번호"), .inside)
        XCTAssertEqual(TypedShortcut.place(of: "카드", in: "👨‍👩‍👧 카드"), .wordStart)
        XCTAssertEqual(TypedShortcut.place(of: "é", in: "cafe\u{301}"), .inside)
        XCTAssertEqual(TypedShortcut.place(of: "app", in: "Apple"), .start)
    }

    // MARK: - OCR 결과는 한 번만

    func testOCRCompletionIsDeliveredOnceOnMain() {
        let delivered = expectation(description: "한 번 넘긴다")
        delivered.expectedFulfillmentCount = 1
        delivered.assertForOverFulfill = true
        let finish = OCRCompletionOnce<[String]> { texts in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(texts, ["첫 결과"])
            delivered.fulfill()
        }
        DispatchQueue.global().async {
            finish(["첫 결과"])
            finish([])
        }
        wait(for: [delivered], timeout: 2)
        // 두 번째 결과가 뒤늦게 메인에 오지 않는지 한 박자 더 본다.
        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { settle.fulfill() }
        wait(for: [settle], timeout: 1)
    }
}
