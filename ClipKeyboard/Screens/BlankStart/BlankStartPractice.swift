//
//  BlankStartPractice.swift
//  ClipKeyboard
//
//  백지 첫 실행의 **직접 해 보기.**
//
//  ① 버튼을 눌러 복사 → ② 입력칸에 붙여넣기 → ③ 보내기(말풍선이 생긴다) →
//  ④ 이번엔 버튼만 눌러 입력칸에 바로 넣기 → ⑤ 한 번 더 보내기.
//  ②와 ④의 대비가 이 앱이 하는 일이다. 복사해서 붙여넣던 것을 버튼 한 번으로.
//
//  ⚠️ 입력칸은 진짜 TextField 다. 붙여넣기도 iOS 의 진짜 '붙여넣기' 로 한다. 손이 실제로 하는 일을 배운다.
//  ⚠️ 햅틱: 복사 = success, 붙여넣기 · 바로 넣기가 들어감 = light, 보내기 = soft. 그 밖에는 울리지 않는다.
//

import SwiftUI
import LeeoKit
import UIKit

struct BlankStartPractice: View {
    enum Step: Equatable { case copy, paste, send, insert, sendAgain }

    let startAt: Step
    let onDone: () -> Void

    @State private var step: Step
    @State private var text = ""
    @State private var bubbles: [String] = []
    @State private var line = ""
    @State private var subline = ""
    @State private var lineShown = true
    @State private var showToast = false
    @State private var buttonUsed = false
    @State private var typing = false
    @FocusState private var fieldFocused: Bool

    init(startAt: Step, onDone: @escaping () -> Void) {
        self.startAt = startAt
        self.onDone = onDone
        _step = State(initialValue: startAt)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 말풍선이 생기기 전에는 하얀 화면 가운데에 버튼 하나만 선다
            if bubbles.isEmpty { Spacer(minLength: 0) } else { chat }
            VStack(spacing: 8) {
                Text(line).font(.title2.weight(.bold))
                Text(subline).font(.body).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .opacity(lineShown ? 1 : 0)
            .offset(y: lineShown ? 0 : 8)
            .padding(.vertical, 18)
            sampleButton
            if step != .copy {
                inputRow
                    .padding(.top, 22)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if step == .copy { Spacer(minLength: 0) }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
        .overlay(alignment: .top) { toast }
        .onAppear { enter(step) }
        .onChange(of: text) { _, new in pasted(new) }
    }

    // MARK: - 조각

    private var chat: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 8) {
                ForEach(Array(bubbles.enumerated()), id: \.offset) { _, b in
                    Text(b)
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
                }
                if !bubbles.isEmpty {
                    Text(NSLocalizedString("보냄", comment: "Blank start: small 'sent' mark under the last chat bubble"))
                        .font(.body).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 24)
        }
        .defaultScrollAnchor(.bottom)
        .scrollIndicators(.hidden)
    }

