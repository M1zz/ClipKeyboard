//
//  MemoStore.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/05/16.
//

import Foundation

/// 저장소가 던지는 오류. 화면에 그대로 보이지 않고, 부르는 쪽이 저장을 멈추는 신호로 쓴다.
enum MemoStoreError: Error, LocalizedError {
    /// 파일이 있는데 읽지 못했다.
    case unreadable(String, Error)
    /// 읽지 못한 채로 저장하려 했다. 덮어쓰면 그 파일의 내용이 사라진다.
    case unreadBeforeSave(String)

    var errorDescription: String? {
        switch self {
        case .unreadable(let name, let error): return "\(name): \(error.localizedDescription)"
        case .unreadBeforeSave(let name): return "refused to overwrite unread \(name)"
        }
    }
}

enum MemoType: Hashable {
    case memo
    case stack
}

// MARK: - 파일 신원표

/// 파일이 그 사이에 바뀌었는지 판정하기 위한 표식. `stat` 한 번으로 전부 얻는다.
///
/// 왜 mtime 만으로는 부족한가: 이 앱의 저장은 전부 `.write(to:options:.atomic)` 이라
/// 새 파일을 만들어 갈아끼운다. 그래서 **inode 가 바뀐다.** 세 값을 함께 보면
/// 같은 나노초에 같은 크기로 갈아끼운 경우까지 걸러진다.
struct FileStamp: Equatable {
    let modified: Date
    let size: Int
    /// inode. `.atomic` 저장은 새 파일을 만들어 갈아끼우므로 여기서 반드시 달라진다.
    let fileNumber: Int

    /// 파일이 없거나 읽을 수 없으면 nil.
    static func of(_ url: URL) -> FileStamp? {
        guard let a = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = a[.modificationDate] as? Date,
              let size = a[.size] as? Int,
              let fileNumber = a[.systemFileNumber] as? Int else { return nil }
        return FileStamp(modified: modified, size: size, fileNumber: fileNumber)
    }
}

// MARK: - 읽기 실패 막이

extension Data {
    /// 파일을 읽는다. **없으면 nil, 있는데 못 읽으면 던진다.** 두 경우를 섞지 않는 것이 요점이다.
    static func readIfPresent(_ url: URL, options: Data.ReadingOptions = []) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try Data(contentsOf: url, options: options)
        } catch {
            AppLog.error(.store, "❌ [Data.readIfPresent] \(url.lastPathComponent) 를 읽지 못했다: \(error.localizedDescription)")
            throw MemoStoreError.unreadable(url.lastPathComponent, error)
        }
    }
}

/// 파일이 **있는데 못 읽은** 것을 기억하고, 다시 제대로 읽기 전까지 그 파일의 저장을 거절한다.
///
/// 왜 필요한가: 못 읽은 자리에서 빈 목록을 돌려주면, 부르는 쪽은 그 빈 목록에 한 줄을 더해
/// 저장한다. 그러면 **멀쩡한 파일이 한 줄짜리로 덮인다.** 기기가 잠겨 파일 보호가 걸렸을 때
/// 키보드가 읽거나, 다른 프로세스가 파일을 갈아끼우는 찰나에 읽으면 실제로 일어난다.
/// 깨진 파일(디코딩 실패)은 격리 사본이 있어 이 막이에 넣지 않는다(`MemoStore.quarantineCorruptFile`).
final class UnreadFileGuard<Key: Hashable> {
    private var unreadable: Set<Key> = []
    private let lock = NSLock()

    /// 읽고, 성공 · 실패를 적는다.
    func read(_ url: URL, as key: Key, options: Data.ReadingOptions = []) throws -> Data? {
        do {
            let data = try Data.readIfPresent(url, options: options)
            mark(key, readable: true)
            return data
        } catch {
            mark(key, readable: false)
            throw error
        }
    }

    func refuseIfUnread(_ key: Key) throws {
        lock.lock()
        let blocked = unreadable.contains(key)
        lock.unlock()
        guard !blocked else {
            AppLog.error(.store, "🛑 [UnreadFileGuard] \(key) 를 읽지 못한 채라 저장을 거절한다(덮어쓰기 막이)")
            throw MemoStoreError.unreadBeforeSave("\(key)")
        }
    }

    private func mark(_ key: Key, readable: Bool) {
        lock.lock()
        if readable { unreadable.remove(key) } else { unreadable.insert(key) }
        lock.unlock()
    }
}

class MemoStore: ObservableObject {
    static let shared = MemoStore()

    @Published var memos: [Memo] = []
    @Published var combos: [Combo] = []

    // MARK: - 로드 캐시

    /// 디코딩 결과를 파일 신원표와 함께 들고 있는다. 파일이 그대로면 다시 풀지 않는다.
    ///
    /// 왜 필요한가: `load(type:)` 은 부르는 자리가 아주 많다(목록 화면 하나만 해도
    /// `loadMemos()` 호출 지점이 18곳이고, 대부분 시트 `onDismiss` 와 `.memoDataChanged`
    /// 에 물려 있다). 그 전부가 메인 스레드에서 파일을 읽고 JSON 을 통째로 푼다.
    ///
    /// 측정(Instruments, iPhone15,3 / iOS 26.5.2 / Release / 메모 505개 · 339 KB):
    /// 25초 트레이스에서 `decodeMemosFromData` 만 60 ms 였고, 스크롤 도중에도 돌았다.
    ///
    /// ⚠️ 무효화는 **파일 신원표**로 한다. 이 파일은 이 프로세스만 쓰는 것이 아니다.
    ///    키보드·공유 익스텐션(`Shared/QuickShortcutSave.swift`)이 같은 파일을 직접
    ///    갈아끼우고, CloudKit 복원과 백업 가져오기도 그렇다. 알림이나 플래그에
    ///    기대면 그 경로 중 하나만 빠뜨려도 **낡은 목록을 보여주고, 이어서 저장하면
    ///    남의 변경이 조용히 지워진다.** `stat` 은 누가 썼든 알아챈다.
    private var loadCache: [MemoType: (stamp: FileStamp, memos: [Memo])] = [:]
    private let loadCacheLock = NSLock()

    // MARK: - 읽기 실패 막이

    /// 못 읽은 파일 위에 저장하지 않는다(`UnreadFileGuard`).
    private let unread = UnreadFileGuard<MemoType>()

    private func cachedMemos(for type: MemoType, stamp: FileStamp?) -> [Memo]? {
        guard let stamp else { return nil }
        loadCacheLock.lock()
        defer { loadCacheLock.unlock() }
        guard let hit = loadCache[type], hit.stamp == stamp else { return nil }
        return hit.memos
    }

    private func rememberMemos(_ memos: [Memo], for type: MemoType, at url: URL) {
        // 치유 저장 등으로 읽은 뒤 파일이 바뀌었을 수 있어 **지금** 다시 잰다.
        guard let stamp = FileStamp.of(url) else { return }
        loadCacheLock.lock()
        loadCache[type] = (stamp, memos)
        loadCacheLock.unlock()
    }

