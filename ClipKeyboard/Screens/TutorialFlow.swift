//
//  TutorialFlow.swift
//  ClipKeyboard
//
//  **써 보는 튜토리얼** - 단축어 다음에 템플릿, 그다음에 콤보.
//
//  ⚠️ 여기서 **아무것도 만들게 하지 않는다.** 예전에는 첫 단축어·템플릿·콤보를 차례로
//     직접 만들게 했는데, 처음 온 사람에게 빈 칸을 세 번 내미는 일이었다. 만드는 법은
//     쓸 일이 생겼을 때 배우면 되고, 처음 필요한 것은 **이게 무엇을 해주는 물건인지**다.
//
//  ⚠️ 대신 **우리가 시나리오를 넣어 둔다.** 설치 첫 실행에 단축어·템플릿·콤보가
//     한 벌씩 목록에 들어가고(`performSampleInsertion`), 튜토리얼은 그것들을 차례로
//     가리키며 눌러 보게 한다. 세 번 누르고 나면 셋이 어떻게 다른지 손이 안다.
//
//  ⚠️ 넣어 둔 것도 **진짜다.** 튜토리얼이 끝나도 지우지 않는다. 연습용 가짜를 만들었다가
//     지우면 아무것도 안 남고, 남겨 두면 그날부터 바로 쓸 수 있는 세 개가 된다.
//

import SwiftUI
#if canImport(UIKit)
import LeeoKit
#endif

// MARK: - 장

/// 써 보는 순서: 단축어 → 템플릿 → 콤보.
///
/// ⚠️ 순서에 뜻이 있다. 단축어는 누르면 그대로 들어가고, 템플릿은 빈칸을 한 번 채우고,
///    콤보는 여러 개가 차례로 들어간다. **뒤로 갈수록 한 겹씩 얹히는** 순서라야
///    "아까 것과 뭐가 다르지"가 매번 한 가지로 답해진다.
enum TutorialChapter: String, Identifiable, CaseIterable {
    /// 눌러서 그대로 입력되는 가장 단순한 것.
    case snippet
    /// 빈칸을 채워 쓰는 것.
    case template
    /// 여러 값이 순서대로 들어가는 것.
    case combo

    var id: String { rawValue }

    /// 가리키는 카드·키 옆에 뜨는 안내 한 줄.
    ///
    /// ⚠️ "무엇을 누르라"가 아니라 **"누르면 무슨 일이 나는지"**를 적는다. 처음 온 사람은
    ///    누르는 법을 모르는 게 아니라 눌러도 되는지를 모른다.
    var coachLine: String {
        switch self {
        case .snippet:
            return NSLocalizedString("이걸 눌러보세요. 적힌 그대로 입력돼요.",
                                     comment: "Coach line: try the prepared snippet")
        case .template:
            return NSLocalizedString("이번엔 템플릿이에요. 눌러서 빈칸만 채워보세요.",
                                     comment: "Coach line: try the prepared template")
        case .combo:
            return NSLocalizedString("마지막은 콤보예요. 여러 개가 순서대로 들어가요.",
                                     comment: "Coach line: try the prepared combo")
        }
    }

    /// 환영 화면에서 "이런 걸 넣어뒀어요"로 소개하는 한 줄.
    var introLine: String {
        switch self {
        case .snippet:
            return NSLocalizedString("눌러서 그대로 입력하는 단축어",
                                     comment: "Welcome: what a snippet is")
        case .template:
            return NSLocalizedString("빈칸만 채워 쓰는 템플릿",
                                     comment: "Welcome: what a template is")
        case .combo:
            return NSLocalizedString("여러 값을 순서대로 넣는 콤보",
                                     comment: "Welcome: what a combo is")
        }
    }

    var symbolName: String {
        switch self {
        case .snippet:  return "text.cursor"
        case .template: return "square.dashed"
        case .combo:    return "list.number"
        }
    }
}

// MARK: - 넣어 둔 시나리오

/// 첫 실행에 심어 둔 시나리오 중 **장마다 하나씩**을 찾아 준다.
///
/// ⚠️ 새로 만들지 않는다. 이미 목록에 들어가 있는 것(`SampleMemoStorage`)에서 고른다.
///    튜토리얼이 자기 것을 따로 만들면, 화면에 보이는 카드와 튜토리얼이 가리키는 것이
///    다른 물건이 되어 "그래서 뭘 누르라는 거지"가 된다.
///
/// ⚠️ 지운 것은 없는 것으로 친다. 심어 준 것을 사용자가 지웠을 수도 있고, 그때는
///    그 장을 조용히 건너뛴다 - 없는 카드를 가리키며 누르라고 할 수는 없다.
enum TutorialScenarios {

