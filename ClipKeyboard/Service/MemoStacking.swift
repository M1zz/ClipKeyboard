//
//  MemoStacking.swift
//  ClipKeyboard
//
//  단축어 카드를 끌어 다른 카드에 놓으면 스택이 된다.
//
//  왜 생겼나: 사용자 요청 "스택을 드래그 앤 드롭으로 쌓게하기. 만들고보니 여러개를 묶을때".
//  따로 만들어 둔 것을 스택으로 합치려면 값을 하나씩 옮겨 적어야 했다.
//

import Foundation

enum MemoStacking {

    /// 칸이 될 수 있는 단축어인가.
    ///
    /// ⚠️ 잠근 단축어는 값이 암호화돼 있어 잠기지 않은 스택에 섞을 수 없고, 이미지는 칸에 담을 곳이 없고,
    ///    템플릿의 {빈칸} 은 스택이 채워 주지 않아 글자 그대로 들어간다. 합쳐서 망가뜨리느니 막는다.
    static func canStack(_ memo: Memo) -> Bool {
        !memo.isSecure
            && !memo.isTemplate
            && memo.imageFileName == nil
            && memo.imageFileNames.isEmpty
            && memo.contentType == .text
    }

    /// `target` 뒤에 `dragged` 의 칸을 이어 붙인 단축어. 합칠 수 없으면 nil.
    ///
    /// 이름 없던 칸은 단축어 제목을 칸 이름으로 물려받는다. 무엇이었는지 스택 안에서도 알아보게.
    static func stacked(_ target: Memo, adding dragged: Memo, now: Date = Date()) -> Memo? {
        guard target.id != dragged.id, canStack(target), canStack(dragged) else { return nil }
        var result = target
        result.stackItems = items(of: target) + items(of: dragged)
        result.lastEdited = now
        return result
    }

    private static func items(of memo: Memo) -> [StackItem] {
        memo.isStack ? memo.stackItems : [StackItem(key: memo.title, value: memo.value)]
    }
}
