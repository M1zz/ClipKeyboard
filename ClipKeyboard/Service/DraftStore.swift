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

    private static func fileURL() -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) else { return nil }
        return containerURL.appendingPathComponent(StorageFile.drafts)
    }

    // MARK: - Load / Save

    func reload() {
        let items = Self.loadFromDisk()
        DispatchQueue.main.async { [weak self] in
            self?.drafts = items
        }
    }

    static func loadFromDisk() -> [SavedDraft] {
        guard let url = fileURL(), let data = try? Data(contentsOf: url) else { return [] }
        let items = (try? JSONDecoder().decode([SavedDraft].self, from: data)) ?? []
        return items.sorted { $0.savedAt > $1.savedAt }
    }

    private func persist(_ items: [SavedDraft]) {
        let sorted = items.sorted { $0.savedAt > $1.savedAt }
        if let url = Self.fileURL(), let data = try? JSONEncoder().encode(sorted) {
            try? data.write(to: url, options: .atomic)
        }
        DispatchQueue.main.async { [weak self] in
            self?.drafts = sorted
        }
        NotificationCenter.default.post(name: .draftsChanged, object: nil)
    }

    // MARK: - Mutations

    /// 드래프트를 추가하거나(같은 id 없으면) 갱신한다(이어쓰기 저장).
    func save(_ draft: SavedDraft) {
        var items = Self.loadFromDisk()
        if let idx = items.firstIndex(where: { $0.id == draft.id }) {
            items[idx] = draft
        } else {
            items.insert(draft, at: 0)
        }
        persist(items)
        print("✅ [DraftStore.save] 임시 저장 (총 \(items.count)개)")
    }

    func remove(_ id: UUID) {
        var items = Self.loadFromDisk()
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items.remove(at: idx)
        persist(items)
    }

    var count: Int { drafts.count }
}
