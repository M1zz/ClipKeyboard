//
//  NewMemoIntro.swift
//  ClipKeyboard
//
//  방금 만든 단축어를 **빈 자리로 먼저 세웠다가** 내용을 들여보내는 연출.
//
//  왜 필요한가: 사용자 요청.
//
//    "지금 추가를 하면 너무 뷰가 바로 생기는데 (...) 빈 것을 생성하고 나서
//     1초 뒤에 그 안에 내용을 채우는 것과 같은 느낌을 주도록"
//
//  만들자마자 완성된 카드가 격자 어딘가에 툭 나타나면, 그게 어디에 생겼는지 눈이 못 쫓는다.
//  빈 자리가 먼저 서면 눈이 거기로 가고, 그 다음 내용이 들어오는 것을 **본다.**
//  같은 결과지만 어디에 무엇이 생겼는지가 남는다.
//
//  ⚠️ **화면에 나타난 뒤부터 시간을 센다.** 저장 화면은 저장하고 1초 뒤에 닫히므로
//     (`MemoAddViewModel.saveMemo`), 저장한 순간부터 세면 그 1초가 시트 뒤에서 다 지나가고
//     사용자는 아무것도 못 본다. 그래서 표시만 걸어 두고, 카드가 실제로 나타났다고
//     알려 오면(`noticeAppeared`) 그때부터 센다.
//
//  ⚠️ 끝내 안 나타날 수도 있다(다른 탭에 생겼거나, 화면을 바로 떠났거나). 그때를 위해
//     스스로 푸는 시간을 둔다. 안 두면 그 단축어는 다음에 열 때도 빈 카드로 서 있다.
//

import SwiftUI

@MainActor
final class NewMemoIntro: ObservableObject {

    static let shared = NewMemoIntro()

    /// 빈 자리로 서 있는 시간. 요청받은 그대로 1초다.
    static let blankDuration: TimeInterval = 1.0
    /// 내용이 들어올 때의 속도.
    static let revealDuration: TimeInterval = 0.35
    /// 화면에 끝내 안 나타나면 이만큼 뒤에 스스로 푼다.
    private static let giveUpAfter: TimeInterval = 12

    /// 지금 비워 둔 단축어. nil 이면 아무 일도 없다.
    @Published private(set) var blankMemoId: UUID?

    private var revealTask: Task<Void, Never>?
    private var giveUpTask: Task<Void, Never>?
    private var observer: NSObjectProtocol?

    private init() {
        // 새 단축어가 저장되면 알려 온다(`MemoAddViewModel.saveMemo`). 화면마다 따로
        // 받아 넘기지 않는다 - 그러면 새 화면을 만들 때마다 이어 붙이는 것을 잊는다.
        observer = NotificationCenter.default.addObserver(
            forName: .memoSaved, object: nil, queue: .main
        ) { note in
            guard let id = note.object as? UUID else { return }
            Task { @MainActor in NewMemoIntro.shared.begin(id) }
        }
    }

    /// 이 단축어를 빈 자리로 세운다. **아직 시간을 세지 않는다.**
    func begin(_ id: UUID) {
        revealTask?.cancel()
        revealTask = nil
        giveUpTask?.cancel()
        blankMemoId = id
        giveUpTask = Task { [id] in
            try? await Task.sleep(for: .seconds(Self.giveUpAfter))
            guard !Task.isCancelled, self.blankMemoId == id else { return }
            self.blankMemoId = nil
        }
    }

    /// 그 자리가 화면에 나타났다. **여기서부터 1초를 센다.**
    func noticeAppeared(_ id: UUID) {
        guard blankMemoId == id, revealTask == nil else { return }
        revealTask = Task { [id] in
            try? await Task.sleep(for: .seconds(Self.blankDuration))
            guard !Task.isCancelled, self.blankMemoId == id else { return }
            withAnimation(.easeOut(duration: Self.revealDuration)) {
                self.blankMemoId = nil
            }
            self.revealTask = nil
        }
    }

    func isBlank(_ id: UUID) -> Bool { blankMemoId == id }
}

// MARK: - 붙이는 자리

/// 방금 만든 것이면 잠깐 비워 뒀다가 내용을 들여보낸다.
///
/// ⚠️ **바탕이 아니라 내용에만 건다.** 카드의 면과 키캡은 그대로 서 있어야 한다.
///    거기까지 사라지면 "빈 자리가 생겼다"가 아니라 "아무 일도 없었다"가 된다.
///
/// ⚠️ 나타날 때는 애니메이션을 걸지 않는다. 비어 있는 것이 시작 상태라 그냥 그렇게 서면 되고,
///    들여보낼 때만 `NewMemoIntro` 가 `withAnimation` 으로 움직인다.
struct NewMemoIntroFade: ViewModifier {

    let memoId: UUID
    @ObservedObject private var intro = NewMemoIntro.shared

    init(memoId: UUID) {
        self.memoId = memoId
    }

    func body(content: Content) -> some View {
        let blank = intro.isBlank(memoId)
        return content
            .opacity(blank ? 0 : 1)
            .scaleEffect(blank ? 0.97 : 1)
            .onAppear { intro.noticeAppeared(memoId) }
    }
}

extension View {
    /// 방금 만든 단축어면 빈 자리로 먼저 세운다.
    func newMemoIntro(_ memoId: UUID) -> some View {
        modifier(NewMemoIntroFade(memoId: memoId))
    }
}
