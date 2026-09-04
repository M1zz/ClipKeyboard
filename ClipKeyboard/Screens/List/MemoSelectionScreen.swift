//
//  MemoSelectionScreen.swift
//  ClipKeyboard
//
//  여러 개 고르기 - 지금 카테고리 탭의 카드를 체크로 골라 한꺼번에 옮기거나 지운다.
//
//  순서 바꾸기와 같은 꼴(전체 화면 + 같은 범위)이다. 목록 위에 그대로 얹지 않는 이유는
//  그 화면이 이미 카테고리 페이저·배너·팁을 이고 있어서, 고르기 크롬까지 얹으면
//  무엇을 누르는 자리인지가 흐려지기 때문이다.
//
//  ⚠️ 확인 창 둘(삭제 확인·새 카테고리)은 **이 화면 안에** 산다. 목록 화면에 두면
//     전체 화면 덮개에 가려 아예 뜨지 않는다.
//

import SwiftUI
import LeeoKit

struct MemoSelectionScreen<Model: MemoSelectionModel>: View {

    /// 저장소는 `MemoSelectionModel` 이 약속한 만큼만 보인다(MemoScreenContracts.swift).
    @ObservedObject var viewModel: Model

    /// 카드 얼굴 - 목록과 **같은 값**을 받아야 여기서만 다르게 보이지 않는다.
    let style: MemoCardStyle

