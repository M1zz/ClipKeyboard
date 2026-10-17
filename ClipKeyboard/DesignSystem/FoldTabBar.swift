//
//  FoldTabBar.swift
//  ClipKeyboard
//
//  아이폰 듀오를 폈을 때 시스템 탭바 대신 서는 탭 막대.
//
//  시스템 탭바는 **창 가운데**에 선다. 가로로 펴면 창 가운데가 곧 접힌 선이라, 막대가 선을
//  가로질러 두 쪽에 걸친다. 접힌 선 위에는 아무것도 두지 않으므로(`FoldLayout` 머리 주석)
//  펴면 시스템 탭바를 숨기고 이 막대를 **고르는 쪽 판 안**에 세운다.
//  가로면 왼쪽 판의 바닥 가운데, 세로면 아래 쪽 판의 바닥 가운데다.
//
//  칸 이름 · 아이콘 · 순서 · 누르는 동작은 시스템 탭바와 같다. 같은 바인딩을 쓴다.
//  ⚠️ 글자는 고른 칸에만 붙인다. 네 칸 모두 아이콘과 글자를 달면 독일어 같은 긴 말에서
//     고르는 쪽 폭(약 463pt)을 넘는다. 나머지 칸은 아이콘과 접근성 이름으로 읽힌다.
//

import SwiftUI
import UIKit
import LeeoKit   // HapticManager

struct FoldTabBar<Value: Hashable>: View {
    struct Item: Identifiable {
        let value: Value
        let title: String
        let symbol: String
        /// 막대 밖 동그라미로 따로 선다(시스템 탭바의 검색 칸과 같은 모양).
        var standsApart = false
        var id: Value { value }
    }

    let items: [Item]
    let selected: Value
    let select: (Value) -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(items.filter { !$0.standsApart }) { item in
                    button(item)
                }
            }
            .padding(4)
            .glassEffect(.regular.interactive(), in: Capsule())

            ForEach(items.filter(\.standsApart)) { item in
                button(item)
                    .padding(4)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
    }

    private func button(_ item: Item) -> some View {
        let isOn = item.value == selected
        return Button {
            HapticManager.shared.selection()
            select(item.value)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: item.symbol)
                    .font(.title3.weight(.semibold))
                if isOn && !item.standsApart {
                    Text(item.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(isOn ? Color.accentColor : Color.primary)
            .frame(minWidth: 44, minHeight: 44)
            .padding(.horizontal, isOn && !item.standsApart ? 12 : 4)
            .background {
                if isOn && !item.standsApart {
                    Capsule().fill(Color.accentColor.opacity(0.14))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - 탭 판에 자리 내기

extension View {
    /// 펼친 화면에서 이 탭의 시스템 탭바를 숨기고, 바닥에 `FoldTabBar` 가 설 자리를 비운다.
    /// 각 탭의 맨 바깥에 건다. 접혀 있으면 아무것도 하지 않는다.
    func foldTabBarRoom() -> some View {
        modifier(FoldTabBarRoomModifier())
    }
}

private struct FoldTabBarRoomModifier: ViewModifier {
    @Environment(\.foldLayout) private var fold

    /// 막대 높이(칸 44 + 위아래 4) + 바닥 여백 8.
    static var barHeight: CGFloat { 60 }

    /// ⚠️ 자리는 SwiftUI `safeAreaInset` 이 아니라 **UIKit 안전 영역**으로 낸다.
    ///    `safeAreaInset` 은 탭 안의 `NavigationStack` 안쪽까지 내려가지 않았다(실측: 목록 안쪽의
    ///    바닥 여백이 시스템 탭바 83 에서 홈 막대 20 으로 줄었다). 그래서 목록 · 사용 기록 · 설정 ·
    ///    검색의 갈래 점, 알림 띠, 스크롤 끝이 이 막대 밑에 깔렸다. 시스템 탭바가 자리를 내는 길과
    ///    같은 길(`additionalSafeAreaInsets`)이라야 어느 깊이에서든 똑같이 비켜 선다.
    /// ⚠️ 접고 펴도 같은 뷰로 둔다. `if` 로 가르면 펴는 순간 탭 안쪽이 새로 만들어진다.
    func body(content: Content) -> some View {
        content
            .toolbarVisibility(fold.isUnfolded ? .hidden : .automatic, for: .tabBar)
            .background {
                TabSafeAreaRoom(bottom: fold.isUnfolded ? Self.barHeight : 0)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
    }
}

/// 이 탭을 담은 화면(탭 막대 컨트롤러의 자식)의 바닥 안전 영역에 `bottom` 만큼 더한다.
private struct TabSafeAreaRoom: UIViewControllerRepresentable {
    let bottom: CGFloat

    func makeUIViewController(context: Context) -> Probe {
        Probe()
    }

    func updateUIViewController(_ probe: Probe, context: Context) {
        probe.bottom = bottom
        probe.apply()
    }

    final class Probe: UIViewController {
        var bottom: CGFloat = 0

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            apply()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            apply()
        }

        /// 탭 막대 컨트롤러 바로 밑의 화면. 탭 하나를 통째로 담은 그릇이다.
        private var tabRoot: UIViewController? {
            var vc: UIViewController? = parent
            while let current = vc {
                if current.parent is UITabBarController { return current }
                vc = current.parent
            }
            return nil
        }

        func apply() {
            guard let root = tabRoot, root.additionalSafeAreaInsets.bottom != bottom else { return }
            root.additionalSafeAreaInsets.bottom = bottom
            print("📐 [TabSafeAreaRoom.apply] 탭 바닥 자리 \(bottom)pt")
        }
    }
}
