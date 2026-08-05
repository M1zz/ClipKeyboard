//
//  CursorAndClipboardTokenTests.swift
//  ClipKeyboardTests
//
//  v4.4.4 신규 토큰 두 개의 규약을 고정한다.
//
//  가장 중요한 두 지점:
//   ① 커서 토큰은 **값이 아니라 위치**다 — "값을 입력하세요" 오버레이가 뜨면 안 된다.
//      (extractCustomTokens가 이 토큰을 건지면 문구를 누를 때마다 빈 폼이 뜬다)
//   ② 커서 토큰은 **기본적으로 제거**된다 — 캐럿을 못 옮기는 경로(클립보드 복사·미리보기)에서
//      토큰이 살아남으면 사용자에게 "{커서}"가 그대로 붙여넣어진다.
//

import Testing
import Foundation
@testable import ClipKeyboard

@Suite("커서·클립보드 토큰")
struct CursorAndClipboardTokenTests {

    // MARK: - 커서 위치 계산

    @Test("토큰이 없으면 이동하지 않는다")
    func noTokenMeansNoMove() {
        let placement = TemplateVariableProcessor.resolveCursor(in: "안녕하세요")
        #expect(placement.text == "안녕하세요")
        #expect(placement.offsetFromEnd == 0)
        #expect(placement.needsCursorMove == false)
    }

    @Test("토큰 자리만큼 캐럿을 되돌린다")
    func cursorMovesBackToToken() {
        let placement = TemplateVariableProcessor.resolveCursor(in: "안녕하세요 {커서}님")
        #expect(placement.text == "안녕하세요 님")
        #expect(placement.offsetFromEnd == 1)   // "님"
        #expect(placement.needsCursorMove)
    }

    @Test("영문 토큰도 동일하게 동작한다")
    func englishTokenWorks() {
        let placement = TemplateVariableProcessor.resolveCursor(in: "Hi {cursor}, thanks")
        #expect(placement.text == "Hi , thanks")
        #expect(placement.offsetFromEnd == ", thanks".count)
    }

    @Test("맨 끝의 토큰은 이동이 필요 없다 — 캐럿이 이미 거기 있다")
    func tokenAtEndNeedsNoMove() {
        let placement = TemplateVariableProcessor.resolveCursor(in: "계좌번호: {커서}")
        #expect(placement.text == "계좌번호: ")
        #expect(placement.offsetFromEnd == 0)
        #expect(placement.needsCursorMove == false)
    }

    @Test("맨 앞의 토큰은 전체 길이만큼 되돌린다")
    func tokenAtStartMovesWholeLength() {
        let placement = TemplateVariableProcessor.resolveCursor(in: "{커서}님께")
        #expect(placement.text == "님께")
        #expect(placement.offsetFromEnd == 2)
    }

    /// 캐럿은 하나뿐이라 두 곳을 동시에 가리킬 수 없다.
    /// 나머지 토큰을 안 지우면 사용자 눈에 "{커서}"가 그대로 남는다.
    @Test("토큰이 여러 개면 첫 번째만 쓰고 나머지는 지운다")
    func onlyFirstTokenCounts() {
        let placement = TemplateVariableProcessor.resolveCursor(in: "A{커서}B{커서}C")
        #expect(placement.text == "ABC")
        #expect(placement.offsetFromEnd == 2)   // "BC"
        #expect(!placement.text.contains("{커서}"))
    }

    @Test("ko/en이 섞이면 더 앞에 있는 것이 위치가 된다")
    func earliestTokenWins() {
        let koFirst = TemplateVariableProcessor.resolveCursor(in: "A{커서}B{cursor}C")
        #expect(koFirst.offsetFromEnd == 2)
        let enFirst = TemplateVariableProcessor.resolveCursor(in: "A{cursor}BB{커서}C")
        #expect(enFirst.offsetFromEnd == 3)
        #expect(!enFirst.text.contains("{"))
    }

    // MARK: - 제거가 기본 (가장 중요)

    @Test("process는 기본적으로 커서 토큰을 지운다 — 복사 경로로 새면 안 된다")
    func processStripsCursorByDefault() {
        let out = TemplateVariableProcessor.process("계좌: {커서}입금")
        #expect(out == "계좌: 입금")
        #expect(!out.contains("커서"))
    }

