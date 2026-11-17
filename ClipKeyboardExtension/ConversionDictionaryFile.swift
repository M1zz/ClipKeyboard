//
//  ConversionDictionaryFile.swift
//  ClipKeyboardExtension
//
//  읽기(병음 · 주음) → 한자 사전 파일을 읽는다. 파일은 `scripts/make_typing_dictionary.py` 가 만든다.
//
//  ⚠️ 파일을 메모리에 올리지 않는다. 메모리 매핑으로 열고 이분 탐색으로 필요한 곳만 읽는다.
//     키보드 확장은 메모리 한도가 작다(`docs/engineering/TYPING_KEYBOARD.md` 4단계).
//

import Foundation

// MARK: - 사용자가 고른 낱말

/// 고른 낱말을 읽기별로 기억한다. 다음에 같은 읽기를 치면 앞에 세운다.
/// 기기 안(App Group UserDefaults)에만 남는다.
final class LearnedConversions {
    private let defaults: UserDefaults?
    private let key: String
    private var words: [String: [String]] = [:]
    private var order: [String] = []

    static let maxReadings = 400
    static let maxWordsPerReading = 3

    init(defaults: UserDefaults?, key: String) {
        self.defaults = defaults
        self.key = key
        guard let saved = defaults?.dictionary(forKey: key) else { return }
        words = saved["words"] as? [String: [String]] ?? [:]
        order = (saved["order"] as? [String] ?? []).filter { words[$0] != nil }
    }

    func words(for reading: String) -> [String] { words[reading] ?? [] }

    func note(_ word: String, for reading: String) {
        guard !word.isEmpty, !reading.isEmpty else { return }
        var list = words[reading] ?? []
        list.removeAll { $0 == word }
        list.insert(word, at: 0)
        words[reading] = Array(list.prefix(Self.maxWordsPerReading))
        order.removeAll { $0 == reading }
        order.append(reading)
        while order.count > Self.maxReadings {
            words[order.removeFirst()] = nil
        }
        defaults?.set(["words": words, "order": order], forKey: key)
    }
}

// MARK: - 사전 파일

final class MappedConversionDictionary: ConversionDictionary {
    private let data: Data
    private let keyCount: Int
    private let learned: LearnedConversions?

    private static let magic = Array("CKDICT1\0".utf8)
    private static let headerSize = 12
    /// 한 번에 보는 읽기 길이. 이보다 길면 앞부분만 바꾼다.
    private static let maxReadingLength = 48
    /// 낱말 하나의 읽기가 이보다 길 수는 없다(8글자 × 병음 6자).
    private static let maxWordReadingLength = 48
    /// 앞부분이 같은 읽기를 훑는 한도. "n" 하나로 수천 개가 걸린다.
    private static let completionScanLimit = 3_000

