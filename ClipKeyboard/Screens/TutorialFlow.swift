//
//  TutorialFlow.swift
//  ClipKeyboard
//
//  **이어지는 튜토리얼** — 단축어 다음에 콤보, 그다음에 템플릿.
//
//  세 개를 한 번에 가르치지 않는다. 첫 화면에서 "단축어·콤보·템플릿이 있어요"를 다 설명하면
//  하나도 안 남는다. **하나 만들고 → 써 보고 → 그다음 것을 권한다.**
//  권할 때마다 빠져나갈 수 있어야 한다 — 붙잡으면 다음에 안 온다.
//
//  ⚠️ 여기서 만드는 것도 전부 **진짜**다. 연습용 가짜를 만들었다가 지우면 아무것도 안 남는다.
//

import SwiftUI
#if canImport(UIKit)
import LeeoKit
#endif

// MARK: - 장

/// 배우는 순서: 단축어(온보딩) → 템플릿 → **내 단축어를 템플릿으로** → 콤보.
///
/// ⚠️ 순서에 뜻이 있다. 템플릿을 한 번 만들어 본 다음이라야 "이미 있는 걸 템플릿으로
///    바꿀 수도 있다"는 말이 통한다. 반대로 하면 바꾸는 법부터 배우게 되어 무엇으로
///    바뀌는지를 모른다. 콤보는 성격이 달라(여러 값) 맨 뒤에 둔다.
enum TutorialChapter: String, Identifiable, CaseIterable {
    /// 템플릿 하나를 새로 만든다.
    case template
    /// 이미 만든 단축어를 템플릿으로 바꿔 본다 — 기존 "템플릿으로 만들기" 기능을 그대로 태운다.
    case makeTemplate
    /// 여러 값을 하나로 묶는 콤보.
    case combo

    var id: String { rawValue }

    var inviteTitle: String {
        switch self {
        case .template:
            return NSLocalizedString("템플릿도 만들어 볼까요?", comment: "Tutorial invite title: template")
        case .makeTemplate:
            return NSLocalizedString("있는 단축어를 템플릿으로 바꿔볼까요?", comment: "Tutorial invite title: make template")
        case .combo:
            return NSLocalizedString("콤보도 만들어 볼까요?", comment: "Tutorial invite title: combo")
        }
    }

    var inviteBody: String {
        switch self {
        case .template:
            return NSLocalizedString("매번 한 군데만 바뀌는 문구는 빈칸으로 남겨 둘 수 있어요.",
                                     comment: "Tutorial invite body: template")
        case .makeTemplate:
            return NSLocalizedString("처음에 만든 단축어, 새로 쓰지 않고 그대로 템플릿으로 바꿀 수 있어요.",
                                     comment: "Tutorial invite body: make template")
        case .combo:
            return NSLocalizedString("이름·연락처처럼 늘 같이 쓰는 것들을 하나로 묶어 둘 수 있어요.",
                                     comment: "Tutorial invite body: combo")
        }
    }

    /// 만든 뒤 목록에 뜨는 안내. 없는 장은 안내 없이 넘어간다.
    var coachLine: String? {
        switch self {
        case .template:
            return NSLocalizedString("만든 템플릿을 눌러보세요. 빈칸만 채우면 돼요.",
                                     comment: "Coach line: template")
        case .combo:
            return NSLocalizedString("만든 콤보를 눌러보세요. 값을 골라 쓸 수 있어요.",
                                     comment: "Coach line: combo")
        case .makeTemplate:
            // 기존 편집 화면을 그대로 태우므로 우리가 안내할 단계가 없다.
            return nil
        }
    }
}

// MARK: - 권유

/// "이어서 해볼까요?" — 붙잡지 않는 권유.
struct TutorialInviteView: View {
    let chapter: TutorialChapter
    let onAccept: () -> Void
    let onDecline: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // "하나 더 있다"를 먼저 알린다 — 방금 하나를 끝낸 사람에게 필요한 건
            // 새 제목이 아니라 **이게 몇 번째인지**다.
            Text(NSLocalizedString("튜토리얼이 하나 더 있어요", comment: "Tutorial invite: eyebrow"))
                .font(.footnote.weight(.semibold))
                .foregroundColor(theme.accent)
                .padding(.top, 8)

