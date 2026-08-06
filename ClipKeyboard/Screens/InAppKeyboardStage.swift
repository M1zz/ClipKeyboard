//
//  InAppKeyboardStage.swift
//  ClipKeyboard
//
//  **무대** — 앱을 열면 키보드가 실제로 올라온 모습이 그대로 보인다.
//
//  왜 이렇게 하는가: 이 앱의 값어치는 목록이 아니라 **다른 앱에서 키보드로 꺼내 쓰는 순간**에
//  있다. 그런데 앱을 열면 카드 목록만 보여서, 키보드를 설치하고도 한 번도 안 써 본 사람이
//  자기가 뭘 갖고 있는지 모른 채 지나갔다. 그래서 앱의 첫 화면을 **키보드가 쓰이는 장면**으로 둔다.
//
//  ⚠️ 아래 키보드는 흉내가 아니라 **익스텐션과 같은 `KeyboardView`** 다. 두 벌로 만들면
//     하나만 고쳐지는 날이 반드시 온다. 다른 점은 글이 가는 곳뿐 —
//     익스텐션은 남의 앱 텍스트 필드로, 여기서는 위 입력창으로 간다(`InAppKeyboardHost`).
//
//  ⚠️ 위쪽 대화는 **우리 말풍선**이다. 메시지 앱을 그대로 베끼지 않는다 —
//     남의 앱 화면을 재현한 것처럼 보이면 심사에서 문제가 되고, 사용자도 진짜 대화로 오해한다.
//

import SwiftUI
import LeeoKit

struct InAppKeyboardStage: View {
    @StateObject private var host = InAppKeyboardHost()
    @Environment(\.appTheme) private var theme

    /// 예전 화면(카드 목록) — 여기서 문구를 만들고 고친다.
    /// ⚠️ 반드시 남겨 둘 것. 무대에는 문구를 **만드는** 길이 없다.
    @State private var showsList = false

    /// 문구 목록이 바뀔 때마다 올린다 — `KeyboardView`는 등장할 때 한 번만 목록을 읽으므로
    /// (익스텐션에서는 키보드가 뜰 때마다 새 프로세스라 그걸로 충분했다),
    /// 앱에서는 이 값을 `.id`로 물려 다시 태어나게 해야 새 문구가 보인다.
    @State private var feedToken = 0

