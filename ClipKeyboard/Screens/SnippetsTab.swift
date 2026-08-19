//
//  SnippetsTab.swift
//  ClipKeyboard
//
//  단축어 탭이 무엇을 보여줄지 고르는 자리 - **목록** 이냐 **키보드 무대** 냐.
//
//  ⚠️ 쓰던 사람의 첫 화면은 업데이트로 바뀌지 않는다. 저장된 값이 없으면 목록이고,
//     새 설치에만 첫 실행에서 무대를 뿌린다. 기존 사용자에게는 **한 번 권하고 끝**이다
//     ([[LivingSkin]]·배경 제안과 같은 규칙 - 권할 때마다 빠져나갈 수 있어야 한다).
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

    /// 저장된 값이 없으면 **목록** - 쓰던 사람 쪽에 맞춘 기본값이다.
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

    /// 하단 탭바에 적히는 **짧은** 이름.
    ///
    /// ⚠️ `localizedName`("단축어 목록"·"키보드 화면")과 일부러 다르다. 그쪽은 설정에서
    ///    두 선택지를 견주어 고르는 자리라 길어도 되지만, 탭바는 네 칸을 나눠 쓰는 자리라
    ///    긴 이름은 말줄임으로 잘려 오히려 무슨 화면인지 알 수 없게 된다.
    var tabName: String {
        switch self {
        case .list:     return NSLocalizedString("목록", comment: "Tab: snippets showing the list")
        case .keyboard: return NSLocalizedString("키보드", comment: "Tab: snippets showing the keyboard stage")
        }
    }

    var symbolName: String {
        switch self {
        case .list:     return "square.grid.2x2"
        case .keyboard: return "keyboard"
        }
    }

    /// 반대쪽 화면. 툴바의 전환 버튼과 탭바 다시 누르기가 **같은 규칙**을 쓰도록 여기 둔다.
    var toggled: SnippetsTabStyle {
        self == .list ? .keyboard : .list
    }
}

// MARK: - 처음 쓰는 사람이 지나는 길

/// 첫 흐름의 **지금 어디쯤**인가.
///
/// ⚠️ 세 걸음이 **끊기지 않고 이어져야** 한다
///    ① 무엇이 준비돼 있는지 보고 ② 그것들을 하나씩 눌러 보고 ③ 키보드를 켠다.
///
/// ⚠️ 여기서 **아무것도 만들게 하지 않는다.** 예전에는 ①이 "첫 단축어 만들기"였고
///    ②의 자리에 템플릿·콤보를 차례로 만드는 장이 셋 더 있었다. 처음 온 사람에게
///    빈 칸을 네 번 내미는 일이었다 - 만드는 법보다 **무엇을 해주는 물건인지**가 먼저다.
///    쓸 것은 설치 첫 실행에 이미 넣어 두었다(`performSampleInsertion`).
///
/// ⚠️ 쓰던 사람은 이 길을 걷지 않는다(`startedFresh`).
enum SnippetsOnboardingStep: Equatable {
    /// ① 무엇을 넣어 뒀는지 알린다.
    case welcome
    /// ② 넣어 둔 것을 **무대에서 차례로 눌러 본다** (단축어 → 템플릿 → 콤보).
    case tryScenarios
    /// ③ 마지막에 진짜 키보드 켜기 - 이미 켜져 있으면 건너뛴다.
    case keyboardSetup
    /// 다 지났다. 평소 화면으로.
    case done

