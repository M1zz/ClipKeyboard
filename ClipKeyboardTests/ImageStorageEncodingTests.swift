//
//  ImageStorageEncodingTests.swift
//  ClipKeyboardTests
//
//  단축어에 붙이는 그림은 줄여서 저장한다. 원본 PNG(1200만 화소면 15~25MB)가 백업 · 동기화 ·
//  키보드 붙여넣기까지 따라다니던 것을 막는다.
//

import XCTest
import UIKit
@testable import ClipKeyboard

final class ImageStorageEncodingTests: XCTestCase {

    private func image(width: CGFloat, height: CGFloat, opaque: Bool) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            UIColor.systemTeal.withAlphaComponent(opaque ? 1 : 0.5).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: width / 2))
        }
    }

    func test_큰_사진은_긴_변_2048_JPEG() throws {
        let photo = image(width: 4000, height: 3000, opaque: true)
        let encoded = try XCTUnwrap(MemoStore.storageEncoding(for: photo))
        XCTAssertEqual(encoded.fileExtension, "jpg")
        let decoded = try XCTUnwrap(UIImage(data: encoded.data))
        XCTAssertEqual(max(decoded.size.width * decoded.scale, decoded.size.height * decoded.scale), 2048, accuracy: 1)
        XCTAssertLessThan(encoded.data.count, 2_000_000, "원본 PNG 의 수십 분의 일이어야 한다")
    }

    func test_투명한_그림은_PNG_로_둔다() throws {
        let sticker = image(width: 600, height: 600, opaque: false)
        let encoded = try XCTUnwrap(MemoStore.storageEncoding(for: sticker))
        XCTAssertEqual(encoded.fileExtension, "png", "JPEG 는 투명을 검게 메운다")
    }

    func test_작은_그림은_키우지_않는다() throws {
        let small = image(width: 300, height: 200, opaque: true)
        let encoded = try XCTUnwrap(MemoStore.storageEncoding(for: small))
        let decoded = try XCTUnwrap(UIImage(data: encoded.data))
        XCTAssertEqual(decoded.size.width * decoded.scale, 300, accuracy: 1)
    }

    func test_저장한_이름의_확장자로_붙여넣기_형식이_정해진다() throws {
        let fileName = try MemoStore.shared.saveImage(image(width: 3000, height: 2000, opaque: true))
        defer {
            if let url = MemoStore.shared.imageURL(fileName: fileName) { try? FileManager.default.removeItem(at: url) }
        }
        XCTAssertTrue(fileName.hasSuffix(".jpg"))
        XCTAssertEqual(MemoStore.shared.imagePasteboardType(fileName: fileName), "public.jpeg")
        XCTAssertNotNil(MemoStore.shared.loadThumbnail(fileName: fileName, maxPixel: 400), "키보드 썸네일도 그대로 읽힌다")
    }
}
