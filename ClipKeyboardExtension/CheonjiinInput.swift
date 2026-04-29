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

    /// 직전 vowel-render에서 proxy로 직접 삽입한 raw 글자 수 (단독 ㆍ 등). 다음 stroke 도착 시 cleanup.
    private var prevTentativeRawCount: Int = 0

    /// 직전 vowel-render에서 composer.input으로 합성된 모음 medial이 존재하는지.
    /// true면 다음 stroke 시작 전에 composer.backspace로 medial을 clean state로 복원해야 함.
    private var hasComposedVowel: Bool = false

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

    /// stroke 시퀀스 → 결합된 모음 자모. 정확 매치 우선.
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
        "ㆍㆍㅣㅣ": "ㅖ",
        // 복합 모음 (ㅘ/ㅙ/ㅝ/ㅞ) — ㅗ/ㅜ + ㅏ/ㅓ/ㅐ/ㅔ
        "ㆍㅡㅣㆍ": "ㅘ",
        "ㆍㅡㅣㆍㅣ": "ㅙ",
        "ㅡㆍㆍㅣ": "ㅝ",
        "ㅡㆍㆍㅣㅣ": "ㅞ"
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
        // 미완성 raw stroke만 폐기. composer로 합성된 모음은 syllable에 포함되어 commit됨.
        cleanupTentative()
        composer?.commit()
        reset()
    }

    /// proxy로 직접 삽입한 임시 raw 글자 제거
    private func cleanupTentative() {
        for _ in 0..<prevTentativeRawCount {
            composer?.proxy?.deleteBackward()
        }
        prevTentativeRawCount = 0
    }

    /// 직전 vowel-sequence rendering을 완전히 되돌림 (composer-rendered medial 포함)
    private func clearPreviousRender() {
        cleanupTentative()
        if hasComposedVowel {
            // medial이 사라질 때까지 backspace. 단일 medial이면 1번, 복합 (ㅘ ㅚ 등)이면 2번.
            // safety counter는 무한 루프 방지.
            var safety = 5
            while composer?.medialIsSet == true && safety > 0 {
                composer?.backspace()
                safety -= 1
            }
            hasComposedVowel = false
        }
    }

    /// 백스페이스 — 진행 중인 cycle/stroke를 되돌리거나 composer에 위임
    func backspace() {
        if prevTentativeRawCount > 0 {
            // 임시 raw 표시 중 — 마지막 raw + 마지막 stroke 제거
            composer?.proxy?.deleteBackward()
            prevTentativeRawCount -= 1
            if !vowelStrokes.isEmpty { vowelStrokes.removeLast() }
            return
        }
        if !vowelStrokes.isEmpty {
            // 합성된 모음 stroke 진행 중 — 마지막 stroke 제거 + 남은 stroke 재렌더
            vowelStrokes.removeLast()
            clearPreviousRender()
            if !vowelStrokes.isEmpty {
                renderCurrentStrokes()
            }
            return
        }
        if lastConsonantKey != nil {
            // 자음 한 글자 완전 제거 (iOS 네이티브 천지인 동작과 일치)
            composer?.backspace()
            lastConsonantKey = nil
            lastTapTime = nil
            consonantTapIndex = 0
            return
        }
        composer?.backspace()
    }

    func reset() {
        lastConsonantKey = nil
        lastTapTime = nil
        consonantTapIndex = 0
        vowelStrokes.removeAll()
        lastVowelStrokeTime = nil
        prevTentativeRawCount = 0
        hasComposedVowel = false
    }

    // MARK: - Handlers

    private func handleConsonant(key: String, cycle: [Character]) {
        // 미완성 raw 모음 정리 — composer-rendered 모음은 syllable에 포함되므로 유지.
        cleanupTentative()
        vowelStrokes.removeAll()
        lastVowelStrokeTime = nil
        // 직전 syllable이 medial을 갖고 있어도 그건 유지 (final/migration은 HangulComposer가 처리).
        hasComposedVowel = false

        let now = Date()
        let isCycleContinuation = (lastConsonantKey == key) &&
            (lastTapTime.map { now.timeIntervalSince($0) < consonantTimeout } ?? false)

        if isCycleContinuation {
            // 같은 키 빠르게 재탭 → cycle 한 단계 진행
            consonantTapIndex = (consonantTapIndex + 1) % cycle.count
            composer?.backspace()
            composer?.input(cycle[consonantTapIndex])
        } else {
            // 새 키 또는 timeout 후 — 새로 시작
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
            clearPreviousRender()
            vowelStrokes.removeAll()
        }
        lastVowelStrokeTime = now

        vowelStrokes.append(stroke)
        // 직전 render 완전히 되돌리고 현재 buffer로 새로 렌더 — state 일관성 보장.
        clearPreviousRender()
        renderCurrentStrokes()
    }

    /// 현재 vowelStrokes를 clean state(host에 이전 sequence 흔적 없음)에서 렌더.
    private func renderCurrentStrokes() {
        let strokeStr = String(vowelStrokes)

        // 1) 정확 매치
        if let vowel = Self.vowelStrokeMap[strokeStr] {
            composer?.input(vowel)
            hasComposedVowel = true
            return
        }

        // 2) prefix 매치 (가장 긴) + 나머지 raw
        let prefixMatches = Self.vowelStrokeMap.filter { strokeStr.hasPrefix($0.key) }
        if let bestMatch = prefixMatches.max(by: { $0.key.count < $1.key.count }) {
            composer?.input(bestMatch.value)
            hasComposedVowel = true
            for ch in strokeStr.dropFirst(bestMatch.key.count) {
                composer?.input(ch)
                // composer.input이 medial을 변경하면 hasComposedVowel은 이미 true이므로 OK.
            }
            return
        }

        // 3) strokeStr이 더 긴 key의 prefix → tentative raw로 표시 (다음 stroke 대기)
        let canExtend = Self.vowelStrokeMap.keys.contains(where: { $0.hasPrefix(strokeStr) })
        if canExtend {
            for ch in vowelStrokes {
                composer?.proxy?.insertText(String(ch))
                prevTentativeRawCount += 1
            }
            return
        }

        // 4) 매치 불가 — 마지막 stroke 그대로 commit
        for ch in vowelStrokes {
            composer?.input(ch)
        }
    }
}