    /// 순서: 환영 → 써 보기 → 키보드 설정.
    ///
    /// ⚠️ 키보드 설정이 **맨 뒤**인 이유: 설정 앱으로 나갔다 오는 일이라 흐름이 가장 크게 끊긴다.
    ///    써 볼 것을 다 써 본 뒤에 "이제 다른 앱에서도 쓰려면" 으로 이어져야 나갔다 돌아올 이유가
    ///    분명하다. (무대에서 눌러 보는 데에는 진짜 키보드가 켜져 있을 필요가 없다.)
    static func current(startedFresh: Bool,
                        welcomeDone: Bool,
                        chaptersDone: Bool,
                        keyboardSetupDone: Bool,
                        keyboardUsable: Bool) -> SnippetsOnboardingStep {
        guard startedFresh else { return .done }
        if !welcomeDone { return .welcome }
        if !chaptersDone { return .tryScenarios }
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
/// 고른 값은 그대로 저장된다(설정 > 첫 화면과 같은 값) - 다음에 열면 마지막에 본 쪽이 나온다.
struct SnippetsStyleSwitchButton: View {
    /// 유리 서클 버튼들 사이 간격 - **목록 툴바와 무대 머리말이 같은 값을 쓴다.**
    ///
    /// ⚠️ 두 곳이 제각각이던 것을 여기로 모았다. 목록은 `-8`(서클이 8pt 겹침),
    ///    무대는 `14`(넉넉히 떨어짐)라, 같은 버튼 쌍이 화면마다 다른 물건처럼 보였다.
    ///    음수 간격은 44pt 서클끼리 실제로 겹쳐서 두 개가 한 덩어리로 읽힌다.
    static let clusterSpacing: CGFloat = 6

    /// 유리 서클의 지름 - 버튼을 새로 만들 때 이 값을 쓸 것.
    static let diameter: CGFloat = 44

    @Binding var styleRaw: String

    private var current: SnippetsTabStyle { SnippetsTabStyle(rawValue: styleRaw) ?? .list }
    /// 탭바를 다시 누르는 것과 **같은 규칙**을 쓴다(`SnippetsTabStyle.toggled`).
    /// 두 길이 다른 곳으로 가면 같은 자리에서 누를 때마다 결과가 달라진다.
    private var target: SnippetsTabStyle { current.toggled }

    var body: some View {
        Button {
            HapticManager.shared.light()
            withAnimation(.easeInOut(duration: 0.2)) { styleRaw = target.rawValue }
        } label: {
            // 툴바의 + 와 **같은 유리 언어** - 클리어 글래스 서클(하단 탭바와도 같다).
            // 옆에 나란히 선 버튼이 하나만 맨몸이면 그것만 다른 앱에서 온 것처럼 보인다.
            Image(systemName: target.symbolName)
                .font(.body.weight(.semibold))
                .foregroundColor(.accentColor)
                .frame(width: Self.diameter, height: Self.diameter)
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
    /// 환영 화면을 지났는가(시작했든 나중에 보기로 했든).
    @AppStorage(DefaultsKey.tutorialWelcomeDone) private var welcomeDone: Bool = false
    /// 이 기기가 4.4.4 이후로 처음 시작했는가 - 쓰던 사람에게 튜토리얼을 다시 깔지 않기 위한 표식.
    @AppStorage(DefaultsKey.startedFreshV444) private var startedFresh: Bool = false
    /// 키보드 켜기 안내까지 지나왔는가(끝냈든 건너뛰었든).
    @AppStorage(DefaultsKey.keyboardSetupTutorialDone) private var keyboardSetupDone: Bool = false
    /// 지금 무대에서 가리키고 있는 단축어 id - 아직 안 눌러 봤으면 값이 남아 있다.
    @AppStorage(DefaultsKey.tutorialFirstUseMemoId) private var firstUseMemoIdRaw: String = ""
    /// 써 보는 장(단축어 → 템플릿 → 콤보) 완료 표식.
    @AppStorage(DefaultsKey.tutorialSnippetDone) private var tutorialSnippetDone: Bool = false
    @AppStorage(DefaultsKey.tutorialTemplateDone) private var tutorialTemplateDone: Bool = false
    @AppStorage(DefaultsKey.tutorialComboDone) private var tutorialComboDone: Bool = false
    /// 챕터 기계가 "더 가리킬 것이 없다"고 알려주면 켜진다.
    @AppStorage(DefaultsKey.tutorialChaptersDone) private var chaptersFinished: Bool = false

    @State private var showOffer = false
    /// 다음 장까지 도는 원이 끝나는 시각. nil 이면 안 보인다.
    @State private var countdownEndsAt: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var theme

    /// 화면이 갈아 끼워질 때의 모습 - 자리를 옮기지 않고 그 자리에서 바뀐다.
    private var screenTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.985))
    }

    private var style: SnippetsTabStyle { SnippetsTabStyle(rawValue: styleRaw) ?? .list }

    /// 지금 첫 흐름의 어디쯤인가(위 `SnippetsOnboardingStep` 참고).
    private var onboardingStep: SnippetsOnboardingStep {
        .current(startedFresh: startedFresh,
                 welcomeDone: welcomeDone,
                 chaptersDone: chaptersFinished
                     || (tutorialSnippetDone && tutorialTemplateDone && tutorialComboDone),
                 keyboardSetupDone: keyboardSetupDone,
                 keyboardUsable: KeyboardInstallState.isUsable)
    }

    /// 누른 뒤 **입력된 걸 보여주는** 시간(초).
    private let dwellAfterUse: Double = 0.9
    /// 장과 장 사이 쉼(초). 이 동안 카운트다운 원이 돈다.
    static let chapterBreather: Double = 5.0

    /// 아직 안 눌러 본, 지금 가리키는 단축어.
    private var highlightedMemoId: UUID? {
        firstUseMemoIdRaw.isEmpty ? nil : UUID(uuidString: firstUseMemoIdRaw)
    }

    var body: some View {
        // 두 화면 **뒤에 같은 바닥**을 깐다. 각 화면이 자기 배경을 칠하면 갈아 끼우는 순간
        // 바닥색이 한 번 바뀌어 번쩍인다 - 바뀌는 건 그 위에 놓인 것뿐이어야 한다.
        ZStack {
            theme.bg.ignoresSafeArea()
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch onboardingStep {
            case .welcome:
                TutorialWelcomeView(
                    onStart: { startTutorial() },
                    onSkip: { skipTutorial() }
                )
                .transition(screenTransition)
            case .keyboardSetup:
                KeyboardSetupOnboardingView { keyboardSetupDone = true }
                    .transition(screenTransition)

            // ⚠️ 이 둘을 **한 분기로 묶는다.** 나눠 두면 단계가 바뀔 때 SwiftUI가 무대를
            //    다른 뷰로 보고 새로 만든다 - 그 순간 입력창을 들고 있던 객체도 새것이 되어
            //    **방금 넣은 글이 사라진다.** 눌러서 배운 결과가 눈앞에서 지워지는 셈이다.
            //    (가리키는 키는 뷰를 갈아 끼우지 않고 `highlightedMemoId` 값만 바뀌면 된다)
            case .tryScenarios, .done:
                switch style {
                case .list:
                    // 전환 버튼은 목록의 **툴바 + 왼쪽**에 있다(ClipKeyboardList.toolbarButtons).
                    // 화면 위에 겹쳐 띄우면 카드를 가린다.
                    ClipKeyboardList()
                        .transition(screenTransition)
                case .keyboard:
                    InAppKeyboardStage(styleRaw: $styleRaw,
                                       highlightedMemoId: highlightedMemoId,
                                       tutorialLine: nextChapter?.coachLine)
                        .transition(screenTransition)
                }
            }
        }
        // 장과 장 사이의 원 - 아래쪽에 잠깐 떠 있다가 스스로 사라진다.
        // 무대 위에 얹되 누를 수 없어서, 뒤에서 하던 것을 가리지 않는다.
        .overlay(alignment: .bottom) {
            if let endsAt = countdownEndsAt {
                NextChapterCountdown(endsAt: endsAt, total: Self.chapterBreather)
                    .padding(.bottom, 92)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: onboardingStep)
        // 두 화면은 **같은 자리에서 갈아 끼우는 것**이라 서로 밀어내지 않는다
        // 밀려 들어오면 어디로 이동한 것처럼 보이고, 여기서는 이동한 게 아니라 모습이 바뀐 것이다.
        // 살짝 줄었다 펴지는 것만 얹어 "바뀌었다"를 눈이 알아채게 한다.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: styleRaw)
        .onReceive(NotificationCenter.default.publisher(for: .memoUsed), perform: completeChapter)
        .onAppear {
            offerKeyboardStageIfNeeded()
            resumeTutorialIfStalled()
        }
        // 걸음이 바뀌어 무대로 들어왔는데 가리키는 것이 없으면 여기서 이어 붙인다.
        .onChange(of: onboardingStep) { _, _ in resumeTutorialIfStalled() }
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

    // MARK: - 써 보는 장들 (무대 위에서 돈다)

    /// 아직 안 지난 다음 장. 없으면 nil.
    private var nextChapter: TutorialChapter? {
        TutorialChapter.allCases.first { chapter in
            switch chapter {
            case .snippet:  return !tutorialSnippetDone
            case .template: return !tutorialTemplateDone
            case .combo:    return !tutorialComboDone
            }
        }
    }

    /// 앱을 껐다 켰는데 **가리키는 것이 없는 채로** 써 보는 차례에 서 있으면 이어 붙인다.
    ///
    /// ⚠️ 없으면 튜토리얼이 거기서 멈춘다. 장과 장 사이 5초 동안 앱을 끄면 가리키던 표식은
    ///    이미 비워졌고 다음 장은 아직 안 켜졌다 - 다시 열었을 때 아무 일도 안 일어난다.
    private func resumeTutorialIfStalled() {
        guard onboardingStep == .tryScenarios,
              highlightedMemoId == nil,
              countdownEndsAt == nil else { return }
        openNextChapter()
    }

    /// 환영 화면에서 "눌러볼게요" - 무대로 옮기고 첫 장을 연다.
    private func startTutorial() {
        withAnimation(.easeInOut(duration: 0.28)) {
            welcomeDone = true
            // 가리킨 키를 보려면 무대에 있어야 한다.
            styleRaw = SnippetsTabStyle.keyboard.rawValue
        }
        openNextChapter()
    }

    /// "나중에 볼게요" - 남은 장을 다 지난 것으로 두고 평소 화면으로.
    ///
    /// ⚠️ 개별 표식을 켜지 않고 `chaptersFinished` 만 켠다. 나중에 설정에서 다시 하기를
    ///    누르면 그 표식만 지우면 되므로, 건너뛴 사람과 다 해 본 사람의 길이 같아진다.
    private func skipTutorial() {
        withAnimation(.easeInOut(duration: 0.28)) {
            welcomeDone = true
            chaptersFinished = true
        }
    }

    /// 다음 장을 연다 - **가리킬 카드를 찾아 무대의 그 키에 불을 켠다.**
    ///
    /// ⚠️ 가리킬 것이 없으면(사용자가 그 종류를 지웠다면) 조용히 건너뛴다. 없는 카드를
    ///    가리키며 누르라고 하면 튜토리얼이 거기서 멈춘 것처럼 보인다.
    private func openNextChapter() {
        guard let chapter = nextChapter else {
            withAnimation(.easeInOut(duration: 0.28)) { chaptersFinished = true }
            return
        }
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        guard let memo = TutorialScenarios.memo(for: chapter, in: memos) else {
            print("⏭️ [SnippetsTab] \(chapter.rawValue) 장에 가리킬 것이 없어 건너뜁니다")
            markChapterDone(chapter)
            openNextChapter()
            return
        }
        withAnimation(.easeInOut(duration: 0.28)) {
            firstUseMemoIdRaw = memo.id.uuidString
        }
    }

    /// 가리킨 키를 실제로 눌렀다 - 이 장 끝. 한 박자 쉬고 다음 장으로.
    ///
    /// ⚠️ 아무 문구나 눌러도 끝난 것으로 치지 않는다. **그 문구**를 눌러야 한다
    ///    가리킨 것과 다른 걸 눌렀는데 안내가 사라지면 무엇 때문에 끝났는지 알 수 없다.
    private func completeChapter(_ note: Notification) {
        guard let used = note.userInfo?[MemoUsedKey.memoID] as? UUID,
              used == highlightedMemoId,
              let chapter = nextChapter else { return }

        // ⚠️ 넘기기 전에 **입력된 걸 보여준다.** 누르자마자 화면이 바뀌면 방금 무슨 일이
        //    일어났는지 못 보고 지나간다 - 이 튜토리얼이 알려주려던 게 바로 그 장면이다.
        DispatchQueue.main.asyncAfter(deadline: .now() + dwellAfterUse) {
            withAnimation(.easeInOut(duration: 0.28)) { firstUseMemoIdRaw = "" }
            markChapterDone(chapter)
            // ⚠️ **무대에 그대로 머문다.** 화면을 옮기면 방금 익힌 자리가 사라져서
            //    배우던 흐름이 끊긴 것처럼 느껴진다. 다음 장은 이 화면 **위에서** 이어진다.
            //
            // ⚠️ 곧바로 다음 걸 켜지 않는다. 방금 "눌렀더니 글이 들어갔다"를 본 참인데
            //    바로 다음이 빛나면 그 장면을 음미할 틈이 없고, 배우는 게 아니라
            //    떠밀리는 느낌이 된다. 쉬는 동안은 카운트다운 원이 대신 말해 준다.
            scheduleNextChapter()
        }
    }

    /// 장과 장 사이의 쉼. 남은 시간을 원으로 보여주고, 다 돌면 다음 장을 연다.
    ///
    /// ⚠️ 예전에는 곳마다 0.45~0.6초씩 제각각 기다렸다가 곧바로 다음 걸 띄웠다.
    ///    그 사이 화면은 아무 말도 안 해서 끝난 건지 멈춘 건지 알 수 없었다.
    ///    이제 **모든 장 사이가 같은 5초**이고, 그동안 원이 돈다.
    private func scheduleNextChapter() {
        guard nextChapter != nil else {
            openNextChapter()      // 더 없으면 곧바로 마무리한다 - 셀 이유가 없다.
            return
        }
        let gap = Self.chapterBreather
        countdownEndsAt = Date().addingTimeInterval(gap)
        DispatchQueue.main.asyncAfter(deadline: .now() + gap) {
            withAnimation(.easeOut(duration: 0.2)) { countdownEndsAt = nil }
            openNextChapter()
        }
    }

    private func markChapterDone(_ chapter: TutorialChapter) {
        switch chapter {
        case .snippet:  tutorialSnippetDone = true
        case .template: tutorialTemplateDone = true
        case .combo:    tutorialComboDone = true
        }
    }

    /// 쓰던 사람에게 **한 번만** 권한다.
    ///
    /// 새 설치는 이미 무대로 시작하므로 권할 일이 없고, 한 번 권한 뒤에는
    /// 고르든 넘기든 다시 묻지 않는다. 설정에 자리가 있으므로 언제든 바꿀 수 있다.
    private func offerKeyboardStageIfNeeded() {
        guard !offered, style == .list else { return }
        offered = true
        // 화면이 자리를 잡은 뒤에 - 열자마자 알림이 뜨면 무엇에 대한 물음인지 안 보인다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showOffer = true
        }
    }
}
