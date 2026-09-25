//
//  KeyboardSetupOnboardingView.swift
//  ClipKeyboard
//
//  Tips 앱 스타일 단계별 키보드 설정 가이드
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Main View

/// 이 기기에서 우리 키보드를 **쓸 수 있는 상태인가.**
///
/// ⚠️ 신호가 두 개이고 **둘 다 봐야 한다.**
///  ① iOS 설정에서 켰는가 - `AppleKeyboards`(켜 둔 키보드 목록)에 우리 번들이 있는지.
///     설정에서 켜자마자 참이 된다.
///  ② 실제로 한 번 떠 봤는가 - 익스텐션이 처음 뜰 때 App Group에 남기는 표식.
///     켜 두기만 하고 아직 아무 앱에서도 안 불러냈다면 거짓이다.
///
/// 예전에는 ②만 봤다. 그래서 **설정에서 켜고 전체 접근까지 허용하고 돌아와도**
/// "아직 다른 앱에서는 못 써요" 가 그대로 남아 있었다 - 켰는데 안 켜졌다고 우기는 꼴이다.
/// 어느 쪽이든 참이면 쓸 수 있는 상태로 본다.
enum KeyboardInstallState {

    /// 키보드 익스텐션 번들 ID. 앱 번들 ID + `.ClipKeyboardExtension`.
    static let extensionBundleID = "com.Ysoup.TokenMemo.ClipKeyboardExtension"

    /// iOS 설정에서 이 키보드를 켜 두었는가.
    ///
    /// `AppleKeyboards` 는 시스템이 각 앱의 표준 UserDefaults 에 비춰 주는 값이라
    /// 별도 권한 없이 읽을 수 있다. 못 읽는 상황이면 판단을 미루고 `false`.
    static var isEnabledInSettings: Bool {
        enabledInSettingsIfKnown ?? false
    }

    /// 설정에서 켰는가를 **알 수 있으면** 그 값, 목록을 못 읽으면 nil.
    ///
    /// 사용 통계가 쓴다. `isEnabledInSettings` 는 못 읽을 때 `false` 로 떨어져서,
    /// 그대로 보내면 "안 켰다"와 "모른다"가 한 칸에 섞인다.
    static var enabledInSettingsIfKnown: Bool? {
        guard let keyboards = UserDefaults.standard.array(forKey: "AppleKeyboards") as? [String] else {
            return nil
        }
        return keyboards.contains(extensionBundleID)
    }

    /// 익스텐션이 한 번이라도 떠 본 적 있는가(App Group 표식).
    ///
    /// ⚠️ **한 번 켜지면 영영 안 꺼지는 걸쇠다.** 익스텐션이 뜰 때 `true` 로 적고,
    ///    지우는 코드는 어디에도 없다. 지울 수도 없다 - 키보드를 설정에서 뺐다는 것을
    ///    익스텐션이 알 길이 없기 때문이다(빠진 익스텐션은 뜨지 않는다).
    static var didLoadOnce: Bool {
        AppGroup.defaults?
            .bool(forKey: DefaultsKey.keyboardExtensionDidLoad) ?? false
    }

    /// 지금 이 키보드를 다른 앱에서 쓸 수 있는가.
    ///
    /// ⚠️ 예전에는 `isEnabledInSettings || didLoadOnce` 였다. **한 번이라도 키보드를
    ///    띄워 본 사람에게는 이 값이 영영 참**이라, 나중에 설정에서 키보드를 빼도 앱은
    ///    계속 "켜져 있다"고 믿었다. 그 사람은 무대에서 켜라는 안내를 다시는 못 받는다.
    ///    (실제로 그렇게 신고가 들어왔다 - "설정 안 했는데 왜 안내가 안 뜨지")
    ///
    /// ⚠️ 그래서 **읽을 수 있으면 `AppleKeyboards` 가 진실이다.** 걸쇠는 그 값을 못 읽는
    ///    상황에서만 대신 쓴다. 못 읽는데 걸쇠도 없으면 "아직" 으로 보고 안내를 띄운다
    ///    - 켜 둔 사람을 한 번 귀찮게 하는 것보다, 못 켠 사람을 영영 놓치는 쪽이 나쁘다.
    static var isUsable: Bool {
        usable(enabledKeyboards: UserDefaults.standard.array(forKey: "AppleKeyboards") as? [String],
               didLoadOnce: didLoadOnce)
    }

