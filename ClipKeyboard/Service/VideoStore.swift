//
//  VideoStore.swift
//  ClipKeyboard
//
//  단축어에 붙인 동영상 파일. App Group 의 `Videos/` 폴더 하나만 다룬다.
//  앱(가져오기 · 줄이기)과 키보드(클립보드에 얹기)가 같은 문을 쓴다.
//
//  사용자 요청(2026-11, 중국어): "啥时候能快捷发视频" (동영상도 빨리 보내고 싶다).
//
//  ⚠️ 키보드 익스텐션은 남의 입력칸에 동영상을 넣을 수 없다. 이미지 단축어처럼
//     **클립보드에 얹고 붙여넣게** 한다. 받는 앱이 붙여넣은 동영상을 받는지는 그 앱 몫이다.
//  ⚠️ 키보드 익스텐션의 메모리 한도는 앱의 몇십 분의 일이다. 그래서 저장할 때 줄이고
//     (`maxStoredBytes`), 키보드에서는 크기를 먼저 보고 넘치면 얹지 않는다(`keyboardCopyLimit`).
//     죽는 대신 "앱에서 복사해 주세요" 라고 말한다.
//  ⚠️ 동영상은 iCloud 동기화 · 백업에 싣지 않는다(한 편이 그림 수십 장 크기다). 다른 기기에서는
//     단축어만 보이고 누르면 "이 기기에 없어요" 라고 말한다.
//

#if os(iOS)
import AVFoundation
import UIKit
import UniformTypeIdentifiers

enum VideoStore {

    enum Failure: Error, LocalizedError {
        case noContainer
        case unreadable
        case tooLong
        case tooLarge
        case exportFailed

        /// 사용자에게 보일 말. 화면은 이 말을 그대로 토스트로 띄운다.
        var errorDescription: String? {
            switch self {
            case .noContainer, .exportFailed:
                return NSLocalizedString("동영상을 저장하지 못했어요. 다시 시도해 주세요",
                                         comment: "Video attach failed: generic")
            case .unreadable:
                return NSLocalizedString("이 동영상은 읽을 수 없어요",
                                         comment: "Video attach failed: cannot read the file")
            case .tooLong:
                return NSLocalizedString("동영상은 3분까지 붙일 수 있어요",
                                         comment: "Video attach failed: longer than 3 minutes")
            case .tooLarge:
                return NSLocalizedString("동영상이 너무 커요. 더 짧은 동영상을 골라 주세요",
                                         comment: "Video attach failed: still too large after compression")
            }
        }
    }

    // MARK: - 한도

    /// 붙일 수 있는 가장 긴 길이. 넘으면 줄이기 전에 거절한다(줄이는 데만 몇 분 걸린다).
    static let maxDuration: TimeInterval = 180
    /// 저장하는 파일의 가장 큰 크기. 줄여도 넘으면 거절한다.
    static let maxStoredBytes: Int64 = 20 * 1024 * 1024
    /// 키보드가 클립보드에 얹는 가장 큰 크기. 다른 기기 · 옛 판에서 들어온 큰 파일도 여기서 막는다.
    static let keyboardCopyLimit: Int64 = 25 * 1024 * 1024

    /// 줄이는 순서. 앞의 것이 한도를 넘으면 다음 것으로 다시 줄인다.
    private static let exportPresets = [
        AVAssetExportPreset1280x720,
        AVAssetExportPreset960x540,
        AVAssetExportPreset640x480,
    ]

    // MARK: - 자리

