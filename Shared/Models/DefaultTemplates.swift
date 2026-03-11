//
//  DefaultTemplates.swift
//  Token memo
//
//  Created by Claude Code on 2026-01-28.
//  기본 제공 템플릿 정의
//

import Foundation

// Memo와 MemoStore는 별도 파일에 정의되어 있으므로 타입만 참조

struct DefaultTemplates {

    /// 앱 초기 실행 시 기본 템플릿 제공 여부 확인
    static var hasProvidedDefaultTemplates: Bool {
        get {
            UserDefaults.standard.bool(forKey: "hasProvidedDefaultTemplates")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hasProvidedDefaultTemplates")
        }
    }

    /// 기본 템플릿 목록
    static func getDefaultTemplates() -> [Memo] {
        greetingTemplates + businessTemplates + responseTemplates
    }

    // MARK: - Template Groups

    private static var greetingTemplates: [Memo] {
        [
            Memo(
                title: "인사말",
                value: "안녕하세요, {이름}입니다.",
                category: "인사",
                isTemplate: true,
                templateVariables: ["이름"],
                placeholderValues: ["이름": []]
            ),
            Memo(
                title: "감사 인사",
                value: "감사합니다. 좋은 하루 되세요!",
                category: "인사",
                isTemplate: false
            ),
            Memo(
                title: "긴급 연락처",
                value: """
                긴급 연락처

                이름: {이름}
                관계: {관계}
                전화: {전화번호}
                """,
                category: "연락처",
                isTemplate: true,
                templateVariables: ["이름", "관계", "전화번호"],
                placeholderValues: ["이름": [], "관계": [], "전화번호": []]
            )
        ]
    }

    private static var businessTemplates: [Memo] {
        [
            Memo(
                title: "회의 일정",
                value: """
                회의 일정 안내

                일시: {날짜} {시간}
                장소: {장소}
                참석자: {참석자}

                감사합니다.
                """,
                category: "업무",
                isTemplate: true,
                templateVariables: ["날짜", "시간", "장소", "참석자"],
                placeholderValues: ["날짜": [], "시간": [], "장소": [], "참석자": []]
            ),
            Memo(
                title: "이메일 서명",
                value: """
                {이름} | {직책}
                {회사명}
                {이메일} | {전화번호}
                """,
                category: "업무",
                isTemplate: true,
                templateVariables: ["이름", "직책", "회사명", "이메일", "전화번호"],
                placeholderValues: ["이름": [], "직책": [], "회사명": [], "이메일": [], "전화번호": []]
            ),
            Memo(
                title: "배송 주소",
                value: """
                [{우편번호}] {주소}
                상세주소: {상세주소}
                수령인: {이름} ({전화번호})
                """,
                category: "주소",
                isTemplate: true,
                templateVariables: ["우편번호", "주소", "상세주소", "이름", "전화번호"],
                placeholderValues: ["우편번호": [], "주소": [], "상세주소": [], "이름": [], "전화번호": []]
            ),
            Memo(
                title: "일정 확인",
                value: "{날짜} {시간}에 일정이 가능하신가요?",
                category: "업무",
                isTemplate: true,
                templateVariables: ["날짜", "시간"],
                placeholderValues: ["날짜": [], "시간": []]
            )
        ]
    }

    private static var responseTemplates: [Memo] {
        [
            Memo(
                title: "정중한 거절",
                value: "죄송하지만 해당 요청은 어렵습니다. 양해 부탁드립니다.",
                category: "응대",
                isTemplate: false
            ),
            Memo(
                title: "확인 완료",
                value: "확인했습니다. 감사합니다!",
                category: "응대",
                isTemplate: false
            ),
            Memo(
                title: "문의 답변",
                value: """
                안녕하세요, {이름}님.

                문의하신 {내용}에 대해 답변드립니다.

                {답변}

                추가 문의사항이 있으시면 언제든 연락 주세요.
                감사합니다.
                """,
                category: "업무",
                isTemplate: true,
                templateVariables: ["이름", "내용", "답변"],
                placeholderValues: ["이름": [], "내용": [], "답변": []]
            )
        ]
    }

    /// 기본 템플릿 생성 (앱 초기 실행 시 1회만)
    static func provideDefaultTemplatesIfNeeded(to memoStore: MemoStore) {
        // 이미 제공했다면 스킵
        if hasProvidedDefaultTemplates {
            print("ℹ️ [DefaultTemplates] 이미 기본 템플릿이 제공됨. 스킵합니다.")
            return
        }

        print("📝 [DefaultTemplates] 기본 템플릿 제공 시작...")

        let templates = getDefaultTemplates()

        // 기존 메모에 추가
        memoStore.memos.insert(contentsOf: templates, at: 0)

        // 저장
        do {
            try memoStore.save(memos: memoStore.memos, type: .tokenMemo)
            hasProvidedDefaultTemplates = true
            print("✅ [DefaultTemplates] 기본 템플릿 \(templates.count)개 제공 완료")
        } catch {
            print("❌ [DefaultTemplates] 기본 템플릿 저장 실패: \(error)")
        }
    }
}
