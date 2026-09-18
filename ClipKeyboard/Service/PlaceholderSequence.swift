//
//  PlaceholderSequence.swift
//  ClipKeyboard / ClipKeyboardExtension
//
//  빈칸 값의 **다음 차례**.
//
//  인보이스 번호·회차·주문번호는 매번 하나씩 오른다. 지난번 값이 `INV-1042` 였으면 이번은
//  거의 틀림없이 `INV-1043` 이다. 그런데 칩에는 지난 값만 있어서, 사람은 지난 값을 고른 뒤
//  숫자를 고치거나(키보드에서는 못 고친다) 새로 쳐야 했다. 그리고 가장 흔한 사고가 여기서 난다.
//  **지난달 번호가 그대로 나간다.**
//
//  언제 다음 번호를 내놓나:
//   - 가장 최근 값이 숫자로 끝나고
//   - 빈칸 이름이 차례를 뜻하거나(번호·회차·No·# …), 최근 두 값이 딱 1 차이일 때
//
//  ⚠️ 전화번호·계좌번호·카드번호처럼 **숫자로 끝나지만 오르지 않는 값**은 이름만으로는
//     차례로 보지 않는다. 그래서 이름에 "번호" 가 들어가도 그런 말이 함께 있으면 뺀다.
//
//  다음 번호를 골랐으면 넣기를 마칠 때 그 값을 새로 적어 둔다. 안 적으면 다음번에도
//  같은 번호를 내놓는다.
//
//  ⚠️ **고른 값을 앞으로 옮기지 않는다.** 5.0.7 에서 사용자 요청으로 "쓴다고 자리가 움직이지
//     않는다" 로 정했다(docs/release-notes/HISTORY.md v5.0.7). 순서는 빈칸 관리에서 사람이 정한다.
//     새로 적는 다음 번호만 맨 앞에 붙는다. 별을 눌러 남긴 값과 같은 자리다.
//
//  ⚠️ 이번에만 쓰려고 직접 친 값은 **적지 않는다.** 한 번 쓰고 말 값까지 칩으로 남으면
//     목록이 금세 못 쓰게 된다(`PlaceholderInputView.commitDraft` 와 같은 규칙).
//

import Foundation

enum PlaceholderSequence {

    /// 차례를 뜻하는 말. 이름에 들어 있으면 최근 값 하나만으로도 다음 번호를 내놓는다.
    static let sequenceWords = [
        "번호", "회차", "차수", "호수", "순번", "일련",
        "no.", "no", "number", "num", "#", "seq", "invoice", "order", "issue", "ticket", "ref",
        "编号", "单号", "期", "номер"
    ]

    /// 숫자로 끝나지만 오르지 않는 값을 뜻하는 말. 함께 있으면 이름으로는 차례로 보지 않는다.
    static let fixedWords = [
        "전화", "휴대폰", "핸드폰", "연락처", "계좌", "카드", "우편", "사업자", "주민", "여권", "학번", "사번",
        "phone", "mobile", "tel", "account", "card", "zip", "postal", "passport", "iban", "tax", "vat",
        "电话", "账号", "卡号", "телефон", "счет", "счёт", "карта"
    ]

    /// 숫자 자리 상한. 이보다 길면 번호가 아니라 식별자다(카드번호 16자리 같은).
    static let maxDigits = 9

    // MARK: - 다음 번호

    /// 빈칸 이름이 차례를 뜻하는가.
    static func isSequenceToken(_ token: String) -> Bool {
        let name = token.strippingTemplateBraces.lowercased()
        guard !fixedWords.contains(where: { name.contains($0) }) else { return false }
        return sequenceWords.contains { word in
            // 짧은 영어 낱말(no, num)은 다른 낱말 속에 숨어 있기 쉽다(note, number 는 괜찮다).
            if word.count <= 3, word.allSatisfy({ $0.isASCII && $0.isLetter }) {
                return name.split(whereSeparator: { !$0.isLetter }).contains { $0 == Substring(word) }
            }
            return name.contains(word)
        }
    }

    /// 다음 차례 값. 없으면 nil - **순수 함수.**
    /// - Parameter values: 최근 것이 앞인 저장 값들.
    static func nextValue(after values: [String], token: String) -> String? {
        guard let latest = values.first, let parts = split(latest) else { return nil }

        let consecutive: Bool = {
            guard values.count >= 2, let previous = split(values[1]) else { return false }
            return previous.prefix == parts.prefix && parts.number - previous.number == 1
        }()
        guard isSequenceToken(token) || consecutive else { return nil }

        let next = String(parts.number + 1)
        let padded = next.count < parts.width
            ? String(repeating: "0", count: parts.width - next.count) + next
            : next
        return parts.prefix + padded
    }

    /// 끝의 숫자와 그 앞을 나눈다. 숫자로 끝나지 않거나 너무 길면 nil.
    private static func split(_ value: String) -> (prefix: String, number: Int, width: Int)? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.reversed().prefix(while: { $0.isASCII && $0.isNumber })
        guard !digits.isEmpty, digits.count <= maxDigits,
              let number = Int(String(digits.reversed())) else { return nil }
        return (String(trimmed.dropLast(digits.count)), number, digits.count)
    }

    // MARK: - 다음 번호를 골랐나

    /// 넣기를 마친 뒤 이 값을 새로 적어 둘지 - **순수 함수.**
    /// 다음 번호를 골랐을 때만 true 다. 이미 있는 값·직접 친 값은 건드리지 않는다.
    static func shouldRemember(chosen: String, stored: [String], token: String) -> Bool {
        let value = chosen.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !stored.contains(value) else { return false }
        return nextValue(after: stored, token: token) == value
    }
}