    /// App Group 안의 동영상 폴더.
    private static var directory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent("Videos")
    }

    /// 동영상 파일 자리. 없으면 nil.
    static func url(fileName: String) -> URL? {
        guard !fileName.isEmpty, let fileURL = directory?.appendingPathComponent(fileName),
              FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return fileURL
    }

    /// 파일 크기(바이트). 못 읽으면 nil.
    static func fileSize(at url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else { return nil }
        return size.int64Value
    }

    /// 파일 이름에서 클립보드용 타입을 고른다. 모르는 것은 mp4 로 본다(저장은 늘 mp4 다).
    static func pasteboardType(fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext), type.conforms(to: .movie) else {
            return UTType.mpeg4Movie.identifier
        }
        return type.identifier
    }

    // MARK: - 가져오기 (앱)

    /// 고른 동영상을 붙일 모양(mp4, 720p 이하, `maxStoredBytes` 이하)으로 줄여 **임시 폴더**에 둔다.
    ///
    /// 아직 App Group 으로 옮기지 않는다. 저장 화면을 닫고 나가면 임시 파일만 남고
    /// iOS 가 치운다. 저장할 때 `adopt(_:)` 가 옮긴다.
    static func prepareAttachment(from sourceURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        let duration: CMTime
        do {
            duration = try await asset.load(.duration)
        } catch {
            print("❌ [VideoStore.prepareAttachment] 길이를 읽지 못함: \(error)")
            throw Failure.unreadable
        }
        let seconds = duration.seconds
        guard seconds.isFinite, seconds > 0 else { throw Failure.unreadable }
        guard seconds <= maxDuration else { throw Failure.tooLong }

        for preset in exportPresets {
            let output = FileManager.default.temporaryDirectory
                .appendingPathComponent("video-\(UUID().uuidString).mp4")
            do {
                try await export(asset, preset: preset, to: output)
            } catch {
                print("⚠️ [VideoStore.prepareAttachment] \(preset) 줄이기 실패: \(error)")
                try? FileManager.default.removeItem(at: output)
                continue
            }
            if let size = fileSize(at: output), size <= maxStoredBytes {
                print("✅ [VideoStore.prepareAttachment] \(preset) · \(size) bytes · \(Int(seconds))s")
                return output
            }
            try? FileManager.default.removeItem(at: output)
        }
        throw Failure.tooLarge
    }

    private static func export(_ asset: AVAsset, preset: String, to output: URL) async throws {
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw Failure.exportFailed
        }
        session.shouldOptimizeForNetworkUse = true
        if #available(iOS 18.0, *) {
            try await session.export(to: output, as: .mp4)
        } else {
            session.outputURL = output
            session.outputFileType = .mp4
            await session.export()
            guard session.status == .completed else {
                throw session.error ?? Failure.exportFailed
            }
        }
    }

    /// 임시 파일을 App Group 으로 옮기고 파일 이름을 돌려준다.
    static func adopt(_ tempURL: URL) throws -> String {
        guard let directory else { throw Failure.noContainer }
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let fileName = "\(UUID().uuidString).mp4"
        let destination = directory.appendingPathComponent(fileName)
        do {
            try FileManager.default.moveItem(at: tempURL, to: destination)
        } catch {
            // 다른 볼륨이면 옮기기가 실패할 수 있다. 복사로 한 번 더.
            try FileManager.default.copyItem(at: tempURL, to: destination)
            try? FileManager.default.removeItem(at: tempURL)
        }
        return fileName
    }

    /// 이 파일이 App Group 안에 이미 있는 것인가(편집 중 그대로 둔 동영상).
    static func isStored(_ url: URL) -> Bool {
        guard let directory else { return false }
        return url.standardizedFileURL.deletingLastPathComponent().path
            == directory.standardizedFileURL.path
    }

    // MARK: - 미리보기 (앱)

    /// 첫 장면 그림. **앱에서만** 쓴다(키보드는 아이콘만 그린다).
    static func thumbnail(for url: URL, maxPixel: CGFloat) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixel, height: maxPixel)
        do {
            let (cgImage, _) = try await generator.image(at: .zero)
            return UIImage(cgImage: cgImage)
        } catch {
            print("⚠️ [VideoStore.thumbnail] 첫 장면을 만들지 못함: \(error)")
            return nil
        }
    }

    /// 길이(초). 못 읽으면 nil.
    static func duration(of url: URL) async -> TimeInterval? {
        guard let time = try? await AVURLAsset(url: url).load(.duration) else { return nil }
        let seconds = time.seconds
        return seconds.isFinite ? seconds : nil
    }

    // MARK: - 클립보드 (앱 · 키보드)

    enum CopyResult: Equatable {
        case copied
        case missing
        case tooLarge
        case failed
    }

    /// 동영상을 클립보드에 얹는다. **던지지 않는다.** 무엇이 안 됐는지는 돌려준다.
    ///
    /// ⚠️ 바이트는 메모리 매핑으로 읽는다(실제로 읽는 만큼만 올라온다). 크기를 먼저 보고
    ///    `limit` 을 넘으면 읽지도 않는다. 키보드에서 큰 파일을 통째로 올리면 iOS 가 키보드를
    ///    말없이 죽인다(`docs/postmortem/KEYBOARD_IMAGE_MEMORY.md` 와 같은 함정).
    static func copyToPasteboard(fileName: String, limit: Int64) -> CopyResult {
        guard let fileURL = url(fileName: fileName) else { return .missing }
        guard let size = fileSize(at: fileURL) else { return .failed }
        guard size <= limit else { return .tooLarge }
        do {
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            UIPasteboard.general.setData(data, forPasteboardType: pasteboardType(fileName: fileName))
            return .copied
        } catch {
            print("❌ [VideoStore.copyToPasteboard] 읽기 실패: \(error)")
            return .failed
        }
    }

    /// 결과를 사용자에게 할 말로. 복사됐으면 nil.
    static func message(for result: CopyResult) -> String? {
        switch result {
        case .copied:
            return nil
        case .missing:
            return NSLocalizedString("이 기기에 동영상 파일이 없어요. 동영상은 iCloud로 옮겨지지 않아요",
                                     comment: "Video copy failed: file not on this device (videos are not synced)")
        case .tooLarge:
            return NSLocalizedString("동영상이 커서 키보드에서는 복사할 수 없어요. 앱에서 눌러 복사해 주세요",
                                     comment: "Video copy failed: too large for the keyboard extension")
        case .failed:
            return NSLocalizedString("동영상을 복사하지 못했어요",
                                     comment: "Video copy failed: generic")
        }
    }
}
#endif
