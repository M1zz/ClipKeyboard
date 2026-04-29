//
//  HangulTestRunner.swift
//  Standalone test for HangulComposer + CheonjiinInput.
//  Compile with: swiftc HangulTestRunner.swift HangulComposer.swift CheonjiinInput.swift -o runner
//

import Foundation

// MARK: - Mock proxy

final class MockProxy: HangulInputProxy {
    var buffer: String = ""
    func insertText(_ text: String) { buffer.append(text) }
    func deleteBackward() {
        guard !buffer.isEmpty else { return }
        buffer.removeLast()
    }
}

// MARK: - Test harness

var passed = 0
var failed = 0

func check(_ desc: String, expected: String, actual: String) {
    if actual == expected {
        passed += 1
        print("  ✓ \(desc): \"\(actual)\"")
    } else {
        failed += 1
        print("  ✗ \(desc)")
        print("      expected: \"\(expected)\"")
        print("      actual:   \"\(actual)\"")
    }
}

// MARK: - Dubeolsik tests

func runDubeolsik() {
    print("\n=== Dubeolsik (두벌식) ===")
    let cases: [(String, String, String)] = [
        // (jamo sequence, expected, description)
        ("ㅇㅏㄴㄴㅕㅇ", "안녕", "안녕"),
        ("ㄱㅡㄱ", "극", "극"),
        ("ㄴㅓㅇㅗㅏ", "너와", "너와"),
        ("ㅁㅜㅎㅗㅏㄱㅗㅏ", "무화과", "무화과"),
        ("ㅇㅏㅇㅣㄱㅗ", "아이고", "아이고"),
        ("ㄱㅗㅇㅣㅇㅑㅇㅇㅣ", "고이양이", "고이양이 (sequence)"),
        ("ㅇㅏㄴ", "안", "안"),
        ("ㅇㅏㄴㅏ", "아나", "아나 — final ㄴ migrates"),
        ("ㄱㅓㅂㅅㅗ", "겁소", "겁소 (ㅂ+ㅅ=ㅄ → migrate ㅅ)"),
        ("ㅎㅏㄴㄱㅜㄱㅇㅓ", "한국어", "한국어"),
        ("ㅂㅏㄹㅂㅗㅇㄱㅏ", "발봉가", "발봉가 — multi finals"),
        ("ㅎㅏㄴㄱㅗㄱ", "한곡", "한곡"),
        ("ㄱㅏㄱㅏ", "가가", "가가"),
        ("ㄱㅗㅏㅇ", "광", "광 — direct compound"),
        ("ㄱㅗㅏ", "과", "과"),
        ("ㅎㅗㅏㄱㄱㅗㅏ", "확과", "확과"),
        ("ㅁㅜㅓㅎㅗㅏㄱㅗㅏ", "뭐화과", "뭐화과 (ㅜ+ㅓ=ㅝ)"),
        ("ㅇㅡㅣ", "의", "의 (ㅡ+ㅣ=ㅢ)"),
        ("ㄱㅗㅏㅇㅈㅏㅇ", "광장", "광장"),
        ("ㅎㅏㄴㄱㅜㄱ", "한국", "한국"),
    ]

    for (jamoStr, expected, desc) in cases {
        let proxy = MockProxy()
        let composer = HangulComposer()
        composer.proxy = proxy
        for ch in jamoStr {
            composer.input(ch)
        }
        composer.commit()
        check(desc, expected: expected, actual: proxy.buffer)
    }
}

// MARK: - Cheonjiin tests

final class CheonjiinAdapter: HangulInputProxy {
    let proxy: MockProxy
    init(_ p: MockProxy) { proxy = p }
    func insertText(_ text: String) { proxy.insertText(text) }
    func deleteBackward() { proxy.deleteBackward() }
}

