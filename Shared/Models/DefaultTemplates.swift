//
//  DefaultTemplates.swift
//  ClipKeyboard
//
//  Default seed templates. v4.0: global freelancer pack of 30 English templates.
//  Korean locale also gets legacy Korean presets preserved for continuity.
//

import Foundation

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

    /// 기본 템플릿 목록. iOS locale이 `ko`인 경우 legacy Korean 템플릿도 함께 반환.
    static func getDefaultTemplates() -> [Memo] {
        let isKoreanLocale = Locale.current.language.languageCode?.identifier == "ko"
        if isKoreanLocale {
            return englishFreelancerTemplates + koreanLegacyTemplates
        }
        return englishFreelancerTemplates
    }

    // MARK: - v4.0 English Freelancer Pack (30)

    /// 디지털 노마드/원격 프리랜서 중심 30개 프리셋.
    /// {auto-vars}: {timezone}, {currency}, {greeting_time}, {date}, {time} 등은 입력 시점에 자동 치환.
    /// {custom}: {name}, {client_name}, {iban} 등은 사용자가 개별 값 입력.
    private static var englishFreelancerTemplates: [Memo] {
        [
            Memo(
                title: "Intro to new client",
                value: "Hi {client_name}, I'm {name}, a {role} based in {timezone}. Looking forward to {project}.",
                category: "text",
                isTemplate: true,
                templateVariables: ["client_name", "name", "role", "project"]
            ),
            Memo(
                title: "Rate quote",
                value: "My rate for {scope} is {currency} {amount}/hour. Total estimate: {currency} {total}.",
                category: "text",
                isTemplate: true,
                templateVariables: ["scope", "amount", "total"]
            ),
            Memo(
                title: "Timezone auto-reply",
                value: "Hey! I'm currently in {timezone} ({greeting_time} here). I'll get back to you within {hours}h.",
                category: "text",
                isTemplate: true,
                templateVariables: ["hours"]
            ),
            Memo(
                title: "IBAN invoice info",
                value: "Bank: {bank_name}\nIBAN: {iban}\nSWIFT/BIC: {swift}\nAccount name: {name}",
                category: "text",
                isTemplate: true,
                templateVariables: ["bank_name", "iban", "swift", "name"]
            ),
            Memo(
                title: "PayPal payment",
                value: "You can send payment to: paypal.me/{paypal_username}\nAmount: {currency} {amount}",
                category: "text",
                isTemplate: true,
                templateVariables: ["paypal_username", "amount"]
            ),
            Memo(
                title: "Wise payment info",
                value: "Wise (preferred for fast transfers):\nEmail: {wise_email}\nName: {name}",
                category: "text",
                isTemplate: true,
                templateVariables: ["wise_email", "name"]
            ),
            Memo(
                title: "Crypto payment",
                value: "Crypto options:\nUSDC (Polygon): {usdc_wallet}\nUSDT (TRON): {usdt_wallet}\nBTC: {btc_wallet}",
                category: "text",
                isTemplate: true,
                templateVariables: ["usdc_wallet", "usdt_wallet", "btc_wallet"]
            ),
            Memo(
                title: "EU VAT invoice",
                value: "Billing info:\nName: {name}\nAddress: {address}\nVAT: {vat}",
                category: "text",
                isTemplate: true,
                templateVariables: ["name", "address", "vat"]
            ),
            Memo(
                title: "Scope confirmation",
                value: "Just to confirm the scope:\n- {item_1}\n- {item_2}\n- {item_3}\nDeadline: {date}. Sound right?",
                category: "text",
                isTemplate: true,
                templateVariables: ["item_1", "item_2", "item_3"]
            ),
            Memo(
                title: "Delay / running late",
                value: "Hey {client_name}, running a bit late — I'll send {deliverable} by end of {date}. Apologies for the shift.",
                category: "text",
                isTemplate: true,
                templateVariables: ["client_name", "deliverable"]
            ),
            Memo(
                title: "Availability",
                value: "This week I'm available {timezone} {time_range}. Book a slot: {calendar_link}",
                category: "text",
                isTemplate: true,
                templateVariables: ["time_range", "calendar_link"]
            ),
            Memo(
                title: "Thank you (project end)",
                value: "Thanks {client_name}! Was a pleasure working on {project}. If you have 2 min, a short testimonial would mean a lot.",
                category: "text",
                isTemplate: true,
                templateVariables: ["client_name", "project"]
            ),
            Memo(
                title: "Follow-up",
                value: "Hey {client_name}, just following up on {topic}. Any thoughts when you get a sec?",
                category: "text",
                isTemplate: true,
                templateVariables: ["client_name", "topic"]
            ),
            Memo(
                title: "Polite decline",
                value: "Thanks for considering me, {client_name}. Unfortunately I can't take this on right now — my calendar is full through {date}.",
                category: "text",
                isTemplate: true,
                templateVariables: ["client_name"]
            ),
            Memo(
                title: "Kickoff checklist",
                value: "To kick off, I'll need:\n1. {asset_1}\n2. Credentials for {tool}\n3. Decision-maker on the client side\nAnything else blocking?",
                category: "text",
                isTemplate: true,
                templateVariables: ["asset_1", "tool"]
            ),
            Memo(
                title: "Weekly update",
                value: "Week of {date}\nDone: {done}\nNext: {next}\nBlockers: {blockers}",
                category: "text",
                isTemplate: true,
                templateVariables: ["done", "next", "blockers"]
            ),
            Memo(
                title: "File delivery",
                value: "Delivered: {link}\nPassword: {password}\nPlease review by {date} — revisions go into the next round.",
                category: "text",
                isTemplate: true,
                templateVariables: ["link", "password"]
            ),
            Memo(
                title: "Feedback / review request",
                value: "Happy with {deliverable}? A quick review on {platform} really helps me: {review_link}",
                category: "text",
                isTemplate: true,
                templateVariables: ["deliverable", "platform", "review_link"]
            ),
            Memo(
                title: "Meeting request",
                value: "{greeting_time} {client_name}, would {date} {time} {timezone} work for a 30-min call?",
                category: "text",
                isTemplate: true,
                templateVariables: ["client_name"]
            ),
            Memo(
                title: "Reschedule",
                value: "Sorry {client_name}, need to move our {date} call. Free slots:\n- {slot_1}\n- {slot_2}",
                category: "text",
                isTemplate: true,
                templateVariables: ["client_name", "slot_1", "slot_2"]
            ),
            Memo(
                title: "Out of office",
                value: "I'm OOO {start_date}–{end_date}, limited availability. For urgent items: {backup_email}.",
                category: "text",
                isTemplate: true,
                templateVariables: ["start_date", "end_date", "backup_email"]
            ),
            Memo(
                title: "NDA acknowledgment",
                value: "Received, reviewed, signing attached. Ready to kick off once you confirm.",
                category: "text",
                isTemplate: false
            ),
            Memo(
                title: "Contract standard terms",
                value: "Terms:\n- 50% upfront, 50% on delivery\n- NET 7 payment\n- Kill fee: 30% if cancelled after kickoff\n- 2 revision rounds included",
                category: "text",
                isTemplate: false
            ),
            Memo(
                title: "Referral",
                value: "Not the right fit for me on this one, but {colleague_name} would be great: {contact}. Tell them I sent you.",
                category: "text",
                isTemplate: true,
                templateVariables: ["colleague_name", "contact"]
            ),
            Memo(
                title: "Pricing push-back",
                value: "I understand budget matters. Here's a scoped-down version at {currency} {lower_amount}:\n- {reduced_scope}",
                category: "text",
                isTemplate: true,
                templateVariables: ["lower_amount", "reduced_scope"]
            ),
            Memo(
                title: "Extension request",
                value: "Need {extra_days} more days on {deliverable} due to {reason}. New ETA: {date}. Works?",
                category: "text",
                isTemplate: true,
                templateVariables: ["extra_days", "deliverable", "reason"]
            ),
            Memo(
                title: "Asset request",
                value: "To move forward I need:\n- {asset_1}\n- {asset_2}\nCan you send by {date}?",
                category: "text",
                isTemplate: true,
                templateVariables: ["asset_1", "asset_2"]
            ),
            Memo(
                title: "Final delivery",
                value: "Here's the final {deliverable}: {link}. Invoice attached. Thanks for the project, {client_name}!",
                category: "text",
                isTemplate: true,
                templateVariables: ["deliverable", "link", "client_name"]
            ),
            Memo(
                title: "Upsell",
                value: "For {outcome}, I also offer {addon} at {currency} {price}. Happy to scope if interested.",
                category: "text",
                isTemplate: true,
                templateVariables: ["outcome", "addon", "price"]
            ),
            Memo(
                title: "Email signature",
                value: "{name}\n{role} · {website}\n{timezone}",
                category: "text",
                isTemplate: true,
                templateVariables: ["name", "role", "website"]
            )
        ]
    }

    // MARK: - Korean legacy presets (ko locale only)

    private static var koreanLegacyTemplates: [Memo] {
        [
            Memo(
                title: "인사말",
                value: "안녕하세요, {이름}입니다.",
                category: "인사",
                isTemplate: true,
                templateVariables: ["이름"]
            ),
            Memo(
                title: "감사 인사",
                value: "감사합니다. 좋은 하루 되세요!",
                category: "인사",
                isTemplate: false
            ),
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
                templateVariables: ["장소", "참석자"]
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
                templateVariables: ["이름", "직책", "회사명", "이메일", "전화번호"]
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
            try memoStore.save(memos: memoStore.memos, type: .memo)
            hasProvidedDefaultTemplates = true
            print("✅ [DefaultTemplates] 기본 템플릿 \(templates.count)개 제공 완료 (locale: \(Locale.current.identifier))")
        } catch {
            print("❌ [DefaultTemplates] 기본 템플릿 저장 실패: \(error)")
        }
    }
}
