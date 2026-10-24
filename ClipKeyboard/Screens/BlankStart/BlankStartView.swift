//
//  BlankStartView.swift
//  ClipKeyboard
//
//  **백지 첫 실행.** 새로 설치한 사람이 처음 보는 화면이다.
//
//  하얀 화면에서 그림으로 한 번 보여 주고(복사해서 담아 두고 필요할 때 꺼내 쓴다),
//  직접 눌러 복사 → 붙여넣기 → 보내기 → 버튼으로 바로 넣기를 해 본다. 끝에서
//  "내 단축어 만들러 가기" 와 "이 앱으로 할 수 있는 일 더 알아보기" 중 고른다.
//
//  ⚠️ 옛 튜토리얼(단축어 · 템플릿 · 스택 · 크기)을 대신한다. 기존 사용자는 이 화면을 보지 않는다
//     (`DefaultsKey.blankStartV1` 은 새 설치에서만 켜진다).
//  ⚠️ 어디까지 했는지는 `LessonLedger` 에 적는다. 끝내기 전에 앱이 꺼지면 처음부터 다시 한다(맥락이 날아가서).
//  ⚠️ 시안: docs/design/blank-start-onboarding.html
//

import SwiftUI
import LeeoKit

struct BlankStartView: View {
    /// 첫 실행을 끝냈다. 목록으로 간다.
    let onFinish: () -> Void

    @State private var stage: Stage = BlankStartView.resumeStage()
    @State private var showLearnMore = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Stage: Equatable {
        case intro
        case practice(BlankStartPractice.Step)
        case choose
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            switch stage {
            case .intro:
                BlankStartIntro {
                    LessonLedger.learn(.intro)
                    withAnimation(.easeInOut(duration: 0.4)) { stage = .practice(.copy) }
                }
                .transition(.opacity)
            case .practice(let step):
                BlankStartPractice(startAt: step) {
                    withAnimation(.easeInOut(duration: 0.4)) { stage = .choose }
                }
                .transition(.opacity)
            case .choose:
                chooseView
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showLearnMore) { BlankStartLearnMoreSheet() }
        .onAppear {
            // 움직임 줄이기를 켠 사람에게 10초짜리 그림을 돌리지 않는다. 같은 말을 글로 하고 바로 해 본다.
            if reduceMotion, stage == .intro {
                LessonLedger.learn(.intro)
                stage = .practice(.copy)
            }
        }
    }

    // MARK: - 고르기

    private var chooseView: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(NSLocalizedString("이게 클립키보드예요", comment: "Blank start: final line after trying the app"))
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            Text(NSLocalizedString("키보드에 이 버튼들이 서 있어서, 어느 앱에서든 한 번에 넣어요",
                                   comment: "Blank start: what the keyboard does, under the final line"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                HapticManager.shared.selection()
                makeOwn()
            } label: {
                Text(NSLocalizedString("내 단축어 만들러 가기", comment: "Blank start: go to my snippet list"))
                    .font(.body.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .foregroundStyle(Color(.systemBackground))
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            Button {
                HapticManager.shared.selection()
                showLearnMore = true
            } label: {
                Text(NSLocalizedString("이 앱으로 할 수 있는 일 더 알아보기", comment: "Blank start: open the list of what the app can do"))
                    .font(.body.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .foregroundStyle(Color.primary)
                    .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
    }

    /// 방금 써 본 그 버튼이 목록의 첫 단축어로 남는다.
    private func makeOwn() {
        BlankStartSample.insertIfNeeded()
        UserDefaults.standard.set(true, forKey: DefaultsKey.blankStartFinished)
        print("✅ [BlankStartView.makeOwn] 첫 실행 끝, 목록으로")
        onFinish()
    }

    // MARK: - 다시 켰을 때

    /// 첫 실행을 **끝내기 전에** 앱이 꺼졌으면 처음(그림)부터 다시 한다.
    ///
    /// ⚠️ 중간부터 잇지 않는다. "이번엔 버튼만 눌러 보세요" 는 앞에서 복사 · 붙여넣기를 해 본
    ///    사람에게만 뜻이 있다. 그 맥락이 날아간 채 중간에서 시작하면 무엇과 무엇을 견주는지 모른다.
    ///    다 끝냈으면(바로 넣기까지) 고르기 화면에서 연다.
    static func resumeStage() -> Stage {
        guard LessonLedger.nextFirstRunLesson() == nil else {
            LessonLedger.forget(Lesson.firstRun)
            return .intro
        }
        return .choose
    }
}

// MARK: - 예시 단축어

/// 첫 실행에서 눌러 보는 예시. 끝나면 이것 하나가 목록에 덩그러니 남는다.
enum BlankStartSample {
    static var title: String {
        NSLocalizedString("계좌번호", comment: "Blank start: example snippet title (bank account)")
    }
    static var value: String {
        NSLocalizedString("신한 110-123-456789", comment: "Blank start: example bank account value. Use a bank name common in the locale and keep the made-up number format")
    }

    /// 목록에 예시 하나를 남긴다. 이미 같은 것이 있으면 넣지 않는다.
    static func insertIfNeeded() {
        do {
            var memos = (try? MemoStore.shared.load(type: .memo)) ?? []
            guard !memos.contains(where: { $0.title == title && $0.value == value }) else { return }
            memos.append(Memo(title: title, value: value))
            try MemoStore.shared.save(memos: memos, type: .memo)
            print("✅ [BlankStartSample.insertIfNeeded] 예시 단축어 남김")
        } catch {
            print("❌ [BlankStartSample.insertIfNeeded] 저장 실패: \(error)")
        }
    }
}
