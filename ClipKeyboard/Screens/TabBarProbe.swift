//
//  TabBarProbe.swift
//  ClipKeyboard
//
//  **하단 탭바에서 첫 칸이 어디 있는지** 재는 자.
//
//  왜 필요한가: 튜토리얼이 "아래 탭을 한 번 더 누르면 같은 곳을 오갑니다"라고 말하는데,
//  정작 그 탭은 가만히 있었다. 글로 어디라고 적어 봐야 탭이 넷이면 어느 것인지 모른다.
//
//  ⚠️ 탭바는 **UIKit 이 그리고 SwiftUI 콘텐츠 위에 얹힌다.** 그래서 자리를 SwiftUI 안에서
//     알 길이 없고, 콘텐츠 쪽에 덧그리면 탭바 유리 뒤로 들어가 뭉개진다. 재는 것은 여기서
//     하고, 그리는 것은 `TabView` **바깥쪽 overlay** 가 맡는다(`MainTabView`).
//
//  ⚠️ 못 재면 **아무것도 안 그린다.** 엉뚱한 자리에 물결이 뜨면 없느니만 못하다.
//     시스템이 탭바를 다른 것으로 바꾸는 날에도 안내 글은 그대로 남는다.
//

import SwiftUI
import UIKit

enum TabBarProbe {

    /// 탭바 **첫 칸**의 자리(화면 좌표). 못 찾으면 nil.
    ///
    /// 첫 칸인 이유: 단축어 탭이 늘 맨 앞이다(`MainTabView.body`). 순서가 바뀌면
    /// 여기도 같이 고쳐야 한다.
    static func firstItemFrame() -> CGRect? {
        guard let window = keyWindow, let bar = findTabBar(in: window) else { return nil }

        let items = controls(in: bar)
            .filter { $0.frame.width >= 20 && $0.frame.height >= 20 }
            .map { $0.convert($0.bounds, to: nil) }
            .sorted { $0.minX < $1.minX }

        guard let first = items.first else { return nil }
        // 잰 값이 말이 되는지 한 번 본다 - 화면 안에 있고, 아래쪽이어야 한다.
        // 시스템이 탭바를 접어 두거나 다른 모양으로 바꾸면 여기서 걸러진다.
        let screen = window.bounds
        guard screen.contains(CGPoint(x: first.midX, y: first.midY)),
              first.midY > screen.height * 0.7 else { return nil }
        return first
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    private static func findTabBar(in view: UIView) -> UITabBar? {
        if let bar = view as? UITabBar { return bar }
        for sub in view.subviews {
            if let found = findTabBar(in: sub) { return found }
        }
        return nil
    }

    /// 누를 수 있는 칸들. 탭바 속살은 버전마다 다르게 감싸여 있어 **깊이로 찾는다.**
    private static func controls(in view: UIView) -> [UIView] {
        var found: [UIView] = []
        for sub in view.subviews {
            if sub is UIControl {
                found.append(sub)
            } else {
                found.append(contentsOf: controls(in: sub))
            }
        }
        return found
    }
}
