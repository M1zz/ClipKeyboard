//
//  CursorMemory.swift
//  ClipKeyboard
//
//  **넣은 뒤 캐럿이 설 자리를 스스로 배운다.**
//
//  왜 필요한가: `{커서}` 토큰은 쓸모가 큰데 문법을 알아야 존재를 안다.
//  "그거 아세요?"로 알려 주는 방식은 백 명 중 몇 명에게만 닿는다.
//  그래서 알려 주는 대신, 같은 자리로 세 번 돌아간 사람에게는 앱이 조용히 해 준다.
//
//  ⚠️ **사용자의 글은 한 글자도 고치지 않는다.** 배운 값은 본문이 아니라 여기 따로 둔다.
//     본문에 `{커서}` 를 꽂아 넣으면 (1) 사용자가 안 쓴 글자가 자기 단축어에 박히고
//     (2) 맥으로 동기화되면 거기서도 보이고 (3) 되돌리려면 사용자가 손으로 지워야 한다.
//     본문 밖에 두면 셋 다 없다. 끄는 것도 값 하나 지우면 끝이다.
//
//  ⚠️ 본문이 바뀌면 배운 값을 버린다(`textLength` 로 판별). 글이 달라졌는데 옛 자리를
//     그대로 쓰면 엉뚱한 데 캐럿이 선다. 틀린 자동화는 없는 것만 못하다.
//
//  ⚠️ 토큰이 이미 있으면 이쪽은 아무 일도 하지 않는다. 사용자가 직접 정한 자리가 언제나 이긴다.
//
//  관련: ClipKeyboard/Extensions/TemplateVariableProcessor.swift (`resolveCursor`)
//

import Foundation

enum CursorMemory {

    // MARK: - 정책

    /// 같은 자리로 몇 번 돌아가야 "습관"으로 보고 해 주는가.
    /// 한 번은 우연이고 두 번은 우연일 수 있다. 세 번이면 자리다.
    static let threshold = 3

    /// 배운 자리를 쓸 수 있는 최대 거리(글자). 이보다 뒤로 가는 것은 캐럿 이동이 아니라
    /// 딴 문장으로 옮겨 간 것으로 본다.
    static let maxOffset = 500

    // MARK: - 저장 형태

    /// 단축어 하나에 대해 배운 것.
    struct Learned: Codable, Equatable {
        /// 끝에서 몇 글자 앞에 캐럿을 세울지. `CursorPlacement.offsetFromEnd` 와 같은 단위.
        var offsetFromEnd: Int
        /// 같은 자리가 몇 번 관측됐는지.
        var hits: Int
        /// 관측 당시 넣은 글의 길이. 본문이 바뀌면 버리는 근거.
        var textLength: Int
        /// 이미 한 번이라도 적용했는가. 안내를 딱 한 번만 띄우려고 둔다.
        var noticed: Bool = false
        /// 사용자가 껐다. 그러면 다시 배우지 않는다.
        var off: Bool = false

        /// 문턱을 넘어 실제로 해 줄 단계인가.
        var isReady: Bool { !off && hits >= CursorMemory.threshold && offsetFromEnd > 0 }
    }

    // MARK: - 순수 계산 (여기만 시험한다)

    /// 삽입 직후와 지금의 "캐럿 앞 글" 두 장을 견줘, 사용자가 넣은 글 **안쪽** 어디로
    /// 돌아갔는지를 글자 수로 낸다. 돌아간 게 아니면 nil.
    ///
    /// - Parameters:
    ///   - insertedText: 방금 넣은 글(토큰이 제거된 실제 입력값).
    ///   - beforeContextAtInsert: 넣은 **직후**의 `documentContextBeforeInput`.
    ///   - beforeContextNow: 지금의 `documentContextBeforeInput`.
    ///
    /// 판정 조건 (하나라도 어긋나면 nil):
    /// 1. 지금 것이 삽입 직후 것의 **진부분 앞부분**이어야 한다. 뒤로 간 게 아니라 앞으로 갔다는 뜻.
    /// 2. 줄어든 꼬리가 넣은 글의 **꼬리와 같아야** 한다. 캐럿이 넣은 글 안에 있다는 뜻이고,
    ///    동시에 그 사이 글이 안 바뀌었다는 확인이다.
    /// 3. 거리가 0보다 크고 `maxOffset` 이하.
    ///
    /// ⚠️ `documentContextBeforeInput` 은 시스템이 앞쪽을 잘라서 준다. 두 장 모두 같은 방식으로
    ///    잘리므로 꼬리 비교는 그대로 성립한다.
    static func offsetFromCaretMove(insertedText: String,
                                    beforeContextAtInsert: String,
                                    beforeContextNow: String) -> Int? {
        guard !insertedText.isEmpty,
              beforeContextNow.count < beforeContextAtInsert.count,
              beforeContextAtInsert.hasPrefix(beforeContextNow) else { return nil }

        let removed = String(beforeContextAtInsert.dropFirst(beforeContextNow.count))
        let distance = removed.count
        guard distance > 0, distance <= maxOffset, distance <= insertedText.count else { return nil }
        guard insertedText.hasSuffix(removed) else { return nil }

        return distance
    }

