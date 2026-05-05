//
//  MemoStoreUsageAndImageTests.swift
//  ClipKeyboardTests
//
//  MemoStoreTests에서 다루지 않는 영역:
//  - incrementClipCount: 사용 카운트 증가 + lastUsedAt 갱신
//  - 이미지 저장/로드/삭제 (App Group `Images/` 폴더)
//  - 즐겨찾기 메모 보유 체크
//

import XCTest
#if os(iOS)
import UIKit
#endif
@testable import ClipKeyboard

final class MemoStoreUsageAndImageTests: XCTestCase {

    var sut: MemoStore!
    var seedMemo: Memo!

    override func setUp() {
        super.setUp()
        sut = MemoStore.shared
        seedMemo = Memo(title: "사용카운트 테스트", value: "test value")
        try? sut.save(memos: [seedMemo], type: .memo)
    }

    override func tearDown() {
        try? sut.save(memos: [], type: .memo)
        seedMemo = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Clip count

    func testIncrementClipCount_IncrementsBy1() throws {
        try sut.incrementClipCount(for: seedMemo.id)

        let memos = try sut.load(type: .memo)
        XCTAssertEqual(memos[0].clipCount, 1)
        XCTAssertNotNil(memos[0].lastUsedAt)
    }

    func testIncrementClipCount_Repeated_AccumulatesCount() throws {
        try sut.incrementClipCount(for: seedMemo.id)
        try sut.incrementClipCount(for: seedMemo.id)
        try sut.incrementClipCount(for: seedMemo.id)

        let memos = try sut.load(type: .memo)
        XCTAssertEqual(memos[0].clipCount, 3)
    }

    func testIncrementClipCount_NonexistentId_NoThrow() {
        // 존재하지 않는 ID에 대해서는 조용히 통과해야 함 (UI에서 race condition 발생 가능)
        XCTAssertNoThrow(try sut.incrementClipCount(for: UUID()))
    }

    func testIncrementClipCount_UpdatesLastUsedAt() throws {
        let before = Date()
        try sut.incrementClipCount(for: seedMemo.id)
        let after = Date()

        let memos = try sut.load(type: .memo)
        let lastUsed = try XCTUnwrap(memos[0].lastUsedAt)
        XCTAssertGreaterThanOrEqual(lastUsed.timeIntervalSince1970, before.timeIntervalSince1970 - 1)
        XCTAssertLessThanOrEqual(lastUsed.timeIntervalSince1970, after.timeIntervalSince1970 + 1)
    }

    // MARK: - Favorite

    func testHasFavoriteMemo_NoFavorites_False() throws {
        try sut.save(memos: [seedMemo], type: .memo)
        XCTAssertFalse(sut.hasFavoriteMemo())
    }

    func testHasFavoriteMemo_WithFavorite_True() throws {
        var favorite = Memo(title: "즐겨찾기", value: "값")
        favorite.isFavorite = true
        try sut.save(memos: [seedMemo, favorite], type: .memo)
        XCTAssertTrue(sut.hasFavoriteMemo())
    }

    // MARK: - Images (iOS only)

    #if os(iOS)
    private func makeTestImage(color: UIColor = .red, size: CGSize = CGSize(width: 50, height: 50)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    func testSaveImage_AndLoad_RoundTrip() throws {
        let image = makeTestImage()
        let fileName = "xctest_image_\(UUID().uuidString).png"

        try sut.saveImage(image, fileName: fileName)
        defer { try? sut.deleteImage(fileName: fileName) }

        // size는 디바이스 scale(2x/3x)로 PNG가 저장된 후 로드 시 1x로 해석되어 달라지므로
        // round-trip은 데이터가 디스크에 존재하고 디코딩 가능한지로 검증한다.
        let loaded = sut.loadImage(fileName: fileName)
        XCTAssertNotNil(loaded)
        XCTAssertGreaterThan(loaded?.size.width ?? 0, 0)
        XCTAssertGreaterThan(loaded?.size.height ?? 0, 0)
    }

    func testLoadImage_NonexistentFile_ReturnsNil() {
        let loaded = sut.loadImage(fileName: "_xctest_does_not_exist_\(UUID().uuidString).png")
        XCTAssertNil(loaded)
    }

    func testDeleteImage_RemovesFile() throws {
        let image = makeTestImage()
        let fileName = "xctest_delete_\(UUID().uuidString).png"

        try sut.saveImage(image, fileName: fileName)
        XCTAssertNotNil(sut.loadImage(fileName: fileName))

        try sut.deleteImage(fileName: fileName)
        XCTAssertNil(sut.loadImage(fileName: fileName))
    }

    func testDeleteImage_NonexistentFile_NoThrow() {
        // 이미 없는 파일을 삭제해도 에러를 던지지 않아야 함 (UI 정리 시 idempotent)
        XCTAssertNoThrow(try sut.deleteImage(fileName: "_xctest_phantom.png"))
    }

    func testSaveImage_OverwritesExisting() throws {
        let fileName = "xctest_overwrite_\(UUID().uuidString).png"
        defer { try? sut.deleteImage(fileName: fileName) }

        let small = makeTestImage(size: CGSize(width: 10, height: 10))
        try sut.saveImage(small, fileName: fileName)
        let smallLoaded = try XCTUnwrap(sut.loadImage(fileName: fileName))
        let smallWidth = smallLoaded.size.width

        let large = makeTestImage(size: CGSize(width: 100, height: 100))
        try sut.saveImage(large, fileName: fileName)
        let largeLoaded = try XCTUnwrap(sut.loadImage(fileName: fileName))
        // 절대 사이즈는 디바이스 scale 의존이라, 큰 이미지가 작은 이미지보다 큰지로 비교
        XCTAssertGreaterThan(largeLoaded.size.width, smallWidth)
    }
    #endif
}
