//
//  HangulComposer.swift
//  ClipKeyboardExtension
//
//  한국어 자모 입력을 syllable로 결합. textDocumentProxy를 통한 실시간 갱신용.
//  단순 자판 (2벌식) 기준. 복합 자모 일부 지원 (ㅘ ㅙ ㅚ ㅝ ㅞ ㅟ ㅢ / ㄳ ㄵ ㄶ ㄺ ...).
//

import Foundation

/// Hangul 결합 결과를 host textDocumentProxy에 반영하기 위한 인터페이스.
/// proxy.deleteBackward()로 이전 syllable을 지우고 insertText()로 새 syllable을 넣어
/// 사용자가 한 글자씩 자라나는 것을 본다.
protocol HangulInputProxy: AnyObject {
    func insertText(_ text: String)
    func deleteBackward()
}

final class HangulComposer {

    // MARK: - Jamo tables

    private static let initials: [Character] = [
        "ㄱ","ㄲ","ㄴ","ㄷ","ㄸ","ㄹ","ㅁ","ㅂ","ㅃ","ㅅ",
        "ㅆ","ㅇ","ㅈ","ㅉ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ"
    ]
    private static let medials: [Character] = [
        "ㅏ","ㅐ","ㅑ","ㅒ","ㅓ","ㅔ","ㅕ","ㅖ","ㅗ","ㅘ",
        "ㅙ","ㅚ","ㅛ","ㅜ","ㅝ","ㅞ","ㅟ","ㅠ","ㅡ","ㅢ","ㅣ"
    ]
    private static let finals: [Character?] = [
        nil,
        "ㄱ","ㄲ","ㄳ","ㄴ","ㄵ","ㄶ","ㄷ","ㄹ","ㄺ","ㄻ",
        "ㄼ","ㄽ","ㄾ","ㄿ","ㅀ","ㅁ","ㅂ","ㅄ","ㅅ","ㅆ",
        "ㅇ","ㅈ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ"
    ]

    /// 모음 결합 가능 (ㅗ+ㅏ=ㅘ 등)
    private static let medialCombines: [Character: [Character: Character]] = [
        "ㅗ": ["ㅏ":"ㅘ", "ㅐ":"ㅙ", "ㅣ":"ㅚ"],
        "ㅜ": ["ㅓ":"ㅝ", "ㅔ":"ㅞ", "ㅣ":"ㅟ"],
        "ㅡ": ["ㅣ":"ㅢ"]
    ]

    /// 자음 종성 결합 (ㄱ+ㅅ=ㄳ 등) — 종성 한정
    private static let finalCombines: [Character: [Character: Character]] = [
        "ㄱ": ["ㅅ":"ㄳ"],
        "ㄴ": ["ㅈ":"ㄵ", "ㅎ":"ㄶ"],
        "ㄹ": ["ㄱ":"ㄺ", "ㅁ":"ㄻ", "ㅂ":"ㄼ", "ㅅ":"ㄽ", "ㅌ":"ㄾ", "ㅍ":"ㄿ", "ㅎ":"ㅀ"],
        "ㅂ": ["ㅅ":"ㅄ"]
    ]

    /// 결합된 종성을 이전 종성과 새 자모로 분해 (모음 입력 시 종성 일부를 새 syllable의 초성으로 옮길 때)
    private static let finalDecomposeMap: [Character: (Character, Character)] = {
        var dict: [Character: (Character, Character)] = [:]
        for (base, combos) in finalCombines {
            for (added, combined) in combos {
                dict[combined] = (base, added)
            }
        }
        return dict
    }()

    // MARK: - State

    private var initial: Int? = nil
    private var medial: Int? = nil
    private var final: Int? = nil

    /// 강한 참조 — adapter가 임시 인스턴스인 경우가 많아 weak이면 즉시 dealloc된다.
    /// retain cycle 위험 없음 (proxy → KeyboardViewController, controller는 view를 value로만 보유).
    var proxy: HangulInputProxy?