    init?(url: URL, learned: LearnedConversions? = nil) {
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped),
              data.count >= Self.headerSize,
              Array(data.prefix(8)) == Self.magic else { return nil }
        let count = data.withUnsafeBytes { Int(UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: 8, as: UInt32.self))) }
        guard Self.headerSize + count * 4 <= data.count else { return nil }
        self.data = data
        self.keyCount = count
        self.learned = learned
    }

    // MARK: - ConversionDictionary

    func candidates(for reading: String, limit: Int) -> [String] {
        matches(for: reading, limit: limit).map(\.text)
    }

    func noteChosen(_ word: String, for reading: String) {
        learned?.note(word, for: reading)
    }

    func matches(for reading: String, limit: Int) -> [ConversionMatch] {
        let chars = Array(reading.prefix(Self.maxReadingLength))
        guard !chars.isEmpty, limit > 0 else { return [] }

        // 글자 자리 → 바이트 자리. 주음 기호는 한 글자가 3바이트다.
        var bytes: [UInt8] = []
        var starts: [Int] = [0]
        for ch in chars {
            bytes.append(contentsOf: String(ch).utf8)
            starts.append(bytes.count)
        }
        let count = chars.count

        return data.withUnsafeBytes { raw -> [ConversionMatch] in
            let file = FileReader(raw: raw, keyCount: keyCount)
            var out: [ConversionMatch] = []
            var seen = Set<String>()
            func add(_ text: String, _ consumed: Int) {
                guard out.count < limit, seen.insert(text).inserted else { return }
                out.append(ConversionMatch(text: text, consumed: consumed))
            }

            // 1. 전에 고른 것.
            for word in learned?.words(for: String(chars)) ?? [] { add(word, count) }

            // 2. 읽기 전체와 같은 낱말, 읽기로 시작하는 낱말(덜 친 낱말).
            let whole = bytes[...]
            let exact = file.words(for: whole, limit: limit)
            let longer = file.completions(of: whole, limit: 10, scanLimit: Self.completionScanLimit)
            if exact.isEmpty, longer.isEmpty, count > 1,
               let sentence = sentence(file: file, bytes: bytes, starts: starts) {
                // 3. 통째로는 없는 긴 읽기. 낱말로 잘라 이은 한 줄을 맨 앞에 세운다.
                add(sentence, count)
            }
            // 덜 친 낱말은 조금 뒤로 민다(같은 무게면 다 친 낱말이 앞).
            let merged = (exact.map { ($0.text, $0.weight) } + longer.map { ($0.text, $0.weight - 15) })
                .sorted { $0.1 > $1.1 }
            for (text, _) in merged { add(text, count) }
            if !exact.isEmpty || !longer.isEmpty, count > 1, out.count < limit,
               let sentence = sentence(file: file, bytes: bytes, starts: starts) {
                add(sentence, count)
            }

            // 4. 앞부분만 바꾸는 후보. 긴 것부터, 고르면 나머지 읽기는 남는다.
            var length = count - 1
            while length >= 1, out.count < limit {
                let part = bytes[0..<starts[length]]
                let partKey = String(chars[0..<length])
                for word in learned?.words(for: partKey) ?? [] { add(word, length) }
                for word in file.words(for: part, limit: limit) { add(word.text, length) }
                length -= 1
            }
            return out
        }
    }

    // MARK: - 긴 읽기를 낱말로 자르기

    /// 읽기를 낱말로 잘라 가장 그럴듯한 한 줄을 낸다. 마지막 낱말은 덜 쳤어도 된다.
    /// 자를 수 없으면 nil.
    private func sentence(file: FileReader, bytes: [UInt8], starts: [Int]) -> String? {
        let count = starts.count - 1
        // best[i]: 앞의 i 글자를 바꾸는 가장 싼 길.
        var cost = [Int](repeating: .max, count: count + 1)
        var text = [String](repeating: "", count: count + 1)
        var words = [Int](repeating: 0, count: count + 1)
        cost[0] = 0

        for from in 0..<count where cost[from] != .max {
            var to = from + 1
            while to <= count, to - from <= Self.maxWordReadingLength {
                let part = bytes[starts[from]..<starts[to]]
                let index = file.lowerBound(part)
                // 이 앞부분으로 시작하는 읽기가 하나도 없으면 더 길게 봐도 없다.
                guard file.key(at: index, hasPrefix: part) else { break }
                if file.key(at: index, equals: part), let top = file.words(at: index, limit: 1).first {
                    relax(from: from, to: to, word: top.text, edge: 300 - top.weight,
                          cost: &cost, text: &text, words: &words)
                } else if to == count,
                          let top = file.completions(of: part, limit: 1, scanLimit: 400).first {
                    relax(from: from, to: to, word: top.text, edge: 340 - top.weight,
                          cost: &cost, text: &text, words: &words)
                }
                to += 1
            }
        }
        guard cost[count] != .max, words[count] > 1 else { return nil }
        return text[count]
    }

    private func relax(from: Int, to: Int, word: String, edge: Int,
                       cost: inout [Int], text: inout [String], words: inout [Int]) {
        let next = cost[from] + edge
        guard next < cost[to] else { return }
        cost[to] = next
        text[to] = text[from] + word
        words[to] = words[from] + 1
    }
}

// MARK: - 파일 읽기

