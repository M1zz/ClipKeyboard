//
//  MemoBulkSelection.swift
//  ClipKeyboard
//
//  여러 개 고르기의 부품들 - 두 손가락 탭으로 들어가는 문과, 고른 뒤에 서는 아래 막대.
//
//  왜 생겼나: 사용자 피드백.
//
//    Would you consider adding bulk edit (especially bulk delete)?
//    ... a capacity to select multiple snippets (really cool would be to be able to
//    switch to select mode by means of 2 finger tap or something like that),
//    so that we can send multiple to a folder/category or delete them.
//
//  지금까지는 하나씩 꾹 눌러 지우는 길뿐이었다. 열 개를 지우려면 같은 동작을 열 번 한다.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - 두 손가락 탭

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
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var action: () -> Void
        var attached: (UIView, UIGestureRecognizer)?

        init(action: @escaping () -> Void) { self.action = action }

        @objc func fire() { action() }

        /// 스크롤·탭 인식기와 나란히 산다. 혼자 독점하면 목록이 굳는다.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
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
    /// ⚠️ 보이스오버가 켜져 있으면 두 손가락 탭은 시스템이 먼저 가져간다(읽기 멈춤).
    ///    그래서 이 길만 두지 않는다 - 꾹 누르기 판에도 같은 문이 있다.
    @ViewBuilder
    func onTwoFingerTap(perform action: @escaping () -> Void) -> some View {
        #if os(iOS)
        overlay(TwoFingerTapCatcher(action: action).allowsHitTesting(false))
        #else
        self
        #endif
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
