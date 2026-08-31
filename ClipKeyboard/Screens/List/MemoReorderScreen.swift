//
//  MemoReorderScreen.swift
//  ClipKeyboard
//
//  순서 바꾸기 - 지금 카테고리 탭의 카드를 흔들리는 격자로 세우고 끌어서 자리를 바꾼다.
//
//  ⚠️ `ClipKeyboardList` 에서 꺼냈다. 흔들림과 드래그에만 쓰이는 상태(`draggingMemo` ·
//     `wiggle`)가 목록 화면의 스무 개 남짓한 상태 사이에 섞여 있어서, 이 화면을 고치려면
//     저 화면을 다 읽어야 했다. 이제 그 둘은 여기서만 산다.
//

import SwiftUI
import UniformTypeIdentifiers
import LeeoKit

struct MemoReorderScreen: View {

    @ObservedObject var viewModel: ClipKeyboardListViewModel

    /// 카드 얼굴 - 목록과 **같은 값**을 받아야 여기서만 다르게 보이지 않는다.
    let style: MemoCardStyle

    /// 격자 열 수. 아이폰 2열 / 아이패드·맥 4열(목록과 같은 기준).
    let columnCount: Int

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 지금 끌고 있는 카드.
    @State private var draggingMemo: Memo?
    /// 흔들림 스위치. `repeatForever` 는 값이 바뀔 때만 붙어서, 껐다 켜 다시 시작시킨다.
    @State private var wiggle: Bool = false

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(hintText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)

