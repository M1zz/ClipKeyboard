//
//  ShareVideoSheet.swift
//  ClipKeyboard
//
//  아낀 시간을 담은 짧은 세로 영상을 **먼저 보여주고** 나서 내보낸다.
//
//  ⚠️ 예전에는 버튼을 누르면 영상을 굽고 곧장 공유 시트가 떴다. 자기가 무엇을 내보내는지
//     못 본 채로 남에게 보낼 것을 고르게 되는 것이다. 남에게 보여줄 물건이라면
//     **본인이 먼저 봐야 한다.** 마음에 안 들면 안 보내는 것도 선택지여야 한다.
//
//  ⚠️ 굽는 데 1~2초 걸린다. 그동안 빈 화면을 두면 고장 난 것처럼 보이므로, 시트는 즉시
//     열고 그 안에서 도는 표시를 보여준다. 기다림을 감추는 것보다 **보이게 하는 쪽**이 낫다.
//
//  ⚠️ 미리보기는 계속 돌아간다. 3초짜리라 한 번 보고 멈추면 놓친 사람이 다시 볼 방법이 없다.
//

import SwiftUI
#if canImport(UIKit)
import AVKit
import LeeoKit
import UIKit

struct ShareVideoSheet: View {
    /// 이 기간에 아낀 시간. 사용 기록 화면에서 고른 기간 그대로 들어온다.
    let totalSeconds: Double
    let totalUses: Int

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var videoURL: URL?
    @State private var player: AVPlayer?
    @State private var failed = false
    @State private var isSharing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                preview
                buttons
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("친구들에게 알리기", comment: "Share video sheet title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("닫기", comment: "Close button")) { dismiss() }
                }
            }
            .sheet(isPresented: $isSharing) {
                if let videoURL {
                    ActivityShareSheet(items: [videoURL])
                }
            }
        }
        .task { await make() }
        .onDisappear { player?.pause() }
    }

    // MARK: - 미리보기

    @ViewBuilder
    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                .fill(theme.surface)

            if let player {
                VideoPlayer(player: player)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
                    // 미리보기지 재생기가 아니다. 눌러서 멈추거나 감을 일이 없다.
                    .allowsHitTesting(false)
                    .accessibilityLabel(NSLocalizedString("아낀 시간을 담은 영상 미리보기",
                                                          comment: "Share video preview accessibility label"))
            } else if failed {
                VStack(spacing: 8) {
                    Image(systemName: AppSymbol.exclamationmarkTriangleFill)
                        .font(.largeTitle)
                        .foregroundColor(theme.textFaint)
                        .accessibilityHidden(true)
                    Text(NSLocalizedString("영상을 만들지 못했어요", comment: "Share video: render failed"))
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.text)
                    Button(NSLocalizedString("다시 시도", comment: "Retry button")) {
                        Task { await make() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.accent)
                }
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                    Text(NSLocalizedString("영상을 만드는 중이에요", comment: "Share video: rendering"))
                        .font(.footnote)
                        .foregroundColor(theme.textMuted)
                }
            }
        }
        // ⚠️ 테두리를 두른다. 영상 바탕이 흰색(다크에서는 검정)이 되면서 **미리보기 카드와
        //    같은 색**이 됐다 - 선이 없으면 어디까지가 영상인지 안 보이고, 스토리 비율이
        //    어떻게 잘리는지도 가늠이 안 된다. 베이지였을 때는 저절로 갈라졌던 자리다.
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                .strokeBorder(theme.divider, lineWidth: 1)
        )
        // 스토리 비율 그대로 보여준다. 다른 비율로 보여주고 다른 비율을 내보내면
        // 본 것과 보낸 것이 다른 물건이 된다.
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 내보내기

    /// ⚠️ 예전에는 "인스타 스토리에 올리기"가 따로 있었다. 뺐다. 특정 서비스로 가는 길을
    ///    앱이 직접 들고 있으면 그 서비스가 규칙을 바꿀 때마다 우리 코드가 따라가야 하고,
    ///    그 서비스를 안 쓰는 사람에게는 자리만 차지하는 단추가 된다. 어디로 보낼지는
    ///    시스템 공유 시트가 이미 안다. 우리는 **보낼 것**만 잘 만들면 된다.
    private var buttons: some View {
        Button {
            HapticManager.shared.light()
            isSharing = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: AppSymbol.squareAndArrowUp)
                    .font(.body.weight(.semibold))
                Text(NSLocalizedString("공유하기", comment: "Button: share"))
                    .font(.body.weight(.semibold))
                Spacer(minLength: 0)
            }
            .foregroundColor(theme.accentFg)
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                    .fill(theme.accent)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(videoURL == nil)
        .opacity(videoURL == nil ? 0.5 : 1)
    }

    // MARK: - 굽기

    private func make() async {
        failed = false
        player = nil
        do {
            let url = try await ShareVideoRenderer.render(totalSeconds: totalSeconds, totalUses: totalUses)
            videoURL = url
            player = loopingPlayer(for: url)
            player?.play()
        } catch {
            // ⚠️ 조용히 실패하지 않는다. 눌렀는데 아무 일도 안 일어나면 그게 가장 나쁘다.
            print("❌ [ShareVideoSheet.make] 영상 만들기 실패: \(error)")
            HapticManager.shared.error()
            failed = true
        }
    }

    /// 끝까지 가면 처음으로 되감아 다시 튼다. 3초짜리를 한 번만 틀면 놓친 사람이 다시 볼 수 없다.
    private func loopingPlayer(for url: URL) -> AVPlayer {
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        return player
    }
}
#endif
