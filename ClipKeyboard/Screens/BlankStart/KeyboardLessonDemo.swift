//
//  KeyboardLessonDemo.swift
//  ClipKeyboard
//
//  키보드 켜기 수업의 **그림.** 왜 켜는지를 먼저 보여 준다.
//
//  메시지 앱에서 "주소 좀 보내 줄래?" 가 와 있다 → 지구본이 빛난다 → 키보드가 클립키보드로
//  바뀌고 담아 둔 카드들이 서 있다 → 방금 만든 카드가 눌리고 입력칸에 들어간다.
//
//  ⚠️ 그림이다. 누를 수 없다. 진짜로 해 보는 것은 키보드를 켠 뒤의 실습이다(`KeyboardLessonView`).
//

import SwiftUI
import LeeoKit

struct KeyboardLessonDemo: View {
    /// 키보드에 세울 카드들(이름 · 값). 마지막 것이 방금 만든 것이다.
    let snippets: [(title: String, value: String)]
    let onDone: () -> Void

    @State private var globeGlow = false
    @State private var showCards = false
    @State private var pressed = false
    @State private var filled = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Spacer(minLength: 0)
                Text(NSLocalizedString("주소 좀 보내 줄래?", comment: "Keyboard lesson demo: incoming chat message"))
                    .font(.body)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 16))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            Text(filled ? (snippets.last?.value ?? "") : NSLocalizedString("메시지", comment: "Blank start intro: placeholder of the chat input"))
                .font(.body)
                .lineLimit(1)
                .foregroundStyle(filled ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Color(.systemBackground), in: Capsule())
                .overlay(Capsule().stroke(Color(.separator)))
                .padding(.horizontal, 10).padding(.bottom, 8)
            keyboard
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .task { await run() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(NSLocalizedString("메시지를 쓰다가 지구본을 누르면 담아 둔 단축어가 키보드에 서 있어요. 누르면 바로 들어가요.",
                                              comment: "Keyboard lesson demo: whole animation for VoiceOver"))
    }

    // MARK: - 키보드 그림

    private var keyboard: some View {
        ZStack {
            letters.opacity(showCards ? 0 : 1)
            cards.opacity(showCards ? 1 : 0)
        }
        .frame(height: 176)
        .background(Color(.systemGray4))
    }

    private var letters: some View {
        let rows = ["ㅂㅈㄷㄱㅅㅛㅕㅑㅐㅔ", "ㅁㄴㅇㄹㅎㅗㅓㅏㅣ", "ㅋㅌㅊㅍㅠㅜㅡ"]
        return VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 5) {
                    ForEach(Array(row), id: \.self) { ch in key(String(ch)) }
                }
            }
            HStack(spacing: 5) {
                key("123", wide: 44, dim: true)
                Image(systemName: AppSymbol.globe)
                    .font(.body)
                    .frame(width: 40, height: 34)
                    .background(Color(.systemGray2), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(BlankStartPulse(active: globeGlow, cornerRadius: 6))
                key(NSLocalizedString("스페이스", comment: "Keyboard lesson demo: space bar label"), wide: nil)
                key("return", wide: 64, dim: true)
            }
        }
        .padding(.horizontal, 5)
    }

    private func key(_ t: String, wide: CGFloat? = 28, dim: Bool = false) -> some View {
        Text(t)
            .font(.body)
            .frame(maxWidth: wide ?? .infinity)
            .frame(width: wide, height: 34)
            .background(dim ? Color(.systemGray2) : Color(.systemBackground), in: RoundedRectangle(cornerRadius: 6))
    }

    private var cards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(Array(snippets.suffix(4).enumerated()), id: \.offset) { i, s in
                let isLast = i == min(snippets.count, 4) - 1
                Text(s.title)
                    .font(.body.weight(.bold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(isLast && pressed ? Color.accentColor.opacity(0.25) : Color(.systemBackground),
                                in: RoundedRectangle(cornerRadius: 12))
                    .scaleEffect(isLast && pressed ? 0.95 : 1)
            }
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - 순서

    private func wait(_ ms: Int) async { try? await Task.sleep(for: .milliseconds(ms)) }

    private func run() async {
        await wait(900)
        globeGlow = true
        await wait(1300)
        globeGlow = false
        withAnimation(.easeInOut(duration: 0.3)) { showCards = true }
        await wait(1400)
        withAnimation(.spring(duration: 0.25)) { pressed = true }
        HapticManager.shared.light()
        await wait(250)
        withAnimation(.spring(duration: 0.25)) { pressed = false; filled = true }
        await wait(1600)
        guard !Task.isCancelled else { return }
        onDone()
    }
}