/// 매핑된 파일을 읽는 손. 범위를 벗어난 자리는 읽지 않는다(깨진 파일에 죽지 않는다).
private struct FileReader {
    let raw: UnsafeRawBufferPointer
    let keyCount: Int

    struct Word {
        let text: String
        let weight: Int
    }

    private func recordOffset(_ index: Int) -> Int? {
        guard index >= 0, index < keyCount else { return nil }
        let at = 12 + index * 4
        guard at + 4 <= raw.count else { return nil }
        return Int(UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: at, as: UInt32.self)))
    }

    private func keyRange(_ index: Int) -> Range<Int>? {
        guard let offset = recordOffset(index), offset < raw.count else { return nil }
        let start = offset + 1
        let end = start + Int(raw[offset])
        guard end <= raw.count else { return nil }
        return start..<end
    }

    /// key(index) 와 query 를 바이트 순으로 견준다. 음수면 key 가 앞.
    private func compare(_ index: Int, _ query: ArraySlice<UInt8>) -> Int {
        guard let range = keyRange(index) else { return 1 }
        var at = range.lowerBound
        for byte in query {
            if at >= range.upperBound { return -1 }
            let own = raw[at]
            if own != byte { return own < byte ? -1 : 1 }
            at += 1
        }
        return at < range.upperBound ? 1 : 0
    }

    /// query 보다 앞서지 않는 첫 key 의 자리.
    func lowerBound(_ query: ArraySlice<UInt8>) -> Int {
        var low = 0
        var high = keyCount
        while low < high {
            let mid = (low + high) / 2
            if compare(mid, query) < 0 { low = mid + 1 } else { high = mid }
        }
        return low
    }

    func key(at index: Int, equals query: ArraySlice<UInt8>) -> Bool {
        index < keyCount && compare(index, query) == 0
    }

    func key(at index: Int, hasPrefix query: ArraySlice<UInt8>) -> Bool {
        guard let range = keyRange(index), range.count >= query.count else { return false }
        var at = range.lowerBound
        for byte in query {
            if raw[at] != byte { return false }
            at += 1
        }
        return true
    }

    func words(at index: Int, limit: Int) -> [Word] {
        guard let range = keyRange(index), range.upperBound + 2 <= raw.count else { return [] }
        let size = Int(raw[range.upperBound]) | Int(raw[range.upperBound + 1]) << 8
        var at = range.upperBound + 2
        let end = min(at + size, raw.count)
        var out: [Word] = []
        while at + 2 <= end, out.count < limit {
            let weight = Int(raw[at])
            let length = Int(raw[at + 1])
            at += 2
            guard at + length <= end else { break }
            let text = String(decoding: UnsafeRawBufferPointer(rebasing: raw[at..<(at + length)]), as: UTF8.self)
            out.append(Word(text: text, weight: weight))
            at += length
        }
        return out
    }

    private func topWeight(at index: Int) -> Int {
        guard let range = keyRange(index), range.upperBound + 3 <= raw.count else { return 0 }
        return Int(raw[range.upperBound + 2])
    }

    func words(for query: ArraySlice<UInt8>, limit: Int) -> [Word] {
        let index = lowerBound(query)
        return key(at: index, equals: query) ? words(at: index, limit: limit) : []
    }

    /// query 로 시작하지만 더 긴 읽기들의 첫 낱말. 무게 큰 것부터 `limit` 개.
    func completions(of query: ArraySlice<UInt8>, limit: Int, scanLimit: Int) -> [Word] {
        var index = lowerBound(query)
        if key(at: index, equals: query) { index += 1 }
        var best: [Word] = []
        var scanned = 0
        while scanned < scanLimit, key(at: index, hasPrefix: query) {
            // 무게만 먼저 본다. 안 들어갈 낱말은 글로 풀지 않는다.
            if best.count < limit || topWeight(at: index) > (best.last?.weight ?? 0),
               let top = words(at: index, limit: 1).first {
                let slot = best.firstIndex { $0.weight < top.weight } ?? best.count
                best.insert(top, at: slot)
                if best.count > limit { best.removeLast() }
            }
            index += 1
            scanned += 1
        }
        return best
    }
}
