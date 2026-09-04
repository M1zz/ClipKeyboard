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
//  무엇을 크게 띄우는가
//  ⚠️ 큰 자리에 서는 것은 **시간이 아니라 시간을 바꿔 말한 것**이다("5.2km", "커피 3잔").
//     시간은 크기가 안 잡히는 단위라, "1시간 24분"을 읽고 그게 큰지 작은지 알려면
//     머릿속에서 한 번 더 환산해야 한다. 넘겨 보는 3초 안에 그 환산은 안 일어난다.
//     시간과 횟수는 아래에 작게 남는다 - 사라지지는 않되 앞에 서지도 않는다.
//     (무엇으로 바꿔 말할지는 `TimeEquivalent`, 매번 다른 것이 뽑힌다)
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

/// ⚠️ **이 타입은 메인 액터가 아니다.** 예전에는 `@MainActor` 였고, 그래서 102장을
///    굽는 동안 메인 스레드가 통째로 잡혔다. 5.0.4 의 워치독 종료(0x8BADF00D,
///    `scene-update` · `Failed to terminate gracefully`)가 전부 이 자리였다.
///    자세한 것: `docs/postmortem/WATCHDOG_SHARE_VIDEO_5_0_4.md`
///
///    메인에서 해야만 하는 것은 `frame(...)` 하나다(`ImageRenderer` 가 메인 액터다).
///    나머지(픽셀 버퍼로 옮기기·인코더에 넣기)는 메인 밖에서 한다.
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
    ///   - equivalent: 큰 자리에 세울 바꿔 말하기. nil 이면 예전처럼 시간이 큰 자리에 선다
    ///     (아낀 시간이 너무 짧아 말이 되는 갈래가 하나도 없을 때 그렇다).
    ///
    /// ⚠️ 임시 폴더에 쓴다. 공유 시트가 읽어 간 뒤 시스템이 정리한다 - 사용자의
    ///    저장 공간에 우리 파일을 남기지 않는다.
    static func render(totalSeconds: Double,
                       totalUses: Int,
                       equivalent: TimeEquivalent?) async throws -> URL {
        // ⚠️ **한 번만 묻는다.** 프레임마다 트레이트를 물으면 102장을 굽는 동안
        //    사용자가 화면을 뒤집었을 때 영상 중간에서 배경이 갈린다.
        let isDark = await MainActor.run { UITraitCollection.current.userInterfaceStyle == .dark }

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
            // 시트를 닫았으면 그만둔다. `.task` 는 화면이 사라질 때 취소를 걸어 주는데,
            // 예전에는 이 고리가 그걸 듣지 않아 안 볼 영상을 끝까지 구웠다.
            try Task.checkCancellation()

            let progress = Double(index) / Double(max(1, frameCount - 1))
            // 메인에서 해야만 하는 딱 한 가지. 한 장 그리고 바로 메인을 놓아 준다.
            let image = await frame(progress: progress, totalSeconds: totalSeconds, totalUses: totalUses,
                                    equivalent: equivalent, isDark: isDark)
            // 여기부터는 메인 밖이다. 2.1MP 를 픽셀 버퍼로 옮기는 일이 장당 붙는데,
            // 이걸 메인에서 하면 한 장의 비용이 두 배가 된다.
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

    /// ⚠️ `ImageRenderer` 가 메인 액터라 이 함수도 메인에서 돈다.
    ///    **여기 말고 다른 것을 메인으로 끌어들이지 말 것.** 한 장의 비용이 곧
    ///    메인이 멈춰 있는 시간이고, 102장이 쌓이면 워치독이 앱을 끈다.
    @MainActor
    private static func frame(progress: Double, totalSeconds: Double, totalUses: Int,
                              equivalent: TimeEquivalent?, isDark: Bool) -> UIImage {
        let eased = min(1, progress / countUpPortion)
        // 처음엔 빠르게, 끝에서 천천히 - 숫자가 자리를 잡는 느낌이 난다.
        let curve = 1 - pow(1 - eased, 3)

        let view = ShareVideoFrame(seconds: totalSeconds,
                                   uses: totalUses,
                                   equivalent: equivalent,
                                   // 굴러 올라가는 것은 **큰 자리 하나뿐**이다. 둘이 같이
                                   // 구르면 눈이 어디를 따라갈지 못 정한다.
                                   countUp: curve,
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
    /// 아낀 시간(초). 이제 **큰 자리가 아니라 아래 작은 줄**에 선다.
    let seconds: Double
    let uses: Int
    /// 큰 자리에 세울 바꿔 말하기. nil 이면 예전처럼 시간이 큰 자리에 선다.
    let equivalent: TimeEquivalent?
    /// 큰 숫자가 얼마나 굴러 올라왔는가(0~1).
    var countUp: Double = 1
    /// 숫자가 다 굴러 제자리에 섰는가 - 이때만 아래 문구가 나타난다.
    let settled: Bool
    /// 어두운 화면으로 뽑을 것인가.
    var isDark: Bool = false

    /// 바탕 - 흰 종이, 또는 앱의 다크 바탕과 같은 검정.
    private var ground: Color {
        isDark ? Color(red: 0x0D/255, green: 0x0D/255, blue: 0x0E/255) : .white
    }
    /// 큰 숫자와 그림에 쓰는 키컬러. 앱에서 보던 그 색이다.
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
    /// 맨 아래 작은 줄 - 곁들이는 글자보다 한 단계 더 물러난다.
    private var faint: Color {
        isDark ? Color(red: 0x6E/255, green: 0x6E/255, blue: 0x75/255)
               : Color(red: 0x9A/255, green: 0x9A/255, blue: 0xA1/255)
    }

    /// 그림. 바꿔 말하기마다 다르다 - 달리기에는 달리는 사람, 커피에는 잔.
    ///
    /// ⚠️ 예전에는 시계 하나뿐이었고 두 가지 색을 쓰는 심볼이라 팔레트 순서에
    ///    걸려 넘어졌다(첫 번째가 배지, 두 번째가 시계판이라 반대로 넣으면
    ///    초록 시계에 파란 배지가 나왔다). 지금 쓰는 그림은 전부 한 색짜리라
    ///    그 함정이 없다. 두 색 심볼로 바꾸려거든 **한 장 구워 보고** 정할 것.
    private var symbolName: String {
        equivalent?.symbol ?? AppSymbol.clockBadgeCheckmarkFill
    }

    /// 큰 자리에 설 글자. 굴러 올라가는 중간값을 그린다.
    private var headline: String {
        if let equivalent {
            return equivalent.amountText(equivalent.value * countUp)
        }
        return RefundReceipt.durationText(seconds: seconds * countUp)
    }

    /// 큰 숫자 **아래** 한 줄. 위의 "이걸 손으로 했다면" 과 이어져 한 문장이 된다.
    ///
    /// ⚠️ 바꿔 말하기가 없을 때는 이 줄이 예전의 "실제로는 단축어 N번" 자리다.
    ///    그때는 큰 자리에 시간이 서 있으므로 아래 작은 줄과 겹치지 않는다.
    private var subline: String {
        equivalent?.caption
            ?? String(format: NSLocalizedString("실제로는 단축어 %d번", comment: "Share video: uses line"), uses)
    }

    var body: some View {
        ZStack {
            ground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Image(systemName: symbolName)
                    .font(.system(size: 190, weight: .light))
                    .foregroundStyle(accent)
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

                Text(headline)
                    .font(.system(size: 150, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundColor(accent)
                    .padding(.horizontal, 60)
                    .padding(.top, 8)

                Text(subline)
                    .font(.system(size: 44, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                    .foregroundColor(muted)
                    .padding(.horizontal, 60)
                    .padding(.top, 18)

                // ⚠️ **이 줄만 사실이다.** 위의 큰 숫자는 어림한 것을 또 한 번 바꿔 말한
                //    것이고, 이 줄의 횟수는 실제로 일어나서 우리가 센 것이다. 그래서
                //    작더라도 반드시 남긴다 - 어림값만 있는 그림은 자랑이 아니라 광고다.
                //
                // ⚠️ 굴러 올라가는 중에는 안 보인다. 큰 숫자가 구르는 동안 아래에서
                //    또 무언가가 움직이면 눈이 둘로 갈린다.
                if equivalent != nil {
                    Text(String(format: NSLocalizedString("%@ · 단축어 %d번",
                                                          comment: "Share video: small footer with time and uses"),
                                RefundReceipt.durationText(seconds: seconds), uses))
                        .font(.system(size: 38, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(faint)
                        .padding(.top, 44)
                        .opacity(settled ? 1 : 0)
                }

                Text(verbatim: "ClipKeyboard")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundColor(ink)
                    .padding(.top, equivalent == nil ? 70 : 44)
                    .opacity(settled ? 1 : 0)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 120)
        }
        .frame(width: ShareVideoRenderer.size.width, height: ShareVideoRenderer.size.height)
    }
}
#endif
