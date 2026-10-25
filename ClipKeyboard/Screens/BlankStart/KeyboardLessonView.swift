//
//  KeyboardLessonView.swift
//  ClipKeyboard
//
//  **키보드 켜기 수업.** 첫 단축어를 V 로 저장한 바로 그때 뜬다.
//
//  그림(왜 켜는지) → 세 걸음 미리 보기(설정 앱 안에는 우리 안내를 띄울 수 없어서 가기 전에 보여 준다)
//  → 설정 앱 → 돌아오면 켜졌는지 확인 → 켜졌으면 진짜 입력칸에서 진짜 키보드로 한 번 보내 본다.
//
//  ⚠️ 앱은 사용자가 다른 앱에 간 순간을 알 수 없다. 그래서 가장 의욕이 있을 때(첫 단축어를 막 담은 때) 묻는다.
//  ⚠️ 전체 접근은 키보드가 한 번 떠야 알 수 있다. 꺼져 있으면 실습에서 키보드가 스스로 말한다
//     (`KeyboardAppLinkTests/fullAccessNoticeOnlyInExtensionWhenOff`).
//  ⚠️ "나중에 다시" 를 고르면 목록 위에 한 줄로 남는다(`KeyboardLessonBanner`). 켤 때까지만.
//  ⚠️ 햅틱: 키보드로 글이 들어옴 = success, 보내기 = soft. 그 밖에는 고르기 단추의 selection 뿐.
//

import SwiftUI
import LeeoKit
import UIKit

struct KeyboardLessonView: View {
    let onClose: () -> Void

    @State private var phase: Phase = .demo
    @State private var waitingForReturn = false
    @State private var text = ""
    @State private var bubbles: [String] = []
    /// 담아 둔 카드 값이 키보드로 실제로 들어왔는가. 이때만 '키보드 켜기' 를 배운 것으로 적는다.
    @State private var insertedByKeyboard = false
    @FocusState private var fieldFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Phase: Equatable { case demo, howto, notYet, practice, sent }

