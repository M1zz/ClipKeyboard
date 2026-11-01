//
//  MemoReorderDropDelegates.swift
//  ClipKeyboard
//
//  순서 바꾸기 드래그가 어디로 떨어지는가.
//  화면을 그리는 코드가 아니라 드롭 규칙이라, 목록 뷰와 붙어 있을 이유가 없다.
//

import SwiftUI
import LeeoKit   // HapticManager

/// 순서 바꾸기 그리드의 드롭 델리게이트 - 드래그가 다른 카드 위로 들어오면 그 자리로 즉시 이동.
/// `.onDrag`가 손가락을 따라오는 네이티브 미리보기를 제공하고, dropEntered에서 라이브 재배치한다.
struct MemoReorderDropDelegate: DropDelegate {
    let item: Memo
    @Binding var list: [Memo]
    @Binding var dragging: Memo?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging.id != item.id,
              let from = list.firstIndex(where: { $0.id == dragging.id }),
              let to = list.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            list.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
        HapticManager.shared.light()
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

/// 그리드 여백에 드롭됐을 때 드래그 상태만 정리하는 컨테이너용 델리게이트(재배치는 안 함).
struct ReorderResetDropDelegate: DropDelegate {
    @Binding var dragging: Memo?
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

/// 목록의 카드를 다른 카드 위에 놓으면 묶자고 묻는다(`MemoStacking`).
///
/// ⚠️ 끄는 것이 앱의 카드일 때만 받는다. 다른 앱에서 끌어온 글은 이 카드와 묶을 것이 아니다.
struct MemoStackDropDelegate: DropDelegate {
    let target: Memo
    @Binding var dragging: Memo?
    @Binding var targetedID: UUID?
    let onDrop: (_ dragged: Memo, _ target: Memo) -> Void

    private var isOwnCard: Bool {
        guard let dragging else { return false }
        return dragging.id != target.id
    }

    func validateDrop(info: DropInfo) -> Bool { isOwnCard }

    func dropEntered(info: DropInfo) {
        guard isOwnCard else { return }
        targetedID = target.id
        HapticManager.shared.light()
    }

    func dropExited(info: DropInfo) {
        if targetedID == target.id { targetedID = nil }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        isOwnCard ? DropProposal(operation: .copy) : DropProposal(operation: .forbidden)
    }

    func performDrop(info: DropInfo) -> Bool {
        targetedID = nil
        defer { dragging = nil }
        guard isOwnCard, let dragging else { return false }
        onDrop(dragging, target)
        return true
    }
}
