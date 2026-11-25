//
//  PaywallReachAndCopiedCardTests.swift
//  ClipKeyboardTests
//
//  2026-11-25 허브 기록 두 가지의 순수한 부분.
//   - 페이월을 보는 사람이 설치의 1.3%: 문턱 영수증이 노출을 안 남기던 것, 복사 기록 한도가 말없이 자르던 것
//   - 1점 리뷰 "Scam": '방금 복사함' 카드가 숫자 아무거나 "내 계좌번호" 라 부르던 것
//  끝에서 끝까지의 길은 `BasicScenarioTests` 의 두 시험이다(여정 표).
//

import Foundation
import Testing
@testable import ClipKeyboard

@Suite("페이월에 닿는 길 · 방금 복사함 카드")
struct PaywallReachAndCopiedCardTests {

    // MARK: - 방금 복사함 카드

    @Test("숫자만 이어진 글은 계좌번호라고 부르지 않는다")
    func bareDigitsAreNotCalledAnAccount() {
        let (type, confidence) = ClipboardClassificationService.shared.classify(content: "1234567890")
        #expect(type == .bankAccount, "분류기는 그대로다. 카드가 부르는 이름만 바뀐다")
        #expect(FreshClipboardPresentation.displayedType(type, confidence: confidence) == .text)
    }

    @Test("확신이 있는 돈 · 신원 종류는 그 이름으로 부른다", arguments: [
        ClipboardItemType.creditCard, .iban, .passportNumber
    ])
    func confidentSensitiveKeepsItsType(type: ClipboardItemType) {
        #expect(FreshClipboardPresentation.displayedType(type, confidence: 0.9) == type)
    }

    @Test("돈 · 신원과 상관없는 종류는 확신이 낮아도 건드리지 않는다")
    func nonSensitiveIsUntouched() {
        #expect(FreshClipboardPresentation.displayedType(.phone, confidence: 0.55) == .phone)
        #expect(FreshClipboardPresentation.displayedType(.name, confidence: 0.5) == .name)
    }

    @Test("카드번호 같은 것은 끝 네 자리만 보인다, 그냥 글은 그대로")
    func previewMasksSensitive() {
        #expect(FreshClipboardPresentation.preview("4111 1111 1111 1234", type: .creditCard) == "\u{2022}\u{2022}\u{2022}\u{2022} 1234")
        #expect(FreshClipboardPresentation.preview("회의 10시", type: .text) == "회의 10시")
    }

    @Test("돈 · 신원 종류의 제목에는 '내' 를 붙이지 않는다(남의 계좌일 때가 많다)")
    func sensitiveTitleIsNotPossessive() {
        #expect(ClipboardItemType.bankAccount.suggestedMemoTitle == ClipboardItemType.bankAccount.localizedName)
        #expect(ClipboardItemType.creditCard.suggestedMemoTitle == ClipboardItemType.creditCard.localizedName)
        // 이메일은 대개 내 것이다. 예전 그대로.
        #expect(ClipboardItemType.email.suggestedMemoTitle != ClipboardItemType.email.localizedName)
    }

    // MARK: - 복사 기록 한도

    @Test("복사 기록이 무료 한도에 닿은 무료 사용자에게만, 찾는 중이 아닐 때 목록 끝 한 줄")
    func historyCapNoteRule() {
        let limit = ProFeatureManager.freeClipboardHistoryLimit
        #expect(RecentClipsPage.showsHistoryCapNote(hasFullAccess: false, storedCount: limit, isFiltering: false))
        #expect(!RecentClipsPage.showsHistoryCapNote(hasFullAccess: false, storedCount: limit - 1, isFiltering: false))
        #expect(!RecentClipsPage.showsHistoryCapNote(hasFullAccess: true, storedCount: 100, isFiltering: false))
        #expect(!RecentClipsPage.showsHistoryCapNote(hasFullAccess: false, storedCount: limit, isFiltering: true))
    }

    @Test("복사 기록 페이월은 허브에 clipboard_history 로 남는다")
    func clipboardHistoryTriggerKey() {
        #expect(ProFeatureManager.LimitType.clipboardHistory.analyticsKey == "clipboard_history")
    }

    // MARK: - 문턱 영수증 노출

    @Test("문턱 영수증 · 안내의 결제 화면은 서로 다른 출처로 남는다")
    func freeUsePaywallSources() {
        #expect(FreeUsePaywallView.analyticsSource(isThresholdMoment: true) == "free_use_threshold")
        #expect(FreeUsePaywallView.analyticsSource(isThresholdMoment: false) == "free_use_guide")
    }
}
