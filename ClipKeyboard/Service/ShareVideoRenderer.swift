//
//  ShareVideoRenderer.swift
//  ClipKeyboard
//
//  아낀 시간을 **짧은 세로 영상**으로 뽑는다. 인스타그램 스토리에 그대로 올라간다.
//
//  왜 이미지가 아니라 영상인가
//  ⚠️ 자랑은 **숫자가 아니라 숫자가 올라가는 장면**에서 생긴다. "1시간 24분"이라고
//     적힌 그림은 스크롤에 묻히지만, 0에서 그 숫자까지 굴러 올라가는 3초는 눈이 따라간다.
//     스토리에 올릴 것을 만드는 일이므로, 멈춘 그림보다 움직이는 쪽이 맞다.
//
//  ⚠️ 세로 9:16(1080×1920)로 고정한다. 스토리·릴스가 전부 이 비율이고, 다른 비율로
//     주면 사용자가 올릴 때 잘라야 한다. 잘라야 하는 순간 대부분 안 올린다.
//
//  ⚠️ 내용은 **숫자와 앱 이름뿐이다.** 문구 제목도, 내용도 들어가지 않는다.
//     이건 남에게 보여주려고 만드는 파일이라 실수로 새어나갈 여지를 아예 없앤다.
//     (영수증은 제목까지는 넣지만, 영상은 그마저도 뺀다 - 스토리는 더 넓게 퍼진다)
//
//  ⚠️ 소리는 없다. 스토리는 대개 음소거로 넘겨 본다.
//

import Foundation
#if canImport(UIKit)
import AVFoundation
import SwiftUI
import UIKit

@MainActor
enum ShareVideoRenderer {

    /// 스토리 규격.
    static let size = CGSize(width: 1080, height: 1920)
    static let fps: Int = 30
    /// 길이(초). 3초보다 짧으면 다 읽기 전에 끝나고, 길면 스토리에서 넘겨 버린다.
    static let duration: Double = 3.4

    enum RenderError: Error {
        case writerUnavailable
        case frameFailed
    }

    /// 영상 한 편을 만들어 파일 URL을 돌려준다.
    ///
    /// - Parameters:
    ///   - totalSeconds: 지금까지 아낀 시간(초).
    ///   - totalUses: 다시 치지 않은 횟수.
    ///
    /// ⚠️ 임시 폴더에 쓴다. 공유 시트가 읽어 간 뒤 시스템이 정리한다 - 사용자의
    ///    저장 공간에 우리 파일을 남기지 않는다.
    static func render(totalSeconds: Double, totalUses: Int) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipKeyboard-\(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: url)

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else {
            throw RenderError.writerUnavailable
        }
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameCount = Int(duration * Double(fps))
        for index in 0..<frameCount {
            let progress = Double(index) / Double(max(1, frameCount - 1))
            let image = frame(progress: progress, totalSeconds: totalSeconds, totalUses: totalUses)
            guard let buffer = pixelBuffer(from: image, pool: adaptor.pixelBufferPool) else {
                throw RenderError.frameFailed
            }
            // 입력이 받을 준비가 될 때까지 기다린다. 안 기다리고 밀어 넣으면 조용히 버려진다.
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 3_000_000)
            }
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(index),
                                                               timescale: CMTimeScale(fps)))
        }

        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw RenderError.frameFailed }
        return url
    }

    // MARK: - 한 장면

    /// 숫자가 굴러 올라가는 구간의 비율.
    ///
    /// ⚠️ 끝까지 굴리지 않는다. 마지막 30%는 **완성된 숫자가 그대로 멈춰 있어야** 한다.
    ///    스토리는 넘기면서 보는 것이라, 멈춰 있는 구간이 없으면 숫자를 못 읽는다.
    private static let countUpPortion = 0.7

    private static func frame(progress: Double, totalSeconds: Double, totalUses: Int) -> UIImage {
        let eased = min(1, progress / countUpPortion)
        // 처음엔 빠르게, 끝에서 천천히 - 숫자가 자리를 잡는 느낌이 난다.
        let curve = 1 - pow(1 - eased, 3)
        let shownSeconds = totalSeconds * curve
        let shownUses = Int((Double(totalUses) * curve).rounded())

        let view = ShareVideoFrame(seconds: shownSeconds,
                                   uses: shownUses,
                                   settled: eased >= 1)
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.uiImage ?? UIImage()
    }

    private static func pixelBuffer(from image: UIImage, pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        guard let cg = image.cgImage else { return nil }
        var buffer: CVPixelBuffer?
        if let pool {
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        } else {
            CVPixelBufferCreate(nil, cg.width, cg.height, kCVPixelFormatType_32ARGB, nil, &buffer)
        }
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: CVPixelBufferGetWidth(buffer),
            height: CVPixelBufferGetHeight(buffer),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return nil }
        context.draw(cg, in: CGRect(origin: .zero,
                                    size: CGSize(width: CVPixelBufferGetWidth(buffer),
                                                 height: CVPixelBufferGetHeight(buffer))))
        return buffer
    }
}

// MARK: - 장면 한 장

/// 영상의 한 프레임. 세로 스토리 한 장이라고 보면 된다.
///
/// ⚠️ 테마를 따르지 않고 **밝은 브랜드 화면 하나로 고정**한다. 이 그림은 남의 스토리에
///    올라가는 것이라, 만든 사람이 다크 모드였다는 이유로 어두운 그림이 나가면 안 된다.
struct ShareVideoFrame: View {
    let seconds: Double
    let uses: Int
    /// 숫자가 다 굴러 제자리에 섰는가 - 이때만 아래 문구가 나타난다.
    let settled: Bool

    private let sand = Color(red: 0xEE/255, green: 0xD2/255, blue: 0xA7/255)
    private let deep = Color(red: 0x0E/255, green: 0x5A/255, blue: 0x4C/255)
    private let ink = Color(red: 0x16/255, green: 0x21/255, blue: 0x1D/255)

    var body: some View {
        ZStack {
            sand.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Image(systemName: AppSymbol.clockBadgeCheckmarkFill)
                    .font(.system(size: 200, weight: .light))
                    .foregroundColor(.white)
                    .frame(width: 320, height: 320)

                Text(NSLocalizedString("다시 치지 않아서 아낀 시간", comment: "Share video: caption above the number"))
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundColor(ink.opacity(0.75))
                    .padding(.top, 40)

                Text(RefundReceipt.durationText(seconds: seconds))
                    .font(.system(size: 150, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundColor(deep)
                    .padding(.horizontal, 60)
                    .padding(.top, 8)

                Text(String(format: NSLocalizedString("단축어 %d번으로", comment: "Share video: uses line"), uses))
                    .font(.system(size: 40, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(ink.opacity(0.6))
                    .padding(.top, 12)

                // 다 굴러간 뒤에만 나타난다 - 숫자와 같이 뜨면 눈이 둘로 갈린다.
                Text(verbatim: "ClipKeyboard")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundColor(deep)
                    .padding(.top, 70)
                    .opacity(settled ? 1 : 0)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 120)
        }
        .frame(width: ShareVideoRenderer.size.width, height: ShareVideoRenderer.size.height)
    }
}
#endif