    private var sampleButton: some View {
        Button(action: tapSample) {
            VStack(spacing: 4) {
                Text(BlankStartSample.title).font(.title3.weight(.bold))
                Text(BlankStartSample.value).font(.body).foregroundStyle(.secondary)
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 30).padding(.vertical, 16)
            .background(buttonUsed ? Color.accentColor.opacity(0.14) : Color(.secondarySystemFill),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(BlankStartPulse(active: sampleIsNext, cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .disabled(!(step == .copy || step == .insert) || typing)
        .accessibilityHint(step == .insert
                           ? NSLocalizedString("입력칸에 바로 넣어요", comment: "Blank start: hint for the sample button in the insert step")
                           : NSLocalizedString("복사해요", comment: "Blank start: hint for the sample button in the copy step"))
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField(NSLocalizedString("여기를 누르세요", comment: "Blank start: placeholder of the practice input field"), text: $text)
                .font(.body)
                .focused($fieldFocused)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .overlay(Capsule().stroke(fieldFocused || step == .paste ? Color.accentColor : Color(.separator),
                                          lineWidth: step == .paste ? 2.5 : 1.5))
                // "여기에 붙여넣어 보세요" 의 '여기' 가 어딘지 보이게 입력칸이 물결친다. 붙여넣으면 거둔다
                .overlay(BlankStartPulse(active: step == .paste && text.isEmpty, cornerRadius: 26))
                .disabled(step == .insert)
            Button(action: send) {
                Image(systemName: AppSymbol.arrowUp)
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(canSend ? Color.accentColor : Color(.systemGray4), in: Circle())
                    .overlay(BlankStartPulse(active: canSend && step == .send, cornerRadius: 22))
            }
            .disabled(!canSend)
            .accessibilityLabel(NSLocalizedString("보내기", comment: "Blank start: send button"))
        }
    }

    @ViewBuilder
    private var toast: some View {
        if showToast {
            Text(NSLocalizedString("복사했어요", comment: "Blank start: toast after copying the sample"))
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.black.opacity(0.85), in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// 지금 물결로 짚어 줄 곳이 이 버튼인가. 누르고 난 뒤(흐려진 동안)에는 물결을 거둔다.
    /// 다 했는데 계속 물결치면 시선만 끌고, 또 누르라는 말로 읽힌다.
    ///
    /// ⚠️ 물결은 "지금 누를 곳" 에만 건다: 복사 버튼 · 붙여넣을 입력칸 · 첫 보내기 · 바로 넣기 버튼.
    ///    "이번엔 버튼만 눌러 보세요" 에서도 누르기 전까지는 물결친다. 두 번째 보내기에는 없다.
    private var sampleIsNext: Bool {
        (step == .copy || step == .insert) && !buttonUsed && !typing
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty && !typing && (step == .send || step == .sendAgain)
    }

    // MARK: - 걸음

    private func say(_ a: String, _ b: String) {
        withAnimation(.easeOut(duration: 0.2)) { lineShown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            line = a; subline = b
            withAnimation(.easeOut(duration: 0.4)) { lineShown = true }
        }
    }

    private func enter(_ s: Step) {
        withAnimation(.easeInOut(duration: 0.35)) { step = s }
        switch s {
        case .copy:
            buttonUsed = false
            say(NSLocalizedString("눌러 보세요", comment: "Blank start: copy step line"),
                NSLocalizedString("자주 쓰는 계좌번호를 담아 뒀어요", comment: "Blank start: copy step subline"))
        case .paste:
            say(NSLocalizedString("여기에 붙여넣어 보세요", comment: "Blank start: paste step line"),
                NSLocalizedString("입력칸을 누르고, 한 번 더 눌러 '붙여넣기'를 고르세요", comment: "Blank start: paste step subline, how to paste on iOS"))
        case .send:
            fieldFocused = false
            say(NSLocalizedString("보내 볼까요?", comment: "Blank start: send step line"),
                NSLocalizedString("오른쪽 파란 화살표를 누르세요", comment: "Blank start: send step subline"))
        case .insert:
            buttonUsed = false
            text = ""
            say(NSLocalizedString("이번엔 버튼만 눌러 보세요", comment: "Blank start: insert step line"),
                NSLocalizedString("붙여넣지 않아도 바로 들어가요", comment: "Blank start: insert step subline"))
        case .sendAgain:
            say(NSLocalizedString("한 번에 들어갔죠?", comment: "Blank start: after the button typed the text in"),
                NSLocalizedString("보내기까지 눌러 보세요", comment: "Blank start: send again subline"))
        }
    }

    private func tapSample() {
        buttonUsed = true
        if step == .copy {
            UIPasteboard.general.string = BlankStartSample.value
            HapticManager.shared.success()
            withAnimation(.spring(duration: 0.3)) { showToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { showToast = false } }
            LessonLedger.learn(.copy)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { enter(.paste) }
        } else if step == .insert {
            typeIn(BlankStartSample.value)
        }
    }

    /// 붙여넣기가 들어왔는가. 직접 쳐서 같은 글을 만들어도 된다.
    private func pasted(_ new: String) {
        guard step == .paste, new.contains(BlankStartSample.value) else { return }
        HapticManager.shared.light()
        LessonLedger.learn(.paste)
        enter(.send)
    }

    /// 버튼이 대신 쳐 준다. 키보드가 하는 일을 눈으로 보이게 글자가 흐른다.
    private func typeIn(_ value: String) {
        typing = true
        text = ""
        HapticManager.shared.light()
        let chars = Array(value)
        for (i, c) in chars.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.028) {
                text.append(c)
                if i == chars.count - 1 {
                    typing = false
                    LessonLedger.learn(.insert)
                    enter(.sendAgain)
                }
            }
        }
    }

    private func send() {
        guard canSend else { return }
        HapticManager.shared.soft()
        withAnimation(.spring(duration: 0.45, bounce: 0.35)) { bubbles.append(text) }
        text = ""
        if step == .send {
            LessonLedger.learn(.send)
            say(NSLocalizedString("아, 이렇게 보내는 거예요", comment: "Blank start: after the first message is sent"),
                NSLocalizedString("복사해 두고 꺼내 쓰는 것, 이게 전부예요", comment: "Blank start: after the first message is sent, subline"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { enter(.insert) }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onDone() }
        }
    }
}

// MARK: - 눌러 볼 곳을 알리는 물결

/// 다음에 누를 곳 하나에만 건다. 둘이 동시에 물결치면 어디를 누를지 모른다.
struct BlankStartPulse: View {
    let active: Bool
    let cornerRadius: CGFloat

    var body: some View {
        // ⚠️ 꺼지면 물결을 **통째로 걷는다.** 투명도만 0 으로 두면 끝없이 도는 애니메이션이
        //    살아 남아, 다른 값이 바뀔 때 다시 비쳐 보였다(버튼이 흐려진 뒤에도 물결이 남던 것).
        if active {
            Ring(cornerRadius: cornerRadius)
                .transition(.opacity)
        }
    }

    private struct Ring: View {
        let cornerRadius: CGFloat
        @State private var on = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            RoundedRectangle(cornerRadius: cornerRadius + 6, style: .continuous)
                .stroke(Color.accentColor, lineWidth: 3)
                .padding(-6)
                .scaleEffect(on ? 1.1 : 0.97)
                .opacity(on ? 0 : 0.9)
                .allowsHitTesting(false)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { on = true }
                }
        }
    }
}
