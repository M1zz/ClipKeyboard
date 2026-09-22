//
//  PersonaEdition.swift
//  ClipKeyboard
//
//  **같은 앱, 네 가지 판.** 알아본 쓰임새마다 "이 사람에게 가장 비싼 순간" 이 다르다.
//
//  왜 필요한가: 필요의 순간 지도(docs/product/PERSONA_JOURNEY_MAP.html)를 네 사람으로 그려 보니
//  하루에 앱이 필요해지는 자리가 겹치지 않았다. 정하늘은 당근의 "계좌 알려주세요",
//  한유진은 Slack 의 "banking details", 최민재는 미팅 직후 팔로업, 이서준은 마감 20분 전
//  교수님 메일이다. 같은 빈 화면, 같은 샘플, 같은 키보드 첫 칸을 모두에게 주면
//  네 사람 모두에게 조금씩 남의 앱이다.
//
//  그래서 판마다 세 가지만 다르게 한다. 셋 다 "무엇을 먼저 꺼내 보이나" 이고,
//  한도·결제·기능 잠금은 건드리지 않는다(`FeatureFit` 과 같은 규칙).
//
//  | 무엇 | 어디 | 판마다 다른 것 |
//  | --- | --- | --- |
//  | 필수 단축어 세 칸 | 목록 맨 위 카드 (`PersonaEssentialsCard`) | 그 사람의 가장 비싼 순간 셋 |
//  | 키보드 붙박이 | 빠른 줄 (`QuickRowPlanner` 의 `.anchor`) | 요청이 와야 생기는 순간의 단축어 |
//  | 결제 순간의 차례 | `FeatureFit.purchaseMomentOrder` | 보안 · 두 대째 · 백업 중 무엇이 먼저인가 |
//
//  ⚠️ **확신이 없으면 모두의 판(`everyone`)이다.** 좁혀서 틀리면 엉뚱한 진열대가 선다
//     (`PersonaResolver.confident` 와 같은 규칙). 모두의 판도 비어 있지 않다. 계좌·주소·연락처는
//     네 사람 모두의 재고 목록 위쪽에 있었다.
//
//  ⚠️ 판정은 **순수 함수**다. 기기에서 값을 긁고 적는 일은 `PersonaEditionStore` 가 한다.
//

import Foundation

enum PersonaEdition {

    // MARK: - 판

    enum Kind: String, CaseIterable, Equatable {
        /// 아직 쓰임새를 모른다. 누구에게나 맞는 것부터.
        case everyone
        case general
        case nomad
        case business
        case student
    }

    /// 지금 이 사람에게 맞는 판. 확신이 없으면 모두의 판이다.
    static func kind(for profile: FeatureFit.Profile) -> Kind {
        guard profile.isConfident else { return .everyone }
        switch profile.persona {
        case .general: return .general
        case .nomad: return .nomad
        case .business: return .business
        case .student: return .student
        }
    }

    // MARK: - 필수 단축어

    /// 판마다 먼저 채워 두면 좋은 단축어 한 칸.
    struct Essential: Equatable, Identifiable {
        /// 칸 이름. 저장(`DefaultsKey.editionEssentialLinks`)에 쓰이므로 바꾸지 않는다.
        let id: String
        let emoji: String
        let title: String
        /// 저장될 본문. `{빈칸}` 이 들어 있다.
        let example: String
        /// 이 단축어가 필요해지는 순간. 카드가 "왜 이걸" 에 답하는 한 줄이다.
        let moment: String
        /// 이 종류로 분류된 단축어가 있으면 이미 찬 칸으로 본다.
        let types: Set<ClipboardItemType>
        /// 제목·본문에 이 낱말이 있으면 이미 찬 칸으로 본다(소문자, ko·en).
        let keywords: [String]
        /// **요청이 와야 생기는 순간**인가. 그렇다면 키보드 빠른 줄에 붙박는다.
        /// 언제 올지 모르는 순간이라 박자(`UsageRhythm`)로는 앞에 세울 수 없다.
        let anchorsKeyboard: Bool
    }