    /// 새 관측 하나를 이전 상태에 합친다. 저장소를 안 건드리는 순수 함수라 시험이 쉽다.
    ///
    /// - 같은 자리면 세고, 다른 자리면 **처음부터 다시 센다**(마지막 자리로 갈아탄다).
    ///   사람이 마음을 바꾸면 옛 자리를 끌고 가지 않는 편이 낫다.
    /// - 본문 길이가 달라졌으면 옛 기록을 통째로 버린다.
    /// - 꺼 둔 것은 그대로 꺼 둔다.
    static func merging(_ existing: Learned?,
                        offsetFromEnd: Int,
                        textLength: Int) -> Learned {
        if let existing, existing.off {
            return existing
        }
        guard let existing, existing.textLength == textLength else {
            return Learned(offsetFromEnd: offsetFromEnd, hits: 1, textLength: textLength)
        }
        if existing.offsetFromEnd == offsetFromEnd {
            var next = existing
            next.hits += 1
            return next
        }
        return Learned(offsetFromEnd: offsetFromEnd, hits: 1, textLength: textLength)
    }

    // MARK: - 저장소 (App Group, 키보드와 앱이 같은 값을 본다)

    private static var defaults: UserDefaults? { AppGroup.defaults }

    private static func loadAll() -> [String: Learned] {
        guard let data = defaults?.data(forKey: DefaultsKey.cursorMemory) else { return [:] }
        return (try? JSONDecoder().decode([String: Learned].self, from: data)) ?? [:]
    }

    private static func saveAll(_ all: [String: Learned]) {
        guard let data = try? JSONEncoder().encode(all) else { return }
        defaults?.set(data, forKey: DefaultsKey.cursorMemory)
    }

    // MARK: - 쓰는 쪽

    /// 이 단축어에 대해 배운 것(있으면).
    static func learned(for memoId: UUID) -> Learned? {
        loadAll()[memoId.uuidString]
    }

    /// 지금 넣을 글에 실제로 적용할 거리. 해 줄 단계가 아니거나 본문이 바뀌었으면 nil.
    static func offset(for memoId: UUID, textLength: Int) -> Int? {
        guard let learned = learned(for: memoId),
              learned.isReady,
              learned.textLength == textLength,
              learned.offsetFromEnd <= textLength else { return nil }
        return learned.offsetFromEnd
    }

    /// 관측 하나를 기록한다.
    /// - Returns: 이번 관측으로 **처음** 해 줄 단계가 됐으면 true.
    @discardableResult
    static func observe(memoId: UUID, offsetFromEnd: Int, textLength: Int) -> Bool {
        var all = loadAll()
        let before = all[memoId.uuidString]
        guard before?.off != true else { return false }

        let after = merging(before, offsetFromEnd: offsetFromEnd, textLength: textLength)
        all[memoId.uuidString] = after
        saveAll(all)

        let wasReady = before?.isReady ?? false
        return !wasReady && after.isReady
    }

    /// 안내를 아직 안 띄웠으면 띄웠다고 표시하고 true. 두 번째부터는 false.
    static func markNoticedIfFirstTime(for memoId: UUID) -> Bool {
        var all = loadAll()
        guard var entry = all[memoId.uuidString], entry.isReady, !entry.noticed else { return false }
        entry.noticed = true
        all[memoId.uuidString] = entry
        saveAll(all)
        return true
    }

    /// 사용자가 껐다. 더 배우지도, 해 주지도 않는다.
    ///
    /// ⚠️ 배운 자리 자체는 **지우지 않는다.** 되살릴 때 다시 세 번 가르치게 하지 않으려는 것이고,
    ///    편집 화면의 스위치가 계속 보이려면 기록이 남아 있어야 한다.
    static func turnOff(for memoId: UUID) {
        var all = loadAll()
        var entry = all[memoId.uuidString] ?? Learned(offsetFromEnd: 0, hits: 0, textLength: 0)
        entry.off = true
        all[memoId.uuidString] = entry
        saveAll(all)
    }

    /// 편집 화면에 스위치를 보여 줄 것인가.
    /// 해 주고 있거나(`isReady`), 사용자가 꺼 둔 것이거나. 둘 다 "설명이 필요한 상태"다.
    static func hasSwitch(for memoId: UUID) -> Bool {
        guard let learned = learned(for: memoId) else { return false }
        return learned.isReady || learned.off
    }

    /// 껐던 것을 다시 켠다.
    ///
    /// ⚠️ 배운 자리는 **지우지 않고 그대로 되살린다.** 껐다 켠 사람은 처음부터 다시
    ///    세 번 가르치고 싶은 게 아니라, 방금 끈 것을 되돌리고 싶은 것이다.
    ///    아예 잊게 하려면 `forget(for:)` 이다.
    static func turnOn(for memoId: UUID) {
        var all = loadAll()
        guard var entry = all[memoId.uuidString] else { return }
        entry.off = false
        all[memoId.uuidString] = entry
        saveAll(all)
    }

    /// 단축어가 지워질 때 같이 지운다.
    static func forget(for memoId: UUID) {
        var all = loadAll()
        guard all[memoId.uuidString] != nil else { return }
        all[memoId.uuidString] = nil
        saveAll(all)
    }
}
