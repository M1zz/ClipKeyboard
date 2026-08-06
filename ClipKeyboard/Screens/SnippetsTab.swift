//
//  SnippetsTab.swift
//  ClipKeyboard
//
//  단축어 탭이 무엇을 보여줄지 고르는 자리 — **목록** 이냐 **키보드 무대** 냐.
//
//  ⚠️ 쓰던 사람의 첫 화면은 업데이트로 바뀌지 않는다. 저장된 값이 없으면 목록이고,
//     새 설치에만 첫 실행에서 무대를 뿌린다. 기존 사용자에게는 **한 번 권하고 끝**이다
//     ([[LivingSkin]]·배경 제안과 같은 규칙 — 권할 때마다 빠져나갈 수 있어야 한다).
//
//  ⚠️ 제안 알림을 `ClipKeyboardList` 안에 두지 않았다. 그 화면은 이미 뷰 트리가 깊어
//     한 겹만 더 얹어도 기기에서 무너진 적이 있다(SwiftUI 타입 메타데이터 한계).
//     탭 껍데기인 여기가 그 알림의 자리로 맞다.
//

import SwiftUI
import LeeoKit

// MARK: - 무엇을 첫 화면으로 볼 것인가

enum SnippetsTabStyle: String, CaseIterable, Identifiable {
    /// 예전부터 있던 카드 목록. 문구를 만들고 고치는 곳.
    case list
    /// 키보드가 실제로 올라온 장면.
    case keyboard

    var id: String { rawValue }

    /// 저장된 값이 없으면 **목록** — 쓰던 사람 쪽에 맞춘 기본값이다.
    static var current: SnippetsTabStyle {
        let raw = UserDefaults.standard.string(forKey: DefaultsKey.snippetsTabStyle) ?? ""
        return SnippetsTabStyle(rawValue: raw) ?? .list
    }

    var localizedName: String {
        switch self {
        case .list:
            return NSLocalizedString("단축어 목록", comment: "Snippets tab style: list")
        case .keyboard:
            return NSLocalizedString("키보드 화면", comment: "Snippets tab style: keyboard stage")
        }
    }

    var localizedDescription: String {
        switch self {
        case .list:
            return NSLocalizedString("카드 목록이에요. 여기서 만들고 고칩니다.",
                                     comment: "Snippets tab style description: list")
        case .keyboard:
            return NSLocalizedString("다른 앱에서 키보드가 올라온 모습 그대로예요. 눌러서 바로 써 볼 수 있어요.",
                                     comment: "Snippets tab style description: keyboard stage")
        }
    }

    var symbolName: String {
        switch self {
        case .list:     return "square.grid.2x2"
        case .keyboard: return "keyboard"
        }
    }
}

// MARK: - 처음 쓰는 사람이 지나는 길

/// 첫 흐름의 **지금 어디쯤**인가.
///
/// ⚠️ 세 걸음이 **끊기지 않고 이어져야** 한다 —
///    ① 하나 만들고 ② 키보드를 켜고 ③ 그걸 눌러 본다.
///    예전에는 ①이 끝나면 무대로 떨어뜨려 두고, ②는 띠를 눌러야만 시작됐다.
///    거기서 끊기면 "만들긴 했는데 어디에 쓰는 거지"로 끝난다 —
///    이 앱의 값어치는 ③에서만 드러나고, ②를 건너뛰면 ③이 영영 안 온다.
///
/// ⚠️ 쓰던 사람은 이 길을 걷지 않는다(`startedFresh`). 목록 쪽도 자기 빈 화면에서 같은
///    첫 단계를 띄우므로, 이 길은 **무대 쪽에서만** 쓴다 — 안 그러면 두 번 나온다.
enum SnippetsOnboardingStep: Equatable {
    /// 첫 단축어 만들기.
    case firstShortcut
    /// 진짜 키보드 켜기 — 이미 켜져 있으면 건너뛴다.
    case keyboardSetup
    /// 다 지났다. 평소 화면으로.
    case done