    /// 위 규칙만 떼어 낸 것 - 시험에서 값을 넣어 볼 수 있게 한다.
    /// - Parameter enabledKeyboards: `AppleKeyboards` 값. 못 읽었으면 nil.
    static func usable(enabledKeyboards: [String]?, didLoadOnce: Bool) -> Bool {
        if let enabledKeyboards {
            return enabledKeyboards.contains(extensionBundleID)
        }
        return didLoadOnce
    }
}

struct KeyboardSetupOnboardingView: View {
    var exitAction: () -> Void

    @State private var currentPage = 0
    @State private var setupStatus: SetupStatus = .idle
    @State private var isWaitingForReturn = false
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum SetupStatus { case idle, checking, confirmed, notFound }

    private let steps = SetupStep.all

    var body: some View {
        ZStack(alignment: .top) {
            theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button row
                HStack {
                    Spacer()
                    Button(action: exitAction) {
                        Image(systemName: AppSymbol.xmark)
                            .font(.callout.weight(.semibold))
                            .foregroundColor(theme.textMuted)
                            .padding(9)
                            .background(theme.surfaceAlt)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(NSLocalizedString("닫기", comment: "Close"))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)

                // Step pages
                TabView(selection: $currentPage) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                        StepPageView(step: step, setupStatus: setupStatus, theme: theme)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: currentPage)

                // Bottom controls
                VStack(spacing: 16) {
                    // Page dots
                    HStack(spacing: 5) {
                        ForEach(0..<steps.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage ? theme.accent : theme.divider)
                                .frame(width: i == currentPage ? 22 : 7, height: 7)
                                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(format: NSLocalizedString("%d단계 중 %d단계", comment: "Step X of Y"), currentPage + 1, steps.count))

                    // Action buttons
                    HStack(spacing: 12) {
                        // "설정 열기" 버튼 - step 2(index 1)와 step 3(index 2)에서 표시
                        if currentPage == 1 || currentPage == 2 {
                            Button(action: openSettings) {
                                HStack(spacing: 6) {
                                    Image(systemName: AppSymbol.gear)
                                        .accessibilityHidden(true)
                                    Text(NSLocalizedString("설정 열기", comment: "Open Settings button"))
                                }
                                .font(.headline)
                                .foregroundColor(theme.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(theme.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                            }
                        }

                        // Next / Done
                        if currentPage == 2 {
                            // ⚠️ 여기서 **말로 넘어가지 않는다.** 예전에는 "설정 완료"를 누르면
                            //    그대로 다음 장으로 갔다. 설정에 다녀오지 않은 사람도 눌렀고,
                            //    그러면 켜지지도 않은 채로 "다 됐다"가 되었다.
                            //    이제 누르면 **실제로 켜졌는지 본다.**
                            Button(action: verifySetup) {
                                Text(NSLocalizedString("네, 켰어요", comment: "Setup confirm button"))
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(theme.accentFg)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(theme.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                            }
                        } else if currentPage < steps.count - 1 {
                            Button {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                                    currentPage += 1
                                }
                            } label: {
                                Text(NSLocalizedString("다음", comment: "Next button"))
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(theme.accentFg)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(theme.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                            }
                        } else {
                            Button(action: exitAction) {
                                Text(NSLocalizedString("시작하기", comment: "Get started button"))
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(theme.accentFg)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(theme.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            guard isWaitingForReturn, currentPage == 2 else { return }
            isWaitingForReturn = false
            setupStatus = .checking
            // 설정에서 켜기만 해도 확인된 것으로 본다(KeyboardInstallState 머리말 참고).
            let loaded = KeyboardInstallState.isUsable
            withAnimation(.easeInOut(duration: 0.3)) {
                setupStatus = loaded ? .confirmed : .notFound
            }
            if loaded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { currentPage = steps.count - 1 }
                }
            }
        }
    }

    /// "네, 켰어요" - **말이 아니라 사실을 본다.**
    ///
    /// ⚠️ 못 찾았다고 나무라지 않는다. 켜는 자리가 헷갈리는 것은 흔한 일이고,
    ///    여기서 "안 하셨네요"로 읽히면 사람은 화면을 닫는다. 어디가 막혔는지
    ///    한 줄로 다시 알려 주고 그 자리에 세워 둔다.
    private func verifySetup() {
        withAnimation(.easeInOut(duration: 0.2)) { setupStatus = .checking }
        // 시스템이 `AppleKeyboards` 를 비추는 데 한 박자 걸린다 - 곧바로 물으면 방금 켠 것도 못 본다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            let on = KeyboardInstallState.isUsable
            withAnimation(.easeInOut(duration: 0.3)) {
                setupStatus = on ? .confirmed : .notFound
                if on { currentPage = steps.count - 1 }
            }
        }
    }

    private func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
            isWaitingForReturn = true
        }
        #endif
    }
}

// MARK: - Step Data

struct SetupStep {
    let title: String
    let description: String
    let path: [String]       // 경로 표시용 (예: ["설정", "일반", "키보드"])
    let kind: Kind

    enum Kind {
        case welcome
        case addKeyboard
        case fullAccess
        case done
    }

    static let all: [SetupStep] = [
        SetupStep(
            title: NSLocalizedString("키보드를 추가해요", comment: "Setup step 1 title"),
            description: NSLocalizedString("iPhone 설정에서 ClipKeyboard 키보드를 추가하세요. 딱 한 번만 하면 됩니다.", comment: "Setup step 1 description"),
            path: [
                NSLocalizedString("설정", comment: "iOS Settings"),
                NSLocalizedString("일반", comment: "iOS Settings: General"),
                NSLocalizedString("키보드", comment: "iOS Settings: Keyboard"),
                NSLocalizedString("새로운 키보드 추가…", comment: "iOS Settings: Add New Keyboard")
            ],
            kind: .addKeyboard
        ),
        SetupStep(
            title: NSLocalizedString("ClipKeyboard를 선택해요", comment: "Setup step 2 title"),
            description: NSLocalizedString("서드파티 키보드 목록에서 'ClipKeyboard'를 찾아 탭하세요.", comment: "Setup step 2 description"),
            path: [
                NSLocalizedString("ClipKeyboard", comment: "Keyboard name in list")
            ],
            kind: .addKeyboard
        ),
        SetupStep(
            title: NSLocalizedString("전체 접근을 허용해요", comment: "Setup step 3 title"),
            // ⚠️ 이 걸음에서 가장 많이 멈춘다("키보드가 내 카톡을 읽나?"). 왜 필요한지와 함께
            //    **무엇을 안 하는지**를 같이 말한다(docs/product/PERSONA_JOURNEY_MAP.html 7단계).
            description: NSLocalizedString("키보드 목록에서 ClipKeyboard를 탭한 후, '전체 접근 허용'을 켜주세요.\n앱에 저장한 단축어를 키보드가 꺼내 오려면 필요해요. 치시는 글자는 기기 밖으로 보내지 않아요.", comment: "Setup step 3 description: why Full Access is needed and reassurance that typed text never leaves the device"),
            path: [
                NSLocalizedString("ClipKeyboard", comment: "Keyboard name"),
                NSLocalizedString("전체 접근 허용", comment: "Allow Full Access toggle")
            ],
            kind: .fullAccess
        ),
        SetupStep(
            title: NSLocalizedString("준비 완료!", comment: "Setup done title"),
            description: NSLocalizedString("이제 키보드에서 단축어를 바로 불러올 수 있어요.\n키보드를 열고 🌐를 길게 눌러 ClipKeyboard로 전환하세요.", comment: "Setup done description"),
            path: [],
            kind: .done
        )
    ]
}

// MARK: - Single Step Page

private struct StepPageView: View {
    let step: SetupStep
    let setupStatus: KeyboardSetupOnboardingView.SetupStatus
    let theme: AppTheme

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Illustration
                illustrationArea
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .background(theme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg))
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                // Text content
                VStack(alignment: .leading, spacing: 12) {
                    Text(step.title)
                        .font(.title2.weight(.bold))
                        .foregroundColor(theme.text)

                    Text(step.description)
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    if !step.path.isEmpty && step.kind != .done {
                        pathCard
                    }

                    if step.kind == .fullAccess {
                        setupStatusBadge
                    }

                    privacyNote
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: Illustration

    @ViewBuilder
    private var illustrationArea: some View {
        switch step.kind {
        case .welcome:
            EmptyView()

        case .addKeyboard:
            if step.path.count > 1 {
                // Step 1: Settings path illustration
                SettingsPathIllustration(
                    path: [
                        NSLocalizedString("설정", comment: "iOS Settings"),
                        NSLocalizedString("일반", comment: "General"),
                        NSLocalizedString("키보드", comment: "Keyboard"),
                        NSLocalizedString("새로운 키보드 추가…", comment: "Add New Keyboard")
                    ],
                    theme: theme
                )
            } else {
                // Step 2: keyboard list with ClipKeyboard highlighted
                KeyboardListIllustration(theme: theme)
            }

        case .fullAccess:
            FullAccessIllustration(theme: theme)

        case .done:
            DoneIllustration(theme: theme)
        }
    }

    // MARK: Path Card

    private var pathCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(step.path.enumerated()), id: \.offset) { i, item in
                HStack(spacing: 10) {
                    if step.kind == .fullAccess && i == step.path.count - 1 {
                        // Toggle ON
                        RoundedRectangle(cornerRadius: theme.radiusSm)
                            .fill(theme.success)
                            .frame(width: 40, height: 24)
                            .overlay(
                                Circle()
                                    .fill(.white)
                                    .frame(width: 20, height: 20)
                                    .offset(x: 8)
                            )
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: i == step.path.count - 1 ? "checkmark.circle.fill" : "arrow.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(i == step.path.count - 1 ? Color.checkGreen : theme.accent)
                            .accessibilityHidden(true)
                    }

                    Text(item)
                        .font(i == step.path.count - 1 ? .subheadline.weight(.semibold) : .subheadline)
                        .foregroundColor(i == step.path.count - 1 ? theme.text : theme.textMuted)
                }
                .padding(.vertical, 8)

                if i < step.path.count - 1 {
                    Divider()
                        .padding(.leading, 34)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
    }

    // MARK: Setup Status

    @ViewBuilder
    private var setupStatusBadge: some View {
        switch setupStatus {
        case .confirmed:
            HStack(spacing: 8) {
                Image(systemName: AppSymbol.checkmarkCircleFill)
                    .foregroundColor(Color.checkGreen)
                    .accessibilityHidden(true)
                Text(NSLocalizedString("키보드가 확인됐어요! 다음으로 넘어갈게요.", comment: "Setup confirmed"))
                    .font(.body)
                    .foregroundColor(theme.text)
            }
            .padding(12)
            .background(theme.success.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm))
            .transition(.move(edge: .bottom).combined(with: .opacity))

        case .notFound:
            HStack(spacing: 8) {
                Image(systemName: AppSymbol.exclamationmarkCircleFill)
                    .foregroundColor(theme.warn)
                    .accessibilityHidden(true)
                Text(NSLocalizedString("아직 설정이 완료되지 않은 것 같아요. 다시 확인해볼까요?", comment: "Setup not found"))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
            }
            .padding(12)
            .background(theme.warn.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm))
            .transition(.move(edge: .bottom).combined(with: .opacity))

        default:
            EmptyView()
        }
    }

    // MARK: Privacy Note

    private var privacyNote: some View {
        HStack(spacing: 8) {
            Image(systemName: AppSymbol.lockShieldFill)
                .font(.body)
                .foregroundColor(theme.textFaint)
                .accessibilityHidden(true)
            Text(NSLocalizedString("개인정보를 수집하지 않습니다.", comment: "Privacy assurance"))
                .font(.body)
                .foregroundColor(theme.textFaint)
        }
    }
}

// MARK: - Illustrations

private struct SettingsPathIllustration: View {
    let path: [String]
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 0) {
            // Fake Settings rows
            ForEach(Array(path.enumerated()), id: \.offset) { i, label in
                HStack {
                    if i == 0 {
                        Image(systemName: AppSymbol.gear)
                            .font(.body)
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
                            .accessibilityHidden(true)
                    } else {
                        Spacer().frame(width: 28)
                    }

                    Text(label)
                        .font(.body)
                        .foregroundColor(i == path.count - 1 ? theme.accent : theme.text)
                        .fontWeight(i == path.count - 1 ? .semibold : .regular)

                    Spacer()

                    Image(systemName: i < path.count - 1 ? "chevron.right" : "plus.circle.fill")
                        .font(.body)
                        .foregroundColor(i == path.count - 1 ? theme.accent : theme.textFaint)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if i < path.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
        .padding(20)
    }
}

private struct KeyboardListIllustration: View {
    let theme: AppTheme

    // iOS 설정의 키보드 목록을 흉내낸 예시 - 사용자 언어에 맞는 이름으로 표시(영어 유저는 Korean/English (US)/Emoji).
    private var keyboards: [String] {
        [NSLocalizedString("한국어", comment: "Keyboard name: Korean"),
         NSLocalizedString("영어(미국)", comment: "Keyboard name: English (US)"),
         NSLocalizedString("이모티콘", comment: "Keyboard name: Emoji")]
    }
    private let clipKeyboard = "ClipKeyboard"

    var body: some View {
        VStack(spacing: 0) {
            Text(NSLocalizedString("키보드", comment: "Keyboard list header"))
                .font(.body)
                .foregroundColor(theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

            ForEach(keyboards, id: \.self) { kb in
                HStack {
                    Text(kb)
                        .font(.body)
                        .foregroundColor(theme.text)
                    Spacer()
                    Image(systemName: AppSymbol.chevronRight)
                        .font(.body)
                        .foregroundColor(theme.textFaint)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                Divider().padding(.leading, 16)
            }

            // Highlighted row
            HStack {
                Text(clipKeyboard)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.accent)
                Spacer()
                Image(systemName: AppSymbol.arrowLeftCircleFill)
                    .foregroundColor(theme.accent)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(theme.accentSoft)
        }
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
        .padding(20)
    }
}

private struct FullAccessIllustration: View {
    let theme: AppTheme
    @State private var toggled = true

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Image(systemName: AppSymbol.keyboard)
                    .font(.title3)
                    .foregroundColor(theme.accent)
                    .accessibilityHidden(true)
                Text("ClipKeyboard")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.text)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.leading, 16)

            // Toggle row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("전체 접근 허용", comment: "Allow Full Access"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(theme.text)
                    Text(NSLocalizedString("단축어 접근에 필요합니다", comment: "Required for memo access"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
                Spacer()
                // Animated toggle
                ZStack(alignment: toggled ? .trailing : .leading) {
                    Capsule()
                        .fill(toggled ? theme.success : theme.divider)
                        .frame(width: 50, height: 30)
                    Circle()
                        .fill(.white)
                        .frame(width: 26, height: 26)
                        .padding(.horizontal, 2)
                        .shadow(radius: 2)
                }
                .onAppear {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.6)) {
                        toggled = true
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
        .padding(20)
    }
}

private struct DoneIllustration: View {
    let theme: AppTheme
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.accentSoft)
                    .frame(width: 100, height: 100)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)

                Image(systemName: AppSymbol.checkmark)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(Color.checkGreen)
                    .scaleEffect(appeared ? 1 : 0.3)
                    .opacity(appeared ? 1 : 0)
            }

