//
//  FirstShortcutOnboardingView.swift
//  ClipKeyboard
//
//  **첫 단축어 만들기** — 하나를 실제로 만들어 보는 자리.
//
//  ⚠️ 예전 빈 화면(활용 사례 카드 격자 + 스타터팩 배너)을 대신한다.
//     그 화면의 문제는 **읽을 거리만 주고 아무것도 시키지 않았다**는 것이다.
//     "이렇게 쓸 수 있어요"를 아무리 잘 써 놔도, 한 번도 안 만들어 본 사람에게는
//     남의 이야기다. 만들어서 써 본 사람만 다음 날 다시 온다.
//
//  ⚠️ 빈 칸부터 주지 않는다. 첫 화면에서 "제목:"과 커서를 마주하면 무엇을 써야 할지
//     막막해서 대부분 나간다. 예시를 고르게 하고 **내용 한 칸만** 채우게 한다 —
//     고르는 건 쉽고, 채운 것은 자기 것이 된다.
//
//  ⚠️ 여기서 만든 단축어는 진짜다. 연습용 가짜를 만들었다가 지우면 아무것도 안 남는다.
//

import SwiftUI
#if canImport(UIKit)
import LeeoKit
#endif

struct FirstShortcutOnboardingView: View {

    /// 만들어진 단축어를 알려준다 — 목록이 이걸 받아 "눌러보세요"를 띄운다.
    let onCreated: (Memo) -> Void
    let onSkip: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: Step = .greeting
    @State private var picked: Seed?
    @State private var value: String = ""
    @FocusState private var typing: Bool

    private enum Step { case greeting, pick, fill }

    /// 캘 만한 것들. 자주 쓰면서 **매번 치기 귀찮은** 것으로만 고른다 —
    /// 한 번 쓰고 말 문구는 아무리 예뻐도 다음 날 이 앱을 다시 열 이유가 안 된다.
    ///
    /// ⚠️ 고르는 자리에는 **상황**을 보여준다("지인에게 내 주소 알려주기").
    ///    "내 주소"만 있으면 그게 뭘 하는 건지, 왜 저장해 두면 좋은지가 안 보인다 —
    ///    처음 온 사람에게 필요한 건 항목 이름이 아니라 **언제 쓰는 물건인가**이다.
    ///
    /// ⚠️ 다만 **만들어지는 단축어 이름은 짧게**(`title`) 남긴다. 상황 문장을 그대로 이름으로
    ///    쓰면 카드와 키에 "지인에게 내 주소 알려주기"가 박혀 정작 목록에서 못 알아본다.
    struct Seed: Identifiable, Equatable {
        let id: String
        /// 고르는 자리에 보이는 **상황** 한 줄.
        let situation: String
        /// 실제로 만들어질 단축어 이름 — 카드·키에 박히므로 짧게.
        let title: String
        let placeholder: String
        let hint: String
    }

    private var seeds: [Seed] {
        [
            Seed(id: "address",
                 situation: NSLocalizedString("지인에게 내 주소 알려주기", comment: "Onboarding situation: share my address"),
                 title: NSLocalizedString("내 주소", comment: "Onboarding seed: home address"),
                 placeholder: NSLocalizedString("서울시 …", comment: "Onboarding seed placeholder: address"),
                 hint: NSLocalizedString("택배 보낼 때, 배달 주문할 때마다 치던 그 주소예요.", comment: "Onboarding seed hint: address")),
            Seed(id: "account",
                 situation: NSLocalizedString("입금받으려고 계좌번호 알려주기", comment: "Onboarding situation: share bank account"),
                 title: NSLocalizedString("계좌번호", comment: "Onboarding seed: bank account"),
                 placeholder: NSLocalizedString("○○은행 123-456-789", comment: "Onboarding seed placeholder: account"),
                 hint: NSLocalizedString("정산할 때마다 메모장을 열어 찾지 않아도 돼요.", comment: "Onboarding seed hint: account")),
            Seed(id: "email",
                 situation: NSLocalizedString("가입할 때 이메일 적기", comment: "Onboarding situation: type email when signing up"),
                 title: NSLocalizedString("이메일", comment: "Onboarding seed: email"),
                 placeholder: NSLocalizedString("me@example.com", comment: "Onboarding seed placeholder: email"),
                 hint: NSLocalizedString("가입할 때마다 오타 나던 그거요.", comment: "Onboarding seed hint: email"))
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            speech
            content
            Spacer(minLength: 0)
            skip
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
    }

    /// 첫 화면이 건네는 말. 단계마다 한 문장씩만 — 두 문장이 되면 안 읽는다.
    private var speech: some View {
        Text(line)
            .font(.title3.weight(.semibold))
            .foregroundColor(theme.text)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 14)
            .padding(.bottom, 20)
            .transition(.opacity)
            .id(line)
    }

