//
//  DataCorruptionDetectionTests.swift
//  ClipKeyboardTests
//
//  "메모 0개"와 "파일이 깨짐"을 구분하는 규칙을 고정한다.
//
//  이 구분이 무너지는 두 방향 모두 사고다:
//   · 손상을 빈 배열로 취급 → 사용자는 데이터가 날아간 줄 알고, 이후 저장이 원본을 덮는다.
//   · 정상적인 빈 목록을 손상으로 취급 → 멀쩡한 사용자에게 매번 경고가 뜬다.
//

import XCTest
@testable import ClipKeyboard

final class DataCorruptionDetectionTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = AppGroup.defaults
        MemoStore.clearCorruptionFlag()
    }

    override func tearDown() {
        MemoStore.clearCorruptionFlag()
        super.tearDown()
    }

    // MARK: - 플래그 계약

    func testNoCorruptionFlagByDefault() {
        XCTAssertFalse(MemoStore.hasDetectedCorruption)
    }

    func testFlagIsDetectedOnceSet() {
        defaults.set(Date().timeIntervalSince1970, forKey: MemoStore.corruptionFlagKey)

        XCTAssertTrue(MemoStore.hasDetectedCorruption)
    }

    /// 확인 버튼은 플래그만 지운다 - 격리 사본 정보까지 지워도 되지만
    /// 플래그가 남아 매번 안내가 뜨는 일은 없어야 한다.
    func testClearingFlagStopsPrompt() {
        defaults.set(Date().timeIntervalSince1970, forKey: MemoStore.corruptionFlagKey)
        defaults.set("memos.data.corrupt-123", forKey: MemoStore.corruptionFileKey)

        MemoStore.clearCorruptionFlag()

        XCTAssertFalse(MemoStore.hasDetectedCorruption)
        XCTAssertNil(defaults.string(forKey: MemoStore.corruptionFileKey))
    }

    // MARK: - 빈 배열 vs 손상

    /// ⚠️ 핵심: 정상적으로 저장된 **빈 배열**은 손상이 아니다.
    /// `[]` 는 2바이트짜리 유효한 JSON이라, "데이터가 있는데 메모가 0개"라는 이유만으로
    /// 손상 판정을 하면 메모를 전부 지운 사용자에게 매번 경고가 뜬다.
    func testEmptyArrayIsValidNotCorrupt() throws {
        let data = try XCTUnwrap("[]".data(using: .utf8))
        let decoded = try JSONDecoder().decode([Memo].self, from: data)

        XCTAssertTrue(decoded.isEmpty)
        // 디코딩이 성공했으므로 손상 경로를 타지 않는다.
    }

    /// 깨진 바이트열은 디코딩이 실패해야 한다(= 손상 경로 진입).
    func testGarbageDataFailsToDecode() throws {
        let data = try XCTUnwrap("{not json at all".data(using: .utf8))

        XCTAssertThrowsError(try JSONDecoder().decode([Memo].self, from: data))
    }

    /// 잘린 파일(전송·저장 중 중단)도 실패해야 한다.
    func testTruncatedDataFailsToDecode() throws {
        let full = try JSONEncoder().encode([Memo(title: "a", value: "b")])
        let truncated = full.prefix(full.count / 2)

        XCTAssertThrowsError(try JSONDecoder().decode([Memo].self, from: Data(truncated)))
    }

    /// 반대 방향 보호: 구버전 JSON은 **손상이 아니다**.
    /// 관용 디코더가 이걸 살려내므로 손상 경로로 새면 안 된다.
    func testLegacyFormatIsNotTreatedAsCorrupt() throws {
        let data = try XCTUnwrap(#"[{"title":"구버전","value":"v"}]"#.data(using: .utf8))
        let decoded = try JSONDecoder().decode([Memo].self, from: data)

        XCTAssertEqual(decoded.count, 1)
    }

    // MARK: - 없음 vs 못 읽음

    /// 파일이 없으면 nil(새 사용자), 있는데 못 읽으면 던진다. 못 읽은 것을 빈 목록으로 돌려주면
    /// 다음 저장이 멀쩡한 메모 파일을 덮는다.
    func testUnreadableFileThrowsInsteadOfLookingEmpty() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let missing = dir.appendingPathComponent("missing.data")
        XCTAssertNil(try Data.readIfPresent(missing), "없는 파일은 비어 있는 것이다")

        let locked = dir.appendingPathComponent("memos.data")
        try Data("[]".utf8).write(to: locked)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.path) }
        XCTAssertThrowsError(try Data.readIfPresent(locked), "있는데 못 읽은 파일을 빈 것으로 치면 안 된다")
    }

    // MARK: - 목록 파일(빠른 메모 · 임시 저장)

    private struct Row: Codable, Equatable { let n: Int }

    private func scratchFile() throws -> (AppGroupListFile<Row>, URL) {
        let name = "test-\(UUID().uuidString).data"
        let container = try XCTUnwrap(FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier))
        return (AppGroupListFile<Row>(fileName: name), container.appendingPathComponent(name))
    }

    func testListFileReadsMissingAsEmptyAndModifies() throws {
        let (file, url) = try scratchFile()
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(try file.read(), [], "없는 파일은 빈 목록")
        try file.modify { $0.append(Row(n: 1)) }
        try file.modify { $0.append(Row(n: 2)) }
        XCTAssertEqual(try file.read(), [Row(n: 1), Row(n: 2)])
    }

    /// 못 읽은 파일에는 쓰지 않는다. 빈 목록에 한 줄을 더해 쓰면 보관함이 통째로 덮인다.
    func testListFileRefusesToModifyUnreadableFile() throws {
        let (file, url) = try scratchFile()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
            try? FileManager.default.removeItem(at: url)
        }
        try file.write([Row(n: 1), Row(n: 2), Row(n: 3)])
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)
        XCTAssertThrowsError(try file.modify { $0.append(Row(n: 4)) })
        XCTAssertEqual(file.readForDisplay(), [], "화면에는 빈 목록으로 보일 뿐이다")
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
        XCTAssertEqual(try file.read().count, 3, "원본은 그대로다")
    }

    /// 깨진 파일은 사본을 남기고 빈 목록으로 시작한다.
    func testListFileKeepsCopyOfCorruptFile() throws {
        let (file, url) = try scratchFile()
        let copy = url.appendingPathExtension("unreadable")
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: copy)
        }
        try Data("not json".utf8).write(to: url)
        XCTAssertEqual(try file.read(), [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: copy.path), "깨진 원본의 사본이 남는다")
    }

    // MARK: - 빈칸 값 장부

    /// 풀지 못한 빈칸 값 위에 하나를 더해 쓰면 그 빈칸의 값이 통째로 사라진다. 쓰지 않아야 한다.
    func testPlaceholderBookDoesNotOverwriteUndecodableValues() throws {
        let token = "{test-\(UUID().uuidString)}"
        let key = PlaceholderValueBook.key(for: token)
        defer { PlaceholderValueBook.remove(token) }
        let garbage = Data("not json".utf8)
        defaults.set(garbage, forKey: key)

        XCTAssertNil(PlaceholderValueBook.stored(token), "풀지 못한 것은 빈 목록이 아니다")
        XCTAssertFalse(PlaceholderValueBook.add("서울", for: token, sourceMemoId: UUID(), sourceMemoTitle: "t"))
        XCTAssertEqual(defaults.data(forKey: key), garbage, "원본은 그대로다")
    }

    /// 앱(MemoStore)이 적은 값을 장부가 그대로 읽고, 같은 값은 맨 앞으로 끌어올린다.
    func testPlaceholderBookIsSharedAndDeduplicates() throws {
        let token = "{test-\(UUID().uuidString)}"
        defer { PlaceholderValueBook.remove(token) }
        let memo = UUID()
        MemoStore.shared.addPlaceholderValue("A", for: token, sourceMemoId: memo, sourceMemoTitle: "t")
        MemoStore.shared.addPlaceholderValue("B", for: token, sourceMemoId: memo, sourceMemoTitle: "t")
        XCTAssertTrue(PlaceholderValueBook.add("A", for: token, sourceMemoId: memo, sourceMemoTitle: "t"))
        XCTAssertEqual(PlaceholderValueBook.values(token).map(\.value), ["A", "B"])
        XCTAssertTrue(PlaceholderValueBook.storedTokens().contains(token))
    }
}
