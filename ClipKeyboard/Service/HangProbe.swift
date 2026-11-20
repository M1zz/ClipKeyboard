//
//  HangProbe.swift
//  ClipKeyboard
//
//  메인 스레드가 멈춘 시간을 재는 탐침. **개발 빌드에만 있고, `-HangProbe` 로 켰을 때만 돈다.**
//
//  왜 필요한가: 이 앱을 죽인 사고는 거의 전부 "화면을 끝없이 다시 그리는 고리" 였다
//  (docs/postmortem/LAUNCH_INCOMPLETE_BACKGROUND_WAKE_5_1_24.md 3 · 4절). 로직은 맞고 함수 단위
//  시험은 전부 통과하는데, 한 프레임의 갱신이 몇 초씩 끝나지 않아 워치독이 앱을 끈다.
//  그런 멈춤은 "죽었는가" 로는 못 잡는다. 몽키 시험이 지나간 자리에서도 앱은 살아 있다.
//  그래서 **멈춘 시간 자체**를 잰다.
//
//  어떻게: 뒤쪽 스레드가 메인 스레드에 공을 던지고 돌아올 때까지의 시간을 잰다.
//  `threshold` 를 넘기면 멈춤으로 적고, 돌아오면 얼마나 멈췄는지 적는다.
//  화면이 스스로 세는 다시 그리기 횟수(`noteRender`)도 받아, 1초에 200번을 넘으면 폭주로 적는다.
//
//  쓰는 곳: `ClipKeyboardUITests/ListHangUITests.swift` 가 단축어 수백 개를 깔고 목록을
//  굴리며 이 기록을 읽는다. 기록 파일은 환경 변수 `HANG_PROBE_REPORT` 가 정한다.
//
//  ⚠️ `-HangProbeMemos N` 은 단축어 N개를 **시연 데이터로** 깐다(`DemoDataService.apply`).
//     원래 데이터는 백업되고, `-HangProbeRestore` 로 한 번 켜면 돌아온다(시험이 끝에 그렇게 한다).
//

#if DEBUG
import Foundation

enum HangProbe {