    private var line: String {
        switch step {
        case .greeting:
            return NSLocalizedString("매번 똑같은 걸 치고 있지는 않나요? 도와드릴게요.", comment: "Onboarding line: greeting")
        case .pick:
            return NSLocalizedString("뭐부터 도와드릴까요?", comment: "Onboarding line: pick a seed")
        case .fill:
            return picked.map(\.hint) ?? ""
        }
    }

    // MARK: - 단계별 내용

    @ViewBuilder
    private var content: some View {
        switch step {
        case .greeting:
            Button {
                HapticManager.shared.light()
                withAnimation(.easeOut(duration: 0.25)) { step = .pick }
            } label: {
                primaryLabel(NSLocalizedString("좋아요", comment: "Onboarding: start button"))
            }
            .buttonStyle(.plain)

        case .pick:
            VStack(spacing: 10) {
                ForEach(seeds) { seed in
                    Button {
                        HapticManager.shared.light()
                        picked = seed
                        withAnimation(.easeOut(duration: 0.25)) { step = .fill }
                        typing = true
                    } label: {
                        HStack(spacing: 10) {
                            // 상황이 먼저 읽히고, 만들어질 이름은 그 아래에 작게.
                            VStack(alignment: .leading, spacing: 2) {
                                Text(seed.situation)
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(theme.text)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(seed.title)
                                    .font(.caption)
                                    .foregroundColor(theme.textMuted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: AppSymbol.chevronRight)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(theme.textFaint)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                                .fill(theme.surface)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

        case .fill:
            VStack(spacing: 14) {
                if let picked {
                    // 제목은 이미 정해졌다 — 채울 칸을 **하나만** 남긴다.
                    HStack {
                        Text(picked.title)
                            .font(.headline)
                            .foregroundColor(theme.text)
                        Spacer(minLength: 0)
                    }

                    TextField(picked.placeholder, text: $value, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                                .fill(theme.surface)
                        )
                        .focused($typing)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif

                    Button(action: save) {
                        primaryLabel(NSLocalizedString("이걸로 만들기", comment: "Onboarding: save the first shortcut"))
                    }
                    .buttonStyle(.plain)
                    .disabled(trimmed.isEmpty)
                    .opacity(trimmed.isEmpty ? 0.45 : 1)
                }
            }
        }
    }

    private func primaryLabel(_ text: String) -> some View {
        Text(text)
            .font(.body.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                    .fill(theme.accent)
            )
    }

    private var skip: some View {
        Button {
            HapticManager.shared.light()
            onSkip()
        } label: {
            Text(NSLocalizedString("나중에 할게요", comment: "Onboarding: skip"))
                .font(.footnote)
                .foregroundColor(theme.textFaint)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 18)
    }

    // MARK: - 저장

    private var trimmed: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 진짜 단축어로 저장한다. 연습용 가짜를 만들었다가 지우면 아무것도 안 남는다.
    private func save() {
        guard let picked, !trimmed.isEmpty else { return }

        var memo = Memo(title: picked.title, value: trimmed)
        memo.lastEdited = Date()

        do {
            var memos = (try? MemoStore.shared.load(type: .memo)) ?? []
            memos.insert(memo, at: 0)
            try MemoStore.shared.save(memos: memos, type: .memo)
            HapticManager.shared.success()
            onCreated(memo)
        } catch {
            print("❌ [FirstShortcutOnboarding.save] 첫 단축어 저장 실패: \(error)")
            // 저장이 실패했는데 완료로 넘기면 빈 목록에 "눌러보세요"만 남는다.
            onSkip()
        }
    }
}