    static func fileURL(type: MemoType) throws -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) else {
            return URL(string: "")
        }

        switch type {
        case .memo:
            return containerURL.appendingPathComponent(StorageFile.memos)
        case .stack:
            return containerURL.appendingPathComponent(StorageFile.combos)
        }
    }

    /// 데이터가 바뀌었다고 알린다. **언제나 메인에서 쏜다.**
    ///
    /// ⚠️ 받는 쪽은 전부 화면이다. 목록·설정·무대·카테고리 관리가 `onReceive` 로 받아
    ///    곧바로 다시 읽는데, `onReceive` 는 **알림이 쏘아진 스레드에서** 돈다.
    ///    저장은 배경에서도 일어나므로(동기화·백업·일괄 가져오기), 거기서 그대로 쏘면
    ///    화면의 `@Published` 가 배경에서 바뀌어 이 경고가 뜬다.
    ///
    ///        Publishing changes from background threads is not allowed
    ///
    ///    경고로 끝나지 않는다. 뷰 갱신이 배경에서 시작되면 드물게 화면이 어긋나거나
    ///    죽는다. 값이 아니라 **알리는 자리**를 메인으로 옮기는 것이 옳다.
    ///    받는 쪽마다 `receive(on:)` 을 붙이는 방법도 있지만, 받는 곳이 일곱이고
    ///    앞으로 더 는다. 쏘는 곳 한 군데를 고치면 전부 끝난다.
    ///
    /// ⚠️ **메인이어도 미룬다.** 조건 없이 `DispatchQueue.main.async` 하나만 쓴다.
    ///
    ///    처음에는 "이미 메인이면 그 자리에서 쏜다"로 두었다. 순서를 지키려던 것인데,
    ///    그렇게 두면 받는 쪽이 **쏘는 쪽의 호출 스택 안에서 곧바로** 돈다.
    ///    `memoDataChanged` 를 받으면 목록이 `loadMemos()` 를 부르고, 그 안에서
    ///    빈 카테고리를 정규화하다 다시 저장하면 이 함수가 **다시** 불린다.
    ///    저장 도중에 저장이 겹치는 재진입이라, 그 안에서 무엇이 발행되는지 따라가기 어렵다.
    ///
    ///    한 박자 미루면 그런 겹침이 없다. 받는 쪽은 언제나 **저장이 끝난 뒤** 깨끗한
    ///    상태에서 읽는다. 늦어지는 것은 한 런루프이고, 받는 일은 화면을 다시 읽는 것뿐이라
    ///    그 지연이 보이지 않는다.
    /// `memoDataChanged` 의 userInfo 열쇠. 값은 `MemoStore.Change.rawValue`.
    static let changeKindKey = "MemoStore.change"

    static func postDataChanged(_ change: Change = .content) {
        // ⚠️ `NotificationCenter.postOnMain` 이 아니다. 그쪽은 이미 메인이면 그 자리에서 쏜다.
        //    여기는 위에 적은 재진입 때문에 **메인이어도** 한 박자 미뤄야 한다.
        DispatchQueue.main.async {
            // notify-ok: 메인이어도 한 박자 미뤄야 하는 재진입 때문(위 머리말)
            NotificationCenter.default.post(name: Notification.Name.memoDataChanged, object: nil,
                                            userInfo: [Self.changeKindKey: change.rawValue])
        }
    }

    /// 쓴 횟수만 바뀐 저장의 알림인가. 동기화 · 백업처럼 내용만 보는 곳은 이걸로 거른다.
    /// 열쇠가 없는 알림(다른 길에서 온 것)은 내용 변경으로 본다 - 놓치는 것보다 한 번 더 도는 편이 낫다.
    static func isUsageOnly(_ note: Notification) -> Bool {
        (note.userInfo?[changeKindKey] as? String) == Change.usage.rawValue
    }

    /// 무엇이 바뀐 저장인가.
    ///
    /// ⚠️ `.usage` 는 **쓴 횟수 · 마지막 사용 시각만** 바뀐 저장이다. 넣을 때마다 오는 저장이라
    ///    가장 잦은데, 예전에는 내용 편집과 똑같이 이력 비교(파일을 한 번 더 풀고 단축어 전부를
    ///    이어 붙여 두 번 비교) · 카테고리 보조 기록 · 동기화 · 백업까지 다 깨웠다.
    ///    단축어 500개에서 넣을 때마다 메인이 100ms 가까이 막혔다.
    enum Change: String {
        case content
        case usage
    }

    func save(memos: [Memo], type: MemoType, recordHistory: Bool = true, change: Change = .content) throws {
        try unread.refuseIfUnread(type)
        // 타임머신: 메모를 덮어쓰기 직전, 의미 있는 변경이면 "이전 상태"를 스냅샷으로 보관.
        // (대량 삭제·편집·마이그레이션 사고를 되돌릴 수 있는 로컬 안전망. 최근 10개 유지.)
        // 사용량만 바뀐 저장은 이력 비교 자체를 하지 않는다 - 비교해 봐야 같다.
        if type == .memo, recordHistory, change == .content {
            captureMemoHistoryIfMeaningful(newMemos: memos)
        }
        let data = try JSONEncoder().encode(memos)
        guard let outfile = try Self.fileURL(type: type) else { return }
        // 덮기 직전의 목록(캐시가 디스크와 같을 때만). 사라진 단축어를 알아보는 데 쓴다.
        let previous = type == .memo && change == .content ? cachedMemos(for: type, stamp: FileStamp.of(outfile)) : nil
        try data.write(to: outfile, options: .atomic)
        if let previous { Self.forgetRemoved(from: previous, keeping: memos) }
        // 방금 쓴 내용이 곧 진실이다. 알림을 받은 화면들이 바로 다시 읽으므로
        // 여기서 캐시를 채워두면 그 재로드가 디코딩 없이 끝난다.
        rememberMemos(memos, for: type, at: outfile)
        // 다운그레이드로 유실되지 않도록 카테고리 할당을 사이드카에도 보관.
        // 사용량만 바뀐 저장에서는 카테고리가 그대로라 다시 쓰지 않는다.
        if type == .memo, change == .content {
            Self.writeCategorySidecar(memos)
        }
        Self.postDataChanged(change)
    }

    /// 사라진 단축어에 대해 배운 것(커서 자리 · 편집 습관)을 지운다.
    ///
    /// 왜 여기인가: 단축어가 지워지는 길은 목록 · 키보드 · 일괄 선택 · 기기 간 동기화로 여럿이다.
    /// 그 길마다 지우기를 붙이면 하나는 빠진다(실제로 지우는 함수에만 붙어 있었고 그 함수는 불리지 않았다).
    /// 모든 길이 이 저장을 지나므로 여기서 한 번 본다.
    private static func forgetRemoved(from previous: [Memo], keeping memos: [Memo]) {
        let removed = Set(previous.map(\.id)).subtracting(memos.map(\.id))
        for id in removed {
            CursorMemory.forget(for: id)
            EditPattern.forget(for: id)
        }
    }

    func load(type: MemoType) throws -> [Memo] {
        guard let fileURL = try Self.fileURL(type: type) else { return [] }

        // 파일이 그대로면 디코딩을 통째로 건너뛴다. `stat` 은 마이크로초, 디코딩은 밀리초다.
        let stamp = FileStamp.of(fileURL)
        if let cached = cachedMemos(for: type, stamp: stamp) { return cached }

        guard let data = try unread.read(fileURL, as: type) else { return [] }

        // ⚠️ 손상 감지: 예전에는 디코딩이 실패해도 빈 배열을 돌려줘서 "메모가 전부 사라진 것처럼"
        //    보였다. 더 나쁜 건 그 뒤 아무 저장이나 일어나면 빈 배열이 파일에 덮여 **진짜로**
        //    사라진다는 점이다. 실패를 구분해서 원본을 격리 보존하고 화면에 알린다.
        guard var memos = decodeMemosFromData(data) else {
            Self.quarantineCorruptFile(at: fileURL, type: type)
            return []
        }
        if type == .memo {
            if Self.restoreCategoriesFromSidecar(&memos) {
                // 다운그레이드 등으로 memos.data의 category가 유실된 흔적 →
                // 사이드카에서 복원하고 파일도 치유(재저장, 스냅샷 폭주 방지 위해 recordHistory:false).
                // 치유 저장 실패는 치명적이지 않다(다음 로드에서 다시 시도한다).
                // 다만 조용히 넘기면 "왜 계속 복원되지?"의 원인을 못 찾으니 남긴다.
                do {
                    try save(memos: memos, type: .memo, recordHistory: false)
                    AppLog.info(.store, "🔄 [MemoStore.load] 유실된 메모 카테고리를 사이드카에서 복원·치유")
                } catch {
                    AppLog.warning(.store, "⚠️ [MemoStore.load] 카테고리 치유 저장 실패(다음 로드에서 재시도): \(error.localizedDescription)")
                }
            } else if Self.categorySidecarMissing() {
                // 기존 사용자 1회 부트스트랩 - 이후 다운그레이드에 대비해 사이드카를 채워둔다.
                Self.writeCategorySidecar(memos)
            }
        }
        rememberMemos(memos, for: type, at: fileURL)
        return memos
    }

    /// 디코딩 결과. **nil = 손상**(빈 배열과 구분해야 한다
    /// 메모가 0개인 정상 상태와 파일이 깨진 상태는 완전히 다른 사건이다).
    private func decodeMemosFromData(_ data: Data) -> [Memo]? {
        if let memos = try? JSONDecoder().decode([Memo].self, from: data) {
            return memos
        }
        if let oldMemos = try? JSONDecoder().decode([OldMemo].self, from: data) {
            return oldMemos.map { Memo(from: $0) }
        }
        return nil
    }

    // MARK: - 손상 격리

    /// 손상 감지 플래그 - 앱이 읽어 복구 안내를 띄운다. (키보드 익스텐션도 같은 키를 쓴다)
    static let corruptionFlagKey = "data.corruption.detectedAt"
    /// 격리된 원본 파일명 - 복구 안내에서 "원본은 보관돼 있다"고 알려주기 위해.
    static let corruptionFileKey = "data.corruption.quarantinedFile"

    /// 깨진 파일을 **지우지 않고** 사본으로 격리한 뒤 플래그를 세운다.
    /// ⚠️ 원본을 삭제하거나 덮어쓰지 않는다 - 사용자 데이터를 되살릴 마지막 단서다.
    private static func quarantineCorruptFile(at url: URL, type: MemoType) {
        let stamp = Int(Date().timeIntervalSince1970)
        let quarantined = url.deletingLastPathComponent()
            .appendingPathComponent("\(url.lastPathComponent).corrupt-\(stamp)")

        do {
            // 복사(이동 아님) - 원본을 그대로 두어야 다른 경로에서 복구를 시도할 수 있다.
            if !FileManager.default.fileExists(atPath: quarantined.path) {
                try FileManager.default.copyItem(at: url, to: quarantined)
            }
            AppLog.error(.store, "🚨 [MemoStore.quarantine] \(url.lastPathComponent) 디코딩 실패 → \(quarantined.lastPathComponent) 로 사본 보관")
        } catch {
            AppLog.error(.store, "❌ [MemoStore.quarantine] 사본 보관 실패: \(error.localizedDescription)")
        }

        let defaults = AppGroup.defaults
        defaults?.set(Date().timeIntervalSince1970, forKey: corruptionFlagKey)
        defaults?.set(quarantined.lastPathComponent, forKey: corruptionFileKey)
    }

    /// 복구 안내를 띄워야 하는가.
    static var hasDetectedCorruption: Bool {
        (AppGroup.defaults?.double(forKey: corruptionFlagKey) ?? 0) > 0
    }

    /// 사용자가 안내를 확인했을 때 호출 - 플래그만 지운다(격리 사본은 남긴다).
    static func clearCorruptionFlag() {
        let defaults = AppGroup.defaults
        defaults?.removeObject(forKey: corruptionFlagKey)
        defaults?.removeObject(forKey: corruptionFileKey)
    }

    // MARK: - 카테고리 다운그레이드 안전장치 (사이드카)
    //
    // 각 메모의 `category`는 memos.data JSON 안에 저장된다. 카테고리 필드가 없는 구버전
    // Memo 모델이 이 파일을 로드한 뒤 재저장하면 `category` 키가 통째로 빠져, 다운그레이드 →
    // 재업그레이드 시 모든 메모가 "기본"으로 떨어진다(카테고리 유실). 이미 배포된 구버전의
    // 동작은 바꿀 수 없으므로, 구버전이 절대 읽지/쓰지 않는 App Group UserDefaults 키에
    // [메모ID: 카테고리] 맵을 따로 저장해두고 신버전 로드 시 복원한다.
    // (구버전엔 카테고리 편집 UI가 없으니, 신버전 저장 시점의 사이드카가 항상 정답이다.)
    private static let categorySidecarKey = "memoCategoryAssignments_v1"
    private static let defaultCategoryName = "기본"
    private static var sidecarDefaults: UserDefaults? {
        AppGroup.defaults
    }

    /// 현재 메모들의 '비기본' 카테고리 할당을 사이드카에 통째로 덮어써 항상 최신 상태로 유지.
    static func writeCategorySidecar(_ memos: [Memo]) {
        guard let d = sidecarDefaults else { return }
        var map: [String: String] = [:]
        for m in memos where !m.category.isEmpty && m.category != defaultCategoryName {
            map[m.id.uuidString] = m.category
        }
        d.set(map, forKey: categorySidecarKey)
    }

    static func categorySidecarMissing() -> Bool {
        sidecarDefaults?.dictionary(forKey: categorySidecarKey) == nil
    }

    /// 사이드카의 카테고리를 복원. memos.data 쪽이 기본/빈값(=구버전이 지운 유실 신호)인
    /// 메모만 덮어쓴다. 신버전에서 의도적으로 '기본'으로 옮긴 경우엔 저장 시 사이드카에서도
    /// 제거되므로 잘못 되살아나지 않는다. 변경이 있었으면 true.
    static func restoreCategoriesFromSidecar(_ memos: inout [Memo]) -> Bool {
        guard let d = sidecarDefaults,
              let map = d.dictionary(forKey: categorySidecarKey) as? [String: String],
              !map.isEmpty else { return false }
        var changed = false
        for i in memos.indices {
            guard let saved = map[memos[i].id.uuidString],
                  !saved.isEmpty, saved != defaultCategoryName else { continue }
            let current = memos[i].category
            if current.isEmpty || current == defaultCategoryName {
                memos[i].category = saved
                changed = true
            }
        }
        return changed
    }

    // MARK: - Clip Count

    /// - Parameter copiedText: 실제로 클립보드에 들어간 글. 콤보처럼 **여러 값 중 하나**를
    ///   골라 쓰는 경우 메모 본문만 봐서는 무엇이 복사됐는지 알 수 없어서 호출자가 알려준다.
    ///   (붙여넣기 연습이 "복사한 그것"과 맞는지 볼 때 쓴다.)
    func incrementClipCount(for memoId: UUID, copiedText: String? = nil) throws {
        var memos = try load(type: .memo)
        if let index = memos.firstIndex(where: { $0.id == memoId }) {
            memos[index].clipCount += 1
            memos[index].lastUsedAt = Date()
            let used = memos[index]
            if used.isConsumable {
                // 쓰면 지우기: 방금 나간 윗줄을 지운다. 마지막 줄이었으면 단축어째 지운다.
                // 넣는 자리마다 지우기를 붙이면 하나는 빠진다(키보드 · 앱 목록 · Siri · 길게 눌러 복사).
                // 모든 길이 여기를 지나므로 여기 한 곳이면 된다. 내용이 바뀐 저장이라 동기화도 따라간다.
                if let rest = Self.valueAfterConsuming(used) {
                    memos[index].value = rest
                    memos[index].lastEdited = Date()
                } else {
                    memos.remove(at: index)
                }
                try save(memos: memos, type: .memo, change: .content)
            } else {
                try save(memos: memos, type: .memo, change: .usage)
            }
            // 일일 카운트 + 평생 절약 시간 + 월 원장 갱신 (메모 길이 기반)
            KeyboardUsageTracker.recordMemoUse(value: used.value,
                                               type: used.autoDetectedType,
                                               memoID: memoId)

            // 무료로 쓰는 기간을 센다. 줄지 않는 값이라 단축어를 지워도 남는다(FreeUse).
            FreeUse.recordUse()

            // "오늘 썼다"는 표식. 사용자 상태(UserState)의 활동일이 여기서 쌓인다.
            // ⚠️ 이 함수가 앱·키보드 양쪽 사용의 **유일한 길목**이라 여기 한 곳이면 된다.
            ActiveDayLedger.record()

            // 언제 썼는가. 매주·매달·매일 같은 때 쓰는 단축어를 그때가 오면 앞에 세운다.
            // 남기는 것은 id 와 시각뿐이다(ClipKeyboard/Service/UsageRhythm.swift).
            UsageRhythmLog.record(memoID: memoId)

            // "문구를 한 번 썼다"는 신호. 일반 탭·템플릿 확정·콤보 값 복사·보안 인증 후
            // **어느 경로로 들어와도 여기 한 곳을 지난다.** 화면이 탭 시점에 직접 판단하면
            // 시트가 뜨는 경로에서 아직 쓰지도 않았는데 동전이 날아간다.
            NotificationCenter.postOnMain(
                name: .memoUsed,
                object: nil,
                userInfo: [MemoUsedKey.memoID: memoId,
                           MemoUsedKey.earnedSeconds: KeyboardUsageTracker.earnedSeconds(
                            value: used.value,
                            type: used.autoDetectedType,
                            useCount: 1),
                           MemoUsedKey.copiedText: copiedText ?? used.textToUse(),
                           MemoUsedKey.title: used.title,
                           MemoUsedKey.isSecure: used.isSecure,
                           MemoUsedKey.isImage: used.contentType == .image]
            )
        }
    }

    /// 쓰면 지우기 단축어를 **넣지 않고 복사만** 한 길(길게 눌러 복사 · Siri · 메뉴)에서 부른다.
    /// 복사도 한 번 준 것이다. 그 줄을 지우지 않으면 같은 코드가 두 사람에게 간다.
    func consumeIfNeeded(_ memo: Memo, copiedText: String) {
        guard memo.isConsumable else { return }
        do { try incrementClipCount(for: memo.id, copiedText: copiedText) }
        catch { print("⚠️ [MemoStore.consumeIfNeeded] 지우지 못함: \(error)") }
    }

    /// 쓰면 지우기 단축어에서 첫 줄을 뺀 본문. 남은 줄이 없으면 nil.
    /// 잠근 단축어는 풀어서 빼고 다시 잠근다. 열쇠가 없어 못 풀면 그대로 둔다
    /// (지우지 못한 것이지, 잘못 지운 것은 아니다. 키보드도 그때는 넣지 않는다).
    private static func valueAfterConsuming(_ memo: Memo) -> String? {
        guard SecureMemoCrypto.isEncrypted(memo.value) else { return ConsumableLines.remainder(after: memo.value) }
        guard let plain = SecureMemoCrypto.decrypt(memo.value) else { return memo.value }
        guard let rest = ConsumableLines.remainder(after: plain) else { return nil }
        return SecureMemoCrypto.encrypt(rest) ?? memo.value
    }

    // MARK: - Favorite

    func hasFavoriteMemo() -> Bool {
        guard let memos = try? load(type: .memo) else { return false }
        return memos.contains(where: { $0.isFavorite })
    }

    // MARK: - Placeholder Values

    // ⚠️ 빈칸 값의 자리와 형식은 `PlaceholderValueBook` 한 곳에 있다(키보드도 그것을 쓴다).
    //    여기서 고치는 일은 전부 `modify` 를 거친다. 풀지 못한 값 위에 덮어쓰지 않기 위해서다.

    func loadPlaceholderValues(for placeholder: String) -> [PlaceholderValue] {
        PlaceholderValueBook.values(placeholder)
    }

    func savePlaceholderValues(_ values: [PlaceholderValue], for placeholder: String) {
        PlaceholderValueBook.write(values, for: placeholder)
    }

    /// 값 **하나**를 맨 앞에 올린다. 최근에 쓴 것이 앞에 오는 목록이라 이게 맞다.
    ///
    /// ⚠️ 여러 개를 넣을 때 이걸 **되풀이해서 부르지 말 것.** 하나씩 맨 앞에 꽂으므로
    ///    넣은 순서가 통째로 뒤집힌다(`["A","B","C"]` → `["C","B","A"]`).
    ///    목록을 통째로 넣을 때는 아래 `mergePlaceholderValues(_:for:...)` 를 쓴다.
    func addPlaceholderValue(_ value: String, for placeholder: String, sourceMemoId: UUID, sourceMemoTitle: String) {
        PlaceholderValueBook.add(value, for: placeholder, sourceMemoId: sourceMemoId, sourceMemoTitle: sourceMemoTitle)
    }

    /// 넣기를 마친 빈칸 값 가운데 **다음 번호**만 새로 적는다. 안 적으면 다음번에도 같은 번호가 나온다.
    ///
    /// ⚠️ 고른 값의 자리는 옮기지 않는다 - 순서는 사람이 빈칸 관리에서 정한다(5.0.7).
    /// ⚠️ 직접 친 값은 **적지 않는다.** 이번에만 쓰는 값이다.
    ///    규칙: `PlaceholderSequence.shouldRemember` · 키보드 쪽 같은 일: `KeyboardViewController.rememberNextSequenceValues`
    func rememberNextSequenceValues(_ inputs: [String: String], sourceMemoId: UUID, sourceMemoTitle: String) {
        for (placeholder, chosen) in inputs {
            let value = chosen.trimmingCharacters(in: .whitespacesAndNewlines)
            let stored = loadPlaceholderValues(for: placeholder).map(\.value)
            guard PlaceholderSequence.shouldRemember(chosen: value, stored: stored, token: placeholder) else { continue }
            addPlaceholderValue(value, for: placeholder, sourceMemoId: sourceMemoId, sourceMemoTitle: sourceMemoTitle)
        }
    }

    /// 단축어가 들고 있는 빈칸 값 목록을 **적어 둔 순서 그대로** 공용 저장소에 합친다.
    ///
    /// 왜 따로 있나: 예전에는 저장할 때 `addPlaceholderValue` 를 값마다 되풀이해 불렀다.
    /// 그 함수는 하나씩 **맨 앞에** 꽂으므로, 편집 화면에서 위에서 아래로 적어 둔 값이
    /// 저장할 때마다 아래에서 위로 뒤집혔다. 다시 열면 뒤집힌 채로 보이고, 고쳐 저장하면
    /// 또 뒤집힌다(사용자 신고: "편집할 때마다 관리 빈칸 섹션이 자주 뒤집혀 있습니다").
    ///
    /// ⚠️ 순서는 화면에 보이는 것만의 문제가 아니다. 키보드는 목록의 **첫 값**을 기본값으로
    ///    집어 넣는다. 뒤집히면 맨 처음 적어 둔 값 대신 맨 나중 값이 들어간다
    ///    (같은 신고의 "{} 부분이 잘못되고" 가 이것이다).
    func mergePlaceholderValues(_ values: [String],
                                for placeholder: String,
                                sourceMemoId: UUID,
                                sourceMemoTitle: String) {
        let incoming = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !incoming.isEmpty else { return }

        // 이 단축어가 말하는 값들은 앞으로, 다른 데서 온 값들은 그 뒤로.
        let fresh = incoming.map {
            PlaceholderValue(value: $0, sourceMemoId: sourceMemoId, sourceMemoTitle: sourceMemoTitle)
        }
        PlaceholderValueBook.modify(placeholder) { values in
            values.removeAll { incoming.contains($0.value) }
            values = fresh + values
        }
    }

    /// 값 하나를 지운다.
    ///
    /// ⚠️ **단축어에 붙어 있는 사본(`Memo.placeholderValues`)에서도 함께 지운다.**
    ///    그 사본은 키보드가 폴백으로 읽는 자리라, 공용 저장소에서만 지우면 앱에서는 사라졌는데
    ///    키보드에서는 그대로 나오는 일이 생긴다. 지운 것이 다시 나오면 사용자는 지웠다는 것을
    ///    믿지 못하게 된다.
    func deletePlaceholderValue(valueId: UUID, for placeholder: String) {
        var removed: String?
        PlaceholderValueBook.modify(placeholder) { values in
            removed = values.first { $0.id == valueId }?.value
            values.removeAll { $0.id == valueId }
        }

        if let removed {
            removeValueFromMemoCopies(removed, for: placeholder)
        }
    }

    /// 단축어에 붙어 있는 옛 사본에서 같은 값을 걷어낸다. 사본이 없으면 아무 일도 안 한다.
    private func removeValueFromMemoCopies(_ value: String, for placeholder: String) {
        guard var memos = try? load(type: .memo) else { return }
        var touched = false

        for index in memos.indices {
            guard var values = memos[index].placeholderValues[placeholder],
                  values.contains(value) else { continue }
            values.removeAll { $0 == value }
            if values.isEmpty {
                memos[index].placeholderValues.removeValue(forKey: placeholder)
            } else {
                memos[index].placeholderValues[placeholder] = values
            }
            touched = true
        }

        guard touched else { return }
        do {
            try save(memos: memos, type: .memo)
            print("🧹 [MemoStore.deletePlaceholderValue] 단축어에 붙어 있던 사본에서도 지웠다: \(placeholder)")
        } catch {
            // 공용 저장소에서는 이미 지워졌다. 사본 정리 실패로 지우기 자체를 되돌리지는 않는다.
            print("⚠️ [MemoStore.deletePlaceholderValue] 사본 정리 실패: \(error)")
        }
    }

    /// 빈칸 이름 바꾸기의 결과. 화면이 무엇을 말해 줄지 이 값으로 정한다.
    enum PlaceholderRenameResult: Equatable {
        /// 바꿨다. 본문을 고친 단축어 수를 함께 준다(0이면 값만 남아 있던 빈칸).
        case renamed(memosTouched: Int)
        /// 이름이 비었거나 중괄호만 남는 등 쓸 수 없는 이름.
        case invalidName
        /// `{날짜}` 처럼 앱이 알아서 채우는 자동 변수 이름이라 쓸 수 없다.
        case reservedName
        /// 이미 있는 빈칸 이름이다. 두 빈칸을 합치는 일은 하지 않는다.
        case nameTaken
        /// 같은 이름이라 할 일이 없다.
        case unchanged
    }

    /// 빈칸 이름을 바꾼다. 값도, 본문도, 사본도 함께 옮긴다.
    ///
    /// 어디에 쓰나: "안 쓰는 이름이 쌓여 목록이 지저분하다"는 제보에서 지우기와 함께 나온 요청.
    /// 이름을 잘못 지었을 때 지우고 다시 만드는 것 말고는 길이 없었다(사용자 제보, 2026-08).
    ///
    /// ⚠️ 지우기와 달리 **본문의 `{토큰}` 을 고친다.** 그렇게 하지 않으면 이름만 바뀌고
    ///    단축어들은 여전히 옛 이름을 가리켜, 바꾼 쪽이 곧바로 고아가 된다. 본문을 건드리는
    ///    일이라 부르는 쪽에서 몇 개가 바뀌는지 먼저 보여 주고 물어야 한다.
    ///
    /// ⚠️ 이미 있는 이름으로는 바꾸지 않는다(`nameTaken`). 두 빈칸을 합치면 값이 섞이고
    ///    어느 쪽 값이 남는지 사용자가 알 수 없다. 합치기는 다른 기능이다.
    ///
    /// - Parameters:
    ///   - old: 중괄호를 포함한 지금 이름. 예: `{이름}`
    ///   - newName: 사용자가 적은 새 이름. 중괄호는 있어도 없어도 된다.
    @discardableResult
    func renamePlaceholder(_ old: String, to newName: String) -> PlaceholderRenameResult {
        let bare = newName.strippingTemplateBraces.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bare.isEmpty, !bare.contains("{"), !bare.contains("}") else { return .invalidName }
        let new = "{\(bare)}"
        guard new != old else { return .unchanged }
        guard !TemplateVariableProcessor.autoVariableTokens.contains(new) else { return .reservedName }

        var memos = (try? load(type: .memo)) ?? []
        let taken = Set(storedPlaceholderTokens())
            .union(memos.flatMap { TemplatePlaceholder.customTokens(in: $0.value) })
        guard !taken.contains(new) else { return .nameTaken }

        // 1) 값 - 새 이름으로 옮기고 옛 자리는 비운다(App Group + 표준 UserDefaults 의 옛 값).
        // 풀지 못한 값은 옮기지도 지우지도 않는다(옛 자리에 남겨 두어야 되찾을 수 있다).
        if let values = PlaceholderValueBook.stored(old) {
            if !values.isEmpty { PlaceholderValueBook.write(values, for: new) }
            PlaceholderValueBook.remove(old)
        }

        // 2) 본문·변수 목록·사본 - 셋 다 옛 이름을 들고 있다.
        var touched = 0
        for index in memos.indices where Self.rename(&memos[index], from: old, to: new) {
            touched += 1
        }

        if touched > 0 {
            do {
                try save(memos: memos, type: .memo)
            } catch {
                // 값은 이미 옮겨졌다. 본문 저장이 실패하면 옛 이름이 본문에 남아 새 빈칸이
                // 고아가 된다. 되돌리기보다 무엇이 어긋났는지 남기고 화면에 알린다.
                print("❌ [MemoStore.renamePlaceholder] 본문 저장 실패: \(error)")
            }
        }
        print("✏️ [MemoStore.renamePlaceholder] \(old) → \(new) (단축어 \(touched)개)")
        return .renamed(memosTouched: touched)
    }

    /// 빈칸을 **손으로 만든다.** 본문에 `{ }` 를 적기 전에 값을 먼저 모아 두고 싶을 때.
    ///
    /// 어디에 쓰나: 빈칸 관리에는 이름을 바꾸고 지우는 길만 있고 **만드는 길이 없었다**.
    /// 그래서 새 빈칸 하나를 만들려면 단축어 본문에 `{이름}` 을 적었다가 지우는 우회가
    /// 필요했다(사용자 제보).
    ///
    /// ⚠️ 값이 없어도 목록에 남아야 하므로 **빈 배열을 적어 둔다.** 목록은 저장소의
    ///    `placeholder_values_*` 열쇠를 훑어 모으므로(`storedPlaceholderTokens`),
    ///    열쇠 자체가 "이 빈칸이 있다"는 표시가 된다.
    /// ⚠️ 이름 규칙은 이름 바꾸기와 **같다**. 한쪽만 느슨하면 만들 수는 있는데 못 바꾸는
    ///    이름이 생긴다.
    ///
    /// - Parameter name: 사용자가 적은 이름. 중괄호는 있어도 없어도 된다.
    @discardableResult
    func createPlaceholder(_ name: String) -> PlaceholderCreateResult {
        let bare = name.strippingTemplateBraces.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bare.isEmpty, !bare.contains("{"), !bare.contains("}") else { return .invalidName }
        let token = "{\(bare)}"
        guard !TemplateVariableProcessor.autoVariableTokens.contains(token) else { return .reservedName }

        let memos = (try? load(type: .memo)) ?? []
        let taken = Set(storedPlaceholderTokens())
            .union(memos.flatMap { TemplatePlaceholder.customTokens(in: $0.value) })
        guard !taken.contains(token) else { return .nameTaken }

        savePlaceholderValues([], for: token)
        print("➕ [MemoStore.createPlaceholder] 빈칸을 만들었다: \(token)")
        return .created(token: token)
    }

    /// 빈칸 만들기의 결과. 막힌 이유를 화면이 그대로 말해 준다.
    enum PlaceholderCreateResult: Equatable {
        case created(token: String)
        /// 이름이 비었거나 중괄호가 섞여 쓸 수 없는 이름.
        case invalidName
        /// `{날짜}` 처럼 앱이 알아서 채우는 이름.
        case reservedName
        /// 이미 있는 빈칸 이름.
        case nameTaken
    }

    /// 단축어 하나에서 빈칸 이름을 갈아 끼운다. 바꾼 것이 있으면 true.
    ///
    /// 옛 이름이 숨어 있는 자리가 셋이라 따로 뺐다 - 본문, 변수 목록(`templateVariables`),
    /// 그리고 단축어에 붙어 있는 값 사본. 저장소를 건드리지 않는 순수한 일이라
    /// 시험도 여기에 걸 수 있다.
    static func rename(_ memo: inout Memo, from old: String, to new: String) -> Bool {
        var changed = false
        if memo.value.contains(old) {
            memo.value = memo.value.replacingOccurrences(of: old, with: new)
            changed = true
        }
        if memo.templateVariables.contains(old) {
            memo.templateVariables = memo.templateVariables.map { $0 == old ? new : $0 }
            changed = true
        }
        if let copies = memo.placeholderValues.removeValue(forKey: old) {
            memo.placeholderValues[new] = copies
            changed = true
        }
        return changed
    }

    /// 빈칸 하나를 통째로 지운다. 값도, 남아 있던 사본도 함께.
    ///
    /// 어디에 쓰나: 템플릿을 지웠거나 이름을 바꿔서 **쓰는 단축어가 하나도 없는** 빈칸이
    /// 관리 화면에 계속 남는다. 값은 하나씩 지울 수 있었지만 빈칸 자체는 지울 방법이 없어,
    /// 목록이 쓰지 않는 이름으로 불어나기만 했다(사용자 피드백, 2026-08).
    ///
    /// ⚠️ 지워야 할 자리가 **세 곳**이다. 하나라도 빠뜨리면 지운 것이 되살아난다.
    ///    1. App Group 의 값 (지금 저장소)
    ///    2. 표준 UserDefaults 의 옛 값 - `storedPlaceholderTokens()` 가 양쪽을 훑기 때문에
    ///       안 지우면 값이 0인 유령 이름으로 목록에 남는다
    ///    3. 단축어에 붙어 있는 사본(`Memo.placeholderValues`) - 키보드가 폴백으로 읽는 자리다
    ///
    /// ⚠️ **본문의 `{토큰}` 은 건드리지 않는다.** 남의 글을 말없이 고치지 않는다는 뜻이고,
    ///    그래서 아직 쓰는 단축어가 있는 빈칸은 지워도 다음에 다시 나타난다.
    ///    부르는 쪽이 "쓰는 단축어 없음"(`PlaceholderSummary.isOrphan`)만 지우게 할 것.
    func deletePlaceholder(_ placeholder: String) {
        PlaceholderValueBook.remove(placeholder)
        removePlaceholderFromMemoCopies(placeholder)
        print("🗑️ [MemoStore.deletePlaceholder] 빈칸을 지웠다: \(placeholder)")
    }

    /// 단축어에 붙어 있는 사본에서 이 빈칸을 통째로 걷어낸다. 사본이 없으면 아무 일도 안 한다.
    private func removePlaceholderFromMemoCopies(_ placeholder: String) {
        guard var memos = try? load(type: .memo) else { return }
        var touched = false

        for index in memos.indices where memos[index].placeholderValues[placeholder] != nil {
            memos[index].placeholderValues.removeValue(forKey: placeholder)
            touched = true
        }

        guard touched else { return }
        do {
            try save(memos: memos, type: .memo)
            print("🧹 [MemoStore.deletePlaceholder] 단축어에 붙어 있던 사본에서도 지웠다: \(placeholder)")
        } catch {
            // 공용 저장소에서는 이미 지워졌다. 사본 정리 실패로 지우기 자체를 되돌리지는 않는다.
            print("⚠️ [MemoStore.deletePlaceholder] 사본 정리 실패: \(error)")
        }
    }

    /// 값이 저장돼 있는 빈칸 이름 전부.
    ///
    /// 어디에 쓰나: 단축어에서 사라진 빈칸도 값은 남아 있다(템플릿을 지웠거나 이름을 바꿨을 때).
    /// 그 값이 화면 어디에도 안 보이면 지울 수도 없다. 관리 화면이 이 목록으로 그것들까지 보여 준다.
    ///
    /// ⚠️ 값은 **App Group** 에 저장된다. 예전에 표준 UserDefaults 로 쓰던 것도 있어 양쪽을 훑는다.
    func storedPlaceholderTokens() -> [String] {
        PlaceholderValueBook.storedTokens()
    }

    // MARK: - Combo

    func saveCombos(_ combos: [Combo]) throws {
        try unread.refuseIfUnread(.stack)
        let data = try JSONEncoder().encode(combos)
        guard let outfile = try Self.fileURL(type: .stack) else { return }
        try data.write(to: outfile, options: .atomic)
        DispatchQueue.main.async { [weak self] in self?.combos = combos }
        Self.postDataChanged()
    }

    func loadCombos() throws -> [Combo] {
        guard let fileURL = try Self.fileURL(type: .stack) else { return [] }
        guard let data = try unread.read(fileURL, as: .stack) else { return [] }
        guard let combos = try? JSONDecoder().decode([Combo].self, from: data) else {
            // 메모와 같은 이유로 원본을 격리 보존한다 - 빈 목록 뒤의 저장이 덮어쓰지 못하게
            Self.quarantineCorruptFile(at: fileURL, type: .stack)
            return []
        }
        DispatchQueue.main.async { [weak self] in self?.combos = combos }
        return combos
    }

    func addStack(_ stack: Combo) throws {
        var combos = try loadCombos()
        combos.insert(stack, at: 0)
        try saveCombos(combos)
    }

    func incrementStackUseCount(id: UUID) throws {
        var combos = try loadCombos()
        if let index = combos.firstIndex(where: { $0.id == id }) {
            combos[index].useCount += 1
            combos[index].lastUsed = Date()
            try saveCombos(combos)
        }
    }

    func getStackItemValue(_ item: ComboItem) throws -> String? {
        switch item.type {
        case .memo:
            return try load(type: .memo).first(where: { $0.id == item.referenceId })?.value
        case .clipboardHistory:
            return try ClipboardHistoryStore.shared.load().first(where: { $0.id == item.referenceId })?.content
        case .template:
            if let displayValue = item.displayValue, !displayValue.isEmpty { return displayValue }
            return try load(type: .memo).first(where: { $0.id == item.referenceId })?.value
        }
    }

    func validateStackItem(_ item: ComboItem) throws -> Bool {
        switch item.type {
        case .memo:
            return try load(type: .memo).contains(where: { $0.id == item.referenceId && !$0.isTemplate })
        case .clipboardHistory:
            return try ClipboardHistoryStore.shared.load().contains(where: { $0.id == item.referenceId })
        case .template:
            return try load(type: .memo).contains(where: { $0.id == item.referenceId && $0.isTemplate })
        }
    }

    func cleanupStack(_ stack: Combo) throws -> Combo {
        var validItems: [ComboItem] = []
        for item in stack.items {
            if try validateStackItem(item) {
                validItems.append(item)
            }
        }

        var cleaned = stack
        cleaned.items = validItems.enumerated().map { index, item in
            var updated = item
            updated.order = index
            return updated
        }
        return cleaned
    }

    // MARK: - Memo Time Machine (최근 변경 스냅샷)

    /// 메모 전체 상태의 스냅샷(되돌리기용). 최근 N개만 보관.
    static let memoHistoryLimit = 10

    private static func historyFileURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent(StorageFile.memoHistory)
    }

    /// 사용량(clipCount/lastUsedAt/lastEdited)만 다른 저장은 스냅샷하지 않도록 비교용 서명 생성.
    /// 제목·본문·카테고리·타입·자식·이미지·힌트 등 "의미 있는" 필드만 포함.
    ///
    /// ⚠️ 문자열로 이어 붙이지 않는다. 예전에는 단축어 전부를 정렬해 한 줄로 잇고(수백 KB)
    ///    그걸 두 번 만들어 비교했다. 지금은 단축어마다 해시를 내고 **더한다** - 더하기는 순서와
    ///    상관없어서 정렬이 필요 없다. 같은 프로세스 안에서 두 값을 비교할 뿐이라 `Hasher` 로 충분하다.
    static func historySignature(_ memos: [Memo]) -> Int {
        memos.reduce(into: (count: 0, sum: 0)) { acc, m in
            var h = Hasher()
            h.combine(m.id)
            h.combine(m.title)
            h.combine(m.value)
            h.combine(m.category)
            h.combine(m.isTemplate)
            h.combine(m.isSecure)
            h.combine(m.childMemoIds)
            h.combine(m.imageFileNames)
            h.combine(m.hint)
            h.combine(m.icon)
            acc.count += 1
            acc.sum &+= h.finalize()
        }.sum &+ memos.count
    }

    /// 되돌리기 이력. **밀려 있는 이력 쓰기가 끝난 뒤의 것**을 읽는다.
    ///
    /// ⚠️ 이력 쓰기는 메인 밖 한 줄(`historyQueue`)에서 한다. 저장 직후 바로 읽어도 방금 것이
    ///    빠지지 않게, 읽기도 같은 줄을 지난다. 그 줄 안에서 부르면 기다리지 않고 바로 읽는다.
    func loadMemoHistory() -> [MemoSnapshot] {
        if DispatchQueue.getSpecific(key: Self.historyQueueKey) != nil {
            return readMemoHistoryFile()
        }
        return Self.historyQueue.sync { readMemoHistoryFile() }
    }

    private func readMemoHistoryFile() -> [MemoSnapshot] {
        guard let url = Self.historyFileURL(), let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([MemoSnapshot].self, from: data)) ?? []
    }

    private func saveMemoHistory(_ snapshots: [MemoSnapshot]) {
        guard let url = Self.historyFileURL() else { return }
        // 되돌리기 이력 저장 실패는 앱을 멈출 일은 아니지만, 조용히 넘기면
        // "되돌리기가 왜 비어 있지?"의 원인을 나중에 찾을 수 없다.
        do {
            let data = try JSONEncoder().encode(snapshots)
            try data.write(to: url, options: .atomic)
        } catch {
            AppLog.error(.store, "❌ [MemoStore.saveMemoHistory] 변경 기록 저장 실패: \(error.localizedDescription)")
        }
    }

    /// 현재 디스크 상태(곧 덮어쓸 이전 메모)를 스냅샷으로 push. 의미 있는 변경일 때만.
    private func captureMemoHistoryIfMeaningful(newMemos: [Memo]) {
        guard let url = try? Self.fileURL(type: .memo) else { return }
        // 디스크 그대로를 이미 들고 있으면 다시 풀지 않는다(파일 신원표가 같을 때만 믿는다).
        let current: [Memo]
        if let cached = cachedMemos(for: .memo, stamp: FileStamp.of(url)) {
            current = cached
        } else {
            guard let data = try? Data(contentsOf: url) else { return }   // 기존 데이터 없으면 스냅샷 불필요
            // 디코딩 실패(nil)면 스냅샷을 만들지 않는다 - 깨진 내용을 이력에 남길 이유가 없다.
            guard let decoded = decodeMemosFromData(data) else { return }
            current = decoded
        }
        guard !current.isEmpty else { return }
        guard Self.historySignature(current) != Self.historySignature(newMemos) else { return }  // 사용량만 변경 → skip
        pushMemoSnapshot(current)
    }

    /// 이력 파일을 다루는 줄. 한 줄이라 쓰기끼리 겹치지 않는다.
    ///
    /// ⚠️ 이력은 최근 10벌을 통째로 담은 파일이라(단축어 500개면 수 MB) 읽고 다시 쓰는 데
    ///    수백 ms 가 든다. 예전에는 단축어를 고칠 때마다 메인에서 했다. 이 파일은 되돌리기
    ///    화면만 읽으므로 저장을 기다릴 이유가 없다.
    private static let historyQueueKey = DispatchSpecificKey<Bool>()
    private static let historyQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "MemoStore.history", qos: .utility)
        queue.setSpecific(key: historyQueueKey, value: true)
        return queue
    }()

    private func pushMemoSnapshot(_ memos: [Memo]) {
        let snapshot = MemoSnapshot(id: UUID(), timestamp: Date(), memoCount: memos.count, memos: memos)
        Self.historyQueue.async { [weak self] in
            guard let self else { return }
            var history = self.readMemoHistoryFile()
            history.insert(snapshot, at: 0)
            if history.count > Self.memoHistoryLimit {
                history = Array(history.prefix(Self.memoHistoryLimit))
            }
            self.saveMemoHistory(history)
        }
    }

    /// 밀려 있는 이력 쓰기가 끝날 때까지 기다린다. 되돌리기 화면과 시험이 부른다.
    func flushMemoHistory() {
        Self.historyQueue.sync {}
    }

    /// 스냅샷으로 되돌린다. 되돌리기 자체도 취소할 수 있도록 현재 상태를 먼저 스냅샷에 남긴다.
    @discardableResult
    func restoreMemoSnapshot(_ id: UUID) -> Bool {
        flushMemoHistory()
        let history = loadMemoHistory()
        guard let snapshot = history.first(where: { $0.id == id }) else { return false }
        // 현재 상태 보존(되돌리기의 되돌리기 가능)
        if let url = try? Self.fileURL(type: .memo), let data = try? Data(contentsOf: url) {
            // 깨진 파일은 스냅샷으로 남기지 않는다(되돌릴 값이 못 된다).
            if let current = decodeMemosFromData(data), !current.isEmpty { pushMemoSnapshot(current) }
        }
        do {
            try save(memos: snapshot.memos, type: .memo, recordHistory: false)
            AppLog.info(.store, "↩️ [MemoStore] 스냅샷 복원: \(snapshot.memoCount)개 (\(snapshot.timestamp))")
            return true
        } catch {
            AppLog.error(.store, "❌ [MemoStore] 스냅샷 복원 실패: \(error)")
            return false
        }
    }
}