    /// 격자 열 수. 아이폰 2열 / 아이패드·맥 4열(목록과 같은 기준).
    let columnCount: Int

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showBulkDeleteConfirm: Bool = false
    @State private var showBulkNewCategoryAlert: Bool = false
    @State private var newCategoryForSelection: String = ""

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount)
    }

    var body: some View {
        selectionModeView
    }

    /// 어느 범위에서 고르는 중인지. 카테고리 기능이 꺼져 있으면 nil(전체에서 고른다).
    private var selectionScopeName: String? {
        CategoryStore.shared.isFeatureEnabled ? viewModel.selectedCategoryTab.displayName : nil
    }

    /// 화면 제목 아래에 서는 한 줄 - 몇 개 골랐는지, 아직 하나도 안 골랐으면 무엇을 하라는지.
    private var selectionHintText: String {
        if viewModel.selectedCount > 0 {
            return String(format: NSLocalizedString("%d개 선택됨", comment: "Selection mode: selected count"),
                          viewModel.selectedCount)
        }
        if let scope = selectionScopeName {
            return String(format: NSLocalizedString("'%@'에서 옮기거나 지울 카드를 고르세요", comment: "Selection mode hint scoped to current category"), scope)
        }
        return NSLocalizedString("옮기거나 지울 카드를 고르세요", comment: "Selection mode hint")
    }

    /// 고른 것 중에 이미 카테고리에 들어 있는 것이 있는가 - "카테고리에서 빼기"를 보일지 정한다.
    private var anySelectedHasCategory: Bool {
        guard CategoryStore.shared.isFeatureEnabled else { return false }
        return viewModel.selectedMemos.contains { viewModel.customCategories.contains($0.category) }
    }

    /// 여러 개 고르기 전용 화면 - 현재 카테고리 탭의 카드를 체크박스와 함께 보여주고,
    /// 고른 것을 한꺼번에 카테고리로 보내거나 지운다.
    ///
    /// 순서 바꾸기와 같은 꼴(전체 화면 + 같은 범위)이다. 목록 위에 그대로 얹지 않는 이유는
    /// 그 화면이 이미 카테고리 페이저·배너·팁을 이고 있어서, 고르기 크롬까지 얹으면
    /// 무엇을 누르는 자리인지가 흐려지기 때문이다.
    private var selectionModeView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                selectionGrid
                BulkSelectionBar(
                    selectedCount: viewModel.selectedCount,
                    categories: viewModel.customCategories,
                    anySelectedHasCategory: anySelectedHasCategory,
                    onMove: { category in performBulkMove(to: category) },
                    onCreateNewCategory: {
                        newCategoryForSelection = ""
                        showBulkNewCategoryAlert = true
                    },
                    onRemoveFromCategory: { performBulkMove(to: "기본") },
                    onDelete: {
                        HapticManager.shared.warning()
                        showBulkDeleteConfirm = true
                    }
                )
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("여러 개 고르기", comment: "Selection mode title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("취소", comment: "Cancel")) {
                        HapticManager.shared.light()
                        viewModel.exitSelectionMode()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isAllSelectedInScope
                           ? NSLocalizedString("전체 해제", comment: "Selection mode: deselect all")
                           : NSLocalizedString("전체 선택", comment: "Selection mode: select all")) {
                        HapticManager.shared.selection()
                        if viewModel.isAllSelectedInScope {
                            viewModel.deselectAll()
                        } else {
                            viewModel.selectAllInScope()
                        }
                    }
                    .disabled(viewModel.selectionList.isEmpty)
                }
            }
            .solidNavBar(theme.bg)
            .alert(
                NSLocalizedString("고른 단축어 삭제", comment: "Bulk delete alert title"),
                isPresented: $showBulkDeleteConfirm
            ) {
                Button(NSLocalizedString("삭제", comment: "Confirm delete"), role: .destructive) {
                    performBulkDelete()
                }
                Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(format: NSLocalizedString("%d개를 삭제하시겠습니까? 이 작업은 취소할 수 없습니다.", comment: "Bulk delete confirm message"), viewModel.selectedCount))
            }
            .alert(
                NSLocalizedString("새 카테고리 만들기", comment: "Create new category and assign alert title"),
                isPresented: $showBulkNewCategoryAlert
            ) {
                TextField(NSLocalizedString("카테고리 이름", comment: "Category name placeholder"), text: $newCategoryForSelection)
                Button(NSLocalizedString("추가", comment: "Add")) {
                    let trimmed = newCategoryForSelection.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        viewModel.addCustomCategory(trimmed)
                        performBulkMove(to: trimmed)
                    }
                    newCategoryForSelection = ""
                }
                Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {
                    newCategoryForSelection = ""
                }
            } message: {
                Text(NSLocalizedString("카테고리가 생성되고 고른 단축어가 모두 이동됩니다.", comment: "Bulk create category and move message"))
            }
        }
    }

    private var selectionGrid: some View {
        ScrollView {
            Text(selectionHintText)
                .font(.footnote)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 12)
                // 개수가 바뀔 때 글자가 통째로 갈리지 않고 숫자만 굴러가게.
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.selectedCount)

            // 이 탭에 고를 것이 없으면 빈 격자 대신 이유를 말한다
            // (범위가 현재 탭이라 다른 탭의 카드가 여기 없는 것이 정상이다).
            if viewModel.selectionList.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: AppSymbol.trayFull)
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("이 카테고리에는 고를 단축어가 없어요", comment: "Selection mode empty state title"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("다른 카테고리 탭에서 다시 열어 보세요", comment: "Selection mode empty state subtitle"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            }

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(viewModel.selectionList) { memo in
                    selectionCardCell(memo: memo)
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
    }

    /// 고르기 격자의 한 칸 - 목록과 같은 카드에 체크만 얹는다.
    /// 여기서는 탭이 **복사가 아니라 고르기**다(복사하려고 열지 않았다).
    private func selectionCardCell(memo: Memo) -> some View {
        let isSelected = viewModel.selectedMemoIDs.contains(memo.id)
        return style.surface(for: memo, lightweight: true)
            .overlay {
                RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
                    .strokeBorder(theme.accent, lineWidth: 3)
                    .opacity(isSelected ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                SelectionCheckmark(isSelected: isSelected)
            }
            // 고른 카드는 아주 살짝 들어간다 - 체크 하나로는 격자 전체에서 잘 안 읽힌다.
            .scaleEffect(isSelected ? 0.97 : 1.0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isSelected)
            .contentShape(RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous))
            .onTapGesture {
                HapticManager.shared.selection()
                viewModel.toggleSelection(memo.id)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityLabel(memo.title)
            .accessibilityHint(isSelected
                               ? NSLocalizedString("탭하면 선택을 해제합니다", comment: "VoiceOver: deselect hint")
                               : NSLocalizedString("탭하면 선택합니다", comment: "VoiceOver: select hint"))
    }

    /// 고른 것을 한꺼번에 옮기고, 화면을 닫은 뒤 결과를 한 줄로 알린다.
    /// 옮기면 그 카드는 지금 탭에서 사라질 수 있으므로 화면을 계속 붙잡아 두지 않는다.
    private func performBulkMove(to category: String) {
        let moved = viewModel.moveSelectedMemos(toCategory: category)
        guard moved > 0 else { return }
        HapticManager.shared.success()
        viewModel.exitSelectionMode()
        viewModel.showPlainToast(
            String(format: NSLocalizedString("%1$d개를 '%2$@'(으)로 옮겼어요", comment: "Bulk move done toast"),
                   moved, category)
        )
    }

    private func performBulkDelete() {
        let removed = viewModel.deleteSelectedMemos()
        guard removed > 0 else { return }
        HapticManager.shared.success()
        viewModel.exitSelectionMode()
        viewModel.showPlainToast(
            String(format: NSLocalizedString("%d개를 삭제했어요", comment: "Bulk delete done toast"), removed)
        )
    }

}

// MARK: - 고른 것 위에 얹는 표식

/// 고른 카드에 얹히는 동그란 체크. 안 고른 카드에는 빈 테두리만 둔다
/// (빈 자리를 비워 두면 고를 수 있다는 것 자체가 안 보인다).
struct SelectionCheckmark: View {
    let isSelected: Bool
    @Environment(\.appTheme) private var theme

    var body: some View {
        Image(systemName: isSelected ? AppSymbol.checkmarkCircleFill : AppSymbol.circle)
            .font(.title2)
            .symbolRenderingMode(isSelected ? .palette : .monochrome)
            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.9),
                             isSelected ? theme.accent : Color.clear)
            .background(
                Circle()
                    .fill(isSelected ? Color.white : Color.black.opacity(0.28))
                    .padding(2)
            )
            .padding(10)
            .accessibilityHidden(true)
    }
}