            Text(chapter.inviteTitle)
                .font(.title3.weight(.semibold))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)
                .padding(.top, 6)

            Text(chapter.inviteBody)
                .font(.subheadline)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.bottom, 26)

            Button(action: onAccept) {
                Text(NSLocalizedString("네, 해볼게요", comment: "Tutorial invite: accept"))
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                            .fill(theme.accent)
                    )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button(action: onDecline) {
                Text(NSLocalizedString("나중에 할게요", comment: "Onboarding: skip"))
                    .font(.footnote)
                    .foregroundColor(theme.textFaint)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 18)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
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

/// "만든 걸 눌러보세요" — 목록 위에 뜨는 안내.
///
/// ⚠️ 처음에는 작은 회색 알약이었는데 **아무도 못 봤다.** 이 안내는 온보딩의 마지막 걸음이라
///    놓치면 흐름이 거기서 끊긴다. 그래서 배경을 강조색으로 채우고, 글자를 키우고,
///    천천히 맥박처럼 커졌다 작아지게 했다 — 화면에서 **유일하게 움직이는 것**이라야 눈이 간다.
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
                // 말풍선 꼬리 — 안내가 무엇을 가리키는지 화살표 하나가 문장보다 빠르다.
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
        .foregroundColor(.white)
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

// MARK: - 콤보 만들기

/// 콤보 한 개를 만든다. 칸을 **둘만** 둔다 — 온보딩에서 세 칸을 채우게 하면 거기서 나간다.
struct ComboTutorialView: View {
    let onCreated: (Memo) -> Void
    let onSkip: () -> Void

    @Environment(\.appTheme) private var theme

    @State private var name = ""
    @State private var contact = ""
    @FocusState private var focused: Field?
    private enum Field { case name, contact }

    private var ready: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Text(NSLocalizedString("같이 쓰는 것들을 묶어 둘게요", comment: "Combo tutorial: headline"))
                .font(.title3.weight(.semibold))
                .foregroundColor(theme.text)
                .padding(.top, 14)

            Text(NSLocalizedString("나중에 필요한 값만 골라서 쓸 수 있어요.", comment: "Combo tutorial: subline"))
                .font(.subheadline)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.bottom, 22)

            VStack(spacing: 10) {
                field(NSLocalizedString("이름", comment: "Combo tutorial field: name"),
                      text: $name, tag: .name)
                field(NSLocalizedString("연락처", comment: "Combo tutorial field: contact"),
                      text: $contact, tag: .contact)
            }

            Button(action: save) {
                Text(NSLocalizedString("이걸로 만들기", comment: "Onboarding: save the first shortcut"))
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                            .fill(theme.accent)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!ready)
            .opacity(ready ? 1 : 0.45)
            .padding(.top, 18)

            Spacer(minLength: 0)
            skip
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
        .onAppear { focused = .name }
    }

    private func field(_ label: String, text: Binding<String>, tag: Field) -> some View {
        TextField(label, text: text)
            .textFieldStyle(.plain)
            .font(.body)
            .focused($focused, equals: tag)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                    .fill(theme.surface)
            )
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            #endif
    }

    private var skip: some View {
        Button(action: onSkip) {
            Text(NSLocalizedString("나중에 할게요", comment: "Onboarding: skip"))
                .font(.footnote)
                .foregroundColor(theme.textFaint)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 18)
    }

    private func save() {
        guard ready else { return }
        // 콤보는 본문(value)이 비고 단계(comboValues)에 값이 들어간다 — isCombo 는 계산형이다.
        let memo = Memo(
            title: NSLocalizedString("내 소개", comment: "Combo tutorial: created combo title"),
            value: "",
            comboValues: [name.trimmingCharacters(in: .whitespacesAndNewlines),
                          contact.trimmingCharacters(in: .whitespacesAndNewlines)]
        )
        TutorialStore.insert(memo, onCreated: onCreated, onFailure: onSkip)
    }
}

