//
//  PersonaInference.swift
//  ClipKeyboard
//
//  **묻지 않고 알아본다.** 이 사람이 무엇을 저장했는지를 보고 어떤 쓰임새인지 짐작한다.
//
//  왜 묻지 않나: 처음 여는 자리에서 물으면 아무도 답을 모른다(`Persona.default` 주석).
//  써 보고 나서 물어도, "디지털 노마드 / 학생 / 직장인" 가운데 하나를 고르는 일은 사람에게
//  자기를 분류하라는 숙제다. 그리고 그 답은 **이미 저장한 것들에 적혀 있다.**
//  IBAN 과 {시차} 를 저장한 사람에게 노마드냐고 물을 이유가 없다.
//
//  보는 것 (전부 기기 안에 이미 있는 것)
//
//  | 무엇 | 예 | 무게 |
//  | --- | --- | --- |
//  | 자동 분류된 종류 | IBAN·SWIFT → 노마드, 사번/학번 → 학생·직장인 | 종류마다 |
//  | 제목·본문의 낱말 | "교수님", "세금계산서", "공동현관" | 단축어 하나에 최대 2 |
//  | 빈칸 이름 | {학번} {시차} {고객사} | 빈칸마다 1.5 |
//  | 직접 만든 카테고리 이름 | "학교", "거래처" | 카테고리마다 1 |
//  | 예전에 직접 고른 페르소나 | 5.1.3 까지의 선택 | 2 (덮어쓰지 않고 한 표만) |
//
//  정하는 법: 가장 높은 쪽이 **4점 이상**이고 둘째보다 **1.5배 이상** 앞서야 확신한다.
//  확신이 없으면 `.general` 이고 `isConfident == false` 다. 이때 화면은 좁혀 보여 주지 않는다.
//  좁게 잡았다가 틀리면 엉뚱한 추천이 나가고, 그건 아무 추천도 안 하느니만 못하다.
//
//  ⚠️ 판정은 **순수 함수**다. 기기에서 값을 긁는 일은 `PersonaResolver` 가 한다.
//  ⚠️ 샘플은 넣지 않는다. 앱이 심어 준 것으로 사람을 판단하면 모두가 같은 페르소나가 된다.
//  ⚠️ 보안 단축어의 본문은 보지 않는다(암호문이다). 제목과 종류만 본다.
//

import Foundation

/// 판정에 넣는 값.
struct PersonaFacts: Equatable {

    struct Item: Equatable {
        var title: String
        /// 본문. 보안 단축어는 nil.
        var value: String?
        var type: ClipboardItemType?
        /// 빈칸 이름(중괄호 없이).
        var placeholders: [String] = []
    }

    var items: [Item] = []
    /// 사용자가 직접 만든 카테고리 이름.
    var customCategories: [String] = []
    /// 5.1.3 까지 사람이 직접 고른 페르소나(`CategoryStore.selectedPersona`).
    var earlierChoice: Persona?
}

enum PersonaInference {

    // MARK: - 결과

    /// 왜 그렇게 봤는지. 설정 화면이 사람에게 그대로 보여 준다.
    struct Evidence: Equatable {
        enum Kind: Equatable {
            case type(ClipboardItemType)
            case keyword(String)
            case placeholder(String)
            case category(String)
            case earlierChoice
        }
        let kind: Kind
        let persona: Persona
        /// 몇 개의 단축어(또는 빈칸)에서 보였나.
        let count: Int
    }

    struct Result: Equatable {
        let persona: Persona
        let isConfident: Bool
        let scores: [Persona: Double]
        /// 고른 페르소나의 근거, 센 순서.
        let evidence: [Evidence]

        static let unknown = Result(persona: .general, isConfident: false, scores: [:], evidence: [])
    }

    enum Threshold {
        static let minScore = 4.0
        static let dominance = 1.5
        static let keywordCapPerItem = 2
        static let placeholderWeight = 1.5
        static let categoryWeight = 1.0
        static let earlierChoiceWeight = 2.0
    }

    // MARK: - 신호표

    static let typeWeights: [ClipboardItemType: [Persona: Double]] = [
        .iban: [.nomad: 3],
        .swift: [.nomad: 3],
        .vat: [.nomad: 2],
        .paypalLink: [.nomad: 2],
        .cryptoWallet: [.nomad: 1],
        .passportNumber: [.nomad: 1.5],
        .taxID: [.business: 1.5],
        .employeeID: [.student: 1, .business: 1],
        .address: [.general: 1],
        .trackingNumber: [.general: 1],
        .bankAccount: [.general: 0.5],
        .phone: [.general: 0.5],
        .postalCode: [.general: 0.5]
    ]

    static let keywords: [Persona: [String]] = [
        .nomad: [
            "iban", "swift", "bic", "wise", "revolut", "paypal", "payoneer", "invoice", "인보이스",
            "비자", "passport", "여권", "timezone", "time zone", "시차", "gmt", "utc",
            "airbnb", "에어비앤비", "coworking", "co-working", "코워킹", "환율", "exchange rate",
            "freelance", "프리랜서", "노마드", "nomad", "calendly", "upwork", "fiverr",
            "签证", "汇率", "自由职业", "виза", "фриланс"
        ],
        .business: [
            "회사", "직책", "직급", "팀장", "과장", "대리", "부장", "차장", "미팅", "회의",
            "업무 보고", "주간 보고", "주간보고", "보고드립니다", "견적", "세금계산서", "사업자",
            "거래처", "고객사", "담당자", "명함", "결재", "출장",
            "regards", "meeting", "agenda", "quotation", "proposal", "purchase order", "colleague",
            "会议", "报告", "公司", "客户", "报价", "встреча", "отчет", "отчёт", "компания"
        ],
        .student: [
            "학번", "학과", "교수", "과제", "레포트", "조별", "팀플", "수강", "강의",
            "출석", "기숙사", "자취", "동아리", "장학금", "학기", "중간고사", "기말고사", "휴학",
            "professor", "assignment", "homework", "student id", "semester", "campus", "dorm", "lecture",
            "学号", "教授", "作业", "学期", "宿舍", "студент", "преподаватель", "семестр", "общежитие"
        ],
        .general: [
            "공동현관", "택배", "배달", "중고", "당근", "회비", "학원", "어린이집", "유치원", "관리비",
            "delivery", "parcel", "landlord"
        ]
    ]