// MARK: - 아래 막대

/// 여러 개 고르기 화면 바닥에 서는 막대 - 카테고리로 보내기와 삭제.
///
/// 아무것도 안 골랐을 때도 자리를 지킨다. 골랐을 때만 나타나면 막대가 나타나느라
/// 그리드가 한 번 튀어 오른다.
struct BulkSelectionBar: View {
    let selectedCount: Int
    /// 보낼 수 있는 카테고리 목록.
    let categories: [String]
    /// 고른 것들이 이미 어느 카테고리에 들어 있는가 - "카테고리에서 빼기"를 보일지 정한다.
    let anySelectedHasCategory: Bool
    let onMove: (String) -> Void
    let onCreateNewCategory: () -> Void
    let onRemoveFromCategory: () -> Void
    let onDelete: () -> Void

    @Environment(\.appTheme) private var theme

    private var isEmpty: Bool { selectedCount == 0 }

    var body: some View {
        HStack(spacing: 12) {
            moveMenu
            deleteButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private var moveMenu: some View {
        Menu {
            ForEach(categories, id: \.self) { category in
                Button {
                    onMove(category)
                } label: {
                    Label(category, systemImage: categorySymbol(for: category, in: categories))
                }
            }
            Divider()
            Button {
                onCreateNewCategory()
            } label: {
                Label(NSLocalizedString("새 카테고리에 추가", comment: "Create new category and assign memo"),
                      systemImage: AppSymbol.folderBadgePlus)
            }
            if anySelectedHasCategory {
                Divider()
                Button {
                    onRemoveFromCategory()
                } label: {
                    Label(NSLocalizedString("카테고리에서 빼기", comment: "Action: remove memo from its category"),
                          systemImage: AppSymbol.tray)
                }
            }
        } label: {
            barLabel(text: NSLocalizedString("카테고리로 옮기기", comment: "Bulk action: move selected to a category"),
                     systemImage: AppSymbol.folder,
                     tint: theme.accent)
        }
        .disabled(isEmpty)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            onDelete()
        } label: {
            barLabel(text: NSLocalizedString("삭제", comment: "Action: delete"),
                     systemImage: AppSymbol.trash,
                     tint: .red)
        }
        .disabled(isEmpty)
    }

    private func barLabel(text: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
            Text(text)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(isEmpty ? theme.textFaint : tint)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                .fill((isEmpty ? theme.textFaint : tint).opacity(0.12))
        )
        .contentShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
    }
}
