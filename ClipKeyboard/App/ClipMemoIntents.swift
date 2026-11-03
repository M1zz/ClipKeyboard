//
//  ClipMemoIntents.swift
//  ClipKeyboard
//
//  단축어 하나하나를 Siri · Spotlight · 단축어 앱이 알아보게 한다.
//
//  "Siri야, 클립키보드에서 계좌번호 복사해줘". 앱을 열지 않고 그 값이 클립보드에 들어간다.
//  Spotlight 에서 이름을 쳐도 나오고, 누르면 앱이 열리며 복사된다(위젯을 누른 것과 같다).
//
//  ⚠️ 싣는 것은 **보통 단축어뿐**이다. 보안 단축어는 음성 명령이나 검색 결과로 새면 안 되고,
//     템플릿 · 스택은 값을 그대로 붙여 봐야 쓸 수 없다(빈칸을 채우거나 차례로 넣어야 한다).
//  ⚠️ 색인에는 **이름과 카테고리만** 넣는다. 값(계좌번호 같은 것)은 Spotlight 에 올리지 않는다.
//  ⚠️ 복사는 잠금 해제를 요구한다. 잠긴 폰에 대고 말해서 값을 꺼내는 일이 없어야 한다.
//

import AppIntents
import CoreSpotlight
import Foundation
#if os(iOS)
import UIKit
#endif

// MARK: - 단축어

struct ClipMemoEntity: IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("단축어", comment: "Siri/Spotlight: the kind of item ClipKeyboard stores (a saved snippet)")
    )
    static let defaultQuery = ClipMemoQuery()

    let id: UUID
    let title: String
    let category: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(category)")
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let set = defaultAttributeSet
        set.keywords = [category]
        return set
    }

    init(_ memo: Memo) {
        id = memo.id
        title = memo.title
        category = memo.category
    }

    /// Siri 에 실어도 되는 단축어인가 (머리말).
    static func isOffered(_ memo: Memo) -> Bool {
        !memo.isSecure && !memo.isTemplate && memo.stackItems.isEmpty && !memo.value.isEmpty
            && !memo.title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    static func offeredMemos() -> [Memo] {
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        return memos.filter(isOffered)
    }

    /// Spotlight 색인을 지금 단축어 목록에 맞춘다. 지운 것이 남지 않게 통째로 다시 싣는다.
    static func reindex() async {
        let entities = offeredMemos().map(ClipMemoEntity.init)
        let index = CSSearchableIndex.default()
        try? await index.deleteAppEntities(ofType: ClipMemoEntity.self)
        try? await index.indexAppEntities(entities)
        // "○○ 복사해줘" 의 ○○ 자리에 들어갈 이름이 바뀌었다고 Siri 에 알린다.
        ClipKeyboardAppShortcuts.updateAppShortcutParameters()
    }
}

struct ClipMemoQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [ClipMemoEntity] {
        let wanted = Set(identifiers)
        return ClipMemoEntity.offeredMemos().filter { wanted.contains($0.id) }.map(ClipMemoEntity.init)
    }

    func entities(matching string: String) async throws -> [ClipMemoEntity] {
        let query = string.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return try await suggestedEntities() }
        return ClipMemoEntity.offeredMemos()
            .filter { $0.title.localizedCaseInsensitiveContains(query) || $0.category.localizedCaseInsensitiveContains(query) }
            .map(ClipMemoEntity.init)
    }

    /// 즐겨찾기 먼저, 그다음 많이 쓴 순서.
    func suggestedEntities() async throws -> [ClipMemoEntity] {
        ClipMemoEntity.offeredMemos()
            .sorted { ($0.isFavorite ? 1 : 0, $0.clipCount) > ($1.isFavorite ? 1 : 0, $1.clipCount) }
            .prefix(30)
            .map(ClipMemoEntity.init)
    }
}

// MARK: - 복사

/// 단축어 값을 클립보드에 넣는다. 앱을 띄우지 않는다.
struct CopyClipMemoIntent: AppIntent {
    static let title = LocalizedStringResource("단축어 복사", comment: "Siri: copy a saved snippet's value")
    static let description = IntentDescription(
        LocalizedStringResource("저장한 단축어의 값을 클립보드에 복사합니다.", comment: "Siri: copy snippet description")
    )
    static let openAppWhenRun = false
    static let authenticationPolicy = IntentAuthenticationPolicy.requiresAuthentication

    @Parameter(title: LocalizedStringResource("단축어", comment: "Siri: snippet parameter"),
               requestValueDialog: IntentDialog(LocalizedStringResource("어떤 단축어를 복사할까요?", comment: "Siri: ask which snippet")))
    var memo: ClipMemoEntity

    init() {}
    init(memo: ClipMemoEntity) { self.memo = memo }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let copied = ClipMemoCopier.copy(memo.id) else {
            return .result(dialog: IntentDialog(LocalizedStringResource("그 단축어를 찾지 못했어요.", comment: "Siri: snippet not found")))
        }
        // 화면 없이 깨어난 실행이면 여기서 닫는다 (`AddQuickNoteIntent` 와 같은 이유).
        await MainActor.run { LaunchGuard.closeIfBackgroundLaunch("copy-clip-memo-intent") }
        return .result(dialog: IntentDialog(LocalizedStringResource("‘\(copied)’을 복사했어요.", comment: "Siri: snippet copied. Argument is the snippet name")))
    }
}

/// Spotlight 에서 단축어를 누르면 앱이 열리며 복사된다. 위젯을 누른 것과 같다.
struct OpenClipMemoIntent: OpenIntent {
    static let title = LocalizedStringResource("단축어 열기", comment: "Siri/Spotlight: open a snippet")

    @Parameter(title: LocalizedStringResource("단축어", comment: "Siri: snippet parameter"))
    var target: ClipMemoEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = ClipMemoCopier.copy(target.id)
        return .result()
    }
}

// MARK: - 실제로 복사하는 곳

enum ClipMemoCopier {
    /// 값을 클립보드에 넣고 그 단축어 이름을 돌려준다. 못 찾거나 실어선 안 되는 단축어면 nil.
    static func copy(_ id: UUID) -> String? {
        guard let memo = ((try? MemoStore.shared.load(type: .memo)) ?? []).first(where: { $0.id == id }),
              ClipMemoEntity.isOffered(memo) else { return nil }
        #if os(iOS)
        UIPasteboard.general.string = memo.value
        #endif
        return memo.title
    }
}