    static func current(startedFresh: Bool,
                        firstShortcutDone: Bool,
                        keyboardSetupDone: Bool,
                        keyboardUsable: Bool) -> SnippetsOnboardingStep {
        guard startedFresh else { return .done }
        if !firstShortcutDone { return .firstShortcut }
        // 이미 켜 둔 사람에게 켜는 법을 가르치지 않는다.
        if !keyboardSetupDone, !keyboardUsable { return .keyboardSetup }
        return .done
    }
}

// MARK: - 화면 전환 버튼

/// 단축어 목록 ↔ 키보드 미리보기 **한 개짜리 전환 버튼.**
///
/// ⚠️ 버튼은 **갈 곳**을 보여준다. 목록에 있으면 키보드 모양(= 누르면 키보드 미리보기로),
///    미리보기에 있으면 격자 모양(= 누르면 단축어 목록으로). 누르는 순간 그 버튼이
///    반대편 모양으로 바뀌므로, 한 자리에서 왔다갔다 하는 것이 한눈에 읽힌다.
///
/// ⚠️ 지금 상태를 그리지 않는다. 두 칸짜리 스위치는 "지금 여기"를 보여주지만,
///    버튼 하나는 "다음에 갈 곳"을 보여주는 편이 눌렀을 때 무슨 일이 나는지 분명하다.
///
/// 고른 값은 그대로 저장된다(설정 > 첫 화면과 같은 값) — 다음에 열면 마지막에 본 쪽이 나온다.
struct SnippetsStyleSwitchButton: View {
    @Binding var styleRaw: String

    private var current: SnippetsTabStyle { SnippetsTabStyle(rawValue: styleRaw) ?? .list }
    private var target: SnippetsTabStyle { current == .list ? .keyboard : .list }