/// 메모 전체 상태 스냅샷(타임머신 1개 지점).
struct MemoSnapshot: Codable, Identifiable {
    var id: UUID
    var timestamp: Date
    var memoCount: Int
    var memos: [Memo]
}

// MARK: - 사용 신호

extension Notification.Name {
    /// 문구를 실제로 한 번 썼다(`MemoStore.incrementClipCount` 성공).
    static let memoUsed = Notification.Name("clipkeyboard.memoUsed")
}

enum MemoUsedKey {
    static let memoID = "memoID"
    static let earnedSeconds = "earnedSeconds"
    /// 실제로 클립보드에 들어간 글.
    static let copiedText = "copiedText"
    /// 단축어 제목 · 보안인가 · 그림인가. 받는 쪽이 파일을 다시 읽지 않게 함께 싣는다
    /// (듀오 결과 쪽 `FoldCopiedPane` 이 "방금 복사함"에 쓴다).
    static let title = "title"
    static let isSecure = "isSecure"
    static let isImage = "isImage"
}

// MARK: - KeyboardUsageTracker

/// 키보드/메모 사용 통계 - App Group UserDefaults 기반.
/// - 일일 카운트: `kb.usage.daily.YYYY-MM-DD` (사용자 로컬 자정 기준 자연 초기화)
/// - 평생 절약 시간: `kb.timeSaved.totalSeconds` (Double 누적)
///
/// 메모 사용 시점에 `recordMemoUse(value:)` 호출. 키보드 익스텐션과 메인 앱 모두
/// `MemoStore.incrementClipCount`를 거치므로 양쪽에서 일관되게 집계된다.
enum KeyboardUsageTracker {
    private static let timeSavedKey = "kb.timeSaved.totalSeconds"
    private static let dailyKeyPrefix = "kb.usage.daily."
    // 내역을 나눠 담는다 - 화면이 "왜 이만큼인가"를 펼쳐 보이려면 합계만으로는 안 된다.
    private static let retrievalKey = "kb.timeSaved.retrievalSeconds"
    /// 선택·복사·붙여넣기로 옮겨 담던 시간. (이 조각이 늦게 들어와 예전 기록에는 없다)
    private static let handlingKey = "kb.timeSaved.handlingSeconds"
    private static let typingKey = "kb.timeSaved.typingSeconds"
    private static let verificationKey = "kb.timeSaved.verificationSeconds"
    /// 밑값을 채운 몫. 조각을 다 더해도 `minimumSavedSeconds` 에 못 미칠 때 붙는다.
    /// (이 조각도 늦게 들어와 예전 기록에는 없다)
    private static let baselineKey = "kb.timeSaved.baselineSeconds"
    /// 이 앱을 쓰느라 **든** 시간. 내역을 펼쳤을 때 네 줄의 합에서 이걸 빼야 위의 큰 숫자가 된다.
    /// (오래 안 쌓아 두던 값이라 예전 기록에는 없다 - 그때는 합계에서만 빠져 있었다)
    private static let tapCostKey = "kb.timeSaved.tapCostSeconds"
    private static let kindKeyPrefix = "kb.usage.kind."
    /// 문구별 **마지막으로 쓴 시각**. 잇달아 쓴 것을 가려내는 데만 쓴다.
    /// 창을 벗어난 것은 쓸 때마다 지우므로, 이 사전은 최근 몇 분치보다 커지지 않는다.
    private static let recentUseKey = "kb.timeSaved.recentUse"

