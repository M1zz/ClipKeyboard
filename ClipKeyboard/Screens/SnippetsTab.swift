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
    /// ① 첫 단축어 만들기.
    case firstShortcut
    /// ② 무대에서 **방금 만든 그 키를 눌러 본다.** 만들기만 하고 끝나면 아무것도 안 배운 것이다.
    case tryInKeyboard
    /// ③~⑤ 템플릿 → 있는 걸 템플릿으로 → 콤보. 목록 화면의 챕터 기계가 맡는다.
    case chapters
    /// ⑥ 마지막에 진짜 키보드 켜기 — 이미 켜져 있으면 건너뛴다.
    case keyboardSetup
    /// 다 지났다. 평소 화면으로.
    case done

    /// 순서: 단축어 → **눌러보기** → 템플릿 → 템플릿으로 만들기 → 콤보 → 키보드 설정.
    ///
    /// ⚠️ 키보드 설정이 **맨 뒤**인 이유: 설정 앱으로 나갔다 오는 일이라 흐름이 가장 크게 끊긴다.
    ///    배울 것을 다 배운 뒤에 "이제 다른 앱에서도 쓰려면" 으로 이어져야 나갔다 돌아올 이유가 분명하다.
    static func current(startedFresh: Bool,
                        firstShortcutDone: Bool,
                        firstUsePending: Bool,
                        chaptersDone: Bool,
                        keyboardSetupDone: Bool,
                        keyboardUsable: Bool) -> SnippetsOnboardingStep {
        guard startedFresh else { return .done }
        if !firstShortcutDone { return .firstShortcut }
        // 만들어 놓고 아직 안 눌러 봤다 — 무대에서 그 키를 가리킨다.
        if firstUsePending { return .tryInKeyboard }
        if !chaptersDone { return .chapters }
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
    /// 튜토리얼에서 만든 단축어 id — 아직 안 눌러 봤으면 값이 남아 있다.
    @AppStorage(DefaultsKey.tutorialFirstUseMemoId) private var firstUseMemoIdRaw: String = ""
    /// 목록 쪽 챕터(템플릿 → 템플릿으로 만들기 → 콤보) 완료 표식.
    @AppStorage(DefaultsKey.tutorialTemplateDone) private var tutorialTemplateDone: Bool = false
    @AppStorage(DefaultsKey.tutorialMakeTemplateDone) private var tutorialMakeTemplateDone: Bool = false
    @AppStorage(DefaultsKey.tutorialComboDone) private var tutorialComboDone: Bool = false
    /// 목록의 챕터 기계가 "더 권할 것이 없다"고 알려주면 켜진다.
    @AppStorage(DefaultsKey.tutorialChaptersDone) private var chaptersFinished: Bool = false

    @State private var showOffer = false
    /// 지금 권하고 있는 장(템플릿·템플릿으로 만들기·콤보).
    @State private var tutorialInvite: TutorialChapter?
    /// 지금 만들고 있는 장.
    @State private var tutorialMaking: TutorialChapter?
    /// 튜토리얼이 끝난 뒤 "만든 것 지울까요?" 를 한 번만 묻는다.
    @AppStorage(DefaultsKey.tutorialCleanupAsked) private var cleanupAsked: Bool = false
    @State private var showCleanupPrompt = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var theme

    /// 화면이 갈아 끼워질 때의 모습 — 자리를 옮기지 않고 그 자리에서 바뀐다.
    private var screenTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.985))
    }

    private var style: SnippetsTabStyle { SnippetsTabStyle(rawValue: styleRaw) ?? .list }

    /// 지금 첫 흐름의 어디쯤인가(위 `SnippetsOnboardingStep` 참고).
    private var onboardingStep: SnippetsOnboardingStep {
        .current(startedFresh: startedFresh,
                 firstShortcutDone: firstShortcutDone,
                 firstUsePending: highlightedMemoId != nil,
                 chaptersDone: chaptersFinished
                     || (tutorialTemplateDone && tutorialMakeTemplateDone && tutorialComboDone),
                 keyboardSetupDone: keyboardSetupDone,
                 keyboardUsable: KeyboardInstallState.isUsable)
    }

    /// 누른 뒤 **입력된 걸 보여주는** 시간(초).
    private let dwellAfterUse: Double = 0.9
    /// 첫 튜토리얼을 끝낸 뒤 다음을 권하기까지(초, 누른 시점 기준).
    private static let firstTutorialBreather: Double = 5.0
    /// 그 뒤의 장 사이 간격(초) — 리듬을 이미 아는 사람에겐 짧아도 된다.
    private static let nextChapterGap: Double = 0.45

    /// 아직 안 눌러 본 튜토리얼 단축어.
    private var highlightedMemoId: UUID? {
        firstUseMemoIdRaw.isEmpty ? nil : UUID(uuidString: firstUseMemoIdRaw)
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
                    // 만든 그 문구를 **무대에서 가리킨다** — 만들기만 하고 끝나면 아무것도 안 배운다.
                    onCreated: { memo in advanceFromFirstShortcut(created: memo) },
                    onSkip: { advanceFromFirstShortcut(created: nil) }
                )
                .transition(screenTransition)
            case .keyboardSetup:
                KeyboardSetupOnboardingView { keyboardSetupDone = true }
                    .transition(screenTransition)

            // ⚠️ 이 셋을 **한 분기로 묶는다.** 나눠 두면 단계가 바뀔 때 SwiftUI가 무대를
            //    다른 뷰로 보고 새로 만든다 — 그 순간 입력창을 들고 있던 객체도 새것이 되어
            //    **방금 넣은 글이 사라진다.** 눌러서 배운 결과가 눈앞에서 지워지는 셈이다.
            //    (가리키는 키는 뷰를 갈아 끼우지 않고 `highlightedMemoId` 값만 바뀌면 된다)
            case .tryInKeyboard, .chapters, .done:
                switch style {
                case .list:
                    // 전환 버튼은 목록의 **툴바 + 왼쪽**에 있다(ClipKeyboardList.toolbarButtons).
                    // 화면 위에 겹쳐 띄우면 카드를 가린다.
                    ClipKeyboardList()
                        .transition(screenTransition)
                case .keyboard:
                    InAppKeyboardStage(styleRaw: $styleRaw, highlightedMemoId: highlightedMemoId)
                        .transition(screenTransition)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: onboardingStep)
        // 두 화면은 **같은 자리에서 갈아 끼우는 것**이라 서로 밀어내지 않는다 —
        // 밀려 들어오면 어디로 이동한 것처럼 보이고, 여기서는 이동한 게 아니라 모습이 바뀐 것이다.
        // 살짝 줄었다 펴지는 것만 얹어 "바뀌었다"를 눈이 알아채게 한다.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: styleRaw)
        .onReceive(NotificationCenter.default.publisher(for: .memoUsed), perform: completeFirstUse)
        // 목록에서 '템플릿으로 만들기' 장이 끝났다 — 무대로 돌아와 다음 장으로 잇는다.
        .onReceive(NotificationCenter.default.publisher(for: .makeTemplateTutorialFinished)) { _ in
            tutorialMakeTemplateDone = true
            withAnimation(.easeInOut(duration: 0.28)) {
                styleRaw = SnippetsTabStyle.keyboard.rawValue
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { inviteNextChapter() }
        }
        // ⚠️ 다음 장을 권하는 건 **하프 모달**이다. 전체 화면으로 덮으면 하던 일이 사라져
        //    "또 뭘 시키나" 가 되지만, 반쯤 올라오면 뒤에 방금 만든 것이 보인 채로 묻는다 —
        //    권유는 이어지는 말이지 새 화면이 아니다.
        .sheet(item: $tutorialInvite) { chapter in
            TutorialInviteView(chapter: chapter) {
                tutorialInvite = nil
                // 시트가 겹치지 않게 한 박자 뒤에.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    if chapter == .makeTemplate {
                        // ⚠️ 이 장만은 목록에서 한다 — **고치는 일은 목록에서**라는 규칙 그대로다.
                        //    이미 있는 "템플릿으로 만들기" 화면을 그대로 태운다(전용 화면을 새로
                        //    배워봐야 정작 평소에 쓰는 메뉴는 여전히 낯설다).
                        //
                        // ⚠️ **여기서 끝난 것으로 표시하지 않는다.** 목록이 그 화면을 실제로
                        //    띄우고 닫았을 때가 끝이다. 미리 찍어 두면 화면이 안 떠도
                        //    지나간 것이 되어 그 장이 통째로 사라진다.
                        UserDefaults.standard.set(true, forKey: DefaultsKey.pendingMakeTemplateTutorial)
                        styleRaw = SnippetsTabStyle.list.rawValue
                        NotificationCenter.default.post(name: .startMakeTemplateTutorial, object: nil)
                    } else {
                        tutorialMaking = chapter
                    }
                }
            } onDecline: {
                tutorialInvite = nil
                // 거절도 답이다 — 다시 묻지 않고 다음 장으로.
                finishChapter(chapter)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $tutorialMaking) { chapter in
            switch chapter {
            case .template:
                TemplateTutorialView(onCreated: { chapterCreated($0, chapter: .template) },
                                     onSkip: { finishChapter(.template) })
            case .combo:
                ComboTutorialView(onCreated: { chapterCreated($0, chapter: .combo) },
                                  onSkip: { finishChapter(.combo) })
            case .makeTemplate:
                // 여기로 오지 않는다(위에서 목록으로 보낸다). 안전망.
                Color.clear.onAppear { tutorialMaking = nil }
            }
        }
        .onAppear {
            offerKeyboardStageIfNeeded()
            askCleanupIfFinished()
        }
        .onChange(of: onboardingStep) { _, step in
            guard step == .done else { return }
            // 마지막 걸음이 끝난 **그때** 묻는다 — 나중에 물으면 무엇에 대한 물음인지 모른다.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { askCleanupIfFinished() }
        }
        .alert(NSLocalizedString("연습으로 만든 단축어를 지울까요?", comment: "Tutorial cleanup alert title"),
               isPresented: $showCleanupPrompt) {
            Button(NSLocalizedString("지우기", comment: "Delete"), role: .destructive) {
                TutorialCreations.deleteAll()
            }
            Button(NSLocalizedString("그대로 둘게요", comment: "Keep tutorial creations"), role: .cancel) {
                TutorialCreations.forget()
            }
        } message: {
            Text(NSLocalizedString("튜토리얼을 따라 하며 만든 것들이에요. 계속 쓸 거면 그대로 두세요.",
                                   comment: "Tutorial cleanup alert message"))
        }
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
    ///
    /// 만들었으면 그 문구를 무대에서 가리키고(눌러 봐야 끝난다), 건너뛰었으면 가리킬 것이 없으니
    /// 바로 다음 걸음으로 간다.
    private func advanceFromFirstShortcut(created memo: Memo?) {
        if let memo {
            TutorialCreations.remember(memo.id)
            firstUseMemoIdRaw = memo.id.uuidString
            // 만든 것을 눌러 보려면 무대에 있어야 한다.
            styleRaw = SnippetsTabStyle.keyboard.rawValue
        }
        withAnimation(.easeInOut(duration: 0.28)) { firstShortcutDone = true }
    }

    /// 가리킨 키를 실제로 눌렀다 — 이 장 끝. 곧바로 다음 장을 권한다.
    ///
    /// 첫 단축어든 방금 만든 템플릿·콤보든 같은 규칙이다 — **만들고 한 번 써 봐야** 끝난다.
    ///
    /// ⚠️ 아무 문구나 눌러도 끝난 것으로 치지 않는다. **그 문구**를 눌러야 한다 —
    ///    가리킨 것과 다른 걸 눌렀는데 안내가 사라지면 무엇 때문에 끝났는지 알 수 없다.
    private func completeFirstUse(_ note: Notification) {
        guard let used = note.userInfo?[MemoUsedKey.memoID] as? UUID,
              used == highlightedMemoId else { return }

        // 아직 아무 장도 안 지났으면 이번이 **첫 번째** 튜토리얼이다.
        let isFirstTutorial = !tutorialTemplateDone && !tutorialMakeTemplateDone && !tutorialComboDone

        // ⚠️ 넘기기 전에 **입력된 걸 보여준다.** 누르자마자 화면이 바뀌면 방금 무슨 일이
        //    일어났는지 못 보고 지나간다 — 이 튜토리얼이 알려주려던 게 바로 그 장면이다.
        DispatchQueue.main.asyncAfter(deadline: .now() + dwellAfterUse) {
            withAnimation(.easeInOut(duration: 0.28)) { firstUseMemoIdRaw = "" }
            // ⚠️ **무대에 그대로 머문다.** 화면을 옮기면 방금 익힌 자리가 사라져서
            //    배우던 흐름이 끊긴 것처럼 느껴진다. 다음 장은 이 화면 **위에** 열린다.
            //
            // ⚠️ 첫 번째 뒤에는 **한 박자 더 쉰다**(눌렀을 때부터 5초). 방금 처음으로
            //    "눌렀더니 글이 들어갔다"를 본 참인데 곧바로 다음 걸 권하면 그 장면을
            //    음미할 틈이 없고, 배우는 게 아니라 떠밀리는 느낌이 된다.
            let breather = isFirstTutorial
                ? Self.firstTutorialBreather - dwellAfterUse
                : Self.nextChapterGap
            DispatchQueue.main.asyncAfter(deadline: .now() + breather) { inviteNextChapter() }
        }
    }

    // MARK: - 배우는 장들 (무대 위에서 연다)

    /// 아직 안 지난 다음 장. 없으면 nil.
    private var nextChapter: TutorialChapter? {
        TutorialChapter.allCases.first { chapter in
            switch chapter {
            case .template:     return !tutorialTemplateDone
            case .makeTemplate: return !tutorialMakeTemplateDone
            case .combo:        return !tutorialComboDone
            }
        }
    }

    /// 다음 장을 권한다. 더 없으면 배우는 차례가 끝난 것으로 표시한다
    /// (그래야 마지막 걸음인 키보드 설정으로 넘어간다).
    private func inviteNextChapter() {
        guard let next = nextChapter else {
            withAnimation(.easeInOut(duration: 0.28)) { chaptersFinished = true }
            return
        }
        tutorialInvite = next
    }

    private func markChapterDone(_ chapter: TutorialChapter) {
        switch chapter {
        case .template:     tutorialTemplateDone = true
        case .makeTemplate: tutorialMakeTemplateDone = true
        case .combo:        tutorialComboDone = true
        }
    }

    /// 장에서 **무언가를 만들었다** — 다음 장으로 곧장 넘기지 않는다.
    ///
    /// ⚠️ 만들기만 하고 넘어가면 "저장했다"로 끝난다. 첫 단축어에 세운 규칙과 같다 —
    ///    **한 번 눌러 봐야** 왜 만들었는지를 안다. 그래서 무대에서 그 키를 가리키고,
    ///    누르는 순간(`completeFirstUse`) 다음 장을 권한다.
    private func chapterCreated(_ memo: Memo, chapter: TutorialChapter) {
        TutorialCreations.remember(memo.id)
        tutorialMaking = nil
        markChapterDone(chapter)
        firstUseMemoIdRaw = memo.id.uuidString
        // 가리킨 키를 보려면 무대에 있어야 한다.
        styleRaw = SnippetsTabStyle.keyboard.rawValue
    }

    /// 장을 마쳤다(건너뛰었거나 만들 것이 없었다) — 한 박자 뒤 다음 장으로.
    private func finishChapter(_ chapter: TutorialChapter) {
        tutorialMaking = nil
        markChapterDone(chapter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { inviteNextChapter() }
    }

    /// 튜토리얼을 다 지났고 만든 것이 남아 있으면 **한 번만** 묻는다.
    ///
    /// ⚠️ 만든 것이 없으면(전부 건너뛴 경우) 묻지 않는다 — 지울 것도 없는데 물으면
    ///    무엇을 지운다는 건지 모를 물음이 된다.
    private func askCleanupIfFinished() {
        guard !cleanupAsked, onboardingStep == .done, !TutorialCreations.all.isEmpty else { return }
        cleanupAsked = true
        showCleanupPrompt = true
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
