//
//  PlaceholderExamples.swift
//  ClipKeyboard
//
//  **빈칸 예시** — 값이 하나도 없는 빈칸에 무엇을 넣는지 보여 준다.
//
//  처음 만든 템플릿을 눌러보면 빈칸만 덩그러니 있어서 뭘 넣어야 할지 모르고 거기서 멈춘다.
//  "값을 추가하세요"라고 써 두는 것보다 **어떻게 생긴 값인지 보여 주는 쪽**이 빠르다.
//
//  ⚠️ 예시는 미리 저장하지 않는다. 눌렀을 때에만 내 값이 된다 —
//     쓴 적 없는 값이 목록에 쌓이면 나중에 그게 내가 넣은 건지 앱이 넣은 건지 알 수 없다.
//
//  ⚠️ 빈칸 이름을 못 알아보면 **아무것도 안 보여준다.** 엉뚱한 예시는 없느니만 못하다.
//

import Foundation

enum PlaceholderExamples {

    /// 빈칸 이름에서 그럴듯한 예시 값을 고른다.
    static func suggestions(for placeholder: String) -> [String] {
        let key = placeholder.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for (keywords, examples) in table where keywords.contains(where: { key.contains($0) }) {
            return examples
        }
        return generic
    }

    /// 이름별 예시. 앞의 것이 더 구체적이므로 순서를 지킨다
    /// (예: "회사이름"은 '회사'가 '이름'보다 먼저 걸려야 한다).
    private static var table: [([String], [String])] {
        [
            (["회사", "company", "직장"],
             [NSLocalizedString("○○주식회사", comment: "Placeholder example: company"),
              NSLocalizedString("프리랜서", comment: "Placeholder example: freelancer")]),
            (["이름", "성함", "name", "고객", "담당"],
             [NSLocalizedString("홍길동", comment: "Placeholder example: person name"),
              NSLocalizedString("김민수", comment: "Placeholder example: person name 2")]),
            (["금액", "가격", "원", "price", "amount", "비용"],
             ["10,000", "50,000"]),
            (["전화", "연락", "휴대", "phone", "tel"],
             ["010-1234-5678"]),
            (["메일", "email", "mail"],
             ["me@example.com"]),
            (["주소", "address"],
             [NSLocalizedString("서울시 강남구 …", comment: "Placeholder example: address")]),
            (["시간", "time"],
             ["10:00", "14:30"]),
            (["요일", "day"],
             [NSLocalizedString("월요일", comment: "Placeholder example: weekday"),
              NSLocalizedString("금요일", comment: "Placeholder example: weekday 2")]),
            (["장소", "위치", "place", "location"],
             [NSLocalizedString("회의실 A", comment: "Placeholder example: place"),
              NSLocalizedString("온라인", comment: "Placeholder example: place online")])
        ]
    }

    /// 이름만으로는 못 알아볼 때. 값 자체를 흉내내지 않고 **형태만** 알려 준다.
    private static let generic: [String] = []
}