    // MARK: - Public API

    /// 자모 입력 (사용자가 키 누름).
    /// 자음/모음/그 외(영문·숫자·기호)에 따라 처리.
    func input(_ jamo: Character) {
        // 초성·종성 가능한 자음
        if Self.initials.contains(jamo) || Self.finals.contains(where: { $0 == jamo }) {
            handleConsonant(jamo)
        } else if Self.medials.contains(jamo) {
            handleVowel(jamo)
        } else {
            // Hangul jamo가 아닌 문자 (영문·숫자·기호) — 현재 syllable commit 후 그대로 입력
            commitAndReset()
            proxy?.insertText(String(jamo))
        }
    }

    /// 백스페이스 — 컴포지션 중이면 한 단계 되돌리기, 아니면 host에 deleteBackward 전달.
    func backspace() {
        if final != nil {
            // 종성이 결합된 경우 분해 가능한지 확인
            if let f = final, let fChar = Self.finals[f], let (base, _) = Self.finalDecomposeMap[fChar] {
                // 결합 종성 → 베이스 종성으로 축소
                final = Self.finals.firstIndex(of: base)
                rerenderCurrent()
                return
            }
            // 단일 종성 제거
            final = nil
            rerenderCurrent()
            return
        }
        if medial != nil {
            // 복합 모음 분해
            if let m = medial, let mChar = Optional(Self.medials[m]),
               let (base, _) = decomposeMedial(mChar) {
                medial = Self.medials.firstIndex(of: base)
                rerenderCurrent()
                return
            }
            // 단일 중성 제거 (초성만 남김)
            medial = nil
            rerenderCurrent()
            return
        }
        if initial != nil {
            // 초성만 있는 상태 → 비우기
            initial = nil
            // 현재 표시된 초성 자모 한 글자 삭제
            proxy?.deleteBackward()
            return
        }
        // 컴포지션 비어 있음 → host 전달
        proxy?.deleteBackward()
    }

    /// 현재 syllable을 host에 확정. 새 syllable 시작.
    func commit() {
        commitAndReset()
    }

    // MARK: - Private handlers

    private func handleConsonant(_ jamo: Character) {
        // 케이스 1: 컴포지션 비어 있음 → 새 초성
        if initial == nil {
            guard let idx = Self.initials.firstIndex(of: jamo) else {
                proxy?.insertText(String(jamo))
                return
            }
            initial = idx
            renderCurrent(insertNew: true)
            return
        }

        // 케이스 2: 초성만 있음 (medial nil) → 자음 두 개 연속, 첫 자음 commit 후 두 번째 새로
        if medial == nil {
            commitAndReset()
            if let idx = Self.initials.firstIndex(of: jamo) {
                initial = idx
                renderCurrent(insertNew: true)
            } else {
                proxy?.insertText(String(jamo))
            }
            return
        }

        // 케이스 3: 초성+중성 → 종성 추가 시도
        if final == nil {
            if let fIdx = Self.finals.firstIndex(of: jamo) {
                final = fIdx
                rerenderCurrent()
                return
            }
            // 종성 불가 자모 (ㄸ ㅃ ㅉ 등) → commit 후 새 syllable 시작
            commitAndReset()
            if let idx = Self.initials.firstIndex(of: jamo) {
                initial = idx
                renderCurrent(insertNew: true)
            }
            return
        }

        // 케이스 4: 종성 이미 있음 → 결합 시도
        if let f = final, let fChar = Self.finals[f],
           let combos = Self.finalCombines[fChar],
           let combined = combos[jamo],
           let combinedIdx = Self.finals.firstIndex(of: combined) {
            final = combinedIdx
            rerenderCurrent()
            return
        }

        // 결합 안 됨 → 현재 syllable commit, 새 syllable의 초성으로
        commitAndReset()
        if let idx = Self.initials.firstIndex(of: jamo) {
            initial = idx
            renderCurrent(insertNew: true)
        }
    }

