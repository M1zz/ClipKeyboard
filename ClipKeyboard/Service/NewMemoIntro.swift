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
            // 여기서 `withAnimation` 을 걸지 않는다. 어떤 곡선으로 들어올지는 **붙는 자리**가
            // 정한다(카드와 키캡은 크기가 달라 같은 곡선이 같게 안 보이고, 움직임 줄이기를
            // 켠 사람에게는 아예 다른 것을 줘야 한다). 여기서 걸면 그 선택을 빼앗는다.
            self.blankMemoId = nil
            self.revealTask = nil
        }
    }

    func isBlank(_ id: UUID) -> Bool { blankMemoId == id }
}

// MARK: - 붙이는 자리

/// 빈 자리가 무엇처럼 생겼는가. 카드와 키캡은 크기가 달라 같은 뼈대가 같게 안 보인다.
enum NewMemoIntroShape {
    /// 목록 카드. 위에서부터 두 줄.
    case card
    /// 키보드 키캡. 가운데 한 줄.
    case key

    var lines: [CGFloat] {
        switch self {
        case .card: return [1.0, 0.55]
        case .key:  return [0.7]
        }
    }

    /// 뼈대가 설 자리. **채워졌을 때 글이 서는 자리와 같아야 한다.**
    ///
    /// ⚠️ 카드에서 맨 위(`topLeading`)에 두면 안 된다. 카드의 제목은 위 아이콘 줄 아래,
    ///    세로 가운데쯤에 선다. 뼈대를 맨 위에 두면 "줄이 위에 있다가 글이 가운데 나타나는"
    ///    두 동작이 되어 같은 것이 채워졌다고 안 읽힌다.
    var alignment: Alignment {
        switch self {
        case .card: return .leading
        case .key:  return .center
        }
    }

    /// 뼈대 줄이 어느 쪽에 붙어 자라는가. 카드는 글이 왼쪽에서 시작하고,
    /// 키캡은 글이 가운데 선다. 뼈대도 그 자리에 있어야 들어올 글의 자리로 읽힌다.
    var lineAnchor: UnitPoint {
        switch self {
        case .card: return .leading
        case .key:  return .center
        }
    }
}

/// 방금 만든 것이면 잠깐 비워 뒀다가 내용을 들여보낸다.
///
/// ⚠️ **바탕이 아니라 내용에만 건다.** 카드의 면과 키캡은 그대로 서 있어야 한다.
///    거기까지 사라지면 "빈 자리가 생겼다" 가 아니라 "아무 일도 없었다" 가 된다.
///
/// ⚠️ 빈 동안 **가만히 두지 않는다.** 1초는 짧지 않아서, 아무 일도 안 일어나면
///    비어 있는 것이 연출이 아니라 고장으로 읽힌다. 뼈대 두 줄이 천천히 숨을 쉰다.
///
/// ⚠️ 움직임 줄이기를 켠 사람에게는 **숨도 스프링도 없다.** 밝기만 부드럽게 바뀐다.
///    이 연출의 뜻("여기에 생겼다")은 그것만으로도 전해진다.
struct NewMemoIntroFade: ViewModifier {

    let memoId: UUID
    let shape: NewMemoIntroShape

    @ObservedObject private var intro = NewMemoIntro.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    init(memoId: UUID, shape: NewMemoIntroShape) {
        self.memoId = memoId
        self.shape = shape
    }

    func body(content: Content) -> some View {
        let blank = intro.isBlank(memoId)
        return content
            .opacity(blank ? 0 : 1)
            // 살짝 작게, 살짝 아래에서, 살짝 흐리게 올라온다. 셋 다 아주 조금씩이다
            // 크게 주면 연출이 눈에 띄어 정작 무엇이 생겼는지를 가린다.
            .scaleEffect(blank && !reduceMotion ? 0.94 : 1)
            .offset(y: blank && !reduceMotion ? 8 : 0)
            .blur(radius: blank && !reduceMotion ? 2.5 : 0)
            .overlay(alignment: shape.alignment) {
                if blank {
                    skeleton
                        .transition(.opacity)
                }
            }
            // ⚠️ 오버레이보다 **뒤에** 건다. 앞에 걸면 뼈대가 사라지는 것은 이 곡선을 못 타서
            //    글이 부드럽게 올라오는 동안 뼈대만 툭 없어진다. 한 동작으로 보이지 않는다.
            .animation(revealCurve, value: blank)
            .onAppear { intro.noticeAppeared(memoId) }
    }

    /// 들어올 때의 곡선. 스프링이 끝에서 아주 조금 자리를 잡는다 - 툭 서는 것과
    /// 내려앉는 것의 차이가 "부드럽다" 로 읽히는 자리다.
    private var revealCurve: Animation {
        reduceMotion
            ? .easeInOut(duration: NewMemoIntro.revealDuration)
            : .spring(response: 0.55, dampingFraction: 0.78)
    }

    /// 아직 내용이 없는 동안 서 있는 뼈대.
    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(shape.lines.enumerated()), id: \.offset) { _, ratio in
                // 길이는 `scaleEffect` 로 준다. 폭을 숫자로 박으면 카드와 키캡에서
                // 같은 길이가 되어 한쪽에서는 넘치고 한쪽에서는 초라해진다.
                Capsule()
                    .fill(.tertiary)
                    .frame(height: 10)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: ratio, anchor: shape.lineAnchor)
            }
        }
        .opacity(breathing ? 0.5 : 0.22)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
}

/// 방금 만든 것이면 **자리 자체가 자라며 들어온다.**
///
/// 안쪽(`NewMemoIntroFade`)이 내용을 들여보내는 일을 한다면, 이쪽은 그 자리가 격자에
/// 끼어드는 순간을 맡는다. 이게 없으면 빈 카드가 툭 나타난 뒤에야 부드러워져서,
/// 연출의 첫 프레임이 제일 거칠다.
///
/// ⚠️ **방금 만든 그 하나만** 움직인다. 나타나는 모든 카드에 걸면 탭을 옮길 때마다
///    격자 전체가 피어나고, 그러면 새로 생긴 것이 어디인지는 오히려 안 보인다.
struct NewMemoIntroEntry: ViewModifier {

    let memoId: UUID

    @ObservedObject private var intro = NewMemoIntro.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entered = false

    init(memoId: UUID) {
        self.memoId = memoId
    }

    func body(content: Content) -> some View {
        let waiting = intro.isBlank(memoId) && !entered
        return content
            .scaleEffect(waiting && !reduceMotion ? 0.88 : 1)
            .opacity(waiting ? 0 : 1)
            .onAppear {
                guard intro.isBlank(memoId) else {
                    entered = true      // 남의 자리는 그냥 서 있는다
                    return
                }
                withAnimation(reduceMotion
                              ? .easeOut(duration: 0.25)
                              : .spring(response: 0.45, dampingFraction: 0.8)) {
                    entered = true
                }
            }
    }
}

extension View {
    /// 방금 만든 단축어면 빈 자리로 먼저 세운다. **내용에 건다**(바탕은 그대로 서 있어야 한다).
    func newMemoIntro(_ memoId: UUID, shape: NewMemoIntroShape = .card) -> some View {
        modifier(NewMemoIntroFade(memoId: memoId, shape: shape))
    }

    /// 방금 만든 단축어면 그 자리가 자라며 들어온다. **카드·키캡 바깥에 건다.**
    func newMemoEntry(_ memoId: UUID) -> some View {
        modifier(NewMemoIntroEntry(memoId: memoId))
    }
}
