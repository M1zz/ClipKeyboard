//
//  CheonjiinInputTests.swift
//  ClipKeyboardTests
//
//  Created by Claude Code on 2026-06-11.
//  키보드 익스텐션 천지인(3x4) 입력 테스트.
//
//  사용자 시나리오: 자음 키 연타로 ㄱ→ㅋ→ㄲ 순환, ㅣ·ㆍ·ㅡ 획 조합으로 모음 생성,
//  HangulComposer와 결합해 음절 완성. fake proxy의 text가 사용자가 보는 결과.
//

import XCTest
@testable import ClipKeyboard

final class CheonjiinInputTests: XCTestCase {

    var proxy: FakeHangulProxy!
    var composer: HangulComposer!
    var cheonjiin: CheonjiinInput!

    override func setUp() {
        super.setUp()
        proxy = FakeHangulProxy()
        composer = HangulComposer()
        composer.proxy = proxy
        cheonjiin = CheonjiinInput()
        cheonjiin.composer = composer
    }

    override func tearDown() {
        cheonjiin = nil
        composer = nil
        proxy = nil
        super.tearDown()
    }

    // MARK: - 자음 multi-tap 순환

    func testConsonantKey_SingleTap() {
        cheonjiin.tap("ㄱㅋ")
        XCTAssertEqual(proxy.text, "ㄱ")
    }

    func testConsonantKey_MultiTapCycles() {
        // 같은 키 빠른 연타: ㄱ → ㅋ → ㄲ → (다시) ㄱ
        cheonjiin.tap("ㄱㅋ")
        XCTAssertEqual(proxy.text, "ㄱ")
        cheonjiin.tap("ㄱㅋ")
        XCTAssertEqual(proxy.text, "ㅋ")
        cheonjiin.tap("ㄱㅋ")
        XCTAssertEqual(proxy.text, "ㄲ")
        cheonjiin.tap("ㄱㅋ")
        XCTAssertEqual(proxy.text, "ㄱ", "사이클은 한 바퀴 돌면 처음으로")
    }

    func testConsonantKey_SlowTapsStillCycle() {
        // 시간이 아니라 → 키가 끊는다. 천천히 쳐도 ㄱ ㄱ 은 ㅋ (기본 10키와 같다)
        cheonjiin.tap("ㄱㅋ")
        Thread.sleep(forTimeInterval: 0.6)
        cheonjiin.tap("ㄱㅋ")
        XCTAssertEqual(proxy.text, "ㅋ")
    }

    func testDifferentConsonantKey_BreaksCycle() {
        cheonjiin.tap("ㄱㅋ")
        cheonjiin.tap("ㄴㄹ")
        XCTAssertEqual(proxy.text, "ㄱㄴ")
    }

    // MARK: - 모음 획(stroke) 조합

    func testVowelStrokes_Composition_A() {
        // ㅇ + (ㅣ,ㆍ)=ㅏ → "아"
        cheonjiin.tap("ㅇㅁ")
        cheonjiin.tap("ㅣ")
        cheonjiin.tap("ㆍ")
        XCTAssertEqual(proxy.text, "아")
    }

    func testVowelStrokes_EvolveWhileTyping() {
        // 획이 쌓일 때마다 화면의 모음이 진화: 이 → 아 → 야
        cheonjiin.tap("ㅇㅁ")
        cheonjiin.tap("ㅣ")
        XCTAssertEqual(proxy.text, "이")
        cheonjiin.tap("ㆍ")
        XCTAssertEqual(proxy.text, "아")
        cheonjiin.tap("ㆍ")
        XCTAssertEqual(proxy.text, "야")
    }

    func testVowelStrokes_CompoundVowel_Ae() {
        // (ㅣ,ㆍ,ㅣ)=ㅐ → "애"
        cheonjiin.tap("ㅇㅁ")
        cheonjiin.tap("ㅣ")
        cheonjiin.tap("ㆍ")
        cheonjiin.tap("ㅣ")
        XCTAssertEqual(proxy.text, "애")
    }

    func testLoneDot_ShowsTentative_ThenResolves() {
        // 단독 ㆍ는 임시 표시, 다음 획이 오면 정리되고 모음으로 해석
        cheonjiin.tap("ㆍ")
        XCTAssertEqual(proxy.text, "ㆍ")
        cheonjiin.tap("ㅣ")
        XCTAssertEqual(proxy.text, "ㅓ")
    }

    /// 보이는 모음에 획을 더한다: 오 + ㆍ = 요, 우 + ㆍ = 유 (2026-10 사용자 신고).
    func testStrokeAddsToShownVowel() {
        cheonjiin.tap("ㅇㅁ")
        cheonjiin.tap("ㆍ")
        cheonjiin.tap("ㅡ")
        XCTAssertEqual(proxy.text, "오")
        cheonjiin.tap("ㆍ")
        XCTAssertEqual(proxy.text, "요")

        cheonjiin.commit()
        cheonjiin.tap("ㅇㅁ")
        cheonjiin.tap("ㅡ")
        cheonjiin.tap("ㆍ")
        cheonjiin.tap("ㆍ")
        XCTAssertEqual(proxy.text, "요유")
    }

    /// 늦게 쳐도 모음이 끊기지 않는다.
    func testSlowStrokesStillCompose() {
        cheonjiin.tap("ㅇㅁ")
        cheonjiin.tap("ㅣ")
        Thread.sleep(forTimeInterval: 0.7)
        cheonjiin.tap("ㆍ")
        XCTAssertEqual(proxy.text, "아")
    }

