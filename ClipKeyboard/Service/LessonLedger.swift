//
//  LessonLedger.swift
//  ClipKeyboard
//
//  **배운 것 장부.** 이 앱의 기능 소개를 사용자가 어디까지 받았는지 한 곳에 적는다.
//
//  첫 실행에서 배우는 칸(그림 → 복사 → 붙여넣기 → 보내기 → 바로 넣기)과, 그 기능을 처음
//  만나는 순간에 배우는 칸(키보드 켜기 · 템플릿 · 스택 · 보안 · 분류 · 최근)이 같은 장부에 있다.
//  설정의 가이드북은 이 장부를 보고 "봤어요" 를 붙인다.
//  첫 실행을 끝내기 전에 꺼졌으면 첫 실행 칸을 지우고 처음부터 한다.
//
//  ⚠️ App Group 에 둔다. 키보드에서 처음 쓴 순간도 여기 적어야 하기 때문이다.
//  ⚠️ 시안: docs/design/blank-start-onboarding.html
//

import Foundation

/// 장부의 한 칸.
///
/// ⚠️ rawValue 는 저장 키다. 바꾸면 이미 배운 사람이 다시 배운다.
enum Lesson: String, CaseIterable, Identifiable {
    // 첫 실행에서 배우는 것
    case intro, copy, paste, send, insert
    /// 자기 단축어를 처음 하나 담았다.
    case makeOwn
    // 필요한 순간에 배우는 것
    case keyboard, template, stack, secure, category, recent
    /// 키보드를 켠 뒤 생기는 미리보기 단추를 처음 눌렀다.
    case stage

    var id: String { rawValue }

    /// 첫 실행에서 차례로 지나는 칸. 이 순서가 화면 순서다.
    static let firstRun: [Lesson] = [.intro, .copy, .paste, .send, .insert]
}

enum LessonLedger {

    // MARK: - 읽기

    /// 언제 배웠는가. 안 배웠으면 nil.
    static func learnedAt(_ lesson: Lesson, defaults: UserDefaults? = AppGroup.defaults) -> Date? {
        guard let seconds = table(defaults)[lesson.rawValue] else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    static func hasLearned(_ lesson: Lesson, defaults: UserDefaults? = AppGroup.defaults) -> Bool {
        learnedAt(lesson, defaults: defaults) != nil
    }

    /// 첫 실행에서 아직 안 배운 첫 칸. 다 배웠으면 nil.
    static func nextFirstRunLesson(defaults: UserDefaults? = AppGroup.defaults) -> Lesson? {
        let done = table(defaults)
        return Lesson.firstRun.first { done[$0.rawValue] == nil }
    }

    // MARK: - 쓰기

    /// 배웠다고 적는다. 이미 적혀 있으면 처음 배운 시각을 지킨다.
    static func learn(_ lesson: Lesson, at date: Date = Date(), defaults: UserDefaults? = AppGroup.defaults) {
        var t = table(defaults)
        guard t[lesson.rawValue] == nil else { return }
        t[lesson.rawValue] = date.timeIntervalSince1970
        defaults?.set(t, forKey: DefaultsKey.lessonLedger)
        print("📝 [LessonLedger.learn] \(lesson.rawValue) 배움")
        // 처음 적힐 때 한 번만 허브로. 이름만 보낸다(시각 · 내용은 보내지 않는다)
        AnalyticsService.log(.lessonLearned, parameters: [.source: lesson.rawValue])
    }

    /// 여러 칸을 한 번에 배운 것으로 적는다(기존 사용자처럼 이미 다 아는 사람).
    static func learnAll(_ lessons: [Lesson], defaults: UserDefaults? = AppGroup.defaults) {
        lessons.forEach { learn($0, defaults: defaults) }
    }

    /// 적어 둔 칸을 지운다. 첫 실행을 끝내기 전에 꺼졌을 때 처음부터 다시 하려고 쓴다.
    static func forget(_ lessons: [Lesson], defaults: UserDefaults? = AppGroup.defaults) {
        var t = table(defaults)
        lessons.forEach { t[$0.rawValue] = nil }
        defaults?.set(t, forKey: DefaultsKey.lessonLedger)
    }

    // MARK: - Private Helpers

    private static func table(_ defaults: UserDefaults?) -> [String: Double] {
        (defaults?.dictionary(forKey: DefaultsKey.lessonLedger) as? [String: Double]) ?? [:]
    }
}