            HStack(spacing: 8) {
                Image(systemName: AppSymbol.globe)
                    .font(.title3)
                    .foregroundColor(theme.textMuted)
                    .accessibilityHidden(true)
                Text(NSLocalizedString("🌐 길게 눌러 전환", comment: "Long press globe to switch"))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.surfaceAlt)
            .clipShape(Capsule())
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.2)) {
                appeared = true
            }
        }
    }
}

// MARK: - Preview

struct KeyboardSetupOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        KeyboardSetupOnboardingView(exitAction: { })
    }
}

// MARK: - Persona (same file to avoid Xcode project registration)

import Foundation

enum Persona: String, CaseIterable, Codable {
    // ⚠️ **선언 순서가 곧 화면 순서이자 판정의 동점 순서다.** 설정 > 나에게 맞추기의 목록이
    //    `ForEach(Persona.allCases)` 로 그리고, `PersonaInference` 는 점수가 같으면 앞의 것을 고른다.
    //    그래서 기본(`default`)인 일반이 맨 위에 있어야 한다 - 모르면 넓게 잡는다.
    //
    // ⚠️ `rawValue` 는 저장에 쓰이므로 **문자열은 건드리지 않는다.** 순서만 바꾼다.
    case general = "general"
    case nomad = "nomad"
    case business = "business"
    case student = "student"

