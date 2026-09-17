//
//  ContentLanguageTests.swift
//  ClipKeyboardTests
//
//  예시·샘플을 고르는 언어가 **앱에서 고른 언어**를 따르는지 못박는다.
//
//  어떻게 생긴 문제인가: 앱 안에서 언어를 고르면 바뀌는 것은 번들뿐이고 `Locale.current` 는
//  기기 언어 그대로다. 예시를 고르는 곳들이 `Locale.current` 를 봐서, 한국어 기기에서
//  러시아어를 고른 사람에게 글자는 러시아어인데 예시만 한국어로 나왔다.
//

import Testing
@testable import ClipKeyboard

@Suite("예시 언어는 앱 언어를 따른다", .serialized)
struct ContentLanguageTests {

    @Test("러시아어를 고르면 한국어 예시가 나오지 않는다")
    func russianNeverGetsKoreanExamples() {
        let before = AppLanguage.current
        defer { AppLanguage.select(before) }

        AppLanguage.select(.ru)
        #expect(AppLanguage.contentLanguageCode == "ru")
        #expect(QuickPattern.defaults.first?.title == "Bank account")
    }

    @Test("중국어는 지역이 붙어도 언어 코드만 돌려준다")
    func chineseStripsScript() {
        let before = AppLanguage.current
        defer { AppLanguage.select(before) }

        AppLanguage.select(.zhHant)
        #expect(AppLanguage.contentLanguageCode == "zh")
    }

    @Test("한국어를 고르면 한국어 예시가 나온다")
    func koreanGetsKoreanExamples() {
        let before = AppLanguage.current
        defer { AppLanguage.select(before) }

        AppLanguage.select(.ko)
        #expect(QuickPattern.defaults.first?.title == "계좌번호")
    }
}
