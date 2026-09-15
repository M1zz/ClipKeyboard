//
//  UserStageSimulatorView.swift
//  ClipKeyboard
//
//  단계 하나를 고르면 앱이 그 단계 사람의 것처럼 보인다. **개발자 전용**(마스터 모드).
//
//  ⚠️ 내 데이터는 백업된다(`DemoDataService`). 끄면 그대로 돌아온다.
//     그래도 화면 맨 아래에 그 말을 적어 둔다 - 처음 누르는 사람은 알 수 없는 일이다.
//

import SwiftUI

struct UserStageSimulatorView: View {

    @Environment(\.appTheme) private var theme
    @ObservedObject private var userState = UserStateStore.shared
    @State private var activeStage: UserStage? = UserStageSimulator.activeStage
    @State private var failureMessage: String?

    var body: some View {
        List {
            currentSection
            stageSection
            if activeStage != nil { offSection }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.bg)
        .navigationTitle(NSLocalizedString("사용 단계 흉내 (개발자)", comment: "Stage simulator screen title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(NSLocalizedString("단계를 바꾸지 못했어요", comment: "Stage simulator failure alert title"),
               isPresented: Binding(get: { failureMessage != nil },
                                    set: { if !$0 { failureMessage = nil } })) {
            Button(NSLocalizedString("확인", comment: "Confirm button")) { failureMessage = nil }
        } message: {
            Text(failureMessage ?? "")
        }
    }

    // MARK: - 지금 상태

    private var currentSection: some View {
        Section {
            LabeledContent(NSLocalizedString("숙련도", comment: "Stage simulator: level"),
                           value: userState.state.level.localizedName)
            LabeledContent(NSLocalizedString("기간", comment: "Stage simulator: tenure"),
                           value: userState.state.tenure.localizedName)
            LabeledContent(NSLocalizedString("결", comment: "Stage simulator: grain"),
                           value: userState.state.grain.localizedName)
            LabeledContent(NSLocalizedString("앞에 세운 안내", comment: "Stage simulator: leading prompt"),
                           value: userState.leadingSurface.map(\.rawValue)
                               ?? NSLocalizedString("없음", comment: "Stage simulator: nothing leading"))
        } header: {
            Text(NSLocalizedString("지금 앱이 보는 나", comment: "Stage simulator: current state header"))
        } footer: {
            if activeStage == nil {
                Text(NSLocalizedString("진짜 내 기록으로 판정한 값입니다.", comment: "Stage simulator: real state footer"))
            }
        }
    }

    // MARK: - 단계 고르기

    private var stageSection: some View {
        Section {
            ForEach(UserStage.allCases) { stage in
                Button { select(stage) } label: {
                    StageRow(stage: stage, isActive: activeStage == stage)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(activeStage == stage ? [.isSelected] : [])
            }
        } header: {
            Text(NSLocalizedString("단계", comment: "Stage simulator: stage list header"))
        } footer: {
            Text(NSLocalizedString("고른 단계의 단축어와 클립보드 기록이 깔리고, 안내와 감춤도 그 사람 것으로 바뀝니다. 내 데이터는 보관되고 끄면 그대로 돌아옵니다.", comment: "Stage simulator: stage list footer"))
        }
    }

    private var offSection: some View {
        Section {
            Button(role: .destructive) { turnOff() } label: {
                Label(NSLocalizedString("끄고 내 데이터로 돌아가기", comment: "Stage simulator: turn off"),
                      systemImage: AppSymbol.arrowUturnBackward)
            }
        }
    }

    // MARK: - 줄 하나

    private struct StageRow: View {
        @Environment(\.appTheme) private var theme
        let stage: UserStage
        let isActive: Bool

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(stage.title)
                        .font(.body.weight(isActive ? .semibold : .regular))
                        .foregroundColor(theme.text)
                    Text(stage.summary)
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if isActive {
                    Image(systemName: AppSymbol.checkmark)
                        .foregroundColor(theme.accent)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
    }

    // MARK: - 동작

    private func select(_ stage: UserStage) {
        if activeStage == stage { turnOff(); return }
        guard UserStageSimulator.apply(stage) else {
            failureMessage = NSLocalizedString("데이터를 보관하지 못해 단계를 켜지 않았습니다. 내 단축어는 그대로입니다.",
                                               comment: "Stage simulator: apply failed message")
            return
        }
        activeStage = stage
        refreshEverything()
    }

    private func turnOff() {
        UserStageSimulator.clear()
        activeStage = nil
        refreshEverything()
    }

    /// 목록 화면들도 같이 다시 읽게 한다. 설정에서 나가야 바뀌면 흉내가 반쯤만 걸린다.
    private func refreshEverything() {
        userState.refresh()
        NotificationCenter.postOnMain(name: .memoDataChanged, object: nil)
    }
}
