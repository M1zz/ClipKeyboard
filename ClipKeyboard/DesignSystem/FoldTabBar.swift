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

    func body(content: Content) -> some View {
        if fold.isUnfolded {
            content
                .toolbarVisibility(.hidden, for: .tabBar)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: Self.barHeight)
                }
        } else {
            content
        }
    }
}
