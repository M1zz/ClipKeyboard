//
//  MemoSyncConvergenceTests.swift
//  ClipKeyboardTests
//
//  동기화가 **수렴**하는지를 본다 — `MemoSyncCoreTests` 가 개별 규칙(최신 우선·툼스톤)을
//  검증한다면, 여기서는 그 규칙들이 만족해야 하는 성질을 검증한다.
//
//  왜 성질을 따로 보나: 동기화 버그는 규칙 하나가 틀려서가 아니라 **두 기기가 서로 다른
//  결론에 도달**해서 생긴다. 그러면 A는 지웠는데 B에서 되살아나고, 다시 A로 퍼진다(핑퐁).
//  아래 세 성질이 그걸 막는다:
//   ① 결정성 — 타임스탬프가 같아도 어느 기기에서 계산하든 같은 승자
//   ② 대칭성 — 병합 순서가 달라도 같은 결과
//   ③ 멱등성 — 같은 원격을 두 번 받아도 결과가 안 바뀐다
//

import Testing
import Foundation
@testable import ClipKeyboard

struct MemoSyncConvergenceTests {

    private func memo(_ id: UUID, title: String = "t", value: String = "v",
                      edited: Date) -> Memo {
        var m = Memo(title: title, value: value)
        m.id = id
        m.lastEdited = edited
        return m
    }

    private let t100 = Date(timeIntervalSince1970: 100)
    private let t200 = Date(timeIntervalSince1970: 200)

    // MARK: - ① 결정성 (타임스탬프 동률)

    /// 서로 다른 기기가 **같은 초**에 편집하는 일은 실제로 일어난다(자동 저장·마이그레이션).
    /// 이때 시각만으로는 승자를 못 정하므로 id 사전순으로 못 박는다.
    /// 이 규칙이 없으면 기기마다 다른 승자를 골라 영원히 서로 덮어쓴다.
    @Test("타임스탬프가 같으면 id 사전순으로 승자가 결정된다")
    func tieBreakIsDeterministic() {
        let low = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let high = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!

        #expect(MemoSyncCore.isNewer(t100, idLhs: high, than: t100, idRhs: low))
        #expect(!MemoSyncCore.isNewer(t100, idLhs: low, than: t100, idRhs: high))
    }

    /// 같은 id·같은 시각이면 어느 쪽도 "더 최신"이 아니다(무한 재업로드 방지).
    @Test("완전히 같은 항목은 어느 쪽도 더 최신이 아니다")
    func identicalIsNotNewer() {
        let id = UUID()

        #expect(!MemoSyncCore.isNewer(t100, idLhs: id, than: t100, idRhs: id))
    }

    // MARK: - ② 대칭성 (병합 순서 무관)

    /// 원격 레코드가 도착하는 순서는 네트워크가 정한다. 순서에 따라 결과가 달라지면
    /// 같은 데이터를 받은 두 기기가 다른 상태가 된다.
    @Test("원격 레코드 순서가 바뀌어도 병합 결과는 같다")
    func mergeIsOrderIndependent() {
        let idA = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
        let idB = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")!

        let remote = [
            RemoteMemo(id: idA, memo: memo(idA, title: "A", edited: t200), lastEdited: t200),
            RemoteMemo(id: idB, memo: nil, lastEdited: t200)   // B는 원격 삭제
        ]
        let local = [memo(idA, title: "old", edited: t100), memo(idB, title: "B", edited: t100)]

        let forward = MemoSyncCore.merge(local: local, localTombstones: [:], remote: remote)
        let backward = MemoSyncCore.merge(local: local, localTombstones: [:], remote: remote.reversed())

        #expect(forward == backward)
        #expect(forward.memos.count == 1)              // A만 남는다
        #expect(forward.tombstones[idB] != nil)        // B는 툼스톤
    }

    // MARK: - ③ 멱등성

    /// 같은 원격 변경을 두 번 받아도(재시도·중복 푸시) 상태가 흔들리면 안 된다.
    @Test("같은 원격 변경을 두 번 병합해도 결과가 같다")
    func mergeIsIdempotent() {
        let id = UUID()
        let remote = [RemoteMemo(id: id, memo: memo(id, title: "new", edited: t200), lastEdited: t200)]
        let local = [memo(id, title: "old", edited: t100)]

        let once = MemoSyncCore.merge(local: local, localTombstones: [:], remote: remote)
        let twice = MemoSyncCore.merge(local: once.memos, localTombstones: once.tombstones, remote: remote)

        #expect(once == twice)
        #expect(twice.memos.first?.title == "new")
        // 두 번째 병합에서 재업로드가 새로 생기면 핑퐁이 된다.
        #expect(twice.toReupload.isEmpty)
    }

    /// 툼스톤도 멱등이어야 한다 — 삭제를 두 번 받아도 되살아나거나 재업로드되지 않는다.
    @Test("툼스톤 병합도 멱등이다")
    func tombstoneMergeIsIdempotent() {
        let id = UUID()
        let remote = [RemoteMemo(id: id, memo: nil, lastEdited: t200)]
        let local = [memo(id, edited: t100)]

        let once = MemoSyncCore.merge(local: local, localTombstones: [:], remote: remote)
        let twice = MemoSyncCore.merge(local: once.memos, localTombstones: once.tombstones, remote: remote)

        #expect(once == twice)
        #expect(twice.memos.isEmpty)
        #expect(twice.toReupload.isEmpty)
    }

    // MARK: - 시계 역전

    /// 기기 시계가 뒤로 가 있으면(수동 변경·시간대 사고) 그 기기의 편집은 "오래된 것"으로
    /// 취급돼 덮인다. 이건 **의도된 동작**이다 — 여기서 예외를 두면 최신 우선 규칙 자체가
    /// 무너진다. 대신 그런 편집이 조용히 사라지지 않도록 재업로드 목록에도 오르지 않음을 고정한다.
    @Test("과거 시각으로 저장된 로컬 편집은 최신 원격에 덮인다")
    func staleClockLocalEditLoses() {
        let id = UUID()
        let past = Date(timeIntervalSince1970: 1)
        let remote = [RemoteMemo(id: id, memo: memo(id, title: "remote", edited: t200), lastEdited: t200)]
        let local = [memo(id, title: "local-with-bad-clock", edited: past)]

        let result = MemoSyncCore.merge(local: local, localTombstones: [:], remote: remote)

        #expect(result.memos.first?.title == "remote")
        #expect(result.toReupload.isEmpty)
    }

    // MARK: - 로컬 변경 산출

    /// 삭제를 감지한 뒤 다시 계산해도 툼스톤이 중복 생성되면 안 된다(재전송 폭주 방지).
    @Test("이미 알고 있는 삭제는 다시 툼스톤으로 만들지 않는다")
    func localChangesDoesNotDuplicateTombstones() {
        let id = UUID()
        let shadow: [UUID: String] = [id: "fingerprint"]

        let first = MemoSyncCore.localChanges(current: [], shadow: shadow,
                                              knownTombstones: [:], now: t100)
        #expect(first.newTombstones[id] == t100)

        let second = MemoSyncCore.localChanges(current: [], shadow: shadow,
                                               knownTombstones: first.newTombstones, now: t200)
        #expect(second.newTombstones.isEmpty)
        #expect(second.isEmpty)
    }
}