    /// 판마다 세 칸. 순서가 곧 카드의 순서이자 붙박이의 순서다.
    static func essentials(for kind: Kind) -> [Essential] {
        switch kind {
        case .everyone: return [account, address, contact]
        case .general: return [account, address, meetup]
        case .nomad: return [payout, timezone, invoice]
        case .business: return [businessCard, followUp, weeklyReport]
        case .student: return [studentID, professorMail, teamNotice]
        }
    }

    // MARK: 모두 · 일반

    static var account: Essential {
        Essential(id: "account", emoji: "💳",
                  title: NSLocalizedString("입금 계좌", comment: "Essential snippet title: my bank account for receiving money"),
                  example: NSLocalizedString("{은행} {계좌번호} {예금주}", comment: "Essential snippet body: bank account. Keep every {…} blank with its braces; translate only the words inside"),
                  moment: NSLocalizedString("누가 \"계좌 알려주세요\" 할 때", comment: "Essential snippet moment: someone asks for your bank account"),
                  types: [.bankAccount, .iban],
                  keywords: ["계좌", "입금", "account", "iban"],
                  anchorsKeyboard: true)
    }

    static var address: Essential {
        Essential(id: "address", emoji: "🏠",
                  title: NSLocalizedString("집 주소", comment: "Essential snippet title: home address"),
                  example: NSLocalizedString("{주소}\n공동현관 {현관 비밀번호}", comment: "Essential snippet body: home address plus building door code. Keep every {…} blank with its braces; translate only the words inside"),
                  moment: NSLocalizedString("배달앱 주소칸이 비어 있을 때", comment: "Essential snippet moment: a delivery app asks for your address"),
                  types: [.address],
                  keywords: ["주소", "공동현관", "address"],
                  anchorsKeyboard: true)
    }

    static var contact: Essential {
        Essential(id: "contact", emoji: "📇",
                  title: NSLocalizedString("내 연락처", comment: "Essential snippet title: my contact details"),
                  example: NSLocalizedString("{이름}\n{전화번호}\n{이메일}", comment: "Essential snippet body: name, phone, email. Keep every {…} blank with its braces; translate only the words inside"),
                  moment: NSLocalizedString("처음 만난 사람이 연락처를 물을 때", comment: "Essential snippet moment: someone new asks for your contact"),
                  types: [.phone, .email],
                  keywords: ["연락처", "전화번호", "이메일", "contact", "phone", "email"],
                  anchorsKeyboard: false)
    }

    static var meetup: Essential {
        Essential(id: "meetup", emoji: "🤝",
                  title: NSLocalizedString("직거래 약속", comment: "Essential snippet title: meeting place for a second-hand trade"),
                  example: NSLocalizedString("{요일} {약속 시간}, {장소} 앞에서 뵐게요. 도착하면 채팅 주세요!", comment: "Essential snippet body: in-person trade meetup. Keep every {…} blank with its braces; translate only the words inside"),
                  moment: NSLocalizedString("중고거래 시간과 장소를 정할 때", comment: "Essential snippet moment: arranging a second-hand trade meetup"),
                  types: [],
                  keywords: ["직거래", "거래", "당근", "meetup", "pickup"],
                  anchorsKeyboard: false)
    }

    // MARK: 노마드

    static var payout: Essential {
        Essential(id: "payout", emoji: "💶",
                  title: NSLocalizedString("송금 정보", comment: "Essential snippet title: international payment details (IBAN, SWIFT)"),
                  example: NSLocalizedString("Name: {영문 이름}\nIBAN: {IBAN}\nSWIFT/BIC: {SWIFT}", comment: "Essential snippet body: payment details for clients. Keep every {…} blank with its braces; translate only the words inside"),
                  moment: NSLocalizedString("클라이언트가 banking details 를 물을 때", comment: "Essential snippet moment: a client asks for your banking details"),
                  types: [.iban, .swift],
                  keywords: ["iban", "swift", "bic", "wise", "banking", "송금"],
                  anchorsKeyboard: true)
    }

