//
//  FeatureNudge.swift
//  ClipKeyboard
//
//  **넛지와 추천.** 단순하게 잘 쓰던 사람이 설정에 가서 스택 · 템플릿을 스스로 켜기를 기대하지 않는다.
//  쓰는 모습이 그 기능을 부를 때, 저장이 끝난 바로 뒤에 한 번 권한다.
//
//  | 이럴 때 | 권하는 것 |
//  | 카드 · 계좌번호 같은 글을 저장 | 보안 |
//  | 앞 단축어와 이름만 다른 글을 저장 | 템플릿 |
//  | 번호만 다른 이름이 생김(출근 보고 1 · 2) | 스택 |
//  | 단축어가 6개를 넘음 | 분류 |
//  | 붙여넣어 담는 일이 잦음 | 최근 |
//
//  ⚠️ 지나치지 않게: 기능마다 한 번, "괜찮아요" 면 다시 묻지 않는다, 하루에 하나까지.
//     백지 사용자만 대상이다(기존 사용자는 이미 다 켜져 있다).
//  ⚠️ 판단은 순수 함수다(`suggestion`). 시험이 값을 넣어 본다.
//

import Foundation

enum FeatureNudge {

    enum Answer: String { case shown, no, yes }

    // MARK: - 무엇을 권할까

    /// 방금 저장한 것과 이미 있는 것을 보고 권할 기능을 하나 고른다. 없으면 nil.
    /// - Parameters:
    ///   - saved: 방금 저장한 단축어(이름 · 내용)
    ///   - others: 그 밖의 단축어들
    ///   - recentPastes: 최근에 붙여넣어 담은 횟수
    static func suggestion(saved: (title: String, value: String),
                           others: [(title: String, value: String)],
                           recentPastes: Int = 0) -> AppFeature? {
        if looksSensitive(saved) { return .secure }
        if others.contains(where: { onlyNameDiffers($0.value, saved.value) }) { return .template }
        if numberedSibling(saved.title, others.map(\.title)) { return .stack }
        if others.count + 1 >= 6 { return .category }
        if recentPastes >= 3 { return .recent }
        return nil
    }

    /// 카드번호(16자리) 또는 계좌 · 카드 낱말과 함께 쓴 긴 숫자.
    static func looksSensitive(_ s: (title: String, value: String)) -> Bool {
        let digits = s.value.filter(\.isNumber)
        if s.value.range(of: #"\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b"#, options: .regularExpression) != nil { return true }
        let words = ["계좌", "카드", "account", "card", "IBAN", "账号", "銀行", "口座"]
        let text = (s.title + " " + s.value).lowercased()
        return digits.count >= 10 && words.contains { text.contains($0.lowercased()) }
    }

    /// 첫 낱말(받는 사람 이름)만 다르고 나머지가 같은가. "김님 안녕하세요 …" / "박님 안녕하세요 …"
    static func onlyNameDiffers(_ a: String, _ b: String) -> Bool {
        guard a != b else { return false }
        func tail(_ s: String) -> String {
            guard let space = s.firstIndex(of: " ") else { return "" }
            return String(s[space...]).trimmingCharacters(in: .whitespaces)
        }
        let ta = tail(a), tb = tail(b)
        return ta.count >= 8 && ta == tb
    }

    /// 번호만 다른 이름이 있는가. "출근 보고 2" 와 "출근 보고 1"
    static func numberedSibling(_ title: String, _ others: [String]) -> Bool {
        func base(_ s: String) -> String? {
            guard let r = s.range(of: #"\s*\d+$"#, options: .regularExpression) else { return nil }
            let b = String(s[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
            return b.isEmpty ? nil : b
        }
        guard let b = base(title) else { return false }
        return others.contains { $0 != title && base($0) == b }
    }

    // MARK: - 띄워도 되나

    /// 이 기능을 지금 권해도 되는가: 백지 사용자, 아직 꺼져 있고, 한 번도 안 물었고, 오늘 아직 안 물었다.
    static func mayAsk(_ feature: AppFeature, now: Date = Date(), group: UserDefaults? = AppGroup.defaults) -> Bool {
        guard FeatureSet.isBlankStartUser(group: group), !FeatureSet.isOn(feature, group: group) else { return false }
        let t = table(group)
        guard t[feature.rawValue] == nil else { return false }
        if let day = t["__day"], day == dayStamp(now) { return false }
        return true
    }

    static func record(_ feature: AppFeature, _ answer: Answer, now: Date = Date(), group: UserDefaults? = AppGroup.defaults) {
        var t = table(group)
        t[feature.rawValue] = answer.rawValue
        t["__day"] = dayStamp(now)
        group?.set(t, forKey: DefaultsKey.featureNudges)
        print("📝 [FeatureNudge.record] \(feature.rawValue) \(answer.rawValue)")
        AnalyticsService.log(.featureNudge, parameters: [.source: "\(feature.rawValue).\(answer.rawValue)"])
    }

    // MARK: - 붙여넣어 담기 횟수 ('최근' 을 부른다)

    /// 새 단축어 내용을 붙여넣어 채우고 저장했다. 이런 저장이 쌓이면 '최근' 을 권한다.
    static func notePastedSave(group: UserDefaults? = AppGroup.defaults) {
        let n = pastedSaves(group: group) + 1
        group?.set(n, forKey: DefaultsKey.featureNudgePastedSaves)
        print("📝 [FeatureNudge.notePastedSave] 붙여넣어 담기 \(n)번째")
    }

    static func pastedSaves(group: UserDefaults? = AppGroup.defaults) -> Int {
        group?.integer(forKey: DefaultsKey.featureNudgePastedSaves) ?? 0
    }

    /// 입력칸 글이 한 번에 이만큼 늘었으면 손으로 친 것이 아니라 붙여넣은 것으로 본다.
    static func looksPasted(old: String, new: String) -> Bool {
        new.count - old.count >= 6
    }

    // MARK: - 추천 조합

    /// 설정 ▸ 기능 더하기의 조합 셋 중 하나에 '추천' 을 붙인다. 켜 주지는 않는다.
    ///
    /// 담아 둔 글을 본다: 빈칸이나 답장 · 인사말이 있으면 '답장이 많아요', 8개 이상이면 '전부', 그 밖에는 '단순하게'.
    static func recommendedPreset(memos: [(title: String, value: String)]) -> FeaturePreset {
        if memos.count >= 8 { return .all }
        let replyWords = ["{", "답장", "문의", "안녕하세요", "감사합니다", "thanks", "hello", "hi "]
        if memos.contains(where: { m in replyWords.contains { (m.title + " " + m.value).lowercased().contains($0) } }) {
            return .reply
        }
        return .simple
    }

    // MARK: - Private Helpers

    private static func table(_ group: UserDefaults?) -> [String: String] {
        (group?.dictionary(forKey: DefaultsKey.featureNudges) as? [String: String]) ?? [:]
    }

    private static func dayStamp(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}

/// 설정 ▸ 기능 더하기의 조합. 하나씩 켜기 귀찮은 사람을 위해 셋만 둔다.
enum FeaturePreset: String, CaseIterable, Identifiable {
    case simple, reply, all
    var id: String { rawValue }

    var features: Set<AppFeature> {
        switch self {
        case .simple: return []
        case .reply: return [.template, .recent]
        case .all: return Set(AppFeature.allCases)
        }
    }

    /// 지금 켜진 것이 이 조합과 같은가. 하나씩 바꾸면 어느 조합도 아니다(직접 고름).
    static func matching(_ on: Set<AppFeature>) -> FeaturePreset? {
        allCases.first { $0.features == on }
    }
}