    /// 키보드에 서 있을 카드(이름 · 값). 지금 목록 그대로.
    private let snippets: [(title: String, value: String)] = {
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        return memos.filter { !$0.isSecure && !$0.value.isEmpty }.map { ($0.title, $0.value) }
    }()

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                    .padding(.top, 40)
                    .padding(.bottom, 18)
                content
                    .frame(maxHeight: .infinity)
                footer
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
        .onAppear { if reduceMotion { phase = .howto } }
        // 펼친 듀오: 접힌 선 위에 글이 걸리지 않게 한쪽 판에만 선다
        .foldConfined { Color(.systemBackground).ignoresSafeArea() }
        .onChange(of: scenePhase) { _, p in
            guard p == .active, waitingForReturn else { return }
            waitingForReturn = false
            // 시스템이 `AppleKeyboards` 를 비추는 데 한 박자 걸린다(KeyboardSetupOnboardingView.verifySetup)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    phase = KeyboardInstallState.isUsable ? .practice : .notYet
                }
                if phase == .practice {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { fieldFocused = true }
                }
            }
        }
    }

    // MARK: - 머리말

    private var header: some View {
        VStack(spacing: 8) {
            Text(line).font(.title2.weight(.bold))
            Text(subline).font(.body).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .animation(.easeInOut(duration: 0.3), value: phase)
    }

    private var line: String {
        switch phase {
        case .demo: return NSLocalizedString("이제 다른 앱에서 써 볼까요?", comment: "Keyboard lesson: demo line")
        case .howto: return NSLocalizedString("키보드를 한 번만 켜 두면 돼요", comment: "Keyboard lesson: how-to line")
        case .notYet: return NSLocalizedString("아직 안 켜졌어요", comment: "Keyboard lesson: came back but keyboard is not on")
        case .practice: return NSLocalizedString("켜졌어요. 써 볼까요?", comment: "Keyboard lesson: keyboard is on, try it")
        case .sent: return NSLocalizedString("이제 어느 앱에서든 이렇게 써요", comment: "Keyboard lesson: done")
        }
    }

    private var subline: String {
        switch phase {
        case .demo: return NSLocalizedString("메시지를 쓰다가 지구본을 누르면", comment: "Keyboard lesson: demo subline")
        case .howto: return NSLocalizedString("설정에서 이렇게 하세요", comment: "Keyboard lesson: how-to subline")
        case .notYet: return NSLocalizedString("2번 '클립키보드 켜기'만 하면 돼요", comment: "Keyboard lesson: not on yet subline")
        case .practice:
            return text.isEmpty
                ? NSLocalizedString("지구본을 눌러 클립키보드로 바꾸고, 카드를 누르세요", comment: "Keyboard lesson: practice subline")
                : NSLocalizedString("들어갔어요. 보내 보세요", comment: "Keyboard lesson: practice, text inserted")
        case .sent: return NSLocalizedString("카톡 · 문자 · 메일 어디서든 지구본 한 번", comment: "Keyboard lesson: done subline")
        }
    }

    // MARK: - 가운데

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .demo:
            KeyboardLessonDemo(snippets: snippets.isEmpty ? [(BlankStartSample.title, BlankStartSample.value)] : snippets) {
                withAnimation(.easeInOut(duration: 0.4)) { phase = .howto }
            }
            .transition(.opacity)
        case .howto, .notYet:
            steps.transition(.opacity)
        case .practice, .sent:
            practice.transition(.opacity)
        }
    }

    private var steps: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            step(1, NSLocalizedString("키보드", comment: "Keyboard lesson step 1 title"),
                 NSLocalizedString("설정에서 '키보드'를 누르세요", comment: "Keyboard lesson step 1 detail"))
            step(2, NSLocalizedString("클립키보드 켜기", comment: "Keyboard lesson step 2 title"),
                 NSLocalizedString("스위치를 켜세요", comment: "Keyboard lesson step 2 detail"))
            step(3, NSLocalizedString("전체 접근 허용 켜기", comment: "Keyboard lesson step 3 title"),
                 NSLocalizedString("담아 둔 글을 키보드가 읽으려면 필요해요", comment: "Keyboard lesson step 3 detail"))
            Spacer(minLength: 0)
        }
    }

    private func step(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            Text("\(n)")
                .font(.body.weight(.heavy))
                .foregroundStyle(Color(.systemBackground))
                .frame(width: 30, height: 30)
                .background(Color.primary, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(detail).font(.body).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var practice: some View {
        VStack(spacing: 10) {
            ScrollView {
                VStack(alignment: .trailing, spacing: 8) {
                    Text(NSLocalizedString("주소 좀 보내 줄래?", comment: "Keyboard lesson demo: incoming chat message"))
                        .font(.body)
                        .padding(.horizontal, 13).padding(.vertical, 9)
                        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 18))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(bubbles.enumerated()), id: \.offset) { _, b in
                        Text(b)
                            .font(.body).foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
                    }
                }
                .padding(.top, 8)
            }
            .defaultScrollAnchor(.bottom)
            HStack(spacing: 8) {
                // 진짜 입력칸. 여기에 진짜 키보드가 뜬다
                TextField(NSLocalizedString("메시지", comment: "Blank start intro: placeholder of the chat input"), text: $text)
                    .font(.body)
                    .focused($fieldFocused)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .overlay(Capsule().stroke(Color.accentColor, lineWidth: 1.5))
                    .onChange(of: text) { _, new in
                        // 담아 둔 값이 통째로 들어왔으면 키보드로 넣은 것이다
                        if !insertedByKeyboard, snippets.contains(where: { new.contains($0.value) }) {
                            insertedByKeyboard = true
                            HapticManager.shared.success()
                        }
                    }
                Button(action: send) {
                    Image(systemName: AppSymbol.arrowUp)
                        .font(.body.weight(.bold)).foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(text.isEmpty ? Color(.systemGray4) : Color.accentColor, in: Circle())
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel(NSLocalizedString("보내기", comment: "Blank start: send button"))
            }
        }
    }

    // MARK: - 아래 단추

    @ViewBuilder
    private var footer: some View {
        switch phase {
        case .demo:
            EmptyView()
        case .practice:
            // ⚠️ 실습에도 나갈 길을 둔다. 전체 접근이 꺼져 있거나 키보드가 잘 안 뜨면 카드를 못 넣는데,
            //    예전에는 단추가 하나도 없어 그대로 갇혔다(설계 검토, 2026-10).
            laterButton
        case .howto, .notYet:
            VStack(spacing: 8) {
                primaryButton(phase == .notYet
                              ? NSLocalizedString("다시 가기", comment: "Keyboard lesson: go to Settings again")
                              : NSLocalizedString("키보드 켜러 가기", comment: "Keyboard lesson: open Settings"),
                              action: openSettings)
                laterButton
                Text(NSLocalizedString("입력하는 글은 어디로도 보내지 않아요", comment: "Keyboard lesson: privacy line"))
                    .font(.body).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        case .sent:
            primaryButton(NSLocalizedString("목록으로", comment: "Keyboard lesson: back to the list"), action: onClose)
        }
    }

    private var laterButton: some View {
        Button {
            HapticManager.shared.selection()
            UserDefaults.standard.set(true, forKey: DefaultsKey.keyboardLessonDeferred)
            AnalyticsService.log(.keyboardLessonDeferred)
            onClose()
        } label: {
            Text(NSLocalizedString("나중에 다시", comment: "Keyboard lesson: postpone"))
                .font(.body).foregroundStyle(.secondary)
                .padding(8)
        }
        .buttonStyle(.plain)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            Text(title)
                .font(.body.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .foregroundStyle(Color(.systemBackground))
                .background(Color.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: - 동작

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        waitingForReturn = true
        UIApplication.shared.open(url)
        print("⚙️ [KeyboardLessonView.openSettings] 설정 앱으로")
    }

    private func send() {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        HapticManager.shared.soft()
        withAnimation(.spring(duration: 0.45, bounce: 0.35)) { bubbles.append(t) }
        text = ""
        fieldFocused = false
        // 손으로 친 글을 보낸 것은 키보드를 배운 것이 아니다. 카드가 들어와야 배운 것이다
        guard insertedByKeyboard else { return }
        LessonLedger.learn(.keyboard)
        UserDefaults.standard.set(false, forKey: DefaultsKey.keyboardLessonDeferred)
        withAnimation(.easeInOut(duration: 0.3)) { phase = .sent }
    }
}

// MARK: - 나중에 다시 → 목록 위 한 줄

/// "나중에 다시" 를 고른 사람의 목록 위에 남는 한 줄. 켤 때까지만.
struct KeyboardLessonBanner: View {
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(NSLocalizedString("키보드를 켜면 어느 앱에서든 바로 넣을 수 있어요", comment: "Keyboard lesson banner on the list"))
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                HapticManager.shared.selection()
                onOpen()
            } label: {
                Text(NSLocalizedString("켜기", comment: "Keyboard lesson banner: turn on button"))
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.accentColor, in: Capsule())
            }
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// 지금 띄울 때인가: 미뤄 뒀고, 아직 안 배웠고, 아직 안 켰다.
    static var isDue: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.keyboardLessonDeferred)
            && !LessonLedger.hasLearned(.keyboard)
            && !KeyboardInstallState.isUsable
    }
}
