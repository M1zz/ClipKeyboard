//
//  MascotHelpSheet.swift
//  ClipKeyboard
//
//  **무대에서 악어 얼굴을 누르면 열리는 자리.**
//
//  왜 여기인가: 미리보기 무대는 말풍선으로 된 대화 화면이라, 얼굴 옆의 말풍선이 이미
//  말을 걸고 있다. 그 얼굴을 누르면 대화가 이어지는 것이 자연스럽다.
//  도움말을 설정 깊은 곳에만 두면, 막힌 사람은 막힌 자리에서 길을 찾지 못한다.
//
//  ⚠️ 새 안내 화면을 만들지 않는다. 여기는 **문패**다. 갈 곳은 이미 있는 두 화면
//     (`TutorialView` 사용 가이드 · 튜토리얼 다시 하기)이고, 이 시트는 그 앞에서
//     "무엇을 도와드릴까요"를 묻는 역할만 한다. 같은 내용을 세 곳에 두면 셋 다 낡는다.
//
//  ⚠️ 손 흔드는 그림은 온보딩과 **같은 영상**을 쓴다(`MascotWaveView`). 첫 화면에서 본
//     그 악어가 여기서도 손을 흔들어야 같은 인물로 읽힌다. 새로 그리면 남이 된다.
//

import SwiftUI
import LeeoKit   // HapticManager

struct MascotHelpSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showTutorialRestartConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    greeting
                    doors
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(theme.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("닫기", comment: "Close")) { dismiss() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert(NSLocalizedString("튜토리얼을 다시 할까요?", comment: "Restart tutorial alert title"),
               isPresented: $showTutorialRestartConfirm) {
            Button(NSLocalizedString("다시 하기", comment: "Restart tutorial confirm")) {
                TutorialReset.restartAll()
                // 튜토리얼은 무대에서 시작한다. 시트가 덮고 있으면 첫 걸음이 안 보인다.
                dismiss()
            }
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("준비된 단축어·템플릿·콤보를 다시 하나씩 눌러보며 안내해요. 목록의 단축어는 그대로 남아요.", comment: "Restart tutorial alert message"))
        }
    }

    // MARK: - 인사

    private var greeting: some View {
        VStack(spacing: 12) {
            mascot
            Text(NSLocalizedString("무엇을 도와드릴까요?", comment: "Mascot help sheet title"))
                .font(.title2.weight(.bold))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)
            Text(NSLocalizedString("처음이면 손잡고 한 번 같이 해 봐요. 이미 해 봤다면 필요한 것만 찾아보셔도 돼요.", comment: "Mascot help sheet subtitle"))
                .font(.subheadline)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity)
    }

    /// 손 흔드는 악어. 영상이 없으면 손 흔드는 기호로 대신한다.
    ///
    /// ⚠️ 온보딩과 같은 방식으로 얹는다 - 알파 영상이라 뒤가 비어 있어서, 브랜드색
    ///    옅은 원을 깔지 않으면 캐릭터가 허공에 뜬 것처럼 보인다.
    private var mascot: some View {
        ZStack {
            Circle()
                .fill(theme.accentSoft)
                .frame(width: 104, height: 104)

            if MascotWaveView.videoURL != nil {
                MascotWaveView(animates: !reduceMotion)
                    .frame(width: 118, height: 118)
            } else {
                Image(systemName: "hand.wave.fill")
                    .font(.largeTitle)
                    .foregroundColor(theme.accent)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - 갈 곳

    private var doors: some View {
        VStack(spacing: 10) {
            NavigationLink {
                TutorialView()
            } label: {
                door(
                    symbol: AppSymbol.bookClosed,
                    title: NSLocalizedString("사용 가이드", comment: "User guide"),
                    detail: NSLocalizedString("단축어·템플릿·콤보가 무엇인지, 키보드는 어떻게 켜는지 읽어 보세요.", comment: "Mascot help: user guide detail"),
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            Button {
                HapticManager.shared.light()
                showTutorialRestartConfirm = true
            } label: {
                door(
                    symbol: AppSymbol.sparkles,
                    title: NSLocalizedString("튜토리얼 다시 하기", comment: "Restart tutorial"),
                    detail: NSLocalizedString("읽는 대신 직접 눌러 보면서 배워요. 준비된 것을 하나씩 가리켜 드릴게요.", comment: "Mascot help: tutorial detail"),
                    showsChevron: false
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func door(symbol: String, title: String, detail: String, showsChevron: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundColor(theme.accent)
                .frame(width: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(theme.text)
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsChevron {
                Image(systemName: AppSymbol.chevronRight)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(theme.textFaint)
                    .padding(.top, 3)
                    .accessibilityHidden(true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                .fill(theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                .strokeBorder(theme.divider, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }
}