    @Test("키보드만 keepCursorToken으로 토큰을 살린다")
    func keyboardKeepsCursorToken() {
        let out = TemplateVariableProcessor.process("계좌: {커서}입금", keepCursorToken: true)
        #expect(out.contains("{커서}"))
    }

    // MARK: - 클립보드 토큰

    @Test("클립보드 값이 있으면 그대로 꽂는다")
    func clipboardSubstitutes() {
        let out = TemplateVariableProcessor.process("계좌: {clipboard}", clipboard: "110-2402-8845-01")
        #expect(out == "계좌: 110-2402-8845-01")
    }

    @Test("한글 토큰도 동일하게 치환된다")
    func koreanClipboardToken() {
        let out = TemplateVariableProcessor.process("{클립보드} 확인 부탁드려요", clipboard: "ABC")
        #expect(out == "ABC 확인 부탁드려요")
    }

    /// 전체 접근이 꺼져 있거나 클립보드가 비었을 때 — 빈칸이 남는 게
    /// "{clipboard}"가 그대로 붙여넣어지는 것보다 낫다.
    @Test("클립보드 값이 없으면 토큰을 지운다")
    func clipboardMissingLeavesBlank() {
        let out = TemplateVariableProcessor.process("계좌: {clipboard}", clipboard: nil)
        #expect(out == "계좌: ")
        #expect(!out.contains("clipboard"))
    }

    /// 알려진 결과: 클립보드를 **먼저** 꽂기 때문에, 붙은 값 안에 자동 변수가 들어 있으면
    /// 그것도 함께 치환된다. 막으려면 이스케이프 장치가 필요한데 그만한 값이 없다고 판단했다.
    /// 여기 고정해 두는 이유는 나중에 순서를 바꿨을 때 **말없이 동작이 달라지는 걸 막기 위해서**다.
    @Test("클립보드로 들어온 값 안의 자동 변수도 함께 치환된다")
    func clipboardValueIsAlsoProcessed() {
        var c = DateComponents()
        c.year = 2026; c.month = 3; c.day = 7
        let fixed = Calendar.current.date(from: c)!

        let out = TemplateVariableProcessor.process("{clipboard}", at: fixed, clipboard: "메모 {날짜}")
        #expect(out == "메모 2026-03-07")
    }

    // MARK: - 감지 헬퍼 (프롬프트를 아낀다)

    @Test("토큰이 있을 때만 클립보드를 읽도록 감지한다")
    func detectsClipboardToken() {
        #expect(TemplateVariableProcessor.containsClipboardToken("계좌 {clipboard}"))
        #expect(TemplateVariableProcessor.containsClipboardToken("계좌 {클립보드}"))
        #expect(!TemplateVariableProcessor.containsClipboardToken("계좌 {이름}"))
        #expect(!TemplateVariableProcessor.containsClipboardToken("그냥 문장"))
    }

    @Test("커서 토큰 유무를 감지한다")
    func detectsCursorToken() {
        #expect(TemplateVariableProcessor.containsCursorToken("A{커서}B"))
        #expect(TemplateVariableProcessor.containsCursorToken("A{cursor}B"))
        #expect(!TemplateVariableProcessor.containsCursorToken("A{이름}B"))
    }

    // MARK: - 커스텀 플레이스홀더로 오인되지 않을 것 (회귀 방지)

    /// 이게 깨지면 `{커서}`가 든 문구를 누를 때마다 "커서에 넣을 값"을 묻는
    /// 빈 입력 폼이 뜬다 — 기능이 아니라 버그로 보인다.
    @Test("새 토큰들은 사용자 입력 토큰으로 추출되지 않는다")
    func newTokensAreNotCustomPlaceholders() {
        let tokens = TemplateVariableProcessor.extractCustomTokens(in: "{이름}님 {커서} {cursor} {clipboard} {클립보드}")
        #expect(tokens == ["{이름}"])
    }

    @Test("자동 변수 집합에 네 토큰이 모두 등록돼 있다")
    func tokensAreRegistered() {
        for token in ["{커서}", "{cursor}", "{clipboard}", "{클립보드}"] {
            #expect(TemplateVariableProcessor.autoVariableTokens.contains(token),
                    "\(token)이 autoVariableTokens에 없으면 입력 폼이 뜬다")
        }
    }
}
