//
//  AppIntent.swift
//  widget
//
//  Created by hyunho lee on 2/1/26.
//

import WidgetKit
import AppIntents

// MARK: - Memo Entity (위젯 설정에서 메모 선택용)

struct MemoEntity: AppEntity {
    var id: String
    var title: String
    var value: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource("설정해주세요", comment: "Memo entity placeholder")
        )
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(String(value.prefix(30)))"
        )
    }

    static var defaultQuery = MemoEntityQuery()
}

// MARK: - Memo Entity Query

struct MemoEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [MemoEntity] {
        let memos = SharedMemoLoader.loadFavoriteMemos()
        return identifiers.compactMap { id in
            guard let memo = memos.first(where: { $0.id.uuidString == id }) else { return nil }
            return MemoEntity(id: memo.id.uuidString, title: memo.title, value: memo.value)
        }
    }

    func suggestedEntities() async throws -> [MemoEntity] {
        let memos = SharedMemoLoader.loadFavoriteMemos()
        return memos.map { MemoEntity(id: $0.id.uuidString, title: $0.title, value: $0.value) }
    }

    func defaultResult() async -> MemoEntity? {
        let favorites = SharedMemoLoader.loadFavoriteMemos()
        // 즐겨찾기가 1개면 자동 선택
        guard let first = favorites.first else { return nil }
        return MemoEntity(id: first.id.uuidString, title: first.title, value: first.value)
    }
}

// MARK: - Memo Options Provider

struct MemoOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [MemoEntity] {
        let memos = SharedMemoLoader.loadFavoriteMemos()
        return memos.map { MemoEntity(id: $0.id.uuidString, title: $0.title, value: $0.value) }
    }

    func defaultResult() async -> MemoEntity? {
        let favorites = SharedMemoLoader.loadFavoriteMemos()
        guard let first = favorites.first else { return nil }
        return MemoEntity(id: first.id.uuidString, title: first.title, value: first.value)
    }
}

// MARK: - Select Memo Intent (위젯 설정용)

struct SelectMemoIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource {
        LocalizedStringResource("즐겨찾기 메모 선택", comment: "Select favorite memo intent")
    }

    static var description: IntentDescription {
        IntentDescription(
            LocalizedStringResource("위젯에 표시할 즐겨찾기 메모를 선택합니다", comment: "Select memo intent description")
        )
    }

    @Parameter(
        title: LocalizedStringResource("복사 될 값", comment: "Value to copy parameter"),
        optionsProvider: MemoOptionsProvider()
    )
    var memo: MemoEntity?
}