    /// 키보드 설치 안내(`KeyboardSetupOnboardingView`)를 띄우는 중인가.
    @State private var showsKeyboardSetup = false
    /// 이 무대를 볼 때마다 다시 확인한다 — 설정에서 켜고 돌아오면 띠가 사라져야 한다.
    @State private var keyboardReady = true

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                stageHeader
                // 여기까지 배웠으면 마지막 한 걸음은 **진짜 키보드를 켜는 것**이다.
                // 무대에서 아무리 눌러 봐도 다른 앱에서 못 쓰면 아무 일도 일어나지 않는다.
                if !keyboardReady { keyboardSetupBanner }
                conversation
                composer
                // 진짜 키보드와 같은 뷰. 높이는 실제 키보드가 차지하는 만큼(화면의 절반쯤).
                KeyboardView(typingProxy: host,
                             documentState: host.documentState,
                             hostKind: .inApp)
                    .frame(height: min(max(geo.size.height * 0.5, 260), 430))
                    .id(feedToken)
            }
        }
        .background(theme.bg.ignoresSafeArea())
        .onAppear {
            reloadFeed()
            refreshKeyboardReady()
        }
        .onDisappear { host.stop() }
        // 설정에서 키보드를 켜고 돌아오면 띠가 스스로 사라져야 한다.
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshKeyboardReady()
        }
        .fullScreenCover(isPresented: $showsKeyboardSetup, onDismiss: refreshKeyboardReady) {
            KeyboardSetupOnboardingView { showsKeyboardSetup = false }
        }
        // 목록에서 문구를 만들거나 고치면 무대의 키보드도 따라와야 한다.
        .onReceive(NotificationCenter.default.publisher(for: .memoDataChanged)) { _ in
            reloadFeed()
        }
        .fullScreenCover(isPresented: $showsList, onDismiss: reloadFeed) {
            listCover
        }
    }

    /// 저장소 → `clipMemos` → 키보드 뷰 순으로 새로 읽는다.
    private func reloadFeed() {
        KeyboardMemoFeed.reload()
        feedToken += 1
    }

    /// 진짜 키보드가 한 번이라도 떠 본 적 있는가.
    ///
    /// 익스텐션은 처음 뜰 때 App Group에 표식을 남긴다(`keyboardExtensionDidLoad`).
    /// iOS는 "이 키보드가 켜져 있는가"를 앱에 알려주지 않으므로, **떠 본 적 있는가**가
    /// 우리가 알 수 있는 가장 가까운 사실이다. 아직 없다면 아직 못 쓰고 있는 것이다.
    private func refreshKeyboardReady() {
        keyboardReady = UserDefaults(suiteName: AppGroup.identifier)?
            .bool(forKey: DefaultsKey.keyboardExtensionDidLoad) ?? false
    }

    /// 무대 아래 띠 — 마지막 한 걸음(진짜 키보드 켜기)으로 데려간다.
    ///
    /// ⚠️ 알림(모달)로 띄우지 않는다. 앱을 열자마자 창이 뜨면 무엇을 하라는 건지 보기도 전에
    ///    닫게 된다. 무대를 보여준 **다음에** 한 줄로 권하는 편이 이어진다.
    private var keyboardSetupBanner: some View {
        Button {
            HapticManager.shared.light()
            showsKeyboardSetup = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.title3)
                    .foregroundColor(theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(NSLocalizedString("아직 다른 앱에서는 못 써요", comment: "Keyboard not set up banner title"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(theme.text)
                    Text(NSLocalizedString("키보드를 켜면 어디서든 이 화면이 올라와요", comment: "Keyboard not set up banner body"))
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                }
                Spacer(minLength: 0)
                Text(NSLocalizedString("켜기", comment: "Turn on the keyboard"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(theme.accent))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(theme.accentSoft)
    }

    // MARK: - 머리말

    private var stageHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(NSLocalizedString("키보드 미리보기", comment: "In-app keyboard stage title"))
                    .font(.headline)
                    .foregroundColor(theme.text)
                Text(NSLocalizedString("다른 앱에서 보이는 그대로예요", comment: "In-app keyboard stage subtitle"))
                    .font(.caption)
                    .foregroundColor(theme.textMuted)
            }
            Spacer(minLength: 0)
            Button {
                HapticManager.shared.light()
                showsList = true
            } label: {
                Label(NSLocalizedString("목록", comment: "Open the snippet list"),
                      systemImage: "square.grid.2x2")
                    .font(.subheadline.weight(.semibold))
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .foregroundColor(theme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.surface.opacity(0.6))
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.divider.opacity(0.5)).frame(height: 0.5)
        }
    }

    // MARK: - 대화

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(host.messages) { message in
                        bubble(message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: host.messages.count) {
                guard let last = host.messages.last else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bubble(_ message: StageMessage) -> some View {
        let mine = message.side == .outgoing
        return HStack {
            if mine { Spacer(minLength: 40) }
            Text(message.text)
                .font(.callout)
                .foregroundColor(mine ? .white : theme.text)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(mine ? theme.accent : theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
                .textSelection(.enabled)
            if !mine { Spacer(minLength: 40) }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - 입력창

    /// 시스템 키보드는 뜨지 않는다 — 이 칸은 **아래 우리 키보드만** 채운다.
    /// (진짜 `TextField`를 두면 탭할 때 시스템 키보드가 올라와 무대가 가려진다)
    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            composerField
            Button {
                HapticManager.shared.light()
                withAnimation(.easeOut(duration: 0.2)) { host.send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(host.text.isEmpty ? theme.textMuted.opacity(0.5) : theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(host.text.isEmpty)
            .accessibilityLabel(NSLocalizedString("보내기", comment: "Send composed message"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surface.opacity(0.6))
        .overlay(alignment: .top) {
            Rectangle().fill(theme.divider.opacity(0.5)).frame(height: 0.5)
        }
    }

    private var composerField: some View {
        Group {
            if host.text.isEmpty {
                // 빈칸일 때도 캐럿은 서 있어야 "여기로 들어간다"가 읽힌다.
                (caretGlyph + Text(NSLocalizedString("여기에 입력돼요", comment: "In-app keyboard composer placeholder"))
                    .foregroundColor(theme.textMuted))
            } else {
                composedText
            }
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 34, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(theme.divider.opacity(0.6), lineWidth: 0.5)
        )
        .accessibilityLabel(NSLocalizedString("입력창", comment: "Composer field accessibility label"))
        .accessibilityValue(host.text)
    }

    /// 캐럿을 사이에 낀 본문. 깜빡이지 않는다 —
    /// 하루에도 여러 번 여는 화면에서 상시 타이머는 소음이고 배터리다.
    private var composedText: Text {
        let chars = Array(host.text)
        let cut = min(max(host.caret, 0), chars.count)
        return Text(String(chars[0..<cut])).foregroundColor(theme.text)
            + caretGlyph
            + Text(String(chars[cut...])).foregroundColor(theme.text)
    }

    private var caretGlyph: Text {
        Text(verbatim: "\u{258F}").foregroundColor(theme.accent)
    }

    // MARK: - 목록으로 가는 문

    /// 예전 화면을 그대로 띄운다. 목록 쪽 코드는 손대지 않고, 돌아오는 버튼만 아래에 얹는다
    /// (목록 화면은 이미 위아래가 꽉 차 있어 새 버튼을 끼울 자리가 없다).
    private var listCover: some View {
        ZStack(alignment: .bottom) {
            ClipKeyboardList()
            Button {
                HapticManager.shared.light()
                showsList = false
            } label: {
                Label(NSLocalizedString("키보드 화면", comment: "Back to the in-app keyboard stage"),
                      systemImage: "keyboard")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(theme.accent))
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 18)
        }
    }
}