    static var timezone: Essential {
        // {도시}·{타임존} 은 자동 변수다. 옮겨 다니는 사람이 매번 고치던 두 자리가 알아서 채워진다.
        Essential(id: "timezone", emoji: "🕐",
                  title: NSLocalizedString("시차 안내", comment: "Essential snippet title: time zone note for booking a call"),
                  example: NSLocalizedString("Hi {상대 이름}, I'm in {도시} ({타임존}). I can do {가능한 시간}. Book here: {예약 링크}", comment: "Essential snippet body: time zone note. {도시} and {타임존} are automatic tokens: in English write {city} and {timezone} exactly. Keep every other {…} blank with its braces"),
                  moment: NSLocalizedString("다른 시간대의 클라이언트와 통화를 잡을 때", comment: "Essential snippet moment: booking a call across time zones"),
                  types: [],
                  keywords: ["시차", "timezone", "time zone", "gmt", "utc", "calendly"],
                  anchorsKeyboard: false)
    }

    static var invoice: Essential {
        // {번호} 는 다음 번호 칩(`PlaceholderSequence`)이 받는다. 지난달 번호가 그대로 나가지 않는다.
        Essential(id: "invoice", emoji: "🧾",
                  title: NSLocalizedString("인보이스", comment: "Essential snippet title: invoice email"),
                  example: NSLocalizedString("Invoice #{번호} · {금액}\nDue: {기한}\nPayment: {결제 수단}", comment: "Essential snippet body: invoice. Keep every {…} blank with its braces; translate only the words inside"),
                  moment: NSLocalizedString("월말에 인보이스를 보낼 때", comment: "Essential snippet moment: sending the monthly invoice"),
                  types: [],
                  keywords: ["invoice", "인보이스", "청구서"],
                  anchorsKeyboard: false)
    }

    // MARK: 직장인

    static var businessCard: Essential {
        Essential(id: "businessCard", emoji: "📇",
                  title: NSLocalizedString("명함 인사", comment: "Essential snippet title: business card greeting"),
                  example: NSLocalizedString("안녕하세요, {회사} {이름}입니다.\n{이메일} / {전화번호}", comment: "Essential snippet body: business intro with contact. Keep every {…} blank with its braces; translate only the words inside"),
                  moment: NSLocalizedString("명함을 주고받은 뒤 \"자료 보내 주세요\" 가 왔을 때", comment: "Essential snippet moment: a new lead asks for materials"),
                  types: [],
                  keywords: ["명함", "서명", "signature", "business card"],
                  anchorsKeyboard: true)
    }

    static var followUp: Essential {
        Essential(id: "followUp", emoji: "📨",
                  title: NSLocalizedString("미팅 팔로업", comment: "Essential snippet title: follow-up email after a meeting"),
                  example: NSLocalizedString("{담당자}님, 오늘 {고객사} 미팅 감사합니다.\n논의: {요약}\n다음 단계: {다음 단계} ({다음 일정})", comment: "Essential snippet body: meeting follow-up. Keep every {…} blank with its braces; translate only the words inside"),
                  moment: NSLocalizedString("미팅이 끝나고 오늘 안에 팔로업을 보낼 때", comment: "Essential snippet moment: sending a same-day follow-up"),
                  types: [],
                  keywords: ["팔로업", "follow-up", "follow up", "미팅", "meeting"],
                  anchorsKeyboard: false)
    }

