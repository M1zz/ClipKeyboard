//
//  MemoStackScreen.swift
//  ClipKeyboard
//
//  끌어서 스택 만들기 - 카드를 다른 카드 위에 놓으면 그 뒤에 묶인다(`MemoStacking`).
//
//  ⚠️ 목록 카드에 바로 드래그를 달지 않는다. 시스템 드래그가 먼저 집어 들어서, 꾹 눌러 여는
//     메뉴가 열리지 않았다(시뮬레이터로 확인). 순서 바꾸기처럼 들어와서 하는 화면으로 뺐다.
//

import SwiftUI
import UniformTypeIdentifiers
import LeeoKit

struct MemoStackScreen<Model: MemoStackModel>: View {

    @ObservedObject var viewModel: Model
    let style: MemoCardStyle
    let columnCount: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragging: Memo?
    @State private var targetedID: UUID?
    /// 놓아서 묶자고 묻는 중인 한 쌍. 끌어온 카드가 사라지므로 한 번 묻는다.
    @State private var proposal: Proposal?

    private struct Proposal {
        let dragged: Memo
        let target: Memo
    }

    /// 잠금 · 이미지 · 템플릿은 묶을 수 없으니 처음부터 세우지 않는다.
    private var memos: [Memo] {
        viewModel.scopedMemosForCurrentTab().filter(MemoStacking.canStack)
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(memos.count < 2
                     ? NSLocalizedString("묶을 수 있는 단축어가 두 개 이상 필요해요", comment: "Drag to stack screen: fewer than two snippets can be stacked")
                     : NSLocalizedString("카드를 다른 카드 위에 놓으면 그 뒤에 묶여요", comment: "Drag to stack screen hint"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(memos) { memo in
                        cell(memo)
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("끌어서 스택 만들기", comment: "Drag to stack screen title and menu row"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("완료", comment: "Done")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .solidNavBar(theme.bg)
            .confirmationDialog(
                dialogTitle,
                isPresented: Binding(get: { proposal != nil }, set: { if !$0 { proposal = nil } }),
                titleVisibility: .visible,
                presenting: proposal
            ) { proposal in
                Button(NSLocalizedString("묶기", comment: "Bulk import: enter combo bundling mode")) {
                    if viewModel.stackMemo(proposal.dragged.id, onto: proposal.target.id) {
                        HapticManager.shared.success()
                    }
                }
                Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {}
            } message: { _ in
                Text(NSLocalizedString("끌어온 카드는 스택의 다음 칸이 되고 목록에서 사라져요.", comment: "Dialog message: the dragged card becomes the next step of the stack and leaves the list"))
            }
        }
    }

    private var dialogTitle: String {
        guard let proposal else { return "" }
        return String(format: NSLocalizedString("'%1$@' 뒤에 '%2$@' 묶기", comment: "Dialog title after dropping a snippet card on another. %1$@ is the card it was dropped on, %2$@ the dragged card"),
                      proposal.target.title, proposal.dragged.title)
    }

    private func cell(_ memo: Memo) -> some View {
        style.surface(for: memo, lightweight: true)
            .opacity(dragging?.id == memo.id ? 0.3 : 1)
            // 올라간 카드는 테두리로 받는다는 것을 말한다.
            .overlay {
                RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
                    .strokeBorder(theme.accent, lineWidth: 3)
                    .opacity(targetedID == memo.id ? 1 : 0)
            }
            .scaleEffect(targetedID == memo.id && !reduceMotion ? 1.04 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: targetedID)
            .onDrag {
                dragging = memo
                HapticManager.shared.medium()
                // 글 내용을 싣지 않는다. 다른 앱에 놓아도 단축어가 새지 않게.
                return NSItemProvider(object: "" as NSString)
            }
            .onDrop(of: [.text], delegate: MemoStackDropDelegate(
                target: memo,
                dragging: $dragging,
                targetedID: $targetedID,
                onDrop: { dragged, target in
                    HapticManager.shared.medium()
                    proposal = Proposal(dragged: dragged, target: target)
                }
            ))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(memo.title)
    }
}