    /// 장에 해당하는, 지금 목록에 실제로 있는 메모. 없으면 nil.
    static func memo(for chapter: TutorialChapter, in memos: [Memo]) -> Memo? {
        let seeded = SampleMemoStorage.load()
        // 심어 둔 것 먼저, 없으면 목록 전체에서 같은 성격의 것을 찾는다.
        // (튜토리얼을 다시 하는 사람은 심어 둔 것을 이미 지웠을 수 있다.)
        let preferred = memos.filter { seeded.contains($0.id) }
        return match(chapter, in: preferred) ?? match(chapter, in: memos)
    }

    private static func match(_ chapter: TutorialChapter, in memos: [Memo]) -> Memo? {
        switch chapter {
        case .snippet:
            return memos.first {
                !$0.isTemplate && !$0.isCombo && $0.contentType == .text
                    && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        case .template:
            return memos.first { $0.isTemplate && !$0.isCombo }
        case .combo:
            return memos.first { $0.isCombo }
        }
    }

    /// 지금 목록으로 **실제로 써 볼 수 있는** 장들. 환영 화면이 이걸로 목록을 그린다.
    static func availableChapters(in memos: [Memo]) -> [TutorialChapter] {
        TutorialChapter.allCases.filter { memo(for: $0, in: memos) != nil }
    }
}

// MARK: - 환영

/// 첫 화면 - **무엇을 넣어 뒀는지** 알리고 바로 써 보게 한다.
///
/// ⚠️ 여기서 기능을 설명하지 않는다. 셋을 다 설명하면 하나도 안 남는다. 이름만 대고
///    "눌러 보면 안다"로 넘긴다 - 실제 설명은 누른 순간 화면이 대신 해 준다.
struct TutorialWelcomeView: View {

    /// 준비된 것을 써 보러 간다.
    let onStart: () -> Void
    /// 지금은 됐다 - 평소 화면으로.
    let onSkip: () -> Void

    @Environment(\.appTheme) private var theme

    /// 지금 목록에 실제로 있는 장들만 소개한다.
    ///
    /// ⚠️ 계산 프로퍼티로 두지 않는다 - body 가 그려질 때마다 저장소를 디스크에서 읽게 된다.
    ///    화면이 뜰 때 한 번만 읽고 붙잡아 둔다.
    @State private var chapters: [TutorialChapter] = TutorialChapter.allCases

    private func loadChapters() {
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        let available = TutorialScenarios.availableChapters(in: memos)
        chapters = available.isEmpty ? TutorialChapter.allCases : available
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Image(systemName: "hand.wave.fill")
                .font(.largeTitle)
                .foregroundColor(theme.accent)
                .accessibilityHidden(true)

            Text(NSLocalizedString("바로 써 볼 수 있게 준비해 뒀어요",
                                   comment: "Tutorial welcome: headline"))
                .font(.title3.weight(.semibold))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)
                .padding(.top, 14)

