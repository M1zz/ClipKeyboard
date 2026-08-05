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

            MinerScene(height: 190)
                .frame(maxWidth: 260)

            Text(chapter.inviteTitle)
                .font(.title3.weight(.semibold))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)
                .padding(.top, 16)

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

            MinerScene(height: 150)
                .frame(maxWidth: 220)

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

    /// 채울 칸의 이름. 사용자가 고치는 건 이것뿐이다.
    @State private var blankName: String = ""
    @FocusState private var focused: Bool

    /// 미리보기용 본문. 저장 형식(중괄호)은 여기서만 만들고 화면에는 칩으로만 보인다.
    private var body_: String {
        String(format: NSLocalizedString("안녕하세요, {%@}님. 확인 부탁드립니다.",
                                         comment: "Template tutorial: example body"),
               trimmedBlank.isEmpty ? NSLocalizedString("이름", comment: "Combo tutorial field: name") : trimmedBlank)
    }

    private var trimmedBlank: String {
        blankName.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
    }

    private var ready: Bool { !trimmedBlank.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            MinerScene(height: 150)
                .frame(maxWidth: 220)

            Text(NSLocalizedString("바뀌는 곳만 빈칸으로 둘게요", comment: "Template tutorial: headline"))
                .font(.title3.weight(.semibold))
                .foregroundColor(theme.text)
                .padding(.top, 14)

            Text(NSLocalizedString("색이 칠해진 곳이 쓸 때마다 채우는 칸이에요.", comment: "Template tutorial: subline"))
                .font(.subheadline)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .padding(.bottom, 22)

            // ⚠️ 중괄호를 **그대로 보여주지 않는다.** `{}` 는 저장 형식이지 사용자가 배울 문법이 아니다.
            //    카드에서도 칩으로 강조해 보여주므로, 여기만 원문을 노출하면 같은 것이
            //    두 얼굴로 보인다. 여기서는 완성된 모습만 미리 보여준다.
            Text(body_.templateAwareAttributed(theme: theme, font: .body))
                .font(.body)
                .foregroundColor(theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                        .fill(theme.surface)
                )

            // 채울 칸의 이름만 고치게 한다 — 문장 전체를 고치게 하면 중괄호를 지워 놓고
            // "왜 빈칸이 안 생기죠"가 된다.
            HStack(spacing: 10) {
                Text(NSLocalizedString("채울 칸 이름", comment: "Template tutorial: blank name label"))
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
                TextField(NSLocalizedString("이름", comment: "Combo tutorial field: name"), text: $blankName)
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
        .onAppear {
            if blankName.isEmpty {
                blankName = NSLocalizedString("이름", comment: "Combo tutorial field: name")
            }
            focused = true
        }
    }

    private func save() {
        guard ready else { return }
        let text = body_.trimmingCharacters(in: .whitespacesAndNewlines)
        // ⚠️ templateVariables 를 넣지 않으면 isTemplate=false 가 되어
        //    탭했을 때 {이름}이 그대로 복사된다.
        let memo = Memo(
            title: NSLocalizedString("확인 요청", comment: "Template tutorial: created template title"),
            value: text,
            templateVariables: TemplateVariableProcessor.extractCustomTokens(in: text)
        )
        TutorialStore.insert(memo, onCreated: onCreated, onFailure: onSkip)
    }
}

// MARK: - 저장

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