    private func handleVowel(_ jamo: Character) {
        // 케이스 1: 컴포지션 비어 있음 → 모음 단독 입력
        if initial == nil {
            // 'ㅇ' 초성으로 자동 보정 (간단히 그냥 모음 한 글자 삽입)
            commitAndReset()
            proxy?.insertText(String(jamo))
            return
        }

        // 케이스 2: 초성만 있음 → 중성 추가
        if medial == nil {
            guard let idx = Self.medials.firstIndex(of: jamo) else {
                proxy?.insertText(String(jamo))
                return
            }
            medial = idx
            rerenderCurrent()
            return
        }

        // 케이스 3: 초성+중성, 종성 없음 → 복합 모음 시도
        if final == nil {
            if let m = medial,
               let mChar = Optional(Self.medials[m]),
               let combos = Self.medialCombines[mChar],
               let combined = combos[jamo],
               let combinedIdx = Self.medials.firstIndex(of: combined) {
                medial = combinedIdx
                rerenderCurrent()
                return
            }
            // 복합 불가 → 새 syllable 시작 (ㅇ 초성 + 새 중성)
            commitAndReset()
            if let oIdx = Self.initials.firstIndex(of: "ㅇ"),
               let mIdx = Self.medials.firstIndex(of: jamo) {
                initial = oIdx
                medial = mIdx
                renderCurrent(insertNew: true)
            }
            return
        }

        // 케이스 4: 초성+중성+종성 + 모음 → 종성 일부를 새 syllable의 초성으로
        // 예: "안" + "ㅏ" → "아나"
        guard let f = final, let fChar = Self.finals[f] else { return }

        // 결합 종성이면 마지막 자모만 떼어 새 초성으로
        let movingConsonant: Character
        let remainingFinalIdx: Int?
        if let (base, last) = Self.finalDecomposeMap[fChar] {
            remainingFinalIdx = Self.finals.firstIndex(of: base)
            movingConsonant = last
        } else {
            remainingFinalIdx = nil  // 종성 제거
            movingConsonant = fChar
        }
        final = remainingFinalIdx
        rerenderCurrent()
        commitAndReset()

        // 새 syllable 시작
        if let initIdx = Self.initials.firstIndex(of: movingConsonant),
           let medIdx = Self.medials.firstIndex(of: jamo) {
            initial = initIdx
            medial = medIdx
            renderCurrent(insertNew: true)
        }
    }

    // MARK: - Render & utility

    private var currentSyllable: String {
        guard let i = initial else { return "" }
        guard let m = medial else { return String(Self.initials[i]) }
        let f = final ?? 0
        let scalar = 0xAC00 + (i * 21 * 28) + (m * 28) + f
        if let unicode = UnicodeScalar(scalar) {
            return String(Character(unicode))
        }
        return ""
    }

    /// 현재 syllable을 host에 표시. `insertNew=true`면 새로 insert, false면 한 글자 지우고 insert.
    private func renderCurrent(insertNew: Bool) {
        guard !currentSyllable.isEmpty else { return }
        if !insertNew {
            proxy?.deleteBackward()
        }
        proxy?.insertText(currentSyllable)
    }

    private func rerenderCurrent() {
        renderCurrent(insertNew: false)
    }

    private func commitAndReset() {
        // 현재 syllable이 host에 이미 들어가 있음. state만 비우면 된다.
        initial = nil
        medial = nil
        final = nil
    }

    /// 복합 모음 분해 (ㅘ → ㅗ+ㅏ)
    private func decomposeMedial(_ vowel: Character) -> (Character, Character)? {
        for (base, combos) in Self.medialCombines {
            for (added, combined) in combos {
                if combined == vowel { return (base, added) }
            }
        }
        return nil
    }
}