// MARK: - 템플릿 만들기

/// 템플릿 한 개를 만든다. 빈 문장부터 쓰게 하지 않고 **예문을 주고 고치게** 한다 —
/// `{}` 를 어디에 왜 쓰는지는 설명보다 보여주는 쪽이 빠르다.
struct TemplateTutorialView: View {
    let onCreated: (Memo) -> Void
    let onSkip: () -> Void

    @Environment(\.appTheme) private var theme

    /// 두 걸음이다 — **값을 먼저 넣고**, 그다음 **그 자리를 뭐라고 부를지** 정한다.
    ///
    /// ⚠️ 순서에 뜻이 있다. 손에 잡히는 것("이영훈")을 먼저 넣어 보면 문장이 어떻게
    ///    완성되는지가 눈에 들어오고, 그다음에야 "그럼 이 자리는 뭐라고 부를까"가
    ///    자연스러운 물음이 된다. 반대로 하면 이름부터 지으라는 말이라 무엇을 적으라는
    ///    건지 알 수 없고, 실제로 그 자리에 값을 적어 넣는 일이 벌어졌다.
    private enum Step { case value, name }
    @State private var step: Step = .value

    /// 채울 칸의 **이름**(= 무엇이 바뀌는 자리인가). 사용자가 고친다.
    @State private var blankName: String = ""
    /// 그 칸에 넣어 볼 **값**. 만들어진 템플릿에 기억돼 다음에 제안으로 뜬다.
    @State private var sampleValue: String = ""
    @FocusState private var focused: Bool

    private var trimmedBlank: String {
        blankName.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
    }
    private var trimmedValue: String { sampleValue.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// 저장 형식(중괄호)은 여기서만 만든다 — 화면에는 칩으로만 보인다.
    private var templateBody: String {
        String(format: NSLocalizedString("안녕하세요, {%@}님. 확인 부탁드립니다.",
                                         comment: "Template tutorial: example body"),
               trimmedBlank.isEmpty ? defaultBlankName : trimmedBlank)
    }

    /// 값을 넣는 동안 보여줄 문장 — 아직 이름을 안 지었으니 자리는 중립적인 말로 둔다.
    private var valueStepBody: String {
        let slot = trimmedValue.isEmpty
            ? "{\(NSLocalizedString("여기", comment: "Template tutorial: neutral slot label"))}"
            : trimmedValue
        return String(format: NSLocalizedString("안녕하세요, %@님. 확인 부탁드립니다.",
                                                comment: "Template tutorial: example body (plain)"), slot)
    }

    private var defaultBlankName: String {
        NSLocalizedString("소개하는 이름", comment: "Template tutorial: suggested blank name")
    }

    private var ready: Bool {
        step == .value ? !trimmedValue.isEmpty : !trimmedBlank.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Text(headline)
                .font(.title3.weight(.semibold))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Text(subline)
                .font(.subheadline)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .padding(.bottom, 22)

            // ⚠️ 중괄호를 **그대로 보여주지 않는다.** `{}` 는 저장 형식이지 사용자가 배울 문법이 아니다.
            //    칸 이름을 정하는 동안엔 칩으로, 값을 넣는 동안엔 **채워진 문장**으로 보여준다 —
            //    같은 문장이 어떻게 달라지는지가 이 튜토리얼의 전부다.
            Text((step == .value ? valueStepBody : templateBody)
                    .templateAwareAttributed(theme: theme, font: .body))
                .font(.body)
                .foregroundColor(theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                        .fill(theme.surface)
                )

            HStack(spacing: 10) {
                Text(fieldLabel)
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
                TextField(fieldPlaceholder,
                          text: step == .value ? $sampleValue : $blankName)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused($focused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radiusSm, style: .continuous)
                            .fill(theme.surfaceAlt)
                    )
                    #if os(iOS)
                    .autocorrectionDisabled()
                    #endif
            }
            .padding(.top, 12)

            Button(action: advance) {
                Text(step == .value
                     ? NSLocalizedString("다음", comment: "Next button")
                     : NSLocalizedString("이걸로 만들기", comment: "Onboarding: save the first shortcut"))
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                            .fill(theme.accent)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!ready)
            .opacity(ready ? 1 : 0.45)
            .padding(.top, 16)

            Spacer(minLength: 0)

            Button(action: onSkip) {
                Text(NSLocalizedString("나중에 할게요", comment: "Onboarding: skip"))
                    .font(.footnote)
                    .foregroundColor(theme.textFaint)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 18)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
        .animation(.easeOut(duration: 0.25), value: step)
        .onAppear { focused = true }
    }

