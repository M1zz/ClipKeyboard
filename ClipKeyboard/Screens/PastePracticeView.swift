//
//  PastePracticeView.swift
//  ClipKeyboard
//
//  **붙여넣어 보기** — 온보딩의 마지막 한 걸음.
//
//  복사까지만 시키고 끝내면 "복사됐다"로 끝난다. 복사는 이 앱이 해 준 일이고,
//  값어치는 **그 다음에 안 친 것**에 있다. 그래서 붙여넣는 순간까지 데려간다.
//
//  ⚠️ 붙여넣기 버튼을 크게 달지 않는다. 버튼을 누르는 건 연습이 아니다 —
//     길게 눌러 '붙여넣기'를 고르는 그 동작을 손에 익혀야 내일 다른 앱에서도 쓴다.
//     (한참 못 찾는 사람을 위해 몇 초 뒤에만 도움 버튼을 조용히 내놓는다.)
//
//  ⚠️ 성공 판정은 **붙여넣은 값이 복사한 값과 같은지**로 한다. 아무 글자나 치고
//     넘어가면 "안 쳐도 된다"는 말을 자기 손으로 반증하게 된다.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
import LeeoKit
#endif

struct PastePracticeView: View {

    /// 방금 복사한 값. 이게 그대로 들어오면 성공이다.
    let expected: String
    let onDone: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var typed: String = ""
    @State private var succeeded = false
    @State private var showsHelp = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Text(headline)
                .font(.title3.weight(.semibold))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
                .id(headline)

            Text(subline)
                .font(.subheadline)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .padding(.bottom, 22)
                .id(subline)

            field

            if succeeded {
                Button(action: onDone) {
                    Text(NSLocalizedString("다 됐어요", comment: "Paste practice: finish"))
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
                .padding(.top, 18)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if showsHelp {
                helpButton
                    .padding(.top, 14)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)

            Button(action: onDone) {
                Text(NSLocalizedString("건너뛰기", comment: "Paste practice: skip"))
                    .font(.footnote)
                    .foregroundColor(theme.textFaint)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 18)
            .opacity(succeeded ? 0 : 1)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
        .onAppear {
            focused = true
            // 한참 못 찾는 사람에게만 도움을 내놓는다. 처음부터 보이면 다들 그걸 누른다.
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                if !succeeded { withAnimation { showsHelp = true } }
            }
        }
        .onChange(of: typed) { _, new in
            check(new)
        }
    }

    // MARK: - 문구

    private var headline: String {
        succeeded
            ? NSLocalizedString("보셨죠? 한 글자도 안 쳤어요.", comment: "Paste practice: success headline")
            : NSLocalizedString("여기에 붙여넣어 보세요", comment: "Paste practice: headline")
    }

    private var subline: String {
        succeeded
            ? NSLocalizedString("이제 어디서든 이렇게 쓰면 돼요.", comment: "Paste practice: success subline")
            : NSLocalizedString("직접 입력하지 마세요. 꾹 누르고 '붙여넣기'를 고르면 돼요.",
                                comment: "Paste practice: subline")
    }

    // MARK: - 입력칸

    private var field: some View {
        TextField("", text: $typed, axis: .vertical)
            .lineLimit(1...4)
            .textFieldStyle(.plain)
            .font(.body)
            .focused($focused)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                    .fill(theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                    .strokeBorder(succeeded ? Color.green.opacity(0.7) : theme.accent.opacity(0.45),
                                  lineWidth: 1.5)
            )
            .animation(Delight.motion(.once, reduceMotion: reduceMotion), value: succeeded)
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            #endif
    }

    /// 못 찾는 사람을 위한 조용한 대안. 이걸 눌러도 성공으로 친다 —
    /// 여기서 막혀 나가는 것보다는 한 번 보는 편이 낫다.
    private var helpButton: some View {
        Button {
            #if canImport(UIKit)
            typed = UIPasteboard.general.string ?? ""
            #endif
        } label: {
            Text(NSLocalizedString("잘 안 되면 여기를 눌러요", comment: "Paste practice: fallback paste button"))
                .font(.footnote.weight(.medium))
                .foregroundColor(theme.accent)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 판정

    private func check(_ new: String) {
        guard !succeeded else { return }
        let a = new.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = expected.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !b.isEmpty, a == b else { return }

        focused = false
        #if canImport(UIKit)
        HapticManager.shared.success()
        #endif
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { succeeded = true }
    }
}
