//
//  ClipKeyboardRoadmap.swift
//  ClipKeyboard
//
//  **앞으로 만들 것**의 원본. 설정 ▸ 앞으로 만들 기능(`LeeoRoadmapView`)이 이 목록을 그대로 보여 준다.
//
//  ⚠️ 개발하다 "이건 다음에" 가 생기면 **여기에 한 줄을 더한다.** 코드의 TODO 주석으로만 남기지 않는다.
//     - 새 항목: `.planned`. 손대기 시작하면 `.building`. **내보내면 목록에서 뺀다.**
//       이 화면은 '앞으로 만들 기능' 이라 이미 나온 것이 남으면 안 만든 것처럼 읽힌다(2026-10 사용자).
//       무엇이 언제 나왔는지는 릴리즈 노트(RELEASE_NOTES.md · docs/release-notes/)가 기록한다.
//     - id 는 한 번 정하면 바꾸지 않는다(문구는 바꿔도 된다).
//     - 문구는 사용자 말로 쓴다(내부 이름 · 기술 용어 금지). 번역은 `scripts/i18n.py` 가 한다.
//     - 사용자에게 보일 만한 것만 적는다. 리팩터링 · 시험 · 빌드 설정은 `.sprintcommander/tasks.json` 의 몫이다.
//     규칙: docs/engineering/ROADMAP.md
//

import SwiftUI
import LeeoKit

extension ClipKeyboardSpec {
    static var roadmap: [LeeoRoadmapItem] {[
        // MARK: 만들고 있어요
        .init(id: "a11y.contrast", status: .building,
              title: NSLocalizedString("보기 편한 색과 대비", comment: "Roadmap item: better colors and contrast"),
              detail: NSLocalizedString("대비를 높이거나 색을 구별하기 어려워도 내용을 알아볼 수 있어요.", comment: "Roadmap item detail: colors and contrast")),


        // MARK: 다음에 만들어요
        .init(id: "keyboard.autocorrect", status: .planned,
              title: NSLocalizedString("자동 고침과 낱말 추천", comment: "Roadmap item: autocorrect and word suggestions"),
              detail: NSLocalizedString("틀린 글자를 고쳐 주고, 칠 낱말을 미리 보여 줘요.", comment: "Roadmap item detail: autocorrect and suggestions")),
        .init(id: "keyboard.kanji", status: .planned,
              title: NSLocalizedString("일본어·중국어 한자 변환", comment: "Roadmap item: kanji and hanzi conversion"),
              detail: NSLocalizedString("가나·병음·주음을 한자로 바꿔요. 사전은 필요할 때만 받아요.", comment: "Roadmap item detail: kanji conversion with on-demand dictionary")),
        .init(id: "sync.stable", status: .planned,
              title: NSLocalizedString("기기 간 동기화 정식판", comment: "Roadmap item: stable cross-device sync"),
              detail: NSLocalizedString("지금은 베타예요. 더 안정되게 다듬어 정식으로 열어요.", comment: "Roadmap item detail: stable sync")),
        .init(id: "sync.conflict", status: .planned,
              title: NSLocalizedString("동기화가 엇갈릴 때 고르는 화면", comment: "Roadmap item: sync conflict picker"),
              detail: NSLocalizedString("두 기기에서 같은 단축어를 고쳤을 때 어느 쪽을 남길지 직접 골라요.", comment: "Roadmap item detail: sync conflict picker")),
        .init(id: "link.preview", status: .planned,
              title: NSLocalizedString("링크 단축어 미리보기", comment: "Roadmap item: link previews"),
              detail: NSLocalizedString("저장한 링크의 제목과 그림을 목록에서 바로 보여 줘요.", comment: "Roadmap item detail: link previews")),
        .init(id: "a11y.voiceover", status: .planned,
              title: NSLocalizedString("VoiceOver로 더 편하게", comment: "Roadmap item: better VoiceOver support"),
              detail: NSLocalizedString("화면 읽기 기능이 단추와 내용을 빠짐없이, 알맞은 순서로 읽어 줘요.", comment: "Roadmap item detail: better VoiceOver support")),
        .init(id: "a11y.largetext", status: .planned,
              title: NSLocalizedString("큰 글씨에 맞춘 화면", comment: "Roadmap item: layouts that fit large text sizes"),
              detail: NSLocalizedString("글자 크기를 키워도 잘리지 않고 보기 좋게 다시 배치돼요.", comment: "Roadmap item detail: large text layouts")),

    ]}
}

// MARK: - 화면

/// 설정 ▸ 앞으로 만들 기능. "이런 기능이 있으면 좋겠어요" 는 기능 제안으로 시작하는 피드백 창을 연다.
struct RoadmapScreen: View {
    @Environment(\.appTheme) private var theme
    @State private var showFeedback = false

    var body: some View {
        LeeoRoadmapView<ClipKeyboardSpec>(onSuggest: { showFeedback = true })
            .leeoStyle(theme.leeoStyle)
            .sheet(isPresented: $showFeedback) {
                NavigationStack {
                    FeedbackView(origin: .settings, initialType: .feature)
                }
            }
    }
}
