//
//  VideoStoreTests.swift
//  ClipKeyboardTests
//
//  동영상 붙이기의 줄이기 경로. 진짜 동영상을 만들어 `VideoStore.prepareAttachment` 를 지나게 한다.
//  읽을 수 없는 파일은 던지되 죽지 않아야 한다.
//

import XCTest
import AVFoundation
@testable import ClipKeyboard

final class VideoStoreTests: XCTestCase {

    func test_짧은_동영상은_mp4로_줄여_App_Group으로_옮긴다() async throws {
        let source = try await makeMovie(seconds: 2)
        defer { try? FileManager.default.removeItem(at: source) }

        let prepared = try await VideoStore.prepareAttachment(from: source)
        XCTAssertEqual(prepared.pathExtension, "mp4")
        let size = try XCTUnwrap(VideoStore.fileSize(at: prepared))
        XCTAssertGreaterThan(size, 0)
        XCTAssertLessThanOrEqual(size, VideoStore.maxStoredBytes)
        XCTAssertFalse(VideoStore.isStored(prepared), "저장하기 전에는 임시 폴더에 있다")

        let name = try VideoStore.adopt(prepared)
        let stored = try XCTUnwrap(VideoStore.url(fileName: name))
        defer { try? FileManager.default.removeItem(at: stored) }
        XCTAssertTrue(VideoStore.isStored(stored))
        let thumbnail = await VideoStore.thumbnail(for: stored, maxPixel: 100)
        XCTAssertNotNil(thumbnail)
    }

    func test_동영상이_아닌_파일은_읽을_수_없다고_던진다() async throws {
        let junk = FileManager.default.temporaryDirectory.appendingPathComponent("junk-\(UUID().uuidString).mov")
        try Data(repeating: 1, count: 2048).write(to: junk)
        defer { try? FileManager.default.removeItem(at: junk) }
        do {
            _ = try await VideoStore.prepareAttachment(from: junk)
            XCTFail("읽을 수 없는 파일을 붙이면 안 된다")
        } catch let failure as VideoStore.Failure {
            XCTAssertEqual(failure, .unreadable)
            XCTAssertNotNil(failure.errorDescription)
        }
    }

    // MARK: - Helpers

    /// 단색 화면 몇 초짜리 mov 를 만든다.
    private func makeMovie(seconds: Int) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("source-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let width = 320, height = 240
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 10
        for frame in 0..<(seconds * Int(fps)) {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
            guard let buffer else { throw VideoStore.Failure.exportFailed }
            CVPixelBufferLockBaseAddress(buffer, [])
            if let base = CVPixelBufferGetBaseAddress(buffer) {
                memset(base, Int32(frame * 10 % 255), CVPixelBufferGetDataSize(buffer))
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps))
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? VideoStore.Failure.exportFailed }
        return url
    }
}
