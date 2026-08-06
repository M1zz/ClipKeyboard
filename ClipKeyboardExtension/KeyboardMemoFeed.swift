//
//  KeyboardMemoFeed.swift
//  ClipKeyboard / ClipKeyboardExtension
//
//  키보드가 보여 줄 문구 목록. **익스텐션과 앱 무대가 같은 배열을 본다.**
//
//  `clipMemos`는 원래 `KeyboardViewController`에 있던 전역이었다. 앱 안에서도 같은
//  `KeyboardView`를 띄우게 되면서, 컨트롤러가 없는 쪽(앱)에서는 이 배열을 채울 사람이
//  없어졌다. 그래서 배열과 정렬 규칙만 두 타깃이 공유하는 이 파일로 내렸다.
//
//  ⚠️ 정렬 규칙은 여기 한 곳에만 있어야 한다. 앱 목록·키보드·무대가 서로 다른 순서로
//     같은 문구를 보여주면 "왜 여기선 순서가 다르지"가 된다.
//

import Foundation

/// 키보드에 실린 문구 전체(필터·정렬 적용 후).
/// 익스텐션에서는 `KeyboardViewController.populateKeyboardData`가, 앱에서는
/// `KeyboardMemoFeed.reload()`가 채운다.
var clipMemos: [Memo] = []

enum KeyboardMemoFeed {

    /// 앱 무대용 적재 — 저장소에서 읽어 정렬해 `clipMemos`에 넣는다.
    ///
    /// 익스텐션의 사용자 필터(테마/템플릿/즐겨찾기 전용 보기)는 적용하지 않는다.
    /// 그건 키보드 화면 안에서 카테고리 탭으로 다시 고르게 되어 있고,
    /// 앱에서는 전부 보이는 편이 맞다.
    @discardableResult
    static func reload() -> Int {
        do {
            clipMemos = sorted(try MemoStore.shared.load(type: .memo))
        } catch {
            print("❌ [KeyboardMemoFeed.reload] 문구 로드 실패: \(error.localizedDescription)")
            clipMemos = []
        }
        return clipMemos.count
    }

    /// 앱 '순서 바꾸기'로 지정한 수동 순서가 있으면 그 순서, 없으면 즐겨찾기 먼저 → 최근 수정순.
    /// (`ClipKeyboardListViewModel.sortMemos`와 같은 규칙)
    static func sorted(_ memos: [Memo]) -> [Memo] {
        let ud = UserDefaults(suiteName: AppGroup.identifier)
        if ud?.bool(forKey: DefaultsKey.memoManualOrderActiveV1) == true {
            let ids = ud?.stringArray(forKey: DefaultsKey.memoManualOrderV1) ?? []
            let order = ids.compactMap { UUID(uuidString: $0) }
            let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            return memos.sorted { a, b in
                switch (rank[a.id], rank[b.id]) {
                case let (ra?, rb?): return ra < rb
                case (nil, _?):      return true
                case (_?, nil):      return false
                case (nil, nil):     return a.lastEdited > b.lastEdited
                }
            }
        }
        return memos.sorted { a, b in
            a.isFavorite == b.isFavorite ? a.lastEdited > b.lastEdited : a.isFavorite
        }
    }
}