    // MARK: - 걸음마다 달라지는 말

    private var headline: String {
        switch step {
        case .value:
            return NSLocalizedString("매번 한 군데만 바뀌는 문구, 있죠?", comment: "Template tutorial: headline")
        case .name:
            return NSLocalizedString("이 자리를 뭐라고 부를까요?", comment: "Template tutorial: name step headline")
        }
    }

    private var subline: String {
        switch step {
        case .value:
            return NSLocalizedString("이름만 바꿔 보내는 안내문처럼요. 오늘은 그 자리에 뭐라고 넣으시겠어요?",
                                     comment: "Template tutorial: value step subline")
        case .name:
            return String(format: NSLocalizedString("'%@'처럼 매번 달라지는 자리예요. 이름을 붙여 두면 다음에 쓸 때 무엇을 채우는 칸인지 바로 알아봐요.",
                                                    comment: "Template tutorial: name step subline"),
                          trimmedValue)
        }
    }

    private var fieldLabel: String {
        step == .value
            ? NSLocalizedString("여기에 넣을 말", comment: "Template tutorial: value label")
            : NSLocalizedString("이 자리의 이름", comment: "Template tutorial: blank name label")
    }

    private var fieldPlaceholder: String {
        step == .value
            ? NSLocalizedString("예: 이영훈", comment: "Template tutorial: value placeholder")
            : defaultBlankName
    }

    // MARK: - 진행

    private func advance() {
        guard ready else { return }
        if step == .value {
            // 이름 짓는 칸에 들어설 때 제안을 채워 둔다 — 빈칸에서 시작하면 뭘 적으라는 건지 모른다.
            if blankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blankName = defaultBlankName
            }
            withAnimation(.easeOut(duration: 0.25)) { step = .name }
            focused = true
            return
        }
        save()
    }

    private func save() {
        let text = templateBody.trimmingCharacters(in: .whitespacesAndNewlines)
        // ⚠️ templateVariables 를 넣지 않으면 isTemplate=false 가 되어
        //    탭했을 때 {이름}이 그대로 복사된다.
        var memo = Memo(
            title: NSLocalizedString("확인 요청", comment: "Template tutorial: created template title"),
            value: text,
            templateVariables: TemplateVariableProcessor.extractCustomTokens(in: text)
        )
        // 방금 넣어 본 값을 **그 칸의 기억**으로 남긴다 — 다음에 쓸 때 제안으로 뜬다.
        // 배운 것이 화면 안에 흔적으로 남아야 "그래서 뭐가 달라졌지"가 안 된다.
        let token = "{\(trimmedBlank.isEmpty ? defaultBlankName : trimmedBlank)}"
        memo.placeholderValues = [token: [trimmedValue]]
        TutorialStore.insert(memo, onCreated: onCreated, onFailure: onSkip)
    }
}

// MARK: - 저장

/// 튜토리얼을 **처음부터 다시** 할 수 있게 표식을 지운다.
///
/// ⚠️ 한 번 배우고 끝이 아니다. 몇 달 만에 열어 본 사람은 템플릿이 뭐였는지, 콤보를 어떻게
///    만들었는지 기억하지 못한다. 그때 다시 볼 길이 없으면 "예전엔 됐는데"로 끝난다.
///
/// ⚠️ `startedFresh` 도 함께 켠다 — 이 흐름은 그 표식을 보고 도는데, 쓰던 사람에게는
///    꺼져 있어서 켜 주지 않으면 다시 하기를 눌러도 아무 일도 안 일어난다.
/// 튜토리얼에서 **만든 것**을 기억하고, 끝난 뒤 지울지 물어보기 위한 자리.
///
/// ⚠️ 여기서 만드는 것도 전부 진짜다 — 그래서 함부로 지우지 않는다. 다만 연습 삼아 만든
///    것이 목록에 남아 거슬리는 사람도 있어, **끝나고 한 번 물어보고** 그때만 지운다.
enum TutorialCreations {

