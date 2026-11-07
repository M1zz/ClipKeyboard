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

    private var changeObserver: NSObjectProtocol?

    private init() {
        reload()
        // 다른 타겟/화면이 보관함을 바꿨을 때(공유 익스텐션 저장 등) 다시 읽어온다.
        // 블록 기반 옵저버 사용 - NSObject 비상속 클래스에서 #selector 디스패치를 피한다.
        changeObserver = NotificationCenter.default.addObserver(
            forName: .quickNotesChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.reload()
        }
    }

    // MARK: - File

    /// 보관함 파일. 없음 · 못 읽음 · 깨짐을 가르는 규칙은 그쪽에 있다.
    private static let file = AppGroupListFile<QuickNote>(fileName: StorageFile.quickNotes)

    // MARK: - Load / Save

    /// 디스크에서 다시 읽어 published 배열을 최신화(최신 항목이 위로 오도록 생성 역순 정렬).
    func reload() {
        let notes = Self.loadFromDisk()
        DispatchQueue.main.async { [weak self] in
            self?.quickNotes = notes
        }
    }

    /// 화면에 보일 목록. 고칠 때는 이것을 쓰지 않는다(`change`).
    static func loadFromDisk() -> [QuickNote] {
        file.readForDisplay().sorted { $0.createdAt > $1.createdAt }
    }

    /// 읽고 · 바꾸고 · 쓴다. 읽기에 실패하면 쓰지 않는다(빈 목록에 더해 쓰면 보관함이 통째로 덮인다).
    /// 빠른 메모는 공유 시트 · 제어센터에서 들어온 "잃으면 안 되는 캡처" 라 실패를 돌려준다.
    @discardableResult
    private func change(_ edit: (inout [QuickNote]) -> Void) -> Bool {
        do {
            let notes = try Self.file.modify { notes in
                edit(&notes)
                notes.sort { $0.createdAt > $1.createdAt }
            }
            DispatchQueue.main.async { [weak self] in
                self?.quickNotes = notes
            }
            NotificationCenter.postOnMain(name: .quickNotesChanged, object: nil)
            return true
        } catch {
            AppLog.error(.store, "❌ [QuickNoteStore] 보관함을 고치지 못했다(덮지 않음): \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Mutations

    /// 보관함에 빠른 메모를 추가(가장 위로). 담지 못했으면 false - 부르는 쪽이 "담았어요" 라고 말하지 않게.
    @discardableResult
    func add(_ note: QuickNote) -> Bool {
        let ok = change { $0.insert(note, at: 0) }
        print("\(ok ? "✅" : "❌") [QuickNoteStore.add] 빠른 메모 추가 (source: \(note.source))")
        return ok
    }

    /// 보관함 항목을 갱신(편집 저장).
    func update(_ note: QuickNote) {
        change { notes in
            if let idx = notes.firstIndex(where: { $0.id == note.id }) { notes[idx] = note }
        }
    }

    /// 보관함에서 항목을 삭제. deleteImages == true 면 해당 이미지 파일도 정리(완전 삭제 시).
    func remove(_ id: UUID, deleteImages: Bool) {
        var removed: QuickNote?
        guard change({ notes in
            if let idx = notes.firstIndex(where: { $0.id == id }) { removed = notes.remove(at: idx) }
        }), deleteImages, let removed else { return }
        // 이미지는 목록에서 빠진 것이 확정된 뒤에 지운다
        for fileName in removed.imageFileNames {
            try? MemoStore.shared.deleteImage(fileName: fileName)
        }
    }

    /// 보류 항목을 정식 Memo 로 승격한다. 이미지 파일은 그대로 두고 Memo 가 승계하므로 삭제하지 않는다.
    /// 승격된 Memo 를 반환(필요 시 호출부에서 바로 편집 화면 등으로 연결 가능).
    @discardableResult
    func promoteToMemo(_ note: QuickNote) -> Memo {
        let memo = note.toMemo()
        var memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        memos.insert(memo, at: 0)

        // ⚠️ 저장이 실패하면 **원본을 지우면 안 된다.**
        //    예전에는 try? 로 삼키고 아래에서 보관함 항목을 무조건 제거해서,
        //    저장 실패 시 메모도 없고 보관함 원본도 없는 - 캡처가 통째로 사라지는 상태가 됐다.
        do {
            try MemoStore.shared.save(memos: memos, type: .memo)
        } catch {
            AppLog.error(.store, "❌ [QuickNoteStore.promoteToMemo] 승격 저장 실패, 보관함 원본을 유지한다: \(error.localizedDescription)")
            return memo
        }

        DispatchQueue.main.async {
            MemoStore.shared.memos = memos
        }
        // 저장이 확정된 뒤에만 원본 보관함 항목을 제거(이미지는 메모가 참조하므로 보존).
        remove(note.id, deleteImages: false)
        print("✅ [QuickNoteStore.promoteToMemo] 빠른 메모 → 메모 승격: \(memo.title)")
        return memo
    }

    var count: Int { quickNotes.count }
}
