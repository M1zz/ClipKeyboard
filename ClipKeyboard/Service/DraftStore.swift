//
//  DraftStore.swift
//  ClipKeyboard
//
//  임시 저장(드래프트) 저장소(싱글톤). App Group 컨테이너의 drafts.data 를 읽고 쓴다.
//  메모를 만들다가 저장하지 않고 나가면 여기에 자동 보관되고,
//  "임시 저장 보기"에서 이어 작성하거나 삭제할 수 있다. QuickNoteStore 와 동일한 패턴.
//

import Foundation

final class DraftStore: ObservableObject {
    static let shared = DraftStore()

    @Published var drafts: [SavedDraft] = []

    private var changeObserver: NSObjectProtocol?

    private init() {
        reload()
        changeObserver = NotificationCenter.default.addObserver(
            forName: .draftsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.reload()
        }
    }

    // MARK: - File

    /// 임시 저장 파일. 없음 · 못 읽음 · 깨짐을 가르는 규칙은 그쪽에 있다.
    private static let file = AppGroupListFile<SavedDraft>(fileName: StorageFile.drafts)

    // MARK: - Load / Save

    func reload() {
        let items = Self.loadFromDisk()
        DispatchQueue.main.async { [weak self] in
            self?.drafts = items
        }
    }

    /// 화면에 보일 목록. 고칠 때는 이것을 쓰지 않는다(`change`).
    static func loadFromDisk() -> [SavedDraft] {
        file.readForDisplay().sorted { $0.savedAt > $1.savedAt }
    }

    /// 읽고 · 바꾸고 · 쓴다. 읽기에 실패하면 쓰지 않는다(다른 임시 저장본을 덮지 않게).
    private func change(_ edit: (inout [SavedDraft]) -> Void) {
        do {
            let items = try Self.file.modify { items in
                edit(&items)
                items.sort { $0.savedAt > $1.savedAt }
            }
            DispatchQueue.main.async { [weak self] in
                self?.drafts = items
            }
            NotificationCenter.postOnMain(name: .draftsChanged, object: nil)
        } catch {
            AppLog.error(.store, "❌ [DraftStore] 임시 저장을 고치지 못했다(덮지 않음): \(error.localizedDescription)")
        }
    }

    // MARK: - Mutations

    /// 드래프트를 추가하거나(같은 id 없으면) 갱신한다(이어쓰기 저장).
    func save(_ draft: SavedDraft) {
        change { items in
            if let idx = items.firstIndex(where: { $0.id == draft.id }) {
                items[idx] = draft
            } else {
                items.insert(draft, at: 0)
            }
        }
    }

    func remove(_ id: UUID) {
        change { $0.removeAll { $0.id == id } }
    }

    var count: Int { drafts.count }
}
