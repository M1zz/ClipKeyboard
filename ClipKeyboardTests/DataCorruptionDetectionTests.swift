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
        defaults = UserDefaults(suiteName: AppGroup.identifier)
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
}
