//
//  TwoFingerTap.swift
//  ClipKeyboard
//
//  두 손가락으로 톡 치는 몸짓. **목록 화면의 것**이다 - 고르기 화면은 이걸 모른다.
//
//  왜 생겼나: 사용자 피드백.
//
//    really cool would be to be able to switch to select mode by means of 2 finger tap
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - 두 손가락 탭

/// 두 손가락 탭이라는 문을 열어 둘지.
///
/// ⛔️ **보이스오버가 켜져 있으면 열지 않는다.** 보이스오버에서 두 손가락 탭은 이미
///    시스템의 것이다(읽기를 멈추고 다시 잇는 몸짓). 그 위에 우리 것을 얹으면 사용자가
///    말을 멈추려 할 때마다 엉뚱한 화면이 열린다. 우리 지름길 하나 때문에 그 사람이
///    앱을 쓰는 방식 전체가 어긋나는 것이라, 여기서는 우리가 물러난다.
///
/// 물러나도 길이 끊기지는 않는다. 같은 문이 꾹 누르기 판에 '여러 개 고르기'로 서 있고,
/// 그쪽은 보이스오버로도 그대로 닿는다.
///
/// 순수 함수로 떼어 둔 이유는 이 약속을 시험이 지킬 수 있게 하려는 것이다.
enum TwoFingerTapAvailability {
    static func isAllowed(voiceOverRunning: Bool) -> Bool {
        !voiceOverRunning
    }

    #if os(iOS)
    @MainActor
    static var isAllowedNow: Bool {
        isAllowed(voiceOverRunning: UIAccessibility.isVoiceOverRunning)
    }
    #endif
}

#if os(iOS)
/// 두 손가락으로 톡 치면 여러 개 고르기로 들어간다.
///
/// ⚠️ SwiftUI 의 `TapGesture` 는 손가락 **개수**를 못 센다. 그래서 UIKit 인식기를 빌린다.
///
/// ⚠️ 인식기를 자기 자신이 아니라 **위쪽 뷰**에 단다. 이 뷰는 `hitTest` 에서 nil 을 돌려
///    손가락을 그대로 통과시키므로(카드 탭·스크롤이 그대로 산다), 자기한테 달면 아무것도
///    못 받는다. 조상 뷰에 달린 인식기는 자손에서 시작한 터치도 함께 본다.
///
/// ⚠️ 붙는 자리는 **가장 가까운 스크롤 뷰**다. 창까지 거슬러 올라가 붙이면 탭바 너머
///    다른 탭에서 두 손가락을 대도 이 화면이 열린다. 목록이 사는 스크롤 뷰에 붙이면
///    카드가 없는 빈 자리까지 딱 그 페이지만 문이 된다.
private struct TwoFingerTapCatcher: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> PassthroughView {
        let view = PassthroughView()
        view.onAttach = { host in
            let recognizer = UITapGestureRecognizer(target: context.coordinator,
                                                    action: #selector(Coordinator.fire))
            recognizer.numberOfTouchesRequired = 2
            recognizer.numberOfTapsRequired = 1
            recognizer.delegate = context.coordinator
            // 스크롤·카드 탭과 자리를 다투지 않는다. 두 손가락 탭이 실제로 인식될 때만
            // 아래 뷰의 터치가 취소된다(cancelsTouchesInView 기본값).
            host.addGestureRecognizer(recognizer)
            context.coordinator.attached = (host, recognizer)
            // 보이스오버가 켜져 있으면 인식기를 아예 꺼 둔다. 켜 둔 채 시작만 막으면
            // 몸짓 겨루기에는 계속 끼어 있어서 시스템 몸짓을 늦출 수 있다.
            context.coordinator.startWatchingVoiceOver()
        }
        return view
    }

    func updateUIView(_ uiView: PassthroughView, context: Context) {
        context.coordinator.action = action
    }

    static func dismantleUIView(_ uiView: PassthroughView, coordinator: Coordinator) {
        if let (host, recognizer) = coordinator.attached {
            host.removeGestureRecognizer(recognizer)
        }
        coordinator.attached = nil
        coordinator.stopWatchingVoiceOver()
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var action: () -> Void
        var attached: (UIView, UIGestureRecognizer)?
        private var voiceOverObserver: NSObjectProtocol?

        init(action: @escaping () -> Void) { self.action = action }

        deinit { stopWatchingVoiceOver() }

        @objc func fire() { action() }

        /// 보이스오버가 켜지고 꺼지는 것을 따라 인식기를 껐다 켠다.
        /// 앱을 쓰는 도중에 켜는 사람이 있으므로 시작할 때 한 번 보고 끝내지 않는다.
        func startWatchingVoiceOver() {
            syncEnabled()
            guard voiceOverObserver == nil else { return }
            voiceOverObserver = NotificationCenter.default.addObserver(
                forName: UIAccessibility.voiceOverStatusDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.syncEnabled() }
            }
        }

        func stopWatchingVoiceOver() {
            if let voiceOverObserver {
                NotificationCenter.default.removeObserver(voiceOverObserver)
            }
            voiceOverObserver = nil
        }

        @MainActor
        private func syncEnabled() {
            attached?.1.isEnabled = TwoFingerTapAvailability.isAllowedNow
        }

        /// 스크롤·탭 인식기와 나란히 산다. 혼자 독점하면 목록이 굳는다.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        /// 마지막 빗장. `isEnabled` 를 갱신하기 전에 몸짓이 먼저 시작되더라도 여기서 막는다.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            MainActor.assumeIsolated { TwoFingerTapAvailability.isAllowedNow }
        }
    }

    /// 손가락을 통과시키는 빈 판. 자기는 아무것도 받지 않고, 붙을 자리만 알려 준다.
    final class PassthroughView: UIView {
        var onAttach: ((UIView) -> Void)?
        private var didAttach = false

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard !didAttach, window != nil, let host = enclosingScrollView() ?? superview else { return }
            didAttach = true
            onAttach?(host)
        }

        private func enclosingScrollView() -> UIScrollView? {
            var node = superview
            while let current = node {
                if let scroll = current as? UIScrollView { return scroll }
                node = current.superview
            }
            return nil
        }
    }
}
#endif

extension View {
    /// 두 손가락으로 톡 치면 부른다. iOS 밖에서는 아무 일도 하지 않는다.
    ///
    /// ⛔️ 보이스오버가 켜져 있으면 이 문은 열리지 않는다. 이유는
    ///    `TwoFingerTapAvailability` 참고. 꾹 누르기 판의 '여러 개 고르기'가 그 자리를 잇는다.
    @ViewBuilder
    func onTwoFingerTap(perform action: @escaping () -> Void) -> some View {
        #if os(iOS)
        overlay(TwoFingerTapCatcher(action: action).allowsHitTesting(false))
        #else
        self
        #endif
    }
}