    static var weeklyReport: Essential {
        Essential(id: "weeklyReport", emoji: "📋",
                  title: NSLocalizedString("주간 보고", comment: "Essential snippet title: weekly status report"),
                  example: NSLocalizedString("완료: {완료한 일}\n진행: {진행 중인 일}\n다음 주: {다음 주 계획}", comment: "Essential snippet body: weekly report. Keep every {…} blank with its braces; translate only the words inside"),
                  moment: NSLocalizedString("금요일 오후 보고 마감 전에", comment: "Essential snippet moment: before the Friday report deadline"),
                  types: [],
                  keywords: ["주간", "보고", "weekly", "report"],
                  anchorsKeyboard: false)
    }

    // MARK: 학생

    static var studentID: Essential {
        Essential(id: "studentID", emoji: "🎓",
                  title: NSLocalizedString("학과 학번 이름", comment: "Essential snippet title: department, student number, name"),
                  example: NSLocalizedString("{학과} {학번} {이름}", comment: "Essential snippet body: student identity line. Keep every {…} blank with its braces; translate only the words inside"),
                  moment: NSLocalizedString("출석 구글폼·과제 제출에 학번을 적을 때", comment: "Essential snippet moment: typing your student number into forms"),
                  types: [.employeeID],
                  keywords: ["학번", "학과", "student id", "student number"],
                  anchorsKeyboard: true)
    }

    static var professorMail: Essential {
        // {학과}{학번}{이름} 은 위 칸과 같은 이름이라 거기서 적은 값이 칩으로 따라온다.
        Essential(id: "professorMail", emoji: "✉️",
                  title: NSLocalizedString("교수님 메일", comment: "Essential snippet title: email to a professor"),
                  example: NSLocalizedString("안녕하세요 교수님, {학과} {학번} {이름}입니다.\n{과목} {과제} 제출드립니다.", comment: "Essential snippet body: polite email to a professor. Keep every {…} blank with its braces; translate only the words inside"),
                  moment: NSLocalizedString("마감 직전 과제를 메일로 낼 때", comment: "Essential snippet moment: emailing an assignment near the deadline"),
                  types: [],
                  keywords: ["교수", "professor"],
                  anchorsKeyboard: false)
    }

    static var teamNotice: Essential {
        Essential(id: "teamNotice", emoji: "📢",
                  title: NSLocalizedString("조별과제 공지", comment: "Essential snippet title: team project meeting notice"),
                  example: NSLocalizedString("[{과제}] 회의\n{회의 날짜} {회의 시간} @ {장소}\n준비: {준비물}\n확인하면 👍", comment: "Essential snippet body: team meeting notice. Keep every {…} blank with its braces; translate only the words inside"),
                  moment: NSLocalizedString("조장이 되어 회의 공지를 올릴 때", comment: "Essential snippet moment: posting a team meeting notice"),
                  types: [],
                  keywords: ["조별", "팀플", "team project", "group project"],
                  anchorsKeyboard: false)
    }

    // MARK: - 카드 머리말

    /// 카드 맨 위 한 줄. 판마다 "이 앱이 당신에게 무엇인가" 를 다르게 말한다.
    static func headline(for kind: Kind) -> String {
        switch kind {
        case .everyone:
            return NSLocalizedString("가장 자주 다시 치는 세 가지부터", comment: "Essentials card headline for users whose usage is not known yet")
        case .general:
            return NSLocalizedString("계좌·주소는 한 번만 맞춰 두세요", comment: "Essentials card headline: everyday personal use")
        case .nomad:
            return NSLocalizedString("돈 받는 순간을 3초로", comment: "Essentials card headline: freelancer / nomad")
        case .business:
            return NSLocalizedString("고칠 곳을 빈칸으로, 실수 없이", comment: "Essentials card headline: office worker")
        case .student:
            return NSLocalizedString("학번은 이제 한 탭으로", comment: "Essentials card headline: student")
        }
    }

    // MARK: - 이미 찬 칸

    /// 판정에 넣는 단축어 하나. 샘플은 부르는 쪽이 이미 뺐다.
    struct Candidate: Equatable {
        var id: UUID
        var title: String
        /// 본문. 보안 단축어는 nil(암호문이다).
        var value: String?
        var type: ClipboardItemType?
    }

