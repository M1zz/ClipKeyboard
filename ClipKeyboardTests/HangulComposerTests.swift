//
//  HangulComposerTests.swift
//  ClipKeyboardTests
//
//  Created by Claude Code on 2026-06-11.
//  키보드 익스텐션 한글 조합기(2벌식) 타이핑 테스트.
//
//  HangulComposer/CheonjiinInput 소스는 익스텐션 타겟 소속이지만 순수 Foundation 로직이라
//  테스트 타겟에도 컴파일해 fake proxy(텍스트 버퍼)로 실제 타이핑 결과를 검증한다.
//  사용자가 키보드에서 보는 글자 = fake proxy의 text.
//

import XCTest
@testable import ClipKeyboard

/// textDocumentProxy 대역 — insertText/deleteBackward를 텍스트 버퍼로 재현.
final class FakeHangulProxy: HangulInputProxy {
    private(set) var text = ""
    func insertText(_ t: String) { text += t }
    func deleteBackward() { if !text.isEmpty { text.removeLast() } }
}

final class HangulComposerTests: XCTestCase {

    var proxy: FakeHangulProxy!
    var composer: HangulComposer!

    override func setUp() {
        super.setUp()
        proxy = FakeHangulProxy()
        composer = HangulComposer()
        composer.proxy = proxy
    }

    override func tearDown() {
        composer = nil
        proxy = nil
        super.tearDown()
    }

    /// 자모 시퀀스를 순서대로 입력.
    private func type(_ jamos: String) {
        for ch in jamos { composer.input(ch) }
    }

    // MARK: - 기본 음절 조합

    func testBasicSyllable_Composition() {
        type("ㅎㅏㄴ")
        XCTAssertEqual(proxy.text, "한")
    }

    func testMultipleSyllables_CommitOnNewInitial() {
        type("ㅎㅏㄴㄱㅡㄹ")
        XCTAssertEqual(proxy.text, "한글")
    }

    func testDoubleConsonantInitial() {
        type("ㄲㅗ")
        XCTAssertEqual(proxy.text, "꼬")
    }

    func testVowelOnly_InsertsRawVowel() {
        type("ㅏ")
        XCTAssertEqual(proxy.text, "ㅏ")
    }

    func testConsecutiveConsonants_StayAsSeparateJamo() {
        type("ㄱㄱ")
        XCTAssertEqual(proxy.text, "ㄱㄱ")
    }

    // MARK: - 받침 이동 (도깨비불 현상)

    func testBatchimMovesToNextSyllable_OnVowel() {
        // "안" + ㅏ → 받침 ㄴ이 다음 음절 초성으로
        type("ㅇㅏㄴㅏ")
        XCTAssertEqual(proxy.text, "아나")
    }

    func testCompoundBatchim_SplitsOnVowel() {
        // "읽" + ㅓ → ㄺ에서 ㄱ만 떼어 "일거"
        type("ㅇㅣㄹㄱㅓ")
        XCTAssertEqual(proxy.text, "일거")
    }

    // MARK: - 복합 모음 / 겹받침

    func testCompoundVowel_Composition() {
        type("ㄱㅗㅏ")   // ㅗ+ㅏ=ㅘ
        XCTAssertEqual(proxy.text, "과")
    }

    func testCompoundVowel_Ui() {
        type("ㅎㅡㅣ")   // ㅡ+ㅣ=ㅢ
        XCTAssertEqual(proxy.text, "희")
    }

    func testCompoundBatchim_Composition() {
        type("ㅇㅣㄹㄱ")  // ㄹ+ㄱ=ㄺ
        XCTAssertEqual(proxy.text, "읽")
    }

    func testNonCombinableVowel_StartsNewSyllableWithIeung() {
        // "가" + ㅗ → 결합 불가 → ㅇ 초성 자동으로 "가오"
        type("ㄱㅏㅗ")
        XCTAssertEqual(proxy.text, "가오")
    }

    func testNonBatchimConsonant_StartsNewSyllable() {
        // ㄸ은 종성 불가 → "바" 확정 후 "따"
        type("ㅂㅏㄸㅏ")
        XCTAssertEqual(proxy.text, "바따")
    }

    // MARK: - 백스페이스 (조합 단계 되돌리기)

    func testBackspace_RemovesBatchimFirst() {
        type("ㅎㅏㄴ")          // 한
        composer.backspace()    // 종성 제거
        XCTAssertEqual(proxy.text, "하")
        composer.backspace()    // 중성 제거
        XCTAssertEqual(proxy.text, "ㅎ")
        composer.backspace()    // 초성 제거
        XCTAssertEqual(proxy.text, "")
    }

    func testBackspace_DecomposesCompoundBatchim() {
        type("ㅇㅣㄹㄱ")        // 읽
        composer.backspace()    // ㄺ → ㄹ
        XCTAssertEqual(proxy.text, "일")
    }

    func testBackspace_DecomposesCompoundVowel() {
        type("ㄱㅗㅏ")          // 과
        composer.backspace()    // ㅘ → ㅗ
        XCTAssertEqual(proxy.text, "고")
    }

    func testBackspace_EmptyComposition_DeletesHostText() {
        proxy.insertText("줄")
        composer.backspace()    // 조합 중 아님 → host로 위임
        XCTAssertEqual(proxy.text, "")
    }

    // MARK: - 비한글 / commit

    func testNonHangulCharacter_CommitsAndInsertsRaw() {
        type("ㄱㅏ!")
        XCTAssertEqual(proxy.text, "가!")
        // 느낌표 뒤 새 음절이 정상 시작되는지
        type("ㄴㅏ")
        XCTAssertEqual(proxy.text, "가!나")
    }

    func testCommit_FinalizesCurrentSyllable() {
        type("ㄱㅏ")
        composer.commit()
        type("ㄴㅏ")
        XCTAssertEqual(proxy.text, "가나")
        composer.commit()
        // commit 후 백스페이스는 조합 되돌리기가 아니라 글자 단위 삭제
        composer.backspace()
        XCTAssertEqual(proxy.text, "가")
    }
}