    /// 두 점 다음 획: ‥ + ㅣ = ㅕ, ‥ + ㅡ = ㅛ. 겹모음도 보이는 모음에서 간다(외 + ㆍ = 와).
    func testDotsAndCompoundVowels() {
        cheonjiin.tap("ㄱㅋ")
        cheonjiin.tap("ㆍ")
        cheonjiin.tap("ㆍ")
        cheonjiin.tap("ㅣ")
        XCTAssertEqual(proxy.text, "겨")
        cheonjiin.commit()
        cheonjiin.tap("ㄱㅋ")
        cheonjiin.tap("ㆍ")
        cheonjiin.tap("ㅡ")
        cheonjiin.tap("ㅣ")
        cheonjiin.tap("ㆍ")
        XCTAssertEqual(proxy.text, "겨과")
        cheonjiin.commit()
        cheonjiin.tap("ㅇㅁ")
        cheonjiin.tap("ㅡ")
        cheonjiin.tap("ㆍ")
        cheonjiin.tap("ㆍ")
        cheonjiin.tap("ㅣ")
        XCTAssertEqual(proxy.text, "겨과워")
    }

    /// 홀로 친 모음도 획을 더하면 바뀐다(ㅣ + ㆍ = ㅏ, 앞에 ㅣ 가 남지 않는다).
    func testLoneVowelEvolves() {
        cheonjiin.tap("ㅣ")
        cheonjiin.tap("ㆍ")
        XCTAssertEqual(proxy.text, "ㅏ")
    }

    // MARK: - 음절 완성 (자음+모음+받침)

    func testFullSyllable_Han() {
        // ㅅㅎ 키 2연타(ㅎ) + ㅣㆍ(ㅏ) + ㄴㄹ(ㄴ) → "한"
        cheonjiin.tap("ㅅㅎ")
        cheonjiin.tap("ㅅㅎ")
        cheonjiin.tap("ㅣ")
        cheonjiin.tap("ㆍ")
        cheonjiin.tap("ㄴㄹ")
        XCTAssertEqual(proxy.text, "한")
    }

    func testBatchimMoves_WhenVowelFollows() {
        // "간" 뒤 모음 → 받침 ㄴ이 새 음절 초성으로 ("가나")
        cheonjiin.tap("ㄱㅋ")
        cheonjiin.tap("ㅣ")
        cheonjiin.tap("ㆍ")
        cheonjiin.tap("ㄴㄹ")
        XCTAssertEqual(proxy.text, "간")
        cheonjiin.tap("ㅣ")
        cheonjiin.tap("ㆍ")
        XCTAssertEqual(proxy.text, "가나")
    }

    // MARK: - 백스페이스

    func testBackspace_RemovesWholeConsonant() {
        // iOS 네이티브 천지인과 동일: 자음 연타 중 백스페이스는 글자 전체 제거
        cheonjiin.tap("ㄱㅋ")
        cheonjiin.tap("ㄱㅋ")     // ㅋ
        cheonjiin.backspace()
        XCTAssertEqual(proxy.text, "")
    }

    func testBackspace_RewindsVowelStroke() {
        // 획 하나만 되돌리기: 야 → 아
        cheonjiin.tap("ㅇㅁ")
        cheonjiin.tap("ㅣ")
        cheonjiin.tap("ㆍ")
        cheonjiin.tap("ㆍ")
        XCTAssertEqual(proxy.text, "야")
        cheonjiin.backspace()
        XCTAssertEqual(proxy.text, "아")
    }

    func testBackspace_RemovesTentativeDot() {
        cheonjiin.tap("ㆍ")
        cheonjiin.backspace()
        XCTAssertEqual(proxy.text, "")
    }

    // MARK: - commit / reset

    func testCommit_FinalizesSyllable_AndStartsFresh() {
        cheonjiin.tap("ㄱㅋ")
        cheonjiin.tap("ㅣ")
        cheonjiin.tap("ㆍ")
        XCTAssertEqual(proxy.text, "가")

        cheonjiin.commit()
        cheonjiin.tap("ㄴㄹ")
        cheonjiin.tap("ㅣ")
        cheonjiin.tap("ㆍ")
        XCTAssertEqual(proxy.text, "가나")
    }

    func testCommit_DiscardsUnresolvedTentativeStroke() {
        // 미완성 raw 획(단독 ㆍ)은 commit 시 폐기 - 쓰레기 문자가 남으면 안 됨
        cheonjiin.tap("ㄱㅋ")
        cheonjiin.tap("ㅣ")
        cheonjiin.tap("ㆍ")     // "가"
        cheonjiin.commit()
        cheonjiin.tap("ㆍ")     // 임시 ㆍ
        cheonjiin.commit()
        XCTAssertEqual(proxy.text, "가")
    }

    /// 꾹 누르면 전화 자판 자리의 숫자(2026-10 사용자 요청).
    func testLongPressDigitsFollowPhonePad() {
        XCTAssertEqual(CheonjiinInput.digit(for: "ㅣ"), "1")
        XCTAssertEqual(CheonjiinInput.digit(for: "ㄱㅋ"), "4")
        XCTAssertEqual(CheonjiinInput.digit(for: "ㅈㅊ"), "9")
        XCTAssertEqual(CheonjiinInput.digit(for: "ㅇㅁ"), "0")
        XCTAssertNil(CheonjiinInput.digit(for: CheonjiinInput.advanceKey))
    }
}