    /// 칸마다 그 칸을 채운 단축어 - **순수 함수.**
    ///
    /// 보는 순서: ① 판 안에서 만든 것(`links`) ② 분류된 종류 ③ 제목·본문의 낱말.
    /// 단축어 하나는 **한 칸만** 채운다. 연락처 하나가 명함·연락처 두 칸을 다 채우면
    /// 남은 칸이 없는데도 카드가 "다 됐다" 고 말한다.
    ///
    /// - Parameter links: 판 안에서 만든 단축어(`[Essential.id: UUID]`). 지워진 것은 무시한다.
    static func coverage(of essentials: [Essential],
                         candidates: [Candidate],
                         links: [String: UUID] = [:]) -> [String: UUID] {
        var result: [String: UUID] = [:]
        var used = Set<UUID>()
        let alive = Set(candidates.map(\.id))

        for essential in essentials {
            if let linked = links[essential.id], alive.contains(linked), !used.contains(linked) {
                result[essential.id] = linked
                used.insert(linked)
            }
        }
        for essential in essentials where result[essential.id] == nil {
            if let hit = candidates.first(where: { !used.contains($0.id) && matches($0, essential) }) {
                result[essential.id] = hit.id
                used.insert(hit.id)
            }
        }
        return result
    }

    static func matches(_ candidate: Candidate, _ essential: Essential) -> Bool {
        if let type = candidate.type, essential.types.contains(type) { return true }
        let haystack = (candidate.title + "\n" + (candidate.value ?? "")).lowercased()
        return essential.keywords.contains { haystack.contains($0) }
    }

    // MARK: - 키보드 붙박이

    /// 붙박이는 이만큼만. 빠른 줄은 다섯 칸이고, 박자와 최근 쓴 것이 설 자리가 남아야 한다.
    static let anchorLimit = 2

    /// 키보드 빠른 줄에 붙박을 단축어 - **순수 함수.**
    ///
    /// 요청이 와야 생기는 순간(계좌·송금 정보·명함·학번)은 언제 올지 몰라 박자로 앞에 세울 수 없다.
    /// 대신 그 순간이 오면 **늘 같은 자리에** 있으면 된다. 찾지 않아도 되는 자리가 첫 칸이다.
    static func anchors(for kind: Kind, coverage: [String: UUID]) -> [UUID] {
        let ids = essentials(for: kind)
            .filter(\.anchorsKeyboard)
            .compactMap { coverage[$0.id] }
        return Array(ids.prefix(anchorLimit))
    }

    // MARK: - 카드를 세울까

    struct ShelfContext: Equatable {
        var kind: Kind
        /// 찬 칸 수.
        var covered: Int
        /// 전체 칸 수.
        var total: Int
        /// 카드를 닫은 판들.
        var dismissed: Set<Kind>
        /// 자기 단축어 수(샘플 제외).
        var ownMemoCount: Int
        /// 휴면이거나 막 돌아왔는가. 돌아온 첫 화면에 숙제부터 꺼내지 않는다.
        var isAwayOrJustBack: Bool
        /// 목록을 다 읽었는가. 읽기 전에 세우면 "빈 칸 셋" 이 잠깐 번쩍인다.
        var hasLoaded: Bool
    }

    /// 목록 맨 위에 필수 단축어 카드를 세울지 - **순수 함수.**
    ///
    /// ⚠️ 자기 단축어를 **하나는 만든 뒤**에만 선다. 처음 여는 사람에게는 무대와
    ///    "직접 만들어 보기" 가 이미 같은 일을 한다. 둘이 한 화면에서 서로 먼저 하라고 하지 않게.
    static func showsShelf(_ context: ShelfContext) -> Bool {
        guard context.hasLoaded, !context.isAwayOrJustBack else { return false }
        guard context.ownMemoCount >= 1 else { return false }
        guard !context.dismissed.contains(context.kind) else { return false }
        return context.covered < context.total
    }
}