    /// 메모 사용을 1건 기록한다.
    ///
    /// 한 곳에서 **네 가지**를 갱신한다 - 일일 카운트, 평생 절약 시간(합계와 내역),
    /// 이득의 갈래별 횟수, 월 원장.
    ///
    /// ⚠️ 넷을 **한 곳에서** 갱신한다. 따로 부르게 두면 어느 하나가 빠진 경로가 생기고,
    ///    그러면 잔고·영수증·기간 합계·내역이 서로 다른 말을 하기 시작한다.
    ///
    /// - Parameters:
    ///   - type: 이 앱이 분류해 둔 값의 종류. **이게 있어야 "찾아오는 시간"을 셀 수 있다.**
    ///           없으면 외워서 치는 글로 보고 치는 시간만 센다.
    ///   - memoID: 월 원장용. 없으면 기간별 집계에서만 빠지고 누적은 그대로 쌓인다.
    ///     **잇달아 쓴 것을 가려내는 데도 쓴다** - 무엇을 썼는지 알아야 방금 그것인지 안다.
    static func recordMemoUse(value: String,
                              type: ClipboardItemType? = nil,
                              memoID: UUID? = nil,
                              on date: Date = Date()) {
        guard let defaults = AppGroup.defaults else { return }
        let key = dailyKey(for: date)
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)

