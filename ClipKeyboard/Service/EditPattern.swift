//
//  EditPattern.swift
//  ClipKeyboard
//
//  **넣고 나서 매번 같은 자리를 고치면, 그 자리는 빈칸이다.**
//
//  왜 필요한가: 템플릿(`{빈칸}`)은 이 앱에서 가장 쓸모가 큰 기능인데,
//  중괄호 문법을 알아야 존재를 안다. "그거 아세요?"로 알려 주는 방식은
//  설정을 뒤져 볼 몇 명에게만 닿는다. 그래서 알려 주는 대신,
//  **이미 그 일을 손으로 하고 있는 사람**에게만 말을 건다.
//
//  갈래는 셋이고, 셋 다 다른 답이 필요하다.
//
//  | 매번 무엇이 | 뜻 | 할 말 |
//  | --- | --- | --- |
//  | 같은 자리, **다른** 값 | 그 자리는 빈칸이다 | 템플릿으로 만들까요 |
//  | 같은 자리, **같은** 값 | 저장해 둔 글이 낡았다 | 이걸로 바꿀까요 |
//  | 자리가 매번 다름 | 그냥 딴 글을 쓴 것 | 아무 말도 안 한다 |
//
//  ⚠️ 세 번째가 제일 중요하다. 여기서 말을 걸면 그때부터 잔소리가 된다.
//     확신이 없으면 침묵하는 쪽이 언제나 낫다.
//
//  ⚠️ 여기서는 **판정만** 한다. 사용자의 글을 고치지도, 저장소를 건드리지도 않는다.
//     같은 이유로 시험이 쉽다(`EditPatternTests`).
//
//  관련: ClipKeyboard/Service/CursorMemory.swift (같은 관찰에서 갈라져 나온다)
//

import Foundation

enum EditPattern {

    // MARK: - 정책

    /// 몇 번 같은 모양을 봐야 말을 거는가. 캐럿 학습과 같은 문턱이다.
    static let threshold = 3

    /// 이보다 긴 단축어는 보지 않는다.
    ///
    /// ⚠️ 키보드가 읽을 수 있는 `documentContextBeforeInput` 은 앞이 잘려 온다.
    ///    긴 글은 고친 자리가 잘린 쪽에 있을 수 있어, 봤다고 믿으면 틀린 판정을 한다.
    ///    짧은 것(계좌번호·주소·인사말)이 원래 이 기능이 필요한 것들이기도 하다.
    static let maxTextLength = 200

    // MARK: - 한 번의 고침

    /// 넣은 글 하나와 고쳐진 글 하나를 견준 결과.
    struct Diff: Equatable {
        /// 바뀐 구간이 시작되는 자리(앞에서부터 같은 글자 수).
        let prefixLength: Int
        /// 바뀐 구간 뒤로 같은 글자 수.
        let suffixLength: Int
        /// 원래 그 자리에 있던 글.
        let original: String
        /// 사용자가 바꿔 넣은 글.
        let replacement: String

        /// 고친 자리의 모양. 값이 무엇이든 자리가 같으면 같다.
        var slot: String { "\(prefixLength)/\(suffixLength)" }
    }

    /// 두 글의 다른 구간을 하나로 집어낸다. 안 바뀌었거나 볼 수 없는 모양이면 nil.
    ///
    /// 앞뒤로 같은 부분을 깎아 가운데만 남기는 방식이라, 고친 자리가 **한 군데**일 때만
    /// 뜻이 있다. 두 군데 이상 고친 경우도 하나의 넓은 구간으로 뭉쳐 나오는데,
    /// 그건 `merging` 에서 자리가 안 맞아 저절로 걸러진다.
    static func diff(inserted: String, edited: String) -> Diff? {
        guard !inserted.isEmpty,
              inserted != edited,
              inserted.count <= maxTextLength,
              edited.count <= maxTextLength else { return nil }

        let a = Array(inserted)
        let b = Array(edited)

        var prefix = 0
        while prefix < a.count, prefix < b.count, a[prefix] == b[prefix] {
            prefix += 1
        }

        var suffix = 0
        while suffix < (a.count - prefix), suffix < (b.count - prefix),
              a[a.count - 1 - suffix] == b[b.count - 1 - suffix] {
            suffix += 1
        }

        let original = String(a[prefix..<(a.count - suffix)])
        let replacement = String(b[prefix..<(b.count - suffix)])

        // 통째로 갈아치운 것은 "고친 것"이 아니라 딴 글을 쓴 것이다.
        guard prefix > 0 || suffix > 0 else { return nil }

        return Diff(prefixLength: prefix,
                    suffixLength: suffix,
                    original: original,
                    replacement: replacement)
    }

