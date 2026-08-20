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
//  ⚠️ 예전에는 여기가 **문패였다.** 갈 곳 두 개만 있고 답은 전부 그 너머에 있었다.
//     그런데 "사용 가이드"는 한 겹 안이 아니라 **브라우저로 나가는 문**이었고,
//     막힌 사람은 앱을 떠나야 답을 볼 수 있었다. 도움말이 도움을 못 주고 있었다.
//
//     그래서 **가장 많이 막히는 세 가지의 답을 이 시트 안으로 꺼냈다.**
//     · 키보드를 아직 못 켰다  → 켜는 화면을 여기서 바로 연다
//     · 이게 뭐 하는 건지 모르겠다 → 단축어·템플릿·콤보를 한 줄씩, 예시와 함께
//     · 직접 해 보고 싶다      → 튜토리얼 다시 하기
//     긴 글(웹 가이드)은 맨 아래로 내렸다 - 읽을 사람만 읽으면 된다.
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
    @State private var showsKeyboardSetup = false
    /// 진짜 키보드를 이미 켰는가 - 안 켰으면 그게 제일 먼저 풀어야 할 막힘이다.
    @State private var keyboardReady = KeyboardInstallState.isUsable

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    greeting
                    if !keyboardReady { keyboardDoor }
                    whatIsWhat
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
            .onAppear { keyboardReady = KeyboardInstallState.isUsable }
            .fullScreenCover(isPresented: $showsKeyboardSetup,
                             onDismiss: { keyboardReady = KeyboardInstallState.isUsable }) {
                KeyboardSetupOnboardingView { showsKeyboardSetup = false }
            }
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

    /// 아직 키보드를 못 켰다 - **여기서 바로 켠다.**
    ///
    /// ⚠️ 설정 앱 경로를 글로 적어 주지 않는다. 적어 준 대로 따라가다 한 곳에서 막히면
    ///    거기서 끝난다. 켜는 화면이 이미 있으니 그걸 그대로 연다.
    private var keyboardDoor: some View {
        Button {
            HapticManager.shared.light()
            showsKeyboardSetup = true
        } label: {
            door(symbol: AppSymbol.keyboardFill,
                 title: NSLocalizedString("키보드 켜기", comment: "Mascot help: turn on the keyboard"),
                 detail: NSLocalizedString("아직 다른 앱에서는 못 써요. 켜는 곳까지 같이 가 드릴게요.",
                                           comment: "Mascot help: keyboard setup detail"),
                 showsChevron: true)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 10)
    }

    /// **셋이 뭐가 다른가** - 가장 많이 막히는 질문의 답을 여기에 그대로 적는다.
    ///
    /// ⚠️ 링크로 넘기지 않는다. 이 답은 세 줄이면 끝나는데, 세 줄을 보자고 브라우저를
    ///    열게 하면 대부분 안 열고 그냥 닫는다.
    ///
    /// ⚠️ 예시를 같이 적는다. "빈칸을 채워 쓰는 문구"보다 `{이름}님 안녕하세요` 한 줄이
    ///    빠르다. 설명은 읽어야 알지만 예시는 보면 안다.
    private var whatIsWhat: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("셋이 뭐가 달라요?", comment: "Mascot help: what is what header"))
                .font(.footnote.weight(.semibold))
                .foregroundColor(theme.textMuted)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                kindRow(symbol: "text.cursor",
                        name: NSLocalizedString("단축어", comment: "Snippet"),
                        detail: NSLocalizedString("눌러서 적힌 그대로 넣어요.", comment: "Mascot help: snippet detail"),
                        example: NSLocalizedString("내 계좌 · 집 주소", comment: "Mascot help: snippet example"))
                Divider().padding(.leading, 44)
                kindRow(symbol: "square.dashed",
                        name: NSLocalizedString("템플릿", comment: "Template"),
                        detail: NSLocalizedString("빈칸만 채우면 나머지는 그대로 완성돼요.", comment: "Mascot help: template detail"),
                        example: NSLocalizedString("{이름}님, 확인했습니다", comment: "Mascot help: template example"))
                Divider().padding(.leading, 44)
                kindRow(symbol: "list.number",
                        name: NSLocalizedString("콤보", comment: "Combo"),
                        detail: NSLocalizedString("여러 값이 순서대로 하나씩 들어가요.", comment: "Mascot help: combo detail"),
                        example: NSLocalizedString("이름 → 연락처 → 주소", comment: "Mascot help: combo example"))
            }
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                    .fill(theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                    .strokeBorder(theme.divider, lineWidth: 0.5)
            )
        }
        .padding(.bottom, 18)
    }

    private func kindRow(symbol: String, name: String, detail: String, example: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundColor(theme.accent)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.text)
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Text(example)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(theme.accent)
                    .padding(.top, 1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var doors: some View {
        VStack(spacing: 10) {
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

            // 긴 글은 **맨 아래**다. 브라우저로 나가는 문이라, 위에 두면 답을 찾으러 온
            // 사람을 앱 밖으로 먼저 내보내게 된다.
            NavigationLink {
                TutorialView()
            } label: {
                door(
                    symbol: AppSymbol.bookClosed,
                    title: NSLocalizedString("자세한 사용 가이드", comment: "User guide"),
                    detail: NSLocalizedString("웹에서 열려요. 더 많은 예시와 화면별 설명이 있어요.", comment: "Mascot help: user guide detail"),
                    showsChevron: true
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