        // 방금 쓴 것을 또 쓴 것이면 찾아오는 값을 다시 물리지 않는다.
        // ⚠️ 판별과 동시에 시각을 갱신한다 - 나눠 두면 한쪽만 부르는 경로가 생긴다.
        let isRepeat = markUseAndCheckRepeat(memoID: memoID, at: date, defaults: defaults)
        let parts = TimeSavedModel.breakdown(value: value, type: type, isRepeat: isRepeat)

        // ⚠️ 순이득이 0인 사용은 **조각도 쌓지 않는다.** 합계에는 안 들어가는데 내역만 늘면
        //    "이렇게 셌어요" 의 줄들이 위의 큰 숫자보다 커진다. 셈을 펼쳐 보이려고 만든
        //    자리가 셈이 안 맞는다고 말하게 되는 것이다.
        if parts.total > 0 {
            defaults.set(defaults.double(forKey: timeSavedKey) + parts.total, forKey: timeSavedKey)
            defaults.set(defaults.double(forKey: retrievalKey) + parts.retrieval, forKey: retrievalKey)
            defaults.set(defaults.double(forKey: handlingKey) + parts.handling, forKey: handlingKey)
            defaults.set(defaults.double(forKey: typingKey) + parts.typing, forKey: typingKey)
            defaults.set(defaults.double(forKey: verificationKey) + parts.verification, forKey: verificationKey)
            defaults.set(defaults.double(forKey: baselineKey) + parts.baseline, forKey: baselineKey)
            defaults.set(defaults.double(forKey: tapCostKey) + parts.tapCost, forKey: tapCostKey)
        }

