//
//  CheonjiinInput.swift
//  ClipKeyboardExtension
//
//  천지인 (3x3+) 입력 처리. 자음 multi-tap 사이클 + 모음 stroke 결합.
//  HangulComposer를 통해 syllable 합성.
//

import Foundation

final class CheonjiinInput {

    /// 강한 참조 — TypingKeyboardView가 @State로 hangulComposer를 보유하므로 cycle 없음.
    var composer: HangulComposer?

    // MARK: - State

    /// 자음 multi-tap 추적
    private var lastConsonantKey: String?
    private var lastTapTime: Date?
    private var consonantTapIndex: Int = 0
    private let consonantTimeout: TimeInterval = 0.5

    /// 모음 stroke 버퍼 (ㅣ ㆍ ㅡ 시퀀스)
    private var vowelStrokes: [Character] = []
    private var lastVowelStrokeTime: Date?
    private let vowelTimeout: TimeInterval = 0.6

    // MARK: - Tables

    /// 자음 키 → cycle 자모 시퀀스
    private static let consonantCycles: [String: [Character]] = [
        "ㄱㅋ": ["ㄱ", "ㅋ", "ㄲ"],
        "ㄴㄹ": ["ㄴ", "ㄹ"],
        "ㄷㅌ": ["ㄷ", "ㅌ", "ㄸ"],
        "ㅂㅍ": ["ㅂ", "ㅍ", "ㅃ"],
        "ㅅㅎ": ["ㅅ", "ㅎ", "ㅆ"],
        "ㅈㅊ": ["ㅈ", "ㅊ", "ㅉ"],
        "ㅇㅁ": ["ㅇ", "ㅁ"]
    ]

    /// stroke 시퀀스 → 결합된 모음 자모.
    /// 가장 긴 매치 우선. 짧은 prefix 단계에서 부분 매치도 인정.
    private static let vowelStrokeMap: [String: Character] = [
        // 단일
        "ㅣ": "ㅣ",
        "ㅡ": "ㅡ",
        // 기본 결합 (1 stroke)
        "ㅣㆍ": "ㅏ",
        "ㆍㅣ": "ㅓ",
        "ㆍㅡ": "ㅗ",
        "ㅡㆍ": "ㅜ",
        // 2 strokes (야/여/요/유)
        "ㅣㆍㆍ": "ㅑ",
        "ㆍㆍㅣ": "ㅕ",
        "ㆍㆍㅡ": "ㅛ",
        "ㅡㆍㆍ": "ㅠ",
        // 모음 + ㅣ (ㅐ/ㅔ/ㅒ/ㅖ/ㅢ)
        "ㅡㅣ": "ㅢ",
        "ㅣㆍㅣ": "ㅐ",
        "ㆍㅣㅣ": "ㅔ",
        "ㅣㆍㆍㅣ": "ㅒ",
        "ㆍㆍㅣㅣ": "ㅖ"
    ]

    // MARK: - Public API

    /// 천지인 키 탭. consonantCycles에 있으면 자음 multi-tap, 그 외엔 모음 stroke.
    func tap(_ key: String) {
        if let cycle = Self.consonantCycles[key] {
            handleConsonant(key: key, cycle: cycle)
        } else if key == "ㅣ" || key == "ㆍ" || key == "ㅡ" {
            handleVowelStroke(Character(key))
        }
    }

    /// commit — Composer commit + 자체 state reset
    func commit() {
        composer?.commit()
        reset()
    }

    /// 백스페이스 — 현재 진행 중인 cycle/stroke를 한 단계 되돌리거나 composer에 위임
    func backspace() {
        if !vowelStrokes.isEmpty {
            // 모음 stroke 진행 중 — 마지막 stroke 취소
            vowelStrokes.removeLast()
            // composer에서도 한 글자 삭제 (현재 표시된 모음/stroke)
            composer?.backspace()
            // 남은 stroke가 있으면 다시 합성
            if !vowelStrokes.isEmpty {
                let strokeStr = String(vowelStrokes)
                if let vowel = Self.vowelStrokeMap[strokeStr] {
                    composer?.input(vowel)
                } else {
                    // 부분 매치만 — 마지막 stroke 그대로
                    composer?.input(vowelStrokes.last!)
                }
            }
            return
        }
        if lastConsonantKey != nil {
            // 자음 cycle 진행 중 — 한 단계 뒤로
            consonantTapIndex = max(0, consonantTapIndex - 1)
            composer?.backspace()
            if consonantTapIndex >= 0, let cycle = Self.consonantCycles[lastConsonantKey ?? ""] {
                if consonantTapIndex < cycle.count {
                    composer?.input(cycle[consonantTapIndex])
                } else {
                    reset()
                }
            }
            return
        }
        // 진행 중인 게 없으면 composer에 위임
        composer?.backspace()
    }

    func reset() {
        lastConsonantKey = nil
        lastTapTime = nil
        consonantTapIndex = 0
        vowelStrokes.removeAll()
        lastVowelStrokeTime = nil
    }

    // MARK: - Handlers

    private func handleConsonant(key: String, cycle: [Character]) {
        // 모음 진행 중이었으면 commit
        if !vowelStrokes.isEmpty {
            vowelStrokes.removeAll()
            lastVowelStrokeTime = nil
        }

        let now = Date()
        let isCycleContinuation = (lastConsonantKey == key) &&
            (lastTapTime.map { now.timeIntervalSince($0) < consonantTimeout } ?? false)

        if isCycleContinuation {
            // 같은 키 빠르게 재탭 → cycle 한 단계 진행
            consonantTapIndex = (consonantTapIndex + 1) % cycle.count
            composer?.backspace()
            composer?.input(cycle[consonantTapIndex])
        } else {
            // 새 키 또는 timeout 후 — 이전 자음 commit + 새로 시작
            consonantTapIndex = 0
            composer?.input(cycle[0])
        }
        lastConsonantKey = key
        lastTapTime = now
    }

    private func handleVowelStroke(_ stroke: Character) {
        // 자음 cycle 종료
        lastConsonantKey = nil
        lastTapTime = nil
        consonantTapIndex = 0

        let now = Date()
        // timeout 체크 — 지났으면 새 stroke sequence 시작
        if let last = lastVowelStrokeTime, now.timeIntervalSince(last) > vowelTimeout {
            vowelStrokes.removeAll()
        }
        lastVowelStrokeTime = now

        vowelStrokes.append(stroke)
        let strokeStr = String(vowelStrokes)

        if let vowel = Self.vowelStrokeMap[strokeStr] {
            // 정확 매치 — 이전 stroke 결과 지우고 새 모음 입력
            if vowelStrokes.count > 1 {
                composer?.backspace()
            }
            composer?.input(vowel)
        } else {
            // 매치 못 함 — 가장 긴 prefix 매치 찾기
            let prefixMatches = Self.vowelStrokeMap.filter { strokeStr.hasPrefix($0.key) }
            if let bestMatch = prefixMatches.max(by: { $0.key.count < $1.key.count }) {
                // prefix 만큼은 합성된 모음으로, 나머지는 raw stroke로
                let remaining = String(strokeStr.dropFirst(bestMatch.key.count))
                if vowelStrokes.count > 1 {
                    composer?.backspace()
                }
                composer?.input(bestMatch.value)
                for ch in remaining {
                    composer?.input(ch)
                }
                // 버퍼는 그대로 두어 추후 stroke 추가가 가능하도록
            } else {
                // 매치 0 — 그냥 stroke 그대로
                composer?.input(stroke)
            }
        }
    }
}
