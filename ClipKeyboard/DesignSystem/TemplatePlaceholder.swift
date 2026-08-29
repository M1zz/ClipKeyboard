//
//  TemplatePlaceholder.swift
//  ClipKeyboard
//
//  **`{변수}` 에 관한 모든 것은 여기 한 곳에 있다.**
//
//  규칙은 하나다: **플레이스홀더는 어디서든 원문 중괄호가 아니라 하이라이트 칩으로 보인다.**
//  제목이든 값이든 미리보기든, 앱이든 키보드 익스텐션이든 같다.
//
//  ⚠️ 이 파일이 생긴 이유. 예전에는 같은 정규식(`\{([^}]+)\}`)이 열세 군데에 각자 적혀
//     있었고, 칩을 그리는 코드가 앱과 키보드에 두 벌, 중괄호를 떼는 코드가 네 군데에
//     흩어져 있었다. 그래서 **어떤 화면은 칩으로, 어떤 화면은 `{이름}` 그대로** 보였다.
//     새 화면을 만들 때마다 어느 쪽을 따를지 다시 정해야 했고, 대개 잘못 정해졌다.
//
//  ⚠️ 앱·키보드 익스텐션·위젯 **세 타겟에 모두** 들어간다(pbxproj 세 곳 등록).
//     한 곳이라도 빠지면 거기서 복제본이 다시 자란다. 파일을 옮기거나 이름을 바꿀 때 확인한다.
//     그래서 이 파일은 **Foundation·SwiftUI 말고는 아무것도 참조하지 않는다.** 곁가지 둘은
//     각자 아는 곳에 있다: 테마 색을 받는 편한 형태는 `AppTheme.swift`,
//     자동 변수를 걸러내는 `customTokens` 는 `TemplateVariableProcessor.swift`.
//
//  ⚠️ 새로 `{}` 를 다루는 코드를 쓰지 않는다. 정규식을 새로 적고 싶어지면 여기에
//     함수를 하나 더 만든다. 그것이 이 파일의 목적이다.
//

import SwiftUI

// MARK: - 토큰 다루기

/// 템플릿 플레이스홀더(`{이름}`)를 찾고·떼고·골라내는 단 하나의 창구.
enum TemplatePlaceholder {

    /// 하나뿐인 패턴. **다른 곳에 다시 적지 않는다.**
    static let pattern = "\\{([^}]+)\\}"

    /// 한 번만 컴파일해 둔다 - 카드 목록·키보드 격자처럼 한 프레임에 수십 번 도는 자리가 있다.
    static let regex: NSRegularExpression? = try? NSRegularExpression(pattern: pattern)

    /// 중괄호가 하나라도 있는가 - 정규식을 돌리기 전에 싸게 거르는 관문.
    static func hasPlaceholder(_ text: String) -> Bool {
        text.contains("{")
    }

    /// 원문 그대로의 매치 목록. 범위가 필요한 곳(하이라이트 입력칸)에서 쓴다.
    static func matches(in text: String) -> [NSTextCheckingResult] {
        guard hasPlaceholder(text), let regex else { return [] }
        return regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }

    /// 중괄호를 **포함한** 토큰들(`["{이름}", "{날짜}"]`). 중복 제거 + 등장 순서 유지.
    static func tokens(in text: String) -> [String] {
        collect(in: text, rangeIndex: 0)
    }

    /// 중괄호를 **뺀** 이름들(`["이름", "날짜"]`). 중복 제거 + 등장 순서 유지.
    static func names(in text: String) -> [String] {
        collect(in: text, rangeIndex: 1)
    }

    /// 중괄호만 떼어낸 자연스러운 문장. **읽어 주기(VoiceOver)·검색·평문 저장용**이다.
    /// 화면에 그리는 자리에서는 이걸 쓰지 말고 칩(`templateAwareAttributed`)으로 그린다.
    static func strip(_ text: String) -> String {
        guard hasPlaceholder(text) else { return text }
        return text.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
    }

    private static func collect(in text: String, rangeIndex: Int) -> [String] {
        let ns = text as NSString
        var seen = Set<String>()
        var ordered: [String] = []
        for match in matches(in: text) where match.numberOfRanges > rangeIndex {
            let piece = ns.substring(with: match.range(at: rangeIndex))
            if seen.insert(piece).inserted { ordered.append(piece) }
        }
        return ordered
    }
}

