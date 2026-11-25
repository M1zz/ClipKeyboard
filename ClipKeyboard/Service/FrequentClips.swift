//
//  FrequentClips.swift
//  ClipKeyboard / ClipKeyboardExtension
//
//  **'최근' 에서 같은 글을 여러 번 넣었다면, 그 글은 단축어가 되고 싶은 것이다.**
//
//  키보드 '최근' 탭의 글은 30일 뒤 사라진다(`SmartClipboardHistory.retentionDays`).
//  그런데 같은 글을 거기서 몇 번이고 꺼내 쓰는 사람은, 사라지면 안 되는 글을 임시 그릇에 두고 있다.
//  그래서 같은 글을 `threshold` 번 넣으면 판 위에 "단축어로 저장할까요?" 를 한 번 묻는다.
//  저장하거나 닫으면 그 글로는 다시 묻지 않는다.
//
//  ⚠️ 기록에 글을 남기지 않는다. 글의 지문(SHA256 앞 8바이트)만 센다. 카드번호를 넣었어도
//     설정 파일에는 그 번호가 남지 않는다.
//  ⚠️ 판정은 순수 함수다(`FrequentClipsTests`). 키보드는 세고(`recordingUse`) 묻기만(`suggestion`) 한다.
//

import Foundation
import CryptoKit

enum FrequentClips {

    /// 이만큼 넣으면 묻는다. 두 번은 우연일 수 있고, 세 번이면 버릇이다.
    static let threshold = 3
    /// 세어 두는 글의 수 상한. 넘치면 가장 덜 쓴 것부터 버린다(설정 파일이 끝없이 자라지 않게).
    static let capacity = 200

    /// 센 것과 이미 답을 들은 것.
    struct Ledger: Codable, Equatable {
        /// 지문 → 넣은 횟수.
        var counts: [String: Int] = [:]
        /// 저장했거나 닫은 글의 지문. 다시 묻지 않는다.
        var settled: Set<String> = []
    }

    // MARK: - 지문

    /// 앞뒤 빈칸을 빼고 잰다. 끝에 줄바꿈이 붙어 복사된 같은 글을 다른 글로 세지 않게.
    static func fingerprint(_ text: String) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return SHA256.hash(data: Data(normalized.utf8)).prefix(8)
            .map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - 세기

    /// `text` 를 한 번 넣었다.
    static func recordingUse(of text: String, in ledger: Ledger) -> Ledger {
        let key = fingerprint(text)
        guard !ledger.settled.contains(key) else { return ledger }
        var next = ledger
        next.counts[key, default: 0] += 1
        if next.counts.count > capacity,
           let weakest = next.counts.filter({ $0.key != key }).min(by: { $0.value < $1.value })?.key {
            next.counts[weakest] = nil
        }
        return next
    }

    /// 물었고 답을 들었다(저장했든 닫았든). 그 글로는 다시 묻지 않는다.
    static func settling(_ text: String, in ledger: Ledger) -> Ledger {
        let key = fingerprint(text)
        var next = ledger
        next.counts[key] = nil
        next.settled.insert(key)
        return next
    }

    // MARK: - 판정

    /// 물을 글. `threshold` 번 넘게 넣었고, 아직 답을 듣지 않았고, 이미 단축어가 아닌 것.
    /// 여럿이면 가장 많이 넣은 것, 같으면 최근에 복사한 것(목록에서 앞선 것).
    ///
    /// - Parameter savedValues: 지금 있는 단축어의 내용. 이미 단축어인 글은 묻지 않는다.
    static func suggestion(among clips: [SmartClipboardHistory],
                           ledger: Ledger,
                           savedValues: Set<String>) -> SmartClipboardHistory? {
        let saved = Set(savedValues.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        var best: (clip: SmartClipboardHistory, count: Int)?
        for clip in clips where clip.contentType == .text {
            let key = fingerprint(clip.content)
            guard !ledger.settled.contains(key),
                  let count = ledger.counts[key], count >= threshold,
                  !saved.contains(clip.content.trimmingCharacters(in: .whitespacesAndNewlines)) else { continue }
            if count > (best?.count ?? 0) { best = (clip, count) }
        }
        return best?.clip
    }

    // MARK: - 저장

    static func load(from defaults: UserDefaults?) -> Ledger {
        guard let data = defaults?.data(forKey: DefaultsKey.keyboardFrequentClips),
              let ledger = try? JSONDecoder().decode(Ledger.self, from: data) else { return Ledger() }
        return ledger
    }

    static func save(_ ledger: Ledger, to defaults: UserDefaults?) {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        defaults?.set(data, forKey: DefaultsKey.keyboardFrequentClips)
    }
}