// MARK: - 기기에서 읽고 적기

/// 판에 쓰는 값을 App Group 에서 읽고 적는다. 판정은 위 `PersonaEdition` 이 한다.
enum PersonaEditionStore {

    private static var defaults: UserDefaults? { AppGroup.defaults }

    /// 지금의 판. 쓰임새(`PersonaResolver.profile`)에서 나온다.
    static var currentKind: PersonaEdition.Kind {
        PersonaEdition.kind(for: PersonaResolver.profile)
    }

    // MARK: 판 안에서 만든 단축어

    static var links: [String: UUID] {
        let raw = defaults?.dictionary(forKey: DefaultsKey.editionEssentialLinks) as? [String: String] ?? [:]
        return raw.compactMapValues(UUID.init(uuidString:))
    }

    /// 칸을 판 안에서 채웠다고 적는다. 제목을 고치거나 언어를 바꿔도 그 칸은 찬 것으로 남는다.
    static func link(_ essentialID: String, to memoID: UUID) {
        var raw = defaults?.dictionary(forKey: DefaultsKey.editionEssentialLinks) as? [String: String] ?? [:]
        raw[essentialID] = memoID.uuidString
        defaults?.set(raw, forKey: DefaultsKey.editionEssentialLinks)
        print("🧩 [PersonaEditionStore.link] '\(essentialID)' 칸을 채움")
    }

    // MARK: 닫은 카드

    static var dismissed: Set<PersonaEdition.Kind> {
        let raw = defaults?.stringArray(forKey: DefaultsKey.editionShelfDismissed) ?? []
        return Set(raw.compactMap(PersonaEdition.Kind.init(rawValue:)))
    }

    static func dismiss(_ kind: PersonaEdition.Kind) {
        var raw = defaults?.stringArray(forKey: DefaultsKey.editionShelfDismissed) ?? []
        guard !raw.contains(kind.rawValue) else { return }
        raw.append(kind.rawValue)
        defaults?.set(raw, forKey: DefaultsKey.editionShelfDismissed)
        print("🧩 [PersonaEditionStore.dismiss] '\(kind.rawValue)' 판 카드를 닫음")
    }

    // MARK: 판정에 넣을 값

    static func candidates(memos: [Memo], sampleIDs: Set<UUID>) -> [PersonaEdition.Candidate] {
        memos
            .filter { !sampleIDs.contains($0.id) }
            .map { memo in
                PersonaEdition.Candidate(id: memo.id,
                                         title: memo.title,
                                         value: memo.isSecure ? nil : memo.value,
                                         type: PersonaResolver.detectedType(of: memo))
            }
    }

    /// 지금 판의 칸마다 채운 단축어.
    static func coverage(memos: [Memo], sampleIDs: Set<UUID>,
                         kind: PersonaEdition.Kind = currentKind) -> [String: UUID] {
        PersonaEdition.coverage(of: PersonaEdition.essentials(for: kind),
                                candidates: candidates(memos: memos, sampleIDs: sampleIDs),
                                links: links)
    }

    // MARK: 다시 재기

    /// 키보드 붙박이를 다시 적는다. 키보드는 이 목록만 읽는다(쓰임새 판정은 앱에만 있다).
    ///
    /// ⚠️ 부르는 자리는 `UserStateStore.refresh` 다. 쓰임새를 다시 알아본 **바로 뒤**여야
    ///    판이 바뀐 날 붙박이도 같이 바뀐다.
    static func refresh(memos: [Memo], sampleIDs: Set<UUID>) {
        let kind = currentKind
        let anchors = PersonaEdition.anchors(for: kind,
                                             coverage: coverage(memos: memos, sampleIDs: sampleIDs, kind: kind))
        if anchors != QuickRowAnchors.load() {
            QuickRowAnchors.save(anchors)
            print("🧩 [PersonaEditionStore.refresh] '\(kind.rawValue)' 판 붙박이 \(anchors.count)개")
        }
    }
}
