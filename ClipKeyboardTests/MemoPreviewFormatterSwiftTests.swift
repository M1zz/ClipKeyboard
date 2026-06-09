//
//  MemoPreviewFormatterSwiftTests.swift
//  ClipKeyboardTests
//
//  Swift Testing 스위트 — 리스트 한 줄 미리보기(콤보/템플릿/이미지/보안 마스킹/
//  URL/truncate)와 플레이스홀더 추출.
//
//  명세: docs/FEATURE_SPEC.md §5
//

import Testing
import Foundation
@testable import ClipKeyboard

@Suite("MemoPreviewFormatter — 미리보기")
struct MemoPreviewFormatterSwiftTests {

    // MARK: - 콤보 / 템플릿 / 이미지

    @Test("콤보는 단계 개수를 미리보기에 포함한다")
    func comboPreviewShowsCount() {
        let memo = Memo(title: "콤보", value: "A", comboValues: ["A", "B", "C"])
        let preview = MemoPreviewFormatter.preview(for: memo, resolvedType: nil)
        #expect(!preview.isEmpty)
        #expect(preview.contains("3"))   // "%d items" — 로케일 무관하게 숫자는 포함
    }

    @Test("템플릿 미리보기는 중괄호를 제거하고 변수 개수를 덧붙인다")
    func templatePreviewStripsBraces() {
        let memo = Memo(title: "템플릿", value: "안녕 {이름} {날짜}",
                        templateVariables: ["{이름}"])
        let preview = MemoPreviewFormatter.preview(for: memo, resolvedType: nil)
        #expect(!preview.contains("{"))
        #expect(!preview.contains("}"))
        #expect(preview.contains("이름"))
        #expect(preview.contains("·"))   // "본문 · N variables" 구분자
        #expect(preview.contains("2"))   // {이름}, {날짜} → 2개
    }

    @Test("이미지 메모는 이미지 개수를 미리보기에 포함한다")
    func imagePreviewShowsCount() {
        var memo = Memo(title: "사진", value: "", contentType: .image)
        memo.imageFileNames = ["a.jpg", "b.jpg"]
        let preview = MemoPreviewFormatter.preview(for: memo, resolvedType: nil)
        #expect(preview.contains("2"))
    }

    // MARK: - 보안 마스킹

    @Test("보안 카드 메모는 끝 4자리만 노출하고 마스킹한다")
    func secureCardIsMasked() {
        var memo = Memo(title: "카드", value: "4242424242424242", isSecure: true)
        memo.autoDetectedType = .creditCard
        let preview = MemoPreviewFormatter.preview(for: memo, resolvedType: .creditCard)
        #expect(preview == "•••• 4242")
    }

    @Test("보안 계좌 메모도 끝 4자리만 노출한다")
    func secureBankAccountMasked() {
        let memo = Memo(title: "계좌", value: "1002-123-456789", isSecure: true)
        let preview = MemoPreviewFormatter.preview(for: memo, resolvedType: .bankAccount)
        #expect(preview == "•••• 6789")
    }

    @Test("보안이 아니면 마스킹하지 않는다")
    func nonSecureNotMasked() {
        let memo = Memo(title: "카드", value: "4242424242424242", isSecure: false)
        let preview = MemoPreviewFormatter.preview(for: memo, resolvedType: .creditCard)
        #expect(!preview.contains("••••"))
        #expect(preview.contains("4242"))
    }

    // MARK: - URL / 텍스트 truncate

    @Test("URL은 스킴을 떼고 호스트+경로를 보여준다")
    func urlPreviewStripsScheme() {
        let memo = Memo(title: "링크", value: "https://www.example.com/path")
        let preview = MemoPreviewFormatter.preview(for: memo, resolvedType: .url)
        #expect(preview == "www.example.com/path")
    }

    @Test("긴 텍스트는 40자에서 말줄임표로 잘린다")
    func longTextTruncated() {
        let long = String(repeating: "가", count: 60)
        let memo = Memo(title: "긴글", value: long)
        let preview = MemoPreviewFormatter.preview(for: memo, resolvedType: .text)
        #expect(preview.count == 41)            // 40자 + "…"
        #expect(preview.hasSuffix("…"))
    }

    @Test("짧은 텍스트는 그대로 노출된다")
    func shortTextUnchanged() {
        let memo = Memo(title: "짧은글", value: "안녕")
        let preview = MemoPreviewFormatter.preview(for: memo, resolvedType: .text)
        #expect(preview == "안녕")
    }

    @Test("여러 줄 텍스트는 한 줄로 합쳐진다")
    func multilineCollapsedToSingleLine() {
        let memo = Memo(title: "다줄", value: "첫째 줄\n둘째 줄")
        let preview = MemoPreviewFormatter.preview(for: memo, resolvedType: .text)
        #expect(!preview.contains("\n"))
        #expect(preview == "첫째 줄 둘째 줄")
    }

    // MARK: - 플레이스홀더 추출

    @Test("extractPlaceholders는 중괄호를 떼고 중복 제거해 변수명을 반환한다")
    func extractPlaceholderNames() {
        let names = MemoPreviewFormatter.extractPlaceholders(in: "{이름} {이름} {금액}")
        #expect(names == ["이름", "금액"])
    }

    @Test("플레이스홀더가 없으면 빈 배열")
    func extractPlaceholdersEmpty() {
        #expect(MemoPreviewFormatter.extractPlaceholders(in: "변수 없음").isEmpty)
    }
}
