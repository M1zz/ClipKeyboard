//
//  MinerScene.swift
//  ClipKeyboard
//
//  **갱도에 선 광부** — 온보딩의 주인공과 그가 서 있는 자리.
//
//  ⚠️ 캐릭터만 덩그러니 두면 뜬금없다. 곡괭이 든 사람이 흰 카드 위에 서 있으면
//     "이 사람이 왜 여기 있지"가 먼저 든다. **장면이 있어야 인물이 설명된다.**
//     그래서 갱도(나무 기둥·아치·바닥·등불)를 함께 그린다.
//
//  ⚠️ 캐릭터 영상은 **알파가 있는 HEVC**(miner_idle.mov)다. 예전에는 흰 배경 mp4 를
//     multiply 로 지웠는데, 그 방법은 (1) 밝은 판 위에서만 되고 (2) 판과 영상 크기가
//     어긋나면 네모난 단차가 보였다. 배경을 아예 뚫어 두면 어떤 장면 위에도 올라간다.
//
//  ⚠️ 바닥 그림자도 영상에서 지웠다. 구워 넣은 회색 그림자는 장면 색과 안 맞는다 —
//     여기서 장면 색으로 직접 그린다.
//

import SwiftUI
#if canImport(AVKit)
import AVKit
#endif

#if canImport(AVKit)

/// 알파가 있는 캐릭터 영상을 무한 반복한다.
///
/// 첫 프레임과 마지막 프레임이 거의 같아서(평균 차이 2.05) 끝에서 되감아도 이음매가 안 보인다.
private struct LoopingVideo: UIViewRepresentable {
    let resource: String

    func makeUIView(context: Context) -> PlayerContainerView { PlayerContainerView(resource: resource) }
    func updateUIView(_ uiView: PlayerContainerView, context: Context) {}
    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: ()) { uiView.stop() }

    final class PlayerContainerView: UIView {
        private var player: AVPlayer?
        private var observer: NSObjectProtocol?

        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        init(resource: String) {
            super.init(frame: .zero)
            backgroundColor = .clear
            isOpaque = false
            isUserInteractionEnabled = false

            guard let url = Bundle.main.url(forResource: resource, withExtension: "mov") else {
                print("❌ [MinerScene] \(resource).mov 를 번들에서 못 찾음")
                return
            }
            let player = AVPlayer(url: url)
            player.isMuted = true
            player.actionAtItemEnd = .none
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspect
            // 알파가 살아 보이려면 레이어가 불투명하면 안 된다.
            playerLayer.isOpaque = false
            playerLayer.backgroundColor = UIColor.clear.cgColor
            self.player = player

            observer = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
            player.play()
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func stop() {
            player?.pause()
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            player = nil
            playerLayer.player = nil
        }
    }
}

/// 정지 화면(동작 줄이기용). 첫 프레임이 기본 자세다.
private struct StillFrame: UIViewRepresentable {
    let resource: String

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .clear
        guard let url = Bundle.main.url(forResource: resource, withExtension: "mov") else { return view }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        if let cg = try? generator.copyCGImage(at: .zero, actualTime: nil) {
            view.image = UIImage(cgImage: cg)
        }
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {}
}

// MARK: - 갱도

/// 광부가 서 있는 갱도.
///
/// ⚠️ 배경은 그린 일러스트(MineTunnel)를 쓴다. 처음에는 도형(아치·기둥·바닥)으로 직접
///    그렸는데, 몇 개의 사각형과 호로는 "갱도처럼 보이는 것"까지가 한계였다.
///    분위기는 디테일에서 나오고, 디테일은 도형 몇 개로 안 만들어진다.
struct MinerScene: View {
    /// 장면 높이(pt).
    var height: CGFloat = 240
    /// 갱도를 그릴지. 끄면 캐릭터만 나온다.
    var showsScene: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 캐릭터 영상 비율(514×656). 영상을 갈아 끼울 때 **반드시 같이 고친다** —
    /// 비율이 어긋나면 발끝이 바닥선에서 뜨거나 파묻힌다.
    private static let charAspect: CGFloat = 514.0 / 656.0

    /// 캐릭터가 서는 바닥선(높이 비율). 그림 속 선로가 깔린 바닥 높이에 맞춘 값이다.
    /// 그림자와 발끝이 **같은 선**을 봐야 공중에 뜨지 않는다.
    private static let groundLine: CGFloat = 0.90
    /// 캐릭터 키(높이 비율). 갱도 아치 안에 들어가야 한다.
    private static let charHeight: CGFloat = 0.62
    /// 좌우 위치. 정중앙에 두면 광차와 겹쳐서, 살짝 왼쪽에 세운다.
    private static let charCenterX: CGFloat = 0.40

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let ground = h * Self.groundLine
            let charH = h * Self.charHeight

            ZStack {
                if showsScene {
                    Image("MineTunnel")
                        .resizable()
                        .scaledToFill()
                        .frame(width: w, height: h)
                        .clipped()

                    // 아래를 살짝 눌러 준다 — 밝은 흙바닥 위에 밝은 옷을 입은 인물이 서면
                    // 실루엣이 묻힌다.
                    LinearGradient(colors: [.clear, .black.opacity(0.28)],
                                   startPoint: .center, endPoint: .bottom)

                    // 발밑 그림자 — 영상에 구워 넣은 회색 그림자는 지웠으므로 여기서 그린다.
                    Ellipse()
                        .fill(Color.black.opacity(0.34))
                        .frame(width: charH * Self.charAspect * 0.5, height: h * 0.028)
                        .blur(radius: 3)
                        .position(x: w * Self.charCenterX, y: ground)
                }

                character
                    .frame(width: charH * Self.charAspect, height: charH)
                    .position(x: w * Self.charCenterX, y: ground - charH / 2)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var character: some View {
        if reduceMotion {
            StillFrame(resource: "miner_idle")
        } else {
            LoopingVideo(resource: "miner_idle")
        }
    }
}


#else

struct MinerScene: View {
    var height: CGFloat = 240
    var showsScene: Bool = true
    var body: some View { Color.clear.frame(height: height) }
}

#endif