    /// 아직 아무것도 안 고른 사람이 처음 보게 되는 갈래.
    ///
    /// ⚠️ 예전에는 노마드였다. 이 앱이 국제 송금·비자에서 출발했다는 **만든 사람의 사정**이지
    ///    쓰는 사람의 사정이 아니다. 처음 여는 사람 대부분은 전화번호와 주소를 넣으려고
    ///    왔고, 그 사람에게 IBAN 과 여권번호를 들이밀면 이 앱이 자기 것이 아닌 줄 안다.
    ///    모르면 가장 넓은 것을 고른다. 좁히는 일은 **묻지 않고** 저장한 것을 보고 앱이 한다
    ///    (`PersonaInference` · `PersonaResolver`).
    static let `default`: Persona = .general

    var icon: String {
        switch self {
        case .nomad: return "globe"
        case .business: return "briefcase.fill"
        case .student: return "graduationcap.fill"
        case .general: return "person.fill"
        }
    }

    var localizedTitle: String {
        switch self {
        case .nomad: return NSLocalizedString("디지털 노마드 / 프리랜서", comment: "Persona: Digital Nomad title")
        case .business: return NSLocalizedString("비즈니스 / 직장인", comment: "Persona: Business title")
        case .student: return NSLocalizedString("학생", comment: "Persona: Student title")
        case .general: return NSLocalizedString("일반 / 개인", comment: "Persona: General title")
        }
    }