    // MARK: - 쌓인 모양

    /// 무엇을 제안할지.
    enum Suggestion: String, Codable, Equatable {
        /// 같은 자리에 매번 다른 값 → 그 자리를 빈칸으로.
        case makeTemplate
        /// 같은 자리에 매번 같은 값 → 저장해 둔 글 자체를 고치자.
        case updateOriginal
    }

    /// 한 단축어에 대해 쌓인 고침의 모양.
    struct Record: Codable, Equatable {
        /// 고친 자리(`Diff.slot`). 자리가 달라지면 처음부터 다시 센다.
        var slot: String
        /// 같은 자리를 몇 번 고쳤나.
        var hits: Int
        /// 그 자리에 넣은 값들. 값이 매번 같은지 다른지를 이걸로 본다.
        var replacements: [String]
        /// 관측 당시 넣은 글의 길이. 본문이 바뀌면 버리는 근거.
        var textLength: Int
        /// 이미 제안했다. 두 번 묻지 않는다.
        var asked: Bool = false
        /// 사용자가 거절했다. 다시 묻지 않는다.
        var declined: Bool = false

        /// 지금 제안할 것(있으면).
        var suggestion: Suggestion? {
            guard !declined, !asked, hits >= EditPattern.threshold else { return nil }
            guard let first = replacements.first else { return nil }
            // 값까지 매번 같으면 저장해 둔 글이 낡은 것이고,
            // 자리는 같은데 값이 다르면 그 자리가 빈칸이다.
            return replacements.allSatisfy { $0 == first } ? .updateOriginal : .makeTemplate
        }
    }

    /// 새 고침 하나를 이전 상태에 합친다. 저장소를 안 건드리는 순수 함수.
    ///
    /// - 자리가 달라지면 **처음부터 다시 센다.** 지난번과 다른 데를 고쳤다는 건
    ///   빈칸이 아니라 그냥 딴 글을 쓴 것이다.
    /// - 본문 길이가 달라졌으면 옛 기록을 버린다(사용자가 단축어를 고쳤다).
    /// - 거절한 것은 그대로 둔다.
    static func merging(_ existing: Record?, diff: Diff, textLength: Int) -> Record {
        if let existing, existing.declined {
            return existing
        }
        guard let existing,
              existing.textLength == textLength,
              existing.slot == diff.slot else {
            return Record(slot: diff.slot,
                          hits: 1,
                          replacements: [diff.replacement],
                          textLength: textLength)
        }
        var next = existing
        next.hits += 1
        next.replacements.append(diff.replacement)
        // 최근 것만 들고 있으면 된다. 값이 매번 같은지만 보면 되고,
        // 오래된 값까지 쌓아 두면 App Group 에 계속 불어난다.
        if next.replacements.count > threshold {
            next.replacements.removeFirst(next.replacements.count - threshold)
        }
        return next
    }

    /// 제안을 받아들여 만들 템플릿 본문.
    /// 고친 자리를 `{이름}` 으로 판다. 사용자가 직접 중괄호를 칠 일이 없다.
    ///
    /// ⚠️ 원본 단축어를 고치지 않는다. **새 글을 만들어 돌려줄 뿐**이고,
    ///    저장할지는 사용자가 화면에서 정한다.
    static func templateText(from inserted: String, record: Record, placeholderName: String) -> String? {
        guard record.slot.contains("/") else { return nil }
        let parts = record.slot.split(separator: "/")
        guard parts.count == 2,
              let prefix = Int(parts[0]), let suffix = Int(parts[1]) else { return nil }

        let chars = Array(inserted)
        guard prefix >= 0, suffix >= 0, prefix + suffix <= chars.count else { return nil }

        let head = String(chars[0..<prefix])
        let tail = String(chars[(chars.count - suffix)...])
        return head + "{\(placeholderName)}" + tail
    }
}

// MARK: - 저장소 (App Group, 키보드와 앱이 같은 값을 본다)

extension EditPattern {

    private static var defaults: UserDefaults? { AppGroup.defaults }

