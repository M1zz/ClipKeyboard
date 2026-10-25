//
//  FeatureLessonView.swift
//  ClipKeyboard
//
//  **기능 수업.** 그 기능을 처음 켤 때(설정 ▸ 기능 더하기 · 넛지의 "켜고 해 보기") 한 번,
//  가이드북에서는 언제든 다시. 하얀 화면에서 그림으로 직접 해 본다.
//
//  템플릿: 이름 칩을 누르면 빈칸이 바뀌어 채워진다 / 스택: 키를 세 번 누르면 값이 차례로 들어간다 /
//  보안: 가려진 카드를 누르면 Face ID 뒤에 드러난다 / 분류: 탭을 누르면 그 분류만 남는다 /
//  최근: '복사' 를 누르면 최근 목록 맨 위에 들어간다.
//
//  ⚠️ 다 하면 장부에 적는다(`LessonLedger`). 건너뛰어도 기능은 켜진 채다.
//  ⚠️ 시안: docs/design/blank-start-onboarding.html (FeatureLesson)
//

import SwiftUI
import LeeoKit

struct FeatureLessonView: View {
    let feature: AppFeature
    let onClose: () -> Void

    @State private var line = ""
    @State private var subline = ""
    @State private var done = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text(line).font(.title2.weight(.bold))
                    Text(subline).font(.body).foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: line)
                .padding(.top, 48)
                FeatureLessonStage(feature: feature, say: say, finish: finish)
                    .frame(maxHeight: .infinity)
                if done {
                    Button {
                        HapticManager.shared.selection()
                        onClose()
                    } label: {
                        Text(NSLocalizedString("알겠어요", comment: "Keyboard stage intro: dismiss"))
                            .font(.body.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .foregroundStyle(Color(.systemBackground))
                            .background(Color.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .transition(.opacity)
                } else {
                    Button {
                        onClose()
                    } label: {
                        Text(NSLocalizedString("건너뛰기", comment: "Feature lesson: skip"))
                            .font(.body).foregroundStyle(.secondary).padding(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
        // 펼친 듀오: 접힌 선 위에 글이 걸리지 않게 한쪽 판에만 선다
        .appFoldConfined { Color(.systemBackground).ignoresSafeArea() }
    }

    private func say(_ a: String, _ b: String) {
        line = a
        subline = b
    }

    private func finish(_ a: String, _ b: String) {
        say(a, b)
        LessonLedger.learn(feature.lesson)
        HapticManager.shared.success()
        withAnimation(.easeInOut(duration: 0.4).delay(0.3)) { done = true }
    }
}

// MARK: - 기능마다 해 보는 것

private struct FeatureLessonStage: View {
    let feature: AppFeature
    let say: (String, String) -> Void
    let finish: (String, String) -> Void

    // 템플릿
    @State private var name: String?
    @State private var picks = 0
    // 스택
    @State private var stackLines: [String] = []
    // 보안
    @State private var faceID = false
    @State private var revealed = false
    // 분류
    @State private var tab = ""
    @State private var tabTaps = 0
    // 최근
    @State private var recentCopied = false

    var body: some View {
        VStack(spacing: 18) {
            switch feature {
            case .template: template
            case .stack: stack
            case .secure: secure
            case .category: category
            case .recent: recent
            }
        }
        .onAppear(perform: intro)
    }

    private func intro() {
        switch feature {
        case .template:
            say(NSLocalizedString("빈칸이 있는 글이에요", comment: "Feature lesson template: line"),
                NSLocalizedString("넣을 이름을 눌러 보세요", comment: "Feature lesson template: subline"))
        case .stack:
            say(NSLocalizedString("값이 여럿인 키예요", comment: "Feature lesson stack: line"),
                NSLocalizedString("키를 세 번 눌러 보세요", comment: "Feature lesson stack: subline"))
        case .secure:
            say(NSLocalizedString("민감한 글은 잠가 둬요", comment: "Feature lesson secure: line"),
                NSLocalizedString("카드를 눌러 보세요", comment: "Feature lesson secure: subline"))
        case .category:
            tab = allTab
            say(NSLocalizedString("나눠 담을 수 있어요", comment: "Feature lesson category: line"),
                NSLocalizedString("'업무'를 눌러 보세요", comment: "Feature lesson category: subline"))
        case .recent:
            say(NSLocalizedString("복사한 글이 저절로 남아요", comment: "Feature lesson recent: line"),
                NSLocalizedString("메모의 '복사'를 눌러 보세요", comment: "Feature lesson recent: subline"))
        }
    }

    // MARK: 템플릿

    private var template: some View {
        VStack(spacing: 18) {
            card {
                (Text(name ?? NSLocalizedString("이름", comment: "Feature lesson template: the blank's label"))
                    .foregroundColor(name == nil ? .accentColor : .green)
                    .fontWeight(.bold)
                 + Text(NSLocalizedString("님 안녕하세요, 문의 주셔서 감사합니다.", comment: "Feature lesson template: text after the name blank")))
                    .font(.body)
            }
            HStack(spacing: 8) {
                ForEach(names, id: \.self) { n in
                    chip(n, on: name == n, pulse: picks == 0 && n == names.first) {
                        withAnimation(.spring(duration: 0.35)) { name = n }
                        HapticManager.shared.light()
                        picks += 1
                        if picks == 1 {
                            say(NSLocalizedString("들어갔어요", comment: "Feature lesson template: after first pick"),
                                NSLocalizedString("다른 이름도 눌러 보세요", comment: "Feature lesson template: pick another"))
                        } else if picks == 2 {
                            finish(NSLocalizedString("한 글로 여러 사람에게", comment: "Feature lesson template: done line"),
                                   NSLocalizedString("새 단축어 내용에 {이름} 처럼 쓰면 빈칸이 돼요", comment: "Feature lesson template: done subline"))
                        }
                    }
                }
            }
        }
    }

    private var names: [String] {
        [NSLocalizedString("김서연", comment: "Feature lesson template: sample person name 1"),
         NSLocalizedString("박도윤", comment: "Feature lesson template: sample person name 2"),
         NSLocalizedString("홍길동", comment: "Feature lesson template: sample person name 3")]
    }

    // MARK: 스택

    private var stackValues: [String] {
        [NSLocalizedString("홍길동", comment: "Feature lesson template: sample person name 3"),
         NSLocalizedString("개발팀", comment: "Feature lesson stack: sample team"),
         NSLocalizedString("배포 점검", comment: "Feature lesson stack: sample task")]
    }

    private var stack: some View {
        VStack(spacing: 18) {
            let n = stackLines.count
            Button {
                guard n < stackValues.count else { return }
                HapticManager.shared.light()
                withAnimation(.spring(duration: 0.3)) { stackLines.append(stackValues[n]) }
                if n + 1 == 1 {
                    say(NSLocalizedString("한 번 누를 때마다", comment: "Feature lesson stack: after first tap"),
                        NSLocalizedString("다음 값이 차례로 들어가요", comment: "Feature lesson stack: after first tap subline"))
                } else if n + 1 == stackValues.count {
                    finish(NSLocalizedString("양식 칸을 차례로 채울 때 좋아요", comment: "Feature lesson stack: done line"),
                           NSLocalizedString("새 단축어에서 내용을 더하면 스택이 돼요", comment: "Feature lesson stack: done subline"))
                }
            } label: {
                VStack(spacing: 4) {
                    Text(NSLocalizedString("출근 보고", comment: "Feature lesson stack: sample stack name")).font(.title3.weight(.bold))
                    Text(n < stackValues.count ? "\(n + 1)/\(stackValues.count) → \(stackValues[n])"
                         : NSLocalizedString("다 넣었어요", comment: "Feature lesson stack: all values entered"))
                        .font(.body).foregroundStyle(.secondary)
                }
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 28).padding(.vertical, 16)
                .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(BlankStartPulse(active: n == 0, cornerRadius: 18))
            }
            .buttonStyle(.plain)
            card {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(stackLines, id: \.self) { Text($0).font(.body).transition(.move(edge: .bottom).combined(with: .opacity)) }
                }
                .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
            }
        }
    }

    // MARK: 보안

    private var secure: some View {
        VStack(spacing: 22) {
            Button {
                guard !revealed else { return }
                withAnimation(.spring(duration: 0.4)) { faceID = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                    withAnimation(.easeInOut(duration: 0.3)) { faceID = false; revealed = true }
                    finish(NSLocalizedString("본인만 꺼낼 수 있어요", comment: "Feature lesson secure: done line"),
                           NSLocalizedString("옆 사람 화면에도 값이 보이지 않아요", comment: "Feature lesson secure: done subline"))
                }
            } label: {
                VStack(spacing: 4) {
                    Text(NSLocalizedString("카드번호", comment: "Feature lesson secure: sample card title")).font(.title3.weight(.bold))
                    Text(revealed ? "1234-5678-9012-1234" : "•••• •••• •••• 1234")
                        .font(.body.monospacedDigit()).foregroundStyle(.secondary)
                }
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 28).padding(.vertical, 16)
                .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(BlankStartPulse(active: !faceID && !revealed, cornerRadius: 18))
            }
            .buttonStyle(.plain)
            Image(systemName: AppSymbol.faceid)
                .font(.system(size: 54))
                .foregroundStyle(Color.accentColor)
                .opacity(faceID ? 1 : 0)
                .scaleEffect(faceID ? 1 : 0.6)
        }
    }

    // MARK: 분류

    private var allTab: String { NSLocalizedString("전체", comment: "Category tab: all") }
    private var workTab: String { NSLocalizedString("업무", comment: "Feature lesson category: work tab") }
    private var personalTab: String { NSLocalizedString("개인", comment: "Feature lesson category: personal tab") }

    private var category: some View {
        let items: [(String, String)] = [
            (NSLocalizedString("계좌번호", comment: "Blank start: example snippet title (bank account)"), personalTab),
            (NSLocalizedString("회사 이메일", comment: "Feature lesson category: sample work email"), workTab),
            (NSLocalizedString("집 주소", comment: "Feature lesson category: sample home address"), personalTab),
            (NSLocalizedString("출근 보고", comment: "Feature lesson stack: sample stack name"), workTab)]
        return VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach([allTab, workTab, personalTab], id: \.self) { t in
                    chip(t, on: tab == t, pulse: tabTaps == 0 && t == workTab) {
                        withAnimation(.spring(duration: 0.35)) { tab = t }
                        HapticManager.shared.light()
                        tabTaps += 1
                        if tabTaps == 1 {
                            say(NSLocalizedString("업무 것만 남았어요", comment: "Feature lesson category: after first tap"),
                                NSLocalizedString("'개인'도 눌러 보세요", comment: "Feature lesson category: tap personal"))
                        } else if tabTaps == 2 {
                            finish(NSLocalizedString("많아지면 탭으로 찾아요", comment: "Feature lesson category: done line"),
                                   NSLocalizedString("목록에서 옆으로 넘기면 분류가 바뀌어요", comment: "Feature lesson category: done subline"))
                        }
                    }
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(items.filter { tab == allTab || $0.1 == tab }, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.0).font(.body.weight(.bold))
                        Text(item.1).font(.body).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
                    .padding(12)
                    .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    // MARK: 최근

    private var recent: some View {
        let text = NSLocalizedString("내일 7시 강남역 2번 출구", comment: "Feature lesson recent: sample copied text")
        return VStack(spacing: 16) {
            card {
                HStack {
                    Text(text).font(.body)
                    Spacer(minLength: 8)
                    Button {
                        guard !recentCopied else { return }
                        HapticManager.shared.light()
                        withAnimation(.spring(duration: 0.4)) { recentCopied = true }
                        finish(NSLocalizedString("'최근' 탭에 30일 동안 있어요", comment: "Feature lesson recent: done line"),
                               NSLocalizedString("담아 두지 않은 것도 다시 꺼내 써요", comment: "Feature lesson recent: done subline"))
                    } label: {
                        Text(NSLocalizedString("복사", comment: "Blank start intro: the system copy bubble"))
                            .font(.body.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color(.secondarySystemFill), in: Capsule())
                            .overlay(BlankStartPulse(active: !recentCopied, cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            VStack(spacing: 8) {
                if recentCopied { recentRow(text, NSLocalizedString("방금", comment: "Feature lesson recent: just now"), new: true) }
                recentRow("6012-3456-7890", NSLocalizedString("15분 전", comment: "Feature lesson recent: 15 minutes ago"), new: false)
                recentRow(NSLocalizedString("서울 마포구 월드컵북로 396", comment: "Feature lesson recent: sample address"),
                          NSLocalizedString("1시간 전", comment: "Feature lesson recent: 1 hour ago"), new: false)
            }
        }
    }

    private func recentRow(_ t: String, _ when: String, new: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t).font(.body)
            Text(when).font(.body).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(new ? Color.accentColor.opacity(0.14) : Color(.secondarySystemFill),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: 공용

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(.separator)))
    }

    private func chip(_ t: String, on: Bool, pulse: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t)
                .font(.body.weight(.bold))
                .foregroundStyle(on ? Color(.systemBackground) : Color.primary)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(on ? Color.primary : Color(.secondarySystemFill), in: Capsule())
                .overlay(BlankStartPulse(active: pulse, cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}