func runCheonjiin() {
    print("\n=== Cheonjiin (천지인) ===")
    // Each test: list of taps, where each tap is one of:
    //   "ㄱㅋ", "ㄴㄹ", "ㄷㅌ", "ㅂㅍ", "ㅅㅎ", "ㅈㅊ", "ㅇㅁ"  (consonant cycles)
    //   "ㅣ", "ㆍ", "ㅡ"  (vowel strokes)
    // Same key tapped twice = cycle. Different key = new key.
    //
    // We add small delays between same-key taps if cycling needed.

    struct CJ {
        let taps: [String]
        let expected: String
        let desc: String
        let cycles: Set<Int>  // indices where same key is consecutive (continuation)
    }

    let cases: [CJ] = [
        // Single syllables
        CJ(taps: ["ㅇㅁ","ㅣ","ㆍ"], expected: "아", desc: "아 (ㅇ + ㅏ)", cycles: []),
        CJ(taps: ["ㅇㅁ","ㅣ"], expected: "이", desc: "이", cycles: []),
        CJ(taps: ["ㅇㅁ","ㅡ"], expected: "으", desc: "으", cycles: []),
        CJ(taps: ["ㄱㅋ","ㅣ"], expected: "기", desc: "기", cycles: []),
        CJ(taps: ["ㄱㅋ","ㆍ","ㅡ"], expected: "고", desc: "고 (ㄱ + ㅗ)", cycles: []),
        // Cycle test: ㅁ via ㅇㅁ-ㅇㅁ
        CJ(taps: ["ㅇㅁ","ㅇㅁ","ㅣ"], expected: "미", desc: "미 (ㅇㅁ cycle to ㅁ + ㅣ)", cycles: [1]),
        CJ(taps: ["ㅇㅁ","ㅇㅁ","ㅡ","ㆍ"], expected: "무", desc: "무 (cycle ㅁ + ㅜ)", cycles: [1]),
        // Compound vowel ㅘ
        CJ(taps: ["ㅇㅁ","ㆍ","ㅡ","ㅣ","ㆍ"], expected: "와", desc: "와 (ㅇ + ㅘ)", cycles: []),
        CJ(taps: ["ㄱㅋ","ㆍ","ㅡ","ㅣ","ㆍ"], expected: "과", desc: "과 (ㄱ + ㅘ)", cycles: []),
        // 너와
        CJ(taps: ["ㄴㄹ","ㆍ","ㅣ","ㅇㅁ","ㆍ","ㅡ","ㅣ","ㆍ"], expected: "너와",
           desc: "너와", cycles: []),
        // 무화과 — uses cycles, complex
        CJ(taps: ["ㅇㅁ","ㅇㅁ","ㅡ","ㆍ",   // 무
                  "ㅅㅎ","ㅅㅎ","ㆍ","ㅡ","ㅣ","ㆍ",  // 화
                  "ㄱㅋ","ㆍ","ㅡ","ㅣ","ㆍ"],   // 과
           expected: "무화과", desc: "무화과 (cycles + ㅘ ㅘ)", cycles: [1, 5]),
        // 안녕 — first ㄴ is final of 안, second ㄴ is initial of 녕 (separate, NOT cycle)
        CJ(taps: ["ㅇㅁ","ㅣ","ㆍ","ㄴㄹ","ㄴㄹ","ㆍ","ㆍ","ㅣ","ㅇㅁ"], expected: "안녕",
           desc: "안녕", cycles: []),
        // ㅑ/ㅕ extension
        CJ(taps: ["ㅇㅁ","ㅣ","ㆍ","ㆍ"], expected: "야", desc: "야 (ㅇ + ㅑ via ㅣㆍㆍ)", cycles: []),
        CJ(taps: ["ㅇㅁ","ㆍ","ㆍ","ㅣ"], expected: "여", desc: "여 (ㅇ + ㅕ via ㆍㆍㅣ)", cycles: []),
        // ㅝ
        CJ(taps: ["ㅇㅁ","ㅡ","ㆍ","ㆍ","ㅣ"], expected: "워", desc: "워 (ㅇ + ㅝ)", cycles: []),
        // 의
        CJ(taps: ["ㅇㅁ","ㅡ","ㅣ"], expected: "의", desc: "의 (ㅇ + ㅢ)", cycles: []),
        // 외 (ㅗ+ㅣ=ㅚ)
        CJ(taps: ["ㅇㅁ","ㆍ","ㅡ","ㅣ"], expected: "외", desc: "외 (ㅇ + ㅚ)", cycles: []),
    ]

    for cj in cases {
        let proxy = MockProxy()
        let composer = HangulComposer()
        composer.proxy = proxy
        let cheon = CheonjiinInput()
        cheon.composer = composer

        let consonantKeys: Set<String> = ["ㄱㅋ","ㄴㄹ","ㄷㅌ","ㅂㅍ","ㅅㅎ","ㅈㅊ","ㅇㅁ"]
        for (i, tap) in cj.taps.enumerated() {
            // Force timeout between same consonant-key taps unless explicitly cycling.
            // Vowel strokes (ㅣ ㆍ ㅡ) NEVER need a wait — they accumulate naturally.
            if i > 0 && cj.taps[i-1] == tap && consonantKeys.contains(tap) && !cj.cycles.contains(i) {
                Thread.sleep(forTimeInterval: 0.6)
            }
            cheon.tap(tap)
        }
        cheon.commit()
        check(cj.desc, expected: cj.expected, actual: proxy.buffer)
    }
}

// MARK: - Run

print("HangulComposer test runner")
print(String(repeating: "=", count: 50))

runDubeolsik()
runCheonjiin()

print("\n\n=== Summary ===")
print("Passed: \(passed)")
print("Failed: \(failed)")
exit(failed == 0 ? 0 : 1)