    static let placeholderKeywords: [Persona: [String]] = [
        .nomad: ["통화", "currency", "시차", "timezone", "도시", "city", "iban", "swift", "환율", "국가", "country"],
        .business: ["회사", "company", "직책", "직급", "담당자", "고객사", "거래처", "부서", "견적", "client"],
        .student: ["학번", "학과", "과목", "교수", "분반", "과제", "수업", "강의", "course"],
        .general: ["자녀", "아이", "반", "동호수", "공동현관"]
    ]

    // MARK: - 판정

    /// 알아본다 - **순수 함수.**
    static func infer(_ facts: PersonaFacts) -> Result {
        var scores: [Persona: Double] = [:]
        var tally: [Persona: [Evidence.Kind: Int]] = [:]

        func add(_ persona: Persona, _ kind: Evidence.Kind, weight: Double) {
            scores[persona, default: 0] += weight
            tally[persona, default: [:]][kind, default: 0] += 1
        }

        for item in facts.items {
            if let type = item.type, let weights = typeWeights[type] {
                for (persona, weight) in weights { add(persona, .type(type), weight: weight) }
            }

            let text = ([item.title, item.value ?? ""]).joined(separator: "\n").lowercased()
            let words = wordSet(text)
            for persona in Persona.allCases {
                var hits = 0
                for word in keywords[persona] ?? [] where hits < Threshold.keywordCapPerItem && contains(text, words, word) {
                    hits += 1
                    add(persona, .keyword(word), weight: 1)
                }
            }
        }

        let placeholders = Set(facts.items.flatMap(\.placeholders).map { $0.lowercased() })
        for name in placeholders.sorted() {
            for persona in Persona.allCases where (placeholderKeywords[persona] ?? []).contains(where: { matches(name, $0) }) {
                add(persona, .placeholder(name), weight: Threshold.placeholderWeight)
            }
        }

        for category in facts.customCategories {
            let name = category.lowercased()
            let words = wordSet(name)
            for persona in Persona.allCases where (keywords[persona] ?? []).contains(where: { contains(name, words, $0) }) {
                add(persona, .category(category), weight: Threshold.categoryWeight)
            }
        }

        if let earlier = facts.earlierChoice {
            add(earlier, .earlierChoice, weight: Threshold.earlierChoiceWeight)
        }

        return decide(scores: scores, tally: tally)
    }

    /// 영어 낱말은 **낱말 단위로** 맞춘다. 통째로 찾으면 "wise" 가 "otherwise" 에서,
    /// "bic" 이 "public" 에서 잡힌다. 한국어·중국어는 조사가 붙거나 띄어쓰기가 없어 그대로 찾는다.
    private static func contains(_ text: String, _ words: Set<Substring>, _ keyword: String) -> Bool {
        let isPlainEnglishWord = keyword.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
        return isPlainEnglishWord ? words.contains(Substring(keyword)) : text.contains(keyword)
    }

    private static func wordSet(_ text: String) -> Set<Substring> {
        Set(text.split(whereSeparator: { !($0.isLetter || $0.isNumber) }))
    }

    /// 많이 보인 근거가 앞. 같으면 이름순(결과가 흔들리지 않게).
    private static func evidenceOrder(_ a: Evidence, _ b: Evidence) -> Bool {
        if a.count != b.count { return a.count > b.count }
        return String(describing: a.kind) < String(describing: b.kind)
    }

    /// 빈칸 이름 맞추기. 한 글자 낱말(반)은 통째로 같을 때만 - "분반" 이 "반" 으로 잡히지 않게.
    private static func matches(_ name: String, _ word: String) -> Bool {
        name == word || (word.count >= 2 && name.contains(word))
    }

    private static func decide(scores: [Persona: Double], tally: [Persona: [Evidence.Kind: Int]]) -> Result {
        // 같은 점수면 선언 순서(일반이 먼저)가 이긴다 - 모르면 넓게 잡는다.
        let order: [Persona] = Persona.allCases
        let ranked: [Persona] = order.sorted { a, b in
            let left = scores[a] ?? 0
            let right = scores[b] ?? 0
            if left != right { return left > right }
            return (order.firstIndex(of: a) ?? 0) < (order.firstIndex(of: b) ?? 0)
        }
        guard let top = ranked.first else { return .unknown }
        let topScore: Double = scores[top] ?? 0
        guard topScore > 0 else { return .unknown }
        let second: Double = ranked.count > 1 ? (scores[ranked[1]] ?? 0) : 0

        let confident = topScore >= Threshold.minScore
            && (second == 0 || topScore >= second * Threshold.dominance)

        let chosen: Persona = confident ? top : .general
        let counted: [Evidence] = (tally[chosen] ?? [:]).map { Evidence(kind: $0.key, persona: chosen, count: $0.value) }
        let evidence: [Evidence] = counted.sorted(by: evidenceOrder)

        return Result(persona: chosen,
                      isConfident: confident,
                      scores: scores,
                      evidence: confident ? evidence : [])
    }
}

extension PersonaInference.Evidence.Kind: Hashable {}
