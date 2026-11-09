//
//  ReplyStarterPack.swift
//  ClipKeyboard
//
//  **답장 시작 세트** - 같은 답장을 하루에 수십 번 보내는 사람(스마트스토어 · 당근 셀러, 고객 응대)을 위한
//  단축어 다섯 개. 설정 ▸ 기능 더하기에서 템플릿이 켜져 있을 때 한 줄로 보이고, 누르면 내 단축어에 들어간다.
//
//  왜 다섯 개이고 셋만 빈칸인가: 무료 한도가 단축어 10 · 템플릿 3 이다(`ProFeatureManager`). 무료로 쓰는
//  기간이 끝난 사람에게 넣어도 가려지는 것이 없게 그 안에 맞췄다.
//
//  빈칸 이름은 본문에서 읽는다(`extractTemplatePlaceholders`). 번역된 언어에서 `{고객명}` 이 다른 말로
//  바뀌어도 본문과 빈칸 목록이 늘 같다.
//
//  docs/marketing/MARKETING_PLAN_2026-07.md 의 "같은 문장 반복 타이핑" 앵글. 2026-11.
//

import Foundation

enum ReplyStarterPack {

    /// 한 번 넣었으면 다시 권하지 않는다(지웠어도). 표준 UserDefaults.
    static let addedKey = "replyStarter.added.v1"

    static var isAdded: Bool {
        get { UserDefaults.standard.bool(forKey: addedKey) }
        set { UserDefaults.standard.set(newValue, forKey: addedKey) }
    }

    /// 세트의 단축어 다섯 개. 순서는 하루 중 쓰는 순서다: 첫 인사 → 배송 → 품절 → 교환 · 환불 → 후기 감사.
    static func memos(now: Date = Date()) -> [Memo] {
        [
            make(
                NSLocalizedString("문의 첫 인사", comment: "Reply starter pack: title of the first-response memo"),
                NSLocalizedString("안녕하세요, 문의 감사합니다. 확인 후 빠르게 답변드리겠습니다. 잠시만 기다려 주세요.", comment: "Reply starter pack: body of the first-response memo"),
                now: now
            ),
            make(
                NSLocalizedString("배송 안내", comment: "Reply starter pack: title of the shipping notice template"),
                NSLocalizedString("{고객명}님, 주문하신 상품이 오늘 발송되었습니다. 송장번호는 {송장번호}이고, 보통 1~2일 안에 도착합니다. 감사합니다.", comment: "Reply starter pack: body of the shipping notice template. Keep the {placeholders}"),
                now: now
            ),
            make(
                NSLocalizedString("품절 안내", comment: "Reply starter pack: title of the out-of-stock template"),
                NSLocalizedString("안녕하세요. 문의하신 {상품명}은 현재 품절입니다. 재입고되면 바로 알려 드릴까요? 기다려 주셔서 감사합니다.", comment: "Reply starter pack: body of the out-of-stock template. Keep the {placeholders}"),
                now: now
            ),
            make(
                NSLocalizedString("교환 · 환불 안내", comment: "Reply starter pack: title of the exchange/refund template"),
                NSLocalizedString("안녕하세요, {고객명}님. 주문번호 {주문번호} 교환 · 환불 요청 확인했습니다. 상품을 받은 뒤 2~3일 안에 처리해 드릴게요. 불편을 드려 죄송합니다.", comment: "Reply starter pack: body of the exchange/refund template. Keep the {placeholders}"),
                now: now
            ),
            make(
                NSLocalizedString("후기 감사", comment: "Reply starter pack: title of the review thank-you memo"),
                NSLocalizedString("소중한 후기 감사합니다. 다음에도 만족하실 수 있도록 더 신경 쓰겠습니다. 좋은 하루 보내세요!", comment: "Reply starter pack: body of the review thank-you memo"),
                now: now
            ),
        ]
    }

    /// 내 단축어 뒤에 다섯 개를 붙인다. 이미 넣었으면 아무것도 하지 않는다.
    /// `MemoStore` 는 싱글톤이라 읽고 쓰는 문을 넘겨받는다(시험에서는 배열 하나).
    /// - Returns: 넣은 개수 (0 이면 이미 넣었던 것)
    @discardableResult
    static func add(
        load: () throws -> [Memo] = { try MemoStore.shared.load(type: .memo) },
        save: ([Memo]) throws -> Void = { try MemoStore.shared.save(memos: $0, type: .memo) }
    ) throws -> Int {
        guard !isAdded else { return 0 }
        var all = try load()
        let pack = memos()
        all.append(contentsOf: pack)
        try save(all)
        isAdded = true
        print("✅ [ReplyStarterPack.add] 답장 시작 세트 \(pack.count)개 추가")
        return pack.count
    }

    // MARK: - Private

    private static func make(_ title: String, _ value: String, now: Date) -> Memo {
        var memo = Memo(
            title: title,
            value: value,
            templateVariables: value.extractTemplatePlaceholders()
        )
        memo.lastEdited = now
        return memo
    }
}
