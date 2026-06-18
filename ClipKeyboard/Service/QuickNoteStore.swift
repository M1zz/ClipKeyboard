//
//  QuickNoteStore.swift
//  ClipKeyboard
//
//  빠른 메모(Inbox) 보관함 저장소(싱글톤). App Group 컨테이너의 quicknotes.data 를 읽고 쓴다.
//  · 공유 익스텐션·Shortcuts·Control Center 가 raw JSON 으로 직접 append 한 항목도 함께 로드.
//  · "메모로 저장"(promote) 시 정식 Memo 로 승격하고 원본 빠른 메모는 삭제(이미지는 메모가 승계).
//  · "삭제"(discard) 시 항목과 함께 보관함 전용 이미지를 정리.
//

import Foundation
#if os(iOS)
import UIKit
#endif

final class QuickNoteStore: ObservableObject {
    static let shared = QuickNoteStore()

    @Published var quickNotes: [QuickNote] = []

    private init() {
        reload()
        // 다른 타겟/화면이 보관함을 바꿨을 때(공유 익스텐션 저장 등) 다시 읽어온다.
        NotificationCenter.default.addObserver(
            self, selector: #selector(reload),
            name: .quickNotesChanged, object: nil
        )
    }

    // MARK: - File

    private static func fileURL() -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) else { return nil }
        return containerURL.appendingPathComponent(StorageFile.quickNotes)
    }

    // MARK: - Load / Save

    /// 디스크에서 다시 읽어 published 배열을 최신화(최신 항목이 위로 오도록 생성 역순 정렬).
    @objc func reload() {
        let notes = Self.loadFromDisk()
        DispatchQueue.main.async { [weak self] in
            self?.quickNotes = notes
        }
    }

    static func loadFromDisk() -> [QuickNote] {
        guard let url = fileURL(), let data = try? Data(contentsOf: url) else { return [] }
        let notes = (try? JSONDecoder().decode([QuickNote].self, from: data)) ?? []
        return notes.sorted { $0.createdAt > $1.createdAt }
    }

    /// 보관함 전체를 디스크에 저장하고 변경 알림을 보낸다(observer 가 reload).
    private func persist(_ notes: [QuickNote]) {
        let sorted = notes.sorted { $0.createdAt > $1.createdAt }
        if let url = Self.fileURL(), let data = try? JSONEncoder().encode(sorted) {
            try? data.write(to: url)
        }
        DispatchQueue.main.async { [weak self] in
            self?.quickNotes = sorted
        }
        NotificationCenter.default.post(name: .quickNotesChanged, object: nil)
    }

    // MARK: - Mutations

    /// 보관함에 빠른 메모를 추가(가장 위로).
    func add(_ note: QuickNote) {
        var notes = Self.loadFromDisk()
        notes.insert(note, at: 0)
        persist(notes)
        print("✅ [QuickNoteStore.add] 빠른 메모 추가 (총 \(notes.count)개, source: \(note.source))")
    }

    /// 보관함 항목을 갱신(편집 저장).
    func update(_ note: QuickNote) {
        var notes = Self.loadFromDisk()
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx] = note
            persist(notes)
        }
    }

    /// 보관함에서 항목을 삭제. deleteImages == true 면 해당 이미지 파일도 정리(완전 삭제 시).
    func remove(_ id: UUID, deleteImages: Bool) {
        var notes = Self.loadFromDisk()
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let removed = notes.remove(at: idx)
        if deleteImages {
            for fileName in removed.imageFileNames {
                try? MemoStore.shared.deleteImage(fileName: fileName)
            }
        }
        persist(notes)
    }

    /// 보류 항목을 정식 Memo 로 승격한다. 이미지 파일은 그대로 두고 Memo 가 승계하므로 삭제하지 않는다.
    /// 승격된 Memo 를 반환(필요 시 호출부에서 바로 편집 화면 등으로 연결 가능).
    @discardableResult
    func promoteToMemo(_ note: QuickNote) -> Memo {
        let memo = note.toMemo()
        var memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        memos.insert(memo, at: 0)
        try? MemoStore.shared.save(memos: memos, type: .memo)
        DispatchQueue.main.async {
            MemoStore.shared.memos = memos
        }
        // 원본 보관함 항목 제거(이미지는 메모가 참조하므로 보존).
        remove(note.id, deleteImages: false)
        print("✅ [QuickNoteStore.promoteToMemo] 빠른 메모 → 메모 승격: \(memo.title)")
        return memo
    }

    var count: Int { quickNotes.count }
}
