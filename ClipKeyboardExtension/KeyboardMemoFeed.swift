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

    /// 앱 무대용 적재 - 저장소에서 읽어 정렬해 `clipMemos`에 넣는다.
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
        let ud = AppGroup.defaults
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

// MARK: - 키보드에서 바꾼 순서를 적는다

extension KeyboardMemoFeed {

    /// 키보드에서 끌어 바꾼 순서를 **앱과 같은 자리에** 적는다.
    ///
    /// 읽는 규칙(`sorted`)이 이 파일에 있으니 쓰는 규칙도 여기 둔다. 두 곳에 나눠 두면
    /// 한쪽만 고쳐져 "키보드에서 바꿨는데 앱에서는 그대로"가 된다.
    ///
    /// - Parameters:
    ///   - reordered: 사용자가 끌어 만든 새 순서(화면에 보이던 것들).
    ///   - full: 그 화면이 잘라 온 원본 전체(무료 한도로 잘린 뒤쪽까지 포함).
    /// - Returns: 뒤쪽까지 이어 붙인 전체 순서.
    ///
    /// ⚠️ `memos.data` 는 **건드리지 않는다.** 순서를 읽는 쪽(앱 `sortMemos`·키보드 `sorted`)이
    ///    둘 다 이 UserDefaults 키만 보므로 파일을 다시 쓸 이유가 없고, 익스텐션이 목록
    ///    파일을 통째로 덮으면 그 사이 앱이 한 편집이 지워질 수 있다.
    @discardableResult
    static func commitManualOrder(_ reordered: [Memo], within full: [Memo]) -> [Memo] {
        guard !reordered.isEmpty else { return full }

        // 화면에 없던 뒤쪽(무료 한도로 잘린 것들)은 제자리에 두고, 보이던 것들의 자리에만
        // 새 순서를 끼워 넣는다. (앱 `commitReorder` 와 같은 방식)
        let movedIds = Set(reordered.map(\.id))
        var next = reordered.makeIterator()
        var merged: [Memo] = []
        merged.reserveCapacity(full.count)
        for memo in full {
            if movedIds.contains(memo.id) {
                if let item = next.next() { merged.append(item) }
            } else {
                merged.append(memo)
            }
        }
        // 방어: full 에 없던 항목이 남으면 뒤에 붙인다(유실 방지).
        while let leftover = next.next() { merged.append(leftover) }

        let ud = AppGroup.defaults
        ud?.set(merged.map { $0.id.uuidString }, forKey: DefaultsKey.memoManualOrderV1)
        ud?.set(true, forKey: DefaultsKey.memoManualOrderActiveV1)
        // 앱은 이 표식을 보고 포그라운드 복귀 때 목록을 다시 읽는다
        // (`ClipKeyboardListViewModel.reloadIfChangedOutsideApp`). 파일은 안 바뀌었지만
        // 다시 읽어야 새 순서로 다시 정렬된다 - 앱을 깨우는 통로가 이것 하나다.
        ud?.set(Date().timeIntervalSince1970, forKey: DefaultsKey.memosExternalChangeAt)

        clipMemos = merged
        print("✅ [KeyboardMemoFeed.commitManualOrder] 순서 저장 \(reordered.count)개 / 전체 \(merged.count)개")
        return merged
    }
}