            Text(NSLocalizedString("만드는 법은 나중에 알아도 돼요. 먼저 눌러서 어떤 물건인지부터 보세요.",
                                   comment: "Tutorial welcome: body"))
                .font(.subheadline)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(chapters) { chapter in
                    HStack(spacing: 12) {
                        Image(systemName: chapter.symbolName)
                            .font(.body.weight(.semibold))
                            .foregroundColor(theme.accent)
                            .frame(width: 26)
                            .accessibilityHidden(true)
                        Text(chapter.introLine)
                            .font(.subheadline)
                            .foregroundColor(theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
            .padding(.top, 26)

            Button(action: onStart) {
                Text(NSLocalizedString("눌러볼게요", comment: "Tutorial welcome: start"))
                    .font(.body.weight(.semibold))
                    .foregroundColor(theme.accentFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                            .fill(theme.accent)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 26)

            // 빠져나갈 길은 언제나 열어 둔다 - 붙잡으면 다음에 안 온다.
            Button(action: onSkip) {
                Text(NSLocalizedString("나중에 볼게요", comment: "Tutorial welcome: skip"))
                    .font(.subheadline)
                    .foregroundColor(theme.textMuted)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadChapters() }
    }
}

// MARK: - 코치 위치

/// 코치가 가리킬 카드의 화면상 위치(global). 카드가 스스로 올려보낸다.
struct CoachAnchorKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

// MARK: - 코치

/// "이걸 눌러보세요" - 목록 위에 뜨는 안내.
///
/// ⚠️ 처음에는 작은 회색 알약이었는데 **아무도 못 봤다.** 이 안내는 튜토리얼의 전부라
///    놓치면 흐름이 거기서 끊긴다. 그래서 배경을 강조색으로 채우고, 글자를 키우고,
///    천천히 맥박처럼 커졌다 작아지게 했다 - 화면에서 **유일하게 움직이는 것**이라야 눈이 간다.
///
/// ⚠️ 닫기 버튼은 없다. 한 번 쓰면 스스로 사라진다.
struct FirstUseCoachChip: View {
    let line: String
    /// 위쪽 카드를 가리키는 꼭지. 카드 **아래**에 놓일 때만 쓴다.
    var pointsUp: Bool = false

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        VStack(spacing: 0) {
            if pointsUp {
                // 말풍선 꼬리 - 안내가 무엇을 가리키는지 화살표 하나가 문장보다 빠르다.
                Triangle()
                    .fill(theme.accent)
                    .frame(width: 16, height: 9)
            }
            chip
        }
        .scaleEffect(pulsing ? 1.045 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
        .allowsHitTesting(false)
        .accessibilityLabel(line)
    }

    private var chip: some View {
        HStack(spacing: 12) {
            Image(systemName: AppSymbol.handTap)
                .font(.title3.weight(.bold))
            Text(line)
                .font(.callout.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .foregroundColor(theme.accentFg)
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(
            Capsule().fill(theme.accent)
        )
        .shadow(color: theme.accent.opacity(0.45), radius: 14, x: 0, y: 6)
    }
}

/// 위를 가리키는 삼각형 꼭지.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - 다음 장까지

/// 장과 장 사이에 도는 5초 원.
///
/// ⚠️ 왜 그냥 기다리지 않고 원을 보여주나: 방금 하나를 끝냈는데 화면이 잠시 아무것도 안 하면
///    **끝난 건지 멈춘 건지** 알 수 없다. 남은 시간이 보이면 그 몇 초가 '기다림'이 아니라
///    '숨 고르기'가 된다 - 곧 뭔가 온다는 걸 알고 쉬는 것과 모르고 멈춰 있는 건 다르다.
///
/// ⚠️ 시간이 지나면 스스로 사라진다. 닫는 버튼은 없다 - 누를 것이 하나 더 생기면
///    쉬라고 만든 자리가 또 하나의 할 일이 된다.
struct NextChapterCountdown: View {
    let endsAt: Date
    let total: Double

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ring: CGFloat = 46

    var body: some View {
        TimelineView(.animation) { context in
            let remaining = max(0, endsAt.timeIntervalSince(context.date))
            let progress = total > 0 ? remaining / total : 0

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(theme.divider, lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))   // 12시 방향에서 줄어들게
                    Text("\(Int(remaining.rounded(.up)))")
                        .font(.footnote.weight(.bold))
                        .monospacedDigit()
                        .foregroundColor(theme.text)
                }
                .frame(width: ring, height: ring)

                Text(NSLocalizedString("다음 튜토리얼까지", comment: "Countdown to the next tutorial chapter"))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(theme.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().strokeBorder(theme.divider, lineWidth: 0.5))
        }
        .allowsHitTesting(false)
        .accessibilityLabel(NSLocalizedString("다음 튜토리얼까지", comment: "Countdown to the next tutorial chapter"))
    }
}

// MARK: - 다시 하기

enum TutorialReset {

    /// 튜토리얼을 **처음부터 다시** 할 수 있게 표식을 지운다.
    ///
    /// ⚠️ 한 번 배우고 끝이 아니다. 몇 달 만에 열어 본 사람은 템플릿이 뭐였는지, 콤보가
    ///    무엇이었는지 기억하지 못한다. 그때 다시 볼 길이 없으면 "예전엔 됐는데"로 끝난다.
    ///
    /// ⚠️ 지워지는 것은 **표식뿐이다.** 목록의 단축어·템플릿·콤보는 그대로 남는다.
    ///    튜토리얼은 그중에서 가리킬 것을 다시 고른다(`TutorialScenarios`).
    ///
    /// ⚠️ `startedFresh` 도 함께 켠다 - 이 흐름은 그 표식을 보고 도는데, 쓰던 사람에게는
    ///    꺼져 있어서 켜 주지 않으면 다시 하기를 눌러도 아무 일도 안 일어난다.
    static func restartAll() {
        let d = UserDefaults.standard
        d.set(true, forKey: DefaultsKey.startedFreshV444)
        d.set(false, forKey: DefaultsKey.tutorialWelcomeDone)
        d.set(false, forKey: DefaultsKey.tutorialSnippetDone)
        d.set(false, forKey: DefaultsKey.tutorialTemplateDone)
        d.set(false, forKey: DefaultsKey.tutorialComboDone)
        d.set(false, forKey: DefaultsKey.tutorialChaptersDone)
        d.set(false, forKey: DefaultsKey.keyboardSetupTutorialDone)
        d.set("", forKey: DefaultsKey.tutorialFirstUseMemoId)
        // 튜토리얼은 무대에서 시작한다 - 목록에 있으면 첫 걸음이 열리지 않는다.
        d.set(SnippetsTabStyle.keyboard.rawValue, forKey: DefaultsKey.snippetsTabStyle)
        print("🎓 [TutorialReset] 튜토리얼 표식 초기화, 처음부터 다시")
    }
}