    private static func loadAll() -> [String: Record] {
        guard let data = defaults?.data(forKey: DefaultsKey.editPatterns) else { return [:] }
        return (try? JSONDecoder().decode([String: Record].self, from: data)) ?? [:]
    }

    private static func saveAll(_ all: [String: Record]) {
        guard let data = try? JSONEncoder().encode(all) else { return }
        defaults?.set(data, forKey: DefaultsKey.editPatterns)
    }

    static func record(for memoId: UUID) -> Record? {
        loadAll()[memoId.uuidString]
    }

    /// 고침 하나를 기록한다.
    /// - Returns: 이번 고침으로 **제안할 거리**가 생겼으면 그 제안. 아니면 nil.
    static func observe(memoId: UUID, diff: Diff, textLength: Int) -> Suggestion? {
        var all = loadAll()
        let before = all[memoId.uuidString]
        guard before?.declined != true else { return nil }

        let after = merging(before, diff: diff, textLength: textLength)
        all[memoId.uuidString] = after
        saveAll(all)
        return after.suggestion
    }

    /// 물어봤다고 표시한다. 받아들이든 말든 두 번 묻지 않는다.
    static func markAsked(for memoId: UUID) {
        var all = loadAll()
        guard var entry = all[memoId.uuidString] else { return }
        entry.asked = true
        all[memoId.uuidString] = entry
        saveAll(all)
    }

    /// 사용자가 거절했다. 이 단축어에 대해서는 다시 묻지 않는다.
    static func markDeclined(for memoId: UUID) {
        var all = loadAll()
        var entry = all[memoId.uuidString] ?? Record(slot: "", hits: 0, replacements: [], textLength: 0)
        entry.declined = true
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

// MARK: - 제안을 받아들였을 때 실제로 하는 일

extension EditPattern {

    /// 빈칸 이름의 기본값. 사용자가 중괄호를 칠 일이 없게 앱이 대신 판다.
    static var defaultPlaceholderName: String {
        NSLocalizedString("빈칸", comment: "Default placeholder name for an auto-detected template slot")
    }

    /// 제안을 받아들여 단축어를 **그 자리에서** 바꾼다.
    ///
    /// ⚠️ 새 단축어를 만들지 않고 **원래 것을 바꾼다.** 이유가 둘이다.
    ///    (1) 매번 그 자리를 고쳐 온 사람에게 필요한 건 두 벌이 아니라 고쳐진 한 벌이다.
    ///    (2) 새로 만들면 무료 칸을 하나 먹는다. 제안을 받아들였다고 한도에 부딪히면
    ///        도와준 게 아니라 파는 것처럼 보인다.
    ///
    /// ⚠️ 사용자가 **누른 다음에만** 부른다. 조용히 부르지 않는다.
    ///    본문을 바꾸는 일이라, 캐럿 자리 학습과 달리 동의 없이 할 수 있는 일이 아니다.
    ///
    /// - Returns: 바꿨으면 true.
    @discardableResult
    static func apply(_ suggestion: Suggestion, memoId: UUID) -> Bool {
        guard let record = record(for: memoId),
              var memos = try? MemoStore.shared.load(type: .memo),
              let index = memos.firstIndex(where: { $0.id == memoId }) else { return false }

        let original = memos[index].value

        switch suggestion {
        case .makeTemplate:
            guard let text = templateText(from: original,
                                          record: record,
                                          placeholderName: defaultPlaceholderName) else { return false }
            memos[index].value = text
            memos[index].templateVariables = TemplatePlaceholder.names(in: text)

        case .updateOriginal:
            // 매번 같은 값으로 고쳤으니, 그 값을 원래 자리에 박아 둔다.
            guard let replacement = record.replacements.first,
                  let text = templateText(from: original,
                                          record: record,
                                          placeholderName: defaultPlaceholderName) else { return false }
            memos[index].value = text.replacingOccurrences(of: "{\(defaultPlaceholderName)}",
                                                           with: replacement)
        }

        memos[index].lastEdited = Date()
        do {
            try MemoStore.shared.save(memos: memos, type: .memo)
        } catch {
            print("❌ [EditPattern.apply] 저장 실패: \(error)")
            return false
        }

        // 바꿨으니 쌓아 둔 관찰은 뜻이 없다. 새 본문으로 처음부터 본다.
        forget(for: memoId)
        return true
    }
}
