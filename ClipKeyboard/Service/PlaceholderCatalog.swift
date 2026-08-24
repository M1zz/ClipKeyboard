//
//  PlaceholderCatalog.swift
//  ClipKeyboard
//
//  **빈칸은 템플릿의 소유물이 아니다.** 이름 하나가 곧 하나의 빈칸이고, 값도 이름으로 묶인다.
//
//  값이 어디에 저장되는지 보면 분명하다: `placeholder_values_{이름}`. 템플릿 id 가 끼어 있지
//  않다. 그래서 새해인사의 `{이름}` 과 안부의 `{이름}` 은 처음부터 **같은 빈칸**이고 값을 함께
//  쓴다. 그런데 화면은 오랫동안 템플릿부터 고르게 해서, 그 사실이 어디에도 드러나지 않았다.
//  사용자는 템플릿마다 빈칸을 새로 만드는 줄 알고 이름을 조금씩 다르게 적었고
//  (`{회사명}` · `{회사 이름}`), 이름이 갈라지는 순간 값도 갈라졌다.
//
//  이 파일은 그 사실을 화면이 쓸 수 있는 모양으로 모아 준다.
//
//  ⚠️ 단축어에서 사라진 빈칸도 값이 남아 있으면 함께 센다. 템플릿을 지웠거나 이름을 바꾼 뒤
//     남겨진 값은 어디에도 안 보이면 지울 수도 없다. 보여야 정리할 수 있다.
//
//  ⚠️ 자동 변수(`{날짜}` · `{클립보드}` 같은 것)는 빈칸이 아니다. 채울 것이 없으므로 세지 않는다
//     (`TemplatePlaceholder.customTokens` 가 이미 걸러 준다).
//

import Foundation

/// 빈칸 하나와, 그 빈칸을 둘러싼 것들.
struct PlaceholderSummary: Identifiable, Equatable {
    /// 중괄호를 포함한 이름. 예: `{이름}`
    let token: String
    /// 저장해 둔 값의 개수.
    let valueCount: Int
    /// 이 빈칸을 쓰는 단축어들.
    let memos: [Reference]

    var id: String { token }

    /// 화면에 보일 이름(중괄호 없이).
    var displayName: String { token.strippingTemplateBraces }

    /// 금액·수량처럼 숫자를 넣는 자리인가. 이런 빈칸은 값을 저장하지 않는다.
    var isNumeric: Bool { TemplateVariableProcessor.isNumericToken(token) }

    /// 지금 어느 단축어에서도 쓰이지 않는가. 값만 남은 빈칸이다.
    var isOrphan: Bool { memos.isEmpty }

    struct Reference: Equatable, Identifiable {
        let id: UUID
        let title: String
    }
}

enum PlaceholderCatalog {

    /// 지금 이 사람이 가진 빈칸 전부.
    ///
    /// - Parameter memos: 훑을 단축어들. 템플릿만이 아니라 **전부** 넘긴다 -
    ///   템플릿으로 표시하지 않은 단축어에도 `{ }` 는 들어갈 수 있고, 그것도 채워야 하는 칸이다.
    /// - Returns: 쓰임이 많은 것 → 값이 많은 것 → 이름 순.
    static func summaries(from memos: [Memo]) -> [PlaceholderSummary] {
        var references: [String: [PlaceholderSummary.Reference]] = [:]

        for memo in memos {
            for token in TemplatePlaceholder.customTokens(in: memo.value) {
                references[token, default: []].append(
                    PlaceholderSummary.Reference(id: memo.id, title: memo.title)
                )
            }
        }

        // 값만 남은 빈칸도 목록에 세운다.
        var tokens = Set(references.keys)
        tokens.formUnion(MemoStore.shared.storedPlaceholderTokens())

        let summaries = tokens.map { token in
            PlaceholderSummary(
                token: token,
                valueCount: MemoStore.shared.loadPlaceholderValues(for: token).count,
                memos: references[token] ?? []
            )
        }

        return summaries.sorted { lhs, rhs in
            if lhs.memos.count != rhs.memos.count { return lhs.memos.count > rhs.memos.count }
            if lhs.valueCount != rhs.valueCount { return lhs.valueCount > rhs.valueCount }
            return lhs.displayName < rhs.displayName
        }
    }

    /// 새 단축어를 만들 때 **집어 넣을 만한** 빈칸.
    ///
    /// 쓰임이 없고 값도 없는 이름은 뺀다. 한 번 잘못 친 오타가 목록에 영영 남으면
    /// 고르라고 내민 것이 오히려 헷갈리게 한다.
    ///
    /// - Parameter limit: 칩으로 늘어놓을 최대 개수. 가로로 스크롤되지만 끝이 있어야 한다.
    static func insertable(from memos: [Memo], limit: Int = 12) -> [PlaceholderSummary] {
        summaries(from: memos)
            .filter { !$0.memos.isEmpty || $0.valueCount > 0 }
            .prefix(limit)
            .map { $0 }
    }
}
