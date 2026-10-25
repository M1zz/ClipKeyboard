//
//  BlankStartIntro.swift
//  ClipKeyboard
//
//  백지 첫 실행의 **그림.** 10초쯤 혼자 돈다.
//
//  메모에 있는 계좌번호가 선택되고 복사되어 → 이 앱의 상자로 날아 들어가고 →
//  채팅 입력칸으로 꺼내져 들어간다. 위의 한 줄이 장면마다 바뀐다:
//  "다른 곳에 자주 쓰는 글이 있으면" → "복사해서 여기 담아 두세요" → "필요할 때 꺼내 쓰면 돼요"
//
//  ⚠️ 햅틱은 두 번뿐이다: 상자가 받아 삼킬 때(soft), 입력칸에 들어갈 때(light).
//

import SwiftUI
import LeeoKit

struct BlankStartIntro: View {
    let onDone: () -> Void

    @State private var caption = ""
    @State private var showCaption = false
    @State private var showMemo = false
    @State private var selected = false
    @State private var showCopyPill = false
    @State private var showBox = false
    @State private var boxGulp = false
    @State private var chip: ChipSpot = .hidden
    @State private var showChat = false
    @State private var chatFilled = false

    /// 날아다니는 글 조각이 어디 있는가.
    private enum ChipSpot { case hidden, memo, box, chat }

    var body: some View {
        VStack(spacing: 28) {
            Text(caption)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .opacity(showCaption ? 1 : 0)
                .offset(y: showCaption ? 0 : 8)
                .frame(minHeight: 64)
            stage
                .frame(height: 360)
        }
        .padding(.horizontal, 28)
        .task { await run() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(NSLocalizedString("다른 곳에 자주 쓰는 글이 있으면 복사해서 여기 담아 두세요. 필요할 때 꺼내 쓰면 돼요.",
                                              comment: "Blank start intro: whole animation read as one sentence for VoiceOver"))
    }

    // MARK: - 무대

    private var stage: some View {
        ZStack {
            memoCard
                .offset(y: -110)
                .opacity(showMemo ? (chip == .box || chip == .chat ? 0.25 : 1) : 0)
                .opacity(showChat ? 0 : 1)
            Text(NSLocalizedString("복사", comment: "Blank start intro: the system copy bubble"))
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Color.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 10))
                .offset(y: -170)
                .opacity(showCopyPill ? 1 : 0)
                .scaleEffect(showCopyPill ? 1 : 0.8)
            appBox
                .offset(y: 10)
                .opacity(showBox ? 1 : 0)
                .scaleEffect(showBox ? (boxGulp ? 1.08 : 1) : 0.7)
            chatCard
                .offset(y: 120)
                .opacity(showChat ? 1 : 0)
                .offset(y: showChat ? 0 : 16)
            flyingChip
        }
    }

    private var memoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("메모", comment: "Blank start intro: title of the notes card the text is copied from"))
                .font(.body.weight(.bold))
                .foregroundStyle(Color(red: 0.55, green: 0.48, blue: 0.18))
            Text(NSLocalizedString("입금은 여기로", comment: "Blank start intro: a line in the notes card before the account number"))
                .font(.body)
            Text(BlankStartSample.value)
                .font(.body)
                .padding(.horizontal, 2)
                .background(selected ? Color.accentColor.opacity(0.28) : .clear, in: RoundedRectangle(cornerRadius: 4))
        }
        .foregroundStyle(Color.black)
        .padding(16)
        .frame(width: 260, alignment: .leading)
        .background(Color(red: 1, green: 0.98, blue: 0.91), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(red: 0.94, green: 0.9, blue: 0.72)))
    }

    private var appBox: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Color.accentColor)
            .frame(width: 92, height: 92)
            .overlay(Image(systemName: AppSymbol.trayFill).font(.system(size: 40, weight: .semibold)).foregroundStyle(.white))
    }

    private var chatCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("계좌 알려 주실래요?", comment: "Blank start intro: a chat message asking for the account number"))
                .font(.body)
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 18))
            Text(chatFilled ? BlankStartSample.value
                 : NSLocalizedString("메시지", comment: "Blank start intro: placeholder of the chat input"))
                .font(.body)
                .foregroundStyle(chatFilled ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .overlay(Capsule().stroke(Color(.separator)))
        }
        .frame(width: 280)
    }

    private var flyingChip: some View {
        Text(BlankStartSample.value)
            .font(.body.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator)))
            .scaleEffect(chip == .box ? 0.5 : 1)
            .offset(y: chipY)
            .opacity(chip == .hidden ? 0 : 1)
    }

    private var chipY: CGFloat {
        switch chip {
        case .hidden, .memo: return -95
        case .box: return 10
        case .chat: return 145
        }
    }

    // MARK: - 순서

    private func say(_ text: String) async {
        withAnimation(.easeOut(duration: 0.3)) { showCaption = false }
        try? await Task.sleep(for: .milliseconds(300))
        caption = text
        withAnimation(.easeOut(duration: 0.45)) { showCaption = true }
    }

    private func wait(_ ms: Int) async { try? await Task.sleep(for: .milliseconds(ms)) }

    private func run() async {
        await wait(500)
        await say(NSLocalizedString("다른 곳에 자주 쓰는 글이 있으면", comment: "Blank start intro: line 1"))
        await wait(400)
        withAnimation(.easeOut(duration: 0.5)) { showMemo = true }
        await wait(1000)
        withAnimation(.easeOut(duration: 0.5)) { selected = true }
        await wait(500)
        withAnimation(.spring(duration: 0.25)) { showCopyPill = true }
        await wait(800)
        withAnimation(.easeOut(duration: 0.2)) { showCopyPill = false }
        withAnimation(.spring(duration: 0.4, bounce: 0.4)) { showBox = true }
        await say(NSLocalizedString("복사해서 여기 담아 두세요", comment: "Blank start intro: line 2"))
        chip = .memo
        await wait(300)
        withAnimation(.easeInOut(duration: 0.8)) { chip = .box }
        await wait(800)
        // 상자가 받아 삼키는 순간에만 약하게 한 번. 그림 내내 울리면 소음이다
        HapticManager.shared.soft()
        withAnimation(.spring(duration: 0.25)) { boxGulp = true; selected = false }
        chip = .hidden
        await wait(250)
        withAnimation(.spring(duration: 0.25)) { boxGulp = false }
        await wait(700)
        await say(NSLocalizedString("필요할 때 꺼내 쓰면 돼요", comment: "Blank start intro: line 3"))
        withAnimation(.easeOut(duration: 0.5)) { showChat = true }
        await wait(900)
        chip = .box
        await wait(50)
        withAnimation(.easeInOut(duration: 0.8)) { chip = .chat }
        await wait(850)
        chip = .hidden
        HapticManager.shared.light()
        withAnimation(.easeOut(duration: 0.2)) { chatFilled = true }
        await wait(1800)
        guard !Task.isCancelled else { return }
        onDone()
    }
}