// MARK: - 문자열에서 바로

extension String {

    /// 중괄호를 뗀 평문. 읽어 주기·검색용 (화면에 그릴 때는 칩으로).
    var strippingTemplateBraces: String { TemplatePlaceholder.strip(self) }

    /// 이 문자열 안의 토큰들(중괄호 포함, 중복 제거).
    var templatePlaceholderTokens: [String] { TemplatePlaceholder.tokens(in: self) }

    /// 이 문자열 안의 이름들(중괄호 제외, 중복 제거).
    var templatePlaceholderNames: [String] { TemplatePlaceholder.names(in: self) }
}

// MARK: - 칩으로 그리기

extension String {

    /// **화면에 `{변수}` 를 그리는 단 하나의 방법.**
    ///
    /// 중괄호는 숨기고 변수명만 남긴 뒤, 강조색 + 옅은 배경으로 칩처럼 보이게 한다.
    /// 아직 채워지지 않은 자리를 코드가 아니라 '채울 칸'으로 읽히게 하는 것이 목적이다.
    ///
    /// 중괄호가 없으면 정규식을 돌리지 않고 그대로 돌려준다 - 대다수 문자열이 여기서 끝난다.
    ///
    /// - Parameters:
    ///   - accent / accentSoft: 테마 토큰. 앱 카드와 키보드 키가 **같은 값**을 받아야
    ///     테마를 바꿨을 때 두 화면의 칩 색이 갈라지지 않는다.
    ///   - font: 칩 글자의 폰트 - 주변 글과 크기를 맞추기 위해 부르는 쪽이 정한다.
    func templateAwareAttributed(accent: Color,
                                 accentSoft: Color,
                                 font: Font = .body.weight(.semibold)) -> AttributedString {
        guard TemplatePlaceholder.hasPlaceholder(self), let regex = TemplatePlaceholder.regex else {
            return AttributedString(self)
        }
        let ns = self as NSString
        var out = AttributedString()
        var cursor = 0
        for match in regex.matches(in: self, range: NSRange(location: 0, length: ns.length)) {
            let full = match.range
            if full.location > cursor {
                out += AttributedString(ns.substring(with: NSRange(location: cursor, length: full.location - cursor)))
            }
            // 중괄호는 숨기고 이름만, 양옆 얇은 공백(U+2009)으로 칩 안쪽 여백을 흉내낸다.
            var chip = AttributedString("\u{2009}\(ns.substring(with: match.range(at: 1)))\u{2009}")
            chip.foregroundColor = accent
            chip.backgroundColor = accentSoft
            chip.font = font
            out += chip
            cursor = full.location + full.length
        }
        if cursor < ns.length {
            out += AttributedString(ns.substring(from: cursor))
        }
        return out
    }

}

// MARK: - 편집칸 하이라이트 (UIKit)

#if canImport(UIKit)
extension NSMutableAttributedString {

    /// 편집 가능한 입력칸용 칩. `AttributedString` 을 새로 만드는 대신 **있는 글자에 색을 입힌다.**
    ///
    /// ⚠️ 여기서는 중괄호를 **지우지 않는다.** 편집 중인 원문이라 글자를 빼면 커서 위치와
    ///    선택 범위가 어긋난다. 대신 `{`·`}` 두 글자만 투명색으로 칠해서, 칩 배경은 남고
    ///    화면에는 이름만 보이게 한다. 결과는 다른 화면의 칩과 같아 보인다.
    func applyTemplateChipHighlight(accent: UIColor, accentSoft: UIColor, font: UIFont) {
        for match in TemplatePlaceholder.matches(in: string) {
            let range = match.range
            guard range.length >= 2 else { continue }
            addAttributes([.foregroundColor: accent,
                           .backgroundColor: accentSoft,
                           .font: font], range: range)
            addAttribute(.foregroundColor, value: UIColor.clear,
                         range: NSRange(location: range.location, length: 1))
            addAttribute(.foregroundColor, value: UIColor.clear,
                         range: NSRange(location: range.location + range.length - 1, length: 1))
        }
    }
}
#endif
