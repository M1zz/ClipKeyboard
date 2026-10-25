//
//  FoldComposePane.swift
//  ClipKeyboard
//
//  펼친 아이폰 듀오에서 **새 단축어를 결과 쪽 판에 연다.** 시트로 띄우지 않는다.
//
//  설정이 그렇듯(목록 | 자세히) 단축어 탭도 고르는 쪽 | 결과 쪽이다. 시트는 시스템이 창 위에 띄워
//  27.1 에서는 접힌 선 한가운데에 섰고, 자리를 옮기는 공개 API 가 듣지 않았다(2026-10 실측).
//  그래서 펼친 화면에서는 시트를 쓰지 않고 결과 쪽 판('방금 복사함' 자리)에 쓰는 화면을 세운다.
//  다 쓰면(V) 또는 닫으면 판은 다시 '방금 복사함' 으로 돌아간다.
//
//  ⚠️ 접혀 있으면(바깥 화면 · 보통 아이폰) 지금처럼 시트다.
//

import SwiftUI
import LeeoKit

/// 결과 쪽 판에 지금 쓰는 화면을 세울지. 목록이 열고, 단축어 탭이 그린다.
@MainActor
final class FoldComposeRouter: ObservableObject {
    static let shared = FoldComposeRouter()
    private init() {}

    struct Request: Equatable, Identifiable {
        let id = UUID()
        /// 넣을 분류. 비었으면 기본.
        let category: String
    }

    @Published private(set) var request: Request?

    func open(category: String) {
        request = Request(category: category)
        print("🔀 [FoldComposeRouter.open] 새 단축어를 결과 쪽 판에")
    }

    func close() {
        request = nil
    }
}

/// 결과 쪽 판의 새 단축어 화면.
struct FoldComposePane: View {
    let request: FoldComposeRouter.Request

    var body: some View {
        NavigationStack {
            MemoAdd(insertedCategory: request.category.isEmpty ? "텍스트" : request.category)
                .environment(\.foldPaneDismiss, FoldPaneDismiss { FoldComposeRouter.shared.close() })
                .toolbar {
                    // 시트처럼 끌어 내릴 수 없으니 닫는 단추를 둔다
                    ToolbarItem(placement: .topBarLeading) {
                        GlassCircleButton(AppSymbol.xmark, role: .secondary,
                                          label: NSLocalizedString("닫기", comment: "")) {
                            FoldComposeRouter.shared.close()
                        }
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
        }
        .id(request.id)
    }
}

// MARK: - 판에서 닫기

/// 판에 세운 화면이 "다 썼다" 를 알리는 길. 시트면 nil 이라 `dismiss()` 를 쓴다.
struct FoldPaneDismiss {
    let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    func callAsFunction() { action() }
}

private struct FoldPaneDismissKey: EnvironmentKey {
    static let defaultValue: FoldPaneDismiss? = nil
}

extension EnvironmentValues {
    var foldPaneDismiss: FoldPaneDismiss? {
        get { self[FoldPaneDismissKey.self] }
        set { self[FoldPaneDismissKey.self] = newValue }
    }
}
