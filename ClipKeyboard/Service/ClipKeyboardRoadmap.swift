//
//  ClipKeyboardRoadmap.swift
//  ClipKeyboard
//
//  **앞으로 만들 것**의 원본. 설정 ▸ 앞으로 만들 기능(`LeeoRoadmapView`)이 이 목록을 그대로 보여 준다.
//
//  ⚠️ 개발하다 "이건 다음에" 가 생기면 **여기에 한 줄을 더한다.** 코드의 TODO 주석으로만 남기지 않는다.
//     - 새 항목: `.planned`. 손대기 시작하면 `.building`. 내보내면 `.shipped("5.2.0")`.
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
        .init(id: "capture.button", status: .building,
              title: NSLocalizedString("복사하고 버튼 한 번으로 담기", comment: "Roadmap item: capture clipboard with the Action Button"),
              detail: NSLocalizedString("동작 버튼이나 제어 센터를 누르면 방금 복사한 글이 키보드 '최근'에 담겨요.", comment: "Roadmap item detail: capture clipboard")),
        .init(id: "gift.pro", status: .building,
              title: NSLocalizedString("Pro 선물하기", comment: "Roadmap item: gift Pro"),
              detail: NSLocalizedString("결제는 보내는 분이 하고, Pro는 받는 분이 써요.", comment: "Roadmap item detail: gift Pro")),

        // MARK: 다음에 만들어요
        .init(id: "sync.stable", status: .planned,
              title: NSLocalizedString("기기 간 동기화 정식판", comment: "Roadmap item: stable cross-device sync"),
              detail: NSLocalizedString("지금은 베타예요. 더 안정되게 다듬어 정식으로 열어요.", comment: "Roadmap item detail: stable sync")),
        .init(id: "sync.conflict", status: .planned,
              title: NSLocalizedString("동기화가 엇갈릴 때 고르는 화면", comment: "Roadmap item: sync conflict picker"),
              detail: NSLocalizedString("두 기기에서 같은 단축어를 고쳤을 때 어느 쪽을 남길지 직접 골라요.", comment: "Roadmap item detail: sync conflict picker")),
        .init(id: "link.preview", status: .planned,
              title: NSLocalizedString("링크 단축어 미리보기", comment: "Roadmap item: link previews"),
              detail: NSLocalizedString("저장한 링크의 제목과 그림을 목록에서 바로 보여 줘요.", comment: "Roadmap item detail: link previews")),
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