    var body: some View {
        Button {
            HapticManager.shared.light()
            withAnimation(.easeInOut(duration: 0.2)) { styleRaw = target.rawValue }
        } label: {
            // 툴바의 + 와 **같은 유리 언어** — 클리어 글래스 서클(하단 탭바와도 같다).
            // 옆에 나란히 선 버튼이 하나만 맨몸이면 그것만 다른 앱에서 온 것처럼 보인다.
            Image(systemName: target.symbolName)
                .font(.body.weight(.semibold))
                .foregroundColor(.accentColor)
                .frame(width: 44, height: 44)
                .glassEffect(.clear.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(target.localizedName)
        .accessibilityHint(NSLocalizedString("이 화면과 저 화면을 오갑니다", comment: "Switch between list and keyboard preview"))
    }
}

// MARK: - 탭 껍데기

struct SnippetsTab: View {
    @AppStorage(DefaultsKey.snippetsTabStyle) private var styleRaw: String = SnippetsTabStyle.list.rawValue
    @AppStorage(DefaultsKey.keyboardStageOffered) private var offered: Bool = false
    /// 첫 단축어를 만들었거나 건너뛰었는가.
    @AppStorage(DefaultsKey.firstShortcutDone) private var firstShortcutDone: Bool = false
    /// 이 기기가 4.4.4 이후로 처음 시작했는가 — 쓰던 사람에게 튜토리얼을 다시 깔지 않기 위한 표식.
    @AppStorage(DefaultsKey.startedFreshV444) private var startedFresh: Bool = false
    /// 키보드 켜기 안내까지 지나왔는가(끝냈든 건너뛰었든).
    @AppStorage(DefaultsKey.keyboardSetupTutorialDone) private var keyboardSetupDone: Bool = false

    @State private var showOffer = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var theme

    /// 화면이 갈아 끼워질 때의 모습 — 자리를 옮기지 않고 그 자리에서 바뀐다.
    private var screenTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.985))
    }

    private var style: SnippetsTabStyle { SnippetsTabStyle(rawValue: styleRaw) ?? .list }

    /// 지금 첫 흐름의 어디쯤인가. 무대 쪽에서만 걷는 길이다(위 `SnippetsOnboardingStep` 참고).
    private var onboardingStep: SnippetsOnboardingStep {
        guard style == .keyboard else { return .done }
        return .current(startedFresh: startedFresh,
                        firstShortcutDone: firstShortcutDone,
                        keyboardSetupDone: keyboardSetupDone,
                        keyboardUsable: KeyboardInstallState.isUsable)
    }

    var body: some View {
        // 두 화면 **뒤에 같은 바닥**을 깐다. 각 화면이 자기 배경을 칠하면 갈아 끼우는 순간
        // 바닥색이 한 번 바뀌어 번쩍인다 — 바뀌는 건 그 위에 놓인 것뿐이어야 한다.
        ZStack {
            theme.bg.ignoresSafeArea()
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch onboardingStep {
            case .firstShortcut:
                FirstShortcutOnboardingView(
                    // 만들었으면 **곧바로** 다음 걸음(키보드 켜기)으로 이어진다.
                    onCreated: { _ in advanceFromFirstShortcut() },
                    onSkip: { advanceFromFirstShortcut() }
                )
                .transition(screenTransition)
            case .keyboardSetup:
                KeyboardSetupOnboardingView { keyboardSetupDone = true }
                    .transition(screenTransition)
            case .done:
                switch style {
                case .list:
                    // 전환 버튼은 목록의 **툴바 + 왼쪽**에 있다(ClipKeyboardList.toolbarButtons).
                    // 화면 위에 겹쳐 띄우면 카드를 가린다.
                    ClipKeyboardList()
                        .transition(screenTransition)
                case .keyboard:
                    InAppKeyboardStage(styleRaw: $styleRaw)
                        .transition(screenTransition)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: onboardingStep)
        // 두 화면은 **같은 자리에서 갈아 끼우는 것**이라 서로 밀어내지 않는다 —
        // 밀려 들어오면 어디로 이동한 것처럼 보이고, 여기서는 이동한 게 아니라 모습이 바뀐 것이다.
        // 살짝 줄었다 펴지는 것만 얹어 "바뀌었다"를 눈이 알아채게 한다.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: styleRaw)
        .onAppear(perform: offerKeyboardStageIfNeeded)
        .alert(NSLocalizedString("새 키보드 화면을 써보시겠어요?", comment: "Keyboard stage offer title"),
               isPresented: $showOffer) {
            Button(NSLocalizedString("써볼게요", comment: "Accept category activation")) {
                withAnimation { styleRaw = SnippetsTabStyle.keyboard.rawValue }
            }
            Button(NSLocalizedString("괜찮아요", comment: "Decline category activation"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("다른 앱에서 키보드가 올라온 모습 그대로 보여줘요. 언제든 설정 > 첫 화면에서 목록으로 되돌릴 수 있어요.",
                                   comment: "Keyboard stage offer message"))
        }
    }

    /// 첫 단축어를 만들었거나 건너뛴 뒤 — **끊지 않고** 다음 걸음으로 넘긴다.
    /// 키보드가 이미 켜져 있으면 `SnippetsOnboardingStep` 이 알아서 무대로 보낸다.
    private func advanceFromFirstShortcut() {
        withAnimation(.easeInOut(duration: 0.28)) { firstShortcutDone = true }
    }

    /// 쓰던 사람에게 **한 번만** 권한다.
    ///
    /// 새 설치는 이미 무대로 시작하므로 권할 일이 없고, 한 번 권한 뒤에는
    /// 고르든 넘기든 다시 묻지 않는다. 설정에 자리가 있으므로 언제든 바꿀 수 있다.
    private func offerKeyboardStageIfNeeded() {
        guard !offered, style == .list else { return }
        offered = true
        // 화면이 자리를 잡은 뒤에 — 열자마자 알림이 뜨면 무엇에 대한 물음인지 안 보인다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showOffer = true
        }
    }
}
