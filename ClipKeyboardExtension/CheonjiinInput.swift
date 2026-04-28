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

    /// proxy로 직접 삽입한 임시 raw 글자 수 (단독 ㆍ 등). 다음 stroke 도착 시 deleteBackward로 정리.
    private var tentativeRawCount: Int = 0

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
        cleanupTentative()
        composer?.commit()
        reset()
    }

    /// proxy로 직접 삽입한 임시 raw 글자 제거
    private func cleanupTentative() {
        for _ in 0..<tentativeRawCount {
            composer?.proxy?.deleteBackward()
        }
        tentativeRawCount = 0
    }

    /// 백스페이스 — 진행 중인 cycle/stroke를 되돌리거나 composer에 위임
    func backspace() {
        if tentativeRawCount > 0 {
            // 임시 raw 표시 중 — 마지막 raw + 마지막 stroke 제거 (state 정합)
            composer?.proxy?.deleteBackward()
            tentativeRawCount -= 1
            if !vowelStrokes.isEmpty { vowelStrokes.removeLast() }
            return
        }
        if !vowelStrokes.isEmpty {
            // 합성된 모음 stroke 진행 중 — 마지막 stroke 취소 + 남은 stroke 재렌더
            vowelStrokes.removeLast()
            composer?.backspace()
            if !vowelStrokes.isEmpty {
                renderRemainingVowelStrokes()
            }
            return
        }
        if lastConsonantKey != nil {
            // 자음 한 글자 완전 제거 (iOS 네이티브 천지인 동작과 일치 — cycle back이 아님)
            composer?.backspace()
            lastConsonantKey = nil
            lastTapTime = nil
            consonantTapIndex = 0
            return
        }
        // 진행 중인 게 없으면 composer에 위임 (이전 syllable 분해 또는 host 삭제)
        composer?.backspace()
    }

    /// 백스페이스 후 남은 vowelStrokes를 적절하게 재렌더 — 합성/prefix+tentative/all-tentative
    private func renderRemainingVowelStrokes() {
        let strokeStr = String(vowelStrokes)
        if let vowel = Self.vowelStrokeMap[strokeStr] {
            composer?.input(vowel)
            return
        }
        // strokeStr가 어떤 key의 prefix 인 경우 (단독 ㆍ 등) — 전부 tentative
        let canExtend = Self.vowelStrokeMap.keys.contains(where: { $0.hasPrefix(strokeStr) })
        let prefixMatches = Self.vowelStrokeMap.filter { strokeStr.hasPrefix($0.key) }

        if let bestMatch = prefixMatches.max(by: { $0.key.count < $1.key.count }) {
            // 일부는 합성 가능, 나머지는 tentative
            composer?.input(bestMatch.value)
            for ch in strokeStr.dropFirst(bestMatch.key.count) {
                composer?.proxy?.insertText(String(ch))
                tentativeRawCount += 1
            }
        } else if canExtend {
            // 전부 tentative
            for ch in vowelStrokes {
                composer?.proxy?.insertText(String(ch))
                tentativeRawCount += 1
            }
        } else {
            // 매치도 prefix도 없음 — fallback
            for ch in vowelStrokes {
                composer?.input(ch)
            }
        }
    }

    func reset() {
        lastConsonantKey = nil
        lastTapTime = nil
        consonantTapIndex = 0
        vowelStrokes.removeAll()
        lastVowelStrokeTime = nil
        tentativeRawCount = 0
    }

    // MARK: - Handlers

    private func handleConsonant(key: String, cycle: [Character]) {
        // 임시 raw 모음(ㆍ 등) 정리 — 미완성 모음은 자음 입력 시 폐기
        cleanupTentative()
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
        // timeout 체크 — 지났으면 새 stroke sequence 시작 (임시 raw도 정리)
        if let last = lastVowelStrokeTime, now.timeIntervalSince(last) > vowelTimeout {
            cleanupTentative()
            vowelStrokes.removeAll()
        }
        lastVowelStrokeTime = now

        vowelStrokes.append(stroke)
        let strokeStr = String(vowelStrokes)

        // 이전 표시 정리 — 임시 raw가 있으면 raw 삭제, 없으면 composer로 합성된 모음 backspace
        let undoPrevious: () -> Void = { [weak self] in
            guard let self = self else { return }
            if self.tentativeRawCount > 0 {
                self.cleanupTentative()
            } else if self.vowelStrokes.count > 1 {
                self.composer?.backspace()
            }
        }

        if let vowel = Self.vowelStrokeMap[strokeStr] {
            // 정확 매치 — 이전 표시 정리 후 합성된 모음 input
            undoPrevious()
            composer?.input(vowel)
            return
        }

        // 가장 긴 prefix 매치 (strokeStr이 key로 시작) — 예: "ㅣㆍㆍㅣ" → 가장 긴 prefix = "ㅣㆍㆍ"=ㅑ
        let prefixMatches = Self.vowelStrokeMap.filter { strokeStr.hasPrefix($0.key) }
        if let bestMatch = prefixMatches.max(by: { $0.key.count < $1.key.count }) {
            let remaining = String(strokeStr.dropFirst(bestMatch.key.count))
            undoPrevious()
            composer?.input(bestMatch.value)
            for ch in remaining {
                composer?.input(ch)
            }
            return
        }

        // strokeStr이 다른 key의 prefix가 되는지 (예: 단독 ㆍ → ㆍㅡ, ㆍㅣ 등의 prefix)
        // 그렇다면 syllable 합성하지 말고 proxy로 raw 임시 삽입 — 다음 stroke에서 정리.
        let canExtend = Self.vowelStrokeMap.keys.contains(where: { $0.hasPrefix(strokeStr) })
        if canExtend {
            composer?.proxy?.insertText(String(stroke))
            tentativeRawCount += 1
        } else {
            // 어떤 매치도 불가능 — composer에 raw input (commitAndReset + insertText)
            composer?.input(stroke)
        }
    }
}
