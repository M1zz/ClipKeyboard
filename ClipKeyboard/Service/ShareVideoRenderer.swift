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
        // ⚠️ **한 번만 묻는다.** 프레임마다 트레이트를 물으면 102장을 굽는 동안
        //    사용자가 화면을 뒤집었을 때 영상 중간에서 배경이 갈린다.
        let isDark = UITraitCollection.current.userInterfaceStyle == .dark

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
            let image = frame(progress: progress, totalSeconds: totalSeconds, totalUses: totalUses, isDark: isDark)
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

    private static func frame(progress: Double, totalSeconds: Double, totalUses: Int, isDark: Bool) -> UIImage {
        let eased = min(1, progress / countUpPortion)
        // 처음엔 빠르게, 끝에서 천천히 - 숫자가 자리를 잡는 느낌이 난다.
        let curve = 1 - pow(1 - eased, 3)
        let shownSeconds = totalSeconds * curve
        let shownUses = Int((Double(totalUses) * curve).rounded())

        let view = ShareVideoFrame(seconds: shownSeconds,
                                   uses: shownUses,
                                   settled: eased >= 1,
                                   isDark: isDark)
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
/// ⚠️ **바탕은 흰색(또는 다크의 검정)이다.** 예전에는 모래빛 베이지(#EED2A7) 한 장으로
///    고정돼 있었다. 그 색은 앱 어디에도 없어서 남의 스토리에 올라갔을 때 이 앱의
///    그림으로 안 읽혔고, 흰 시계 글리프를 얹으려니 바탕이 탁해야만 했다.
///
/// ⚠️ **다크 모드를 따른다.** 예전에는 일부러 안 따랐다 - 만든 사람이 다크였다는 이유로
///    어두운 그림이 나가면 안 된다고 봤다. 뒤집었다. 스토리는 대개 어두운 배경에서
///    넘겨 보고, 무엇보다 **자기 화면에서 본 그대로 나가는 쪽**이 놀랄 일이 없다.
///    (`isDark` 는 밖에서 넣어 준다 - 프레임마다 트레이트를 묻지 않기 위해서다)
///
/// ⚠️ 숫자는 **사용자가 고른 키컬러**로 칠한다(`AppAccent`). 앱에서 크게 보던 그 색이
///    그대로 나가야 자기 앱에서 나온 그림으로 읽힌다.
struct ShareVideoFrame: View {
    let seconds: Double
    let uses: Int
    /// 숫자가 다 굴러 제자리에 섰는가 - 이때만 아래 문구가 나타난다.
    let settled: Bool
    /// 어두운 화면으로 뽑을 것인가.
    var isDark: Bool = false

    /// 바탕 - 흰 종이, 또는 앱의 다크 바탕과 같은 검정.
    private var ground: Color {
        isDark ? Color(red: 0x0D/255, green: 0x0D/255, blue: 0x0E/255) : .white
    }
    /// 큰 숫자와 시계에 쓰는 키컬러. 앱에서 보던 그 색이다.
    private var accent: Color { AppAccent.current.accent(isDark: isDark) }
    /// 본문 글자.
    private var ink: Color {
        isDark ? Color(red: 0xF2/255, green: 0xF2/255, blue: 0xF4/255)
               : Color(red: 0x13/255, green: 0x13/255, blue: 0x15/255)
    }
    /// 곁들이는 글자.
    private var muted: Color {
        isDark ? Color(red: 0x9C/255, green: 0x9C/255, blue: 0xA3/255)
               : Color(red: 0x6B/255, green: 0x6B/255, blue: 0x72/255)
    }

    var body: some View {
        ZStack {
            ground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // ⚠️ 흰 바탕에 흰 글리프를 얹을 수는 없다(예전에는 베이지라 됐다).
                //    시계는 키컬러, 배지의 체크는 **연두**로 나눠 칠한다 - 체크는
                //    언제나 연두라는 규칙이 이 그림에도 걸린다(`Color.checkGreen`).
                //
                // ⚠️ 이 심볼의 팔레트 순서는 **직관과 반대다.** 첫 번째가 배지(체크),
                //    두 번째가 시계판이다. 반대로 넣었더니 초록 시계에 파란 배지가 나왔다
                //    (실제로 구워 보고 알았다). 순서를 바꾸기 전에 한 장 뽑아 볼 것.
                Image(systemName: AppSymbol.clockBadgeCheckmarkFill)
                    .font(.system(size: 200, weight: .light))
                    .foregroundStyle(Color.checkGreen(isDark: isDark), accent)
                    .frame(width: 320, height: 320)

                // ⚠️ "아낀 시간"이 아니라 "손으로 했다면"이다. 같은 숫자인데 주장하는 바가
                //    다르다. 앞의 것은 일어난 일을 말하고, 뒤의 것은 일어나지 않은 쪽을
                //    말한다. 우리가 아는 것은 뒤쪽뿐이다 - 손으로 한 세상은 존재한 적이
                //    없어서 잰 적도 없다. 스토리에 올라가 남이 보는 그림이라, 여기서
                //    사실인 척하면 그 거짓말이 가장 멀리 간다.
                Text(NSLocalizedString("이걸 손으로 했다면", comment: "Share video: caption above the number"))
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundColor(muted)
                    .padding(.top, 40)

                Text(RefundReceipt.durationText(seconds: seconds))
                    .font(.system(size: 150, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundColor(accent)
                    .padding(.horizontal, 60)
                    .padding(.top, 8)

                // ⚠️ **이 줄만 사실이다.** 위의 큰 숫자는 어림한 것이고, 이건 실제로
                //    일어나서 우리가 센 것이다. 그래서 어림값 뒤에 숨기지 않고 또렷하게 둔다.
                Text(String(format: NSLocalizedString("실제로는 단축어 %d번", comment: "Share video: uses line"), uses))
                    .font(.system(size: 44, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(muted)
                    .padding(.top, 18)

                // 다 굴러간 뒤에만 나타난다 - 숫자와 같이 뜨면 눈이 둘로 갈린다.
                Text(verbatim: "ClipKeyboard")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundColor(ink)
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