    /// 이보다 오래 메인 스레드가 대답하지 않으면 멈춤이다(초). `HANG_PROBE_THRESHOLD` 로 바꾼다.
    static var threshold: TimeInterval {
        ProcessInfo.processInfo.environment["HANG_PROBE_THRESHOLD"].flatMap(TimeInterval.init) ?? 1.0
    }

    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains("-HangProbe") }

    private static var started = false

    // MARK: - 시작

    /// 앱 `init()` 에서 1회. 켜져 있지 않으면 아무것도 하지 않는다.
    static func startIfRequested() {
        // 시험이 끝나면 깔아 둔 것을 걷고 원래 데이터로 되돌린다(`-HangProbeRestore`).
        if ProcessInfo.processInfo.arguments.contains("-HangProbeRestore") {
            restore()
            return
        }
        guard isOn, !started else { return }
        started = true
        seedIfRequested()

        let thread = Thread { watch() }
        thread.name = "HangProbe"
        thread.qualityOfService = .userInteractive
        thread.start()
        write("probe-start threshold=\(threshold)")
    }

    // MARK: - 재기

    private static let lock = NSLock()
    /// 던진 공이 아직 안 돌아왔으면 던진 시각.
    private static var pendingSince: TimeInterval?
    /// 지금 멈춤을 이미 적었는가.
    private static var reported = false

    private static func watch() {
        while true {
            Thread.sleep(forTimeInterval: 0.05)
            let now = Date().timeIntervalSince1970

            lock.lock()
            if let since = pendingSince {
                if !reported, now - since > threshold {
                    reported = true
                    lock.unlock()
                    // 멈춘 **동안에** 적는다. 밖에서 이 줄을 보고 `sample` 로 스택을 뜰 수 있다.
                    write("hang-start at=\(since)")
                    continue
                }
                lock.unlock()
                continue
            }
            pendingSince = now
            lock.unlock()

            DispatchQueue.main.async {
                let back = Date().timeIntervalSince1970
                lock.lock()
                let since = pendingSince ?? back
                let wasReported = reported
                pendingSince = nil
                reported = false
                lock.unlock()
                if wasReported {
                    let seconds = back - since
                    write("hang-end at=\(since) seconds=\(String(format: "%.2f", seconds))")
                    AppLog.error(.launch, "🧊 [HangProbe] 메인 스레드가 \(String(format: "%.1f", seconds))초 멈췄다")
                }
            }
        }
    }

    // MARK: - 다시 그리기 폭주

    /// 1초에 이만큼 넘게 같은 화면의 몸통이 다시 계산되면 폭주로 적는다.
    /// 손이 끄는 동안 프레임마다 한 번(초당 60~120번)까지는 있을 수 있는 일이다.
    static let stormPerSecond = 200

    private static let isOnCached = isOn
    private static var renderCounts: [String: (windowStart: TimeInterval, count: Int, reported: Bool)] = [:]

    /// 화면의 `body` 맨 앞에서 부른다. 꺼져 있으면 아무 일도 하지 않는다.
    ///
    /// 멈춤으로 번지기 전의 고리를 잡으려는 것이다. 한 프레임이 끝나지 않는 고리는 멈춤으로 잡히지만,
    /// 프레임마다 한 번씩 도는 고리는 앱이 굼뜰 뿐 멈추지 않아 탐침의 공은 제때 돌아온다.
    static func noteRender(_ name: String) {
        guard isOnCached, Thread.isMainThread else { return }
        let now = Date().timeIntervalSince1970
        var entry = renderCounts[name] ?? (now, 0, false)
        if now - entry.windowStart > 1 { entry = (now, 0, false) }
        entry.count += 1
        if entry.count > stormPerSecond, !entry.reported {
            entry.reported = true
            write("render-storm at=\(now) view=\(name)")
            AppLog.error(.launch, "🌀 [HangProbe] '\(name)' 이(가) 1초에 \(stormPerSecond)번 넘게 다시 그려진다")
        }
        renderCounts[name] = entry
    }

    // MARK: - 기록

    private static let writeLock = NSLock()

    private static func write(_ line: String) {
        guard let path = ProcessInfo.processInfo.environment["HANG_PROBE_REPORT"] else { return }
        writeLock.lock()
        defer { writeLock.unlock() }
        let data = Data((line + "\n").utf8)
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            FileManager.default.createFile(atPath: path, contents: data)
        }
    }

    // MARK: - 시험 데이터

    private static let addedCategoriesKey = "HangProbe.addedCategories"
    private static let featureWasOnKey = "HangProbe.categoryFeatureWasOn"

    /// 깔아 둔 단축어 · 카테고리를 걷고 원래 데이터로 되돌린다.
    private static func restore() {
        let defaults = UserDefaults.standard
        guard let added = defaults.stringArray(forKey: addedCategoriesKey) else { return }
        DemoDataService.shared.disable()
        for name in added { _ = CategoryStore.shared.remove(name) }
        if !defaults.bool(forKey: featureWasOnKey) { CategoryStore.shared.disableFeature() }
        defaults.removeObject(forKey: addedCategoriesKey)
        defaults.removeObject(forKey: featureWasOnKey)
        print("🧊 [HangProbe] 시험 데이터를 걷고 원래 데이터로 되돌렸다")
    }

    /// `-HangProbeMemos N` 이면 단축어 N개를 카테고리 다섯에 나눠 깐다.
    /// 멈춤은 단축어가 많은 사람에게서 났다. 여섯 개짜리 시연 데이터로는 안 보인다.
    private static func seedIfRequested() {
        let count = UserDefaults.standard.integer(forKey: "HangProbeMemos")
        guard count > 0 else { return }

        let categories = ["업무", "개인", "여행", "쇼핑", "기타"]
        // 이번에 새로 만든 카테고리와 켜기 전 상태를 적어 둔다. 되돌릴 때 그것만 걷는다.
        if UserDefaults.standard.object(forKey: addedCategoriesKey) == nil {
            let added = categories.filter { CategoryStore.shared.add($0) }
            UserDefaults.standard.set(added, forKey: addedCategoriesKey)
            UserDefaults.standard.set(CategoryStore.shared.isFeatureEnabled, forKey: featureWasOnKey)
        }
        CategoryStore.shared.enableFeature()

        let now = Date()
        let memos: [Memo] = (0..<count).map { i in
            let isTemplate = i % 7 == 3
            var memo = Memo(
                title: "단축어 \(i + 1)",
                value: isTemplate
                    ? "안녕하세요 {이름}님, \(i)번 안내드립니다."
                    : String(repeating: "여러 줄로 넘어가는 긴 내용 \(i). ", count: 1 + i % 4),
                isFavorite: i % 9 == 0,
                category: categories[i % categories.count]
            )
            if isTemplate { memo.templateVariables = ["{이름}"] }
            memo.clipCount = (i * 37) % 50
            memo.lastUsedAt = now.addingTimeInterval(-Double(i) * 1800)
            memo.lastEdited = memo.lastUsedAt ?? now
            return memo
        }
        let ok = DemoDataService.shared.apply(memos: memos, clipboard: [])
        print(ok ? "🧊 [HangProbe] 단축어 \(count)개를 깔았다" : "❌ [HangProbe] 단축어를 깔지 못했다")
    }
}
#endif