                // 현재 탭에 재정렬할 메모가 없으면 빈 그리드 대신 이유를 설명한다.
                // (카테고리 범위 재정렬이라 다른 탭의 메모는 여기 나오지 않는 게 정상)
                if viewModel.reorderList.isEmpty {
                    emptyState
                }

                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(Array(viewModel.reorderList.enumerated()), id: \.element.id) { _, memo in
                        cell(memo: memo)
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
                // 재배치 애니메이션은 dropEntered의 withAnimation이 담당(이중 적용 방지).
                // 셀 바깥(여백)에 드롭돼도 드래그 상태를 풀어 카드가 사라진 채 남지 않게 한다.
                .onDrop(of: [.text], delegate: ReorderResetDropDelegate(dragging: $draggingMemo))
            }
            .background(theme.bg.ignoresSafeArea())
            // 그리드 밖(스크롤 영역 아무 곳)에 드롭돼도 드래그 상태를 정리하는 최후 안전망.
            .onDrop(of: [.text], delegate: ReorderResetDropDelegate(dragging: $draggingMemo))
            .navigationTitle(NSLocalizedString("순서 바꾸기", comment: "Reorder mode title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("완료", comment: "Done")) {
                        HapticManager.shared.success()
                        viewModel.exitReorderMode()
                    }
                    .fontWeight(.semibold)
                }
            }
            .solidNavBar(theme.bg)
        }
        .onAppear {
            draggingMemo = nil
            if !reduceMotion { withAnimation { wiggle = true } }
        }
        .onDisappear {
            wiggle = false
            draggingMemo = nil
        }
        // 드래그 세션이 끝나면(정상 드롭·취소 모두) 흔들림을 다시 켠다.
        // repeatForever는 value 변경 시에만 붙으므로 wiggle을 토글해 재시작한다.
        .onChange(of: draggingMemo?.id) { _, newValue in
            if newValue != nil {
                wiggle = false
            } else if !reduceMotion {
                withAnimation { wiggle = true }
            }
        }
    }

    // MARK: - 조각들

    /// 재정렬 안내 문구 - 카테고리 범위 재정렬이면 어느 카테고리인지 함께 보여준다.
    private var hintText: String {
        if let scope = viewModel.reorderScopeName {
            return String(format: NSLocalizedString("'%@'의 카드를 끌어 순서를 바꾸세요", comment: "Reorder mode hint scoped to current category"), scope)
        }
        return NSLocalizedString("카드를 끌어 순서를 바꾸세요", comment: "Reorder mode hint")
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: AppSymbol.trayFull)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(NSLocalizedString("이 카테고리에는 순서를 바꿀 단축어가 없어요", comment: "Reorder empty state title"))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            Text(NSLocalizedString("다른 카테고리 탭에서 순서 바꾸기를 열어 보세요", comment: "Reorder empty state subtitle"))
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    /// 재정렬 그리드의 한 셀 - 흔들림 + onDrag/onDrop 라이브 재배치.
    private func cell(memo: Memo) -> some View {
        let isDragging = draggingMemo?.id == memo.id
        // 드래그 세션 동안엔 모든 카드의 흔들림을 멈춘다 - repeatForever 회전이 재배치
        // 스프링 애니메이션·스크롤과 매 프레임 경합해 버벅임의 주원인이었다.
        let dragActive = draggingMemo != nil
        // 흔들림 위상은 index가 아닌 id 기반 고정값 - 재배치로 index가 바뀔 때마다
        // 애니메이션이 리셋되어 깜빡이던 문제 방지.
        let phase = Double(abs(memo.id.hashValue) % 6) * 0.045
        return style.surface(for: memo, lightweight: true)
            // 드래그 중인 카드의 원위치는 완전히 숨기지 않고 흐릿하게만 - 드롭이 시스템에서
            // 취소돼 콜백이 안 와도 카드가 "사라진" 채 남지 않는다.
            .opacity(isDragging ? 0.3 : 1.0)
            .scaleEffect(isDragging ? 0.95 : 1.0)
            .overlay(alignment: .topLeading) {
                // 흔들기 모드 식별용 작은 그립 배지.
                Image(systemName: AppSymbol.arrowUpAndDownAndArrowLeftAndRight)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Circle().fill(Color.black.opacity(0.35)))
                    .padding(8)
                    .opacity(isDragging ? 0 : 1)
                    .accessibilityHidden(true)
            }
            .onDrag {
                draggingMemo = memo
                HapticManager.shared.medium()
                return NSItemProvider(object: memo.id.uuidString as NSString)
            } preview: {
                // 손가락을 따라오는 미리보기는 항상 또렷하게(원본 dim과 분리).
                style.surface(for: memo, lightweight: true)
                    .frame(width: previewWidth, height: style.cardHeight)
            }
            .onDrop(of: [.text], delegate: MemoReorderDropDelegate(
                item: memo,
                list: $viewModel.reorderList,
                dragging: $draggingMemo
            ))
            // 흔들림 - 드래그 세션 중엔 전체 정지, reduceMotion이면 항상 정지.
            .rotationEffect(.degrees((reduceMotion || dragActive) ? 0 : (wiggle ? 1.4 : -1.4)))
            .animation(
                (reduceMotion || dragActive)
                    ? nil
                    : .easeInOut(duration: 0.22).repeatForever(autoreverses: true).delay(phase),
                value: wiggle
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(memo.title)
            .accessibilityHint(NSLocalizedString("드래그하여 순서를 바꿉니다", comment: "Reorder cell a11y hint"))
    }

    /// 격자 한 칸 너비 - onDrag 미리보기 크기에 쓴다. (좌우 패딩 16+16 + 칸 간격 12)
    ///
    /// ⚠️ iOS 26에서 `UIScreen.main` 이 deprecated - 활성 씬의 **윈도우** 너비를 쓴다.
    ///    화면(screen)이 아니라 윈도우인 이유: 아이패드 분할뷰·스테이지 매니저·Mac Catalyst
    ///    에서는 앱이 화면 전체를 쓰지 않아 screen 기준이면 미리보기가 실제 카드보다 커진다.
    @MainActor
    private var previewWidth: CGFloat {
        #if os(iOS)
        let containerWidth = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows.first { $0.isKeyWindow }?
            .bounds.width
        // 실제 그리드와 같은 열 수로 나눠야 미리보기와 카드 크기가 일치한다.
        // (좌우 패딩 16+16 + 열 사이 간격 12×(n-1))
        let columns = CGFloat(columnCount)
        let spacing = 12 * (columns - 1)
        let usable = (containerWidth ?? 320) - 32 - spacing
        return max(100, usable / columns)
        #else
        return 160
        #endif
    }
}