        let kind = TimeSavedModel.kind(value: value, type: type)
        let kindKey = kindKeyPrefix + kind.rawValue
        defaults.set(defaults.integer(forKey: kindKey) + 1, forKey: kindKey)

        if let memoID {
            RefundLedger.record(memoID: memoID, seconds: parts.total, on: date)
        }
    }

    /// 이 문구를 **방금 전에도** 썼는지 보고, 마지막으로 쓴 시각을 새로 적는다.
    ///
    /// ⚠️ 무엇을 썼는지 모르면(memoID 가 없으면) 판별할 수 없다. 그때는 "처음 쓴 것"으로 본다
    ///    - 모르는 것을 반복이라고 우겨 깎으면 그건 다른 방향의 거짓말이다.
    ///
    /// ⚠️ 사전은 **창 안에 든 것만** 남긴다. 이 경로는 키보드 익스텐션(메모리 60MB)에서도
    ///    돌기 때문에, 문구 수만큼 불어나는 사전을 매번 읽게 두면 안 된다.
    private static func markUseAndCheckRepeat(memoID: UUID?,
                                              at date: Date,
                                              defaults: UserDefaults) -> Bool {
        guard let memoID else { return false }

        let now = date.timeIntervalSince1970
        let window = TimeSavedModel.repeatWindowSeconds
        let raw = defaults.dictionary(forKey: recentUseKey) as? [String: Double] ?? [:]
        // 기기 시각이 뒤로 간 경우(음수)도 걸러 낸다 - 미래에 쓴 것으로 남은 값은 못 믿는다.
        var recent = raw.filter { (0..<window).contains(now - $0.value) }

        let key = memoID.uuidString
        let repeated = recent[key] != nil
        recent[key] = now
        defaults.set(recent, forKey: recentUseKey)
        return repeated
    }

    /// 문구 하나가 지금까지 돌려준 시간(초).
    ///
    /// ⚠️ **누적과 같은 식이어야 한다.** 카드에 쌓인 동전, 영수증의 줄 금액, 잔고 합계가
    ///    각자 계산하면 서로 안 맞고, 그러면 셋 중 둘은 거짓말이 된다.
    ///    그래서 전부 `TimeSavedModel` 하나만 거친다.
    static func earnedSeconds(value: String, type: ClipboardItemType?, useCount: Int) -> Double {
        TimeSavedModel.breakdown(value: value, type: type, useCount: useCount).total
    }

    /// 값의 종류를 모르는 자리에서 쓰는 예전 창구.
    ///
    /// ⚠️ 종류를 모르면 **찾아오는 시간을 셀 수 없다.** 그래서 이 창구로 계산한 값은
    ///    실제보다 작게 나온다. 메모를 들고 있는 자리라면 위의 `earnedSeconds(value:type:useCount:)`
    ///    를 쓸 것. 이건 글자수밖에 없는 옛 호출부를 위해 남겨 둔다.
    static func earnedSeconds(characterCount: Int, useCount: Int) -> Double {
        guard useCount > 0, characterCount >= TimeSavedModel.minimumCharacters else { return 0 }
        let perUse = max(0, Double(characterCount) / TimeSavedModel.proseCharsPerSecond
                            - TimeSavedModel.tapCostSeconds)
        return perUse * Double(useCount)
    }

    /// 특정 날짜의 사용 횟수 (기본: 오늘)
    static func dailyUsageCount(for date: Date = Date()) -> Int {
        AppGroup.defaults?.integer(forKey: dailyKey(for: date)) ?? 0
    }

    /// 평생 누적 절약 시간 (초)
    static func totalTimeSavedSeconds() -> Double {
        AppGroup.defaults?.double(forKey: timeSavedKey) ?? 0
    }

    /// 누적 절약 시간의 **내역**. 사용 기록 화면이 "왜 이만큼인가"를 펼치는 데 쓴다.
    ///
    /// ⚠️ 이 모델이 들어오기 전에 쌓인 시간은 내역이 없다(합계에만 들어 있다).
    ///    그래서 조각의 합은 합계보다 **작을 수 있다.** 화면은 이걸 알고 그려야 한다.
    ///
    /// ⚠️ 뺀 값(`tapCost`)도 함께 돌려준다. 예전에는 0을 넣어 두고 화면에는 안 보여줬는데,
    ///    그러면 펼친 줄들의 합이 위의 큰 숫자보다 **늘 커서** 셈이 안 맞았다.
    ///    내역은 자랑이 아니라 근거라, 뺀 것도 적혀 있어야 근거가 된다.
    static func savedBreakdown() -> TimeSavedModel.Breakdown {
        guard let d = AppGroup.defaults else { return .zero }
        return TimeSavedModel.Breakdown(retrieval: d.double(forKey: retrievalKey),
                                        handling: d.double(forKey: handlingKey),
                                        typing: d.double(forKey: typingKey),
                                        verification: d.double(forKey: verificationKey),
                                        baseline: d.double(forKey: baselineKey),
                                        tapCost: d.double(forKey: tapCostKey))
    }

    /// 이득의 갈래별 사용 횟수.
    static func useCount(of kind: TimeSavedModel.Kind) -> Int {
        AppGroup.defaults?.integer(forKey: kindKeyPrefix + kind.rawValue) ?? 0
    }

    private static func dailyKey(for date: Date) -> String {
        dailyKeyPrefix + LedgerDateFormat.string(date, "yyyy-MM-dd")
    }
}

// MARK: - 장부 날짜 키

/// 장부 키에 쓰는 날짜 글자(`yyyy-MM-dd` · `yyyy-MM`). 달력과 로캘을 고정한다.
///
/// ⚠️ 포맷터를 부를 때마다 만들지 않는다. 넣을 때마다 서너 개씩 새로 만들고 있었다.
///    시간대는 부를 때마다 지금 것으로 맞춘다 - 여행 중에도 "오늘" 이 맞아야 한다.
enum LedgerDateFormat {
    private static let lock = NSLock()
    private static var formatters: [String: DateFormatter] = [:]

    static func string(_ date: Date, _ format: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        let formatter: DateFormatter
        if let cached = formatters[format] {
            formatter = cached
        } else {
            formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            formatters[format] = formatter
        }
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