    static func remember(_ id: UUID) {
        var ids = all
        guard !ids.contains(id) else { return }
        ids.append(id)
        UserDefaults.standard.set(ids.map(\.uuidString).joined(separator: ","),
                                  forKey: DefaultsKey.tutorialCreatedMemoIds)
    }

    static var all: [UUID] {
        (UserDefaults.standard.string(forKey: DefaultsKey.tutorialCreatedMemoIds) ?? "")
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) }
    }

    static func forget() {
        UserDefaults.standard.set("", forKey: DefaultsKey.tutorialCreatedMemoIds)
    }

    /// 기억해 둔 것들을 지운다. **그 사이 사용자가 고쳐 쓰고 있을 수도 있으므로**
    /// 지운 개수를 돌려준다(안내 문구에 쓴다).
    @discardableResult
    static func deleteAll() -> Int {
        let ids = Set(all)
        guard !ids.isEmpty else { return 0 }
        do {
            let memos = try MemoStore.shared.load(type: .memo)
            let kept = memos.filter { !ids.contains($0.id) }
            let removed = memos.count - kept.count
            try MemoStore.shared.save(memos: kept, type: .memo)
            forget()
            NotificationCenter.default.post(name: .memoDataChanged, object: nil)
            print("🧹 [TutorialCreations] 튜토리얼 단축어 \(removed)개 삭제")
            return removed
        } catch {
            print("❌ [TutorialCreations.deleteAll] \(error)")
            return 0
        }
    }
}

enum TutorialReset {

    /// 지워지는 것은 **표식뿐이다.** 만들어 둔 단축어·템플릿·콤보는 그대로 남는다.
    static func restartAll() {
        let d = UserDefaults.standard
        d.set(true, forKey: DefaultsKey.startedFreshV444)
        d.set(false, forKey: DefaultsKey.firstShortcutDone)
        d.set(false, forKey: DefaultsKey.tutorialTemplateDone)
        d.set(false, forKey: DefaultsKey.tutorialMakeTemplateDone)
        d.set(false, forKey: DefaultsKey.tutorialComboDone)
        d.set(false, forKey: DefaultsKey.tutorialChaptersDone)
        d.set(false, forKey: DefaultsKey.keyboardSetupTutorialDone)
        d.set("", forKey: DefaultsKey.tutorialFirstUseMemoId)
        d.set(false, forKey: DefaultsKey.tutorialCleanupAsked)
        TutorialCreations.forget()
        // 튜토리얼은 무대에서 시작한다 — 목록에 있으면 첫 걸음이 열리지 않는다.
        d.set(SnippetsTabStyle.keyboard.rawValue, forKey: DefaultsKey.snippetsTabStyle)
        print("🎓 [TutorialReset] 튜토리얼 표식 초기화 — 처음부터 다시")
    }
}

enum TutorialStore {
    /// 튜토리얼에서 만든 것을 목록 맨 위에 넣는다.
    static func insert(_ memo: Memo, onCreated: (Memo) -> Void, onFailure: () -> Void) {
        do {
            var memos = (try? MemoStore.shared.load(type: .memo)) ?? []
            memos.insert(memo, at: 0)
            try MemoStore.shared.save(memos: memos, type: .memo)
            #if canImport(UIKit)
            HapticManager.shared.success()
            #endif
            onCreated(memo)
        } catch {
            print("❌ [TutorialStore.insert] 저장 실패: \(error)")
            // 저장이 안 됐는데 "만들었어요"로 넘어가면 목록에 없는 걸 누르라고 하게 된다.
            onFailure()
        }
    }
}