    func seedCategories(language: String) -> [String] {
        let lang = language.lowercased()
        switch self {
        case .nomad:
            switch lang {
            case "ko":
                return ["IBAN", "SWIFT/BIC", "VAT/세금번호", "PayPal", "Crypto Wallet",
                        "여권번호", "비자", "Frequent Flyer", "여행자보험", "환전 메모"]
            case "id":
                return ["IBAN", "SWIFT/BIC", "NPWP", "PayPal", "Crypto Wallet",
                        "Paspor", "Visa", "Frequent Flyer", "Asuransi Perjalanan", "Catatan Tukar Uang"]
            default:
                return ["IBAN", "SWIFT/BIC", "VAT / Tax ID", "PayPal", "Crypto Wallet",
                        "Passport", "Visa", "Frequent Flyer", "Travel Insurance", "FX Notes"]
            }
        case .business:
            switch lang {
            case "ko":
                return ["회사 이메일", "비즈니스 주소", "사업자번호", "명함 정보",
                        "미팅 메모", "영수증", "프로젝트 코드", "VPN/계정"]
            case "id":
                return ["Email Kantor", "Alamat Bisnis", "NPWP", "Info Kartu Nama",
                        "Catatan Rapat", "Tanda Terima", "Kode Proyek", "VPN/Akun"]
            default:
                return ["Work Email", "Business Address", "Tax / EIN", "Business Card Info",
                        "Meeting Notes", "Receipt", "Project Code", "VPN / Account"]
            }
        case .student:
            switch lang {
            case "ko":
                return ["학번", "학교 이메일", "학교 주소", "학생증 번호",
                        "과제 템플릿", "도서관 카드", "장학금 정보", "기숙사 주소"]
            case "id":
                return ["NIM", "Email Kampus", "Alamat Kampus", "Nomor KTM",
                        "Template Tugas", "Kartu Perpustakaan", "Beasiswa", "Alamat Asrama"]
            default:
                return ["Student ID", "School Email", "School Address", "Library Card #",
                        "Assignment Template", "Scholarship Info", "Dorm Address"]
            }
        case .general:
            switch lang {
            case "ko":
                return ["이메일", "전화번호", "주소", "비밀번호 힌트", "긴급 연락처"]
            case "id":
                return ["Email", "Nomor Telepon", "Alamat", "Petunjuk Kata Sandi", "Kontak Darurat"]
            default:
                return ["Email", "Phone", "Address", "Password Hint", "Emergency Contact"]
            }
        }
    }
}
