//
//  MemoScreenContracts.swift
//  ClipKeyboard
//
//  순서 바꾸기·여러 개 고르기 화면이 **저장소에 요구하는 것의 전부.**
//
//  ⚠️ 두 화면은 원래 `ClipKeyboardListViewModel` 을 통째로 들고 있었다. 1,600줄짜리
//     저장소의 아무 곳이나 만질 수 있었다는 뜻이고, 그러면 화면 하나를 이해하려고
//     저장소 전체를 읽어야 한다. 반대로 저장소를 고칠 때 어느 화면이 깨질지도 알 수 없다.
//
//     여기 적힌 것이 두 화면이 아는 전부다. 이 목록에 없는 것은 화면이 만질 수 없고,
//     이 목록만 지키면 저장소 안쪽은 마음대로 바꿔도 된다.
//

import SwiftUI

/// 순서 바꾸기 화면이 저장소에 바라는 것. 셋뿐이다.
@MainActor
protocol MemoReorderModel: ObservableObject {
    /// 드래그로 실시간 바뀌는 작업용 목록. 화면이 직접 뒤집으므로 쓰기까지 연다.
    var reorderList: [Memo] { get set }
    /// 어느 카테고리를 재정렬 중인지. nil 이면 전체.
    var reorderScopeName: String? { get }
    /// 지금 순서를 갈무리하고 화면을 닫는다.
    func exitReorderMode()
}

/// 여러 개 고르기 화면이 저장소에 바라는 것.
@MainActor
protocol MemoSelectionModel: ObservableObject {
    /// 고를 수 있는 범위(지금 탭). 지우는 동안 발밑이 바뀌지 않도록 찍어 둔 판이다.
    var selectionList: [Memo] { get }
    var selectedMemoIDs: Set<UUID> { get }
    var selectedCount: Int { get }
    var selectedMemos: [Memo] { get }
    var isAllSelectedInScope: Bool { get }

    /// 보낼 수 있는 카테고리 목록과, 지금 어느 탭에서 고르는 중인지.
    var customCategories: [String] { get }
    var selectedCategoryTab: CategoryTab { get }

    func toggleSelection(_ id: UUID)
    func selectAllInScope()
    func deselectAll()
    func exitSelectionMode()

    /// - Returns: 실제로 옮기거나 지운 개수. 실패하면 0.
    @discardableResult func moveSelectedMemos(toCategory category: String) -> Int
    @discardableResult func deleteSelectedMemos() -> Int

    func addCustomCategory(_ name: String)
    /// 결과 한 줄. 화면을 닫은 뒤 목록 위에 뜬다.
    func showPlainToast(_ message: String)
}

// ClipKeyboardListViewModel 이 이미 이 모양을 갖추고 있다. 여기서는 약속만 맺는다.
extension ClipKeyboardListViewModel: MemoReorderModel, MemoSelectionModel {}
