//
//  MemoSyncCoreTests.swift
//  ClipKeyboardTests
//
//  메모 CloudKit 동기화 순수 로직(MemoSyncCore) 검증.
//  섀도 diff(push 산출)·최신 우선 병합·툼스톤 소프트 삭제를 네트워크 없이 전수 확인한다.
//

import Testing
import Foundation
@testable import ClipKeyboard

@Suite("MemoSyncCore — 섀도 diff & 최신 우선 병합")
struct MemoSyncCoreTests {

    private func memo(_ id: UUID, title: String = "t", value: String = "v",
                      edited: Date = Date(timeIntervalSince1970: 1000)) -> Memo {
        var m = Memo(title: title, value: value)
        m.id = id
        m.lastEdited = edited
        return m
    }

    // MARK: - Fingerprint

    @Test("같은 내용은 같은 지문, 사용량 필드는 지문에서 제외")
    func fingerprintIgnoresUsage() {
        let id = UUID()
        var a = memo(id, title: "hello", value: "world")
        var b = memo(id, title: "hello", value: "world")
        a.clipCount = 5
        a.lastUsedAt = Date(timeIntervalSince1970: 9999)
        b.clipCount = 0
        b.lastUsedAt = nil
        #expect(MemoSyncCore.fingerprint(a) == MemoSyncCore.fingerprint(b))
    }

    @Test("내용이 바뀌면 지문이 달라진다")
    func fingerprintChangesOnContent() {
        let id = UUID()
        let a = memo(id, title: "hello")
        let b = memo(id, title: "HELLO")
        #expect(MemoSyncCore.fingerprint(a) != MemoSyncCore.fingerprint(b))
    }

    // MARK: - localChanges (push 산출)

    @Test("신규/변경 메모는 upsert, 변화 없으면 빈 결과")
    func localChangesDetectsUpserts() {
        let m = memo(UUID(), title: "a")
        let empty = MemoSyncCore.localChanges(current: [m], shadow: [:],
                                              knownTombstones: [:], now: .init(timeIntervalSince1970: 1))
        #expect(empty.upserts.map(\.id) == [m.id])

        let shadow = MemoSyncCore.buildShadow([m])
        let none = MemoSyncCore.localChanges(current: [m], shadow: shadow,
                                             knownTombstones: [:], now: .init(timeIntervalSince1970: 1))
        #expect(none.isEmpty)
    }

    @Test("섀도에 있던 메모가 사라지면 새 툼스톤, 이미 툼스톤이면 재생성 안 함")
    func localChangesDetectsDeletes() {
        let m = memo(UUID(), title: "a")
        let shadow = MemoSyncCore.buildShadow([m])
        let now = Date(timeIntervalSince1970: 5000)

        let del = MemoSyncCore.localChanges(current: [], shadow: shadow,
                                            knownTombstones: [:], now: now)
        #expect(del.newTombstones == [m.id: now])

        let already = MemoSyncCore.localChanges(current: [], shadow: shadow,
                                                knownTombstones: [m.id: now], now: now)
        #expect(already.newTombstones.isEmpty)
    }

    // MARK: - merge (pull)

    @Test("원격 신규 메모는 추가된다")
    func mergeAddsRemoteNew() {
        let r = memo(UUID(), title: "remote")
        let result = MemoSyncCore.merge(local: [], localTombstones: [:],
                                        remote: [RemoteMemo(id: r.id, memo: r, lastEdited: r.lastEdited)])
        #expect(result.memos.map(\.id) == [r.id])
    }

    @Test("최신 우선 — 원격이 더 최신이면 교체, 더 오래면 로컬 유지")
    func mergeLastWriterWins() {
        let id = UUID()
        let localOld = memo(id, title: "local", edited: .init(timeIntervalSince1970: 100))
        let remoteNew = memo(id, title: "remote", edited: .init(timeIntervalSince1970: 200))

        let win = MemoSyncCore.merge(local: [localOld], localTombstones: [:],
                                     remote: [RemoteMemo(id: id, memo: remoteNew, lastEdited: remoteNew.lastEdited)])
        #expect(win.memos.first?.title == "remote")

        let localNew = memo(id, title: "local", edited: .init(timeIntervalSince1970: 300))
        let keep = MemoSyncCore.merge(local: [localNew], localTombstones: [:],
                                      remote: [RemoteMemo(id: id, memo: remoteNew, lastEdited: remoteNew.lastEdited)])
        #expect(keep.memos.first?.title == "local")
    }

    @Test("원격 툼스톤이 더 최신이면 로컬에서 삭제된다")
    func mergeRemoteTombstoneDeletes() {
        let id = UUID()
        let local = memo(id, edited: .init(timeIntervalSince1970: 100))
        let deletedAt = Date(timeIntervalSince1970: 200)
        let result = MemoSyncCore.merge(local: [local], localTombstones: [:],
                                        remote: [RemoteMemo(id: id, memo: nil, lastEdited: deletedAt)])
        #expect(result.memos.isEmpty)
        #expect(result.tombstones[id] == deletedAt)
    }

    @Test("원격 삭제보다 로컬 편집이 최신이면 되살려 재업로드")
    func mergeLocalEditBeatsStaleDelete() {
        let id = UUID()
        let localNew = memo(id, title: "kept", edited: .init(timeIntervalSince1970: 300))
        let deletedAt = Date(timeIntervalSince1970: 200)
        let result = MemoSyncCore.merge(local: [localNew], localTombstones: [:],
                                        remote: [RemoteMemo(id: id, memo: nil, lastEdited: deletedAt)])
        #expect(result.memos.map(\.id) == [id])
        #expect(result.toReupload.map(\.id) == [id])
    }

    @Test("로컬 툼스톤이 원격 메모보다 최신이면 삭제 유지")
    func mergeLocalTombstoneBeatsStaleRemote() {
        let id = UUID()
        let staleRemote = memo(id, title: "old", edited: .init(timeIntervalSince1970: 100))
        let result = MemoSyncCore.merge(local: [], localTombstones: [id: .init(timeIntervalSince1970: 200)],
                                        remote: [RemoteMemo(id: id, memo: staleRemote, lastEdited: staleRemote.lastEdited)])
        #expect(result.memos.isEmpty)
    }

    @Test("원격 메모가 로컬 툼스톤보다 최신이면 되살아난다")
    func mergeRemoteResurrectsOverStaleTombstone() {
        let id = UUID()
        let freshRemote = memo(id, title: "back", edited: .init(timeIntervalSince1970: 300))
        let result = MemoSyncCore.merge(local: [], localTombstones: [id: .init(timeIntervalSince1970: 200)],
                                        remote: [RemoteMemo(id: id, memo: freshRemote, lastEdited: freshRemote.lastEdited)])
        #expect(result.memos.map(\.id) == [id])
        #expect(result.tombstones[id] == nil)
    }
}
